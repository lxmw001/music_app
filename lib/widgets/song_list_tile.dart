import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/player_screen.dart';
import '../services/download_service.dart';

class SongListTile extends StatefulWidget {
  final Song song;
  final bool isLoading;
  final VoidCallback? onRemove;
  final List<Song>? queue;
  final VoidCallback? onTap;
  final bool showDownload;

  const SongListTile({
    super.key, 
    required this.song, 
    this.isLoading = false, 
    this.onRemove, 
    this.queue, 
    this.onTap, 
    this.showDownload = true,
  });

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
    _eqController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
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
    if (mounted) setState(() { 
      _isDownloading = false; 
      _isDownloaded = path != null; 
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context)!;
    final player = context.read<MusicPlayerProvider>();
    
    return Selector<MusicPlayerProvider, ({String? id, bool playing})>(
      selector: (_, p) => (id: p.currentSong?.id, playing: p.isPlaying),
      builder: (context, state, _) {
        final isCurrent = state.id == widget.song.id;
        
        return Dismissible(
          key: Key('swipe_${widget.song.id}'),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Swipe Right -> Add to Queue / Play Next
              player.addSuggestedToQueue(widget.song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${widget.song.title}" added to queue'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            } else if (direction == DismissDirection.endToStart) {
              // Swipe Left -> Toggle Like
              player.toggleLike(widget.song);
            }
            return false; // Don't actually remove from list
          },
          background: Container(
            color: Colors.blue.withValues(alpha: 0.2),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.playlist_add_rounded, color: Colors.blue),
          ),
          secondaryBackground: Container(
            color: primaryColor.withValues(alpha: 0.2),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.favorite_rounded, color: Colors.pink),
          ),
          child: InkWell(
            onTap: widget.onTap ?? () {
              if (player.currentSong?.id == widget.song.id) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
              } else {
                player.playSong(widget.song, queue: widget.queue);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          widget.song.imageUrl,
                          width: 52, height: 52, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultCover(),
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _defaultCover();
                          },
                        ),
                        if (widget.isLoading)
                          Container(
                            width: 52, height: 52, color: Colors.black54,
                            child: const Center(
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                        if (isCurrent && !widget.isLoading)
                          Container(
                            width: 52, height: 52, color: Colors.black54,
                            child: Center(
                              child: _EqualizerIcon(
                                controller: _eqController, 
                                playing: state.playing,
                                color: primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? primaryColor : Colors.white,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.song.artist, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isDownloading)
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else if (widget.showDownload && context.watch<AuthProvider>().canDownload)
                        IconButton(
                          icon: Icon(
                            _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                            size: 22, 
                            color: _isDownloaded ? primaryColor : Colors.grey[600],
                          ),
                          onPressed: _isDownloaded ? null : _download,
                        ),
                      if (widget.onRemove != null)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, size: 22, color: Colors.grey[600]),
                          onSelected: (value) { if (value == 'remove') widget.onRemove!(); },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'remove', 
                              child: Row(
                                children: [
                                  const Icon(Icons.favorite_border_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(l10n.playerQueue), // Placeholder for "Remove from liked"
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _defaultCover() => Container(
    width: 52, height: 52, color: Colors.grey[900],
    child: const Icon(Icons.music_note_rounded, color: Colors.white24),
  );
}

class _EqualizerIcon extends StatelessWidget {
  final AnimationController controller;
  final bool playing;
  final Color color;
  const _EqualizerIcon({required this.controller, required this.playing, required this.color});

  @override
  Widget build(BuildContext context) {
    if (!playing) return const Icon(Icons.pause_rounded, color: Colors.white, size: 20);
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
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
  );
}
