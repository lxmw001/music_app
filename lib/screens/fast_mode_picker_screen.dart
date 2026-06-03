import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/vibe.dart';
import '../providers/music_player_provider.dart';
import '../widgets/mesh_gradient.dart';
import '../widgets/animated_list_item.dart';

class FastModePickerScreen extends StatefulWidget {
  const FastModePickerScreen({super.key});

  @override
  State<FastModePickerScreen> createState() => _FastModePickerScreenState();
}

class _FastModePickerScreenState extends State<FastModePickerScreen> {
  Vibe? _selectedVibe;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerProvider>();
    final vibes = player.vibes;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          MeshGradient(color: _selectedVibe?.color ?? primary),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _selectedVibe == null
                        ? _buildVibeGrid(vibes)
                        : _buildSubCategoryList(_selectedVibe!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 24, 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _selectedVibe == null ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, 
              color: Colors.white, 
              size: 28
            ),
            onPressed: () {
              if (_selectedVibe != null) {
                HapticFeedback.lightImpact();
                setState(() => _selectedVibe = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedVibe == null ? 'Choose your Vibe' : _selectedVibe!.getLocalizedName(context),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.0),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeGrid(List<Vibe> vibes) {
    return GridView.builder(
      key: const ValueKey('vibe_grid'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: vibes.length,
      itemBuilder: (context, index) {
        final vibe = vibes[index];
        return _VibeCard(
          vibe: vibe,
          index: index,
          onTap: () {
            if (vibe.subCategories.isNotEmpty) {
              setState(() => _selectedVibe = vibe);
            } else {
              context.read<MusicPlayerProvider>().playFastMode(vibeId: vibe.id);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }

  Widget _buildSubCategoryList(Vibe vibe) {
    return ListView.builder(
      key: const ValueKey('subcategory_list'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: vibe.subCategories.length + 1,
      itemBuilder: (context, index) {
        final bool isDefault = index == 0;
        final String label = isDefault ? 'Surprise Me' : vibe.subCategories[index - 1].getLocalizedName(context);
        final String icon = isDefault ? '✨' : vibe.subCategories[index - 1].icon;
        final String? subId = isDefault ? null : vibe.subCategories[index - 1].labelKey;

        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () {
                HapticFeedback.heavyImpact();
                context.read<MusicPlayerProvider>().playFastMode(
                  vibeId: vibe.id,
                  subCategoryId: subId,
                );
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: vibe.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.play_circle_fill_rounded, size: 36, color: vibe.color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VibeCard extends StatefulWidget {
  final Vibe vibe;
  final int index;
  final VoidCallback onTap;
  const _VibeCard({required this.vibe, required this.index, required this.onTap});

  @override
  State<_VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends State<_VibeCard> {
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
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.vibe.color.withValues(alpha: 0.4),
                  widget.vibe.color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: widget.vibe.color.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.vibe.color.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10, bottom: -10,
                  child: Opacity(
                    opacity: 0.1,
                    child: Text(widget.vibe.icon, style: const TextStyle(fontSize: 80)),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.vibe.icon, style: const TextStyle(fontSize: 54)),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          widget.vibe.getLocalizedName(context).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
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
}
