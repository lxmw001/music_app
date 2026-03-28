import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/music_models.dart';
import '../services/audio_handler.dart';
import '../services/youtube_service.dart';
import '../services/play_history_service.dart';

abstract class MusicPlayerProvider extends ChangeNotifier {
  Song? get currentSong;
  List<Song> get queue;
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

  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo});
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
  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs);
}

class MusicPlayerProviderImpl extends MusicPlayerProvider {
  late AudioPlayerHandler _audioHandler;
  final YouTubeService _youtubeService = YouTubeService();
  final PlayHistoryService _historyService = PlayHistoryService();
  Timer? _positionSaveTimer;
  Duration _lastRestoredPosition = Duration.zero;
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isShuffled = false;
  bool _isRepeating = false;
  bool _isInitialized = false;
  bool _autoAddSuggestions = true;
  final Set<String> _loadingAudioIds = {};
  bool isLoadingAudio(String songId) => _loadingAudioIds.contains(songId);
  bool _isFetchingSuggestions = false;
  List<Song> _suggestedSongs = [];

  Song? _pendingSong;
  List<Song>? _pendingQueue;

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  bool get isShuffled => _isShuffled;
  bool get isRepeating => _isRepeating;
  bool get isInitialized => _isInitialized;
  bool get autoAddSuggestions => _autoAddSuggestions;
  bool get isFetchingSuggestions => _isFetchingSuggestions;
  List<Song> get suggestedSongs => _suggestedSongs;

