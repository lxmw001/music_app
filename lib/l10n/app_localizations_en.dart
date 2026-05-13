// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Music';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navLibrary => 'Library';

  @override
  String get homeGreeting => 'Good evening';

  @override
  String get homeRecentlyPlayed => 'Recently Played';

  @override
  String get homeTrending => 'Trending Music';

  @override
  String get homeSuggested => 'Suggested for You';

  @override
  String get homeNoPlaylists =>
      'No playlists yet. Search for a song to generate one.';

  @override
  String get searchHint => 'Songs, artists, mixes...';

  @override
  String get searchTabSongs => 'Songs';

  @override
  String get searchTabMixes => 'Mixes';

  @override
  String get searchTabArtists => 'Artists';

  @override
  String get searchPopular => 'Popular searches';

  @override
  String get searchBrowseGenre => 'Browse by genre';

  @override
  String get libraryTitle => 'Your Library';

  @override
  String get libraryLikedSongs => 'Liked Songs';

  @override
  String get libraryDownloaded => 'Downloaded';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryNoLiked => 'No liked songs yet.';

  @override
  String get libraryNoDownloads =>
      'No downloaded songs yet.\nTap ↓ on any song to download.';

  @override
  String get libraryPlayAll => 'Play All';

  @override
  String get playerNowPlaying => 'Now Playing';

  @override
  String get playerQueue => 'Up Next';

  @override
  String get playerLyrics => 'Lyrics';

  @override
  String get playerNoLyrics => 'No lyrics found.';

  @override
  String get updateAvailable => 'A new version is available!';

  @override
  String get updateButton => 'UPDATE';

  @override
  String get updateDismiss => 'DISMISS';

  @override
  String updateDownloading(int percent) {
    return 'Downloading update... $percent%';
  }

  @override
  String get exitConfirm => 'Press back again to exit';

  @override
  String get connectivityTest => 'Test YouTube Connectivity';

  @override
  String get connectivitySuccess => 'SUCCESS: Device can reach YouTube.';

  @override
  String get connectivityFail => 'FAILED: Device cannot reach YouTube.';

  @override
  String get ok => 'OK';

  @override
  String songs(int count) {
    return '$count songs';
  }

  @override
  String get vibe_chill => 'Chill';

  @override
  String get vibe_energetic => 'Energetic';

  @override
  String get vibe_party => 'Party';

  @override
  String get vibe_romantic => 'Romantic';

  @override
  String get vibe_sad => 'Melancholy';

  @override
  String get vibe_focus => 'Focus';

  @override
  String get vibe_happy => 'Happy';

  @override
  String get vibe_latin => 'Latin';

  @override
  String get vibe_night => 'Night';

  @override
  String get vibe_sleep => 'Sleep';

  @override
  String get vibe_chores => 'Chores';

  @override
  String get vibe_gaming => 'Gaming';

  @override
  String get vibe_travel => 'Travel';

  @override
  String get vibe_nostalgia => 'Nostalgia';

  @override
  String get vibe_chill_lofi => 'Lofi';

  @override
  String get vibe_chill_acoustic => 'Acoustic';

  @override
  String get vibe_chill_ambient => 'Ambient';

  @override
  String get vibe_chill_jazz => 'Smooth Jazz';

  @override
  String get vibe_chill_nature => 'Nature';

  @override
  String get vibe_chill_piano => 'Piano';

  @override
  String get vibe_chill_yoga => 'Yoga';

  @override
  String get vibe_energetic_hiit => 'HIIT / Cardio';

  @override
  String get vibe_energetic_running => 'Running';

  @override
  String get vibe_energetic_cycling => 'Cycling';

  @override
  String get vibe_energetic_sports => 'Sports';

  @override
  String get vibe_energetic_dance => 'Dance';

  @override
  String get vibe_party_club => 'Club';

  @override
  String get vibe_party_birthday => 'Birthday';

  @override
  String get vibe_party_babyshower => 'Baby Shower';

  @override
  String get vibe_party_kids => 'Kids';

  @override
  String get vibe_party_wedding => 'Wedding';

  @override
  String get vibe_party_graduation => 'Graduation';

  @override
  String get vibe_party_bbq => 'BBQ';

  @override
  String get vibe_party_pregame => 'Pregame';

  @override
  String get vibe_party_christmas => 'Christmas';

  @override
  String get vibe_party_halloween => 'Halloween';

  @override
  String get vibe_party_new_year => 'New Year';

  @override
  String get vibe_romantic_date => 'Date';

  @override
  String get vibe_romantic_ballad => 'Ballad';

  @override
  String get vibe_romantic_wedding => 'Wedding';

  @override
  String get vibe_romantic_anniversary => 'Anniversary';

  @override
  String get vibe_romantic_serenade => 'Serenade';

  @override
  String get vibe_sad_heartbreak => 'Heartbreak';

  @override
  String get vibe_sad_nostalgic => 'Nostalgic';

  @override
  String get vibe_sad_rainy => 'Rainy Day';

  @override
  String get vibe_sad_lonely => 'Loneliness';

  @override
  String get vibe_sad_cry => 'Cry';

  @override
  String get vibe_focus_study => 'Study';

  @override
  String get vibe_focus_work => 'Work';

  @override
  String get vibe_focus_reading => 'Reading';

  @override
  String get vibe_focus_coding => 'Coding';

  @override
  String get vibe_focus_meditation => 'Meditation';

  @override
  String get vibe_focus_deep_work => 'Deep Work';

  @override
  String get vibe_happy_summer => 'Summer';

  @override
  String get vibe_happy_feel_good => 'Feel Good';

  @override
  String get vibe_happy_morning => 'Morning';

  @override
  String get vibe_happy_road_trip => 'Road Trip';

  @override
  String get vibe_happy_beach => 'Beach';

  @override
  String get vibe_happy_celebration => 'Celebration';

  @override
  String get vibe_latin_reggaeton => 'Reggaeton';

  @override
  String get vibe_latin_salsa => 'Salsa';

  @override
  String get vibe_latin_cumbia => 'Cumbia';

  @override
  String get vibe_latin_bachata => 'Bachata';

  @override
  String get vibe_latin_merengue => 'Merengue';

  @override
  String get vibe_latin_vallenato => 'Vallenato';

  @override
  String get vibe_latin_pop => 'Latin Pop';

  @override
  String get vibe_latin_trap => 'Latin Trap';

  @override
  String get vibe_night_late => 'Late Night';

  @override
  String get vibe_night_club => 'Club';

  @override
  String get vibe_night_chill => 'Chill Night';

  @override
  String get vibe_night_drive => 'Night Drive';

  @override
  String get vibe_night_rooftop => 'Rooftop';

  @override
  String get vibe_sleep_deep => 'Deep Sleep';

  @override
  String get vibe_sleep_relax => 'Relax';

  @override
  String get vibe_sleep_white_noise => 'White Noise';

  @override
  String get vibe_sleep_baby => 'Baby';

  @override
  String get vibe_sleep_meditation => 'Meditation';

  @override
  String get vibe_chores_cleaning => 'Cleaning';

  @override
  String get vibe_chores_cooking => 'Cooking';

  @override
  String get vibe_chores_laundry => 'Laundry';

  @override
  String get vibe_chores_gardening => 'Gardening';

  @override
  String get vibe_chores_diy => 'DIY';

  @override
  String get vibe_gaming_rpg => 'RPG Ambient';

  @override
  String get vibe_gaming_hype => 'Competitive';

  @override
  String get vibe_gaming_retro => 'Retro 8-bit';

  @override
  String get vibe_travel_commute => 'Commute';

  @override
  String get vibe_travel_road_trip => 'Road Trip';

  @override
  String get vibe_travel_flying => 'Flying';

  @override
  String get vibe_nostalgia_80s => '80s';

  @override
  String get vibe_nostalgia_90s => '90s';

  @override
  String get vibe_nostalgia_2000s => '2000s';

  @override
  String get vibe_nostalgia_personal => 'My Era';

  @override
  String get vibe_nostalgia_childhood => 'Childhood';
}
