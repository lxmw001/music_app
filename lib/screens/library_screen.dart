import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../services/download_service.dart';
import '../widgets/song_list_tile.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  /// Combines all sources and filters by offline/search/type
  List<Song> get _displaySongs {
    final Map<String, Song> uniqueSongs = {};
    for (var s in _likedSongs) uniqueSongs[s.id] = s;
    for (var s in _downloadedSongs) uniqueSongs[s.id] = s;
    for (var p in _playlists) {
      for (var s in p.songs) {
        uniqueSongs[s.id] = s;
      }
    }
    
    var songs = uniqueSongs.values.toList();
    
    if (_offlineOnly) {
      songs = songs.where((s) => _downloadedSongs.any((d) => d.id == s.id)).toList();
    }
    
    if (_selectedType != null) {
      songs = songs.where((s) => s.type == _selectedType).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      songs = songs.where((s) => 
        s.title.toLowerCase().contains(query) || 
        s.artist.toLowerCase().contains(query)
      ).toList();
    }
    
    return songs;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: true,
              centerTitle: false,
              title: Text(l10n.libraryTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              actions: [
                _buildOfflineToggle(),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(text: 'Songs'),
                  Tab(text: 'Playlists'),
                  Tab(text: 'Artists'),
                  Tab(text: 'Genres'),
                ],
              ),
            ),
          ],
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSongsTab(),
                    _buildPlaylistsTab(),
                    _buildArtistsTab(),
                    _buildGenresTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _offlineOnly ? Icons.check_circle_rounded : Icons.offline_bolt_outlined, 
              size: 16, 
              color: _offlineOnly ? Colors.black : Colors.grey,
            ),
            const SizedBox(width: 4),
            const Text('Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        selected: _offlineOnly,
        onSelected: (v) => setState(() => _offlineOnly = v),
        selectedColor: Theme.of(context).primaryColor,
        checkmarkColor: Colors.black,
        backgroundColor: Colors.grey[900],
        showCheckmark: false,
        side: BorderSide(color: _offlineOnly ? Colors.transparent : Colors.grey[800]!),
        shape: StadiumBorder(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search in library',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
            prefixIcon: const Icon(Icons.search_rounded, size: 22, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear_rounded, size: 20), onPressed: () => setState(() => _searchQuery = '')) 
                : null,
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: songs.isEmpty 
              ? _buildEmptyState(Icons.music_note_rounded, 'No songs found')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 8),
                  itemCount: songs.length,
                  itemBuilder: (context, i) => SongListTile(song: songs[i], queue: songs),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedType = type);
      },
      backgroundColor: Colors.transparent,
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      shape: StadiumBorder(side: BorderSide(color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800]!)),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          final pl = playlists[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: pl.imageUrl.isNotEmpty
                  ? Image.network(pl.imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _playlistIcon())
                  : _playlistIcon(),
            ),
            title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${pl.songs.length} songs', style: TextStyle(color: Colors.grey[400])),
            onTap: () => _showPlaylistDetail(pl),
          );
        },
      ),
    );
  }

  Widget _buildArtistsTab() {
    final songs = _allSongsBase;
    final Map<String, List<Song>> artistMap = {};
    for (var s in songs) {
      artistMap.putIfAbsent(s.artist, () => []).add(s);
    }
    
    var artists = artistMap.keys.toList()..sort();
    if (_searchQuery.isNotEmpty) {
      artists = artists.where((a) => a.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    if (artists.isEmpty) return _buildEmptyState(Icons.person_rounded, 'No artists found');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final artist = artists[i];
        final artistSongs = artistMap[artist]!;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
            child: Center(child: Text(artist[0].toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          ),
          title: Text(artist, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text('${artistSongs.length} songs', style: TextStyle(color: Colors.grey[400])),
          onTap: () => _showSongsDialog(artist, artistSongs),
        );
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: genres.length,
      itemBuilder: (context, i) {
        final genre = genres[i];
        return GestureDetector(
          onTap: () => _showSongsDialog(genre, genreMap[genre]!),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[800]!, Colors.grey[900]!],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(genre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      },
    );
  }

  List<Song> get _allSongsBase {
    final Map<String, Song> uniqueSongs = {};
    for (var s in _likedSongs) uniqueSongs[s.id] = s;
    for (var s in _downloadedSongs) uniqueSongs[s.id] = s;
    for (var p in _playlists) for (var s in p.songs) uniqueSongs[s.id] = s;
    
    var songs = uniqueSongs.values.toList();
    if (_offlineOnly) {
      songs = songs.where((s) => _downloadedSongs.any((d) => d.id == s.id)).toList();
    }
    return songs;
  }

  Widget _playlistIcon() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 32),
  );

  Widget _buildEmptyState(IconData icon, String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
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
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: songs.length,
                itemBuilder: (context, i) => SongListTile(song: songs[i], queue: songs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistDetail(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PlaylistDetailSheet(playlist: playlist, downloadService: _downloadService),
    );
  }
}

class _PlaylistDetailSheet extends StatelessWidget {
  final Playlist playlist;
  final DownloadService downloadService;
  const _PlaylistDetailSheet({required this.playlist, required this.downloadService});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: playlist.imageUrl.isNotEmpty 
                    ? Image.network(playlist.imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                    : Container(width: 80, height: 80, color: Colors.grey[800], child: const Icon(Icons.music_note, size: 40)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playlist.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('${playlist.songs.length} songs', style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<MusicPlayerProvider>().playSong(playlist.songs.first, queue: playlist.songs);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                  style: IconButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.all(12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: playlist.songs.length,
              itemBuilder: (context, i) => SongListTile(song: playlist.songs[i], queue: playlist.songs),
            ),
          ),
        ],
      ),
    );
  }
}
