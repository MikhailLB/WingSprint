import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ============================================================
// LEGAL VIEW — lightweight WebView for privacy / support pages
// ============================================================
// Opened from the native game menu so the privacy policy and support
// pages stay reachable for organic users (store requirement).
// ============================================================

class LegalView extends StatefulWidget {
  final String title;
  final String url;

  const LegalView({super.key, required this.title, required this.url});

  @override
  State<LegalView> createState() => _LegalViewState();
}

class _LegalViewState extends State<LegalView> {
  late final WebViewController _web;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF4F7FB))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C6CFF),
        foregroundColor: Colors.white,
        title: Text(widget.title),
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _web),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C6CFF)),
              ),
            ),
        ],
      ),
    );
  }
}
