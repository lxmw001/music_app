import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

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

  final List<int> _years = List.generate(80, (index) => DateTime.now().year - index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Fast Mode',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us a bit about yourself to personalize your AI vibes.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              const Text('When were you born?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Select Year'),
                items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                onChanged: (val) => setState(() => _selectedYear = val),
              ),

              const SizedBox(height: 32),
              const Text('Favorite Genres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genres.map((genre) {
                      final isSelected = _selectedGenres.contains(genre);
                      return FilterChip(
                        label: Text(genre),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedGenres.add(genre);
                            } else {
                              _selectedGenres.remove(genre);
                            }
                          });
                        },
                        selectedColor: Colors.green,
                        checkmarkColor: Colors.black,
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_selectedYear != null && _selectedGenres.isNotEmpty)
                    ? _saveAndContinue
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
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
