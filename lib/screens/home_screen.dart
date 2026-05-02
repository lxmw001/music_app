import 'package:flutter/material.dart';
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
  // ignore: library_private_types_in_public_api
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
    // 1. Show cached data immediately
    final cached = await _history.loadCachedTrending();
    final cachedSuggested = await _history.loadCachedSuggested();
    final playlists = await context.read<MusicPlayerProvider>().loadPlaylists();
    if (mounted) {
      setState(() {
        if (cached.isNotEmpty) trendingSongs = cached;
        if (cachedSuggested.isNotEmpty) suggestedSongs = cachedSuggested;
        recentPlaylists = playlists;
        isLoading = cached.isEmpty; // only show spinner if no cache
      });
    }

    // 2. Fetch fresh data in background
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.homeGreeting),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) => auth.isSignedIn
                ? GestureDetector(
                    onTap: () => _showProfileMenu(context, auth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: auth.user?.photoURL != null
                            ? NetworkImage(auth.user!.photoURL!)
                            : null,
                        child: auth.user?.photoURL == null
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    tooltip: 'Sign in',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.homeRecentlyPlayed, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (recentPlaylists.isEmpty)
              Column(
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.queue_music, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.homeNoPlaylists, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
              )
            else
              RecentPlaylistsGrid(playlists: recentPlaylists),
            const SizedBox(height: 32),
            Text(AppLocalizations.of(context)!.homeTrending, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : SongCardList(songs: trendingSongs),
            if (suggestedSongs.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(AppLocalizations.of(context)!.homeSuggested, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SongCardList(songs: suggestedSongs),
            ],
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null,
              child: auth.user?.photoURL == null ? const Icon(Icons.person, size: 32) : null,
            ),
            const SizedBox(height: 12),
            Text(auth.user?.displayName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(auth.user?.email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign out', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); auth.signOut(); },
            ),
          ],
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
