import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  Future<List<Playlist>> loadPlaylists();
  Future<void> deletePlaylist(String id);
}

class MusicPlayerProviderImpl extends MusicPlayerProvider {
  late AudioPlayerHandler _audioHandler;
  final YouTubeService _youtubeService = YouTubeService();
  YouTubeService get youtubeService => _youtubeService;
  final PlayHistoryService _historyService = PlayHistoryService();
  final DownloadService _downloadService = DownloadService();
  final LastFmService _lastFmService = LastFmService();
  AuthProvider? _authProvider;
  void setAuthProvider(AuthProvider auth) => _authProvider = auth;
  VoidCallback? _onRateLimit;
  void setOnRateLimit(VoidCallback cb) => _onRateLimit = cb;
  bool _isRateLimited = false;
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

    // Restore last queue on startup
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
    
    AudioProcessingState? _lastProcessingState;
    bool? _lastPlaying;
    bool _isUpdatingMediaItem = false; // Guard against recursive mediaItem updates
    
    _audioHandler.positionStream.listen((position) {
      if (position > Duration.zero) _lastPosition = position;
      if (_currentSong != null && _autoAddSuggestions) {
        final duration = totalDuration;
        // Only fetch suggestions if we're near the end AND queue is almost exhausted
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

    // Update mediaItem duration when audio loads — fixes Bluetooth/notification display
    _audioHandler.durationStream.listen((duration) {
      if (duration != null && duration > Duration.zero && _currentSong != null && !_isUpdatingMediaItem) {
        final current = _audioHandler.mediaItem.value;
        if (current != null && (current.duration == null || current.duration == Duration.zero)) {
          _isUpdatingMediaItem = true;
          _audioHandler.mediaItem.add(current.copyWith(duration: duration));
          _isUpdatingMediaItem = false;
        }
        notifyListeners();
      }
    });

    _audioHandler.playbackState.listen((state) {
      if (state.processingState == AudioProcessingState.completed && !_isFetchingSuggestions) {
        final completedSongId = _currentSong?.id;
        final duration = totalDuration;
        // Real completion: played at least 5s
        final wasPlaying = _lastPosition.inSeconds >= 5;
        // Near end: within last 20s. If duration unknown, require at least 30s played.
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
        } else if (completedSongId != null && wasPlaying && !nearEnd) {
          rlog('[MusicPlayerProvider] ignoring early completed at ${_lastPosition.inSeconds}s / ${duration.inSeconds}s');
        }
      }

      if (state.processingState == AudioProcessingState.buffering && state.playing && !_isRecoveringFromStall && _loadingAudioIds.isEmpty) {
        // Only start stall timer if position is genuinely stuck (not just buffering ahead)
        _stallTimer ??= Timer(const Duration(seconds: 30), () {
          // Double-check position hasn't advanced before declaring a stall
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

      if (state.processingState != _lastProcessingState || state.playing != _lastPlaying) {
        _lastProcessingState = state.processingState;
        _lastPlaying = state.playing;
        notifyListeners();
      }
    });

    _audioHandler.mediaItem.listen((_) {
      if (!_isUpdatingMediaItem) notifyListeners();
    });

    notifyListeners();
    
    // If there was a pending playSong call, process it now
    if (_pendingSong != null) {
      final song = _pendingSong;
      final queue = _pendingQueue;
      _pendingSong = null;
      _pendingQueue = null;
      _loadingAudioIds.remove(song!.id); // clear pending spinner before re-playing
    rlog('[MusicPlayerProvider] _init complete, processing pending song: ${song.id}');
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
    rlog('[MusicPlayerProvider] stall detected for "${song.title}"');

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = connectivity.any((c) =>
          c == ConnectivityResult.wifi || c == ConnectivityResult.mobile);

      if (!hasInternet) {
        rlog('[MusicPlayerProvider] no internet — switching to offline queue');
        await _playOfflineByGenre(song);
        return;
      }

      rlog('[MusicPlayerProvider] has internet — re-fetching URL...');
      final position = currentPosition;
      // Only clear network URLs — don't wipe local file paths for downloaded songs
      if (!song.audioUrl.startsWith('/') && !song.audioUrl.startsWith('file://')) {
        song.audioUrl = '';
      }
      await playSong(song, seekTo: position);
      rlog('[MusicPlayerProvider] stall recovery succeeded');
    } catch (e) {
      rlog('[MusicPlayerProvider] stall recovery failed: $e');
    } finally {
      _isRecoveringFromStall = false;
    }
  }

  Future<void> _playOfflineByGenre(Song stalledSong) async {
    final downloaded = await _downloadService.getDownloadedSongs();
    if (downloaded.isEmpty) {
      rlog('[MusicPlayerProvider] no downloaded songs available offline');
      return;
    }

    final stalledTags = stalledSong.genres.map((t) => t.toLowerCase()).toSet();
    rlog('[MusicPlayerProvider] offline genre match using tags: $stalledTags');

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

    rlog('[MusicPlayerProvider] offline queue: ${offlineQueue.length} songs, first: ${offlineQueue.first.title}');
    Future.microtask(() => playSong(offlineQueue.first, queue: offlineQueue));
  }

  @override
  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo, bool fromQueue = false, String? searchQuery}) async {
    if (!_isInitialized) {
      rlog('[MusicPlayerProvider] not initialized yet, queuing: ${song.title}');
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
    // Don't restart if same song is already playing (but allow if completed or queue is being set)
    final isCompleted = _audioHandler.playbackState.value.processingState == AudioProcessingState.completed;
    if (_currentSong?.id == song.id && isPlaying && !isCompleted && queue == null) return;
    // Block concurrent auto-advances (fromQueue), but always allow user taps
    
    

    // Snapshot position before it resets, then record play for previous song
    final previousSong = _currentSong;
    final previousPosition = currentPosition.inSeconds;
    if (previousSong != null && previousPosition > 0) {
      rlog('[MusicPlayerProvider] recording play: ${previousSong.title}, position=${previousPosition}s, duration=${previousSong.duration.inSeconds}s');
      _historyService.recordPlay(previousSong, previousPosition);
    }
    // Show song immediately in UI while audio URL is being fetched
    _currentSong = song;
    // Only skip generatePlaylist when navigating within existing queue (next/prev)
    if (!fromQueue) _isRateLimited = false; // user manually picked a song, allow retrying YouTube
    if (fromQueue) {
      if (queue != null) {
        _queue = queue;
      }
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex < 0) _currentIndex = 0;
    } else {
      if (queue != null) {
        _queue = queue;
        _currentIndex = queue.indexWhere((s) => s.id == song.id);
        if (_currentIndex < 0) _currentIndex = 0;
        _historyService.saveQueue(_queue, _currentIndex);
      } else {
        // No queue — reset and generate from server
        _queue = [song];
        _currentIndex = 0;
        _isSeeding = false;
        _pendingSeedQueries = [];
        _usedSeedQueries.clear();

        // Delay to avoid rate limiting when audio URL fetch also hits YouTube
        Future.delayed(const Duration(seconds: 5), () {
          _youtubeService.generatePlaylist(song, search: searchQuery).then((playlist) {
            if (playlist.isEmpty) {
              rlog('[MusicPlayerProvider] generate-playlist returned empty for ${song.id}');
              return;
            }
            if (_currentSong?.id == song.id) {
              _queue = [song, ...playlist];
              _currentIndex = 0;
              rlog('[MusicPlayerProvider] queue updated: ${_queue.length} songs');
              _historyService.saveQueue(_queue, _currentIndex);
              final playlistName = searchQuery?.isNotEmpty == true
                  ? searchQuery!
                  : '${song.title} Radio';
              _historyService.savePlaylist(playlistName, _queue);
              // Prefetch next song now that queue is populated
              if (_queue.length > 1) {
                final next = _queue[1];
                if (next.audioUrl.isEmpty && !_loadingAudioIds.contains(next.id)) {
                  _loadingAudioIds.add(next.id);
                  _youtubeService.getPlayableAudioPath(next.id, serverId: next.serverId, song: next)
                      .then((url) {
                        if (url.isNotEmpty) next.audioUrl = url;
                        _loadingAudioIds.remove(next.id);
                      });
                }
              }
              notifyListeners();
            }
          });
        });
      }
    }
    notifyListeners();

    // Clear suggestions when starting a new song
    _suggestedSongs = [];
    String audioUrl = song.audioUrl;
    rlog('[MusicPlayerProvider] playSong: \\${song.title}, audioUrl empty=\\${audioUrl.isEmpty}, loadingIds=\\$_loadingAudioIds');
    if (audioUrl.isEmpty) {
      _loadingAudioIds.add(song.id);
      _audioHandler.nextEnabled = false;
      notifyListeners();
      try {
        // Prefer cached file, otherwise play online
        audioUrl = await _youtubeService.getPlayableAudioPath(song.id, serverId: song.serverId, song: song);
        rlog('[MusicPlayerProvider] Playable audio for \\${song.title}: \\${audioUrl.isEmpty ? "EMPTY" : audioUrl}');
        song.audioUrl = audioUrl;
      } on YouTubeRateLimitException {
        rlog('[MusicPlayerProvider] Rate limited');
        _isRateLimited = true;
        _loadingAudioIds.remove(song.id);
        _audioHandler.nextEnabled = true;
        notifyListeners();
        // If nothing is playing, switch to offline now; otherwise wait for current song to finish
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
      rlog('[MusicPlayerProvider] Could not get stream URL for \\${song.title}');
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
    _lastPosition = Duration.zero; // reset before setAudioSource to prevent stale position triggering false completed
    try {
      await _audioHandler.setAudioSource(audioUrl, mediaItem);
      if (seekTo != null && seekTo > Duration.zero) {
        await _audioHandler.seek(seekTo);
      }
      await _audioHandler.play();
    } catch (e) {
      rlog('[MusicPlayerProvider] setAudioSource error: $e');
      _loadingAudioIds.remove(song.id);
      _onStreamError?.call(song.title);
      notifyListeners();
      return;
    }
    
    _consecutiveSkips = 0;
    _historyService.savePosition(song, 0);
    _historyService.saveQueue(_queue, _currentIndex);
    _startPositionSaveTimer(song);
    notifyListeners();

    // Cache audio bytes after song finishes streaming to avoid 403 from concurrent requests
    if (!audioUrl.startsWith('/') && !audioUrl.startsWith('file://')) {
      final cacheSongId = song.id;
      final cacheUrl = audioUrl;
      final delay = song.duration > Duration.zero ? song.duration : const Duration(minutes: 5);
      Future.delayed(delay, () {
        if (_currentSong?.id != cacheSongId) { // only cache if song has moved on
          _youtubeService.cacheAudioInBackground(cacheSongId, cacheUrl);
        }
      });
    }

    // Pre-fetch next song's URL — skip if already loading or cached
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      final next = _queue[_currentIndex + 1];
      if (next.audioUrl.isEmpty && !_loadingAudioIds.contains(next.id)) {
        rlog('[MusicPlayerProvider] prefetching next: ${next.title}');
        _loadingAudioIds.add(next.id);
        _youtubeService.getPlayableAudioPath(next.id, serverId: next.serverId, song: next)
            .then((url) {
              if (url.isNotEmpty) next.audioUrl = url;
              _loadingAudioIds.remove(next.id);
              rlog('[MusicPlayerProvider] prefetch done: ${next.title}, empty=${url.isEmpty}');
            });
      } else {
        rlog('[MusicPlayerProvider] prefetch skipped for ${next.title}: audioUrl=${next.audioUrl.isNotEmpty}, loading=${_loadingAudioIds.contains(next.id)}');
      }
    }
  }
  bool _isSeeding = false;
  int _consecutiveSkips = 0;

  /// Fetch suggestions for the seed song and append to queue in background
  void _seedQueueWithSuggestions(Song seedSong) {
    if (_isSeeding || _isRateLimited) {
      rlog('[MusicPlayerProvider] seeding skipped: isSeeding=$_isSeeding, rateLimited=$_isRateLimited');
      return;
    }
    _isSeeding = true;
    _doSeed(seedSong);
  }

  Future<void> _doSeed(Song seedSong) async {
    rlog('[MusicPlayerProvider] _seedQueueWithSuggestions started for: ${seedSong.title}');
    try {
      final metadata = await _youtubeService.getMetadata(seedSong.title);

      if (metadata == null || metadata.isMix) {
        await _seedWithQueries(seedSong, metadata?.suggestedQueries ?? []);
      } else {
        final artist = metadata.artist.isNotEmpty ? metadata.artist : seedSong.artist;

        // 1. Last.fm top tracks (most accurate artist songs)
        final topTracks = await _lastFmService.getArtistTopTracks(artist, limit: 10);
        if (topTracks.isNotEmpty) {
          rlog('[MusicPlayerProvider] Last.fm top tracks for $artist: ${topTracks.length}');
          for (final track in topTracks.take(3)) {
            final songs = await _youtubeService.searchByQuery(track, maxResults: 3);
            _addToQueue(songs, seedSong.id);
          }
        } else {
          final songs = await _youtubeService.searchByQuery('$artist best songs', maxResults: 20);
          _addToQueue(songs, seedSong.id);
        }

        // 2. YouTube algorithm suggestions
        final ytSuggestions = await _youtubeService.getSuggestedSongs(seedSong.id, maxResults: 10, knownTitle: seedSong.title);
        _addToQueue(ytSuggestions, seedSong.id);

        // 3. Similar artists from Last.fm as pending queries
        final similarArtists = await _lastFmService.getSimilarArtists(artist, limit: 5);
        if (similarArtists.isNotEmpty) {
          rlog('[MusicPlayerProvider] Last.fm similar artists: $similarArtists');
          _pendingSeedQueries = similarArtists.map((a) => '$a best songs').toList()..shuffle();
        } else {
          _pendingSeedQueries = List.from(metadata.suggestedQueries)..shuffle();
        }
      }
    } finally {
      _isSeeding = false;
    }
  }

  List<String> _pendingSeedQueries = [];
  final Set<String> _usedSeedQueries = {};

  // ignore: unused_field
  Set<String> _unlikedArtists = {};

  // TODO: Filter unliked songs from queue by title+artist key to avoid same song
  // with different video IDs, while still allowing other songs from same artist.

  void _addToQueue(List<Song> songs, String excludeId) {
    final existing = _queue.map((s) => s.id).toSet();
    final toAdd = songs.where((s) =>
      s.id != excludeId &&
      !existing.contains(s.id)
    ).toList();
    if (toAdd.isNotEmpty) {
      _queue.addAll(toAdd);
      rlog('[MusicPlayerProvider] added ${toAdd.length} songs to queue, total: ${_queue.length}');
      if (toAdd.first.audioUrl.isEmpty) {
        _youtubeService.getAudioUrl(toAdd.first.id).then((url) => toAdd.first.audioUrl = url);
      }
      _historyService.saveQueue(_queue, _currentIndex);
      notifyListeners();
    }
  }
  Future<void> _seedWithQueries(Song seedSong, List<String> queries) async {
    final shuffled = List<String>.from(queries)..shuffle();
    for (final query in shuffled) {
      if (_usedSeedQueries.contains(query)) continue;
      _usedSeedQueries.add(query);
      final songs = await _youtubeService.searchByQuery(query, maxResults: 20);
      _addToQueue(songs, seedSong.id);
      break; // one query at a time, more will be fetched as queue runs out
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
      _consecutiveSkips = 0; // successful advance resets counter
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
      // Use pending seed queries first (no repeats)
      if (_pendingSeedQueries.isNotEmpty) {
        final query = _pendingSeedQueries.removeAt(0);
        if (!_usedSeedQueries.contains(query)) {
          _usedSeedQueries.add(query);
          rlog('[MusicPlayerProvider] fetching more from query: $query');
          final songs = await _youtubeService.searchByQuery(query, maxResults: 20);
          _addToQueue(songs, _currentSong!.id);
          if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
            _currentIndex++;
            playSong(_queue[_currentIndex]);
            return;
          }
        }
      }
      // Fallback
      final suggestions = await _youtubeService.getSuggestedSongs(_currentSong!.id, maxResults: 1, knownTitle: _currentSong!.title);
      if (suggestions.isNotEmpty) {
        _queue.add(suggestions.first);
        _currentIndex = _queue.length - 1;
        playSong(suggestions.first);
      } else {
        // Nothing to play — seek current song back to start
        await _audioHandler.seek(Duration.zero);
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching suggestion: $e');
      // Seek to start so user isn't stuck at end
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
  
  /// Pre-fetch audio URLs for a list of songs in the background
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
    // Sync to server fire-and-forget
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
  Future<List<Playlist>> loadPlaylists() => _historyService.loadPlaylists();
  @override
  Future<void> deletePlaylist(String id) => _historyService.deletePlaylist(id);
  /// Add a suggested song to the queue
  @override
  void addSuggestedToQueue(Song song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      notifyListeners();
    }
  }
  
  /// Clear suggested songs list
  @override
  void clearSuggestions() {
    _suggestedSongs = [];
    notifyListeners();
  }

  @override
  void dispose() {
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
}
