import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_models.dart';
import 'youtube_web_player.dart';

/// Audio player handler that routes YouTube playback to a native WebView
/// (YouTube IFrame API) on Android, and uses just_audio for local files
/// and non-Android platforms.
class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  final YouTubeWebPlayer _webPlayer;
  final VoidCallback? onSkipToNext;
  final VoidCallback? onSkipToPrevious;
  final VoidCallback? onPlay;

  bool _usingWebView = false;
  StreamSubscription? _webStateSub;
  StreamSubscription? _webPlayingSub;
  StreamSubscription? _webErrorSub;

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  AudioPlayerHandler({
    AudioPlayer? player,
    YouTubeWebPlayer? webPlayer,
    this.onSkipToNext,
    this.onSkipToPrevious,
    this.onPlay,
  })  : _player = player ?? AudioPlayer(androidApplyAudioAttributes: false),
        _webPlayer = webPlayer ?? YouTubeWebPlayer.instance {
    _init();
  }

  void _init() {
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

    // Listen to WebView player events
    _webStateSub = _webPlayer.stateStream.listen((_) {
      if (_usingWebView) _emitWebViewState();
    });
    _webPlayingSub = _webPlayer.playingStream.listen((_) {
      if (_usingWebView) _emitWebViewState();
    });
    _webErrorSub = _webPlayer.errorStream.listen((error) {
      debugPrint('[AudioHandler] WebView error: $error');
    });
  }

  void _emitWebViewState() {
    final state = _webPlayer.state;
    final playing = _webPlayer.isPlaying;
    final processingState = switch (state) {
      YtWebPlayerState.idle => AudioProcessingState.idle,
      YtWebPlayerState.loading => AudioProcessingState.loading,
      YtWebPlayerState.ready => AudioProcessingState.ready,
      YtWebPlayerState.playing => AudioProcessingState.ready,
      YtWebPlayerState.paused => AudioProcessingState.ready,
      YtWebPlayerState.buffering => AudioProcessingState.buffering,
      YtWebPlayerState.ended => AudioProcessingState.completed,
      YtWebPlayerState.error => AudioProcessingState.error,
    };

    playbackState.add(PlaybackState(
      controls: _buildControls(playing),
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _webPlayer.position,
      bufferedPosition: _webPlayer.position,
      speed: 1.0,
      queueIndex: 0,
    ));
  }

  bool _nextEnabled = true;
  set nextEnabled(bool value) => _nextEnabled = value;

  List<MediaControl> _buildControls(bool playing) => [
    MediaControl.skipToPrevious,
    if (playing) MediaControl.pause else MediaControl.play,
    if (_nextEnabled) MediaControl.skipToNext,
  ];

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: _buildControls(_player.playing),
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
    if (_usingWebView) {
      await _webPlayer.play();
      final current = mediaItem.value;
      if (current != null) mediaItem.add(current);
      _emitWebViewState();
    } else if (_player.processingState == ProcessingState.idle) {
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
    if (_usingWebView) {
      await _webPlayer.pause();
      _emitWebViewState();
    } else {
      await _player.pause();
      playbackState.add(_transformEvent(_player.playbackEvent));
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_usingWebView) {
      await _webPlayer.seek(position);
    } else {
      await _player.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  @override
  Future<void> stop() async {
    if (_usingWebView) {
      await _webPlayer.stop();
      _usingWebView = false;
    }
    await _player.stop();
    return super.stop();
  }

  Future<void> setAudioSource(String url, MediaItem item, {String? videoId}) async {
    final isLocal = url.startsWith('/') || url.startsWith('file://');

    // On Android, route YouTube playback through the WebView IFrame player.
    // This bypasses rqh=1/PO-token restrictions that block direct HTTP streams.
    if (!isLocal && _isAndroid && videoId != null && videoId.isNotEmpty) {
      debugPrint('[AudioHandler] Using WebView player for $videoId');
      _usingWebView = true;
      try { await _player.stop(); } catch (_) {}
      mediaItem.add(item);
      await _webPlayer.load(videoId, autoplay: true);
      _emitWebViewState();
      return;
    }

    // Local files and non-Android: use just_audio
    _usingWebView = false;
    final uri = isLocal ? Uri.file(url) : Uri.parse(url);
    final headers = isLocal ? null : _headersForUrl(url);
    await _player.setAudioSource(AudioSource.uri(
      uri,
      tag: item,
      headers: (headers == null || headers.isEmpty) ? null : headers,
    ));
    mediaItem.add(item);
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  Map<String, String> _headersForUrl(String url) {
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
      headers: _headersForUrl(song.audioUrl),
    )).toList();
    await _player.setAudioSources(audioSources);
  }

  // Position/duration getters — delegate to WebView when active
  Stream<Duration> get positionStream =>
      _usingWebView ? _webPlayer.positionStream : _player.positionStream;
  Duration get currentPosition =>
      _usingWebView ? _webPlayer.position : _player.position;
  Duration get duration =>
      _usingWebView ? _webPlayer.duration : (_player.duration ?? Duration.zero);
  Stream<Duration?> get durationStream =>
      _usingWebView ? _webPlayer.durationStream.map((d) => d) : _player.durationStream;
  Stream<bool> get playingStream =>
      _usingWebView ? _webPlayer.playingStream : _player.playingStream;

  void dispose() {
    _webStateSub?.cancel();
    _webPlayingSub?.cancel();
    _webErrorSub?.cancel();
  }
}
