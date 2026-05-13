import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class Vibe {
  final String id;
  final String labelKey;
  final String label; // promptLabel from server (fallback)
  final String icon; // emoji string
  final int order;
  final List<VibeSubCategory> subCategories;
  final Color color; // UI styling mapped from labelKey

  const Vibe({
    required this.id,
    required this.labelKey,
    required this.label,
    required this.icon,
    required this.order,
    this.subCategories = const [],
    this.color = Colors.green,
  });

  factory Vibe.fromJson(Map<String, dynamic> json) {
    final key = json['labelKey'] ?? '';
    return Vibe(
      id: json['id'] ?? '',
      labelKey: key,
      label: json['promptLabel'] ?? '',
      icon: json['icon'] ?? '🎵',
      order: json['order'] ?? 0,
      subCategories: (json['subCategories'] as List? ?? [])
          .map((s) => VibeSubCategory.fromJson(s))
          .toList(),
      color: _generateColor(key),
    );
  }

  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (labelKey) {
      case 'vibe_chill': return l10n.vibe_chill;
      case 'vibe_energetic': return l10n.vibe_energetic;
      case 'vibe_party': return l10n.vibe_party;
      case 'vibe_romantic': return l10n.vibe_romantic;
      case 'vibe_sad': return l10n.vibe_sad;
      case 'vibe_focus': return l10n.vibe_focus;
      case 'vibe_happy': return l10n.vibe_happy;
      case 'vibe_latin': return l10n.vibe_latin;
      case 'vibe_night': return l10n.vibe_night;
      case 'vibe_sleep': return l10n.vibe_sleep;
      case 'vibe_chores': return l10n.vibe_chores;
      case 'vibe_gaming': return l10n.vibe_gaming;
      case 'vibe_travel': return l10n.vibe_travel;
      case 'vibe_nostalgia': return l10n.vibe_nostalgia;
      default: return label;
    }
  }

  static Color _generateColor(String key) {
    switch (key) {
      case 'vibe_chill': return Colors.teal;
      case 'vibe_energetic': return Colors.orange;
      case 'vibe_party': return Colors.pink;
      case 'vibe_romantic': return Colors.red;
      case 'vibe_sad': return Colors.blueGrey;
      case 'vibe_focus': return Colors.blue;
      case 'vibe_happy': return Colors.yellow.shade700;
      case 'vibe_latin': return Colors.deepOrange;
      case 'vibe_night': return Colors.indigo;
      case 'vibe_sleep': return Colors.purple;
      case 'vibe_chores': return Colors.brown;
      case 'vibe_gaming': return Colors.deepPurple;
      case 'vibe_travel': return Colors.cyan;
      case 'vibe_nostalgia': return Colors.amber;
      default: return Colors.green;
    }
  }
}

class VibeSubCategory {
  final String labelKey;
  final String label; // promptLabel from server (fallback)
  final String icon;

  const VibeSubCategory({
    required this.labelKey,
    required this.label,
    required this.icon,
  });

