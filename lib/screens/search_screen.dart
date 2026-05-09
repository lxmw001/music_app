import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/youtube_service.dart';
import '../services/music_server_service.dart';
import '../models/music_models.dart';
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
    _searchController.dispose();
    super.dispose();
  }

  FocusNode? _autoFocusNode;

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() { _result = const MusicSearchResult(); _activeFilter = null; });
      return;
    }
    _autoFocusNode?.unfocus();
    setState(() { isLoading = true; _activeFilter = null; });
    final result = await _youtubeService.searchSongs(query);
    setState(() { 
      _result = result; 
      isLoading = false; 
      _currentQuery = query; 
      _activeFilter = 'songs'; 
    });
    if (mounted) context.read<MusicPlayerProvider>().saveSearch(query);
  }

  List<String> _matchingSuggestions(String input) {
    if (input.isEmpty || _suggestions.isEmpty) return [];
    final lower = input.toLowerCase();
    return _suggestions
        .where((s) => s.toLowerCase().contains(lower))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasResults,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasResults) {
          setState(() { _result = const MusicSearchResult(); _activeFilter = null; });
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasResults ? _buildResults() : _buildEmptyState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Autocomplete<String>(
        optionsBuilder: (v) => _matchingSuggestions(v.text),
        onSelected: (s) { 
          _searchController.text = s; 
          _performSearch(s); 
        },
        fieldViewBuilder: (ctx, controller, autoFocusNode, onSubmit) {
          _autoFocusNode = autoFocusNode;
          if (_searchController.text != controller.text && _searchController.text.isNotEmpty) {
             // Sync if needed, but usually controller is the source of truth
          }
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: controller,
              focusNode: autoFocusNode,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(ctx)!.searchHint,
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () {
                          controller.clear();
                          _searchController.clear();
                          autoFocusNode.unfocus();
                          setState(() { _result = const MusicSearchResult(); _currentQuery = ''; _activeFilter = null; });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (text) => _performSearch(text),
            ),
          );
        },
        optionsViewBuilder: (ctx, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200, 
                maxWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    leading: const Icon(Icons.history_rounded, size: 18, color: Colors.grey),
                    title: Text(option, style: const TextStyle(fontSize: 14)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

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
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                itemBuilder: (context, i) {
                  final chip = chips[i];
                  final active = _activeFilter == chip.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: active,
                      onSelected: (_) => setState(() => _activeFilter = active ? null : chip.toLowerCase()),
                      backgroundColor: Colors.transparent,
                      selectedColor: Theme.of(context).primaryColor,
                      labelStyle: TextStyle(
                        color: active ? Colors.black : Colors.white,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: StadiumBorder(side: BorderSide(color: active ? Colors.transparent : Colors.grey[800]!)),
                      showCheckmark: false,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
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
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (_result.songs.isNotEmpty) ...[
              _sectionHeader('Top Songs'),
              ..._result.songs.take(3).map((s) => _songTile(s, loadingIds)),
              if (_result.songs.length > 3)
                _seeAllButton('Songs', () => setState(() => _activeFilter = 'songs')),
            ],
            if (_result.mixes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionHeader('Mixes'),
              ..._result.mixes.take(3).map((s) => _songTile(s, loadingIds)),
              if (_result.mixes.length > 3)
                _seeAllButton('Mixes', () => setState(() => _activeFilter = 'mixes')),
            ],
            const SizedBox(height: 100),
          ],
        );
    }
  }

  Widget _songsList(List<Song> songs, Set<String> loadingIds, {bool showLoadMore = false}) {
    if (songs.isEmpty) return const Center(child: Text('No results', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length + (showLoadMore ? 1 : 0) + 1,
      itemBuilder: (context, i) {
        if (i == songs.length) {
          if (showLoadMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton(
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
            );
          }
          return const SizedBox(height: 100);
        }
        return _songTile(songs[i], loadingIds);
      },
    );
  }

  Widget _artistsList() {
    if (_result.artists.isEmpty) return const Center(child: Text('No artists found', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _result.artists.length,
      itemBuilder: (context, i) => _artistTile(_result.artists[i]),
    );
  }

  Widget _songTile(Song s, Set<String> loadingIds) => SongListTile(
    song: s, 
    isLoading: loadingIds.contains(s.id),
    showDownload: false,
    onTap: () => context.read<MusicPlayerProvider>().playSong(s, searchQuery: _currentQuery),
  );

  Widget _artistTile(String a) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: Colors.grey[900],
      child: Text(a[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
    ),
    title: Text(a, style: const TextStyle(fontWeight: FontWeight.w500)),
    onTap: () => _performSearch(a),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 8),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _seeAllButton(String label, VoidCallback onTap) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: onTap,
      child: Text('See all $label', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_suggestions.isNotEmpty) ...[
            const Text('Popular searches', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _suggestions.take(6).map((s) => ActionChip(
                label: Text(s),
                backgroundColor: Colors.grey[900],
                side: BorderSide(color: Colors.grey[800]!),
                onPressed: () {
                  _searchController.text = s;
                  _autoFocusNode?.unfocus();
                  _performSearch(s);
                },
              )).toList(),
            ),
            const SizedBox(height: 32),
          ],
          const Text('Browse all', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 1.8,
              crossAxisSpacing: 12, 
              mainAxisSpacing: 12,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final genres = ['Pop','Rock','Hip-Hop','Jazz','Classical','Electronic','Country','R&B'];
              final gradients = [
                [const Color(0xFFE91E63), const Color(0xFF880E4F)],
                [const Color(0xFF3F51B5), const Color(0xFF1A237E)],
                [const Color(0xFF9C27B0), const Color(0xFF4A148C)],
                [const Color(0xFF009688), const Color(0xFF004D40)],
                [const Color(0xFF795548), const Color(0xFF3E2723)],
                [const Color(0xFF00BCD4), const Color(0xFF006064)],
                [const Color(0xFF8BC34A), const Color(0xFF33691E)],
                [const Color(0xFFFF9800), const Color(0xFFE65100)],
              ];
              return GestureDetector(
                onTap: () => _performSearch(genres[index]),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradients[index], 
                      begin: Alignment.topLeft, 
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    genres[index], 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
