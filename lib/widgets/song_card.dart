import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      onTap: () {
        HapticFeedback.lightImpact();
        context.read<MusicPlayerProvider>().playSong(song);
      },
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // High-End Glass Container
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Image with subtle gradient darkening
                      Image.network(
                        song.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultCover(),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.05),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isLoading)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: SizedBox(
                              width: 32, height: 32,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                            ),
                          ),
                        ),
                      // Floating Action Button
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              song.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.5),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultCover() => Container(
    color: Colors.grey[900],
    child: const Icon(Icons.music_note_rounded, color: Colors.white12, size: 54),
  );
}
