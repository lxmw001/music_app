import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/music_models.dart';
import '../services/audio_handler.dart';

import 'dart:developer';

class MusicPlayerProvider extends ChangeNotifier {
  static int instanceCount = 0;
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

  bool get isPlaying {
    log('isPlaying accessed: initialized=$_isInitialized');
    return _isInitialized ? _audioHandler.playbackState.value.playing : false;
  }
  Duration get currentPosition {
    log('currentPosition accessed: initialized=$_isInitialized');
    return _isInitialized ? _audioHandler.playbackState.value.updatePosition : Duration.zero;
  }
  Duration get totalDuration {
    log('totalDuration accessed: initialized=$_isInitialized');
    return _isInitialized ? _audioHandler.mediaItem.value?.duration ?? Duration.zero : Duration.zero;
  }

  MusicPlayerProvider() {
    instanceCount++;
    log("MusicPlayerProvider constructed: hashCode=", name: hashCode.toString());
    log("MusicPlayerProvider instanceCount: $instanceCount");
    log("init before");
    _init();
    
  }

  Future<void> _init() async {
    log('AudioHandler initialization started');
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
    log('AudioHandler initialization complete');
    _audioHandler.playbackState.listen((_) {
      log('Playback state changed');
      notifyListeners();
    });
    _audioHandler.mediaItem.listen((_) {
      log('Media item changed');
      notifyListeners();
    });
    notifyListeners();
    // If there was a pending playSong call, process it now
    if (_pendingSong != null) {
      log('Processing pending playSong after initialization');
      final song = _pendingSong;
      final queue = _pendingQueue;
      _pendingSong = null;
      _pendingQueue = null;
      await playSong(song!, queue: queue);
    }
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    log('playSong called: initialized=$_isInitialized, song=${song.title}, provider hashCode=$hashCode');
    if (!_isInitialized) {
      log('playSong queued: not initialized, provider hashCode=$hashCode');
      _pendingSong = song;
      _pendingQueue = queue;
      return;
    }
    _currentSong = song;
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(song);
      log('Queue set with ${queue.length} songs, currentIndex=$_currentIndex');
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
    log('Playback started for ${song.title}');
    notifyListeners();
  }

  Future<void> pause() async {
    log('pause called: initialized=$_isInitialized');
    if (!_isInitialized) return;
    await _audioHandler.pause();
    log('Playback paused');
  }

  Future<void> resume() async {
    log('resume called: initialized=$_isInitialized');
    if (!_isInitialized) return;
    await _audioHandler.play();
    log('Playback resumed');
  }

  Future<void> stop() async {
    log('stop called: initialized=$_isInitialized');
    if (!_isInitialized) return;
    await _audioHandler.stop();
    log('Playback stopped');
  }

  Future<void> seekTo(Duration position) async {
    log('seekTo called: initialized=$_isInitialized, position=$position');
    if (!_isInitialized) return;
    await _audioHandler.seek(position);
    log('Seeked to $position');
  }

  void nextSong() {
    log('nextSong called: initialized=$_isInitialized');
    if (!_isInitialized) return;
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _currentIndex++;
      _currentSong = _queue[_currentIndex];
      log('Next song: ${_currentSong?.title}');
      _audioHandler.skipToNext();
      notifyListeners();
    }
  }

  void previousSong() {
    log('previousSong called: initialized=$_isInitialized');
    if (!_isInitialized) return;
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      _currentSong = _queue[_currentIndex];
      log('Previous song: ${_currentSong?.title}');
      _audioHandler.skipToPrevious();
      notifyListeners();
    }
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    log('toggleShuffle: now $_isShuffled');
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    log('toggleRepeat: now $_isRepeating');
    notifyListeners();
  }

  @override
  void dispose() {
    log('dispose called: initialized=$_isInitialized');
    if (_isInitialized) {
      _audioHandler.stop();
      log('AudioHandler stopped in dispose');
    }
    super.dispose();
  }
}
