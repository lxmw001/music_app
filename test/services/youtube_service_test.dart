import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:music_app/services/youtube_service.dart';
import 'package:music_app/services/music_server_service.dart';
import 'package:music_app/services/gemini_service.dart';

import 'youtube_service_test.mocks.dart';

@GenerateMocks([YoutubeGateway, http.Client, MusicServerService, GeminiService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockYoutubeGateway mockGateway;
  late MockClient mockHttpClient;
  late MockMusicServerService mockServer;
  late MockGeminiService mockGemini;
  late YouTubeService service;

  // VideoId requires a valid 11-character YouTube video ID format
  const ids = [
    'dQw4w9WgXcQ', 'jNQXAC9IVRw', 'kJQP7kiw5Fk', 'OPf0YbXqDm0',
    'YQHsXMglC9A', 'fJ9rUzIMcZQ', 'hT_nvWreIhg', 'CevxZvSJLk8',
  ];

  Video _fakeVideo({
    String? id,
    String title = 'Test Song',
    String author = 'Test Artist',
    Duration? duration,
  }) {
    final videoId = id ?? ids[0];
    return Video(
      VideoId(videoId),
      title,
      author,
      ChannelId('UC_x5XG1OV2P6uZZ5FSM9Ttw'),
      DateTime(2024),
      null,
      null,
      '',
      duration ?? const Duration(seconds: 200),
      ThumbnailSet(videoId),
      null,
      Engagement(1000, null, null),
      false,
    );
  }

  setUp(() {
    mockGateway = MockYoutubeGateway();
    mockHttpClient = MockClient();
    mockServer = MockMusicServerService();
    mockGemini = MockGeminiService();
    when(mockServer.searchSongs(any)).thenAnswer((_) async => []);
    when(mockServer.getTrending(limit: anyNamed('limit'))).thenAnswer((_) async => []);
    when(mockGemini.getSongMetadata(any)).thenAnswer((_) async => null);
    service = YouTubeService(gateway: mockGateway, httpClient: mockHttpClient, server: mockServer, gemini: mockGemini);
  });

  group('YouTubeService.searchSongs', () {
    test('returns songs mapped from gateway results', () async {
      final videos = List.generate(3, (i) => _fakeVideo(id: ids[i], title: 'Song $i'));
      when(mockGateway.search(any, limit: anyNamed('limit')))
          .thenAnswer((_) async => videos);

      final result = await service.searchSongs('test');

      expect(result.length, 3);
      expect(result[0].title, 'Song 0');
      expect(result[0].audioUrl, ''); // not pre-fetched
    });

    test('returns empty list on exception', () async {
      when(mockGateway.search(any, limit: anyNamed('limit')))
          .thenThrow(Exception('network error'));

      final result = await service.searchSongs('test');

      expect(result, isEmpty);
    });

    test('maps video fields to Song correctly', () async {
      final video = _fakeVideo(
          id: 'dQw4w9WgXcQ', title: 'My Song', author: 'My Artist', duration: const Duration(seconds: 180));
      when(mockGateway.search(any, limit: anyNamed('limit')))
          .thenAnswer((_) async => [video]);

      final result = await service.searchSongs('My Song');

      final song = result.first;
      expect(song.id, 'dQw4w9WgXcQ');
      expect(song.title, 'My Song');
      expect(song.artist, 'My Artist');
      expect(song.album, '');
      expect(song.duration, const Duration(seconds: 180));
    });
  });

  group('YouTubeService.getAudioUrl', () {
    test('returns URL from gateway', () async {
      when(mockGateway.getAudioUrl('vid1'))
          .thenAnswer((_) async => 'https://audio.example.com/stream.mp4');

      final url = await service.getAudioUrl('vid1');

      expect(url, 'https://audio.example.com/stream.mp4');
    });

    test('returns empty string on exception', () async {
      when(mockGateway.getAudioUrl(any)).thenThrow(Exception('stream error'));

      final url = await service.getAudioUrl('vid1');

      expect(url, '');
    });
  });

  group('YouTubeService.getTrendingMusic', () {
    test('returns up to 2 songs', () async {
      final videos = List.generate(2, (i) => _fakeVideo(id: ids[i], title: 'Song $i - Artist $i'));
      when(mockGateway.search(any, limit: anyNamed('limit')))
          .thenAnswer((_) async => videos);

      final result = await service.getTrendingMusic();

      expect(result.length, 2);
    });

    test('returns empty list on exception', () async {
      when(mockGateway.search(any, limit: anyNamed('limit')))
          .thenThrow(Exception('error'));

      final result = await service.getTrendingMusic();

      expect(result, isEmpty);
    });
  });

  group('YouTubeService.getPlaylistSongs', () {
    test('maps playlist videos to songs with playlist title as album', () async {
      final videos = [_fakeVideo(id: 'jNQXAC9IVRw', title: 'Track 1')];
      when(mockGateway.getPlaylistVideos('PLxxx')).thenAnswer(
          (_) async => (playlistTitle: 'My Playlist', videos: videos));

      final result = await service.getPlaylistSongs('PLxxx');

      expect(result.length, 1);
      expect(result.first.album, 'My Playlist');
      expect(result.first.title, 'Track 1');
    });

    test('returns empty list on exception', () async {
      when(mockGateway.getPlaylistVideos(any)).thenThrow(Exception('error'));

      final result = await service.getPlaylistSongs('PLxxx');

      expect(result, isEmpty);
    });
  });

  group('YouTubeService.testYouTubeConnectivity', () {
    test('returns true when response status is 200', () async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('', 200));

      final result = await service.testYouTubeConnectivity();

      expect(result, isTrue);
    });

    test('returns false when response status is not 200', () async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenAnswer((_) async => http.Response('', 503));

      final result = await service.testYouTubeConnectivity();

      expect(result, isFalse);
    });

    test('returns false on exception', () async {
      when(mockHttpClient.get(any, headers: anyNamed('headers')))
          .thenThrow(Exception('no network'));

      final result = await service.testYouTubeConnectivity();

      expect(result, isFalse);
    });
  });

  group('YouTubeService.getSuggestedSongs', () {
    test('skips first result and returns up to maxResults songs', () async {
      final sourceVideo = _fakeVideo(id: 'dQw4w9WgXcQ', title: 'Source', author: 'Artist');
      when(mockGateway.getVideo('dQw4w9WgXcQ')).thenAnswer((_) async => sourceVideo);

      final searchVideos = List.generate(4, (i) => _fakeVideo(id: ids[i], title: 'Result $i'));
      when(mockGateway.search(any, limit: anyNamed('limit')))
          .thenAnswer((_) async => searchVideos);

      final result = await service.getSuggestedSongs('dQw4w9WgXcQ', maxResults: 3);

      // skips index 0, returns remaining 3
      expect(result.length, 3);
      expect(result.first.id, 'jNQXAC9IVRw');
    });

    test('returns empty list on exception', () async {
      when(mockGateway.getVideo(any)).thenThrow(Exception('error'));

      final result = await service.getSuggestedSongs('vid1');

      expect(result, isEmpty);
    });
  });
}
