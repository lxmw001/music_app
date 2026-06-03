import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/youtube_cookie_auth.dart';
import '../widgets/youtube_login_webview.dart';
import '../widgets/mesh_gradient.dart';
import '../widgets/floating_particles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    HapticFeedback.mediumImpact();
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
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          const MeshGradient(color: Colors.blue),
          FloatingParticles(color: primary),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Iconic Logo Container
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Icon(
                            Icons.music_note_rounded, 
                            size: 80, 
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Music App', 
                    style: TextStyle(
                      fontSize: 44, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Discover your flow with AI vibes.\nJoin millions listening for free.', 
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), 
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_busy)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _signIn,
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 24, height: 24,
                          errorBuilder: (_, __, ___) => const Icon(Icons.login_rounded, size: 24),
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          backgroundColor: Colors.white.withValues(alpha: 0.03),
                        ),
                        child: const Text(
                          'Skip for now',
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
        ],
      ),
    );
  }
}
