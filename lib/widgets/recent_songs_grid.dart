import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';

class RecentPlaylistsGrid extends StatelessWidget {
  final List<Playlist> playlists;
  const RecentPlaylistsGrid({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final items = playlists.take(10).toList();
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final playlist = items[index];
          return GestureDetector(
            onTap: () => _openPlaylist(context, playlist),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: playlist.imageUrl.isNotEmpty
                        ? Image.network(playlist.imageUrl, width: 140, height: 130, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _icon(140, 130))
                        : _icon(140, 130),
                  ),
                  const SizedBox(height: 6),
                  Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text('${playlist.songs.length} songs',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _icon(double w, double h) => Container(
    width: w, height: h, color: Colors.grey[700],
    child: const Icon(Icons.queue_music, size: 32, color: Colors.white54),
  );

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
                      context.read<MusicPlayerProvider>().playSong(playlist.songs.first, queue: playlist.songs, fromQueue: true);
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
                      context.read<MusicPlayerProvider>().playSong(song, queue: playlist.songs, fromQueue: true);
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
