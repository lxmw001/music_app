import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/music_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/music_models.dart';
import '../services/youtube_service.dart';
import '../services/play_history_service.dart';
import '../widgets/song_card_list.dart';
import '../widgets/recent_songs_grid.dart';
import '../widgets/shimmer.dart';
import '../widgets/animated_list_item.dart';
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
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: RefreshIndicator(
        onRefresh: _loadWithCache,
        color: primaryColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreetingPrefix().toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.homeGreeting,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30, letterSpacing: -1.2),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => IconButton(
                    icon: auth.isSignedIn && auth.user?.photoURL != null
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(auth.user!.photoURL!),
                            ),
                          )
                        : const Icon(Icons.account_circle_outlined, size: 30, color: Colors.white70),
                    onPressed: () => _showProfileAndThemeMenu(context, auth),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  
                  // 1. MOOD / VIBE PICKER
                  _buildSectionHeader('Your Vibe'),
                  const SizedBox(height: 16),
                  _buildVibeSelector(),
                  
                  const SizedBox(height: 40),
                  
                  // 2. RECENTLY PLAYED
                  _buildSectionHeader(AppLocalizations.of(context)!.homeRecentlyPlayed),
                  const SizedBox(height: 16),
                  if (recentPlaylists.isEmpty && !isLoading)
                    _buildEmptyState(Icons.queue_music_rounded, AppLocalizations.of(context)!.homeNoPlaylists)
                  else if (isLoading && recentPlaylists.isEmpty)
                    _buildShimmerHorizontalList()
                  else
                    RecentPlaylistsGrid(playlists: recentPlaylists),
                  
                  const SizedBox(height: 40),
                  
                  // 3. TRENDING
                  _buildSectionHeader(AppLocalizations.of(context)!.homeTrending),
                  const SizedBox(height: 16),
                  isLoading
                      ? _buildShimmerHorizontalList()
                      : SongCardList(songs: trendingSongs),
                  
                  if (suggestedSongs.isNotEmpty || isLoading) ...[
                    const SizedBox(height: 40),
                    // 4. SUGGESTED
                    _buildSectionHeader(AppLocalizations.of(context)!.homeSuggested),
                    const SizedBox(height: 16),
                    isLoading
                      ? _buildShimmerHorizontalList()
                      : SongCardList(songs: suggestedSongs),
                  ],
                  const SizedBox(height: 200), 
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreetingPrefix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4, height: 24,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildVibeSelector() {
    final vibes = [
      {'name': 'Happy', 'color': const Color(0xFFFFD700), 'icon': Icons.wb_sunny_rounded},
      {'name': 'Chill', 'color': const Color(0xFF4FC3F7), 'icon': Icons.nightlight_round},
      {'name': 'Energy', 'color': const Color(0xFFFF7043), 'icon': Icons.bolt_rounded},
      {'name': 'Focus', 'color': const Color(0xFF4DB6AC), 'icon': Icons.psychology_rounded},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vibes.length,
        itemBuilder: (context, i) {
          final vibe = vibes[i];
          final color = vibe['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                // Perform mood search here
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(vibe['icon'] as IconData, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      vibe['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerHorizontalList() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer(child: ShimmerBox(width: 140, height: 140, borderRadius: 20)),
              const SizedBox(height: 12),
              Shimmer(child: ShimmerBox(width: 100, height: 14, borderRadius: 4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 50, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showProfileAndThemeMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (context) => _ProfileAndThemeSheet(auth: auth),
    );
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}

class _ProfileAndThemeSheet extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileAndThemeSheet({required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.5))),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.accentColor.withValues(alpha: 0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundImage: auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null,
                      child: auth.user?.photoURL == null ? const Icon(Icons.person, size: 38) : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.user?.displayName ?? 'Guest User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        Text(auth.user?.email ?? 'Join us to sync your music', style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // PERSONALIZATION
              const Align(alignment: Alignment.centerLeft, child: Text('PERSONALIZATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2.0, color: Colors.white38))),
              const SizedBox(height: 24),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Adaptive Interface', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Colors follow current album art', style: TextStyle(fontSize: 12, color: Colors.white54)),
                      value: theme.isAdaptive,
                      activeColor: theme.accentColor,
                      onChanged: (v) {
                        HapticFeedback.mediumImpact();
                        theme.toggleAdaptive(v);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
                    ListTile(
                      title: const Text('Theme Preset', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: DropdownButton<ThemeModePreset>(
                        value: theme.preset,
                        underline: const SizedBox(),
                        dropdownColor: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        onChanged: (v) {
                          if (v != null) theme.setPreset(v);
                        },
                        items: ThemeModePreset.values.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name[0].toUpperCase() + p.name.substring(1), style: const TextStyle(fontSize: 14)),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (!theme.isAdaptive) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ThemeProvider.premiumPalette.length,
                    itemBuilder: (context, i) {
                      final c = ThemeProvider.premiumPalette[i];
                      final isSelected = theme.accentColor.value == c.value;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          theme.setAccentColor(c);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isSelected ? 48 : 40,
                          height: isSelected ? 48 : 40,
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.white10, width: 1),
                            boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 12)] : [],
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              if (auth.isSignedIn)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () { 
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context); 
                      auth.signOut(); 
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
