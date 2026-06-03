import "package:music_app/utils/logger.dart";
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../services/download_service.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/animated_list_item.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService();
  late TabController _tabController;
  
  List<Song> _likedSongs = [];
  List<Song> _downloadedSongs = [];
  List<Playlist> _playlists = [];
  
  bool _offlineOnly = false;
  String _searchQuery = '';
  SongType? _selectedType; 

  final List<List<Color>> _genreGradients = [
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)], // Purple
    [const Color(0xFF00c6ff), const Color(0xFF0072ff)], // Blue
    [const Color(0xFFf953c6), const Color(0xFFb91d73)], // Pink
    [const Color(0xFF11998e), const Color(0xFF38ef7d)], // Green
    [const Color(0xFFff9966), const Color(0xFFff5e62)], // Orange
    [const Color(0xFF7b4397), const Color(0xFFdc2430)], // Red/Purple
    [const Color(0xFF000000), const Color(0xFF434343)], // Dark Grey
    [const Color(0xFF4568dc), const Color(0xFFb06ab3)], // Blue/Purple
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
        setState(() {});
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final provider = context.read<MusicPlayerProvider>();
    final liked = await provider.getMostLikedFromHistory();
    final downloaded = await _downloadService.getDownloadedSongs();
    final playlists = await provider.loadPlaylists();
    if (mounted) {
      setState(() {
        _likedSongs = liked;
        _downloadedSongs = downloaded;
        _playlists = playlists;
      });
    }
  }

  List<Song> get _displaySongs {
    var songs = _allSongsBase;
    if (_selectedType != null) {
      songs = songs.where((s) => s.type == _selectedType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      songs = songs.where((s) => 
        s.title.toLowerCase().contains(query) || s.artist.toLowerCase().contains(query)
      ).toList();
    }
    return songs;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background aura glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  colors: [
                    primaryColor.withValues(alpha: 0.1),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  snap: true,
                  expandedHeight: 120,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: const EdgeInsets.only(left: 16, bottom: 62),
                    title: Text(l10n.libraryTitle, 
                      style: const TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 26, 
                        letterSpacing: -1.0,
                        color: Colors.white,
                      ),
                    ),
                    background: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.black.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                  actions: [
                    _buildOfflineChip(),
                    const SizedBox(width: 12),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: _buildGlassTabBar(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchBar(),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildSongsTab(),
                  _buildPlaylistsTab(),
                  _buildArtistsTab(),
                  _buildGenresTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), 
              blurRadius: 12, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: '  Songs  '),
          Tab(text: '  Playlists  '),
          Tab(text: '  Artists  '),
          Tab(text: '  Genres  '),
        ],
      ),
    );
  }

  Widget _buildOfflineChip() {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _offlineOnly ? Icons.offline_bolt : Icons.offline_bolt_outlined, 
            size: 16, color: _offlineOnly ? Colors.black : Colors.white60,
          ),
          const SizedBox(width: 6),
          const Text('OFFLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ],
      ),
      selected: _offlineOnly,
      onSelected: (v) {
        HapticFeedback.mediumImpact();
        setState(() => _offlineOnly = v);
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      showCheckmark: false,
      shape: StadiumBorder(side: BorderSide(color: _offlineOnly ? Colors.transparent : Colors.white10)),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Find in your library',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongsTab() {
    final songs = _displaySongs;
    return Column(
      children: [
        _buildTypeFilterChips(),
        if (songs.isNotEmpty) _buildActionButtons(songs),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: songs.isEmpty 
              ? _buildEmptyState(Icons.music_note_rounded, 'No tracks found')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 4),
                  itemCount: songs.length,
                  itemBuilder: (context, i) => AnimatedListItem(index: i, child: SongListTile(song: songs[i], queue: songs)),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(List<Song> songs) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _smallActionButton(
              onPressed: () => context.read<MusicPlayerProvider>().playSong(songs.first, queue: songs),
              icon: Icons.play_arrow_rounded,
              label: 'Play All',
              color: primary,
              isFilled: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _smallActionButton(
              onPressed: () {
                final shuffled = List<Song>.from(songs)..shuffle();
                context.read<MusicPlayerProvider>().playSong(shuffled.first, queue: shuffled);
              },
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              color: Colors.white.withValues(alpha: 0.1),
              isFilled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required VoidCallback onPressed, 
    required IconData icon, 
    required String label, 
    required Color color,
    required bool isFilled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isFilled ? null : Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isFilled ? Colors.black : Colors.white),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                color: isFilled ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildTypeChip('All', null),
          const SizedBox(width: 8),
          _buildTypeChip('Songs', SongType.song),
          const SizedBox(width: 8),
          _buildTypeChip('Mixes', SongType.mix),
          const SizedBox(width: 8),
          _buildTypeChip('Videos', SongType.video),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, SongType? type) {
    final isSelected = _selectedType == type;
    final primary = Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        if (selected) setState(() => _selectedType = type);
      },
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      selectedColor: primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? primary : Colors.white60,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: StadiumBorder(side: BorderSide(color: isSelected ? primary.withValues(alpha: 0.5) : Colors.transparent)),
      showCheckmark: false,
    );
  }

  Widget _buildPlaylistsTab() {
    var playlists = _playlists;
    if (_offlineOnly) {
      playlists = playlists.where((p) => p.songs.any((s) => _downloadedSongs.any((d) => d.id == s.id))).toList();
    }
    if (_searchQuery.isNotEmpty) {
      playlists = playlists.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (playlists.isEmpty) return _buildEmptyState(Icons.playlist_play_rounded, 'No playlists found');

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100, top: 8),
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          final pl = playlists[i];
          return AnimatedListItem(index: i, child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Hero(
              tag: 'playlist_${pl.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.white10, width: 0.5),
                  ),
                  child: pl.imageUrl.isNotEmpty
                      ? Image.network(pl.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _playlistIcon())
                      : _playlistIcon(),
                ),
              ),
            ),
            title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${pl.songs.length} tracks', style: const TextStyle(color: Colors.white38, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            onTap: () => _showPlaylistDetail(pl),
          ));
        },
      ),
    );
  }

  List<String> _splitArtists(String artistStr) {
    if (artistStr.isEmpty) return [];
    return artistStr
        .split(RegExp(r'\s*[,&]\s*|\s+(?:feat|ft)\.?\s+|\s+y\s+|\s+&\s+', caseSensitive: false))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }

  Widget _buildArtistsTab() {
    final songs = _allSongsBase;

    // First pass: count solo songs for each individual artist
    final soloCounts = <String, int>{};
    final fullToIndividuals = <String, List<String>>{};
    for (final s in songs) {
      final individuals = _splitArtists(s.artist);
      fullToIndividuals[s.artist] = individuals;
      if (individuals.length == 1) {
        soloCounts[individuals.first] = (soloCounts[individuals.first] ?? 0) + 1;
      }
    }

    // Second pass: build groups
    final artistMap = <String, List<Song>>{};
    for (final s in songs) {
      final individuals = fullToIndividuals[s.artist]!;
      final hasSoloGroup = individuals.any((a) => soloCounts.containsKey(a));
      if (hasSoloGroup) {
        for (final a in individuals) {
          if (soloCounts.containsKey(a)) {
            artistMap.putIfAbsent(a, () => []).add(s);
          }
        }
      } else {
        artistMap.putIfAbsent(s.artist, () => []).add(s);
      }
    }

    var artists = artistMap.keys.where((a) => a.trim().isNotEmpty).toList()..sort();
    if (_searchQuery.isNotEmpty) {
      artists = artists.where((a) => a.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (artists.isEmpty) return _buildEmptyState(Icons.person_rounded, 'No artists found');

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final artist = artists[i];
        final artistSongs = artistMap[artist]!;
        final firstSongImg = artistSongs.first.imageUrl;

        return AnimatedListItem(index: i, child: GestureDetector(
          onTap: () => _showSongsDialog(artist, artistSongs),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    backgroundImage: firstSongImg.isNotEmpty ? NetworkImage(firstSongImg) : null,
                    child: firstSongImg.isEmpty 
                      ? Text(artist[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70))
                      : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist, 
                textAlign: TextAlign.center,
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                '${artistSongs.length} tracks', 
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ));
      },
    );
  }

  Widget _buildGenresTab() {
    final songs = _allSongsBase;
    final Map<String, List<Song>> genreMap = {};
    for (var s in songs) {
      for (var g in s.genres) {
        genreMap.putIfAbsent(g, () => []).add(s);
      }
    }
    var genres = genreMap.keys.toList()..sort();
    if (_searchQuery.isNotEmpty) {
      genres = genres.where((g) => g.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (genres.isEmpty) return _buildEmptyState(Icons.category_rounded, 'No genres found');

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.6, crossAxisSpacing: 14, mainAxisSpacing: 14,
      ),
      itemCount: genres.length,
      itemBuilder: (context, i) {
        final genre = genres[i];
        final gradient = _genreGradients[i % _genreGradients.length];
        return AnimatedListItem(index: i, child: GestureDetector(
          onTap: () => _showSongsDialog(genre, genreMap[genre]!),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient[0].withValues(alpha: 0.8),
                  gradient[1].withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: gradient[0].withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -15, bottom: -15,
                  child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                ),
                Center(
                  child: Text(
                    genre.toUpperCase(), 
                    style: const TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 15, 
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  List<Song> get _allSongsBase {
    final Map<String, Song> uniqueSongs = {};
    for (var s in _likedSongs) {
      uniqueSongs[s.id] = s;
    }
    for (var s in _downloadedSongs) {
      uniqueSongs[s.id] = s;
    }
    for (var p in _playlists) {
      for (var s in p.songs) {
        uniqueSongs[s.id] = s;
      }
    }
    var songs = uniqueSongs.values.toList();
    if (_offlineOnly) {
      songs = songs.where((s) => _downloadedSongs.any((d) => d.id == s.id)).toList();
    }
    return songs;
  }

  Widget _playlistIcon() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.queue_music_rounded, color: Colors.white24, size: 32),
  );

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: Colors.white10),
          ),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
          if (_searchQuery.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Try a different search', style: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  void _showSongsDialog(String title, List<Song> songs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text('${songs.length} tracks', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      final shuffled = List<Song>.from(songs)..shuffle();
                      context.read<MusicPlayerProvider>().playSong(shuffled.first, queue: shuffled);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.black),
                    style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: songs.length,
                itemBuilder: (context, i) => SongListTile(song: songs[i], queue: songs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylistDetail(Playlist playlist) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PlaylistDetailSheet(playlist: playlist, downloadService: _downloadService),
    );
    _loadAll();
  }
}

