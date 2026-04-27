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
  final _focusNode = FocusNode();
  MusicSearchResult _result = const MusicSearchResult();
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

  @override
  void dispose() {
    _youtubeService.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _result = const MusicSearchResult());
      return;
    }
    _focusNode.unfocus();
    setState(() => isLoading = true);
    final result = await _youtubeService.searchSongs(query);
    setState(() {
      _result = result;
      isLoading = false;
      _currentQuery = query;
    });
    if (mounted) context.read<MusicPlayerProvider>().saveSearch(query);
  }

  List<String> _matchingSuggestions(String input) {
    if (input.isEmpty || _suggestions.isEmpty) return [];
    final lower = input.toLowerCase();
    final scored = _suggestions.map((s) {
      final sl = s.toLowerCase();
      if (sl.startsWith(lower)) return (s: s, score: 1.0);
      if (sl.contains(lower)) return (s: s, score: lower.length / sl.length);
      final inputWords = lower.split(' ').where((w) => w.length > 1).toSet();
      final sWords = sl.split(' ').where((w) => w.length > 1).toSet();
      final overlap = inputWords.intersection(sWords).length;
      if (overlap == 0) return (s: s, score: 0.0);
      return (s: s, score: overlap / sWords.length);
    }).where((e) => e.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).map((e) => e.s).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = !_result.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Autocomplete<String>(
          optionsBuilder: (v) => _matchingSuggestions(v.text),
          onSelected: (s) {
            _searchController.text = s;
            _performSearch(s);
          },
          fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
            controller.text = _searchController.text;
            controller.addListener(() => _searchController.text = controller.text);
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
                          setState(() { _result = const MusicSearchResult(); _currentQuery = ''; });
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
        leading: hasResults
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _result = const MusicSearchResult()),
              )
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasResults
              ? _buildResults()
              : _buildEmptyState(),
    );
  }

  Widget _buildResults() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Songs'), Tab(text: 'Mixes')],
            indicatorColor: Colors.green,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: Selector<MusicPlayerProvider, Set<String>>(
              selector: (_, p) {
                final allIds = [..._result.songs, ..._result.mixes].map((s) => s.id).toSet();
                return allIds.where((id) => p.isLoadingAudio(id)).toSet();
              },
              builder: (context, loadingIds, _) => TabBarView(
                children: [
                  // Songs tab
                  _buildSongSection(_result.songs, loadingIds),
                  // Mixes tab
                  _buildSongSection(_result.mixes, loadingIds),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongSection(List<Song> songs, Set<String> loadingIds) {
    return ListView(
      children: [
        ...songs.map((song) => SongListTile(
          song: song,
          isLoading: loadingIds.contains(song.id),
          onTap: () => context.read<MusicPlayerProvider>()
              .playSong(song, searchQuery: _currentQuery),
        )),
        // Artists section at bottom
        _sectionHeader('Artists'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Artists coming soon', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _buildEmptyState() {
    return SingleChildScrollView(
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
              final genres = ['Pop','Rock','Hip-Hop','Jazz','Classical','Electronic','Country','R&B'];
              final colors = [Colors.red,Colors.blue,Colors.green,Colors.orange,Colors.purple,Colors.pink,Colors.teal,Colors.amber];
              return GestureDetector(
                onTap: () => _performSearch(genres[index]),
                child: Container(
                  decoration: BoxDecoration(color: colors[index], borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(genres[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
