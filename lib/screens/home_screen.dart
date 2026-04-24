import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../models/music_models.dart';
import '../services/youtube_service.dart';
import '../widgets/song_card_list.dart';
import '../widgets/recent_songs_grid.dart';

class HomeScreen extends StatefulWidget {
  final YouTubeService? youtubeService;
  const HomeScreen({super.key, this.youtubeService});

  @override
  // ignore: library_private_types_in_public_api
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final YouTubeService _youtubeService;
  List<Song> trendingSongs = [];
  List<Song> suggestedSongs = [];
  List<Playlist> recentPlaylists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _loadTrendingMusic();
  }

  Future<void> _loadTrendingMusic() async {
    final songs = await _youtubeService.getTrendingMusic();
    final provider = context.read<MusicPlayerProvider>();
    final playlists = await provider.loadPlaylists();
    setState(() {
      trendingSongs = songs;
      recentPlaylists = playlists;
      isLoading = false;
    });
    if (mounted && songs.isNotEmpty) {
      context.read<MusicPlayerProvider>().prefetchAudioUrls(songs.take(3).toList());
    }
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final provider = context.read<MusicPlayerProvider>();
    final likedSongs = await provider.getMostLikedFromHistory();
    print('[HomeScreen] liked songs from history: ${likedSongs.map((s) => s.title).toList()}');
    final seedSongs = likedSongs.isNotEmpty
        ? likedSongs.take(3).toList()
        : trendingSongs.take(2).toList();
    print('[HomeScreen] seed songs for suggestions: ${seedSongs.map((s) => s.title).toList()}');
    if (seedSongs.isEmpty) return;
    final suggestions = await _youtubeService.getSuggestionsFromHistory(seedSongs);
    print('[HomeScreen] suggestions loaded: ${suggestions.length}');
    if (mounted) setState(() => suggestedSongs = suggestions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Good evening'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Test YouTube Connectivity',
            onPressed: () async {
              final result = await _youtubeService.testYouTubeConnectivity();
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('YouTube Connectivity Test'),
                  content: Text(result ? 'SUCCESS: Device can reach YouTube.' : 'FAILED: Device cannot reach YouTube.'),
                  actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recently Played', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (recentPlaylists.isEmpty)
              const Text('No playlists yet. Search for a song to generate one.', style: TextStyle(color: Colors.grey))
            else
              RecentPlaylistsGrid(playlists: recentPlaylists),
            const SizedBox(height: 32),
            const Text('Trending Music', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : SongCardList(songs: trendingSongs),
            if (suggestedSongs.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text('Suggested for You', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SongCardList(songs: suggestedSongs),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}
