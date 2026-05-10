import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import '../services/audio_handler.dart';
import '../services/youtube_service.dart';
import '../services/play_history_service.dart';
import '../services/lastfm_service.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart' show YouTubeService, YouTubeRateLimitException;
import '../utils/logger.dart';
import 'auth_provider.dart';

abstract class MusicPlayerProvider extends ChangeNotifier {
  Song? get currentSong;
  List<Song> get queue;
  int get currentIndex;
  bool get isShuffled;
  bool get isRepeating;
  bool get isInitialized;
  bool get autoAddSuggestions;
  bool get isFetchingSuggestions;
  List<Song> get suggestedSongs;
  bool isLoadingAudio(String songId);
  void prefetchAudioUrls(List<Song> songs);
  bool get isPlaying;
  Duration get currentPosition;
  Duration get totalDuration;
  Stream<Duration> get positionStream;

  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo, bool fromQueue = false, String? searchQuery});
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
  void clearSuggestions();
  Future<List<Song>> getMostLikedFromHistory();
  Future<List<Song>> getRecentSongs();
  Future<bool> isLiked(String songId);
  Future<void> toggleLike(Song song);
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs);
  Future<void> saveSearch(String query);
  Future<List<String>> getSearchHistory();
  Future<void> clearSearchHistory();
  Future<List<Playlist>> loadPlaylists();
  Future<void> deletePlaylist(String id);
}

class MusicPlayerProviderImpl extends MusicPlayerProvider {
  late AudioPlayerHandler _audioHandler;
  final YouTubeService _youtubeService = YouTubeService();
  YouTubeService get youtubeService => _youtubeService;
  final PlayHistoryService _historyService = PlayHistoryService();
  final DownloadService _downloadService = DownloadService();

  Timer? _notifyTimer;
  static const _notifyInterval = Duration(milliseconds: 250);

  @override
  void notifyListeners() {
    if (_notifyTimer?.isActive ?? false) return;
    super.notifyListeners();
    _notifyTimer = Timer(_notifyInterval, () {});
  }
  final LastFmService _lastFmService = LastFmService();
  AuthProvider? _authProvider;
  void setAuthProvider(AuthProvider auth) => _authProvider = auth;
  VoidCallback? _onRateLimit;
  void setOnRateLimit(VoidCallback cb) => _onRateLimit = cb;
  bool _isRateLimited = false;
  bool _isSwitchingSong = false;
  void Function(String title)? _onStreamError;
  void setOnStreamError(void Function(String title) cb) => _onStreamError = cb;
  Timer? _positionSaveTimer;
  Timer? _stallTimer;
  bool _isRecoveringFromStall = false;
  Duration _lastRestoredPosition = Duration.zero;
  Duration _lastPosition = Duration.zero;
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isShuffled = false;
  bool _isRepeating = false;
  bool _isInitialized = false;
  bool _autoAddSuggestions = true;
  final Set<String> _loadingAudioIds = {};
  @override
  bool isLoadingAudio(String songId) => _loadingAudioIds.contains(songId);
  bool _isFetchingSuggestions = false;
  List<Song> _suggestedSongs = [];

  Song? _pendingSong;
  List<Song>? _pendingQueue;

