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
import '../providers/auth_provider.dart';
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
  List<String> _history = [];
  bool isLoading = false;
  String _currentQuery = '';
  String? _activeFilter; 
  bool _showRecentAndPopular = false;
  bool _forceRefresh = false;

  final List<List<Color>> _categoryGradients = [
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)], // Purple
    [const Color(0xFF00c6ff), const Color(0xFF0072ff)], // Blue
    [const Color(0xFFf953c6), const Color(0xFFb91d73)], // Pink
    [const Color(0xFF11998e), const Color(0xFF38ef7d)], // Green
    [const Color(0xFFff9966), const Color(0xFFff5e62)], // Orange
    [const Color(0xFF7b4397), const Color(0xFFdc2430)], // Red/Purple
    [const Color(0xFF4568dc), const Color(0xFFb06ab3)], // Blue/Purple
    [const Color(0xFF085078), const Color(0xFF85D8CE)], // Teal
  ];

  bool get _hasResults => !_result.isEmpty;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _serverService.getSearchSuggestions().then((s) {
      if (mounted) setState(() => _popularSuggestions = s);
    });
    _focusNode.addListener(() {
      if (mounted) {
        if (!_focusNode.hasFocus) {
          setState(() => _showRecentAndPopular = false);
        } else {
          setState(() {});
        }
      }
    });
    _updateHistory();
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateHistory() async {
    final history = await context.read<MusicPlayerProvider>().getSearchHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      _resetSearch();
      return;
    }
    _focusNode.unfocus();
    setState(() { 
      isLoading = true; 
      _activeFilter = null; 
      _showRecentAndPopular = false;
    });
    final result = await _youtubeService.searchSongs(query, force: _forceRefresh);
    setState(() { 
      _result = result; 
      isLoading = false; 
      _currentQuery = query; 
      _activeFilter = 'songs'; 
    });
    if (mounted) {
      await context.read<MusicPlayerProvider>().saveSearch(query);
      _updateHistory();
    }
  }

  void _resetSearch() {
    _searchController.clear();
    _focusNode.unfocus();
    setState(() { 
      _result = const MusicSearchResult(); 
      _currentQuery = ''; 
      _activeFilter = null; 
      _showRecentAndPopular = false;
    });
  }

  Iterable<String> _matchingSuggestions(String input) {
    if (input.isEmpty) return const Iterable<String>.empty();
    final lower = input.toLowerCase();
    final historyMatches = _history.where((s) => s.toLowerCase().contains(lower));
    final popularMatches = _popularSuggestions.where((s) => s.toLowerCase().contains(lower));
    return {...historyMatches, ...popularMatches}.take(10);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isSearching = _showRecentAndPopular && _focusNode.hasFocus && _searchController.text.isEmpty;
    final isActive = _hasResults || _focusNode.hasFocus || _searchController.text.isNotEmpty;

    return PopScope(
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isActive) _resetSearch();
      },
      child: Scaffold(
        body: Stack(
          children: [
            MeshGradient(color: theme.accentColor),
            SafeArea(
              child: Column(
                children: [
                  _buildSearchBar(),
                  if (context.watch<AuthProvider>().isAdmin) _buildAdminForceRefresh(),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (isSearching || !_hasResults) ? _buildEmptyState(isSearching) : _buildResults(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminForceRefresh() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          SizedBox(
            height: 24, width: 24,
            child: Checkbox(
              value: _forceRefresh,
              onChanged: (v) => setState(() => _forceRefresh = v ?? false),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.searchForceRefresh, style: const TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RawAutocomplete<String>(
        focusNode: _focusNode,
        textEditingController: _searchController,
        optionsBuilder: (v) => _matchingSuggestions(v.text),
        onSelected: (s) { 
          _searchController.text = s; 
          _performSearch(s); 
        },
        fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  onTap: () => setState(() => _showRecentAndPopular = true),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(ctx)!.searchHint,
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: _resetSearch)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            padding: const EdgeInsets.only(top: 8, right: 32),
            child: Material(
              elevation: 20,
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 280, maxWidth: MediaQuery.of(context).size.width - 32),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10, indent: 50),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final isHistory = _history.contains(option);
                      return ListTile(
                        leading: Icon(isHistory ? Icons.history_rounded : Icons.trending_up_rounded, size: 20, color: Colors.white38),
                        title: Text(option, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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
          if (chips.length > 1) _buildFilterChips(chips),
          const SizedBox(height: 8),
          Expanded(child: _buildFilteredList(loadingIds)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<String> chips) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (context, i) {
          final chip = chips[i];
          final active = _activeFilter == chip.toLowerCase();
          final primary = Theme.of(context).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(chip),
              selected: active,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() => _activeFilter = active ? null : chip.toLowerCase());
              },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(color: active ? primary : Colors.white60, fontWeight: active ? FontWeight.w900 : FontWeight.w500, fontSize: 13),
              shape: StadiumBorder(side: BorderSide(color: active ? primary.withValues(alpha: 0.5) : Colors.transparent)),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredList(Set<String> loadingIds) {
    switch (_activeFilter) {
      case 'songs': return _songsList(_result.songs, loadingIds, showLoadMore: _result.hasMoreSongs);
      case 'mixes': return _songsList(_result.mixes, loadingIds);
      case 'videos': return _songsList(_result.videos, loadingIds);
      case 'artists': return _artistsList();
      default:
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (_result.songs.isNotEmpty) ...[
              _sectionHeader('Top Results'),
              for (var i = 0; i < _result.songs.length && i < 3; i++)
                AnimatedListItem(index: i, child: _songTile(_result.songs[i], loadingIds)),
              if (_result.songs.length > 3)
                _seeAllButton('Songs', () => setState(() => _activeFilter = 'songs')),
            ],
            if (_result.mixes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionHeader('Featured Mixes'),
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
    if (songs.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.searchNoResults, style: const TextStyle(color: Colors.white38)));
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
                  child: Text(AppLocalizations.of(context)!.commonLoadMore),
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
    if (_result.artists.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.searchNoArtists, style: const TextStyle(color: Colors.white38)));
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    leading: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Center(child: Text(a.isNotEmpty ? a[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w900))),
    ),
    title: Text(a, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    onTap: () => _performSearch(a),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white38)),
  );

  Widget _seeAllButton(String label, VoidCallback onTap) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: onTap,
      child: Text(AppLocalizations.of(context)!.commonSeeAll(label), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 13)),
    ),
  );

  Widget _buildEmptyState(bool isSearching) {
    final theme = context.watch<ThemeProvider>();
    final player = context.read<MusicPlayerProvider>();
    
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        if (isSearching) ...[
          if (_history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.searchRecent, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await player.clearSearchHistory();
                      _updateHistory();
                    },
                    child: Text(AppLocalizations.of(context)!.searchClearAll, style: TextStyle(color: theme.accentColor, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _history.length,
                itemBuilder: (context, i) {
                  final query = _history[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () { _searchController.text = query; _performSearch(query); },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_rounded, size: 16, color: Colors.white38),
                              const SizedBox(width: 8),
                              Text(query, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white38),
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  await player.deleteSearch(query);
                                  _updateHistory();
                                },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
          
          if (_popularSuggestions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(AppLocalizations.of(context)!.searchPopular, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
            ...List.generate(_popularSuggestions.length > 5 ? 5 : _popularSuggestions.length, (index) {
              final query = _popularSuggestions[index];
              final rank = index + 1;
              final isTop3 = rank <= 3;
              return AnimatedListItem(index: index, child: ListTile(
                leading: Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isTop3 ? LinearGradient(colors: [theme.accentColor, theme.accentColor.withValues(alpha: 0.6)]) : null,
                    color: isTop3 ? null : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$rank', style: TextStyle(color: isTop3 ? Colors.black : Colors.white38, fontWeight: FontWeight.w900)),
                ),
                title: Text(query, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                trailing: Icon(Icons.trending_up_rounded, size: 20, color: isTop3 ? theme.accentColor.withValues(alpha: 0.5) : Colors.white10),
                onTap: () { _searchController.text = query; _performSearch(query); },
              ));
            }),
            const SizedBox(height: 32),
          ],
        ],
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(AppLocalizations.of(context)!.searchBrowseGenre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ),
        _buildDiscoveryGrid(),
        const SizedBox(height: 150),
      ],
    );
  }

  Widget _buildDiscoveryGrid() {
    final genres = ['Pop','Rock','Hip-Hop','Jazz','Classical','Electronic','Chill','Mood'];
    final icons = [Icons.music_note, Icons.electric_bolt, Icons.headphones, Icons.piano, Icons.auto_stories, Icons.blur_on, Icons.nightlight_round, Icons.face_retouching_natural];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.7, crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final gradient = _categoryGradients[index % _categoryGradients.length];
        return _DiscoveryCard(
          label: genres[index],
          icon: icons[index],
          colors: gradient,
          onTap: () => _performSearch(genres[index]),
        );
      },
    );
  }
}

class _DiscoveryCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _DiscoveryCard({required this.label, required this.icon, required this.colors, required this.onTap});

  @override
  State<_DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<_DiscoveryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.colors[0].withValues(alpha: 0.8), widget.colors[1].withValues(alpha: 0.6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: widget.colors[0].withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -15, bottom: -15,
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Icon(widget.icon, size: 72, color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.label.toUpperCase(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
