import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/music_models.dart';
import '../providers/music_player_provider.dart';
import 'song_list_tile.dart';
import 'animated_list_item.dart';

class RecentPlaylistsGrid extends StatelessWidget {
  final List<Playlist> playlists;
  const RecentPlaylistsGrid({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) {
    final items = playlists.take(10).toList();
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _RecentPlaylistCard(playlist: items[index], index: index);
        },
      ),
    );
  }
}

class _RecentPlaylistCard extends StatefulWidget {
  final Playlist playlist;
  final int index;
  const _RecentPlaylistCard({required this.playlist, required this.index});

  @override
  State<_RecentPlaylistCard> createState() => _RecentPlaylistCardState();
}

class _RecentPlaylistCardState extends State<_RecentPlaylistCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedListItem(
      index: widget.index,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          _openPlaylist(context, widget.playlist);
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 150,
            margin: const EdgeInsets.only(right: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          widget.playlist.imageUrl.isNotEmpty
                              ? Image.network(
                                  widget.playlist.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) => _icon(),
                                )
                              : _icon(),
                          // Glossy overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.playlist.name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.2),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.playlist.songs.length} tracks',
                  style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon() => Container(
    color: Colors.white.withValues(alpha: 0.05),
    child: const Icon(Icons.queue_music_rounded, size: 48, color: Colors.white12),
  );

  void _openPlaylist(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: playlist.imageUrl.isNotEmpty
                        ? Image.network(playlist.imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                        : Container(width: 80, height: 80, color: Colors.white10, child: const Icon(Icons.music_note, color: Colors.white24)),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(playlist.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                          Text('${playlist.songs.length} tracks', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<MusicPlayerProvider>().playSong(playlist.songs.first, queue: playlist.songs, fromQueue: true);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                      style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, padding: const EdgeInsets.all(12)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: playlist.songs.length,
                  itemBuilder: (context, i) {
                    final song = playlist.songs[i];
                    return SongListTile(
                      song: song,
                      queue: playlist.songs,
                      onTap: () {
                        Navigator.pop(context);
                        context.read<MusicPlayerProvider>().playSong(song, queue: playlist.songs, fromQueue: true);
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
}
