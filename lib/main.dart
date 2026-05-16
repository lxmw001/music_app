import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'firebase_options.dart';
import 'providers/music_player_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/youtube_service.dart';
import 'services/update_service.dart';
import 'services/profile_service.dart';
import 'widgets/youtube_login_webview.dart';
import 'widgets/mini_equalizer.dart';
import 'widgets/mesh_gradient.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (defaultTargetPlatform == TargetPlatform.android) {
    JustAudioMediaKit.ensureInitialized(android: true);
  }
  
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await const MethodChannel('com.lxmw.musicapp/battery')
          .invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<ThemeProvider, MusicPlayerProvider>(
          create: (_) => MusicPlayerProviderImpl(),
          update: (_, theme, player) {
            final impl = player as MusicPlayerProviderImpl;
            impl.setThemeProvider(theme);
            return impl;
          },
        ),
        ChangeNotifierProxyProvider<MusicPlayerProvider, AuthProvider>(
          create: (_) => AuthProvider(),
          update: (_, musicPlayer, auth) {
            final a = auth ?? AuthProvider();
            final impl = musicPlayer as MusicPlayerProviderImpl;
            impl.setAuthProvider(a);
            a.setYouTubeService(impl.youtubeService);
            return a;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Music App',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
          ],
          theme: theme.getThemeData(),
          initialRoute: '/',
          routes: {
            '/': (context) => const Initializer(),
            '/home': (context) => const MainScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
          },
        );
      },
    );
  }
}

class Initializer extends StatefulWidget {
  const Initializer({super.key});

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final onboarded = await ProfileService().isOnboarded();
    if (mounted) {
      if (onboarded) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainScreen extends StatefulWidget {
  final YouTubeService? youtubeService;
  const MainScreen({super.key, this.youtubeService});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final List<Widget> _screens;
  String? _updateUrl;
  double? _downloadProgress;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _screens = [
      HomeScreen(youtubeService: widget.youtubeService),
      SearchScreen(youtubeService: widget.youtubeService),
      LibraryScreen(),
    ];
    UpdateService().checkForUpdate().then((url) {
      if (url != null && mounted) setState(() => _updateUrl = url);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<MusicPlayerProvider>() as MusicPlayerProviderImpl;
      player.setOnRateLimit(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('YouTube rate limited — playing downloaded songs'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ));
      });
      player.setOnStreamError((title) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load "$title"'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _jumpToPage(0);
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.exitConfirm), 
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  void _jumpToPage(int index) {
    if (_currentIndex != index) {
      FocusScope.of(context).unfocus();
    }
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<MusicPlayerProvider>();
    final isFastMode = player.isFastModeActive;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isFastMode) {
          player.exitFastMode();
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // Global Mesh Aura - Hide if Fast Mode is active (it will have its own)
            if (!isFastMode) MeshGradient(color: theme.accentColor),
            
            Column(
              children: [
                if (!isFastMode && _updateUrl != null)
                  MaterialBanner(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    content: _downloadProgress != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocalizations.of(context)!.updateDownloading((_downloadProgress! * 100).toInt())),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: _downloadProgress),
                            ],
                          )
                        : Text(AppLocalizations.of(context)!.updateAvailable),
                    actions: _downloadProgress != null
                        ? [const SizedBox.shrink()]
                        : [
                            TextButton(
                              onPressed: () async {
                                setState(() => _downloadProgress = 0.0);
                                await UpdateService().downloadAndInstall(
                                  _updateUrl!,
                                  onProgress: (p) => setState(() => _downloadProgress = p),
                                );
                                setState(() { _updateUrl = null; _downloadProgress = null; });
                              },
                              child: Text(AppLocalizations.of(context)!.updateButton),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _updateUrl = null),
                              child: Text(AppLocalizations.of(context)!.updateDismiss),
                            ),
                          ],
                  ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      FocusScope.of(context).unfocus();
                      setState(() => _currentIndex = index);
                    },
                    physics: isFastMode 
                        ? const NeverScrollableScrollPhysics() 
                        : const BouncingScrollPhysics(),
                    children: _screens,
                  ),
                ),
              ],
            ),
            
            // Floating Mini Player & NavBar - HIDE IF FAST MODE IS ACTIVE
            if (!isFastMode) ...[
              Positioned(
                left: 12, right: 12, bottom: 95,
                child: Consumer<MusicPlayerProvider>(
                  builder: (context, player, child) {
                    if (player.currentSong == null) return const SizedBox.shrink();
                    return _buildMiniPlayer(player);
                  },
                ),
              ),
              Positioned(
                left: 20, right: 20, bottom: 20,
                child: _buildFloatingNavBar(theme),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeProvider theme) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 25, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: Colors.white.withValues(alpha: 0.06),
            child: Stack(
              children: [
                // Animated Sliding Indicator
                AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  alignment: Alignment(-1.0 + (_currentIndex * 1.0), 0.0),
                  child: FractionallySizedBox(
                    widthFactor: 1/3,
                    child: Center(
                      child: Container(
                        width: 54, height: 44,
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: theme.accentColor.withValues(alpha: 0.1), width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      _navItem(0, Icons.home_rounded, Icons.home_outlined),
                      _navItem(1, Icons.search_rounded, Icons.search_outlined),
                      _navItem(2, Icons.library_music_rounded, Icons.library_music_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.white54;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _jumpToPage(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Icon(isSelected ? activeIcon : inactiveIcon, color: color, size: 28),
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(MusicPlayerProvider player) {
    final theme = Theme.of(context);
    final song = player.currentSong!;
    final progress = player.totalDuration.inSeconds > 0
        ? (player.currentPosition.inSeconds / player.totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutQuart))
                .animate(animation),
              child: child,
            );
          },
        ),
      ),
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          HapticFeedback.mediumImpact();
          player.nextSong();
        } else if (details.primaryVelocity! > 300) {
          HapticFeedback.mediumImpact();
          player.previousSong();
        }
      },
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withValues(alpha: 0.08),
              child: Stack(
                children: [
                  // LIQUID PROGRESS FILL
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.primaryColor.withValues(alpha: 0.15),
                              theme.primaryColor.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'player_art',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              song.imageUrl,
                              width: 44, height: 44, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44, height: 44, color: Colors.grey[800],
                                child: const Icon(Icons.music_note, size: 24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: -0.2),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.artist,
                                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (player.isPlaying) 
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: MiniEqualizer(isPlaying: true, color: theme.primaryColor),
                          ),
                        IconButton(
                          icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 34),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.isPlaying ? player.pause() : player.resume();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Progress line indicator at bottom
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: player.totalDuration.inSeconds > 0
                          ? (player.currentPosition.inSeconds / player.totalDuration.inSeconds).clamp(0.0, 1.0)
                          : 0.0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          boxShadow: [
                            BoxShadow(color: theme.primaryColor.withValues(alpha: 0.6), blurRadius: 6),
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
      ),
    );
  }
}
