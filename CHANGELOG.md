# Changelog

All notable changes to this project will be documented in this file.

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
