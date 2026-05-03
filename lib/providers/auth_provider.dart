import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';

// TODO: Replace with FirebaseAuth.instance.currentUser?.getIdToken() once Firebase is set up
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();

  User? get user => _auth.currentUser;
  bool get isSignedIn => user != null;
  bool _loading = false;
  bool get loading => _loading;

  // Cached permissions from token claims
  Set<String> _permissions = {};
  bool hasPermission(String permission) => _permissions.contains(permission);
  bool get canDownload => hasPermission('offline_play');
  bool get hasSuggestedPlaylists => hasPermission('suggest_playlists');

  AuthProvider() {
    _auth.authStateChanges().listen((u) async {
      if (u != null) await _refreshPermissions();
      notifyListeners();
    });
  }

  Future<void> _refreshPermissions() async {
    try {
      final result = await user?.getIdTokenResult(true);
      final perms = result?.claims?['permissions'] as List<dynamic>? ?? [];
      _permissions = perms.map((e) => e.toString()).toSet();
      print('[Auth] permissions: $_permissions');
    } catch (e) {
      print('[Auth] failed to refresh permissions: $e');
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _loading = true;
      notifyListeners();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      await _refreshPermissions();
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
    _permissions = {};
    notifyListeners();
  }

  Future<String?> getIdToken() async => user?.getIdToken();

  /// Sync a liked song to the server (fire-and-forget, local state is source of truth)
  void syncLike(String serverId, bool liked) {
    if (!isSignedIn || serverId.isEmpty) return;
    if (liked) {
      _api.post('/users/me/liked-songs/$serverId').catchError((e) {
        print('[Auth] syncLike error: $e');
        return null;
      });
    } else {
      _api.delete('/users/me/liked-songs/$serverId').catchError((e) {
        print('[Auth] syncUnlike error: $e');
      });
    }
  }

  /// Sync a downloaded song to the server (fire-and-forget)
  void syncDownload(String serverId, bool downloaded) {
    if (!isSignedIn || serverId.isEmpty) return;
    if (downloaded) {
      _api.post('/users/me/downloads/$serverId').catchError((e) {
        print('[Auth] syncDownload error: $e');
        return null;
      });
    } else {
      _api.delete('/users/me/downloads/$serverId').catchError((e) {
        print('[Auth] syncDeleteDownload error: $e');
      });
    }
  }
}
