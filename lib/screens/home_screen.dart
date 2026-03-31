import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../models/music_models.dart';
import '../services/youtube_service.dart';

class HomeScreen extends StatefulWidget {
  final YouTubeService? youtubeService;
  const HomeScreen({super.key, this.youtubeService});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final YouTubeService _youtubeService;
  List<Song> trendingSongs = [];
  List<Song> suggestedSongs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _loadTrendingMusic();
  }

  Future<void> _loadTrendingMusic() async {
    final songs = await _youtubeService.getTrendingMusic();
    setState(() {
      trendingSongs = songs;
      isLoading = false;
    });
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
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('YouTube Connectivity Test'),
                  content: Text(result ? 'SUCCESS: Device can reach YouTube.' : 'FAILED: Device cannot reach YouTube.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recently Played',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                        child: Image.network(
                          'https://via.placeholder.com/60',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60, height: 60, color: Colors.grey[700],
                            child: const Icon(Icons.music_note, size: 20),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Playlist ${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 32),
            Text(
              'Trending Music',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
                    height: 200,
                    child: Selector<MusicPlayerProvider, String?>(
                      selector: (_, p) {
                        try {
                          return trendingSongs.firstWhere((s) => p.isLoadingAudio(s.id)).id;
                        } catch (_) {
                          return null;
                        }
                      },
                      builder: (context, loadingId, _) => ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: trendingSongs.length,
                        itemBuilder: (context, index) {
                          final song = trendingSongs[index];
                          final isLoading = song.id == loadingId;
                          return GestureDetector(
                            onTap: () => context.read<MusicPlayerProvider>().playSong(song, queue: trendingSongs),
                            child: Container(
                              width: 160,
                              margin: EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.network(
                                          song.imageUrl,
                                          width: 160,
                                          height: 150,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 160, height: 150,
                                            color: Colors.grey[800],
                                            child: Icon(Icons.music_note),
                                          ),
                                        ),
                                        if (isLoading)
                                          Container(
                                            width: 160, height: 150,
                                            color: Colors.black45,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 32, height: 32,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    song.title,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  Text(
                                    song.artist,
                                    style: TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          if (suggestedSongs.isNotEmpty) ...[
            SizedBox(height: 32),
            Text('Suggested for You', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Selector<MusicPlayerProvider, String?>(
                selector: (_, p) {
                  try { return suggestedSongs.firstWhere((s) => p.isLoadingAudio(s.id)).id; }
                  catch (_) { return null; }
                },
                builder: (context, loadingId, _) => ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestedSongs.length,
                  itemBuilder: (context, index) {
                    final song = suggestedSongs[index];
                    final isLoading = song.id == loadingId;
                    return GestureDetector(
                      onTap: () => context.read<MusicPlayerProvider>().playSong(song, queue: suggestedSongs),
                      child: Container(
                        width: 160,
                        margin: EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    song.imageUrl,
                                    width: 160, height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 160, height: 150,
                                      color: Colors.grey[800],
                                      child: Icon(Icons.music_note),
                                    ),
                                  ),
                                  if (isLoading)
                                    Container(
                                      width: 160, height: 150,
                                      color: Colors.black45,
                                      child: const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(song.title, style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 2),
                            Text(song.artist, style: TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
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
