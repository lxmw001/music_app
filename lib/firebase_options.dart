import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjvU53arQvSmEYe073cOl2Y8n9i4IT-cg',
    appId: '1:950104611859:android:6bd99913ae79a0fa05f3e6',
    messagingSenderId: '950104611859',
    projectId: 'music-app-e8267',
    storageBucket: 'music-app-e8267.firebasestorage.app',
  );
}