  bool get isPlaying => _isInitialized ? _audioHandler.playbackState.value.playing : false;
  Duration get currentPosition => _isInitialized ? _audioHandler.playbackState.value.updatePosition : Duration.zero;
  Duration get totalDuration => _isInitialized ? _audioHandler.mediaItem.value?.duration ?? Duration.zero : Duration.zero;

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
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.music_app.channel.audio',
        androidNotificationChannelName: 'Music Player',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      ),
    );
    print('[MusicPlayerProvider] AudioService.init complete');
    _isInitialized = true;

    // Restore last played song so mini player shows on startup
    final lastSongData = await _historyService.loadLastSong();
    if (lastSongData != null && _pendingSong == null) {
      final song = lastSongData.song;
      song.audioUrl = ''; // force fresh URL fetch on play
      _currentSong = song;
      _lastRestoredPosition = Duration(seconds: lastSongData.lastPositionSeconds);
      print('[MusicPlayerProvider] restored song: ${song.title}, position=${lastSongData.lastPositionSeconds}s');
      notifyListeners();
      // Pre-fetch audio URL in background so play is instant
      _youtubeService.getAudioUrl(song.id).then((url) => song.audioUrl = url);
    }
    
    _audioHandler.playbackState.listen((state) {
      if (state.processingState == AudioProcessingState.completed) {
        nextSong();
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
        // When song is 10 seconds from ending, fetch suggestions in background
        if (duration.inSeconds > 0 && 
            (duration - position).inSeconds <= 10 && 
            !_isFetchingSuggestions &&
            _suggestedSongs.isEmpty) {
          _fetchSuggestionsInBackground();
        }
      }
    });
    
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

  Future<void> playSong(Song song, {List<Song>? queue, Duration? seekTo}) async {
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
    // Don't restart if same song is already playing
    if (_currentSong?.id == song.id && isPlaying) return;

    // Record listen percentage for the song being replaced
    _recordCurrentSongPlay();
    _currentSong = song;
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(song);
    }
    notifyListeners();

    // Clear suggestions when starting a new song
    _suggestedSongs = [];
    String audioUrl = song.audioUrl;
    print('[MusicPlayerProvider] playSong: ${song.title}, audioUrl empty=${audioUrl.isEmpty}, loadingIds=$_loadingAudioIds');
    if (audioUrl.isEmpty) {
      _loadingAudioIds.add(song.id);
      _audioHandler.setNextEnabled(false);
      notifyListeners();
      audioUrl = await _youtubeService.getAudioUrl(song.id);
      print('[MusicPlayerProvider] Audio URL fetched for ${song.title}: ${audioUrl.isEmpty ? "EMPTY" : "OK"}');
      song.audioUrl = audioUrl;
      _loadingAudioIds.remove(song.id);
      _audioHandler.setNextEnabled(true);
    }
    // // Fetch audio URL just before playing
    // String audioUrl = song.audioUrl;
    // if (audioUrl.isEmpty) {
    //   audioUrl = await _youtubeService.getAudioUrl(song.id);
    //   print('[MusicPlayerProvider] Audio URL fetched for ${song.title}: $audioUrl');
    // }
    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: Uri.parse(song.imageUrl),
      duration: song.duration,
    );
    await _audioHandler.setAudioSource(audioUrl, mediaItem);
    if (seekTo != null && seekTo > Duration.zero) {
      await _audioHandler.seek(seekTo);
    }
    await _audioHandler.play();
    _historyService.saveLastSong(song);
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

  Future<void> pause() async {
    if (!_isInitialized) return;
    await _audioHandler.pause();
  }

  Future<void> resume() async {
    if (!_isInitialized) return;
    // If restored from history but never loaded into player, play it now
    if (_currentSong != null && !_audioHandler.playbackState.value.playing &&
        _audioHandler.playbackState.value.processingState == AudioProcessingState.idle) {
      final seekTo = _lastRestoredPosition > Duration.zero ? _lastRestoredPosition : null;
      _lastRestoredPosition = Duration.zero;
      await playSong(_currentSong!, seekTo: seekTo);
      // Remove the old wait-and-seek block
      return;
      return;
    }
    await _audioHandler.play();
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _audioHandler.stop();
  }

  Future<void> seekTo(Duration position) async {
    if (!_isInitialized) return;
    await _audioHandler.seek(position);
  }

  void nextSong() {
    if (!_isInitialized) return;
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _currentIndex++;
      playSong(_queue[_currentIndex]);
    } else if (_currentSong != null && _suggestedSongs.isNotEmpty) {
      // Use already pre-fetched suggestion
      final next = _suggestedSongs.first;
      _suggestedSongs = [];
      _queue.add(next);
      _currentIndex = _queue.length - 1;
      playSong(next);
    } else if (_currentSong != null) {
      _fetchAndPlaySuggestion();
    }
  }

  Future<void> _fetchAndPlaySuggestion() async {
    if (_currentSong == null) return;
    try {
      final suggestions = await _youtubeService.getSuggestedSongs(_currentSong!.id, maxResults: 1);
      if (suggestions.isNotEmpty) {
        _queue.add(suggestions.first);
        _currentIndex = _queue.length - 1;
        playSong(suggestions.first);
      }
    } catch (e) {
      print('Error fetching suggestion: $e');
    }
  }

  void previousSong() {
    if (!_isInitialized) return;
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      playSong(_queue[_currentIndex]);
    }
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    notifyListeners();
  }

  void toggleAutoAddSuggestions() {
    _autoAddSuggestions = !_autoAddSuggestions;
    notifyListeners();
  }

  /// Fetch suggested songs in the background based on current song
  Future<void> _fetchSuggestionsInBackground() async {
    if (_currentSong == null || _isFetchingSuggestions) return;
    
    _isFetchingSuggestions = true;
    notifyListeners();
    
    try {
      print('Fetching suggestions for: ${_currentSong!.title}');
      final suggestions = await _youtubeService.getSuggestedSongs(
        _currentSong!.id,
        maxResults: 5,
      );
      
      _suggestedSongs = suggestions;
      
      // Automatically add suggestions to queue if enabled
      if (_autoAddSuggestions && suggestions.isNotEmpty) {
        _queue.addAll(suggestions);
        print('Added ${suggestions.length} suggestions to queue');
      }
      
    } catch (e) {
      print('Error fetching suggestions: $e');
    } finally {
      _isFetchingSuggestions = false;
      notifyListeners();
    }
  }
  
  /// Pre-fetch audio URLs for a list of songs in the background
  void prefetchAudioUrls(List<Song> songs) {
    for (final song in songs) {
      if (song.audioUrl.isEmpty && !_loadingAudioIds.contains(song.id)) {
        _loadingAudioIds.add(song.id);
        notifyListeners();
        _youtubeService.getAudioUrl(song.id).then((url) {
          song.audioUrl = url;
          _loadingAudioIds.remove(song.id);
          notifyListeners();
        });
      }
    }
  }
  Future<void> fetchSuggestions() async {
    _suggestedSongs = [];
    await _fetchSuggestionsInBackground();
  }

  void _startPositionSaveTimer(Song song) {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentSong?.id == song.id) {
        _historyService.saveLastSong(song, lastPositionSeconds: currentPosition.inSeconds);
      }
    });
  }

  void _recordCurrentSongPlay() {
    if (_currentSong == null) return;
    final position = currentPosition.inSeconds;
    if (position <= 0) return;
    _historyService.recordPlay(_currentSong!, position);
  }

  Future<List<({Song song, int likedCount, int playCount})>> getMostLiked(List<Song> knownSongs) =>
      _historyService.getMostLiked(knownSongs);
  /// Add a suggested song to the queue
  void addSuggestedToQueue(Song song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      notifyListeners();
    }
  }
  
  /// Clear suggested songs list
  void clearSuggestions() {
    _suggestedSongs = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSaveTimer?.cancel();
    if (_isInitialized) {
      _audioHandler.stop();
    }
    super.dispose();
  }
}
