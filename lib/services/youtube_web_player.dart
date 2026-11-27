import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Player state mirroring YouTube IFrame API states.
enum YtWebPlayerState {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  ended,
  error,
}

const _channelName = 'com.lxmw.musicapp/youtube_surface';

/// Dart facade for the native Android WebView hosting the YouTube IFrame API.
///
/// On Android, YouTube audio is played through a hidden native WebView using
/// the YouTube IFrame Player API. This bypasses the rqh=1/PO-token restrictions
/// that block direct HTTP audio stream requests.
///
/// Commands are queued until the IFrame API reports `ready`.
class YouTubeWebPlayer {
  YouTubeWebPlayer._();
  static final YouTubeWebPlayer instance = YouTubeWebPlayer._();

  final MethodChannel _channel = const MethodChannel(_channelName);
  bool _isReady = false;
  bool _initialized = false;
  final _commandQueue = <_PendingCommand>[];

  // Broadcast streams
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _stateController = StreamController<YtWebPlayerState>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _loadedController = StreamController<String>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<YtWebPlayerState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<String> get loadedStream => _loadedController.stream;

  bool get isReady => _isReady;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  YtWebPlayerState _state = YtWebPlayerState.idle;
  double _volume = 1.0;

  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  YtWebPlayerState get state => _state;
  double get volume => _volume;

  /// Initialize the native WebView and set up event listener.
  Future<void> ensureReady() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      await _channel.invokeMethod('ensureReady');
    } catch (e) {
      debugPrint('[YouTubeWebPlayer] ensureReady failed: $e');
      _initialized = false;
    }
  }

  /// Check if overlay permission is granted (needed for background playback).
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request overlay permission. Opens system settings.
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('[YouTubeWebPlayer] requestOverlayPermission failed: $e');
    }
  }

  /// Move WebView to overlay window for background playback.
  Future<void> moveToOverlay() async {
    try {
      await _channel.invokeMethod('moveToOverlay');
    } catch (e) {
      debugPrint('[YouTubeWebPlayer] moveToOverlay failed: $e');
    }
  }

  /// Ensure the WebView lives in the overlay window (needed so YouTube's
  /// embed visibility check passes — covered views pause after ~40s).
  /// Requests the SYSTEM_ALERT_WINDOW permission the first time.
  Future<void> ensureOverlay() async {
    try {
      if (await hasOverlayPermission()) {
        await moveToOverlay();
      } else {
        // Opens system settings; the user grants "Display over other apps".
        await requestOverlayPermission();
      }
    } catch (e) {
      debugPrint('[YouTubeWebPlayer] ensureOverlay failed: $e');
    }
  }

  Future<void> load(String videoId, {Duration? start, bool autoplay = true}) async {
    _sendCommand('load', {
      'videoId': videoId,
      'startMs': start?.inMilliseconds ?? 0,
      'autoplay': autoplay,
    });
    _loadedController.add(videoId);
  }

  Future<void> crossfadeTo(String videoId, {Duration? start}) async {
    _sendCommand('crossfade', {
      'videoId': videoId,
      'startMs': start?.inMilliseconds ?? 0,
    });
    _loadedController.add(videoId);
  }

  Future<void> play() async => _sendCommand('play', {});
  Future<void> pause() async => _sendCommand('pause', {});
  Future<void> seek(Duration position) async => _sendCommand('seek', {'positionMs': position.inMilliseconds});
  Future<void> stop() async => _sendCommand('stop', {});
  Future<void> releaseWakeLock() async {
    try {
      await _channel.invokeMethod('releaseWakeLock');
    } catch (_) {}
  }
  Future<void> setVolume(double vol) async {
    _volume = vol;
    _sendCommand('setVolume', {'volume': vol});
  }

  /// Get current position from the WebView.
  Future<Duration> getPosition() async {
    try {
      final ms = await _channel.invokeMethod<int>('getPosition');
      if (ms != null) _position = Duration(milliseconds: ms);
      return _position;
    } catch (_) {
      return _position;
    }
  }

  /// Get current duration from the WebView.
  Future<Duration> getDuration() async {
    try {
      final ms = await _channel.invokeMethod<int>('getDuration');
      if (ms != null && ms > 0) _duration = Duration(milliseconds: ms);
      return _duration;
    } catch (_) {
      return _duration;
    }
  }

  void _sendCommand(String command, Map<String, dynamic> args) {
    if (_isReady) {
      _channel.invokeMethod('cmd', {'command': command, ...args});
    } else {
      _commandQueue.add(_PendingCommand(command, args));
    }
  }

  void _flushQueue() {
    for (final cmd in _commandQueue) {
      _channel.invokeMethod('cmd', {'command': cmd.command, ...cmd.args});
    }
    _commandQueue.clear();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onEvent') return;
    try {
      final raw = call.arguments as String;
      debugPrint('[YouTubeWebPlayer] event: $raw');
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final type = envelope['type'] as String?;
      // HTML wraps payload in envelope['data'] — flatten it for convenience
      final data = (envelope['data'] as Map<String, dynamic>?) ?? {};
      switch (type) {
        case 'ready':
          // Fire _isReady only when both players are ready (allReady: true)
          if (data['allReady'] == true || !_isReady) {
            _isReady = true;
            _state = YtWebPlayerState.ready;
            _stateController.add(YtWebPlayerState.ready);
            _flushQueue();
          }
          break;
        case 'stateChange':
          final stateCode = data['state'] as int?;
          _state = _mapState(stateCode);
          // Update _isPlaying BEFORE firing the state stream — the handler
          // (audio_handler) reads isPlaying inside its listener, and it must
          // already reflect the new state at that point.
          _isPlaying = _state == YtWebPlayerState.playing;
          _stateController.add(_state);
          _playingController.add(_isPlaying);
          break;
        case 'timeUpdate':
          // HTML sends seconds (double), convert to Duration
          final posSec = (data['position'] as num?)?.toDouble();
          final durSec = (data['duration'] as num?)?.toDouble();
          if (posSec != null) {
            _position = Duration(milliseconds: (posSec * 1000).round());
            _positionController.add(_position);
          }
          if (durSec != null && durSec > 0) {
            _duration = Duration(milliseconds: (durSec * 1000).round());
            _durationController.add(_duration);
          }
          break;
        case 'error':
          final code = data['code'] as int?;
          final message = data['message'] as String? ?? 'Unknown error (code: $code)';
          _state = YtWebPlayerState.error;
          _stateController.add(YtWebPlayerState.error);
          _errorController.add('$code:$message'); // format: "code:message"
          break;
        case 'loaded':
          final videoId = data['videoId'] as String?;
          if (videoId != null) _loadedController.add(videoId);
          break;
      }
    } catch (e) {
      debugPrint('[YouTubeWebPlayer] event parse error: $e');
    }
  }

  YtWebPlayerState _mapState(int? code) {
    switch (code) {
      case -1: return YtWebPlayerState.idle; // unstarted
      case 0: return YtWebPlayerState.ended;
      case 1: return YtWebPlayerState.playing;
      case 2: return YtWebPlayerState.paused;
      case 3: return YtWebPlayerState.buffering;
      case 5: return YtWebPlayerState.ready; // cued
      default: return YtWebPlayerState.idle;
    }
  }

  void dispose() {
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _stateController.close();
    _errorController.close();
    _loadedController.close();
    _initialized = false;
    _isReady = false;
  }
}

class _PendingCommand {
  final String command;
  final Map<String, dynamic> args;
  _PendingCommand(this.command, this.args);
}
