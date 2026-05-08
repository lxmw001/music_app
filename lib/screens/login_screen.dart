import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/youtube_cookie_auth.dart';
import '../widgets/youtube_login_webview.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithGoogle();
    if (!ok || !mounted) {
      setState(() => _busy = false);
      return;
    }
    // Skip YouTube WebView if cookies already saved from a previous login
    final hasCookies = await YoutubeCookieAuth.hasCookies();
    if (!hasCookies && mounted) {
      print('[LoginScreen] Google sign-in OK, opening YouTube WebView');
      final ytOk = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const YouTubeLoginWebView()),
      );
      print('[LoginScreen] YouTube WebView result: $ytOk');
      if (mounted && ytOk == true) {
        await auth.reloadYouTubeCookies();
        print('[LoginScreen] YouTube cookies reloaded');
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text('Music App', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sign in to unlock all features', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              if (_busy)
                const CircularProgressIndicator(color: Colors.green)
              else
                OutlinedButton.icon(
                  onPressed: _signIn,
                  icon: Image.network(
                    'https://www.google.com/favicon.ico',
                    width: 20, height: 20,
                    errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
                  ),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue without signing in', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
