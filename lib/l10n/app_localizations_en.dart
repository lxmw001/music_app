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
}
