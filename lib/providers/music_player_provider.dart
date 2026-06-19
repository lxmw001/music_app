import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import '../models/user_profile.dart';
import '../models/vibe.dart';
import '../services/audio_handler.dart';
import '../services/youtube_service.dart';
import '../services/play_history_service.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart' show YouTubeService, YouTubeRateLimitException;
import '../services/music_server_service.dart';
import '../services/profile_service.dart';
import '../utils/logger.dart';
import '../services/error_reporting_service.dart';
import 'auth_provider.dart';
import 'theme_provider.dart';

abstract class MusicPlayerProvider extends ChangeNotifier {
  Song? get currentSong;
  List<Song> get queue;
  int get currentIndex;
  bool get isShuffled;
  bool get isRepeating;
  bool get isInitialized;
  bool get autoAddSuggestions;
  bool get isFetchingSuggestions;
  bool get isFetchingVibe;
  bool get isFastModeActive;
  String? get activeVibeId;
  String? get activeSubCategoryId;
  ({String vibeId, String? subCategoryId})? get lastSavedVibe;
  List<Song> get suggestedSongs;
  Color? get dominantColor;
  UserProfile? get userProfile;
  List<Vibe> get vibes;
  bool get isTransitioning;
  bool isLoadingAudio(String songId);
  void prefetchAudioUrls(List<Song> songs);
  bool get isPlaying;
  Duration get currentPosition;
  Duration get totalDuration;
  Stream<Duration> get positionStream;

  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo, bool fromQueue = false, String? searchQuery});
  Future<void> playFastMode({required String vibeId, String? subCategoryId});
  Future<void> resumeLastVibe();
  void exitFastMode();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  void nextSong();
  void previousSong();
  void toggleShuffle();
  void toggleRepeat();
  void toggleAutoAddSuggestions();
  Future<void> fetchSuggestions();
  void addSuggestedToQueue(Song song);
  void reorderQueue(int oldIndex, int newIndex);
  void clearSuggestions();
  Future<List<Song>> getMostLikedFromHistory();
  Future<List<Song>> getRecentSongs();
  Future<bool> isLiked(String songId);
  Future<void> toggleLike(Song song);
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs);
  Future<void> saveSearch(String query);
  Future<void> deleteSearch(String query);
  Future<List<String>> getSearchHistory();
  Future<void> clearSearchHistory();
  Future<List<Playlist>> loadPlaylists();
  Future<void> deletePlaylist(String id);
  Future<void> refreshVibes();
  String? get errorMessage;
  void clearError();
}

class MusicPlayerProviderImpl extends MusicPlayerProvider {
  late AudioPlayerHandler _audioHandler;
  final YouTubeService _youtubeService = YouTubeService();
  final PlayHistoryService _historyService = PlayHistoryService();
  final DownloadService _downloadService = DownloadService();
  final MusicServerService _serverService = MusicServerService();
  final ProfileService _profileService = ProfileService();

  YouTubeService get youtubeService => _youtubeService;

  Timer? _notifyTimer;
  static const _notifyInterval = Duration(milliseconds: 250);

  @override
  void notifyListeners() {
    if (_notifyTimer?.isActive ?? false) return;
    super.notifyListeners();
    _notifyTimer = Timer(_notifyInterval, () {});
  }

  AuthProvider? _authProvider;
  ThemeProvider? _themeProvider;
  
  void setAuthProvider(AuthProvider auth) => _authProvider = auth;
  void setThemeProvider(ThemeProvider theme) => _themeProvider = theme;

  VoidCallback? _onRateLimit;
  void setOnRateLimit(VoidCallback cb) => _onRateLimit = cb;
  bool _isRateLimited = false;
  bool _isSwitchingSong = false;
  bool _isTransitioning = false;

  Timer? _positionSaveTimer;
  Timer? _stallTimer;
  bool _isRecoveringFromStall = false;
  Duration _lastRestoredPosition = Duration.zero;
  Duration _lastPosition = Duration.zero;
  
  Song? _currentSong;
  
  List<Song> _normalQueue = [];
  int _normalIndex = 0;
  List<Song> _vibeQueue = [];
  int _vibeIndex = 0;
  final Set<String> _vibePlayedIds = {};

  bool _isShuffled = false;
  bool _isRepeating = false;
  bool _isInitialized = false;
  bool _autoAddSuggestions = true;
  final Set<String> _loadingAudioIds = {};
  Color? _dominantColor;

  bool _isFetchingSuggestions = false;
  bool _isFetchingVibe = false;
  bool _isFastModeActive = false;
  String? _activeVibeId;
  String? _activeSubCategoryId;
  ({String vibeId, String? subCategoryId})? _lastSavedVibe;
  List<Song> _suggestedSongs = [];
  UserProfile? _userProfile;
  List<Vibe> _vibes = availableVibes;

  Song? _pendingSong;
  List<Song>? _pendingQueue;

  @override
  String? get errorMessage => _errorMessage;
  @override
  void clearError() { _errorMessage = null; notifyListeners(); }

  @override
  Color? get dominantColor => _dominantColor;

  @override
  bool isLoadingAudio(String songId) => _loadingAudioIds.contains(songId);
  @override
  bool get isTransitioning => _isTransitioning;
  @override
  bool get isFetchingSuggestions => _isFetchingSuggestions;
  @override
  bool get isFetchingVibe => _isFetchingVibe;
  @override
  bool get isFastModeActive => _isFastModeActive;
  @override
  String? get activeVibeId => _activeVibeId;
  @override
  String? get activeSubCategoryId => _activeSubCategoryId;
  @override
  ({String vibeId, String? subCategoryId})? get lastSavedVibe => _lastSavedVibe;
  @override
  List<Song> get suggestedSongs => _suggestedSongs;
  @override
  UserProfile? get userProfile => _userProfile;
  @override
  List<Vibe> get vibes => _vibes;

