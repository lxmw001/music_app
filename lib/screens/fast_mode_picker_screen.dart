import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/vibe.dart';
import '../providers/music_player_provider.dart';
import '../widgets/mesh_gradient.dart';

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

    return Scaffold(
      body: Stack(
        children: [
          const MeshGradient(color: Colors.blue),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
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
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_selectedVibe == null ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, 
              color: Colors.white, size: 30),
            onPressed: () {
              if (_selectedVibe != null) {
                setState(() => _selectedVibe = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 12),
          Text(
            _selectedVibe == null ? 'Choose your Vibe' : _selectedVibe!.getLocalizedName(context),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeGrid(List<Vibe> vibes) {
    return GridView.builder(
      key: const ValueKey('vibe_grid'),
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 1,
      ),
      itemCount: vibes.length,
      itemBuilder: (context, index) {
        final vibe = vibes[index];
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (vibe.subCategories.isNotEmpty) {
              setState(() => _selectedVibe = vibe);
            } else {
              context.read<MusicPlayerProvider>().playFastMode(vibeId: vibe.id);
              Navigator.pop(context);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [vibe.color.withValues(alpha: 0.4), vibe.color.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: vibe.color.withValues(alpha: 0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(vibe.icon, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  vibe.getLocalizedName(context),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.play_circle_fill_rounded, size: 40, color: Colors.white70),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
