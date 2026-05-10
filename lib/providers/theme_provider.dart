import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'accent_color';
  
  Color _accentColor = const Color(0xFF1DB954); // Default Spotify Green
  
  Color get accentColor => _accentColor;

  ThemeProvider() {
    _loadTheme();
  }

  void setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, color.value);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_themeKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
      notifyListeners();
    }
  }

  static List<Color> get premiumPalette => [
    const Color(0xFF1DB954), // Green
    const Color(0xFF2196F3), // Blue
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFFF5722), // Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFFFFD700), // Gold
    const Color(0xFF00BCD4), // Cyan
  ];
}
