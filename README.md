## Music Streaming App

A Flutter mobile application with YouTube as the music source, featuring:

### Features Implemented:
- **YouTube Integration**: Stream music directly from YouTube
- **Real-time Search**: Search YouTube's music catalog
- **Trending Music**: Display trending music from YouTube
- **Music Playback**: Play, pause, skip, seek functionality
- **Queue Management**: Song queue with next/previous controls
- **Home Screen**: YouTube trending content and recently played
- **Search**: Live YouTube search with genre browsing
- **Library**: Personal playlists and saved music
- **Player Interface**: Full-screen player with controls
- **Mini Player**: Bottom player bar for navigation
- **Shuffle & Repeat**: Playback modes
- **State Management**: Provider pattern for app state

### Key Components:
- YouTube music streaming using `youtube_explode_dart`
- Audio playback using `audioplayers` package
- Network image caching with YouTube thumbnails
- Responsive UI with Material Design
- Navigation between screens
- Real-time playback controls

### Setup:
1. Run `flutter pub get` to install dependencies
2. Ensure internet connection for YouTube streaming
3. Add proper network permissions for Android/iOS
4. Test on device for audio playback

### API Keys:
Keys are injected at build/run time via `--dart-define` (never hardcoded):

```bash
# Run with keys
flutter run \
  --dart-define=GEMINI_API_KEY=your_gemini_key

# Build with keys
flutter build apk \
  --dart-define=GEMINI_API_KEY=your_gemini_key
```

- **Gemini API key**: Get free key at [aistudio.google.com](https://aistudio.google.com) — used for AI-powered artist extraction to improve song suggestions. App works without it (falls back to regex).

### Next Steps:
- Add user authentication
- Implement offline downloads
- Add social features (sharing, following)
- Enhance search with filters
- Add lyrics display
- Create custom playlists

### Testing:
- **Unit tests**: `flutter test test/services/`
- **Integration tests (fake)**: `flutter test integration_test/app_test.dart -d <device>`
- **Integration tests (real network)**: `flutter test integration_test/youtube_service_real_test.dart -d <device>`

### Dev Session:
A saved Kiro CLI chat session is available at `music_app_session.json`. To resume:
```bash
# From inside the project directory, start a chat and run:
/chat load music_app_session.json
```
