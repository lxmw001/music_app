import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';

class RecentSongsGrid extends StatelessWidget {
  final List<Song> songs;
  const RecentSongsGrid({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    // Show max 6 (3 rows × 2 cols)
    final items = songs.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final song = items[index];
        return GestureDetector(
          onTap: () => context.read<MusicPlayerProvider>().playSong(song, queue: songs),
          child: Container(
            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                  child: Image.network(
                    song.imageUrl,
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[700], child: const Icon(Icons.music_note, size: 20)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                      Text(song.artist, style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis),
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
}
