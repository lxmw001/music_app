import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/music_player_provider.dart';
import '../services/download_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  final _downloadService = DownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedPath;

  // Dominant color
  Color _dominantColor = Colors.grey.shade900;
  String? _lastColorUrl;

  // Rotation animation
  late final AnimationController _rotationController;

  // Cover style: 0=rotating disc, 1=vinyl disc, 2=static square
  int _coverStyle = 0;

  // Lyrics
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
      if (mounted) setState(() => _dominantColor = color.withValues(alpha: 0.85));
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
      } else {
        if (mounted) setState(() => _lyrics = null);
      }
    } catch (_) {
      if (mounted) setState(() => _lyrics = null);
    } finally {
      if (mounted) setState(() => _lyricsLoading = false);
    }
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
    return Consumer<MusicPlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const Scaffold(body: Center(child: Text('No song playing')));

        // Update dominant color when song changes
        if (song.imageUrl.isNotEmpty) _updateDominantColor(song.imageUrl);

        // Sync rotation animation with play state
        if (player.isPlaying) {
          if (!_rotationController.isAnimating) _rotationController.repeat();
        } else {
          if (_rotationController.isAnimating) _rotationController.stop();
        }

        final isLoading = player.isLoadingAudio(song.id);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Blurred album art background
              Positioned.fill(
                child: Image.network(
                  song.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _dominantColor.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    // App bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(child: Text('Now Playing', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                          if (_isDownloading)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null, strokeWidth: 2, color: Colors.white)),
                            )
                          else
                            IconButton(
                              icon: Icon(_downloadedPath != null ? Icons.download_done : Icons.download,
                                  color: _downloadedPath != null ? Colors.green : null),
                              onPressed: _downloadedPath != null ? null : () => _download(context),
                            ),
                          IconButton(
                            icon: const Icon(Icons.queue_music),
                            onPressed: () => _showQueueSheet(context),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: _showLyrics ? _buildLyricsView(song) : _buildPlayerView(context, player, song, isLoading),
                    ),

                    // Lyrics toggle
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showLyrics = !_showLyrics);
                        if (!_showLyrics == false) {
                          _fetchLyrics(song.title, song.artist);
                        }
                        if (_showLyrics) _fetchLyrics(song.title, song.artist);
                      },
                      icon: Icon(_showLyrics ? Icons.music_note : Icons.lyrics_outlined, size: 16),
                      label: Text(AppLocalizations.of(context)!.playerLyrics),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCover(song, bool isLoading) {
    final image = Image.network(
      song.imageUrl, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey[800], child: const Icon(Icons.music_note, size: 80)),
    );
    final shadow = BoxShadow(color: _dominantColor.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 5);

    switch (_coverStyle) {
      // Style 0: rotating circle
      case 0:
        return AnimatedBuilder(
          animation: _rotationController,
          builder: (_, child) => Transform.rotate(
            angle: _rotationController.value * 2 * 3.14159,
            child: child,
          ),
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [shadow]),
            child: ClipOval(child: Stack(alignment: Alignment.center, children: [
              image,
              if (isLoading) Container(color: Colors.black54, child: const CircularProgressIndicator(color: Colors.white)),
            ])),
          ),
        );

      // Style 1: vinyl disc
      case 1:
        return AnimatedBuilder(
          animation: _rotationController,
          builder: (_, child) => Transform.rotate(
            angle: _rotationController.value * 2 * 3.14159,
            child: child,
          ),
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [shadow]),
            child: CustomPaint(
              painter: _VinylPainter(song.imageUrl),
              child: ClipOval(
                child: Center(
                  child: ClipOval(
                    child: SizedBox(
                      width: 100, height: 100,
                      child: Stack(alignment: Alignment.center, children: [
                        image,
                        if (isLoading) Container(color: Colors.black54, child: const CircularProgressIndicator(color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      // Style 2: static square
      default:
        return Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [shadow],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(alignment: Alignment.center, children: [
              image,
              if (isLoading) Container(color: Colors.black54, child: const CircularProgressIndicator(color: Colors.white)),
            ]),
          ),
        );
    }
  }

  Widget _buildPlayerView(BuildContext context, MusicPlayerProvider player, song, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Album art — tap to cycle styles
          Expanded(
            flex: 3,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -300) player.nextSong();
                if (details.primaryVelocity! > 300) player.previousSong();
              },
              onTap: () => setState(() => _coverStyle = (_coverStyle + 1) % 3),
              child: Center(child: _buildCover(song, isLoading)),
            ),
          ),
          const SizedBox(height: 24),
          // Title + like
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    Text(song.artist, style: const TextStyle(fontSize: 15, color: Colors.white70), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              FutureBuilder<bool>(
                future: player.isLiked(song.id),
                builder: (context, snap) {
                  final liked = snap.data ?? false;
                  return IconButton(
                    icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.green : null),
                    onPressed: () => player.toggleLike(song),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Seek bar — uses StreamBuilder so it updates every second without full rebuild
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snap) {
              final position = snap.data ?? player.currentPosition;
              final total = player.totalDuration.inSeconds.clamp(1, double.infinity).toDouble();
              return Column(
                children: [
                  Slider(
                    value: position.inSeconds.toDouble().clamp(0.0, total),
                    max: total,
                    onChanged: (v) => player.seekTo(Duration(seconds: v.toInt())),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_fmt(player.totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: Icon(Icons.shuffle, color: player.isShuffled ? Colors.green : Colors.white70), onPressed: player.toggleShuffle),
              IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: player.previousSong),
              Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.black),
                  onPressed: () => player.isPlaying ? player.pause() : player.resume(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_next, size: 36, color: isLoading ? Colors.white30 : Colors.white),
                onPressed: isLoading ? null : player.nextSong,
              ),
              IconButton(icon: Icon(Icons.repeat, color: player.isRepeating ? Colors.green : Colors.white70), onPressed: player.toggleRepeat),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLyricsView(song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(song.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(song.artist, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Expanded(
            child: _lyricsLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _lyrics != null
                    ? SingleChildScrollView(
                        child: Text(_lyrics!, style: const TextStyle(fontSize: 15, height: 1.8, color: Colors.white)),
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
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<MusicPlayerProvider>(),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
          builder: (_, controller) => Consumer<MusicPlayerProvider>(
            builder: (context, player, __) => Column(
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    Text(AppLocalizations.of(context)!.playerQueue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    Text('${player.queue.length} songs', style: const TextStyle(color: Colors.grey)),
                  ]),
                ),
                const Divider(color: Colors.grey),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: player.queue.length,
                    itemBuilder: (context, i) {
                      final s = player.queue[i];
                      final isCurrent = i == player.currentIndex;
                      return ListTile(
                        leading: ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: Image.network(s.imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey[800], child: const Icon(Icons.music_note, size: 20)))),
                        title: Text(s.title, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isCurrent ? Colors.green : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(s.artist, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: i < player.currentIndex ? Colors.grey[700] : Colors.grey)),
                        trailing: isCurrent ? const Icon(Icons.equalizer, color: Colors.green) : null,
                        onTap: () { player.playSong(s, fromQueue: true); Navigator.pop(context); },
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

    // Outer vinyl black disc
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1a1a1a));

    // Vinyl grooves
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double r = radius * 0.42; r < radius * 0.95; r += 6) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Label ring
    canvas.drawCircle(center, radius * 0.38, Paint()..color = const Color(0xFF2a2a2a));

    // Center hole
    canvas.drawCircle(center, radius * 0.04, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.imageUrl != imageUrl;
}
