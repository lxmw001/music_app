import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:music_app/main.dart';
import 'package:music_app/models/music_models.dart';
import 'package:music_app/providers/music_player_provider.dart';
import 'package:music_app/services/youtube_service.dart';

// --- Fakes ---

class FakeYoutubeGateway implements YoutubeGateway {
  static Song fakeSong({String id = 'dQw4w9WgXcQ', String title = 'Fake Song', String artist = 'Fake Artist'}) =>
      Song(id: id, title: title, artist: artist, album: '', imageUrl: 'https://via.placeholder.com/160', audioUrl: 'https://fake.audio/track.mp3', duration: const Duration(seconds: 200));

  @override
  Future<List<Video>> search(String query, {int limit = 5}) async => [];

  @override
  Future<String> getAudioUrl(String videoId) async => 'https://fake.audio/track.mp3';

  @override
  Future<Video> getVideo(String videoId) => throw UnimplementedError();

  @override
  Future<({String playlistTitle, List<Video> videos})> getPlaylistVideos(String playlistId) => throw UnimplementedError();
}

/// A YouTubeService backed by the fake gateway that returns predictable songs.
class FakeYouTubeService extends YouTubeService {
  final List<Song> _songs;

  FakeYouTubeService(this._songs) : super(gateway: FakeYoutubeGateway());

  @override
  Future<List<Song>> searchSongs(String query) async => _songs;

  @override
  Future<List<Song>> getTrendingMusic() async => _songs;
}

/// A MusicPlayerProvider that skips AudioService initialization.
class FakeMusicPlayerProvider extends MusicPlayerProvider {
  Song? _song;
  bool _playing = false;
  bool _shuffled = false;
  bool _repeating = false;

  @override
  Song? get currentSong => _song;

  @override
  bool get isPlaying => _playing;

  @override
  bool get isShuffled => _shuffled;

  @override
  bool get isRepeating => _repeating;

  @override
  bool get isInitialized => true;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => const Duration(seconds: 200);

  @override
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    _song = song;
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> resume() async {
    _playing = true;
    notifyListeners();
  }

  @override
  void toggleShuffle() {
    _shuffled = !_shuffled;
    notifyListeners();
  }

  @override
  void toggleRepeat() {
    _repeating = !_repeating;
    notifyListeners();
  }
}

// --- Test app ---

Widget testApp({required FakeMusicPlayerProvider provider, required FakeYouTubeService youtubeService}) {
  return MultiProvider(
    providers: [ChangeNotifierProvider<MusicPlayerProvider>.value(value: provider)],
    child: MaterialApp(
      home: MainScreen(youtubeService: youtubeService),
    ),
  );
}

// --- Tests ---

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicPlayerProvider provider;
  late FakeYouTubeService youtubeService;

  final fakeSong = FakeYoutubeGateway.fakeSong();

  setUp(() {
    provider = FakeMusicPlayerProvider();
    youtubeService = FakeYouTubeService([fakeSong]);
  });

  testWidgets('home screen shows trending music section', (tester) async {
    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    expect(find.text('Trending Music'), findsOneWidget);
  });

  testWidgets('bottom nav navigates to Search tab', (tester) async {
    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Browse all'), findsOneWidget);
  });

  testWidgets('bottom nav navigates to Library tab', (tester) async {
    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.library_music));
    await tester.pumpAndSettle();

    expect(find.text('Your Library'), findsOneWidget);
  });

  testWidgets('search returns results and displays them', (tester) async {
    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rock');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(fakeSong.title), findsOneWidget);
    expect(find.text(fakeSong.artist), findsOneWidget);
  });

  testWidgets('tapping a search result triggers playSong and shows mini player', (tester) async {
    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    // Navigate to search and get results
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rock');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Tap the song
    await tester.tap(find.text(fakeSong.title));
    await tester.pumpAndSettle();

    // Mini player should appear
    expect(provider.currentSong, fakeSong);
    expect(find.text(fakeSong.title), findsWidgets);
  });

  testWidgets('mini player pause button toggles playback', (tester) async {
    await provider.playSong(fakeSong);

    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    expect(provider.isPlaying, isTrue);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();

    expect(provider.isPlaying, isFalse);
  });

  testWidgets('tapping mini player opens player screen', (tester) async {
    await provider.playSong(fakeSong);

    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    // Tap the mini player container (not the pause button)
    final miniPlayer = find.ancestor(
      of: find.text(fakeSong.title),
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(miniPlayer);
    await tester.pumpAndSettle();

    expect(find.text('Now Playing'), findsOneWidget);
  });

  testWidgets('player screen shows song title and artist', (tester) async {
    await provider.playSong(fakeSong);

    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    final miniPlayer = find.ancestor(
      of: find.text(fakeSong.title),
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(miniPlayer);
    await tester.pumpAndSettle();

    expect(find.text(fakeSong.title), findsWidgets);
    expect(find.text(fakeSong.artist), findsWidgets);
  });

  testWidgets('player screen shuffle and repeat buttons toggle state', (tester) async {
    await provider.playSong(fakeSong);

    await tester.pumpWidget(testApp(provider: provider, youtubeService: youtubeService));
    await tester.pumpAndSettle();

    final miniPlayer = find.ancestor(
      of: find.text(fakeSong.title),
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(miniPlayer);
    await tester.pumpAndSettle();

    expect(provider.isShuffled, isFalse);
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pumpAndSettle();
    expect(provider.isShuffled, isTrue);

    expect(provider.isRepeating, isFalse);
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pumpAndSettle();
    expect(provider.isRepeating, isTrue);
  });
}
