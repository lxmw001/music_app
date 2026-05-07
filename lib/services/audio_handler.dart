import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_models.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  final VoidCallback? onSkipToNext;
  final VoidCallback? onSkipToPrevious;
  final VoidCallback? onPlay;

  AudioPlayerHandler({AudioPlayer? player, this.onSkipToNext, this.onSkipToPrevious, this.onPlay})
      : _player = player ?? AudioPlayer(androidApplyAudioAttributes: false) {
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
  Future<void> play() async {
    if (_player.processingState == ProcessingState.idle) {
      // Nothing loaded — delegate to provider to resume last song
      onPlay?.call();
    } else {
      await _player.play();
    }
  }

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

  Future<void> setAudioSource(String url, MediaItem item) async {
    this.mediaItem.add(item);
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final uri = isLocal ? Uri.file(url) : Uri.parse(url);
    final headers = isLocal ? null : (_isWebm(url) ? null : _headersForUrl(url));
    await _player.setAudioSource(AudioSource.uri(uri,
      tag: item,
      headers: (headers == null || headers.isEmpty) ? null : headers,
    ));
  }

  Map<String, String> _headersForUrl(String url) {
    if (url.contains('c=ANDROID_VR')) {
      return {
        'User-Agent': 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
        'X-Youtube-Client-Name': 'ANDROID_VR',
        'X-Youtube-Client-Version': '1.56.21',
      };
    }
    if (url.contains('c=ANDROID_MUSIC')) {
      return {
        'User-Agent': 'com.google.android.apps.youtube.music/7.16.52 (Linux; U; Android 11) gzip',
        'X-Youtube-Client-Name': 'ANDROID_MUSIC',
        'X-Youtube-Client-Version': '7.16.52',
      };
    }
    if (url.contains('c=ANDROID')) {
      return {
        'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
        'X-Youtube-Client-Name': 'ANDROID',
        'X-Youtube-Client-Version': '20.10.38',
      };
    }
    if (url.contains('c=IOS')) {
      return {
        'User-Agent': 'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)',
        'X-Youtube-Client-Name': 'IOS',
        'X-Youtube-Client-Version': '19.29.1',
      };
    }
    return {
      'User-Agent': 'Mozilla/5.0 (SmartHub; SMART-TV; Linux/SmartTV) AppleWebKit/538.1',
      'Referer': 'https://www.youtube.com/',
    };
  }

  /// Check if URL is a WebM/Opus stream
  bool _isWebm(String url) => url.contains('mime=audio%2Fwebm') || url.contains('mime=audio/webm');

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