  @override
  Song? get currentSong => _currentSong;
  @override
  List<Song> get queue => _isFastModeActive ? _vibeQueue : _normalQueue;
  @override
  int get currentIndex => _isFastModeActive ? _vibeIndex : _normalIndex;
  @override
  bool get isShuffled => _isShuffled;
  @override
  bool get isRepeating => _isRepeating;
  @override
  bool get isInitialized => _isInitialized;
  @override
  bool get autoAddSuggestions => _autoAddSuggestions;

  @override
  bool get isPlaying => _isInitialized ? _audioHandler.playbackState.value.playing : false;
  @override
  Duration get currentPosition => _isInitialized ? _audioHandler.currentPosition : Duration.zero;
  @override
  Duration get totalDuration => _isInitialized ? _audioHandler.duration : Duration.zero;
  @override
  Stream<Duration> get positionStream => _isInitialized ? _audioHandler.positionStream : const Stream.empty();

  MusicPlayerProviderImpl() {
    _init();
  }

  Future<void> _init() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(
          onSkipToNext: () => nextSong(),
          onSkipToPrevious: () => previousSong(),
          onPlay: () => resume(),
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.lxmw.musicapp.channel.audio',
          androidNotificationChannelName: 'Music Player',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: true,
        ),
      );

      final savedNormal = await _historyService.loadQueue();
      final savedVibeQueue = await _historyService.loadVibeQueue();
      _userProfile = await _profileService.getProfile();
      _lastSavedVibe = await _historyService.loadVibeState();
      refreshVibes();

      _isInitialized = true;
      
      _audioHandler.positionStream.listen((position) {
        if (!_isSwitchingSong && position > Duration.zero) _lastPosition = position;
        if (_currentSong != null && _autoAddSuggestions) {
          final duration = totalDuration;
          final currentQueue = queue;
          final index = currentIndex;
          final queueHasMore = index < currentQueue.length - 1;
          if (duration.inSeconds > 0 &&
              (duration - position).inSeconds <= 10 &&
              !_isFetchingSuggestions &&
              _suggestedSongs.isEmpty &&
              !queueHasMore) {
            _fetchSuggestionsInBackground();
          }
        }
        // Fallback: detect end-of-song via position when completed state is not emitted
        if (!_isSwitchingSong && !_isTransitioning && _currentSong != null) {
          final duration = totalDuration;
          if (duration.inSeconds > 0 && position.inSeconds >= duration.inSeconds && _currentSong?.id != _lastCompletedSongId) {
            _lastCompletedSongId = _currentSong?.id;
            _historyService.recordPlay(_currentSong!, position.inSeconds);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_currentSong?.id == _lastCompletedSongId) nextSong();
            });
          }
        }
      });

      _audioHandler.durationStream.listen((duration) {
        if (duration != null && duration > Duration.zero && _currentSong != null) {
          final current = _audioHandler.mediaItem.value;
          if (current != null && (current.duration == null || current.duration == Duration.zero)) {
            _audioHandler.mediaItem.add(current.copyWith(duration: duration));
            // Force playbackState update so Bluetooth refreshes metadata
            _audioHandler.playbackState.add(_audioHandler.playbackState.value.copyWith(
              updatePosition: _audioHandler.currentPosition,
            ));
          }
          notifyListeners();
        }
      });

      _audioHandler.playbackState.listen((state) {
        if (state.processingState == AudioProcessingState.completed && !_isSwitchingSong && !_isTransitioning) {
          final completedSongId = _currentSong?.id;
          if (completedSongId == _lastCompletedSongId) return; 
          final duration = totalDuration;
          final played = _lastPosition.inSeconds;
          final wasPlaying = played >= 10;
          final nearEnd = duration.inSeconds > 0
              ? played >= (duration.inSeconds - 15) || played >= (duration.inSeconds * 0.8)
              : played >= 20;
          if (completedSongId != null && wasPlaying && nearEnd) {
            _lastCompletedSongId = completedSongId;
            _historyService.recordPlay(_currentSong!, _lastPosition.inSeconds);
            _markPendingPlaylistLiked(_currentSong!, _lastPosition.inSeconds);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_currentSong?.id != completedSongId) return;
              if (_isRateLimited) {
                _isRateLimited = false;
                _onRateLimit?.call();
                _playOfflineByGenre(_currentSong!).then((_) {
                  if (_currentSong?.id == completedSongId && !isPlaying) {
                    _audioHandler.seek(Duration.zero);
                    notifyListeners();
                  }
                });
              } else {
                nextSong();
              }
            });
          }
        }

        if (state.processingState == AudioProcessingState.buffering && state.playing && !_isRecoveringFromStall && _loadingAudioIds.isEmpty) {
          _stallTimer ??= Timer(const Duration(seconds: 30), () {
            final posNow = currentPosition.inSeconds;
            if (posNow <= _lastPosition.inSeconds + 2) {
              _handleStall();
            } else {
              _stallTimer = null;
            }
          });
        } else {
          _stallTimer?.cancel();
          _stallTimer = null;
        }

        notifyListeners();
      });

      if (savedNormal != null) {
        _normalQueue = savedNormal.queue;
        _normalIndex = savedNormal.currentIndex;
        final songId = _normalQueue[_normalIndex].id;
        final pos = await _historyService.getLastPosition(songId);
        if (pos > 0) _lastRestoredPosition = Duration(seconds: pos);
      }
      if (savedVibeQueue != null) {
        _vibeQueue = savedVibeQueue.queue;
        _vibeIndex = savedVibeQueue.currentIndex;
      }

      if (_pendingSong != null) {
        final song = _pendingSong!;
        final q = _pendingQueue;
        _pendingSong = null;
        _pendingQueue = null;
        await playSong(song, queue: q);
      } else {
        _isFastModeActive = false;
        if (_normalQueue.isNotEmpty) {
          _currentSong = _normalQueue[_normalIndex];
          _updateDominantColor(_currentSong?.imageUrl);
        }
      }
      
      _updateAudioHandlerQueue();
      notifyListeners();
      Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    } catch (e, st) {
      rlog('[MusicPlayerProvider] _init ERROR: $e\n$st');
    }
  }

  Song? _songBeforeOffline;
  Duration _positionBeforeOffline = Duration.zero;
  List<Song>? _queueBeforeOffline;
  int _indexBeforeOffline = 0;
  bool _isOfflineMode = false;

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasInternet = results.any((c) =>
        c == ConnectivityResult.wifi || c == ConnectivityResult.mobile);

    if (!hasInternet && !_isOfflineMode) {
      _isOfflineMode = true;
      if (_currentSong != null && !(_currentSong!.audioUrl.startsWith('/') || _currentSong!.audioUrl.startsWith('file://'))) {
        _songBeforeOffline = _currentSong;
        _queueBeforeOffline = List.from(_normalQueue);
        _indexBeforeOffline = _normalIndex;
        // Wait for buffered audio to finish before switching to offline
        final buffered = _audioHandler.playbackState.value.bufferedPosition;
        final pos = currentPosition;
        final remaining = buffered - pos;
        final delay = remaining > const Duration(seconds: 2) ? remaining - const Duration(seconds: 1) : Duration.zero;
        rlog('[MusicPlayerProvider] internet lost, buffered ${remaining.inSeconds}s ahead, switching in ${delay.inSeconds}s');
        Future.delayed(delay, () {
          if (_isOfflineMode && _songBeforeOffline != null) {
            _positionBeforeOffline = currentPosition;
            _playOfflineByGenre(_songBeforeOffline!);
          }
        });
      }
    } else if (hasInternet && _isOfflineMode) {
      _isOfflineMode = false;
      if (_songBeforeOffline != null) {
        rlog('[MusicPlayerProvider] internet back, resuming ${_songBeforeOffline!.title}');
        final song = _songBeforeOffline!;
        final pos = _positionBeforeOffline;
        _songBeforeOffline = null;
        _positionBeforeOffline = Duration.zero;
        // Restore original queue
        if (_queueBeforeOffline != null) {
          _normalQueue = _queueBeforeOffline!;
          _normalIndex = _indexBeforeOffline;
          _queueBeforeOffline = null;
        }
        song.audioUrl = ''; // force re-fetch
        playSong(song, seekTo: pos, fromQueue: true);
      }
    }
  }

  @override
  Future<void> refreshVibes() async {
    try {
      final serverVibes = await _serverService.getVibes();
      if (serverVibes.isNotEmpty) {
        _vibes = serverVibes;
        notifyListeners();
      }
    } catch (e) {
      rlog('[MusicPlayerProvider] refreshVibes error: $e');
    }
  }

  Future<void> _updateDominantColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100),
      );
      
      final color = generator.vibrantColor?.color ?? 
                    generator.lightVibrantColor?.color ?? 
                    generator.dominantColor?.color;

      _dominantColor = color;
      if (_dominantColor != null && _themeProvider != null) {
        _themeProvider!.updateAdaptiveColor(_dominantColor!);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _handleStall() async {
    final song = _currentSong;
    if (song == null || _isRecoveringFromStall) return;
    _isRecoveringFromStall = true;
    _stallTimer?.cancel();
    _stallTimer = null;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = connectivity.any((c) =>
          c == ConnectivityResult.wifi || c == ConnectivityResult.mobile);

      if (!hasInternet) {
        await _playOfflineByGenre(song);
        return;
      }

      final position = currentPosition;
      if (!song.audioUrl.startsWith('/') && !song.audioUrl.startsWith('file://')) {
        song.audioUrl = '';
      }
      await playSong(song, seekTo: position);
    } catch (e) {
      rlog('[MusicPlayerProvider] stall recovery failed: $e');
    } finally {
      _isRecoveringFromStall = false;
    }
  }

  Future<void> _playOfflineByGenre(Song stalledSong) async {
    final downloaded = await _downloadService.getDownloadedSongs();
    if (downloaded.isEmpty) return;

    final downloadedIds = downloaded.map((s) => s.id).toSet();
    final playlists = await _historyService.loadPlaylists();

    final offlineQueue = <Song>[];
    final seen = <String>{};
    for (final pl in playlists) {
      int count = 0;
      for (final s in pl.songs) {
        if (count >= 10) break;
        if (downloadedIds.contains(s.id) && !seen.contains(s.id) && s.id != stalledSong.id) {
          seen.add(s.id);
          offlineQueue.add(s);
          count++;
        }
      }
    }
    for (final s in downloaded) {
      if (!seen.contains(s.id) && s.id != stalledSong.id) {
        offlineQueue.add(s);
      }
    }

    if (offlineQueue.isEmpty) return;
    offlineQueue.shuffle();
    Future.microtask(() => playSong(offlineQueue.first, queue: offlineQueue));
  }

  Future<void> _handleStreamUrlFailure(Song song, {bool fromQueue = false}) async {
    if (_isHandlingStreamFailure) return;
    _isHandlingStreamFailure = true;

    _consecutiveFailures++;
    if (_consecutiveFailures > 3) {
      _consecutiveFailures = 0;
      _isHandlingStreamFailure = false;
      return;
    }

    try {
      _removeFromQueue(song);
      await _youtubeService.clearStreamUrlCache(song.id);
    } finally {
      _isHandlingStreamFailure = false;
    }

    if (!fromQueue) {
      _errorMessage = 'Could not play "${song.title}"';
      notifyListeners();
      return;
    }

    _fetchAlternative(song);

    Future.microtask(() {
      final currentQueue = queue;
      final index = currentIndex;
      if (currentQueue.isNotEmpty && index < currentQueue.length) {
        playSong(currentQueue[index], fromQueue: true);
      } else {
        nextSong();
      }
    });
  }

  void _removeFromQueue(Song song) {
    if (_isFastModeActive) {
      _vibeQueue.removeWhere((s) => s.id == song.id);
      if (_vibeIndex >= _vibeQueue.length) _vibeIndex = _vibeQueue.isEmpty ? 0 : _vibeQueue.length - 1;
    } else {
      _normalQueue.removeWhere((s) => s.id == song.id);
      if (_normalIndex >= _normalQueue.length) _normalIndex = _normalQueue.isEmpty ? 0 : _normalQueue.length - 1;
    }
    _updateAudioHandlerQueue();
    notifyListeners();
  }

  Future<void> _fetchAlternative(Song failedSong) async {
    try {
      final id = failedSong.serverId.isNotEmpty ? failedSong.serverId : failedSong.id;
      var alternative = await _serverService.findAlternative(id);
      if (alternative == null) return;
      if (alternative.id.isEmpty && alternative.serverId.isNotEmpty) {
        alternative = alternative.copyWith(id: alternative.serverId);
      }

      final currentQueue = _isFastModeActive ? _vibeQueue : _normalQueue;

      final existingIdx = currentQueue.indexWhere((s) => s.serverId.isNotEmpty && s.serverId == alternative!.serverId);
      if (existingIdx >= 0) {
        await _youtubeService.clearStreamUrlCache(currentQueue[existingIdx].id);
        currentQueue[existingIdx] = alternative;
        if (_isFastModeActive) {
          _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
        } else {
          _historyService.saveQueue(_normalQueue, _normalIndex);
        }
        _updateAudioHandlerQueue();
        notifyListeners();
      } else {
        final insertIndex = currentIndex + 1;
        if (insertIndex <= currentQueue.length) {
          if (_isFastModeActive) {
            _vibeQueue.insert(insertIndex, alternative);
            _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
          } else {
            _normalQueue.insert(insertIndex, alternative);
            _historyService.saveQueue(_normalQueue, _normalIndex);
          }
          _updateAudioHandlerQueue();
          notifyListeners();
        }
      }

      if (alternative.serverId.isNotEmpty) {
        await _historyService.updatePlaylistSong(alternative.serverId, alternative.id, alternative.audioUrl);
      }
    } catch (e) {
      rlog('[MusicPlayerProvider] fetchAlternative error: $e');
    }
  }

  @override
  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo, bool fromQueue = false, String? searchQuery}) async {
    if (!_isInitialized) {
      _pendingSong = song;
      _pendingQueue = queue;
      _currentSong = song;
      if (queue != null) {
        _normalQueue = queue;
        _normalIndex = queue.indexOf(song);
      }
      notifyListeners();
      return;
    }
    
    final isCompleted = _audioHandler.playbackState.value.processingState == AudioProcessingState.completed;
    if (_currentSong?.id == song.id && isPlaying && !isCompleted) return;

    final previousSong = _currentSong;
    final previousPosition = currentPosition.inSeconds;
    _lastPosition = Duration.zero;
    if (previousSong != null && previousPosition > 0) {
      _historyService.recordPlay(previousSong, previousPosition);
      _markPendingPlaylistLiked(previousSong, previousPosition);
    }
    
    _isTransitioning = true;
    notifyListeners();

    _currentPlayRequestId = song.id;

    if (fromQueue) {
      if (_isFastModeActive) {
        if (queue != null) _vibeQueue = queue;
        _vibeIndex = _vibeQueue.indexWhere((s) => s.id == song.id);
        if (_vibeIndex < 0) _vibeIndex = 0;
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
      } else {
        if (queue != null) _normalQueue = queue;
        _normalIndex = _normalQueue.indexWhere((s) => s.id == song.id);
        if (_normalIndex < 0) _normalIndex = 0;
        _historyService.saveQueue(_normalQueue, _normalIndex);
      }
    } else {
      if (_isFastModeActive) {
        _isFastModeActive = false;
        _activeVibeId = null;
        _activeSubCategoryId = null;
        _lastSavedVibe = null;
        _historyService.clearVibeState();
      }

      if (queue != null) {
        _normalQueue = queue;
        _normalIndex = _normalQueue.indexWhere((s) => s.id == song.id);
        if (_normalIndex < 0) _normalIndex = 0;
      } else {
        _pendingPlaylistName = null;
        _pendingPlaylistSongs = null;
        _pendingPlaylistLikedCount = 0;
        _normalQueue = [song];
        _normalIndex = 0;
        _isSeeding = false;
        _pendingSeedQueries = [];
        _usedSeedQueries.clear();

        Future.delayed(const Duration(seconds: 5), () {
            if (!_isFastModeActive && !_isHandlingStreamFailure && (_currentPlayRequestId == song.id || _currentSong?.id == song.id)) {
              _youtubeService.generatePlaylist(song, search: searchQuery).then((playlist) {
              if (playlist.isEmpty) return;
              if (!_isFastModeActive && _currentSong?.id == song.id) {
                _normalQueue = [song, ...playlist];
                _normalIndex = 0;
                _historyService.saveQueue(_normalQueue, _normalIndex);
                final plName = searchQuery?.isNotEmpty == true ? searchQuery! : '${song.title} Radio';
                _pendingPlaylistName = plName;
                _pendingPlaylistSongs = _normalQueue;
                _pendingPlaylistLikedCount = 0;
                _updateAudioHandlerQueue();
                notifyListeners();
              }
            });
          }
        });
      }
      _historyService.saveQueue(_normalQueue, _normalIndex);
    }
    _updateAudioHandlerQueue();
    notifyListeners();

    _suggestedSongs = [];
    String audioUrl = song.audioUrl;
    // Check local download first (instant, works offline)
    if (audioUrl.isEmpty) {
      final dlPath = await _downloadService.getDownloadedPathById(song.id);
      if (dlPath != null) {
        audioUrl = dlPath;
        song.audioUrl = dlPath;
      }
    }
    if (audioUrl.isEmpty) {
      _loadingAudioIds.add(song.id);
      _audioHandler.nextEnabled = false;
      notifyListeners();
      try {
        audioUrl = await _youtubeService.getPlayableAudioPath(song.id, serverId: song.serverId, song: song);
        song.audioUrl = audioUrl;
      } on YouTubeRateLimitException {
        _isRateLimited = true;
        _isTransitioning = false;
        _loadingAudioIds.remove(song.id);
        _audioHandler.nextEnabled = true;
        notifyListeners();
        if (!isPlaying) {
          _onRateLimit?.call();
          await _playOfflineByGenre(song);
        }
        return;
      }

      if (audioUrl.isEmpty) {
        _isTransitioning = false;
        _loadingAudioIds.remove(song.id);
        _audioHandler.nextEnabled = true;
        notifyListeners();
        await _handleStreamUrlFailure(song, fromQueue: fromQueue);
        return;
      }
    }
    
    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: song.imageUrl.isNotEmpty ? Uri.tryParse(song.imageUrl) : null,
      duration: song.duration,
    );
    _lastPosition = Duration.zero;
    _isSwitchingSong = true;
    _currentSong = song;
    _updateDominantColor(song.imageUrl);
    notifyListeners();
    try {
      await _audioHandler.setAudioSource(audioUrl, mediaItem);
      if (seekTo != null && seekTo > Duration.zero) {
        await _audioHandler.seek(seekTo);
      }
      await _audioHandler.play();
      _consecutiveFailures = 0;
      _isTransitioning = false;
      _loadingAudioIds.remove(song.id);
      _audioHandler.nextEnabled = true;
      notifyListeners();
    } catch (e) {
      _isTransitioning = false;
      _loadingAudioIds.remove(song.id);
      _audioHandler.nextEnabled = true;
      notifyListeners();
      ErrorReportingService.instance.report(
        error: e.toString(),
        action: 'play_song',
        songId: song.serverId,
        youtubeId: song.id,
      );
      await _handleStreamUrlFailure(song, fromQueue: fromQueue);
      return;
    } finally {
      _isSwitchingSong = false;
    }
    
    _historyService.savePosition(song, 0);
    _startPositionSaveTimer(song);
    notifyListeners();

    if (!audioUrl.startsWith('/') && !audioUrl.startsWith('file://')) {
      final cacheSongId = song.id;
      final cacheUrl = audioUrl;
      final dur = song.duration > Duration.zero ? song.duration : const Duration(minutes: 8);
      Future.delayed(dur + const Duration(seconds: 5), () {
        if (_currentSong?.id != cacheSongId) {
          _youtubeService.cacheAudioInBackground(cacheSongId, cacheUrl);
        }
      });
    }

    final currentQueue = this.queue;
    final index = currentIndex;
    if (index < currentQueue.length - 1) {
      final next = currentQueue[index + 1];
      if (next.audioUrl.isEmpty && !_loadingAudioIds.contains(next.id)) {
        _loadingAudioIds.add(next.id);
        _youtubeService.getPlayableAudioPath(next.id, serverId: next.serverId, song: next)
            .then((url) {
              if (url.isNotEmpty) next.audioUrl = url;
              _loadingAudioIds.remove(next.id);
            }).catchError((e) {
              _loadingAudioIds.remove(next.id);
              if (e is YouTubeRateLimitException) {
                _isRateLimited = true;
              }
            });
      }
    }
  }

  @override
  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    
    if (_isFastModeActive) {
      final song = _vibeQueue.removeAt(oldIndex);
      _vibeQueue.insert(newIndex, song);
      if (_vibeIndex == oldIndex) _vibeIndex = newIndex;
      else if (oldIndex < _vibeIndex && newIndex >= _vibeIndex) _vibeIndex--;
      else if (oldIndex > _vibeIndex && newIndex <= _vibeIndex) _vibeIndex++;
      _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
    } else {
      final song = _normalQueue.removeAt(oldIndex);
      _normalQueue.insert(newIndex, song);
      if (_normalIndex == oldIndex) _normalIndex = newIndex;
      else if (oldIndex < _normalIndex && newIndex >= _normalIndex) _normalIndex--;
      else if (oldIndex > _normalIndex && newIndex <= _normalIndex) _normalIndex++;
      _historyService.saveQueue(_normalQueue, _normalIndex);
    }
    _updateAudioHandlerQueue();
    notifyListeners();
  }

  @override
  Future<void> playFastMode({required String vibeId, String? subCategoryId}) async {
    _userProfile ??= await _profileService.getProfile();

    _activeVibeId = vibeId;
    _activeSubCategoryId = subCategoryId;
    _isFastModeActive = true;
    _lastSavedVibe = (vibeId: vibeId, subCategoryId: subCategoryId);
    _historyService.saveVibeState(vibeId, subCategoryId);

    final hasPreviousSongs = _vibeQueue.isNotEmpty;
    if (hasPreviousSongs) {
      _vibePlayedIds.clear(); 
      final song = _pickVibeSong();
      _vibeIndex = 0;
      _updateAudioHandlerQueue();
      notifyListeners();
      playSong(song, queue: List.from(_vibeQueue), fromQueue: true);
    } else {
      _isFetchingVibe = true;
      notifyListeners();
    }

    _fetchVibeInBackground(vibeId, subCategoryId, playImmediately: !hasPreviousSongs);
  }

  Song _pickVibeSong() {
    final unplayed = _vibeQueue.where((s) => !_vibePlayedIds.contains(s.id)).toList();
    if (unplayed.isEmpty) {
      _vibePlayedIds.clear();
      return (_vibeQueue.toList()..shuffle()).first;
    }
    unplayed.shuffle();
    return unplayed.first;
  }

  Future<void> _fetchVibeInBackground(String vibeId, String? subCategoryId, {bool playImmediately = false}) async {
    try {
      _isFetchingVibe = true;
      notifyListeners();
      final songs = await _serverService.fetchAIVibe(
        vibeId: vibeId,
        subCategoryId: subCategoryId,
        profile: _userProfile ?? UserProfile(favoriteGenres: ['Pop', 'Rock']),
      );
      if (songs.isNotEmpty) {
        _vibeQueue = songs;
        _vibePlayedIds.clear(); 
        _vibeIndex = 0;
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
        _updateAudioHandlerQueue();
        if (playImmediately) {
          final song = _pickVibeSong();
          notifyListeners();
          await playSong(song, queue: songs, fromQueue: true);
        }
      } else if (playImmediately) {
        _isFastModeActive = false;
        _lastSavedVibe = null;
      }
    } catch (e) {
      if (playImmediately) {
        _isFastModeActive = false;
        _lastSavedVibe = null;
      }
      rethrow;
    } finally {
      _isFetchingVibe = false;
      notifyListeners();
    }
  }

  @override
  Future<void> resumeLastVibe() async {
    final state = await _historyService.loadVibeState();
    if (state != null) {
      _lastSavedVibe = state;
      final savedQ = await _historyService.loadVibeQueue();
      if (savedQ != null) {
        _isFastModeActive = true;
        _activeVibeId = state.vibeId;
        _activeSubCategoryId = state.subCategoryId;
        _vibeQueue = savedQ.queue;
        _vibeIndex = savedQ.currentIndex;
        _updateAudioHandlerQueue();
        notifyListeners();
        final pos = await _historyService.getLastPosition(_vibeQueue[_vibeIndex].id);
        await playSong(_vibeQueue[_vibeIndex], fromQueue: true, seekTo: pos > 0 ? Duration(seconds: pos) : null);
      } else {
        await playFastMode(vibeId: state.vibeId, subCategoryId: state.subCategoryId);
      }
    }
  }

  @override
  void exitFastMode() {
    _isFastModeActive = false;
    _activeVibeId = null;
    _activeSubCategoryId = null;
    // Save current position so resume starts where we left off
    if (_currentSong != null) {
      _historyService.savePosition(_currentSong!, currentPosition.inSeconds);
    }
    _audioHandler.stop();
    if (_normalQueue.isNotEmpty) {
      _currentSong = _normalQueue[_normalIndex];
    } else {
      _currentSong = null;
    }
    _updateAudioHandlerQueue();
    notifyListeners();
  }

  bool _isSeeding = false;
  bool _isHandlingStreamFailure = false;
  int _consecutiveFailures = 0;
  String? _pendingPlaylistName;
  List<Song>? _pendingPlaylistSongs;
  int _pendingPlaylistLikedCount = 0;
  String? _errorMessage;
  String? _currentPlayRequestId;
  String? _lastCompletedSongId;

  void _addToQueue(List<Song> songs, String excludeId) {
    final currentQueue = queue;
    final existing = currentQueue.map((s) => s.id).toSet();
    final toAdd = songs.where((s) =>
      s.id != excludeId &&
      !existing.contains(s.id)
    ).toList();
    
    if (toAdd.isNotEmpty) {
      if (_isFastModeActive) {
        _vibeQueue.addAll(toAdd);
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
      } else {
        _normalQueue.addAll(toAdd);
        _historyService.saveQueue(_normalQueue, _normalIndex);
      }
      
      if (toAdd.first.audioUrl.isEmpty) {
        _youtubeService.getAudioUrl(toAdd.first.id).then((url) => toAdd.first.audioUrl = url);
      }
      _updateAudioHandlerQueue();
      notifyListeners();
    }
  }

  @override
  Future<void> pause() async {
    if (!_isInitialized) return;
    if (_currentSong != null) {
      final pos = currentPosition.inSeconds;
      _historyService.recordPlay(_currentSong!, pos);
      _historyService.savePosition(_currentSong!, pos);
    }
    await _audioHandler.pause();
  }

  @override
  Future<void> resume() async {
    if (!_isInitialized) return;
    if (_currentSong != null && !_audioHandler.playbackState.value.playing &&
        _audioHandler.playbackState.value.processingState == AudioProcessingState.idle) {
      final seekTo = _lastRestoredPosition > Duration.zero ? _lastRestoredPosition : null;
      _lastRestoredPosition = Duration.zero;
      await playSong(_currentSong!, fromQueue: true, seekTo: seekTo);
      return;
    }
    await _audioHandler.play();
  }

  @override
  Future<void> stop() async {
    if (!_isInitialized) return;
    if (_currentSong != null) {
      final pos = currentPosition.inSeconds;
      _historyService.recordPlay(_currentSong!, pos);
      _historyService.savePosition(_currentSong!, pos);
    }
    await _audioHandler.stop();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!_isInitialized) return;
    await _audioHandler.seek(position);
  }

  @override
  void nextSong() => Future.microtask(_nextSongAsync);

  Future<void> _nextSongAsync() async {
    if (!_isInitialized) return;
    final currentQueue = queue;
    var index = currentIndex;

    if (_isFastModeActive && _currentSong != null) {
      _vibePlayedIds.add(_currentSong!.id);
    }
    
    if (_isFastModeActive && _vibeQueue.isNotEmpty) {
      final song = _pickVibeSong();
      _vibePlayedIds.add(song.id);
      playSong(song, fromQueue: true);
      return;
    }

    if (currentQueue.isNotEmpty && index < currentQueue.length - 1) {
      index++;
      if (_isFastModeActive) {
        _vibeIndex = index;
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
      } else {
        _normalIndex = index;
        _historyService.saveQueue(_normalQueue, _normalIndex);
      }
      playSong(currentQueue[index], fromQueue: true);
    } else if (_suggestedSongs.isNotEmpty && currentQueue.length > 1) {
      final next = _suggestedSongs.first;
      _suggestedSongs = [];
      if (_isFastModeActive) {
        _vibeQueue.add(next);
        _vibeIndex = _vibeQueue.length - 1;
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
      } else {
        _normalQueue.add(next);
        _normalIndex = _normalQueue.length - 1;
        _historyService.saveQueue(_normalQueue, _normalIndex);
      }
      _updateAudioHandlerQueue();
      playSong(next, fromQueue: true);
    } else if (_currentSong != null) {
      _fetchAndPlaySuggestion();
    }
  }

  Future<void> _fetchAndPlaySuggestion() async {
    if (_currentSong == null || _isSeeding) return;
    if (_isRateLimited) {
      _audioHandler.pause();
      notifyListeners();
      return;
    }
    try {
      if (_pendingSeedQueries.isNotEmpty) {
        final query = _pendingSeedQueries.removeAt(0);
        if (!_usedSeedQueries.contains(query)) {
          _usedSeedQueries.add(query);
          final songs = await _youtubeService.searchByQuery(query, maxResults: 20);
          _addToQueue(songs, _currentSong!.id);
          final currentQueue = queue;
          final index = currentIndex;
          if (currentQueue.isNotEmpty && index < currentQueue.length - 1) {
            final nextIndex = index + 1;
            if (_isFastModeActive) {
              _vibeIndex = nextIndex;
            } else {
              _normalIndex = nextIndex;
            }
            playSong(currentQueue[nextIndex]);
            return;
          }
        }
      }
      final suggestions = await _youtubeService.getSuggestedSongs(_currentSong!.id, maxResults: 1, knownTitle: _currentSong!.title);
      if (suggestions.isNotEmpty) {
        if (_isFastModeActive) {
          _vibeQueue.add(suggestions.first);
          _vibeIndex = _vibeQueue.length - 1;
        } else {
          _normalQueue.add(suggestions.first);
          _normalIndex = _normalQueue.length - 1;
        }
        _updateAudioHandlerQueue();
        playSong(suggestions.first);
      }
    } on YouTubeRateLimitException {
      _isRateLimited = true;
    } catch (e) {
      rlog('[MusicPlayerProvider] fetchAndPlaySuggestion error: $e');
    }
    if (!isPlaying) {
      _audioHandler.pause();
      notifyListeners();
    }
  }

  @override
  void previousSong() {
    if (!_isInitialized) return;
    final currentQueue = queue;
    var index = currentIndex;
    
    if (currentQueue.isNotEmpty && index > 0) {
      index--;
      if (_isFastModeActive) {
        _vibeIndex = index;
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
      } else {
        _normalIndex = index;
        _historyService.saveQueue(_normalQueue, _normalIndex);
      }
      playSong(currentQueue[index], fromQueue: true);
    }
  }

  @override
  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    notifyListeners();
  }

  @override
  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    notifyListeners();
  }

  @override
  void toggleAutoAddSuggestions() {
    _autoAddSuggestions = !_autoAddSuggestions;
    notifyListeners();
  }

  Future<void> _fetchSuggestionsInBackground() async {
    if (_currentSong == null || _isFetchingSuggestions) return;
    _isFetchingSuggestions = true;
    notifyListeners();
    try {
      _suggestedSongs = await _youtubeService.getSuggestedSongs(_currentSong!.id, maxResults: 5);
    } catch (e) {
      rlog('Error fetching suggestions: $e');
    } finally {
      _isFetchingSuggestions = false;
      notifyListeners();
    }
  }
  
  @override
  void prefetchAudioUrls(List<Song> songs) {
    for (final song in songs) {
      if (song.id == _currentSong?.id) continue;
      if (song.audioUrl.isEmpty && !_loadingAudioIds.contains(song.id)) {
        _loadingAudioIds.add(song.id);
        _youtubeService.getPlayableAudioPath(song.id, serverId: song.serverId, song: song).then((url) {
          if (url.isNotEmpty) song.audioUrl = url;
          _loadingAudioIds.remove(song.id);
          notifyListeners();
        }).catchError((e) {
          _loadingAudioIds.remove(song.id);
          if (e is YouTubeRateLimitException) {
            _isRateLimited = true;
          }
          notifyListeners();
        });
      }
    }
  }
  @override
  Future<void> fetchSuggestions() async {
    _suggestedSongs = [];
    await _fetchSuggestionsInBackground();
  }

  void _startPositionSaveTimer(Song song) {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentSong?.id == song.id) {
        _historyService.savePosition(song, currentPosition.inSeconds);
      }
    });
  }

  @override
  Future<List<Song>> getMostLikedFromHistory() => _historyService.getMostLikedSongs();
  @override
  Future<List<Song>> getRecentSongs() => _historyService.getRecentSongs();
  @override
  Future<bool> isLiked(String songId) => _historyService.isLiked(songId);
  @override
  Future<void> toggleLike(Song song) async {
    await _historyService.toggleLike(song);
    final liked = await _historyService.isLiked(song.id);
    final auth = _authProvider;
    if (auth != null) auth.syncLike(song.serverId, liked);
    notifyListeners();
  }

  @override
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs) =>
      _historyService.getMostLiked(knownSongs);

  @override
  Future<void> saveSearch(String query) async {
    await _historyService.saveSearch(query);
    notifyListeners();
  }
  
  @override
  Future<void> deleteSearch(String query) async {
    await _historyService.deleteSearch(query);
    notifyListeners();
  }

  @override
  Future<List<String>> getSearchHistory() => _historyService.getSearchHistory();

  @override
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    notifyListeners();
  }

  @override
  Future<List<Playlist>> loadPlaylists() => _historyService.loadPlaylists();
  @override
  Future<void> deletePlaylist(String id) => _historyService.deletePlaylist(id);
  
  @override
  void addSuggestedToQueue(Song song) {
    if (!queue.contains(song)) {
      if (_isFastModeActive) {
        _vibeQueue.add(song);
        _historyService.saveVibeQueue(_vibeQueue, _vibeIndex);
      } else {
        _normalQueue.add(song);
        _historyService.saveQueue(_normalQueue, _normalIndex);
      }
      _updateAudioHandlerQueue();
      notifyListeners();
    }
  }
  
  @override
  void clearSuggestions() {
    _suggestedSongs = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _positionSaveTimer?.cancel();
    _stallTimer?.cancel();
    if (_isInitialized) {
      if (_currentSong != null) {
        _historyService.savePosition(_currentSong!, currentPosition.inSeconds);
      }
      _audioHandler.stop();
    }
    super.dispose();
  }

  List<String> _pendingSeedQueries = [];
  final Set<String> _usedSeedQueries = {};

  void _markPendingPlaylistLiked(Song song, int listenedSeconds) {
    if (_pendingPlaylistSongs == null || _pendingPlaylistName == null) return;
    final isSuggested = _pendingPlaylistSongs!.skip(1).any((s) => s.id == song.id);
    if (!isSuggested) return;
    final durationSeconds = song.duration.inSeconds;
    final isLiked = durationSeconds >= 360
        ? listenedSeconds >= 180
        : listenedSeconds >= durationSeconds * 0.5;
    if (isLiked) {
      _pendingPlaylistLikedCount++;
      _checkPendingPlaylistThreshold();
    }
  }

  void _checkPendingPlaylistThreshold() {
    if (_pendingPlaylistSongs == null || _pendingPlaylistName == null) return;
    final suggested = _pendingPlaylistSongs!.skip(1).toList();
    if (suggested.isEmpty) return;
    if (_pendingPlaylistLikedCount / suggested.length >= 0.3) {
      _historyService.savePlaylist(_pendingPlaylistName!, _pendingPlaylistSongs!);
      _pendingPlaylistName = null;
      _pendingPlaylistSongs = null;
    }
  }

  void _updateAudioHandlerQueue() {
    if (!_isInitialized) return;
    final currentQueue = queue;
    final mediaItems = currentQueue.map((song) => MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: song.imageUrl.isNotEmpty ? Uri.tryParse(song.imageUrl) : null,
      duration: song.duration,
    )).toList();
    _audioHandler.queue.add(mediaItems);
  }
}

const List<Vibe> availableVibes = [
  Vibe(
    id: 'rcYoqkpVIe242IUSR1u7',
    labelKey: 'vibe_chill',
    label: 'Relajado',
    icon: '😌',
    order: 1,
    color: Colors.teal,
    subCategories: [
      VibeSubCategory(labelKey: 'vibe_chill_lofi', label: 'Lofi', icon: '🎧'),
      VibeSubCategory(labelKey: 'vibe_chill_acoustic', label: 'Acústico', icon: '🎸'),
      VibeSubCategory(labelKey: 'vibe_chill_ambient', label: 'Ambiental', icon: '🌊'),
      VibeSubCategory(labelKey: 'vibe_chill_jazz', label: 'Jazz suave', icon: '🎷'),
      VibeSubCategory(labelKey: 'vibe_chill_nature', label: 'Naturaleza', icon: '🌿'),
      VibeSubCategory(labelKey: 'vibe_chill_piano', label: 'Piano', icon: '🎹'),
      VibeSubCategory(labelKey: 'vibe_chill_yoga', label: 'Yoga', icon: '🧘'),
    ],
  ),
];