  factory VibeSubCategory.fromJson(Map<String, dynamic> json) {
    return VibeSubCategory(
      labelKey: json['labelKey'] ?? json['key'] ?? '',
      label: json['promptLabel'] ?? '',
      icon: json['icon'] ?? '🎵',
    );
  }

  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (labelKey) {
      case 'vibe_chill_lofi': return l10n.vibe_chill_lofi;
      case 'vibe_chill_acoustic': return l10n.vibe_chill_acoustic;
      case 'vibe_chill_ambient': return l10n.vibe_chill_ambient;
      case 'vibe_chill_jazz': return l10n.vibe_chill_jazz;
      case 'vibe_chill_nature': return l10n.vibe_chill_nature;
      case 'vibe_chill_piano': return l10n.vibe_chill_piano;
      case 'vibe_chill_yoga': return l10n.vibe_chill_yoga;
      case 'vibe_energetic_hiit': return l10n.vibe_energetic_hiit;
      case 'vibe_energetic_running': return l10n.vibe_energetic_running;
      case 'vibe_energetic_cycling': return l10n.vibe_energetic_cycling;
      case 'vibe_energetic_sports': return l10n.vibe_energetic_sports;
      case 'vibe_energetic_dance': return l10n.vibe_energetic_dance;
      case 'vibe_party_club': return l10n.vibe_party_club;
      case 'vibe_party_birthday': return l10n.vibe_party_birthday;
      case 'vibe_party_babyshower': return l10n.vibe_party_babyshower;
      case 'vibe_party_kids': return l10n.vibe_party_kids;
      case 'vibe_party_wedding': return l10n.vibe_party_wedding;
      case 'vibe_party_graduation': return l10n.vibe_party_graduation;
      case 'vibe_party_bbq': return l10n.vibe_party_bbq;
      case 'vibe_party_pregame': return l10n.vibe_party_pregame;
      case 'vibe_party_christmas': return l10n.vibe_party_christmas;
      case 'vibe_party_halloween': return l10n.vibe_party_halloween;
      case 'vibe_party_new_year': return l10n.vibe_party_new_year;
      case 'vibe_romantic_date': return l10n.vibe_romantic_date;
      case 'vibe_romantic_ballad': return l10n.vibe_romantic_ballad;
      case 'vibe_romantic_wedding': return l10n.vibe_romantic_wedding;
      case 'vibe_romantic_anniversary': return l10n.vibe_romantic_anniversary;
      case 'vibe_romantic_serenade': return l10n.vibe_romantic_serenade;
      case 'vibe_sad_heartbreak': return l10n.vibe_sad_heartbreak;
      case 'vibe_sad_nostalgic': return l10n.vibe_sad_nostalgic;
      case 'vibe_sad_rainy': return l10n.vibe_sad_rainy;
      case 'vibe_sad_lonely': return l10n.vibe_sad_lonely;
      case 'vibe_sad_cry': return l10n.vibe_sad_cry;
      case 'vibe_focus_study': return l10n.vibe_focus_study;
      case 'vibe_focus_work': return l10n.vibe_focus_work;
      case 'vibe_focus_reading': return l10n.vibe_focus_reading;
      case 'vibe_focus_coding': return l10n.vibe_focus_coding;
      case 'vibe_focus_meditation': return l10n.vibe_focus_meditation;
      case 'vibe_focus_deep_work': return l10n.vibe_focus_deep_work;
      case 'vibe_happy_summer': return l10n.vibe_happy_summer;
      case 'vibe_happy_feel_good': return l10n.vibe_happy_feel_good;
      case 'vibe_happy_morning': return l10n.vibe_happy_morning;
      case 'vibe_happy_road_trip': return l10n.vibe_happy_road_trip;
      case 'vibe_happy_beach': return l10n.vibe_happy_beach;
      case 'vibe_happy_celebration': return l10n.vibe_happy_celebration;
      case 'vibe_latin_reggaeton': return l10n.vibe_latin_reggaeton;
      case 'vibe_latin_salsa': return l10n.vibe_latin_salsa;
      case 'vibe_latin_cumbia': return l10n.vibe_latin_cumbia;
      case 'vibe_latin_bachata': return l10n.vibe_latin_bachata;
      case 'vibe_latin_merengue': return l10n.vibe_latin_merengue;
      case 'vibe_latin_vallenato': return l10n.vibe_latin_vallenato;
      case 'vibe_latin_pop': return l10n.vibe_latin_pop;
      case 'vibe_latin_trap': return l10n.vibe_latin_trap;
      case 'vibe_night_late': return l10n.vibe_night_late;
      case 'vibe_night_club': return l10n.vibe_night_club;
      case 'vibe_night_chill': return l10n.vibe_night_chill;
      case 'vibe_night_drive': return l10n.vibe_night_drive;
      case 'vibe_night_rooftop': return l10n.vibe_night_rooftop;
      case 'vibe_sleep_deep': return l10n.vibe_sleep_deep;
      case 'vibe_sleep_relax': return l10n.vibe_sleep_relax;
      case 'vibe_sleep_white_noise': return l10n.vibe_sleep_white_noise;
      case 'vibe_sleep_baby': return l10n.vibe_sleep_baby;
      case 'vibe_sleep_meditation': return l10n.vibe_sleep_meditation;
      case 'vibe_chores_cleaning': return l10n.vibe_chores_cleaning;
      case 'vibe_chores_cooking': return l10n.vibe_chores_cooking;
      case 'vibe_chores_laundry': return l10n.vibe_chores_laundry;
      case 'vibe_chores_gardening': return l10n.vibe_chores_gardening;
      case 'vibe_chores_diy': return l10n.vibe_chores_diy;
      case 'vibe_gaming_rpg': return l10n.vibe_gaming_rpg;
      case 'vibe_gaming_hype': return l10n.vibe_gaming_hype;
      case 'vibe_gaming_retro': return l10n.vibe_gaming_retro;
      case 'vibe_travel_commute': return l10n.vibe_travel_commute;
      case 'vibe_travel_road_trip': return l10n.vibe_travel_road_trip;
      case 'vibe_travel_flying': return l10n.vibe_travel_flying;
      case 'vibe_nostalgia_80s': return l10n.vibe_nostalgia_80s;
      case 'vibe_nostalgia_90s': return l10n.vibe_nostalgia_90s;
      case 'vibe_nostalgia_2000s': return l10n.vibe_nostalgia_2000s;
      case 'vibe_nostalgia_personal': return l10n.vibe_nostalgia_personal;
      case 'vibe_nostalgia_childhood': return l10n.vibe_nostalgia_childhood;
      default: return label;
    }
  }
}

// Fallback vibes matching the latest server response structure
const List<Vibe> availableVibes = [
  Vibe(
    id: 'rcYoqkpVIe242IUSR1u7',
    labelKey: 'vibe_chill',
    label: 'Relajado',
    icon: '😌',
    order: 1,
    color: Colors.teal,
    subCategories: [
      VibeSubCategory(labelKey: 'vibe_chill_lofi', label: 'Lofi', icon: '🎧'),
      VibeSubCategory(labelKey: 'vibe_chill_acoustic', label: 'Acústico', icon: '🎸'),
      VibeSubCategory(labelKey: 'vibe_chill_ambient', label: 'Ambiental', icon: '🌊'),
      VibeSubCategory(labelKey: 'vibe_chill_jazz', label: 'Jazz suave', icon: '🎷'),
      VibeSubCategory(labelKey: 'vibe_chill_nature', label: 'Naturaleza', icon: '🌿'),
      VibeSubCategory(labelKey: 'vibe_chill_piano', label: 'Piano', icon: '🎹'),
      VibeSubCategory(labelKey: 'vibe_chill_yoga', label: 'Yoga', icon: '🧘'),
    ],
  ),
];