  @override
  Song? get currentSong => _currentSong;
  @override
  List<Song> get queue => _queue;
  @override
  int get currentIndex => _currentIndex;
  @override
  bool get isShuffled => _isShuffled;
  @override
  bool get isRepeating => _isRepeating;
  @override
  bool get isInitialized => _isInitialized;
  @override
  bool get autoAddSuggestions => _autoAddSuggestions;
  @override
  bool get isFetchingSuggestions => _isFetchingSuggestions;
  @override
  List<Song> get suggestedSongs => _suggestedSongs;

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
      rlog('[MusicPlayerProvider] starting AudioService.init');
      _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(
        onSkipToNext: () => nextSong(),
        onSkipToPrevious: () => previousSong(),
        onPlay: () => resume(),
      ),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.lxmw.musicapp.channel.audio',
        androidNotificationChannelName: 'Music Player',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
      ),
    );
    rlog('[MusicPlayerProvider] AudioService.init complete');

    final savedQueue = await _historyService.loadQueue();

    _isInitialized = true;
    if (_pendingSong == null) {
      if (savedQueue != null) {
        _queue = savedQueue.queue;
        _currentIndex = savedQueue.currentIndex;
        _currentSong = _queue[_currentIndex];
        rlog('[MusicPlayerProvider] restored queue: ${_queue.length} songs, index=$_currentIndex');
        notifyListeners();
      }
    }
    
    _audioHandler.positionStream.listen((position) {
      if (!_isSwitchingSong && position > Duration.zero) _lastPosition = position;
      if (_currentSong != null && _autoAddSuggestions) {
        final duration = totalDuration;
        final queueHasMore = _currentIndex < _queue.length - 1;
        if (duration.inSeconds > 0 &&
            (duration - position).inSeconds <= 10 &&
            !_isFetchingSuggestions &&
            _suggestedSongs.isEmpty &&
            !queueHasMore) {
          _fetchSuggestionsInBackground();
        }
      }
    });

    _audioHandler.durationStream.listen((duration) {
      if (duration != null && duration > Duration.zero && _currentSong != null) {
        final current = _audioHandler.mediaItem.value;
        if (current != null && (current.duration == null || current.duration == Duration.zero)) {
          _audioHandler.mediaItem.add(current.copyWith(duration: duration));
        }
        notifyListeners();
      }
    });

    _audioHandler.playbackState.listen((state) {
      if (state.processingState == AudioProcessingState.completed && !_isFetchingSuggestions && !_isSwitchingSong) {
        final completedSongId = _currentSong?.id;
        final duration = totalDuration;
        final wasPlaying = _lastPosition.inSeconds >= 5;
        final nearEnd = duration.inSeconds > 0
            ? _lastPosition.inSeconds >= (duration.inSeconds - 20)
            : _lastPosition.inSeconds >= 30;
        if (completedSongId != null && wasPlaying && nearEnd) {
          _historyService.recordPlay(_currentSong!, _lastPosition.inSeconds);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_currentSong?.id != completedSongId) return;
            if (_isRateLimited) {
              _isRateLimited = false;
              _onRateLimit?.call();
              _playOfflineByGenre(_currentSong!);
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

    _audioHandler.mediaItem.listen((_) {
      notifyListeners();
    });

    notifyListeners();
    
    if (_pendingSong != null) {
      final song = _pendingSong;
      final queue = _pendingQueue;
      _pendingSong = null;
      _pendingQueue = null;
      _loadingAudioIds.remove(song!.id);
      await playSong(song, queue: queue);
    }
    } catch (e, st) {
    rlog('[MusicPlayerProvider] _init ERROR: $e\n$st');
  }
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

    final stalledTags = stalledSong.genres.map((t) => t.toLowerCase()).toSet();
    List<Song> offlineQueue;
    if (stalledTags.isNotEmpty) {
      final scored = downloaded
          .where((s) => s.id != stalledSong.id)
          .map((s) {
            final shared = s.genres.map((t) => t.toLowerCase()).toSet()
                .intersection(stalledTags).length;
            return (song: s, score: shared);
          })
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      offlineQueue = scored.map((e) => e.song).toList();
    } else {
      offlineQueue = downloaded.where((s) => s.id != stalledSong.id).toList();
    }

    if (offlineQueue.isEmpty) offlineQueue = downloaded;
    Future.microtask(() => playSong(offlineQueue.first, queue: offlineQueue));
  }

  @override
  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo, bool fromQueue = false, String? searchQuery}) async {
    if (!_isInitialized) {
      _pendingSong = song;
      _pendingQueue = queue;
      _loadingAudioIds.add(song.id);
      _currentSong = song;
      if (queue != null) {
        _queue = queue;
        _currentIndex = queue.indexOf(song);
      }
      notifyListeners();
      return;
    }
    final isCompleted = _audioHandler.playbackState.value.processingState == AudioProcessingState.completed;
    if (_currentSong?.id == song.id && isPlaying && !isCompleted && queue == null) return;

    final previousSong = _currentSong;
    final previousPosition = currentPosition.inSeconds;
    _lastPosition = Duration.zero;
    if (previousSong != null && previousPosition > 0) {
      _historyService.recordPlay(previousSong, previousPosition);
    }
    _currentSong = song;
    if (fromQueue) {
      if (queue != null) _queue = queue;
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex < 0) _currentIndex = 0;
    } else {
      if (queue != null) {
        _queue = queue;
        _currentIndex = queue.indexWhere((s) => s.id == song.id);
        if (_currentIndex < 0) _currentIndex = 0;
        _historyService.saveQueue(_queue, _currentIndex);
      } else {
        _queue = [song];
        _currentIndex = 0;
        _isSeeding = false;
        _pendingSeedQueries = [];
        _usedSeedQueries.clear();

        Future.delayed(const Duration(seconds: 5), () {
          _youtubeService.generatePlaylist(song, search: searchQuery).then((playlist) {
            if (playlist.isEmpty) return;
            if (_currentSong?.id == song.id) {
              _queue = [song, ...playlist];
              _currentIndex = 0;
              _historyService.saveQueue(_queue, _currentIndex);
              final playlistName = searchQuery?.isNotEmpty == true
                  ? searchQuery!
                  : '${song.title} Radio';
              _historyService.savePlaylist(playlistName, _queue);
              notifyListeners();
            }
          });
        });
      }
    }
    notifyListeners();

    _suggestedSongs = [];
    String audioUrl = song.audioUrl;
    if (audioUrl.isEmpty) {
      _loadingAudioIds.add(song.id);
      _audioHandler.nextEnabled = false;
      notifyListeners();
      try {
        audioUrl = await _youtubeService.getPlayableAudioPath(song.id, serverId: song.serverId, song: song);
        song.audioUrl = audioUrl;
      } on YouTubeRateLimitException {
        _isRateLimited = true;
        _loadingAudioIds.remove(song.id);
        _audioHandler.nextEnabled = true;
        notifyListeners();
        if (!isPlaying) {
          _onRateLimit?.call();
          await _playOfflineByGenre(song);
        }
        return;
      } finally {
        _loadingAudioIds.remove(song.id);
        _audioHandler.nextEnabled = true;
        notifyListeners();
      }
    }
    if (audioUrl.isEmpty) {
      _onStreamError?.call(song.title);
      notifyListeners();
      return;
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
    try {
      await _audioHandler.setAudioSource(audioUrl, mediaItem);
      if (seekTo != null && seekTo > Duration.zero) {
        await _audioHandler.seek(seekTo);
      }
      await _audioHandler.play();
    } catch (e) {
      _loadingAudioIds.remove(song.id);
      _onStreamError?.call(song.title);
      notifyListeners();
      return;
    } finally {
      _isSwitchingSong = false;
    }
    
    _consecutiveSkips = 0;
    _historyService.savePosition(song, 0);
    _historyService.saveQueue(_queue, _currentIndex);
    _startPositionSaveTimer(song);
    notifyListeners();

    if (!audioUrl.startsWith('/') && !audioUrl.startsWith('file://')) {
      final cacheSongId = song.id;
      final cacheUrl = audioUrl;
      final delay = song.duration > Duration.zero ? song.duration : const Duration(minutes: 5);
      Future.delayed(delay, () {
        if (_currentSong?.id != cacheSongId) {
          _youtubeService.cacheAudioInBackground(cacheSongId, cacheUrl);
        }
      });
    }

    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      final next = _queue[_currentIndex + 1];
      if (next.audioUrl.isEmpty && !_loadingAudioIds.contains(next.id)) {
        _loadingAudioIds.add(next.id);
        _youtubeService.getPlayableAudioPath(next.id, serverId: next.serverId, song: next)
            .then((url) {
              if (url.isNotEmpty) next.audioUrl = url;
              _loadingAudioIds.remove(next.id);
            });
      }
    }
  }
  bool _isSeeding = false;
  int _consecutiveSkips = 0;

  void _addToQueue(List<Song> songs, String excludeId) {
    final existing = _queue.map((s) => s.id).toSet();
    final toAdd = songs.where((s) =>
      s.id != excludeId &&
      !existing.contains(s.id)
    ).toList();
    if (toAdd.isNotEmpty) {
      _queue.addAll(toAdd);
      if (toAdd.first.audioUrl.isEmpty) {
        _youtubeService.getAudioUrl(toAdd.first.id).then((url) => toAdd.first.audioUrl = url);
      }
      _historyService.saveQueue(_queue, _currentIndex);
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
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _consecutiveSkips = 0;
      _currentIndex++;
      playSong(_queue[_currentIndex], fromQueue: true);
      _historyService.saveQueue(_queue, _currentIndex);
    } else if (_suggestedSongs.isNotEmpty) {
      _consecutiveSkips = 0;
      final next = _suggestedSongs.first;
      _suggestedSongs = [];
      _queue.add(next);
      _currentIndex = _queue.length - 1;
      playSong(next, fromQueue: true);
    } else if (_currentSong != null) {
      _fetchAndPlaySuggestion();
    }
  }

  Future<void> _fetchAndPlaySuggestion() async {
    if (_currentSong == null || _isSeeding || _isRateLimited) return;
    try {
      if (_pendingSeedQueries.isNotEmpty) {
        final query = _pendingSeedQueries.removeAt(0);
        if (!_usedSeedQueries.contains(query)) {
          _usedSeedQueries.add(query);
          final songs = await _youtubeService.searchByQuery(query, maxResults: 20);
          _addToQueue(songs, _currentSong!.id);
          if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
            _currentIndex++;
            playSong(_queue[_currentIndex]);
            return;
          }
        }
      }
      final suggestions = await _youtubeService.getSuggestedSongs(_currentSong!.id, maxResults: 1, knownTitle: _currentSong!.title);
      if (suggestions.isNotEmpty) {
        _queue.add(suggestions.first);
        _currentIndex = _queue.length - 1;
        playSong(suggestions.first);
      } else {
        await _audioHandler.seek(Duration.zero);
        notifyListeners();
      }
    } catch (e) {
      await _audioHandler.seek(Duration.zero);
      notifyListeners();
    }
  }

  @override
  void previousSong() {
    if (!_isInitialized) return;
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      playSong(_queue[_currentIndex], fromQueue: true);
      _historyService.saveQueue(_queue, _currentIndex);
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
      print('Error fetching suggestions: $e');
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
  Future<void> saveSearch(String query) => _historyService.saveSearch(query);
  
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
    if (!_queue.contains(song)) {
      _queue.add(song);
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
}
