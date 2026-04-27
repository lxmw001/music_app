import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:music_app/services/youtube_service.dart';

/// Real-network integration tests for YouTubeService.
/// Requires an internet connection. Run on a device or emulator:
///   flutter test integration_test/youtube_service_real_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late YouTubeService service;

  setUp(() {
    service = YouTubeService(); // real YoutubeExplodeGateway + real http.Client
  });

  testWidgets('testYouTubeConnectivity returns true', (tester) async {
    final result = await service.testYouTubeConnectivity();
    expect(result, isTrue);
  });

  testWidgets('searchSongs returns non-empty results for a common query', (tester) async {
    final results = await service.searchSongs('coldplay');
    expect(results.songs, isNotEmpty);
    expect(results.songs.first.id, isNotEmpty);
    expect(results.songs.first.title, isNotEmpty);
    expect(results.songs.first.artist, isNotEmpty);
  });

  testWidgets('searchSongs returns at most 5 results', (tester) async {
    final results = await service.searchSongs('pop');
    expect(results.songs.length, lessThanOrEqualTo(5));
  });

  testWidgets('searchSongs returns empty list for gibberish query gracefully', (tester) async {
    // Should not throw — returns empty or minimal results
    final results = await service.searchSongs('xzqwerty12345notareal');
    expect(results.songs, isA<List>());
  });

  testWidgets('getTrendingMusic returns songs', (tester) async {
    final results = await service.getTrendingMusic();
    expect(results.songs, isNotEmpty);
    expect(results.songs.length, lessThanOrEqualTo(2));
  });

  testWidgets('getSuggestedSongs returns related songs', (tester) async {
    // First get a real video ID via search
    final searchResults = await service.searchSongs('coldplay');
    expect(searchResults.songs, isNotEmpty);

    final videoId = searchResults.songs.first.id;
    final suggestions = await service.getSuggestedSongs(videoId, maxResults: 3);

    expect(suggestions, isNotEmpty);
    expect(suggestions.length, lessThanOrEqualTo(3));
    // Should not include the source video
    expect(suggestions.any((s) => s.id == videoId), isFalse);
  });

  testWidgets('getAudioUrl returns a non-empty URL for a valid video', (tester) async {
    final searchResults = await service.searchSongs('coldplay');
    expect(searchResults.songs, isNotEmpty);

    final videoId = searchResults.songs.first.id;
    final url = await service.getAudioUrl(videoId);

    expect(url, isNotEmpty);
    expect(Uri.tryParse(url)?.hasAbsolutePath, isTrue);
  });
}
