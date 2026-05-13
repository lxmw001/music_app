import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vibe.dart';
import '../providers/music_player_provider.dart';

class FastModeSection extends StatelessWidget {
  const FastModeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerProvider>();
    final vibes = player.vibes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Fast Mode',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (player.isFetchingVibe)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                )
              else ...[
                const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                const SizedBox(width: 4),
                const Text('AI Powered',
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: vibes.length,
            itemBuilder: (context, index) {
              final vibe = vibes[index];
              return _VibeCard(vibe: vibe);
            },
          ),
        ),
      ],
    );
  }
}

class _VibeCard extends StatelessWidget {
  final Vibe vibe;
  const _VibeCard({required this.vibe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleVibeTap(context),
      child: Container(
        width: 110,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: vibe.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: vibe.color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              vibe.icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                vibe.getLocalizedName(context),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleVibeTap(BuildContext context) {
    if (vibe.subCategories.isNotEmpty) {
      _showSubCategoryPicker(context);
    } else {
      context.read<MusicPlayerProvider>().playFastMode(vibeId: vibe.id);
    }
  }

  void _showSubCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      vibe.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      vibe.getLocalizedName(context),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vibe.subCategories.length,
                  itemBuilder: (context, i) {
                    final sub = vibe.subCategories[i];
                    return ListTile(
                      leading: Text(sub.icon, style: const TextStyle(fontSize: 24)),
                      title: Text(sub.getLocalizedName(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: const Icon(Icons.play_circle_outline_rounded, color: Colors.white38),
                      onTap: () {
                        Navigator.pop(context);
                        context.read<MusicPlayerProvider>().playFastMode(
                          vibeId: vibe.id,
                          subCategoryId: sub.labelKey, // Using labelKey as ID for AI refinements if needed, or sub.id if we had one
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
