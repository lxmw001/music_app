import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/music_models.dart';
import '../services/audio_handler.dart';

class MusicPlayerProvider extends ChangeNotifier {
  late AudioPlayerHandler _audioHandler;
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isShuffled = false;
  bool _isRepeating = false;
  bool _isInitialized = false;

  Song? _pendingSong;
  List<Song>? _pendingQueue;

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  bool get isShuffled => _isShuffled;
  bool get isRepeating => _isRepeating;
  bool get isInitialized => _isInitialized;

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
    _currentSong = song;
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(song);
      await _audioHandler.setQueue(queue);
    }
    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      artUri: Uri.parse(song.imageUrl),
      duration: song.duration,
    );
    await _audioHandler.setAudioSource(song.audioUrl, mediaItem);
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
      _currentSong = _queue[_currentIndex];
      _audioHandler.skipToNext();
      notifyListeners();
    }
  }

  void previousSong() {
    if (!_isInitialized) return;
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      _currentSong = _queue[_currentIndex];
      _audioHandler.skipToPrevious();
      notifyListeners();
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

  @override
  void dispose() {
    if (_isInitialized) {
      _audioHandler.stop();
    }
    super.dispose();
  }
}
