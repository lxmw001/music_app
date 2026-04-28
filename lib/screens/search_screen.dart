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
  String? _activeFilter; // null = top results, 'songs'|'mixes'|'videos'|'artists'

  bool get _hasResults => !_result.isEmpty;

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
      setState(() { _result = const MusicSearchResult(); _activeFilter = null; });
      return;
    }
    _focusNode.unfocus();
    setState(() { isLoading = true; _activeFilter = null; });
    final result = await _youtubeService.searchSongs(query);
    setState(() { _result = result; isLoading = false; _currentQuery = query; _activeFilter = 'songs'; });
    if (mounted) context.read<MusicPlayerProvider>().saveSearch(query);
  }

  List<String> _matchingSuggestions(String input) {
    if (input.isEmpty || _suggestions.isEmpty) return [];
    final lower = input.toLowerCase();
    final scored = _suggestions.map((s) {
      final sl = s.toLowerCase();
      if (sl.startsWith(lower)) return (s: s, score: 1.0);
      if (sl.contains(lower)) return (s: s, score: lower.length / sl.length);
      final iw = lower.split(' ').where((w) => w.length > 1).toSet();
      final sw = sl.split(' ').where((w) => w.length > 1).toSet();
      final overlap = iw.intersection(sw).length;
      return (s: s, score: overlap == 0 ? 0.0 : overlap / sw.length);
    }).where((e) => e.score > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).map((e) => e.s).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _hasResults
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() { _result = const MusicSearchResult(); _activeFilter = null; }),
              )
            : null,
        title: Autocomplete<String>(
          optionsBuilder: (v) => _matchingSuggestions(v.text),
          onSelected: (s) { _searchController.text = s; _performSearch(s); },
          fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
            controller.text = _searchController.text;
            controller.addListener(() => _searchController.text = controller.text);
            return TextField(
              controller: controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Songs, artists, mixes...',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          _searchController.clear();
                          setState(() { _result = const MusicSearchResult(); _currentQuery = ''; _activeFilter = null; });
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
              elevation: 4, color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView(
                  padding: EdgeInsets.zero, shrinkWrap: true,
                  children: options.map((s) => ListTile(
                    leading: const Icon(Icons.search, size: 18, color: Colors.grey),
                    title: Text(s), dense: true,
                    onTap: () => onSelected(s),
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _hasResults ? _buildResults() : _buildEmptyState(),
    );
  }

  // ─── Results ─────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final chips = [
      if (_result.songs.isNotEmpty) 'Songs',
      if (_result.mixes.isNotEmpty) 'Mixes',
      if (_result.videos.isNotEmpty) 'Videos',
      if (_result.artists.isNotEmpty) 'Artists',
    ];
    return Selector<MusicPlayerProvider, Set<String>>(
      selector: (_, p) {
        final ids = [..._result.songs, ..._result.mixes, ..._result.videos].map((s) => s.id).toSet();
        return ids.where((id) => p.isLoadingAudio(id)).toSet();
      },
      builder: (context, loadingIds, _) => Column(
        children: [
          if (chips.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: chips.map((chip) {
                  final active = _activeFilter == chip.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(chip),
                      selected: active,
                      onSelected: (_) => setState(() =>
                          _activeFilter = active ? null : chip.toLowerCase()),
                      selectedColor: Colors.green,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: active ? Colors.white : Colors.grey[300]),
                      backgroundColor: Colors.grey[850],
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(child: _buildFilteredList(loadingIds)),
        ],
      ),
    );
  }

  Widget _buildFilteredList(Set<String> loadingIds) {
    switch (_activeFilter) {
      case 'songs':
        return _songsList(_result.songs, loadingIds, showLoadMore: _result.hasMoreSongs);
      case 'mixes':
        return _songsList(_result.mixes, loadingIds);
      case 'videos':
        return _songsList(_result.videos, loadingIds);
      case 'artists':
        return _artistsList();
      default:
        // Top results: 3 per section + "See all" links
        return ListView(
          children: [
            if (_result.songs.isNotEmpty) ...[
              _sectionHeader('Top Songs'),
              ..._result.songs.take(3).map((s) => _songTile(s, loadingIds)),
              if (_result.songs.length > 3)
                _seeAllButton('Songs', () => setState(() => _activeFilter = 'songs')),
            ],
            if (_result.mixes.isNotEmpty) ...[
              _sectionHeader('Mixes'),
              ..._result.mixes.take(3).map((s) => _songTile(s, loadingIds)),
              if (_result.mixes.length > 3)
                _seeAllButton('Mixes', () => setState(() => _activeFilter = 'mixes')),
            ],
            if (_result.videos.isNotEmpty) ...[
              _sectionHeader('Videos'),
              ..._result.videos.take(3).map((s) => _songTile(s, loadingIds)),
              if (_result.videos.length > 3)
                _seeAllButton('Videos', () => setState(() => _activeFilter = 'videos')),
            ],
            if (_result.artists.isNotEmpty) ...[
              _sectionHeader('Artists'),
              ..._result.artists.take(3).map(_artistTile),
              if (_result.artists.length > 3)
                _seeAllButton('Artists', () => setState(() => _activeFilter = 'artists')),
            ],
            const SizedBox(height: 16),
          ],
        );
    }
  }

  Widget _songsList(List<Song> songs, Set<String> loadingIds, {bool showLoadMore = false}) {
    if (songs.isEmpty) return const Center(child: Text('No results', style: TextStyle(color: Colors.grey)));
    return ListView(
      children: [
        ...songs.map((s) => _songTile(s, loadingIds)),
        if (showLoadMore)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () async {
                setState(() => isLoading = true);
                final more = await _youtubeService.searchSongs(_currentQuery);
                setState(() {
                  _result = MusicSearchResult(
                    songs: [..._result.songs, ...more.songs.skip(_result.songs.length)],
                    mixes: _result.mixes, videos: _result.videos, artists: _result.artists,
                    hasMoreSongs: more.hasMoreSongs,
                  );
                  isLoading = false;
                });
              },
              child: const Text('Load more'),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _artistsList() {
    if (_result.artists.isEmpty) return const Center(child: Text('No artists found', style: TextStyle(color: Colors.grey)));
    return ListView(
      children: _result.artists.map(_artistTile).toList(),
    );
  }

  Widget _songTile(Song s, Set<String> loadingIds) => SongListTile(
    song: s, isLoading: loadingIds.contains(s.id),
    onTap: () => context.read<MusicPlayerProvider>().playSong(s, searchQuery: _currentQuery),
  );

  Widget _artistTile(String a) => ListTile(
    leading: CircleAvatar(
      backgroundColor: Colors.grey[800],
      child: Text(a[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
    ),
    title: Text(a),
    onTap: () => _performSearch(a),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
  );

  Widget _seeAllButton(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    child: Text('See all $label →', style: const TextStyle(color: Colors.green)),
  );

  // ─── Empty state ──────────────────────────────────────────────────────────

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
                backgroundColor: Colors.grey[850],
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
              crossAxisCount: 2, childAspectRatio: 1.6,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
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
                      Icon(icons[index], color: Colors.white.withValues(alpha: 0.85), size: 26),
                      const SizedBox(width: 8),
                      Text(genres[index], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
