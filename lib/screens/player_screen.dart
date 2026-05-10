import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../providers/music_player_provider.dart';
import '../providers/auth_provider.dart';
import '../services/download_service.dart';
import '../widgets/waveform_progress_bar.dart';

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
    _checkDownloaded();
  }

  @override
  void dispose() {
    _rotationController.dispose();
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
      if (mounted) setState(() => _dominantColor = color);
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
              // Dynamic Background
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _dominantColor.withValues(alpha: 0.8),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context, song),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showLyrics 
                          ? _buildLyricsView(song) 
                          : _buildPlayerView(context, player, song, isLoading),
                      ),
                    ),
                    _buildBottomControls(context, song),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                'PLAYING FROM QUEUE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Now Playing',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {}, // Options menu
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView(BuildContext context, MusicPlayerProvider player, song, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _coverStyle = (_coverStyle + 1) % 3),
            child: _buildCover(song, isLoading),
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
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist,
                      style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.7)),
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
                      color: liked ? Theme.of(context).primaryColor : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => player.toggleLike(song),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWaveformProgressBar(player),
          _buildMainControls(player, isLoading),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWaveformProgressBar(MusicPlayerProvider player) {
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
              onSeek: (p) => player.seekTo(Duration(seconds: (p * total.inSeconds).toInt())),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(position), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  Text(_fmt(total), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainControls(MusicPlayerProvider player, bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded, color: player.isShuffled ? Theme.of(context).primaryColor : Colors.white),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 42),
          onPressed: player.previousSong,
        ),
        GestureDetector(
          onTap: () => player.isPlaying ? player.pause() : player.resume(),
          child: Container(
            height: 72, width: 72,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 48, color: Colors.black,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, size: 42, color: isLoading ? Colors.white24 : Colors.white),
          onPressed: isLoading ? null : player.nextSong,
        ),
        IconButton(
          icon: Icon(Icons.repeat_rounded, color: player.isRepeating ? Theme.of(context).primaryColor : Colors.white),
          onPressed: player.toggleRepeat,
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(_showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined, color: _showLyrics ? Theme.of(context).primaryColor : Colors.white70),
            onPressed: () {
              setState(() => _showLyrics = !_showLyrics);
              if (_showLyrics) _fetchLyrics(song.title, song.artist);
            },
          ),
          const Spacer(),
          if (_isDownloading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (context.watch<AuthProvider>().canDownload)
            IconButton(
              icon: Icon(_downloadedPath != null ? Icons.download_done_rounded : Icons.download_rounded,
                  color: _downloadedPath != null ? Theme.of(context).primaryColor : Colors.white70),
              onPressed: _downloadedPath != null ? null : () => _download(context),
            ),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded, size: 28, color: Colors.white70),
            onPressed: () => _showQueueSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(song, bool isLoading) {
    final shadow = BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 5);

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
          width: 300, height: 300,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [shadow]),
          child: ClipOval(child: Stack(alignment: Alignment.center, children: [
            if (_coverStyle == 1) CustomPaint(painter: _VinylPainter(song.imageUrl), child: Container()),
            SizedBox(
              width: _coverStyle == 1 ? 100 : 300,
              height: _coverStyle == 1 ? 100 : 300,
              child: ClipOval(child: image),
            ),
            if (isLoading) Container(color: Colors.black54, child: const CircularProgressIndicator(color: Colors.white)),
          ])),
        ),
      );
    }

    return Container(
      width: 300, height: 300,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [shadow]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                        child: Text(
                          _lyrics!,
                          style: const TextStyle(fontSize: 24, height: 1.6, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    : Center(child: Text(AppLocalizations.of(context)!.playerNoLyrics, style: const TextStyle(color: Colors.white54))),
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context)!.playerQueue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: Consumer<MusicPlayerProvider>(
                builder: (context, player, _) => ListView.builder(
                  itemCount: player.queue.length,
                  itemBuilder: (context, i) {
                    final s = player.queue[i];
                    final isCurrent = i == player.currentIndex;
                    return ListTile(
                      leading: ClipRRect(borderRadius: BorderRadius.circular(4),
                        child: Image.network(s.imageUrl, width: 48, height: 48, fit: BoxFit.cover)),
                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isCurrent ? Theme.of(context).primaryColor : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: isCurrent ? Icon(Icons.equalizer_rounded, color: Theme.of(context).primaryColor) : null,
                      onTap: () { player.playSong(s, fromQueue: true); Navigator.pop(context); },
                    );
                  },
                ),
              ),
            ),
          ],
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
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF121212));
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double r = radius * 0.4; r < radius * 0.95; r += 6) {
      canvas.drawCircle(center, r, groovePaint);
    }
    canvas.drawCircle(center, radius * 0.35, Paint()..color = const Color(0xFF1a1a1a));
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.imageUrl != imageUrl;
}
