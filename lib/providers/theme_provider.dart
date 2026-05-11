import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModePreset { midnight, deepSea, forest, sunset, cyberpunk, oled }

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'accent_color';
  static const _adaptiveKey = 'is_adaptive';
  static const _presetKey = 'theme_preset';
  
  Color _accentColor = const Color(0xFF1DB954); // Default Spotify Green
  bool _isAdaptive = true; 
  ThemeModePreset _preset = ThemeModePreset.midnight;
  
  Color get accentColor => _accentColor;
  bool get isAdaptive => _isAdaptive;
  ThemeModePreset get preset => _preset;

  ThemeProvider() {
    _loadTheme();
  }

  void setAccentColor(Color color) async {
    _accentColor = color;
    _isAdaptive = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, color.value);
    await prefs.setBool(_adaptiveKey, false);
  }

  void setPreset(ThemeModePreset preset) async {
    _preset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, preset.name);
  }

  void toggleAdaptive(bool value) async {
    _isAdaptive = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adaptiveKey, value);
  }

  void updateAdaptiveColor(Color color) {
    if (_isAdaptive && _accentColor.value != color.value) {
      _accentColor = color;
      notifyListeners();
    }
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isAdaptive = prefs.getBool(_adaptiveKey) ?? true;
    final colorValue = prefs.getInt(_themeKey);
    if (colorValue != null && !_isAdaptive) {
      _accentColor = Color(colorValue);
    }
    final presetName = prefs.getString(_presetKey);
    if (presetName != null) {
      _preset = ThemeModePreset.values.firstWhere((e) => e.name == presetName, orElse: () => ThemeModePreset.midnight);
    }
    notifyListeners();
  }

  ThemeData getThemeData() {
    final Color surfaceColor;
    final Color backgroundColor;
    
    switch (_preset) {
      case ThemeModePreset.midnight:
        surfaceColor = const Color(0xFF121212);
        backgroundColor = Colors.black;
        break;
      case ThemeModePreset.deepSea:
        surfaceColor = const Color(0xFF0A192F);
        backgroundColor = const Color(0xFF020C1B);
        break;
      case ThemeModePreset.forest:
        surfaceColor = const Color(0xFF1A1F16);
        backgroundColor = const Color(0xFF0F140A);
        break;
      case ThemeModePreset.sunset:
        surfaceColor = const Color(0xFF1F1616);
        backgroundColor = const Color(0xFF140A0A);
        break;
      case ThemeModePreset.cyberpunk:
        surfaceColor = const Color(0xFF0D0221);
        backgroundColor = const Color(0xFF02010A);
        break;
      case ThemeModePreset.oled:
        surfaceColor = Colors.black;
        backgroundColor = Colors.black;
        break;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentColor,
        brightness: Brightness.dark,
        surface: surfaceColor,
        onSurface: Colors.white,
        primary: _accentColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: _accentColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static List<Color> get premiumPalette => [
    const Color(0xFF1DB954), // Green
    const Color(0xFF2196F3), // Blue
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFFF5722), // Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFFFFD700), // Gold
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFFFFFF), // White
  ];
}
