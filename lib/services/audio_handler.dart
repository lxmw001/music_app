import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_models.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  final VoidCallback? onSkipToNext;
  final VoidCallback? onSkipToPrevious;

  AudioPlayerHandler({AudioPlayer? player, this.onSkipToNext, this.onSkipToPrevious})
      : _player = player ?? AudioPlayer() {
    _init();
  }

  void _init() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.sequenceStateStream.listen((sequenceState) {
      final currentItem = sequenceState.currentSource?.tag as MediaItem?;
      if (currentItem != null) {
        mediaItem.add(currentItem);
      }
    });
  }

  bool _nextEnabled = true;
  set nextEnabled(bool value) => _nextEnabled = value;

  List<MediaControl> _buildControls() => [
    MediaControl.skipToPrevious,
    if (_player.playing) MediaControl.pause else MediaControl.play,
    if (_nextEnabled) MediaControl.skipToNext,
  ];

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: _buildControls(),
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  AudioSource _buildSource(String url, MediaItem item) {
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final uri = isLocal ? Uri.file(url) : Uri.parse(url);
    return AudioSource.uri(uri,
      tag: item,
      headers: isLocal ? null : {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.youtube.com/',
      },
    );
  }

  Future<void> setAudioSource(String url, MediaItem item) async {
    this.mediaItem.add(item);
    _playlist = ConcatenatingAudioSource(children: [_buildSource(url, item)]);
    await _player.setAudioSource(_playlist, initialIndex: 0);
  }

  /// Append next song to the playlist so just_audio buffers it in background.
  Future<void> setNextSource(String url, MediaItem item) async {
    if (_playlist.length > 1) {
      await _playlist.removeAt(1);
    }
    await _playlist.add(_buildSource(url, item));
    print('[AudioHandler] next source queued for buffering: ${item.title}');
  }

  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  Future<void> setQueue(List<Song> songs) async {
    final audioSources = songs.map((song) => AudioSource.uri(
      Uri.parse(song.audioUrl),
      tag: MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        artUri: Uri.parse(song.imageUrl),
        duration: song.duration,
      ),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.youtube.com/',
      },
    )).toList();

    await _player.setAudioSources(audioSources);
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get currentPosition => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
}
