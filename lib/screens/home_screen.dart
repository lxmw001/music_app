import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/music_player_provider.dart';
import '../providers/auth_provider.dart';
import '../models/music_models.dart';
import '../services/youtube_service.dart';
import '../services/play_history_service.dart';
import '../widgets/song_card_list.dart';
import '../widgets/recent_songs_grid.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final YouTubeService? youtubeService;
  const HomeScreen({super.key, this.youtubeService});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final YouTubeService _youtubeService;
  final _history = PlayHistoryService();
  List<Song> trendingSongs = [];
  List<Song> suggestedSongs = [];
  List<Playlist> recentPlaylists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _youtubeService = widget.youtubeService ?? YouTubeService();
    _loadWithCache();
  }

  Future<void> _loadWithCache() async {
    final cached = await _history.loadCachedTrending();
    final cachedSuggested = await _history.loadCachedSuggested();
    final playlists = await context.read<MusicPlayerProvider>().loadPlaylists();
    if (mounted) {
      setState(() {
        if (cached.isNotEmpty) trendingSongs = cached;
        if (cachedSuggested.isNotEmpty) suggestedSongs = cachedSuggested;
        recentPlaylists = playlists;
        isLoading = cached.isEmpty;
      });
    }

    final fresh = await _youtubeService.getTrendingMusic();
    if (fresh.isNotEmpty) {
      await _history.cacheTrending(fresh);
      if (mounted) setState(() { trendingSongs = fresh; isLoading = false; });
    } else if (mounted) {
      setState(() => isLoading = false);
    }

    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final provider = context.read<MusicPlayerProvider>();
    final likedSongs = await provider.getMostLikedFromHistory();
    final seedSongs = likedSongs.isNotEmpty
        ? likedSongs.take(3).toList()
        : trendingSongs.take(2).toList();
    if (seedSongs.isEmpty) return;
    final suggestions = await _youtubeService.getSuggestionsFromHistory(seedSongs);
    if (suggestions.isNotEmpty) {
      await _history.cacheSuggested(suggestions);
      if (mounted) setState(() => suggestedSongs = suggestions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadWithCache,
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  AppLocalizations.of(context)!.homeGreeting,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                background: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              actions: [
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => IconButton(
                    icon: auth.isSignedIn && auth.user?.photoURL != null
                        ? CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(auth.user!.photoURL!),
                          )
                        : const Icon(Icons.account_circle_outlined),
                    onPressed: () => auth.isSignedIn 
                        ? _showProfileMenu(context, auth) 
                        : Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildSectionHeader(AppLocalizations.of(context)!.homeRecentlyPlayed),
                  const SizedBox(height: 16),
                  if (recentPlaylists.isEmpty)
                    _buildEmptyState(
                      Icons.queue_music_rounded,
                      AppLocalizations.of(context)!.homeNoPlaylists,
                    )
                  else
                    RecentPlaylistsGrid(playlists: recentPlaylists),
                  
                  const SizedBox(height: 32),
                  _buildSectionHeader(AppLocalizations.of(context)!.homeTrending),
                  const SizedBox(height: 16),
                  isLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ))
                      : SongCardList(songs: trendingSongs),
                  
                  if (suggestedSongs.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader(AppLocalizations.of(context)!.homeSuggested),
                    const SizedBox(height: 16),
                    SongCardList(songs: suggestedSongs),
                  ],
                  const SizedBox(height: 100), // Space for mini player
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),
              CircleAvatar(
                radius: 40,
                backgroundImage: auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null,
                child: auth.user?.photoURL == null ? const Icon(Icons.person, size: 40) : null,
              ),
              const SizedBox(height: 16),
              Text(auth.user?.displayName ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (auth.user?.email != null) ...[
                const SizedBox(height: 4),
                Text(auth.user!.email!, style: TextStyle(color: Colors.grey[400])),
              ],
              const SizedBox(height: 32),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.logout_rounded, color: Colors.red),
                ),
                title: const Text('Sign out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); auth.signOut(); },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}
