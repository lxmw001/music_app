import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/youtube_service.dart';
import '../services/music_server_service.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/mesh_gradient.dart';
import '../widgets/animated_list_item.dart';

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
  List<String> _popularSuggestions = [];
  bool isLoading = false;
  String _currentQuery = '';
  String? _activeFilter; 

  bool get _hasResults => !_result.isEmpty;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _serverService.getSearchSuggestions().then((s) {
      if (mounted) setState(() => _popularSuggestions = s);
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
    if (input.isEmpty || _popularSuggestions.isEmpty) return [];
    final lower = input.toLowerCase();
    return _popularSuggestions
        .where((s) => s.toLowerCase().contains(lower))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    return PopScope(
      canPop: !_hasResults,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasResults) {
          setState(() { _result = const MusicSearchResult(); _activeFilter = null; });
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            MeshGradient(color: theme.accentColor),
            SafeArea(
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
          ],
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: autoFocusNode,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(ctx)!.searchHint,
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 16),
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
              ),
            ),
          );
        },
        optionsViewBuilder: (ctx, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              elevation: 12,
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 250, 
                    maxWidth: MediaQuery.of(context).size.width - 32,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.history_rounded, size: 20, color: Colors.white38),
                        title: Text(option, style: const TextStyle(fontSize: 15)),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
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
              height: 54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: chips.length,
                itemBuilder: (context, i) {
                  final chip = chips[i];
                  final active = _activeFilter == chip.toLowerCase();
                  final primary = Theme.of(context).primaryColor;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: active,
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(() => _activeFilter = active ? null : chip.toLowerCase());
                      },
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      selectedColor: primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: active ? primary : Colors.white70,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: StadiumBorder(side: BorderSide(color: active ? primary : Colors.white10)),
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
              for (var i = 0; i < _result.songs.length && i < 3; i++)
                AnimatedListItem(index: i, child: _songTile(_result.songs[i], loadingIds)),
              if (_result.songs.length > 3)
                _seeAllButton('Songs', () => setState(() => _activeFilter = 'songs')),
            ],
            if (_result.mixes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionHeader('Mixes'),
              for (var i = 0; i < _result.mixes.length && i < 3; i++)
                AnimatedListItem(index: i, child: _songTile(_result.mixes[i], loadingIds)),
              if (_result.mixes.length > 3)
                _seeAllButton('Mixes', () => setState(() => _activeFilter = 'mixes')),
            ],
            const SizedBox(height: 120),
          ],
        );
    }
  }

  Widget _songsList(List<Song> songs, Set<String> loadingIds, {bool showLoadMore = false}) {
    if (songs.isEmpty) return const Center(child: Text('No results found', style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length + (showLoadMore ? 1 : 0) + 1,
      itemBuilder: (context, i) {
        if (i == songs.length) {
          if (showLoadMore) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: FilledButton.tonal(
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
          return const SizedBox(height: 120);
        }
        return AnimatedListItem(index: i, child: _songTile(songs[i], loadingIds));
      },
    );
  }

  Widget _artistsList() {
    if (_result.artists.isEmpty) return const Center(child: Text('No artists found', style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _result.artists.length + 1,
      itemBuilder: (context, i) {
        if (i == _result.artists.length) return const SizedBox(height: 120);
        return AnimatedListItem(index: i, child: _artistTile(_result.artists[i]));
      },
    );
  }

  Widget _songTile(Song s, Set<String> loadingIds) => SongListTile(
    song: s, 
    isLoading: loadingIds.contains(s.id),
    showDownload: false,
    onTap: () => context.read<MusicPlayerProvider>().playSong(s, searchQuery: _currentQuery),
  );

  Widget _artistTile(String a) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    leading: Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
      child: Center(child: Text(a[0].toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
    ),
    title: Text(a, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    onTap: () => _performSearch(a),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
    child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
  );

  Widget _seeAllButton(String label, VoidCallback onTap) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: onTap,
      child: Text('See all $label', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildEmptyState() {
    final theme = context.watch<ThemeProvider>();
    
    return FutureBuilder<List<String>>(
      future: context.read<MusicPlayerProvider>().getSearchHistory(),
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (history.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent searches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () async {
                          await context.read<MusicPlayerProvider>().clearSearchHistory();
                          setState(() {});
                        },
                        child: Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: history.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        label: Text(history[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        side: const BorderSide(color: Colors.white10),
                        shape: StadiumBorder(),
                        onPressed: () {
                          _searchController.text = history[i];
                          _performSearch(history[i]);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              if (_popularSuggestions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(AppLocalizations.of(context)!.searchPopular, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _popularSuggestions.length && i < 6; i++)
                  _buildTrendingItem(i + 1, _popularSuggestions[i], theme.accentColor),
                const SizedBox(height: 24),
              ],
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(AppLocalizations.of(context)!.searchBrowseGenre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildGenreGrid(),
              ),
              const SizedBox(height: 150),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTrendingItem(int index, String query, Color accentColor) {
    return InkWell(
      onTap: () {
        _searchController.text = query;
        _performSearch(query);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 1 ? accentColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$index', 
                style: TextStyle(
                  color: index == 1 ? accentColor : Colors.white38, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 15
                )
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(query, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Icon(
              Icons.trending_up_rounded, 
              size: 20, 
              color: index <= 3 ? accentColor.withValues(alpha: 0.4) : Colors.white10
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    final genres = ['Pop','Rock','Hip-Hop','Jazz','Classical','Electronic','Country','R&B'];
    final icons = [
      Icons.music_note_rounded, Icons.music_video_rounded, Icons.headphones_rounded,
      Icons.piano_rounded, Icons.queue_music_rounded, Icons.graphic_eq_rounded,
      Icons.album_rounded, Icons.mic_rounded,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        childAspectRatio: 1.8,
        crossAxisSpacing: 14, 
        mainAxisSpacing: 14,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        final colors = [Colors.primaries[index % Colors.primaries.length], Colors.primaries[(index+3) % Colors.primaries.length]];
        return GestureDetector(
          onTap: () => _performSearch(genres[index]),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors[0].withValues(alpha: 0.7), colors[1].withValues(alpha: 0.3)], 
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Text(
                  genres[index], 
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Icon(
                      icons[index], 
                      size: 56, 
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
