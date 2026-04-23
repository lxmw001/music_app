import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../models/music_models.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../widgets/song_list_tile.dart';

class SearchScreen extends StatefulWidget {
  final YouTubeService? youtubeService;
  const SearchScreen({super.key, this.youtubeService});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final YouTubeService _youtubeService;
  final TextEditingController _searchController = TextEditingController();
  List<Song> searchResults = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }
    setState(() => isLoading = true);

    final results = await _youtubeService.searchSongs(query);
    setState(() {
      searchResults = results;
      isLoading = false;
    });
    if (mounted) context.read<MusicPlayerProvider>().saveSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search songs, artists, albums...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: _performSearch,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Builder(builder: (context) {
        final player = context.read<MusicPlayerProvider>();
        if (isLoading) return Center(child: CircularProgressIndicator());
        if (searchResults.isEmpty) return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Browse all',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: 8,
                        itemBuilder: (context, index) {
                          final genres = [
                            'Pop', 'Rock', 'Hip-Hop', 'Jazz',
                            'Classical', 'Electronic', 'Country', 'R&B'
                          ];
                          final colors = [
                            Colors.red, Colors.blue, Colors.green, Colors.orange,
                            Colors.purple, Colors.pink, Colors.teal, Colors.amber
                          ];
                          
                          return GestureDetector(
                            onTap: () => _performSearch(genres[index]),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors[index],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  genres[index],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
        return Selector<MusicPlayerProvider, Set<String>>(
          selector: (_, p) => Set.from(searchResults.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
          builder: (context, loadingIds, _) => ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final song = searchResults[index];
              return SongListTile(song: song, isLoading: loadingIds.contains(song.id), queue: searchResults);
            },
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}
