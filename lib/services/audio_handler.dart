import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show AudioStreamInfo;
import '../models/music_models.dart';
import 'youtube_service.dart';

/// Streams audio using youtube_explode_dart's own getStream() which correctly
/// handles rqh=1/svpuc=1 signed YouTube URLs. The library's stream fetcher uses
/// chunked range requests internally — the only method proven to work.
/// just_audio serves bytes via http://127.0.0.1/id/<uuid> so MPV never calls YouTube.
class _YtLibStreamSource extends StreamAudioSource {
  final AudioStreamInfo streamInfo;
  final Stream<List<int>> Function(int start) getStream;

  _YtLibStreamSource(this.streamInfo, this.getStream, {dynamic tag})
      : super(tag: tag);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final totalBytes = streamInfo.size.totalBytes;
    debugPrint('[YtLibStream] request start=$from total=$totalBytes mime=${streamInfo.codec.mimeType}');
    return StreamAudioResponse(
      sourceLength: totalBytes,
      contentLength: totalBytes - from,
      offset: from,
      stream: getStream(from),
      contentType: streamInfo.codec.mimeType,
    );
  }
}

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  YouTubeService? _ytService;
  final VoidCallback? onSkipToNext;
  final VoidCallback? onSkipToPrevious;
  final VoidCallback? onPlay;

  AudioPlayerHandler({AudioPlayer? player, YouTubeService? ytService, this.onSkipToNext, this.onSkipToPrevious, this.onPlay})
      : _player = player ?? AudioPlayer(androidApplyAudioAttributes: false),
        _ytService = ytService {
    _init();
  }

  void updateYtService(YouTubeService service) => _ytService = service;

  void _init() {
    // Throttle playbackState updates to ~4/sec to avoid Android notification rate limit
    DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    PlaybackState? pending;
    Timer? throttleTimer;

    void emit(PlaybackState state) {
      final now = DateTime.now();
      if (now.difference(lastEmit).inMilliseconds >= 250) {
        lastEmit = now;
        playbackState.add(state);
      } else {
        pending = state;
        throttleTimer ??= Timer(const Duration(milliseconds: 250), () {
          throttleTimer = null;
          if (pending != null) {
            lastEmit = DateTime.now();
            playbackState.add(pending!);
            pending = null;
          }
        });
      }
    }

    _player.playbackEventStream.map(_transformEvent).listen(emit);
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
      onPlay?.call();
    } else {
      await _player.play();
      final current = mediaItem.value;
      if (current != null) mediaItem.add(current);
      playbackState.add(_transformEvent(_player.playbackEvent));
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  Future<void> setAudioSource(String url, MediaItem item, {String? videoId}) async {
    final isLocal = url.startsWith('/') || url.startsWith('file://');

    // On Android, use youtube_explode_dart's own stream fetcher (_YtLibStreamSource).
    // This is the only method proven to work with rqh=1/svpuc=1 signed URLs.
    // The library's getStream() handles chunked requests internally.
    // just_audio serves bytes via http://127.0.0.1/id/<uuid> — MPV never calls YouTube.
    if (!isLocal && defaultTargetPlatform == TargetPlatform.android
        && _ytService != null && videoId != null && videoId.isNotEmpty) {
      try {
        final result = await _ytService!.getAudioStreamInfo(videoId);
        if (result != null) {
          debugPrint('[AudioHandler] _YtLibStreamSource for $videoId mime=${result.info.codec.mimeType}');
          final source = _YtLibStreamSource(result.info, result.stream, tag: item);
          await _player.setAudioSource(source);
          mediaItem.add(item);
          playbackState.add(_transformEvent(_player.playbackEvent));
          return;
        }
      } catch (e) {
        debugPrint('[AudioHandler] _YtLibStreamSource failed for $videoId: $e — falling back');
      }
    }

    // Fallback: URI source with headers (works on iOS/desktop, fallback on Android)
    final uri = isLocal ? Uri.file(url) : Uri.parse(url);
    final headers = isLocal ? null : (_isWebm(url) ? null : _headersForUrl(url));
    await _player.setAudioSource(AudioSource.uri(uri,
      tag: item,
      headers: (headers == null || headers.isEmpty) ? null : headers,
    ));
    mediaItem.add(item);
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  Map<String, String> _headersForUrl(String url) {
    // Match YoutubeHttpClient.defaultHeaders — what youtube_explode_dart uses.
    return {
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36',
      'cookie': 'CONSENT=YES+cb',
      'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
      'accept-language': 'en-US,en;q=0.5',
    };
  }

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
