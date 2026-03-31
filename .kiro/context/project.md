# music_app — Project Context

## What this is
A Flutter mobile app that streams music from YouTube. Uses `youtube_explode_dart` for search/streaming, `audio_service` + `just_audio` for playback, and `provider` for state management.

## Key architecture
- `MusicPlayerProvider` (abstract) / `MusicPlayerProviderImpl` — playback state, queue, history
- `YouTubeService` + `YoutubeGateway` abstraction — search, audio URL fetch, suggestions
- `AudioPlayerHandler` — wraps `just_audio`, bridges to `audio_service` notifications
- `PlayHistoryService` — persists play history + last song/position to `shared_preferences`

## Important behaviors
- Audio URLs are fetched lazily (on tap), never persisted (they expire with 403)
- Next song always plays a YouTube suggestion, not the next in queue
- Position saved every 15s; restored on app restart with a fresh URL fetch
- Like threshold: ≥50% for short songs, ≥3min for mixes (≥6min duration)
- `IndexedStack` keeps all screens alive — no reload on tab switch

## Running tests
```bash
# Unit tests
flutter test test/services/

# Integration tests (fake, emulator)
flutter test integration_test/app_test.dart -d emulator-5554

# Real network tests (emulator, needs internet)
flutter test integration_test/youtube_service_real_test.dart -d emulator-5554
```

## Flutter/emulator
```bash
# Flutter binary
/Users/luis/Projects/personal/flutter/bin/flutter

# Start emulator
/Users/luis/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_36.1
```

## Session
To resume the full chat history:
```
/chat load music_app_session.json
```
