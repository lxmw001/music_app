import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
              if (auth.loading)
                const CircularProgressIndicator(color: Colors.green)
              else
                OutlinedButton.icon(
                  onPressed: () => auth.signInWithGoogle(),
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
