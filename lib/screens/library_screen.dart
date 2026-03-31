import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../widgets/song_list_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Song> _likedSongs = [];
  bool _showingLiked = false;

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
  }

  Future<void> _loadLikedSongs() async {
    final songs = await context.read<MusicPlayerProvider>().getMostLikedFromHistory();
    if (mounted) setState(() => _likedSongs = songs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showingLiked ? 'Liked Songs' : 'Your Library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _showingLiked
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _showingLiked = false))
            : null,
      ),
      body: _showingLiked ? _buildLikedSongs() : _buildLibrary(),
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
          onTap: () => setState(() => _showingLiked = true),
        ),
      ],
    );
  }

  Widget _buildLikedSongs() {
    if (_likedSongs.isEmpty) {
      return const Center(child: Text('No liked songs yet.\nTap ♥ on any song to like it.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
    }
    return Selector<MusicPlayerProvider, Set<String>>(
      selector: (_, p) => Set.from(_likedSongs.map((s) => s.id).where((id) => p.isLoadingAudio(id))),
      builder: (context, loadingIds, _) => ListView.builder(
        itemCount: _likedSongs.length,
        itemBuilder: (context, index) {
          final song = _likedSongs[index];
          return SongListTile(song: song, queue: _likedSongs, isLoading: loadingIds.contains(song.id));
        },
      ),
    );
  }
}
