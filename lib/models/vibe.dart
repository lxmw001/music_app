import 'package:flutter/material.dart';

class Vibe {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<VibeSubCategory> subCategories;
  final String? defaultQuery;

  const Vibe({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.subCategories = const [],
    this.defaultQuery,
  });
}

class VibeSubCategory {
  final String id;
  final String label;
  final String query;

  const VibeSubCategory({
    required this.id,
    required this.label,
    required this.query,
  });
}

const List<Vibe> availableVibes = [
  Vibe(
    id: 'exercise',
    label: 'Exercise',
    icon: Icons.fitness_center,
    color: Colors.orange,
    subCategories: [
      VibeSubCategory(id: 'hiit', label: 'HIIT / Cardio', query: 'High BPM HIIT training music'),
      VibeSubCategory(id: 'strength', label: 'Strength', query: 'Motivational gym music for lifting'),
      VibeSubCategory(id: 'yoga', label: 'Yoga / Stretch', query: 'Calming yoga and stretching music'),
    ],
  ),
  Vibe(
    id: 'party',
    label: 'Party',
    icon: Icons.celebration,
    color: Colors.pink,
    subCategories: [
      VibeSubCategory(id: 'club', label: 'Club / Dance', query: 'Modern house and dance hits'),
      VibeSubCategory(id: 'dinner', label: 'Chill / Dinner', query: 'Sophisticated dinner party soul and jazz'),
      VibeSubCategory(id: 'singalong', label: 'Sing-Along', query: 'Famous pop anthems everyone knows'),
    ],
  ),
  Vibe(
    id: 'focus',
    label: 'Focus',
    icon: Icons.biotech,
    color: Colors.blue,
    defaultQuery: 'Instrumental focus music for working',
    subCategories: [
      VibeSubCategory(id: 'lofi', label: 'Lofi Study', query: 'Lofi hip hop beats for studying'),
      VibeSubCategory(id: 'deep', label: 'Deep Work', query: 'Minimal techno and binaural beats for concentration'),
    ],
  ),
  Vibe(
    id: 'nostalgia',
    label: 'Nostalgia',
    icon: Icons.history,
    color: Colors.purple,
    defaultQuery: 'Hits from my teenage years',
  ),
  Vibe(
    id: 'relax',
    label: 'Relax',
    icon: Icons.self_improvement,
    color: Colors.teal,
    defaultQuery: 'Chill acoustic and soft vocals',
  ),
];
