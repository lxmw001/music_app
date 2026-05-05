# Music App - Dev Session Context

## Project
- Flutter music streaming app at `/Users/luis/Projects/personal/music_app`
- Server: `https://music-app-server-lupbg4y2ha-uc.a.run.app`
- Server repo: `/Users/luis/Projects/personal/music_app_server`
- Package: `com.lxmw.musicapp`
- Git: `git@github-lx:lxmw001/music_app.git` (branches: `main`, `develop`)
- Flutter: `/Users/luis/Projects/personal/flutter/bin/flutter`
- Physical device: `adb-f6cae4c7-1xygO9._adb-tls-connect._tcp` (Xiaomi Poco F7 Ultra)

## Architecture
- **State**: Provider pattern (`MusicPlayerProviderImpl`, `AuthProvider`)
- **Audio**: `just_audio` + `audio_service` + `AudioPlayerHandler`
- **YouTube**: `youtube_explode_dart` via `YoutubeExplodeGateway`
- **Server**: `MusicServerService` + `ApiService` (Firebase token auth)
- **Auth**: Firebase Auth + Google Sign-In → `AuthProvider`

## Key Services
- `YouTubeService` — search, trending, playlist generation, audio URL resolution
- `MusicServerService` — server search/trending/playlist/stream URL cache
- `ApiService` — authenticated HTTP client with Firebase token injection
- `DownloadService` — local downloads to `documents/downloads/`
- `AudioCacheService` — temp audio cache
- `LastFmService` — artist tags (cached in SharedPreferences for offline)
- `PlayHistoryService` — liked songs, play history, queue persistence

## Server API (key endpoints)
- `GET /songs/search-youtube?query=` → `MusicSearchResult` (songs, mixes, videos, artists)
- `GET /songs/trending?limit=` → songs + mixes
- `GET /songs/:id/generate-playlist?limit=30&search=` → playlist songs
- `GET /songs/searches` → popular search suggestions
- `POST /songs/:id/stream-url` → cache stream URL (songs)
- `POST /songs/mixes/:youtubeId/stream-url` → cache stream URL (mixes)
- `GET /users/me/liked-songs`, `POST/DELETE /users/me/liked-songs/:id`
- `GET /users/me/downloads`, `POST/DELETE /users/me/downloads/:id`
- `GET /users/me/playlists`, CRUD operations

## Song Model Fields
```dart
id: String          // YouTube video ID
serverId: String    // Firestore document ID
title, artist, album, imageUrl
audioUrl: String    // mutable - local path or stream URL
duration: Duration
genres: List<String>
streamUrl: String?  // server-cached stream URL
streamUrlExpiresAt: DateTime?
```

## Auth & Permissions
- Firebase project: `music-app-e8267`
- Google Sign-In enabled
- Permissions from Firebase custom claims: `offline_play`, `suggest_playlists`
- Cached in SharedPreferences, refreshed on app start when online
- `auth.canDownload` → gates download button
- `auth.hasSuggestedPlaylists` → reserved for future use

## Audio URL Resolution Order (getPlayableAudioPath)
1. Permanent downloads (`documents/downloads/`)
2. In-memory `song.streamUrl` (valid, not expired)
3. Persisted stream URL cache (`StreamUrlCache`)
4. Server `GET /songs/:id/stream-url`
5. Direct YouTube via `youtube_explode_dart` → then pushes to server

## YouTube Client Strategy
- Sequential: `ios` → `tv` → `androidVr` → `safari`
- Prefers AAC/MP4 streams, falls back to Opus/WebM
- Stops on `RequestLimitExceededException`, refreshes `YoutubeExplode` instance
- 8s timeout per client

## Playback Flow
- `playSong(song)` — user tap → resets queue to `[song]`, fires `generatePlaylist` in background
- `playSong(song, fromQueue: true)` — next/prev/queue tap → navigates within existing queue
- `playSong(song, queue: [...])` — explicit queue (playlists) → sets queue directly, no `generatePlaylist`
- `nextSong()` → advances index → if end of queue → `_fetchAndPlaySuggestion()`
- Completion detection: `processingState == completed` + `_lastPosition >= 5s` + within last 20s of duration

## Known Issues / Pending
- Downloaded songs being skipped due to stall recovery clearing `audioUrl` (partially fixed)
- `getSuggestedSongs` called even when queue has more items (index tracking bug)
- `suggest_playlists` permission not yet used
- Server user settings (theme, language, quality) endpoint not yet implemented

## Pending Tasks (todo_list)
1. Gate download button behind `offline_play` permission ✓ (done)
2. Sync `downloadSong` to `POST /users/me/downloads/:serverId`
3. Sync `deleteDownload` to `DELETE /users/me/downloads/:serverId`

## CI/CD
- CI: `.github/workflows/ci.yml` — Flutter 3.29.3, runs tests
- CD: `.github/workflows/cd.yml` — Flutter 3.29.3, builds release APK, creates GitHub release
- ProGuard: `android/app/proguard-rules.pro` — keeps Flutter, ExoPlayer, audio_service, Firebase
- `minSdk = 23` (required by firebase-auth)
- No google-services Gradle plugin (uses `DefaultFirebaseOptions` directly)
- `google-services.json` in `android/app/`

## Android Config
- `MainActivity` extends `AudioServiceActivity`
- `WidgetsFlutterBinding.ensureInitialized()` before `Firebase.initializeApp()`
- `JustAudioMediaKit` removed (caused `setAndroidAudioAttributes` unimplemented error)

## Search UI
- Empty state: popular search chips (top 5) + genre grid with gradients
- Results: chip filters (Songs/Mixes/Videos/Artists) + top 3 per section + "See all"
- Autocomplete: uses server `GET /songs/searches`, scores by prefix/substring/word overlap
- System back button: clears results, returns to empty state

## Recent Issues Fixed
- `double.infinity.toInt()` crash in playSong
- Duplicate `dart:async` import
- `just_audio_media_kit` removed (unimplemented error)
- Stall recovery clearing local file paths for downloaded songs
- Skip cascade: stall timer not cancelled on audio fail
- Bluetooth metadata not updating (added `durationStream` listener)
- Early `completed` event: added 20s nearEnd guard
- `RequestLimitExceededException` from background YouTube calls on downloaded songs
