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
import '../widgets/fast_mode_section.dart';
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
    final player = context.watch<MusicPlayerProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;
    
    if (player.isFastModeActive) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: FastModeSection(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: RefreshIndicator(
        onRefresh: _loadWithCache,
        color: primaryColor,
        edgeOffset: 100,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
                title: AnimatedListItem(
                  index: 0,
                  child: Column(
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
                        _getPrompt(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 28, 
                          letterSpacing: -1.0,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              actions: [
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: auth.isSignedIn && auth.user?.photoURL != null
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                                boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.2), blurRadius: 8)],
                              ),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundImage: NetworkImage(auth.user!.photoURL!),
                              ),
                            )
                          : Icon(Icons.account_circle_outlined, size: 28, color: Colors.white.withValues(alpha: 0.7)),
                      onPressed: () => _showProfileAndThemeMenu(context, auth),
                    ),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),
                  
                  // 0. FAST MODE SECTION
                  const AnimatedListItem(index: 1, child: FastModeSection()),

                  const SizedBox(height: 48),
                  
                  // 1. RECENTLY PLAYED
                  _buildSectionHeader(l10n.homeRecentlyPlayed, index: 2),
                  const SizedBox(height: 20),
                  if (recentPlaylists.isEmpty && !isLoading)
                    AnimatedListItem(index: 3, child: _buildEmptyState(Icons.history_rounded, l10n.homeNoPlaylists))
                  else if (isLoading && recentPlaylists.isEmpty)
                    _buildShimmerHorizontalList()
                  else
                    RecentPlaylistsGrid(playlists: recentPlaylists),
                  
                  const SizedBox(height: 48),
                  
                  // 2. TRENDING
                  _buildSectionHeader(l10n.homeTrending, index: 4),
                  const SizedBox(height: 20),
                  isLoading
                      ? _buildShimmerHorizontalList()
                      : SongCardList(songs: trendingSongs),
                  
                  if (suggestedSongs.isNotEmpty || isLoading) ...[
                    const SizedBox(height: 48),
                    // 3. SUGGESTED
                    _buildSectionHeader(l10n.homeSuggested, index: 5),
                    const SizedBox(height: 20),
                    isLoading
                      ? _buildShimmerHorizontalList()
                      : SongCardList(songs: suggestedSongs),
                  ],
                  const SizedBox(height: 180), 
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreetingPrefix() {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 17) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  String _getPrompt() {
    final l10n = AppLocalizations.of(context)!;
    final prompts = [
      l10n.promptVibe,
      l10n.promptReady,
      l10n.promptFindSound,
      l10n.promptMood,
      l10n.promptBeat,
    ];
    final hour = DateTime.now().hour;
    return prompts[hour % prompts.length];
  }

  Widget _buildSectionHeader(String title, {required int index}) {
    return AnimatedListItem(
      index: index,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 20,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), blurRadius: 8),
                  ],
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ],
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildShimmerHorizontalList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer(child: ShimmerBox(width: 155, height: 155, borderRadius: 24)),
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
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showProfileAndThemeMenu(BuildContext context, AuthProvider auth) {
    HapticFeedback.mediumImpact();
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
    final primary = theme.accentColor;
    
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
                      border: Border.all(color: primary.withValues(alpha: 0.5), width: 2),
                      boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 15)],
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
              
              Align(alignment: Alignment.centerLeft, child: Text(AppLocalizations.of(context)!.personalizationTitle.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2.0, color: Colors.white38))),
              const SizedBox(height: 24),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(AppLocalizations.of(context)!.personalizationAdaptive, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(AppLocalizations.of(context)!.personalizationAdaptiveSubtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      value: theme.isAdaptive,
                      activeColor: primary,
                      onChanged: (v) {
                        HapticFeedback.mediumImpact();
                        theme.toggleAdaptive(v);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
                    ListTile(
                      title: Text(AppLocalizations.of(context)!.personalizationThemePreset, style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: DropdownButton<ThemeModePreset>(
                        value: theme.preset,
                        underline: const SizedBox(),
                        dropdownColor: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        onChanged: (v) {
                          if (v != null) {
                            HapticFeedback.selectionClick();
                            theme.setPreset(v);
                          }
                        },
                        items: ThemeModePreset.values.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name[0].toUpperCase() + p.name.substring(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                            boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 15)] : [],
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
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(AppLocalizations.of(context)!.commonSignOut, style: const TextStyle(fontWeight: FontWeight.w900)),
                    onPressed: () { 
                      HapticFeedback.heavyImpact();
                      Navigator.pop(context); 
                      auth.signOut(); 
                    },
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      foregroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(AppLocalizations.of(context)!.commonSignIn, style: const TextStyle(fontWeight: FontWeight.w900)),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
