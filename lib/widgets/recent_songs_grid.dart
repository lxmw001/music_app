import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import 'song_list_tile.dart';

class RecentPlaylistsGrid extends StatelessWidget {
  final List<Playlist> playlists;
  const RecentPlaylistsGrid({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final items = playlists.take(10).toList();
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final playlist = items[index];
          return GestureDetector(
            onTap: () => _openPlaylist(context, playlist),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: playlist.imageUrl.isNotEmpty
                            ? Image.network(
                                playlist.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _icon(),
                              )
                            : _icon(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    playlist.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${playlist.songs.length} songs',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _icon() => Container(
    color: Colors.grey[900],
    child: const Icon(Icons.queue_music_rounded, size: 48, color: Colors.white24),
  );

  void _openPlaylist(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: playlist.imageUrl.isNotEmpty
                      ? Image.network(playlist.imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                      : Container(width: 60, height: 60, color: Colors.grey[800], child: const Icon(Icons.music_note)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text('${playlist.songs.length} songs', style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<MusicPlayerProvider>().playSong(playlist.songs.first, queue: playlist.songs, fromQueue: true);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                    style: IconButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: playlist.songs.length,
                itemBuilder: (context, i) {
                  final song = playlist.songs[i];
                  return SongListTile(
                    song: song,
                    queue: playlist.songs,
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
