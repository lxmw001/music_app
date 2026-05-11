class UserProfile {
  final int? birthYear;
  final List<String> favoriteGenres;
  final String? activityLevel; // e.g., 'high', 'low', 'moderate'
  final bool isPremium;

  UserProfile({
    this.birthYear,
    this.favoriteGenres = const [],
    this.activityLevel,
    this.isPremium = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      birthYear: json['birthYear'] as int?,
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      activityLevel: json['activityLevel'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'birthYear': birthYear,
    'favoriteGenres': favoriteGenres,
    'activityLevel': activityLevel,
    'isPremium': isPremium,
  };

  UserProfile copyWith({
    int? birthYear,
    List<String>? favoriteGenres,
    String? activityLevel,
    bool? isPremium,
  }) {
    return UserProfile(
      birthYear: birthYear ?? this.birthYear,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      activityLevel: activityLevel ?? this.activityLevel,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
