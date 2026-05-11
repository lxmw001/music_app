import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../providers/music_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/download_service.dart';
import '../widgets/waveform_progress_bar.dart';
import '../widgets/floating_particles.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  final _downloadService = DownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedPath;

  Color _dominantColor = Colors.grey.shade900;
  String? _lastColorUrl;

  late final AnimationController _rotationController;
  late final AnimationController _bgAnimationController;
  
  // 3D Tilt variables
  Offset _tiltOffset = Offset.zero;
  int _coverStyle = 0;

  String? _lyrics;
  bool _lyricsLoading = false;
  bool _showLyrics = false;
  String? _lastLyricsKey;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat(reverse: true);
    _checkDownloaded();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkDownloaded() async {
    final song = context.read<MusicPlayerProvider>().currentSong;
    if (song == null) return;
    final path = await _downloadService.getDownloadedPath(song);
    if (mounted) setState(() => _downloadedPath = path);
  }

  Future<void> _updateDominantColor(String imageUrl) async {
    if (imageUrl == _lastColorUrl) return;
    _lastColorUrl = imageUrl;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100),
      );
      final color = generator.dominantColor?.color ?? Colors.grey.shade900;
      if (mounted) {
        setState(() => _dominantColor = color);
        context.read<ThemeProvider>().updateAdaptiveColor(color);
      }
    } catch (_) {}
  }

  Future<void> _fetchLyrics(String title, String artist) async {
    final key = '$title|$artist';
    if (key == _lastLyricsKey) return;
    _lastLyricsKey = key;
    setState(() { _lyricsLoading = true; _lyrics = null; });
    try {
      final uri = Uri.parse('https://api.lyrics.ovh/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _lyrics = data['lyrics'] as String?);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _lyricsLoading = false);
    }
  }

  Future<void> _download(BuildContext context) async {
    final song = context.read<MusicPlayerProvider>().currentSong;
    if (song == null) return;
    HapticFeedback.lightImpact();
    setState(() { _isDownloading = true; _downloadProgress = 0; });
    final path = await _downloadService.downloadSong(song, onProgress: (received, total) {
      if (total > 0 && mounted) setState(() => _downloadProgress = received / total);
    });
    if (mounted) setState(() { _isDownloading = false; _downloadedPath = path; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null ? 'Downloaded to library' : 'Download failed'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const Scaffold(body: Center(child: Text('No song playing')));

        if (song.imageUrl.isNotEmpty) _updateDominantColor(song.imageUrl);

        if (player.isPlaying) {
          if (!_rotationController.isAnimating) _rotationController.repeat();
        } else {
          if (_rotationController.isAnimating) _rotationController.stop();
        }

        final isLoading = player.isLoadingAudio(song.id);

        return Scaffold(
          body: Stack(
            children: [
              // 1. Cinematic Background
              AnimatedBuilder(
                animation: _bgAnimationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.2 + (_bgAnimationController.value * 0.15),
                    child: Transform.rotate(
                      angle: _bgAnimationController.value * 0.05,
                      child: child,
                    ),
                  );
                },
                child: Image.network(
                  song.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
              FloatingParticles(color: _dominantColor),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _dominantColor.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.8),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 2. Main Content
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context, song),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _showLyrics 
                          ? _buildLyricsView(song) 
                          : _buildPlayerView(context, player, song, isLoading),
                      ),
                    ),
                    _buildBottomControls(context, player, song),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 40, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                'PLAYING FROM QUEUE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Now Playing',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            onPressed: () {
              HapticFeedback.mediumImpact();
            }, 
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView(BuildContext context, MusicPlayerProvider player, song, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(),
          // 3D TILT ALBUM ART
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _tiltOffset += details.delta / 1000;
                _tiltOffset = Offset(_tiltOffset.dx.clamp(-0.2, 0.2), _tiltOffset.dy.clamp(-0.2, 0.2));
              });
            },
            onPanEnd: (_) => setState(() => _tiltOffset = Offset.zero),
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _coverStyle = (_coverStyle + 1) % 3);
            },
            child: AnimatedScale(
              scale: player.isPlaying ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateX(-_tiltOffset.dy)
                  ..rotateY(_tiltOffset.dx),
                alignment: FractionalOffset.center,
                child: Stack(
                  children: [
                    _buildCover(song, isLoading),
                    // Light gloss overlay that follows tilt
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            shape: _coverStyle == 2 ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: _coverStyle == 2 ? BorderRadius.circular(24) : null,
                            gradient: LinearGradient(
                              begin: Alignment(_tiltOffset.dx * 5, _tiltOffset.dy * 5),
                              end: Alignment(-_tiltOffset.dx * 5, -_tiltOffset.dy * 5),
                              colors: [
                                Colors.white.withValues(alpha: 0.1),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist,
                      style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FutureBuilder<bool>(
                future: player.isLiked(song.id),
                builder: (context, snap) {
                  final liked = snap.data ?? false;
                  return IconButton(
                    icon: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: liked ? Theme.of(context).primaryColor : Colors.white70,
                      size: 34,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      player.toggleLike(song);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildWaveformProgressBar(player, song),
          const SizedBox(height: 16),
          _buildMainControls(player, isLoading),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWaveformProgressBar(MusicPlayerProvider player, song) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final position = snap.data ?? player.currentPosition;
        final total = player.totalDuration;
        final progress = total.inSeconds > 0 
            ? (position.inSeconds / total.inSeconds).clamp(0.0, 1.0) 
            : 0.0;

        return Column(
          children: [
            WaveformProgressBar(
              progress: progress,
              isPlaying: player.isPlaying,
              color: Colors.white,
              songId: song.id,
              onSeek: (p) {
                HapticFeedback.selectionClick();
                player.seekTo(Duration(seconds: (p * total.inSeconds).toInt()));
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(position), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  Text(_fmt(total), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainControls(MusicPlayerProvider player, bool isLoading) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded, color: player.isShuffled ? theme.primaryColor : Colors.white70),
          onPressed: () {
            HapticFeedback.lightImpact();
            player.toggleShuffle();
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 52),
          onPressed: () {
            HapticFeedback.mediumImpact();
            player.previousSong();
          },
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            player.isPlaying ? player.pause() : player.resume();
          },
          child: Container(
            height: 84, width: 84,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 56, color: Colors.black,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, size: 52, color: isLoading ? Colors.white24 : Colors.white),
          onPressed: isLoading ? null : () {
            HapticFeedback.mediumImpact();
            player.nextSong();
          },
        ),
        IconButton(
          icon: Icon(Icons.repeat_rounded, color: player.isRepeating ? theme.primaryColor : Colors.white70),
          onPressed: () {
            HapticFeedback.lightImpact();
            player.toggleRepeat();
          },
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, MusicPlayerProvider player, song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(_showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined, color: _showLyrics ? Theme.of(context).primaryColor : Colors.white70, size: 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _showLyrics = !_showLyrics);
              if (_showLyrics) _fetchLyrics(song.title, song.artist);
            },
          ),
          const Spacer(),
          if (_isDownloading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
          else if (context.watch<AuthProvider>().canDownload)
            IconButton(
              icon: Icon(_downloadedPath != null ? Icons.download_done_rounded : Icons.download_rounded,
                  color: _downloadedPath != null ? Theme.of(context).primaryColor : Colors.white70, size: 28),
              onPressed: _downloadedPath != null ? null : () => _download(context),
            ),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded, size: 34, color: Colors.white70),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showQueueSheet(context, player);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCover(song, bool isLoading) {
    final shadow = BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 5);

    Widget image = Hero(
      tag: 'player_art',
      child: Image.network(
        song.imageUrl, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[900], child: const Icon(Icons.music_note, size: 80)),
      ),
    );

    if (_coverStyle == 0 || _coverStyle == 1) {
      return AnimatedBuilder(
        animation: _rotationController,
        builder: (_, child) => Transform.rotate(
          angle: _rotationController.value * 2 * 3.14159,
          child: child,
        ),
        child: Container(
          width: 320, height: 320,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [shadow]),
          child: ClipOval(child: Stack(alignment: Alignment.center, children: [
            if (_coverStyle == 1) CustomPaint(painter: _VinylPainter(song.imageUrl), child: Container()),
            SizedBox(
              width: _coverStyle == 1 ? 110 : 320,
              height: _coverStyle == 1 ? 110 : 320,
              child: ClipOval(child: image),
            ),
            if (isLoading) Container(color: Colors.black54, child: const CircularProgressIndicator(color: Colors.white)),
          ])),
        ),
      );
    }

    return Container(
      width: 320, height: 320,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [shadow]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(alignment: Alignment.center, children: [
          image,
          if (isLoading) Container(color: Colors.black54, child: const CircularProgressIndicator(color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _buildLyricsView(song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _lyricsLoading
                ? const Center(child: CircularProgressIndicator())
                : _lyrics != null
                    ? SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          _lyrics!,
                          style: const TextStyle(fontSize: 28, height: 1.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      )
                    : Center(child: Text(AppLocalizations.of(context)!.playerNoLyrics, style: const TextStyle(color: Colors.white54, fontSize: 18))),
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(BuildContext context, MusicPlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(AppLocalizations.of(context)!.playerQueue, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: player.queue.length,
                  itemBuilder: (context, i) {
                    final s = player.queue[i];
                    final isCurrent = i == player.currentIndex;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.network(s.imageUrl, width: 50, height: 50, fit: BoxFit.cover)),
                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isCurrent ? Theme.of(context).primaryColor : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                      subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis, 
                          style: TextStyle(color: isCurrent ? Theme.of(context).primaryColor.withValues(alpha: 0.7) : Colors.white38, fontSize: 13)),
                      trailing: isCurrent ? Icon(Icons.equalizer_rounded, color: Theme.of(context).primaryColor) : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        player.playSong(s, fromQueue: true); 
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
    );
  }

  String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }
}

class _VinylPainter extends CustomPainter {
  final String imageUrl;
  _VinylPainter(this.imageUrl);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF101010));
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double r = radius * 0.4; r < radius * 0.95; r += 6) {
      canvas.drawCircle(center, r, groovePaint);
    }
    canvas.drawCircle(center, radius * 0.35, Paint()..color = const Color(0xFF151515));
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.imageUrl != imageUrl;
}
