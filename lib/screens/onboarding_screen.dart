import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/mesh_gradient.dart';
import '../widgets/animated_list_item.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _profileService = ProfileService();
  int? _selectedYear;
  final List<String> _selectedGenres = [];

  final List<String> _genres = [
    'Rock', 'Pop', 'Hip Hop', 'Electronic', 'Jazz',
    'Classical', 'Lofi', 'Country', 'R&B', 'Metal',
    'Indie', 'Latin', 'Reggae', 'Blues'
  ];

  final List<int> _years = List.generate(60, (index) => DateTime.now().year - index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          const MeshGradient(color: Colors.blue), // Base aura
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Fast Mode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Personalize Your\nAI Vibe',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fast Mode uses AI to match music to your mood. Tell us a bit about you to sharpen the algorithm.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  _sectionHeader(l10n.onboardingBirthYear),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _years.length,
                      itemBuilder: (context, i) {
                        final year = _years[i];
                        final isSelected = _selectedYear == year;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(year.toString()),
                            selected: isSelected,
                            onSelected: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedYear = val ? year : null);
                            },
                            selectedColor: primary.withValues(alpha: 0.2),
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            labelStyle: TextStyle(
                              color: isSelected ? primary : Colors.white60,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                            ),
                            shape: StadiumBorder(side: BorderSide(color: isSelected ? primary : Colors.transparent)),
                            showCheckmark: false,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                  _sectionHeader(l10n.onboardingFavoriteGenres),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _genres.asMap().entries.map((entry) {
                          final i = entry.key;
                          final genre = entry.value;
                          final isSelected = _selectedGenres.contains(genre);
                          return AnimatedListItem(
                            index: i,
                            child: FilterChip(
                              label: Text(genre),
                              selected: isSelected,
                              onSelected: (selected) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (selected) {
                                    _selectedGenres.add(genre);
                                  } else {
                                    _selectedGenres.remove(genre);
                                  }
                                });
                              },
                              selectedColor: primary.withValues(alpha: 0.2),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              labelStyle: TextStyle(
                                color: isSelected ? primary : Colors.white60,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                              ),
                              checkmarkColor: primary,
                              shape: StadiumBorder(side: BorderSide(color: isSelected ? primary : Colors.transparent)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (_selectedYear != null && _selectedGenres.isNotEmpty)
                          BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_selectedYear != null && _selectedGenres.isNotEmpty)
                        ? _saveAndContinue
                        : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.onboardingGetStarted.toUpperCase(), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0)
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        color: Colors.white38,
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    HapticFeedback.heavyImpact();
    final profile = UserProfile(
      birthYear: _selectedYear,
      favoriteGenres: _selectedGenres,
    );
    await _profileService.saveProfile(profile);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
