import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isDownloading;

  const SongListTile({
    super.key, 
    required this.song, 
    this.isLoading = false, 
    this.onRemove, 
    this.queue, 
    this.onTap, 
    this.showDownload = true,
    this.isDownloading = false,
  });

  @override
  State<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends State<SongListTile> with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService();
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isPressed = false;
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
    if (mounted) {
      setState(() => _isDownloaded = path != null);
    }
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    final path = await _downloadService.downloadSong(widget.song);
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = path != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
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
              HapticFeedback.mediumImpact();
              player.addSuggestedToQueue(widget.song);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${widget.song.title}" added to queue'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            } else if (direction == DismissDirection.endToStart) {
              HapticFeedback.mediumImpact();
              player.toggleLike(widget.song);
            }
            return false;
          },
          background: Container(
            color: Colors.blue.withValues(alpha: 0.15),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            child: const Icon(Icons.playlist_add_rounded, color: Colors.blue, size: 28),
          ),
          secondaryBackground: Container(
            color: Colors.pink.withValues(alpha: 0.15),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 28),
          ),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: InkWell(
                onTap: widget.onTap ?? () {
                  if (player.currentSong?.id == widget.song.id) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
                  } else {
                    player.playSong(widget.song, queue: widget.queue);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.network(
                              widget.song.imageUrl,
                              width: 52, height: 52, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _defaultCover(),
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
                                fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.song.artist, 
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? primaryColor.withValues(alpha: 0.7) : Colors.white38,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDownloading || widget.isDownloading)
                            const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else if (widget.showDownload)
                            if (_isDownloaded)
                              Icon(Icons.download_done_rounded, size: 22, color: primaryColor)
                            else if (context.watch<AuthProvider>().canDownload)
                              IconButton(
                                icon: const Icon(Icons.download_rounded, size: 22, color: Colors.white24),
                                onPressed: _download,
                              ),
                          if (widget.onRemove != null)
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, size: 22, color: Colors.white24),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showOptions(context, l10n);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove from Library', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onRemove?.call();
                },
              ),
            ],
          ),
        ),
      ),
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
