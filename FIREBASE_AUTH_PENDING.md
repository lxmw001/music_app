# Pending: Firebase Authentication Integration

## Prerequisites (manual steps required first)

### 1. Create a Firebase project
- Go to https://console.firebase.google.com
- Create a new project (or use existing)
- Enable **Authentication → Sign-in Method → Google**

### 2. Install Firebase CLI tools
```bash
npm install -g firebase-tools
firebase login

dart pub global activate flutterfire_cli
```

### 3. Configure FlutterFire (run inside project directory)
```bash
flutterfire configure
```
This generates `lib/firebase_options.dart` and downloads `android/app/google-services.json`.

### 4. Add `google-services.json` to git
```bash
git add android/app/google-services.json
```

---

## What will be implemented (by Kiro after prerequisites)

- `firebase_core: ^4.7.0`, `firebase_auth: ^6.4.0`, `google_sign_in: ^7.2.0` added to `pubspec.yaml`
- Firebase initialized in `main.dart` before `runApp`
- `AuthService` — Google Sign-In, sign-out, anonymous fallback
- `UserProvider` — exposes current user + custom claims app-wide
- Sign-in screen shown to unauthenticated users
- `MusicServerService` sends `Authorization: Bearer <idToken>` on all requests (ready for server-side auth)
- Features gated by custom claims (e.g. `claims['premium'] == true`)

## Custom claims reference
Claims are set server-side via Firebase Admin SDK and read in Flutter:
```dart
final result = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
final isPremium = result?.claims?['premium'] == true;
```

## Server changes needed (separate task)
- Verify Firebase ID tokens using Admin SDK
- Add `/me` endpoint returning user profile + claims
- Gate premium endpoints behind claim check
