import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../services/download_service.dart';

class SongListTile extends StatefulWidget {
  final Song song;
  final bool isLoading;
  final VoidCallback? onRemove;
  final List<Song>? queue;
  final VoidCallback? onTap;

  const SongListTile({super.key, required this.song, this.isLoading = false, this.onRemove, this.queue, this.onTap});

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile> {
  final _downloadService = DownloadService();
  bool _isDownloading = false;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
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
              Container(
                width: 50, height: 50, color: Colors.black54,
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
          ],
        ),
      ),
      title: Text(widget.song.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(widget.song.artist, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download button
          if (_isDownloading)
            const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            IconButton(
              icon: Icon(
                _isDownloaded ? Icons.download_done : Icons.download,
                size: 20,
                color: _isDownloaded ? Colors.green : Colors.grey,
              ),
              onPressed: _isDownloaded ? null : _download,
            ),
          // ⋮ menu — only shown when onRemove is provided
          if (widget.onRemove != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (value) {
                if (value == 'remove') widget.onRemove!();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('Remove from liked')),
              ],
            ),
        ],
      ),
      onTap: widget.onTap ?? () => context.read<MusicPlayerProvider>().playSong(widget.song),
    );
  }
}
