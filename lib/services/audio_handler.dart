import 'dart:async';
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
  /// Called when IFrame embedding is disabled (error 101/150/152).
  /// Provides the videoId so the caller can fall back to server proxy.
  final void Function(String videoId)? onEmbeddingError;

  bool _usingWebView = false;
  String? _currentVideoId;
  MediaItem? _currentItem;
  StreamSubscription? _webStateSub;
  StreamSubscription? _webPlayingSub;
  StreamSubscription? _webErrorSub;

  /// True when the WebView IFrame player is the active backend. Used by the
  /// provider to treat YouTube 'ended' as authoritative song completion.
  bool get isUsingWebView => _usingWebView;

  // Merged streams: just_audio OR WebView events, whichever backend is active.
  // The provider subscribes once at init, so a getter that switches on
  // _usingWebView at read time would permanently bind to the wrong backend.
  final _positionMerger = StreamController<Duration>.broadcast();
  final _durationMerger = StreamController<Duration?>.broadcast();
  final _playingMerger = StreamController<bool>.broadcast();

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  AudioPlayerHandler({
    AudioPlayer? player,
    YouTubeWebPlayer? webPlayer,
    this.onSkipToNext,
    this.onSkipToPrevious,
    this.onPlay,
    this.onEmbeddingError,
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

    // Forward just_audio streams into merged controllers (only when not using WebView)
    _player.positionStream.listen((p) { if (!_usingWebView) _positionMerger.add(p); });
    _player.durationStream.listen((d) { if (!_usingWebView) _durationMerger.add(d); });
    _player.playingStream.listen((v) { if (!_usingWebView) _playingMerger.add(v); });

    // Listen to WebView player events
    _webStateSub = _webPlayer.stateStream.listen((state) {
      if (_usingWebView) {
        _emitWebViewState();
        _playingMerger.add(_webPlayer.isPlaying);
        // When the YouTube player finishes the video, emit completed so the
        // provider's playbackState listener can advance to the next song.
        // Also call onSkipToNext directly — the provider's completed guard
        // (wasPlaying + nearEnd heuristics) can fail when duration/position
        // data is stale at the moment the event arrives.
        if (state == YtWebPlayerState.ended) {
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
            playing: false,
          ));
          // Small delay so the playbackState listener fires first; if it
          // already called nextSong the skip below is a no-op because
          // _isSwitchingSong will be true.
          Future.delayed(const Duration(milliseconds: 400), () {
            if (_usingWebView == false) return; // already switched
            onSkipToNext?.call();
          });
        }
      }
    });
    _webPlayingSub = _webPlayer.playingStream.listen((v) {
      if (_usingWebView) _playingMerger.add(v);
    });
    _webPlayer.positionStream.listen((p) { if (_usingWebView) _positionMerger.add(p); });
    _webPlayer.durationStream.listen((d) { if (_usingWebView) _durationMerger.add(d); });
    _webErrorSub = _webPlayer.errorStream.listen((error) {
      debugPrint('[AudioHandler] WebView error: $error');
      if (!_usingWebView) return;
      // Error format: "code:message" — codes 101/150/152 mean embedding disabled
      final code = int.tryParse(error.split(':').first);
      if (code == 101 || code == 150 || code == 152) {
        final vid = _currentVideoId;
        if (vid != null) {
          debugPrint('[AudioHandler] Embedding disabled for $vid, triggering fallback');
          _usingWebView = false;
          onEmbeddingError?.call(vid);
        }
      }
    });
  }

  void _emitWebViewState() {
    _emitWebViewStatePlaying(_webPlayer.isPlaying);
  }

  /// Emit a WebView playback state with an explicit playing value. Used right
  /// after play()/pause() so the UI reflects the intent immediately, before
  /// the async JS stateChange event confirms it.
  void _emitWebViewStatePlaying(bool playing) {
    _playingMerger.add(playing);
    final processingState = _webPlayer.state == YtWebPlayerState.error
        ? AudioProcessingState.error
        : AudioProcessingState.ready;
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
      // Emit playing=true immediately — don't wait for the async stateChange
      // event from JS, which arrives after a round-trip and would otherwise
      // leave the UI showing the wrong icon until the next event.
      _emitWebViewStatePlaying(true);
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
      // Emit playing=false immediately — same reason as play() above.
      _emitWebViewStatePlaying(false);
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
      await _webPlayer.releaseWakeLock();
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
      _currentVideoId = videoId;
      _currentItem = item;
      try { await _player.stop(); } catch (_) {}
      mediaItem.add(item);
      // Park the WebView in the overlay window — a covered WebView makes
      // YouTube's embed visibility check fail, pausing playback after ~40s.
      await _webPlayer.ensureOverlay();
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

  // Position/duration getters — always use merged streams so the provider's
  // subscriptions (created once at init) receive events from whichever backend
  // is currently active.
  Stream<Duration> get positionStream => _positionMerger.stream;
  Duration get currentPosition =>
      _usingWebView ? _webPlayer.position : _player.position;
  Duration get duration =>
      _usingWebView ? _webPlayer.duration : (_player.duration ?? Duration.zero);
  Stream<Duration?> get durationStream => _durationMerger.stream;
  Stream<bool> get playingStream => _playingMerger.stream;

  void dispose() {
    _webStateSub?.cancel();
    _webPlayingSub?.cancel();
    _webErrorSub?.cancel();
  }
}
