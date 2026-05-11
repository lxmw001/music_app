import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const _profileKey = 'user_profile';

  Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(raw));
    } catch (_) {
      return UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<bool> isOnboarded() async {
    final profile = await getProfile();
    return profile.birthYear != null && profile.favoriteGenres.isNotEmpty;
  }
}
