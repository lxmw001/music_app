import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';

class SongListTile extends StatelessWidget {
  final Song song;
  final List<Song> queue;
  final bool isLoading;

  const SongListTile({super.key, required this.song, required this.queue, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              song.imageUrl,
              width: 50, height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50, height: 50,
                color: Colors.grey[800],
                child: const Icon(Icons.music_note),
              ),
            ),
            if (isLoading)
              Container(
                width: 50, height: 50,
                color: Colors.black54,
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
          ],
        ),
      ),
      title: Text(song.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, overflow: TextOverflow.ellipsis),
      trailing: FutureBuilder<bool>(
        future: context.read<MusicPlayerProvider>().isLiked(song.id),
        builder: (context, snap) {
          final liked = snap.data ?? false;
          return IconButton(
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border, size: 20, color: liked ? Colors.green : Colors.grey),
            onPressed: () => context.read<MusicPlayerProvider>().toggleLike(song),
          );
        },
      ),
      onTap: () {
        print('[SongListTile] tapped: ${song.title}');
        context.read<MusicPlayerProvider>().playSong(song, queue: [song]);
      },
    );
  }
}
