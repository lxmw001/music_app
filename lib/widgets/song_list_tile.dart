import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../screens/player_screen.dart';
import '../services/download_service.dart';

class SongListTile extends StatefulWidget {
  final Song song;
  final bool isLoading;
  final VoidCallback? onRemove;
  final List<Song>? queue;
  final VoidCallback? onTap;
  final bool showDownload;

  const SongListTile({super.key, required this.song, this.isLoading = false, this.onRemove, this.queue, this.onTap, this.showDownload = true});

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile> with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService();
  bool _isDownloading = false;
  bool _isDownloaded = false;
  late final AnimationController _eqController;

  @override
  void initState() {
    super.initState();
    _eqController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _checkDownloaded();
  }

  @override
  void dispose() {
    _eqController.dispose();
    super.dispose();
  }

  Future<void> _checkDownloaded() async {
    final path = await _downloadService.getDownloadedPathById(widget.song.id);
    if (mounted) setState(() => _isDownloaded = path != null);
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    final path = await _downloadService.downloadSong(widget.song);
    if (mounted) setState(() { _isDownloading = false; _isDownloaded = path != null; });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MusicPlayerProvider, ({String? id, bool playing})>(
      selector: (_, p) => (id: p.currentSong?.id, playing: p.isPlaying),
      builder: (context, state, _) {
        final isCurrent = state.id == widget.song.id;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  widget.song.imageUrl,
                  width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50, height: 50, color: Colors.grey[800],
                    child: const Icon(Icons.music_note),
                  ),
                ),
                if (widget.isLoading)
                  Container(width: 50, height: 50, color: Colors.black54,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                if (isCurrent && !widget.isLoading)
                  Container(
                    width: 50, height: 50, color: Colors.black54,
                    child: Center(child: _EqualizerIcon(controller: _eqController, playing: state.playing)),
                  ),
              ],
            ),
          ),
          title: Text(widget.song.title, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isCurrent ? Colors.green : Colors.white)),
          subtitle: Text(widget.song.artist, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isDownloading)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else if (widget.showDownload)
                IconButton(
                  icon: Icon(_isDownloaded ? Icons.download_done : Icons.download,
                      size: 20, color: _isDownloaded ? Colors.green : Colors.grey),
                  onPressed: _isDownloaded ? null : _download,
                ),
              if (widget.onRemove != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (value) { if (value == 'remove') widget.onRemove!(); },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove from liked'))],
                ),
            ],
          ),
          onTap: widget.onTap ?? () {
            final provider = context.read<MusicPlayerProvider>();
            if (provider.currentSong?.id == widget.song.id) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen()));
            } else {
              provider.playSong(widget.song, queue: widget.queue);
            }
          },
        );
      },
    );
  }
}

class _EqualizerIcon extends StatelessWidget {
  final AnimationController controller;
  final bool playing;
  const _EqualizerIcon({required this.controller, required this.playing});

  @override
  Widget build(BuildContext context) {
    if (!playing) return const Icon(Icons.pause, color: Colors.white, size: 18);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(0.4 + 0.6 * controller.value),
          const SizedBox(width: 2),
          _bar(1.0 - 0.5 * controller.value),
          const SizedBox(width: 2),
          _bar(0.6 + 0.4 * (1 - controller.value)),
        ],
      ),
    );
  }

  Widget _bar(double heightFactor) => Container(
    width: 3,
    height: 16 * heightFactor,
    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(1)),
  );
}

