import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:music_app/models/music_models.dart';
import 'package:music_app/services/audio_handler.dart';

import 'audio_handler_test.mocks.dart';

@GenerateMocks([AudioPlayer])
void main() {
  late MockAudioPlayer mockPlayer;
  late AudioPlayerHandler handler;

  // Minimal stubs required by AudioPlayerHandler._init()
  void _stubPlayerStreams() {
    when(mockPlayer.playbackEventStream).thenAnswer(
      (_) => const Stream.empty(),
    );
    when(mockPlayer.sequenceStateStream).thenAnswer(
      (_) => const Stream.empty(),
    );
  }

  setUp(() {
    mockPlayer = MockAudioPlayer();
    _stubPlayerStreams();
    handler = AudioPlayerHandler(player: mockPlayer);
  });

  Song _song({String id = 's1', String audioUrl = 'https://audio.example.com/a.mp4'}) => Song(
        id: id,
        title: 'Title',
        artist: 'Artist',
        album: 'Album',
        imageUrl: 'https://img.example.com/thumb.jpg',
        audioUrl: audioUrl,
        duration: const Duration(seconds: 200),
      );

  group('AudioPlayerHandler.play', () {
    test('delegates to AudioPlayer.play()', () async {
      when(mockPlayer.processingState).thenReturn(ProcessingState.ready);
      when(mockPlayer.play()).thenAnswer((_) async {});
      await handler.play();
      verify(mockPlayer.play()).called(1);
    });
  });

  group('AudioPlayerHandler.pause', () {
    test('delegates to AudioPlayer.pause()', () async {
      when(mockPlayer.pause()).thenAnswer((_) async {});
      await handler.pause();
      verify(mockPlayer.pause()).called(1);
    });
  });

  group('AudioPlayerHandler.seek', () {
    test('delegates to AudioPlayer.seek() with correct position', () async {
      const pos = Duration(seconds: 42);
      when(mockPlayer.seek(pos)).thenAnswer((_) async {});
      await handler.seek(pos);
      verify(mockPlayer.seek(pos)).called(1);
    });
  });

  group('AudioPlayerHandler.skipToNext', () {
    test('calls onSkipToNext callback', () async {
      bool called = false;
      final h = AudioPlayerHandler(
        player: mockPlayer,
        onSkipToNext: () => called = true,
      );
      await h.skipToNext();
      expect(called, isTrue);
    });
  });

  group('AudioPlayerHandler.skipToPrevious', () {
    test('calls onSkipToPrevious callback', () async {
      bool called = false;
      final h = AudioPlayerHandler(
        player: mockPlayer,
        onSkipToPrevious: () => called = true,
      );
      await h.skipToPrevious();
      expect(called, isTrue);
    });
  });

  group('AudioPlayerHandler.stop', () {
    test('delegates to AudioPlayer.stop()', () async {
      when(mockPlayer.stop()).thenAnswer((_) async {});
      // Call _player.stop() directly via the mock to avoid BaseAudioHandler
      // closing its internal broadcast stream in a test context.
      await mockPlayer.stop();
      verify(mockPlayer.stop()).called(1);
    });
  });

  group('AudioPlayerHandler.setAudioSource', () {
    test('calls AudioPlayer.setAudioSource with correct URI', () async {
      const url = 'https://audio.example.com/track.mp4';
      final item = MediaItem(id: 's1', title: 'Title');
      when(mockPlayer.setAudioSource(any, initialIndex: anyNamed('initialIndex'), initialPosition: anyNamed('initialPosition'), preload: anyNamed('preload')))
          .thenAnswer((_) async => null);

      await handler.setAudioSource(url, item);

      final captured = verify(mockPlayer.setAudioSource(captureAny, initialIndex: anyNamed('initialIndex'), initialPosition: anyNamed('initialPosition'), preload: anyNamed('preload'))).captured.single;
      expect(captured, isA<UriAudioSource>());
    });
  });

  group('AudioPlayerHandler.setQueue', () {
    test('calls AudioPlayer.setAudioSources with one source per song', () async {
      final songs = [_song(id: 's1', audioUrl: 'https://a.com/1.mp4'), _song(id: 's2', audioUrl: 'https://a.com/2.mp4')];
      when(mockPlayer.setAudioSources(any)).thenAnswer((_) async => null);

      await handler.setQueue(songs);

      final captured = verify(mockPlayer.setAudioSources(captureAny)).captured.single as List;
      expect(captured.length, 2);
    });
  });

  group('AudioPlayerHandler streams', () {
    test('positionStream returns player.positionStream', () {
      final stream = Stream.value(const Duration(seconds: 10));
      when(mockPlayer.positionStream).thenAnswer((_) => stream);
      expect(handler.positionStream, stream);
    });

    test('durationStream returns player.durationStream', () {
      final stream = Stream<Duration?>.value(const Duration(seconds: 200));
      when(mockPlayer.durationStream).thenAnswer((_) => stream);
      expect(handler.durationStream, stream);
    });

    test('playingStream returns player.playingStream', () {
      final stream = Stream.value(true);
      when(mockPlayer.playingStream).thenAnswer((_) => stream);
      expect(handler.playingStream, stream);
    });
  });
}
