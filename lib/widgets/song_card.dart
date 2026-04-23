import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';

class SongCard extends StatelessWidget {
  final Song song;
  final List<Song> queue;
  final bool isLoading;

  const SongCard({super.key, required this.song, required this.queue, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<MusicPlayerProvider>().playSong(song),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    song.imageUrl,
                    width: 160, height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 160, height: 150,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note),
                    ),
                  ),
                  if (isLoading)
                    Container(
                      width: 160, height: 150,
                      color: Colors.black45,
                      child: const Center(
                        child: SizedBox(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 2),
            Text(song.artist, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
