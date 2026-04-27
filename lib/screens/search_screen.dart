import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../services/music_server_service.dart';
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
  final _serverService = MusicServerService();
  final TextEditingController _searchController = TextEditingController();
  List<Song> searchResults = [];
  List<String> _suggestions = [];
  bool isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _serverService.getSearchSuggestions().then((s) {
      if (mounted) setState(() => _suggestions = s);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }
    _focusNode.unfocus();
    setState(() => isLoading = true);

    final results = await _youtubeService.searchSongs(query);
    final top15 = results.songs.take(15).toList();
    setState(() {
      searchResults = top15;
      isLoading = false;
      _currentQuery = query;
    });
    if (mounted) {
      context.read<MusicPlayerProvider>().saveSearch(query);
    }
  }

  List<String> _matchingSuggestions(String input) {
    if (input.isEmpty || _suggestions.isEmpty) return [];
    final lower = input.toLowerCase();
    // Score by match percentage (shared chars / suggestion length)
    final scored = _suggestions
        .map((s) {
          final sl = s.toLowerCase();
          if (sl.startsWith(lower)) return (s: s, score: 1.0);
          if (sl.contains(lower)) return (s: s, score: lower.length / sl.length);
          // word overlap
          final inputWords = lower.split(' ').where((w) => w.length > 1).toSet();
          final sWords = sl.split(' ').where((w) => w.length > 1).toSet();
          final overlap = inputWords.intersection(sWords).length;
          if (overlap == 0) return (s: s, score: 0.0);
          return (s: s, score: overlap / sWords.length);
        })
        .where((e) => e.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).map((e) => e.s).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Autocomplete<String>(
          optionsBuilder: (v) => _matchingSuggestions(v.text),
          onSelected: (s) {
            _searchController.text = s;
            _performSearch(s);
          },
          fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
            // sync our controller
            controller.text = _searchController.text;
            controller.addListener(() => _searchController.text = controller.text);
            // use our focusNode so we can unfocus programmatically
            return TextField(
              controller: controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums...',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          _searchController.clear();
                          setState(() { searchResults = []; _currentQuery = ''; });
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) { onSubmit(); _performSearch(controller.text); },
            );
          },
          optionsViewBuilder: (ctx, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: options.map((s) => ListTile(
                    leading: const Icon(Icons.search, size: 18),
                    title: Text(s),
                    dense: true,
                    onTap: () => onSelected(s),
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: searchResults.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => searchResults = []),
              )
            : null,
      ),
      body: Builder(builder: (context) {
        if (isLoading) return Center(child: CircularProgressIndicator());
        if (searchResults.isEmpty) return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_suggestions.isNotEmpty) ...[
                const Text('Popular searches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _suggestions.take(5).map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () {
                      _searchController.text = s;
                      _focusNode.unfocus();
                      _performSearch(s);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 24),
              ],
              const Text('Browse by genre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 1.5,
                  crossAxisSpacing: 16, mainAxisSpacing: 16,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  const genres = ['Pop','Rock','Hip-Hop','Jazz','Classical','Electronic','Country','R&B'];
                  const gradients = [
                    [Color(0xFFe91e63), Color(0xFFff5722)],
                    [Color(0xFF3f51b5), Color(0xFF2196f3)],
                    [Color(0xFF9c27b0), Color(0xFF673ab7)],
                    [Color(0xFF009688), Color(0xFF4caf50)],
                    [Color(0xFF795548), Color(0xFF9e9e9e)],
                    [Color(0xFF00bcd4), Color(0xFF3f51b5)],
                    [Color(0xFF8bc34a), Color(0xFFcddc39)],
                    [Color(0xFFff9800), Color(0xFFf44336)],
                  ];
                  const icons = [
                    Icons.music_note, Icons.music_video, Icons.headphones,
                    Icons.piano, Icons.queue_music, Icons.graphic_eq,
                    Icons.album, Icons.mic,
                  ];
                  return GestureDetector(
                    onTap: () => _performSearch(genres[index]),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradients[index], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(icons[index], color: Colors.white.withValues(alpha: 0.8), size: 28),
                          const SizedBox(width: 8),
                          Text(genres[index], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
        return Selector<MusicPlayerProvider, Set<String>>(
          selector: (_, p) => Set.from(searchResults.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
          builder: (context, loadingIds, _) => ListView.builder(
            itemCount: searchResults.length + 1,
            itemBuilder: (context, index) {
              if (index == searchResults.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() => isLoading = true);
                      final more = await _youtubeService.searchSongs(_currentQuery);
                      final extra = more.songs.skip(searchResults.length).take(10).toList();
                      setState(() { searchResults = [...searchResults, ...extra]; isLoading = false; });
                    },
                    child: const Text('Load more'),
                  ),
                );
              }
              final song = searchResults[index];
              return SongListTile(
                song: song,
                isLoading: loadingIds.contains(song.id),
                queue: searchResults,
                onTap: () => context.read<MusicPlayerProvider>()
                    .playSong(song, searchQuery: _currentQuery),
              );
            },
          ),
        );
      }),
    );
  }

  final _focusNode = FocusNode();

  @override
  void dispose() {
    _youtubeService.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
