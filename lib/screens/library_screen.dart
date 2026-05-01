import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    if (mounted) setState(() {
      _likedSongs = liked;
      _downloadedSongs = downloaded;
      _playlists = playlists;
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = AppLocalizations.of(context)!.libraryTitle;
    if (_showing == 'liked') title = AppLocalizations.of(context)!.libraryLikedSongs;
    if (_showing == 'downloaded') title = AppLocalizations.of(context)!.libraryDownloaded;
    if (_showing == 'playlist') title = _activePlaylist?.name ?? 'Playlist';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _showing != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await _loadAll();
                  if (mounted) setState(() { _showing = null; _activePlaylist = null; });
                })
            : null,
      ),
      body: _showing == 'liked'
          ? _buildSongList(_likedSongs, onDelete: _removeLikedSong)
          : _showing == 'downloaded'
              ? _buildSongList(_downloadedSongs, onDelete: _deleteDownload)
              : _showing == 'playlist' && _activePlaylist != null
                  ? _buildPlaylistDetail(_activePlaylist!)
                  : _buildLibrary(),
    );
  }

  Widget _buildLibrary() {
    return ListView(
      children: [
        ListTile(
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.purple, Colors.blue]),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.favorite, color: Colors.white),
          ),
          title: Text(AppLocalizations.of(context)!.libraryLikedSongs),
          subtitle: Text(AppLocalizations.of(context)!.songs(_likedSongs.length)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _showing = 'liked'),
        ),
        ListTile(
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.download_done, color: Colors.white),
          ),
          title: Text(AppLocalizations.of(context)!.libraryDownloaded),
          subtitle: Text(AppLocalizations.of(context)!.songs(_downloadedSongs.length)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await _loadAll();
            if (mounted) setState(() => _showing = 'downloaded');
          },
        ),
        if (_playlists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(AppLocalizations.of(context)!.libraryPlaylists, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._playlists.map((pl) => Dismissible(
            key: Key(pl.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red, alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) async {
              await context.read<MusicPlayerProvider>().deletePlaylist(pl.id);
              setState(() => _playlists.remove(pl));
            },
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: pl.imageUrl.isNotEmpty
                    ? Image.network(pl.imageUrl, width: 50, height: 50, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _playlistIcon())
                    : _playlistIcon(),
              ),
              title: Text(pl.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(AppLocalizations.of(context)!.songs(pl.songs.length)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() { _activePlaylist = pl; _showing = 'playlist'; }),
            ),
          )),
        ],
      ],
    );
  }

  Widget _playlistIcon() => Container(
    width: 50, height: 50,
    decoration: BoxDecoration(
      color: Colors.grey[800], borderRadius: BorderRadius.circular(4),
    ),
    child: const Icon(Icons.queue_music, color: Colors.white),
  );

  Widget _buildPlaylistDetail(Playlist playlist) {
    final songs = playlist.songs;
    if (songs.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.libraryNoLiked, style: const TextStyle(color: Colors.grey)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.read<MusicPlayerProvider>()
                      .playSong(songs.first, queue: songs),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(AppLocalizations.of(context)!.libraryPlayAll),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 8),
              PlaylistDownloadButton(songs: songs, downloadService: _downloadService),
            ],
          ),
        ),
        Expanded(
          child: Selector<MusicPlayerProvider, Set<String>>(
            selector: (_, p) => Set.from(songs.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
            builder: (context, loadingIds, _) => ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isDownloads ? Icons.download_for_offline : Icons.favorite_border,
                size: 64, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              isDownloads ? 'No downloaded songs yet' : 'No liked songs yet',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              isDownloads ? 'Tap ↓ on any song to download' : 'Songs you listen to will appear here',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Selector<MusicPlayerProvider, Set<String>>(
      selector: (_, p) => Set.from(songs.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
      builder: (context, loadingIds, _) => ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return Dismissible(
            key: Key(song.id),
            direction: isDownloads && onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
            background: Container(
              color: Colors.red, alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                value: widget.songs.isEmpty ? null : _done / widget.songs.length,
                strokeWidth: 2, color: Colors.white,
              ),
            ),
            Text('$_done/${widget.songs.length}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download),
      tooltip: 'Download all',
      onPressed: _downloadAll,
    );
  }
}
