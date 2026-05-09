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

class _LibraryScreenState extends State<LibraryScreen> {
  final _downloadService = DownloadService();
  List<Song> _likedSongs = [];
  List<Song> _downloadedSongs = [];
  List<Playlist> _playlists = [];
  String? _showing; // null=library, 'liked', 'downloaded', 'playlist'
  Playlist? _activePlaylist;

  @override
  void initState() {
    super.initState();
    _loadAll();
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

  @override
  Widget build(BuildContext context) {
    String title = AppLocalizations.of(context)!.libraryTitle;
    if (_showing == 'liked') title = AppLocalizations.of(context)!.libraryLikedSongs;
    if (_showing == 'downloaded') title = AppLocalizations.of(context)!.libraryDownloaded;
    if (_showing == 'playlist') title = _activePlaylist?.name ?? 'Playlist';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _showing != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () async {
                  await _loadAll();
                  if (mounted) setState(() { _showing = null; _activePlaylist = null; });
                })
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_showing == 'liked') return _buildSongList(_likedSongs, onDelete: _removeLikedSong);
    if (_showing == 'downloaded') return _buildSongList(_downloadedSongs, onDelete: _deleteDownload);
    if (_showing == 'playlist' && _activePlaylist != null) return _buildPlaylistDetail(_activePlaylist!);
    return _buildLibrary();
  }

  Widget _buildLibrary() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          _buildLibraryCategory(
            title: AppLocalizations.of(context)!.libraryLikedSongs,
            subtitle: AppLocalizations.of(context)!.songs(_likedSongs.length),
            icon: Icons.favorite_rounded,
            gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            onTap: () => setState(() => _showing = 'liked'),
          ),
          const SizedBox(height: 12),
          _buildLibraryCategory(
            title: AppLocalizations.of(context)!.libraryDownloaded,
            subtitle: AppLocalizations.of(context)!.songs(_downloadedSongs.length),
            icon: Icons.download_done_rounded,
            gradient: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
            onTap: () async {
              await _loadAll();
              if (mounted) setState(() => _showing = 'downloaded');
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.libraryPlaylists,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () {
                  // Add playlist logic could go here
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_playlists.isEmpty)
            _buildEmptyState(Icons.playlist_add_rounded, "No playlists created yet")
          else
            ..._playlists.map((pl) => _buildPlaylistTile(pl)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLibraryCategory({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(Playlist pl) {
    return Dismissible(
      key: Key(pl.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await context.read<MusicPlayerProvider>().deletePlaylist(pl.id);
        setState(() => _playlists.remove(pl));
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: pl.imageUrl.isNotEmpty
              ? Image.network(pl.imageUrl, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _playlistIcon())
              : _playlistIcon(),
        ),
        title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(AppLocalizations.of(context)!.songs(pl.songs.length)),
        trailing: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
        onTap: () => setState(() { _activePlaylist = pl; _showing = 'playlist'; }),
      ),
    );
  }

  Widget _playlistIcon() => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white24),
  );

  Widget _buildPlaylistDetail(Playlist playlist) {
    final songs = playlist.songs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: songs.isEmpty ? null : () => context.read<MusicPlayerProvider>().playSong(songs.first, queue: songs),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(AppLocalizations.of(context)!.libraryPlayAll),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PlaylistDownloadButton(songs: songs, downloadService: _downloadService),
            ],
          ),
        ),
        Expanded(
          child: songs.isEmpty 
              ? _buildEmptyState(Icons.music_off_rounded, AppLocalizations.of(context)!.libraryNoLiked)
              : Selector<MusicPlayerProvider, Set<String>>(
                  selector: (_, p) => Set.from(songs.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
                  builder: (context, loadingIds, _) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: songs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == songs.length) return const SizedBox(height: 100);
                      final song = songs[index];
                      return SongListTile(
                        song: song,
                        isLoading: loadingIds.contains(song.id),
                        queue: songs,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSongList(List<Song> songs, {Future<void> Function(Song)? onDelete}) {
    final isDownloads = _showing == 'downloaded';
    if (songs.isEmpty) {
      return _buildEmptyState(
        isDownloads ? Icons.download_for_offline_rounded : Icons.favorite_border_rounded,
        isDownloads ? 'No downloaded songs' : 'No liked songs',
      );
    }
    return Selector<MusicPlayerProvider, Set<String>>(
      selector: (_, p) => Set.from(songs.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
      builder: (context, loadingIds, _) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: songs.length + 1,
        itemBuilder: (context, index) {
          if (index == songs.length) return const SizedBox(height: 100);
          final song = songs[index];
          return Dismissible(
            key: Key(song.id),
            direction: isDownloads && onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            onDismissed: (_) async {
              await onDelete!(song);
              setState(() => songs.remove(song));
            },
            child: SongListTile(
              song: song,
              isLoading: loadingIds.contains(song.id),
              queue: songs,
              onRemove: !isDownloads && onDelete != null ? () async {
                await onDelete(song);
              } : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _removeLikedSong(Song song) async {
    await context.read<MusicPlayerProvider>().toggleLike(song);
    setState(() => _likedSongs.remove(song));
  }

  Future<void> _deleteDownload(Song song) async {
    await _downloadService.deleteDownload(song);
    await _loadAll();
  }
}

class PlaylistDownloadButton extends StatefulWidget {
  final List<Song> songs;
  final DownloadService downloadService;
  const PlaylistDownloadButton({super.key, required this.songs, required this.downloadService});

  @override
  State<PlaylistDownloadButton> createState() => _PlaylistDownloadButtonState();
}

class _PlaylistDownloadButtonState extends State<PlaylistDownloadButton> {
  bool _downloading = false;
  int _done = 0;

  Future<void> _downloadAll() async {
    setState(() { _downloading = true; _done = 0; });
    for (final song in widget.songs) {
      await widget.downloadService.downloadSong(song);
      if (mounted) setState(() => _done++);
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_downloading) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                value: widget.songs.isEmpty ? null : _done / widget.songs.length,
                strokeWidth: 2, color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Text('$_done/${widget.songs.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return IconButton.filledTonal(
      icon: const Icon(Icons.download_rounded),
      onPressed: widget.songs.isEmpty ? null : _downloadAll,
    );
  }
}
