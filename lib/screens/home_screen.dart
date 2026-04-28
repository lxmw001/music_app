import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../models/music_models.dart';
import '../services/youtube_service.dart';
import '../services/play_history_service.dart';
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
  final _history = PlayHistoryService();
  List<Song> trendingSongs = [];
  List<Song> suggestedSongs = [];
  List<Playlist> recentPlaylists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _loadWithCache();
  }

  Future<void> _loadWithCache() async {
    // 1. Show cached data immediately
    final cached = await _history.loadCachedTrending();
    final cachedSuggested = await _history.loadCachedSuggested();
    final playlists = await context.read<MusicPlayerProvider>().loadPlaylists();
    if (mounted) {
      setState(() {
        if (cached.isNotEmpty) trendingSongs = cached;
        if (cachedSuggested.isNotEmpty) suggestedSongs = cachedSuggested;
        recentPlaylists = playlists;
        isLoading = cached.isEmpty; // only show spinner if no cache
      });
    }

    // 2. Fetch fresh data in background
    final fresh = await _youtubeService.getTrendingMusic();
    if (fresh.isNotEmpty) {
      await _history.cacheTrending(fresh);
      if (mounted) setState(() { trendingSongs = fresh; isLoading = false; });
    } else if (mounted) {
      setState(() => isLoading = false);
    }

    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final provider = context.read<MusicPlayerProvider>();
    final likedSongs = await provider.getMostLikedFromHistory();
    final seedSongs = likedSongs.isNotEmpty
        ? likedSongs.take(3).toList()
        : trendingSongs.take(2).toList();
    if (seedSongs.isEmpty) return;
    final suggestions = await _youtubeService.getSuggestionsFromHistory(seedSongs);
    if (suggestions.isNotEmpty) {
      await _history.cacheSuggested(suggestions);
      if (mounted) setState(() => suggestedSongs = suggestions);
    }
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
              Column(
                children: const [
                  SizedBox(height: 16),
                  Icon(Icons.queue_music, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No playlists yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  Text('Search for a song to generate one', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 16),
                ],
              )
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
