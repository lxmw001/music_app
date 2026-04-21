import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_player_provider.dart';
import '../services/download_service.dart';

class PlayerScreen extends StatefulWidget {
  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _downloadService = DownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final song = context.read<MusicPlayerProvider>().currentSong;
    if (song == null) return;
    final path = await _downloadService.getDownloadedPath(song);
    if (mounted) setState(() => _downloadedPath = path);
  }

  Future<void> _download(BuildContext context) async {
    final song = context.read<MusicPlayerProvider>().currentSong;
    if (song == null || song.audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Play the song first to enable download')),
      );
      return;
    }
    setState(() { _isDownloading = true; _downloadProgress = 0; });
    final path = await _downloadService.downloadSong(song, onProgress: (received, total) {
      if (total > 0 && mounted) setState(() => _downloadProgress = received / total);
    });
    if (mounted) setState(() { _isDownloading = false; _downloadedPath = path; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null ? 'Downloaded!' : 'Download failed'),
      ));
    }
  }

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
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  strokeWidth: 2, color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(_downloadedPath != null ? Icons.download_done : Icons.download),
              color: _downloadedPath != null ? Colors.green : null,
              onPressed: _downloadedPath != null ? null : () => _download(context),
            ),
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () => _showQueueSheet(context),
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
                            value: player.currentPosition.inSeconds.toDouble().clamp(0.0, player.totalDuration.inSeconds.toDouble().clamp(1.0, double.infinity)),
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<MusicPlayerProvider>(),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Consumer<MusicPlayerProvider>(
            builder: (context, player, __) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('Up Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      Text('${player.queue.length} songs', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: player.queue.length,
                    itemBuilder: (context, i) {
                      final song = player.queue[i];
                      final isCurrent = i == player.currentIndex;
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            song.imageUrl,
                            width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48, height: 48, color: Colors.grey[800],
                              child: const Icon(Icons.music_note, size: 20),
                            ),
                          ),
                        ),
                        title: Text(song.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isCurrent ? Colors.green : Colors.white,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(song.artist,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: i < player.currentIndex ? Colors.grey[700] : Colors.grey)),
                        trailing: isCurrent ? const Icon(Icons.equalizer, color: Colors.green) : null,
                        onTap: () {
                          player.playSong(song);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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
