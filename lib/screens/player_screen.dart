import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';

class PlayerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Now Playing'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<MusicPlayerProvider>(
        builder: (context, player, child) {
          if (player.currentSong == null) {
            return Center(child: Text('No song playing'));
          }
          final isLoading = player.isLoadingAudio(player.currentSong!.id);

          return Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            player.currentSong!.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[800], child: Icon(Icons.music_note, size: 80)),
                          ),
                          if (isLoading)
                            Container(
                              color: Colors.black54,
                              child: const CircularProgressIndicator(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.currentSong!.title,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  player.currentSong!.artist,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          FutureBuilder<bool>(
                            future: player.isLiked(player.currentSong!.id),
                            builder: (context, snap) {
                              final liked = snap.data ?? false;
                              return IconButton(
                                icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.green : null),
                                onPressed: () => player.toggleLike(player.currentSong!),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Column(
                        children: [
                          Slider(
                            value: player.currentPosition.inSeconds.toDouble(),
                            max: player.totalDuration.inSeconds.toDouble().clamp(1.0, double.infinity),
                            onChanged: (value) {
                              player.seekTo(Duration(seconds: value.toInt()));
                            },
                            activeColor: Colors.green,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(player.currentPosition)),
                                Text(_formatDuration(player.totalDuration)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: player.isShuffled ? Colors.green : Colors.grey,
                            ),
                            onPressed: player.toggleShuffle,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_previous, size: 32),
                            onPressed: player.previousSong,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                if (player.isPlaying) {
                                  player.pause();
                                } else {
                                  player.resume();
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next, size: 32,
                              color: isLoading ? Colors.grey : Colors.white),
                            onPressed: isLoading ? null : player.nextSong,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.repeat,
                              color: player.isRepeating ? Colors.green : Colors.grey,
                            ),
                            onPressed: player.toggleRepeat,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Up Next queue
                if (player.queue.length > 1) ...[
                  const Divider(color: Colors.grey),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Text('Up Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text('${player.queue.length - player.currentIndex - 1} songs',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: player.queue.length,
                      itemBuilder: (context, i) {
                        final song = player.queue[i];
                        final isCurrent = i == player.currentIndex;
                        if (i <= player.currentIndex) return const SizedBox.shrink();
                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              song.imageUrl,
                              width: 40, height: 40, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40, height: 40, color: Colors.grey[800],
                                child: const Icon(Icons.music_note, size: 16),
                              ),
                            ),
                          ),
                          title: Text(song.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isCurrent ? Colors.green : Colors.white, fontSize: 13)),
                          subtitle: Text(song.artist,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => player.playSong(song),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
