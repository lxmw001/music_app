import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_models.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player;

  AudioPlayerHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _init();
  }

  void _init() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.sequenceStateStream.listen((sequenceState) {
      final currentItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (currentItem != null) {
        mediaItem.add(currentItem);
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
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
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  Future<void> setAudioSource(String url, MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': 'https://www.youtube.com/',
        },
      ),
    );
  }

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
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
}
