import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'cipher.dart';

// ============================================================
// AGENT CLIENT — device-accurate User-Agent HTTP client
// ============================================================
// Every outbound request (gateway POST, attribution refresh, push
// image download) and the WebView itself share ONE User-Agent that
// looks like a real mobile Chrome/Safari build. A generic Dart UA
// would be anomalous to attribution networks and some affiliate
// backends block it.
//
// NOTE: this game is an arcade theme (not a slot), so per the
// gray_user_agent rule we do NOT append the appid/appname identity
// suffix — the plain browser UA is used verbatim.
//
// The Chrome/WebKit version fragments are obfuscated via reveal().
// ============================================================

// "126.0.6478.71"
const List<int> _chromeBlob = [
  14, 234, 222, 37, 82, 77, 53, 189, 71, 60, 98, 145, 104,
];

// "537.36"
const List<int> _webkitBlob = [10, 235, 223, 37, 81, 85];

class AgentClient extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String _ua = 'Mozilla/5.0';

  String get userAgent => _ua;

  /// Reads real device characteristics once and assembles a UA string.
  /// Call from main() before runApp().
  Future<void> warmUp() async {
    final chrome = _orFallback(reveal(_chromeBlob), '126.0.6478.71');
    final webkit = _orFallback(reveal(_webkitBlob), '537.36');
    try {
      final probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await probe.androidInfo;
        final fingerprint =
            a.display.isNotEmpty ? a.display : (a.id.isNotEmpty ? a.id : 'V');
        _ua = _composeAndroid(
          release: _marketingVersion(a.version.release, a.version.sdkInt),
          brand: a.brand,
          model: a.model,
          build: fingerprint,
          chrome: chrome,
          webkit: webkit,
        );
      } else {
        final i = await probe.iosInfo;
        _ua = _composeApple(i.systemVersion, webkit);
      }
    } catch (_) {
      _ua = Platform.isAndroid
          ? _composeAndroid(
              release: '14',
              brand: 'google',
              model: 'Pixel 8',
              build: 'UP1A',
              chrome: chrome,
              webkit: webkit,
            )
          : _composeApple('17.0', webkit);
    }
  }

  static String _orFallback(String value, String fallback) =>
      value.isEmpty ? fallback : value;

  // Maps the API level to its marketing OS version — some OEM images
  // report Build.VERSION.RELEASE incorrectly (empty, or clobbered with
  // the API level itself), which would otherwise leak the SDK number
  // into the UA where a real Android version (e.g. "14") is expected.
  static const Map<int, String> _sdkToMarketing = {
    30: '11', 31: '12', 32: '12', 33: '13', 34: '14', 35: '15', 36: '16',
  };

  static String _marketingVersion(String release, int sdkInt) {
    final trimmed = release.trim();
    final asInt = int.tryParse(trimmed);
    // Real Android release strings never reach the 20s/30s — those
    // values belong to the API level, so treat them as the OEM bug
    // above and recover the version from the SDK-level table instead.
    final looksLikeSdkLevel = asInt != null && asInt >= 20;
    if (trimmed.isNotEmpty && !looksLikeSdkLevel) return trimmed;
    return _sdkToMarketing[sdkInt] ??
        (sdkInt > 20 ? '${sdkInt - 20}' : '14');
  }

  static String _composeAndroid({
    required String release,
    required String brand,
    required String model,
    required String build,
    required String chrome,
    required String webkit,
  }) {
    final ver = release.isEmpty ? '14' : release;
    return 'Mozilla/5.0 (Linux; Android $ver; $brand $model Build/$build) '
        'AppleWebKit/$webkit (KHTML, like Gecko) '
        'Chrome/$chrome Mobile Safari/$webkit';
  }

  static String _composeApple(String osVer, String webkit) {
    final underscored = osVer.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $underscored like Mac OS X) '
        'AppleWebKit/$webkit (KHTML, like Gecko) '
        'Version/$osVer Mobile/15E148 Safari/$webkit';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Process-wide HTTP client shared by every core service.
final AgentClient agentClient = AgentClient();
