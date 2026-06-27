import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../core/agent_client.dart';
import '../core/net_sensor.dart';
import '../core/push_center.dart';
import '../core/vault.dart';
import 'offline_screen.dart';

// ============================================================
// PORTAL STAGE — full-screen WebView shell (web routing)
// ============================================================
// Immersive, dual-orientation WebView with: real device UA, file
// upload, third-party cookies, video autoplay, in-history back, push
// live-URL swap, and the full keyboard / safe-area JS injection set.
//
// Hardened per the gray-part pitfalls:
//   • Landscape padding uses viewPadding.left/right so content never
//     slides under a side camera cutout; portrait pads the status bar.
//   • Keyboard fix uses behavior:'auto' + a single 350 ms scroll (a
//     smooth scroll fights the IME animation and jitters).
//   • Safe-area CSS re-applies on SPA route changes but PAUSES while
//     the keyboard is open (a mid-animation relayout causes a jump).
//   • onWebResourceError covers the native error page with a spinner
//     immediately and, for DNS/disconnect codes, routes offline
//     without a second redundant DNS probe.
//   • A blackout on the connectivity stream is debounced 700 ms before
//     routing offline, absorbing VPN-toggle flicker.
// ============================================================

/// Optional pre-warm hook invoked after the deferred library loads.
Future<void> warmupPortalEngine() async {}

class PortalStage extends StatefulWidget {
  final String url;
  final Vault vault;
  final PushCenter push;
  final NetSensor net;

  const PortalStage({
    super.key,
    required this.url,
    required this.vault,
    required this.push,
    required this.net,
  });

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinning = true;
  bool _routedOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _netSub;
  Timer? _blackoutTimer;

  String? _lastMainFrameUrl;
  int _redirectRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agentClient.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _spinning = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _spinning = false);
            _redirectRetries = 0;
            _injectSafeAreaKill();
            _injectKeyboardFix();
          },
          onWebResourceError: _onResourceError,
          onHttpError: (_) {},
          onNavigationRequest: _onNavigation,
        ),
      );

    _attachPlatform();
    _web.loadRequest(Uri.parse(widget.url));

    widget.push.onLiveUrl = (url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _netSub = widget.net.changes.listen((states) {
      if (NetSensor.isBlackout(states)) {
        _blackoutTimer?.cancel();
        _blackoutTimer = Timer(const Duration(milliseconds: 700), () {
          _gotoOffline();
        });
      } else {
        _blackoutTimer?.cancel();
      }
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    const inApp = {'http', 'https', 'about', 'data', 'blob'};
    if (inApp.contains(uri.scheme)) {
      if (request.isMainFrame) _lastMainFrameUrl = request.url;
      return NavigationDecision.navigate;
    }
    _openExternally(uri);
    return NavigationDecision.prevent;
  }

  void _onResourceError(WebResourceError error) {
    if (error.isForMainFrame != true) return;

    final blurb = error.description.toLowerCase();
    final isRedirectLoop = blurb.contains('too_many_redirects') ||
        blurb.contains('too many redirects') ||
        error.errorCode == -1007 ||
        error.errorCode == -9;
    if (isRedirectLoop &&
        _lastMainFrameUrl != null &&
        _redirectRetries < 3) {
      _redirectRetries++;
      _web.loadRequest(Uri.parse(_lastMainFrameUrl!));
      return;
    }

    // Cover the native error page right away.
    if (mounted) setState(() => _spinning = true);

    final dnsOrDrop = blurb.contains('name_not_resolved') ||
        blurb.contains('internet_disconnected') ||
        blurb.contains('network_changed') ||
        error.errorCode == -105 ||
        error.errorCode == -106 ||
        error.errorCode == -21;

    if (dnsOrDrop) {
      _gotoOffline();
    } else {
      _gotoOfflineIfDown();
    }
  }

  Future<void> _gotoOfflineIfDown() async {
    if (_routedOffline) return;
    final reachable = await widget.net.isReachable();
    if (reachable || !mounted) return;
    _gotoOffline();
  }

  Future<void> _gotoOffline() async {
    if (_routedOffline || !mounted) return;
    _routedOffline = true;
    final current = await _web.currentUrl() ?? widget.url;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineScreen(
          resumeBuilder: (_) => PortalStage(
            url: current,
            vault: widget.vault,
            push: widget.push,
            net: widget.net,
          ),
        ),
      ),
    );
  }

  void _attachPlatform() {
    if (!Platform.isAndroid) return;
    final platform = _web.platform;
    if (platform is! AndroidWebViewController) return;

    platform.setMediaPlaybackRequiresUserGesture(false);
    platform.setOnShowFileSelector(_pickFiles);

    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(platform, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      // file_picker is pinned to the Java-based 8.x line; always use the
      // platform instance API (the static call is deprecated/removed).
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result != null) {
        return result.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _injectKeyboardFix() {
    _web.runJavaScript(r'''
(function(){
  if (window.__wsKbFix) return;
  window.__wsKbFix = true;
  function editable(n){
    if(!n) return false;
    var t=n.tagName;
    return t==='INPUT'||t==='TEXTAREA'||n.isContentEditable===true;
  }
  function reveal(){
    var n=document.activeElement;
    if(!editable(n)) return;
    var vv=window.visualViewport;
    if(vv){
      var b=n.getBoundingClientRect();
      var floor=vv.offsetTop+vv.height;
      if(b.bottom>floor-20||b.top<vv.offsetTop){
        n.scrollIntoView({behavior:'auto',block:'nearest'});
      }
    } else {
      n.scrollIntoView({behavior:'auto',block:'nearest'});
    }
  }
  document.addEventListener('focusin',function(e){
    if(editable(e.target)) setTimeout(reveal,350);
  });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height;
      if(h<prev) setTimeout(reveal,120);
      prev=h;
    });
  }
})();
''');
  }

  void _injectSafeAreaKill() {
    _web.runJavaScript(r'''
(function(){
  if (window.__wsSafeKill) return;
  window.__wsSafeKill = true;
  var STYLE_ID='__ws_safe';
  var CSS=':root{'
    +'--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;'
    +'}'
    +'html,body,#app,#root,#__nuxt,#__layout{padding-top:0!important;'
    +'padding-left:0!important;padding-right:0!important;margin-top:0!important;}';
  function kbOpen(){
    if(!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight*0.75;
  }
  function apply(){
    if(kbOpen()) return; // never relayout mid keyboard animation
    var head=document.head||document.documentElement;
    if(!head) return;
    var meta=document.querySelector('meta[name="viewport"]');
    if(meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content')||'')){
      var c=(meta.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      meta.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var st=document.getElementById(STYLE_ID);
    if(!st){st=document.createElement('style');st.id=STYLE_ID;head.appendChild(st);}
    if(st.textContent!==CSS) st.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var orig=history[fn];
    history[fn]=function(){var r=orig.apply(this,arguments);setTimeout(apply,90);setTimeout(apply,420);return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,90);});
  setInterval(apply,2600);
})();
''');
  }

  Future<bool> _handleBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blackoutTimer?.cancel();
    _netSub?.cancel();
    widget.push.onLiveUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    // Landscape: respect side notch insets. Portrait: pad the status bar.
    final padding = landscape
        ? EdgeInsets.only(
            left: media.viewPadding.left,
            right: media.viewPadding.right,
          )
        : EdgeInsets.only(top: media.viewPadding.top);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: padding,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinning)
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF33D6FF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
