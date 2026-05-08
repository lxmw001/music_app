import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/youtube_cookie_auth.dart';

/// Full-screen WebView that lets the user log into YouTube.
/// Extracts and saves cookies on successful login, then pops.
class YouTubeLoginWebView extends StatefulWidget {
  const YouTubeLoginWebView({super.key});

  @override
  State<YouTubeLoginWebView> createState() => _YouTubeLoginWebViewState();
}

class _YouTubeLoginWebViewState extends State<YouTubeLoginWebView> {
  bool _saving = false;

  Future<void> _trySaveCookies(InAppWebViewController controller) async {
    if (_saving) return;
    final url = (await controller.getUrl())?.toString() ?? '';
    // Only extract after landing back on YouTube (not on accounts.google.com)
    if (!url.contains('youtube.com') || url.contains('accounts.google')) return;

    final cookies = await YoutubeCookieAuth.extractCookies();
    if (cookies.length < 2) return; // not logged in yet

    _saving = true;
    await YoutubeCookieAuth.saveCookies(cookies);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to YouTube'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://accounts.google.com/ServiceLogin?service=youtube'),
        ),
        initialSettings: InAppWebViewSettings(
          userAgent: 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          clearCache: false,
          clearSessionCache: false,
        ),
        onLoadStop: (controller, url) => _trySaveCookies(controller),
      ),
    );
  }
}
