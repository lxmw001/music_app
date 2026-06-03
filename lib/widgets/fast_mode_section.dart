import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/vibe.dart';
import '../providers/music_player_provider.dart';
import '../screens/fast_mode_picker_screen.dart';
import 'mesh_gradient.dart';
import 'floating_particles.dart';

class FastModeSection extends StatelessWidget {
  const FastModeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerProvider>();
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      switchInCurve: Curves.easeInOutQuart,
      switchOutCurve: Curves.easeInOutQuart,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: player.isFastModeActive 
          ? _buildFullScreenPlayer(context, player) 
          : _buildIdleHero(context, player),
    );
  }

  Widget _buildIdleHero(BuildContext context, MusicPlayerProvider player) {
    final savedVibe = player.lastSavedVibe;
    Vibe? vibeObj;
    if (savedVibe != null) {
      try {
        vibeObj = player.vibes.firstWhere((v) => v.id == savedVibe.vibeId);
      } catch (_) {}
    }

    if (savedVibe != null && vibeObj != null) {
      return _buildResumeHero(context, player, vibeObj);
    }

    return _buildNewVibeHero(context);
  }

  Widget _buildResumeHero(BuildContext context, MusicPlayerProvider player, Vibe vibe) {
    return Padding(
      key: const ValueKey('resume'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: LinearGradient(
            colors: [
              vibe.color.withValues(alpha: 0.3),
              vibe.color.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: vibe.color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(color: vibe.color.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              Positioned(
                right: -40, bottom: -40,
                child: Opacity(
                  opacity: 0.08,
                  child: Text(vibe.icon, style: const TextStyle(fontSize: 200)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.fastModeContinueVibe.toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vibe.getLocalizedName(context).toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              player.resumeLastVibe();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: vibe.color,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 28),
                            label: Text(AppLocalizations.of(context)!.fastModeResumeNow.toUpperCase(), 
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add_rounded, size: 28, color: Colors.white70),
                            onPressed: () => _launchPicker(context),
                            padding: const EdgeInsets.all(18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewVibeHero(BuildContext context) {
    return Padding(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: InkWell(
        onTap: () => _launchPicker(context),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: LinearGradient(
              colors: [
                Colors.amber.withValues(alpha: 0.3),
                Colors.orange.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.orange.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, bottom: -20,
                child: Icon(Icons.bolt_rounded, size: 180, color: Colors.amber.withValues(alpha: 0.08)),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 14),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.fastModeAiEngine.toUpperCase(), 
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.fastModeStart,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.fastModeTagline,
                      style: const TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenPlayer(BuildContext context, MusicPlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();
    
    final vibeId = player.activeVibeId;
    final vibe = player.vibes.firstWhere((v) => v.id == vibeId, orElse: () => player.vibes.first);

    return Scaffold(
      key: const ValueKey('active_full'),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // IMMERSIVE BACKGROUND
          MeshGradient(color: vibe.color),
          FloatingParticles(color: vibe.color),
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: vibe.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: vibe.color.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Text(vibe.icon, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Text(
                                  vibe.getLocalizedName(context).toUpperCase(),
                                  style: TextStyle(color: vibe.color, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 36, color: Colors.white54),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          player.exitFastMode();
                        },
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // HUGE CIRCULAR ART
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (player.isPlaying)
                        _PulsingRings(color: vibe.color),
                      
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeInOutBack,
                        width: MediaQuery.of(context).size.width * (player.isPlaying ? 0.82 : 0.72),
                        height: MediaQuery.of(context).size.width * (player.isPlaying ? 0.82 : 0.72),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: vibe.color.withValues(alpha: 0.3), blurRadius: 100, spreadRadius: 10),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            song.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // TRACK INFO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1),
                        textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        song.artist.toUpperCase(),
                        style: TextStyle(fontSize: 16, color: vibe.color, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        textAlign: TextAlign.center,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // HUGE CONTROLS
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _HugeControlIcon(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          player.playFastMode(
                            vibeId: player.activeVibeId!,
                            subCategoryId: player.activeSubCategoryId,
                          );
                        },
                        isLoading: player.isFetchingVibe,
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          player.isPlaying ? player.pause() : player.resume();
                        },
                        child: Container(
                          height: 120, width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: vibe.color.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black, size: 80,
                          ),
                        ),
                      ),
                      _HugeControlIcon(
                        icon: Icons.skip_next_rounded,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          player.nextSong();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launchPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const FastModePickerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _HugeControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _HugeControlIcon({required this.icon, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4)
          : IconButton(
              icon: Icon(icon, size: 44, color: Colors.white),
              onPressed: onTap,
            ),
      ),
    );
  }
}

class _PulsingRings extends StatefulWidget {
  final Color color;
  const _PulsingRings({required this.color});

  @override
  _PulsingRingsState createState() => _PulsingRingsState();
}

class _PulsingRingsState extends State<_PulsingRings> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (index) {
            final progress = (_controller.value + (index / 3)) % 1.0;
            return Container(
              width: MediaQuery.of(context).size.width * 0.8 * (1 + progress * 0.4),
              height: MediaQuery.of(context).size.width * 0.8 * (1 + progress * 0.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: (1 - progress) * 0.4),
                  width: 2,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
