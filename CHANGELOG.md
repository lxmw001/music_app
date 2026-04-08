# Changelog

All notable changes to this project will be documented in this file.

## [1.5.0] - 2026-04-07

### Added
- **AI-powered suggestions** via Gemini API (cached locally, falls back to regex without key)
  - Detects artist, genre, and mix vs individual song from YouTube title
  - Returns 5 genre-based search queries for variety
  - Individual song: seeds queue with artist best songs → YouTube algorithm → genre queries
  - Mix: uses genre/style queries randomly without repeats
- **Queue persistence** — full queue saved and restored on app restart
- **Unliked songs tracking** — songs skipped after >5s recorded for future filtering
- **Search history** saved locally (last 50 queries)
- **Per-song loading spinner** on search and trending cards
- **Spotify-style queue bottom sheet** — draggable, live-updating, auto-scrolls to current song
- **Deduplication** of search results — keeps cleanest `Artist - Song` title per unique song
- **Title cleaning** — removes noise like `(Official Video)`, `[HD]`, `| Channel` from all results
- **Artist extraction** from `Artist - Song` title pattern for better metadata
- **Next button pre-fetch** — next song's audio URL fetched in background while current plays
- **Suggested songs** seeded immediately on tap before audio URL fetch

### Fixed
- `MusicPlayerProvider` constructor missing — `AudioService.init` never called
- Queue seeding blocked by `_isSeeding` flag across different user taps
- Bottom sheet not updating live when suggestions loaded
- `nextSong` skipping queued songs and going straight to suggestions
- Mini player not showing on first tap (now shows immediately)
- Provider type registration causing "could not find provider" error

### Changed
- `IndexedStack` preserves screen state when switching tabs
- Gemini model switched to `gemini-2.5-flash`
- API keys read from `--dart-define` env vars (never hardcoded)
- `SongListTile` always starts fresh queue on tap for proper suggestion seeding

## [1.4.0] - 2026-03-28

### Added
- Play history with smart like threshold (≥50% for short songs, ≥3min for mixes ≥6min)
- Last played song restored in mini player on app restart
- Playback position saved every 15 seconds, restored on next launch
- Audio URL pre-fetched on app start for instant resume
- Auto-play next song when current song completes
- Auto-suggest next song when queue ends (pre-fetched in background)
- Next song pre-fetched while current song plays to reduce lag
- Notification next/prev buttons wired to provider via callbacks
- Per-song loading spinner on search and trending cards
- Loading spinner on player screen album art while fetching audio
- Next button disabled in player and notification while loading
- "Suggested for You" section on home screen based on play history
- `IndexedStack` to preserve screen state when switching tabs

### Fixed
- `MusicPlayerProvider` abstract class — `MusicPlayerProviderImpl` missing constructor (AudioService never initialized)
- Provider type registration causing "could not find provider" error
- `setQueue` crash with empty audio URLs
- Mini player not showing immediately on song tap
- YouTube rate limiting from bulk pre-fetch — now fetches on demand
- Tap not reaching provider due to `Consumer` inside `ListView.builder`
- Notification next button causing `addStream` conflict
- Trending spinner always shown on first song
- 403 expired stream URL on restored song — always fetches fresh URL
- Seek to restored position before `play()` so resume starts at correct time

### Changed
- Audio quality set to lowest bitrate for faster loading
- Search results increased from 5 to 20
- Trending results increased from 2 to 20
- `MusicPlayerProvider` refactored as abstract class for testability

## [1.3.0] - 2026-03-27

### Added
- Unit tests for `YouTubeService` (14 tests) covering search, audio URL, trending, playlist, connectivity, and suggestions
- Unit tests for `AudioPlayerHandler` (11 tests) covering all playback controls and streams

### Changed
- Refactored `YouTubeService` to use a `YoutubeGateway` abstraction for dependency injection
- Refactored `AudioPlayerHandler` to accept an injected `AudioPlayer` instance

### Technical
- Added `mockito` and `build_runner` dev dependencies
- Generated mock files for service tests

## [1.2.0] - 2025-12-31

### Added
- **Media Notification Controls**
  - Play/pause from notification panel
  - Skip to next/previous track from notifications
  - Media session integration with system
  - Background playback support
  - Lock screen controls

### Changed
- **Audio Engine**
  - Replaced audioplayers with just_audio for better notification support
  - Added audio_service for system media controls
  - Enhanced playback state management

### Technical
- Added audio_service package
- Added just_audio package
- Android manifest permissions for foreground service
- Media button receiver configuration

## [1.1.0] - 2025-12-31

### Added
- **YouTube Integration**
  - YouTube music streaming as primary source
  - Real-time search from YouTube catalog
  - Trending music from YouTube
  - High-quality audio stream extraction
  - YouTube thumbnail integration

### Changed
- **Search Functionality**
  - Live YouTube search with real results
  - Genre browsing triggers YouTube searches
  - Search results display actual YouTube videos

- **Home Screen**
  - Trending music section now pulls from YouTube
  - Real YouTube thumbnails and metadata
  - Loading states for async operations

### Technical
- Added youtube_explode_dart package
- Added dio package for HTTP requests
- YouTube service layer implementation
- Error handling for network requests

## [1.0.0] - 2025-12-31

### Added
- **Music Playback Engine**
  - Play, pause, resume, and stop functionality
  - Seek to specific position in track
  - Audio streaming from URLs

- **Queue Management**
  - Song queue with current track tracking
  - Next/previous track navigation
  - Shuffle mode toggle
  - Repeat mode toggle

- **User Interface**
  - Home screen with featured content and recently played
  - Search screen with genre browsing
  - Library screen with playlists and filters
  - Full-screen player with album art and controls
  - Mini player bar for continuous playback during navigation

- **Navigation**
  - Bottom navigation bar (Home, Search, Library)
  - Screen transitions and routing
  - Player screen modal presentation

- **State Management**
  - Provider pattern implementation
  - Real-time playback state updates
  - Position and duration tracking

- **Data Models**
  - Song, Playlist, and Album data structures
  - JSON serialization support

- **Audio Features**
  - Progress slider with seek functionality
  - Duration formatting and display
  - Playback controls (play/pause/skip/previous)

### Technical
- Flutter framework setup
- AudioPlayers package integration
- Provider state management
- Network image caching
- Material Design theming
