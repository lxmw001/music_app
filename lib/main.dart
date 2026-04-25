import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/music_player_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';
import 'services/youtube_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicPlayerProvider>(create: (_) => MusicPlayerProviderImpl()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  final YouTubeService? youtubeService;
  const MainScreen({super.key, this.youtubeService});

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String? _updateUrl;
  double? _downloadProgress; // null = not downloading, 0.0-1.0 = progress

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(youtubeService: widget.youtubeService),
      SearchScreen(youtubeService: widget.youtubeService),
      LibraryScreen(),
    ];
    UpdateService().checkForUpdate().then((url) {
      if (url != null && mounted) setState(() => _updateUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_updateUrl != null)
            MaterialBanner(
              content: _downloadProgress != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Downloading update... ${(_downloadProgress! * 100).toInt()}%'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: _downloadProgress),
                      ],
                    )
                  : const Text('A new version is available!'),
              actions: _downloadProgress != null
                  ? [const SizedBox.shrink()]
                  : [
                      TextButton(
                        onPressed: () async {
                          setState(() => _downloadProgress = 0.0);
                          await UpdateService().downloadAndInstall(
                            _updateUrl!,
                            onProgress: (p) => setState(() => _downloadProgress = p),
                          );
                          setState(() { _updateUrl = null; _downloadProgress = null; });
                        },
                        child: const Text('UPDATE'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _updateUrl = null),
                        child: const Text('DISMISS'),
                      ),
                    ],
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          Consumer<MusicPlayerProvider>(
            builder: (context, player, child) {
              if (player.currentSong != null) {
                return GestureDetector(
                  key: const Key('mini_player'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PlayerScreen()),
                  ),
                  child: Container(
                    height: 60,
                    color: Colors.grey[900],
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            player.currentSong!.imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40, height: 40, color: Colors.grey[700],
                              child: const Icon(Icons.music_note, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                player.currentSong!.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                player.currentSong!.artist,
                                style: const TextStyle(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (player.isPlaying) {
                              player.pause();
                            } else {
                              player.resume();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
        ],
      ),
    );
  }
}
