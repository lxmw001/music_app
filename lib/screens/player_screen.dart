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
                      child: Image.network(
                        player.currentSong!.imageUrl,
                        fit: BoxFit.cover,
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
                          IconButton(
                            icon: Icon(Icons.favorite_border),
                            onPressed: () {},
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
                            icon: Icon(Icons.skip_next, size: 32),
                            onPressed: player.nextSong,
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
