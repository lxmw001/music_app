import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get user => _auth.currentUser;
  bool get isSignedIn => user != null;
  bool _loading = false;
  bool get loading => _loading;

  AuthProvider() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  Future<bool> signInWithGoogle() async {
    try {
      _loading = true;
      notifyListeners();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false; // user cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      print('[Auth] signInWithGoogle error: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<String?> getIdToken() async => user?.getIdToken() != null ? await user!.getIdToken() : null;

  Future<bool> hasPermission(String permission) async {
    final result = await user?.getIdTokenResult();
    final perms = result?.claims?['permissions'] as List<dynamic>? ?? [];
    return perms.contains(permission);
  }
}
