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
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';
import 'screens/login_screen.dart';
import 'services/youtube_service.dart';
import 'services/update_service.dart';
import 'widgets/youtube_login_webview.dart';

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
    systemNavigationBarColor: Colors.black,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MusicPlayerProvider>(create: (_) => MusicPlayerProviderImpl()),
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          brightness: Brightness.dark,
          surface: Colors.black,
          onSurface: Colors.white,
          primary: const Color(0xFF1DB954),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Color(0xFF1DB954),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
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
  late final List<Widget> _screens;
  String? _updateUrl;
  double? _downloadProgress;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
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

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            if (_updateUrl != null)
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
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            // Improved Mini Player
            Consumer<MusicPlayerProvider>(
              builder: (context, player, child) {
                if (player.currentSong != null) {
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                            child: child,
                          );
                        },
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]?.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'player_art',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        player.currentSong!.imageUrl,
                                        width: 44, height: 44, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 44, height: 44, color: Colors.grey[800],
                                          child: const Icon(Icons.music_note, size: 24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player.currentSong!.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          player.currentSong!.artist,
                                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                                    onPressed: () => player.isPlaying ? player.pause() : player.resume(),
                                  ),
                                ],
                              ),
                            ),
                            LinearProgressIndicator(
                              value: player.totalDuration.inSeconds > 0
                                  ? (player.currentPosition.inSeconds / player.totalDuration.inSeconds).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              minHeight: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined),
              label: AppLocalizations.of(context)!.navHome,
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 1 ? Icons.search_rounded : Icons.search_outlined),
              label: AppLocalizations.of(context)!.navSearch,
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 2 ? Icons.library_music_rounded : Icons.library_music_outlined),
              label: AppLocalizations.of(context)!.navLibrary,
            ),
          ],
        ),
      ),
    );
  }
}
