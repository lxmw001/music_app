import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/music_models.dart';
import '../services/audio_handler.dart';
import '../services/youtube_service.dart';

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

  Future<void> playSong(Song song, {List<Song>? queue});
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
}

class MusicPlayerProviderImpl extends MusicPlayerProvider {
  late AudioPlayerHandler _audioHandler;
  final YouTubeService _youtubeService = YouTubeService();
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

  MusicPlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.music_app.channel.audio',
        androidNotificationChannelName: 'Music Player',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      ),
    );
    _isInitialized = true;
    
    _audioHandler.playbackState.listen((_) {
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
      await playSong(song!, queue: queue);
    }
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (!_isInitialized) {
      _pendingSong = song;
      _pendingQueue = queue;
      return;
    }
    // Show song immediately in UI while audio URL is being fetched
    _currentSong = song;
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(song);
    }
    notifyListeners();

    // Clear suggestions when starting a new song
    _suggestedSongs = [];
    String audioUrl = song.audioUrl;
    if (audioUrl.isEmpty) {
      _loadingAudioIds.add(song.id);
      notifyListeners();
      audioUrl = await _youtubeService.getAudioUrl(song.id);
      print('[MusicPlayerProvider] Audio URL fetched for ${song.title}: $audioUrl');
      song.audioUrl = audioUrl;
      _loadingAudioIds.remove(song.id);
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
    await _audioHandler.play();
    notifyListeners();
  }

  Future<void> pause() async {
    if (!_isInitialized) return;
    await _audioHandler.pause();
  }

  Future<void> resume() async {
    if (!_isInitialized) return;
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
    _suggestedSongs = []; // Clear previous suggestions
    await _fetchSuggestionsInBackground();
  }
  
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
    if (_isInitialized) {
      _audioHandler.stop();
    }
    super.dispose();
  }
}
