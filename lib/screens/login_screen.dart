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
    
    final hasCookies = await YoutubeCookieAuth.hasCookies();
    if (!hasCookies && mounted) {
      final ytOk = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const YouTubeLoginWebView()),
      );
      if (mounted && ytOk == true) {
        await auth.reloadYouTubeCookies();
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.15),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note_rounded, 
                    size: 100, 
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Music App', 
                  style: TextStyle(
                    fontSize: 40, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Millions of songs.\nFree on Music App.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400], 
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                if (_busy)
                  const CircularProgressIndicator()
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _signIn,
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 24, height: 24,
                        errorBuilder: (_, __, ___) => const Icon(Icons.login_rounded, size: 24),
                      ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[800]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text(
                        'Continue without signing in',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
