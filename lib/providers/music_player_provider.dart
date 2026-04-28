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
  final PlayHistoryService _historyService = PlayHistoryService();
  final DownloadService _downloadService = DownloadService();
  final LastFmService _lastFmService = LastFmService();
  Timer? _positionSaveTimer;
  Timer? _stallTimer;
  Duration _lastRestoredPosition = Duration.zero;
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

  MusicPlayerProviderImpl() {
    _init();
  }

  Future<void> _init() async {
    try {
      print('[MusicPlayerProvider] starting AudioService.init');
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
    print('[MusicPlayerProvider] AudioService.init complete');

    // Restore last queue and song on startup BEFORE marking initialized
    final savedQueue = await _historyService.loadQueue();
    final lastSongData = await _historyService.loadLastSong();

    _isInitialized = true;
    if (_pendingSong == null) {
      if (savedQueue != null) {
        _queue = savedQueue.queue;
        _currentIndex = savedQueue.currentIndex;
        _currentSong = _queue[_currentIndex];
        _lastRestoredPosition = Duration(seconds: lastSongData?.lastPositionSeconds ?? 0);
        print('[MusicPlayerProvider] restored queue: ${_queue.length} songs, index=$_currentIndex');
      } else if (lastSongData != null) {
        _currentSong = lastSongData.song;
        _queue = [lastSongData.song];
        _currentIndex = 0;
        _lastRestoredPosition = Duration(seconds: lastSongData.lastPositionSeconds);
        print('[MusicPlayerProvider] restored last song: ${lastSongData.song.title}');
      }
      if (_currentSong != null) {
        notifyListeners();
        final song = _currentSong!;
        _youtubeService.getAudioUrl(song.id).then((url) => song.audioUrl = url);
        // If queue has only 1 song (no suggestions yet), seed in background
        if (_queue.length <= 1) _seedQueueWithSuggestions(song);
      }
    }
    
    _audioHandler.playbackState.listen((state) {
      if (state.processingState == AudioProcessingState.completed && !_isFetchingSuggestions && !_isSwitchingSong) {
        print('[MusicPlayerProvider] song completed, calling nextSong');
        if (_currentSong != null) {
          _historyService.recordPlay(_currentSong!, _currentSong!.duration.inSeconds);
        }
        // Use Future.microtask to avoid calling nextSong synchronously inside a stream listener
        Future.microtask(() => nextSong());
      }

      // Stall detection: if buffering for >8s, re-fetch URL and retry
      if (state.processingState == AudioProcessingState.buffering && state.playing) {
        _stallTimer ??= Timer(const Duration(seconds: 8), _handleStall);
      } else {
        _stallTimer?.cancel();
        _stallTimer = null;
      }

      notifyListeners();
    });
    _audioHandler.mediaItem.listen((_) {
      notifyListeners();
    });
    
    // Listen for when a song is about to end and fetch suggestions
    _audioHandler.positionStream.listen((position) {
      if (_currentSong != null && _autoAddSuggestions) {
        final duration = totalDuration;
        if (duration.inSeconds > 0 &&
            (duration - position).inSeconds <= 10 &&
            !_isFetchingSuggestions &&
            _suggestedSongs.isEmpty) {
          _fetchSuggestionsInBackground();
        }
      }
      // Do NOT call notifyListeners here — position updates fire multiple times/sec
      // and cause excessive rebuilds. UI reads position directly from audioHandler.
    });

    _audioHandler.durationStream.listen((_) => notifyListeners());
    
    notifyListeners();
    
    // If there was a pending playSong call, process it now
    if (_pendingSong != null) {
      final song = _pendingSong;
      final queue = _pendingQueue;
      _pendingSong = null;
      _pendingQueue = null;
      _loadingAudioIds.remove(song!.id); // clear pending spinner before re-playing
    print('[MusicPlayerProvider] _init complete, processing pending song: ${song.id}');
      await playSong(song, queue: queue);
    }
    } catch (e, st) {
    print('[MusicPlayerProvider] _init ERROR: $e\n$st');
  }
  }

  Future<void> _handleStall() async {
    final song = _currentSong;
    if (song == null) return;
    print('[MusicPlayerProvider] stall detected for "${song.title}"');

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = connectivity.any((c) =>
        c == ConnectivityResult.wifi || c == ConnectivityResult.mobile);

    if (!hasInternet) {
      print('[MusicPlayerProvider] no internet — switching to offline queue');
      await _playOfflineByGenre(song);
      return;
    }

    // Has internet — re-fetch URL and retry from current position
    print('[MusicPlayerProvider] has internet — re-fetching URL...');
    final position = currentPosition;
    song.audioUrl = '';
    try {
      await playSong(song, seekTo: position);
      print('[MusicPlayerProvider] stall recovery succeeded');
    } catch (e) {
      print('[MusicPlayerProvider] stall recovery failed: $e');
    }
  }

  Future<void> _playOfflineByGenre(Song stalledSong) async {
    final downloaded = await _downloadService.getDownloadedSongs();
    if (downloaded.isEmpty) {
      print('[MusicPlayerProvider] no downloaded songs available offline');
      return;
    }

    final stalledTags = stalledSong.genres.map((t) => t.toLowerCase()).toSet();
    print('[MusicPlayerProvider] offline genre match using tags: $stalledTags');

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

    print('[MusicPlayerProvider] offline queue: ${offlineQueue.length} songs, first: ${offlineQueue.first.title}');
    await playSong(offlineQueue.first, queue: offlineQueue);
  }

  @override
  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo, bool fromQueue = false, String? searchQuery}) async {
    if (!_isInitialized) {
      print('[MusicPlayerProvider] not initialized yet, queuing: ${song.title}');
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
    // Don't restart if same song is already playing (but allow if queue is being set)
    if (_currentSong?.id == song.id && isPlaying && queue == null) return;
    // Prevent concurrent playSong calls
    if (_isSwitchingSong) return;
    _isSwitchingSong = true;

    // Snapshot position before it resets, then record play for previous song
    final previousSong = _currentSong;
    final previousPosition = currentPosition.inSeconds;
    if (previousSong != null && previousPosition > 0) {
      print('[MusicPlayerProvider] recording play: ${previousSong.title}, position=${previousPosition}s, duration=${previousSong.duration.inSeconds}s');
      _historyService.recordPlay(previousSong, previousPosition);
    }
    // Show song immediately in UI while audio URL is being fetched
    _currentSong = song;
    // Only skip generatePlaylist when navigating within existing queue (next/prev)
    if (fromQueue) {
      // If an explicit queue is provided (e.g. playing from saved playlist), set it
      if (queue != null) {
        _queue = queue;
      }
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex < 0) _currentIndex = 0;
    } else {
      // User tapped a song — always reset queue and generate fresh playlist
      _queue = [song];
      _currentIndex = 0;
      _isSeeding = false;
      _pendingSeedQueries = [];
      _usedSeedQueries.clear();

      _youtubeService.generatePlaylist(song, search: searchQuery).then((playlist) {
        if (playlist.isEmpty) {
          print('[MusicPlayerProvider] generate-playlist returned empty for ${song.id}');
          return;
        }
        if (_currentSong?.id == song.id) {
          _queue = [song, ...playlist];
          _currentIndex = 0;
          print('[MusicPlayerProvider] queue updated: ${_queue.length} songs');
          _historyService.saveQueue(_queue, _currentIndex);
          // Save as named playlist using the seed song as the name
          final playlistName = searchQuery?.isNotEmpty == true
              ? searchQuery!
              : '${song.title} Radio';
          _historyService.savePlaylist(playlistName, _queue);
          notifyListeners();
        }
      });
    }
    notifyListeners();

    // Clear suggestions when starting a new song
    _suggestedSongs = [];
    String audioUrl = song.audioUrl;
    print('[MusicPlayerProvider] playSong: \\${song.title}, audioUrl empty=\\${audioUrl.isEmpty}, loadingIds=\\$_loadingAudioIds');
    if (audioUrl.isEmpty) {
      _loadingAudioIds.add(song.id);
      _audioHandler.nextEnabled = false;
      notifyListeners();
      try {
        // Prefer cached file, otherwise play online
        audioUrl = await _youtubeService.getPlayableAudioPath(song.id, serverId: song.serverId, song: song);
        print('[MusicPlayerProvider] Playable audio for \\${song.title}: \\${audioUrl.isEmpty ? "EMPTY" : audioUrl}');
        song.audioUrl = audioUrl;
      } finally {
        _loadingAudioIds.remove(song.id);
        _audioHandler.nextEnabled = true;
        notifyListeners();
      }
    }
    if (audioUrl.isEmpty) {
      print('[MusicPlayerProvider] Could not get audio file for \\${song.title}, skipping');
      _isSwitchingSong = false;
      return;
    }
    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: song.imageUrl.isNotEmpty ? Uri.tryParse(song.imageUrl) : null,
      duration: song.duration,
    );
    try {
      await _audioHandler.setAudioSource(audioUrl, mediaItem);
      if (seekTo != null && seekTo > Duration.zero) {
        await _audioHandler.seek(seekTo);
      }
      await _audioHandler.play();
    } catch (e) {
      print('[MusicPlayerProvider] setAudioSource error: $e — retrying with fresh URL');
      try {
        song.audioUrl = '';
        final freshUrl = await _youtubeService.getPlayableAudioPath(song.id);
        if (freshUrl.isEmpty) throw Exception('empty URL on retry');
        song.audioUrl = freshUrl;
        await _audioHandler.setAudioSource(freshUrl, mediaItem);
        if (seekTo != null && seekTo > Duration.zero) {
          await _audioHandler.seek(seekTo);
        }
        await _audioHandler.play();
      } catch (e2) {
        print('[MusicPlayerProvider] retry failed: $e2 — skipping to next');
        _loadingAudioIds.remove(song.id);
        _isSwitchingSong = false;
        notifyListeners();
        // Remove failed song from queue to prevent infinite skip loop
        _queue.removeWhere((s) => s.id == song.id);
        if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
        nextSong();
        return;
      }
    }
    _isSwitchingSong = false;
    _consecutiveSkips = 0;
    _historyService.savePosition(song, 0);
    _historyService.saveQueue(_queue, _currentIndex);
    _startPositionSaveTimer(song);
    notifyListeners();

    // Pre-fetch next song's URL in background to reduce lag on next tap
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      final nextSong = _queue[_currentIndex + 1];
      if (nextSong.audioUrl.isEmpty) {
        _youtubeService.getAudioUrl(nextSong.id).then((url) => nextSong.audioUrl = url);
      }
    } else {
      // At end of queue — pre-fetch a suggestion + its audio URL
      _youtubeService.getSuggestedSongs(song.id, maxResults: 1).then((suggestions) {
        if (suggestions.isNotEmpty) {
          _suggestedSongs = suggestions;
          final suggested = suggestions.first;
          _youtubeService.getAudioUrl(suggested.id).then((url) => suggested.audioUrl = url);
        }
      });
    }
  }
  bool _isSeeding = false;
  bool _isSwitchingSong = false;
  int _consecutiveSkips = 0;
  static const _maxConsecutiveSkips = 5;

  /// Fetch suggestions for the seed song and append to queue in background
  void _seedQueueWithSuggestions(Song seedSong) {
    if (_isSeeding) {
      print('[MusicPlayerProvider] already seeding, skipped for: ${seedSong.title}');
      return;
    }
    _isSeeding = true;
    _doSeed(seedSong);
  }

  Future<void> _doSeed(Song seedSong) async {
    print('[MusicPlayerProvider] _seedQueueWithSuggestions started for: ${seedSong.title}');
    try {
      final metadata = await _youtubeService.getMetadata(seedSong.title);

      if (metadata == null || metadata.isMix) {
        await _seedWithQueries(seedSong, metadata?.suggestedQueries ?? []);
      } else {
        final artist = metadata.artist.isNotEmpty ? metadata.artist : seedSong.artist;

        // 1. Last.fm top tracks (most accurate artist songs)
        final topTracks = await _lastFmService.getArtistTopTracks(artist, limit: 10);
        if (topTracks.isNotEmpty) {
          print('[MusicPlayerProvider] Last.fm top tracks for $artist: ${topTracks.length}');
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
          print('[MusicPlayerProvider] Last.fm similar artists: $similarArtists');
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
      print('[MusicPlayerProvider] added ${toAdd.length} songs to queue, total: ${_queue.length}');
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
  void nextSong() {
    if (!_isInitialized) return;
    if (_isSwitchingSong) return;
    _consecutiveSkips++;
    if (_consecutiveSkips > _maxConsecutiveSkips) {
      print('[MusicPlayerProvider] too many consecutive skips, stopping');
      _consecutiveSkips = 0;
      _isSwitchingSong = false;
      return;
    }
    _isSwitchingSong = true;
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _currentIndex++;
      playSong(_queue[_currentIndex], fromQueue: true);
      _historyService.saveQueue(_queue, _currentIndex);
    } else if (_suggestedSongs.isNotEmpty) {
      final next = _suggestedSongs.first;
      _suggestedSongs = [];
      _queue.add(next);
      _currentIndex = _queue.length - 1;
      playSong(next, fromQueue: true);
    } else if (_currentSong != null) {
      _isSwitchingSong = false; // no song to play, release lock
      _fetchAndPlaySuggestion();
    } else {
      _isSwitchingSong = false;
    }
  }

  Future<void> _fetchAndPlaySuggestion() async {
    if (_currentSong == null || _isSeeding) return;
    try {
      // Use pending seed queries first (no repeats)
      if (_pendingSeedQueries.isNotEmpty) {
        final query = _pendingSeedQueries.removeAt(0);
        if (!_usedSeedQueries.contains(query)) {
          _usedSeedQueries.add(query);
          print('[MusicPlayerProvider] fetching more from query: $query');
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
      }
    } catch (e) {
      print('Error fetching suggestion: $e');
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
        _youtubeService.getAudioUrl(song.id).then((url) {
          song.audioUrl = url;
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
