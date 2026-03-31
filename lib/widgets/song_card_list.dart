import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import 'song_card.dart';

class SongCardList extends StatelessWidget {
  final List<Song> songs;
  const SongCardList({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Selector<MusicPlayerProvider, String?>(
        selector: (_, p) {
          try { return songs.firstWhere((s) => p.isLoadingAudio(s.id)).id; }
          catch (_) { return null; }
        },
        builder: (context, loadingId, _) => ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongCard(song: song, queue: songs, isLoading: song.id == loadingId);
          },
        ),
      ),
    );
  }
}
