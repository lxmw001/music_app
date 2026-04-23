import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String? _showing; // null=library, 'liked', 'downloaded'

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
    _loadDownloadedSongs();
  }

  Future<void> _loadLikedSongs() async {
    final songs = await context.read<MusicPlayerProvider>().getMostLikedFromHistory();
    if (mounted) setState(() => _likedSongs = songs);
  }

  Future<void> _loadDownloadedSongs() async {
    final songs = await _downloadService.getDownloadedSongs();
    if (mounted) setState(() => _downloadedSongs = songs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showing == 'liked' ? 'Liked Songs' : _showing == 'downloaded' ? 'Downloaded' : 'Your Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _showing != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await _loadDownloadedSongs();
                  if (mounted) setState(() => _showing = null);
                })
            : null,
      ),
      body: _showing == 'liked'
          ? _buildSongList(_likedSongs, onDelete: _removeLikedSong)
          : _showing == 'downloaded'
              ? _buildSongList(_downloadedSongs, onDelete: _deleteDownload)
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
          title: const Text('Liked Songs'),
          subtitle: Text('${_likedSongs.length} songs'),
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
          title: const Text('Downloaded'),
          subtitle: Text('${_downloadedSongs.length} songs'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await _loadDownloadedSongs();
            if (mounted) setState(() => _showing = 'downloaded');
          },
        ),
      ],
    );
  }

  Widget _buildSongList(List<Song> songs, {Future<void> Function(Song)? onDelete}) {
    final isDownloads = _showing == 'downloaded';
    if (songs.isEmpty) {
      return Center(child: Text(
        isDownloads ? 'No downloaded songs yet.\nTap ↓ on any song to download.' : 'No liked songs yet.',
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey),
      ));
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
    await _loadDownloadedSongs();
  }
}
