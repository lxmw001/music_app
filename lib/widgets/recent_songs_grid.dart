import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';

class RecentPlaylistsGrid extends StatelessWidget {
  final List<Playlist> playlists;
  const RecentPlaylistsGrid({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final items = playlists.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final playlist = items[index];
        final coverUrl = playlist.imageUrl.isNotEmpty
            ? playlist.imageUrl
            : playlist.songs.isNotEmpty ? playlist.songs.first.imageUrl : '';
        return GestureDetector(
          onTap: () => _openPlaylist(context, playlist),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                coverUrl.isNotEmpty
                    ? Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]))
                    : Container(color: Colors.grey[800], child: const Icon(Icons.queue_music, size: 40)),
                // Dark gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8, left: 8, right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playlist.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                      Text('${playlist.songs.length} songs',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(playlist.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<MusicPlayerProvider>().playSong(playlist.songs.first, queue: playlist.songs);
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: playlist.songs.length,
                itemBuilder: (context, i) {
                  final song = playlist.songs[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(song.imageUrl, width: 40, height: 40, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: Colors.grey[700], child: const Icon(Icons.music_note, size: 16))),
                    ),
                    title: Text(song.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(song.artist, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(context);
                      context.read<MusicPlayerProvider>().playSong(song, queue: playlist.songs);
                    },
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
