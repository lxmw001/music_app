import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import 'song_card.dart';
import 'animated_list_item.dart';

class SongCardList extends StatelessWidget {
  final List<Song> songs;
  const SongCardList({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220, // Increased slightly to accommodate new shadows and labels
      child: Selector<MusicPlayerProvider, String?>(
        selector: (_, p) {
          try { return songs.firstWhere((s) => p.isLoadingAudio(s.id)).id; }
          catch (_) { return null; }
        },
        builder: (context, loadingId, _) => ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 4), // Balanced padding
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return AnimatedListItem(
              index: index,
              child: SongCard(
                song: song, 
                queue: songs, 
                isLoading: song.id == loadingId
              ),
            );
          },
        ),
      ),
    );
  }
}
