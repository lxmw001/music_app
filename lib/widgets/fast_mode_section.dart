import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vibe.dart';
import '../providers/music_player_provider.dart';

class FastModeSection extends StatelessWidget {
  const FastModeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text(
                'Fast Mode',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
              SizedBox(width: 4),
              Text('AI Powered', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: availableVibes.length,
            itemBuilder: (context, index) {
              final vibe = availableVibes[index];
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
        width: 100,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: vibe.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: vibe.color.withOpacity(0.5), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(vibe.icon, color: vibe.color, size: 32),
            const SizedBox(height: 8),
            Text(
              vibe.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
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
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select ${vibe.label} Type',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...vibe.subCategories.map((sub) => ListTile(
                leading: Icon(Icons.music_note, color: vibe.color),
                title: Text(sub.label),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  context.read<MusicPlayerProvider>().playFastMode(
                    vibeId: vibe.id,
                    subCategoryId: sub.id,
                  );
                },
              )).toList(),
            ],
          ),
        );
      },
    );
  }
}