class _PlaylistDetailSheet extends StatefulWidget {
  final Playlist playlist;
  final DownloadService downloadService;
  const _PlaylistDetailSheet({required this.playlist, required this.downloadService});

  @override
  State<_PlaylistDetailSheet> createState() => _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState extends State<_PlaylistDetailSheet> {
  final Set<String> _downloadingIds = {};
  int _downloadVersion = 0;

  void _onDownloadingChanged(String songId, bool isDownloading) {
    setState(() {
      if (isDownloading) {
        _downloadingIds.add(songId);
      } else {
        _downloadingIds.remove(songId);
        _downloadVersion++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 16), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Hero(
                    tag: 'playlist_${playlist.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: playlist.imageUrl.isNotEmpty 
                        ? Image.network(playlist.imageUrl, width: 90, height: 90, fit: BoxFit.cover)
                        : Container(width: 90, height: 90, color: Colors.white.withValues(alpha: 0.05), child: const Icon(Icons.music_note, size: 40, color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('${playlist.songs.length} tracks', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        context.read<MusicPlayerProvider>().playSong(playlist.songs.first, queue: playlist.songs);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                      label: const Text('Play', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _DownloadAllButton(
                    playlist: playlist,
                    downloadService: widget.downloadService,
                    onDownloadingChanged: _onDownloadingChanged,
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: () {
                      context.read<MusicPlayerProvider>().deletePlaylist(playlist.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Colors.redAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: playlist.songs.length,
                itemBuilder: (context, i) {
                  final song = playlist.songs[i];
                  return SongListTile(
                    key: ValueKey('${song.id}_v$_downloadVersion'),
                    song: song,
                    queue: playlist.songs,
                    isDownloading: _downloadingIds.contains(song.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadAllButton extends StatefulWidget {
  final Playlist playlist;
  final DownloadService downloadService;
  final void Function(String songId, bool isDownloading) onDownloadingChanged;
  const _DownloadAllButton({required this.playlist, required this.downloadService, required this.onDownloadingChanged});

  @override
  State<_DownloadAllButton> createState() => _DownloadAllButtonState();
}

class _DownloadAllButtonState extends State<_DownloadAllButton> {
  bool _isDownloading = false;
  bool _allDownloaded = false;
  int _completed = 0;

  @override
  void initState() {
    super.initState();
    _checkAllDownloaded();
  }

  Future<void> _checkAllDownloaded() async {
    for (final song in widget.playlist.songs) {
      final existing = await widget.downloadService.getDownloadedPathById(song.id);
      if (existing == null) return;
    }
    if (mounted) setState(() => _allDownloaded = true);
  }

  Future<void> _downloadAll() async {
    setState(() { _isDownloading = true; _completed = 0; _allDownloaded = false; });
    final songs = widget.playlist.songs;
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      widget.onDownloadingChanged(song.id, true);
      final existing = await widget.downloadService.getDownloadedPathById(song.id);
      if (existing == null) {
        final result = await widget.downloadService.downloadSong(song);
        if (result == null) {
          rlog('[Library] download failed for ${song.title} (id=${song.id})');
        }
      }
      widget.onDownloadingChanged(song.id, false);
      if (mounted) setState(() => _completed = i + 1);
    }
    if (mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isDownloading = false;
        _allDownloaded = _completed == songs.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $_completed of ${songs.length} tracks'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: _isDownloading || _allDownloaded ? null : _downloadAll,
      icon: _isDownloading
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Icon(_allDownloaded ? Icons.download_done_rounded : Icons.download_rounded, 
              size: 22, 
              color: _allDownloaded ? Theme.of(context).colorScheme.primary : Colors.white
            ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
