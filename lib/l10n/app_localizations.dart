import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreeting;

  /// No description provided for @homeRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get homeRecentlyPlayed;

  /// No description provided for @homeTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending Music'**
  String get homeTrending;

  /// No description provided for @homeSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested for You'**
  String get homeSuggested;

  /// No description provided for @homeNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Search for a song to generate one.'**
  String get homeNoPlaylists;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Songs, artists, mixes...'**
  String get searchHint;

  /// No description provided for @searchTabSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get searchTabSongs;

  /// No description provided for @searchTabMixes.
  ///
  /// In en, this message translates to:
  /// **'Mixes'**
  String get searchTabMixes;

  /// No description provided for @searchTabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchTabArtists;

  /// No description provided for @searchPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular searches'**
  String get searchPopular;

  /// No description provided for @searchBrowseGenre.
  ///
  /// In en, this message translates to:
  /// **'Browse by genre'**
  String get searchBrowseGenre;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
  String get libraryTitle;

  /// No description provided for @libraryLikedSongs.
  ///
  /// In en, this message translates to:
  /// **'Liked Songs'**
  String get libraryLikedSongs;

  /// No description provided for @libraryDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get libraryDownloaded;

  /// No description provided for @libraryPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get libraryPlaylists;

  /// No description provided for @libraryNoLiked.
  ///
  /// In en, this message translates to:
  /// **'No liked songs yet.'**
  String get libraryNoLiked;

  /// No description provided for @libraryNoDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloaded songs yet.\nTap ↓ on any song to download.'**
  String get libraryNoDownloads;

  /// No description provided for @libraryPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get libraryPlayAll;

  /// No description provided for @playerNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get playerNowPlaying;

  /// No description provided for @playerQueue.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get playerQueue;

  /// No description provided for @playerLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get playerLyrics;

  /// No description provided for @playerNoLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found.'**
  String get playerNoLyrics;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A new version is available!'**
  String get updateAvailable;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get updateButton;

  /// No description provided for @updateDismiss.
  ///
  /// In en, this message translates to:
  /// **'DISMISS'**
  String get updateDismiss;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update... {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @exitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get exitConfirm;

  /// No description provided for @connectivityTest.
  ///
  /// In en, this message translates to:
  /// **'Test YouTube Connectivity'**
  String get connectivityTest;

  /// No description provided for @connectivitySuccess.
  ///
  /// In en, this message translates to:
  /// **'SUCCESS: Device can reach YouTube.'**
  String get connectivitySuccess;

  /// No description provided for @connectivityFail.
  ///
  /// In en, this message translates to:
  /// **'FAILED: Device cannot reach YouTube.'**
  String get connectivityFail;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songs(int count);

  /// No description provided for @vibe_chill.
  ///
  /// In en, this message translates to:
  /// **'Chill'**
  String get vibe_chill;

  /// No description provided for @vibe_energetic.
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get vibe_energetic;

  /// No description provided for @vibe_party.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get vibe_party;

  /// No description provided for @vibe_romantic.
  ///
  /// In en, this message translates to:
  /// **'Romantic'**
  String get vibe_romantic;

  /// No description provided for @vibe_sad.
  ///
  /// In en, this message translates to:
  /// **'Melancholy'**
  String get vibe_sad;

  /// No description provided for @vibe_focus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get vibe_focus;

  /// No description provided for @vibe_happy.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get vibe_happy;

  /// No description provided for @vibe_latin.
  ///
  /// In en, this message translates to:
  /// **'Latin'**
  String get vibe_latin;

  /// No description provided for @vibe_night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get vibe_night;

  /// No description provided for @vibe_sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get vibe_sleep;

  /// No description provided for @vibe_chores.
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get vibe_chores;

  /// No description provided for @vibe_gaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get vibe_gaming;

  /// No description provided for @vibe_travel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get vibe_travel;

  /// No description provided for @vibe_nostalgia.
  ///
  /// In en, this message translates to:
  /// **'Nostalgia'**
  String get vibe_nostalgia;

  /// No description provided for @vibe_chill_lofi.
  ///
  /// In en, this message translates to:
  /// **'Lofi'**
  String get vibe_chill_lofi;

  /// No description provided for @vibe_chill_acoustic.
  ///
  /// In en, this message translates to:
  /// **'Acoustic'**
  String get vibe_chill_acoustic;

  /// No description provided for @vibe_chill_ambient.
  ///
  /// In en, this message translates to:
  /// **'Ambient'**
  String get vibe_chill_ambient;

  /// No description provided for @vibe_chill_jazz.
  ///
  /// In en, this message translates to:
  /// **'Smooth Jazz'**
  String get vibe_chill_jazz;

  /// No description provided for @vibe_chill_nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get vibe_chill_nature;

  /// No description provided for @vibe_chill_piano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get vibe_chill_piano;

  /// No description provided for @vibe_chill_yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get vibe_chill_yoga;

  /// No description provided for @vibe_energetic_hiit.
  ///
  /// In en, this message translates to:
  /// **'HIIT / Cardio'**
  String get vibe_energetic_hiit;

  /// No description provided for @vibe_energetic_running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get vibe_energetic_running;

  /// No description provided for @vibe_energetic_cycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get vibe_energetic_cycling;

  /// No description provided for @vibe_energetic_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get vibe_energetic_sports;

  /// No description provided for @vibe_energetic_dance.
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get vibe_energetic_dance;

  /// No description provided for @vibe_party_club.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get vibe_party_club;

  /// No description provided for @vibe_party_birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get vibe_party_birthday;

  /// No description provided for @vibe_party_babyshower.
  ///
  /// In en, this message translates to:
  /// **'Baby Shower'**
  String get vibe_party_babyshower;

  /// No description provided for @vibe_party_kids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get vibe_party_kids;

  /// No description provided for @vibe_party_wedding.
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get vibe_party_wedding;

  /// No description provided for @vibe_party_graduation.
  ///
  /// In en, this message translates to:
  /// **'Graduation'**
  String get vibe_party_graduation;

  /// No description provided for @vibe_party_bbq.
  ///
  /// In en, this message translates to:
  /// **'BBQ'**
  String get vibe_party_bbq;

  /// No description provided for @vibe_party_pregame.
  ///
  /// In en, this message translates to:
  /// **'Pregame'**
  String get vibe_party_pregame;

  /// No description provided for @vibe_party_christmas.
  ///
  /// In en, this message translates to:
  /// **'Christmas'**
  String get vibe_party_christmas;

  /// No description provided for @vibe_party_halloween.
  ///
  /// In en, this message translates to:
  /// **'Halloween'**
  String get vibe_party_halloween;

  /// No description provided for @vibe_party_new_year.
  ///
  /// In en, this message translates to:
  /// **'New Year'**
  String get vibe_party_new_year;

  /// No description provided for @vibe_romantic_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get vibe_romantic_date;

  /// No description provided for @vibe_romantic_ballad.
  ///
  /// In en, this message translates to:
  /// **'Ballad'**
  String get vibe_romantic_ballad;

  /// No description provided for @vibe_romantic_wedding.
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get vibe_romantic_wedding;

  /// No description provided for @vibe_romantic_anniversary.
  ///
  /// In en, this message translates to:
  /// **'Anniversary'**
  String get vibe_romantic_anniversary;

  /// No description provided for @vibe_romantic_serenade.
  ///
  /// In en, this message translates to:
  /// **'Serenade'**
  String get vibe_romantic_serenade;

  /// No description provided for @vibe_sad_heartbreak.
  ///
  /// In en, this message translates to:
  /// **'Heartbreak'**
  String get vibe_sad_heartbreak;

  /// No description provided for @vibe_sad_nostalgic.
  ///
  /// In en, this message translates to:
  /// **'Nostalgic'**
  String get vibe_sad_nostalgic;

  /// No description provided for @vibe_sad_rainy.
  ///
  /// In en, this message translates to:
  /// **'Rainy Day'**
  String get vibe_sad_rainy;

  /// No description provided for @vibe_sad_lonely.
  ///
  /// In en, this message translates to:
  /// **'Loneliness'**
  String get vibe_sad_lonely;

  /// No description provided for @vibe_sad_cry.
  ///
  /// In en, this message translates to:
  /// **'Cry'**
  String get vibe_sad_cry;

  /// No description provided for @vibe_focus_study.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get vibe_focus_study;

  /// No description provided for @vibe_focus_work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get vibe_focus_work;

  /// No description provided for @vibe_focus_reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get vibe_focus_reading;

  /// No description provided for @vibe_focus_coding.
  ///
  /// In en, this message translates to:
  /// **'Coding'**
  String get vibe_focus_coding;

  /// No description provided for @vibe_focus_meditation.
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get vibe_focus_meditation;

  /// No description provided for @vibe_focus_deep_work.
  ///
  /// In en, this message translates to:
  /// **'Deep Work'**
  String get vibe_focus_deep_work;

  /// No description provided for @vibe_happy_summer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get vibe_happy_summer;

  /// No description provided for @vibe_happy_feel_good.
  ///
  /// In en, this message translates to:
  /// **'Feel Good'**
  String get vibe_happy_feel_good;

  /// No description provided for @vibe_happy_morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get vibe_happy_morning;

  /// No description provided for @vibe_happy_road_trip.
  ///
  /// In en, this message translates to:
  /// **'Road Trip'**
  String get vibe_happy_road_trip;

  /// No description provided for @vibe_happy_beach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get vibe_happy_beach;

  /// No description provided for @vibe_happy_celebration.
  ///
  /// In en, this message translates to:
  /// **'Celebration'**
  String get vibe_happy_celebration;

  /// No description provided for @vibe_latin_reggaeton.
  ///
  /// In en, this message translates to:
  /// **'Reggaeton'**
  String get vibe_latin_reggaeton;

  /// No description provided for @vibe_latin_salsa.
  ///
  /// In en, this message translates to:
  /// **'Salsa'**
  String get vibe_latin_salsa;

  /// No description provided for @vibe_latin_cumbia.
  ///
  /// In en, this message translates to:
  /// **'Cumbia'**
  String get vibe_latin_cumbia;

  /// No description provided for @vibe_latin_bachata.
  ///
  /// In en, this message translates to:
  /// **'Bachata'**
  String get vibe_latin_bachata;

  /// No description provided for @vibe_latin_merengue.
  ///
  /// In en, this message translates to:
  /// **'Merengue'**
  String get vibe_latin_merengue;

  /// No description provided for @vibe_latin_vallenato.
  ///
  /// In en, this message translates to:
  /// **'Vallenato'**
  String get vibe_latin_vallenato;

  /// No description provided for @vibe_latin_pop.
  ///
  /// In en, this message translates to:
  /// **'Latin Pop'**
  String get vibe_latin_pop;

  /// No description provided for @vibe_latin_trap.
  ///
  /// In en, this message translates to:
  /// **'Latin Trap'**
  String get vibe_latin_trap;

  /// No description provided for @vibe_night_late.
  ///
  /// In en, this message translates to:
  /// **'Late Night'**
  String get vibe_night_late;

  /// No description provided for @vibe_night_club.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get vibe_night_club;

  /// No description provided for @vibe_night_chill.
  ///
  /// In en, this message translates to:
  /// **'Chill Night'**
  String get vibe_night_chill;

  /// No description provided for @vibe_night_drive.
  ///
  /// In en, this message translates to:
  /// **'Night Drive'**
  String get vibe_night_drive;

  /// No description provided for @vibe_night_rooftop.
  ///
  /// In en, this message translates to:
  /// **'Rooftop'**
  String get vibe_night_rooftop;

  /// No description provided for @vibe_sleep_deep.
  ///
  /// In en, this message translates to:
  /// **'Deep Sleep'**
  String get vibe_sleep_deep;

  /// No description provided for @vibe_sleep_relax.
  ///
  /// In en, this message translates to:
  /// **'Relax'**
  String get vibe_sleep_relax;

  /// No description provided for @vibe_sleep_white_noise.
  ///
  /// In en, this message translates to:
  /// **'White Noise'**
  String get vibe_sleep_white_noise;

  /// No description provided for @vibe_sleep_baby.
  ///
  /// In en, this message translates to:
  /// **'Baby'**
  String get vibe_sleep_baby;

  /// No description provided for @vibe_sleep_meditation.
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get vibe_sleep_meditation;

  /// No description provided for @vibe_chores_cleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get vibe_chores_cleaning;

  /// No description provided for @vibe_chores_cooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get vibe_chores_cooking;

  /// No description provided for @vibe_chores_laundry.
  ///
  /// In en, this message translates to:
  /// **'Laundry'**
  String get vibe_chores_laundry;

  /// No description provided for @vibe_chores_gardening.
  ///
  /// In en, this message translates to:
  /// **'Gardening'**
  String get vibe_chores_gardening;

  /// No description provided for @vibe_chores_diy.
  ///
  /// In en, this message translates to:
  /// **'DIY'**
  String get vibe_chores_diy;

  /// No description provided for @vibe_gaming_rpg.
  ///
  /// In en, this message translates to:
  /// **'RPG Ambient'**
  String get vibe_gaming_rpg;

  /// No description provided for @vibe_gaming_hype.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get vibe_gaming_hype;

  /// No description provided for @vibe_gaming_retro.
  ///
  /// In en, this message translates to:
  /// **'Retro 8-bit'**
  String get vibe_gaming_retro;

  /// No description provided for @vibe_travel_commute.
  ///
  /// In en, this message translates to:
  /// **'Commute'**
  String get vibe_travel_commute;

  /// No description provided for @vibe_travel_road_trip.
  ///
  /// In en, this message translates to:
  /// **'Road Trip'**
  String get vibe_travel_road_trip;

  /// No description provided for @vibe_travel_flying.
  ///
  /// In en, this message translates to:
  /// **'Flying'**
  String get vibe_travel_flying;

  /// No description provided for @vibe_nostalgia_80s.
  ///
  /// In en, this message translates to:
  /// **'80s'**
  String get vibe_nostalgia_80s;

  /// No description provided for @vibe_nostalgia_90s.
  ///
  /// In en, this message translates to:
  /// **'90s'**
  String get vibe_nostalgia_90s;

  /// No description provided for @vibe_nostalgia_2000s.
  ///
  /// In en, this message translates to:
  /// **'2000s'**
  String get vibe_nostalgia_2000s;

  /// No description provided for @vibe_nostalgia_personal.
  ///
  /// In en, this message translates to:
  /// **'My Era'**
  String get vibe_nostalgia_personal;

  /// No description provided for @vibe_nostalgia_childhood.
  ///
  /// In en, this message translates to:
  /// **'Childhood'**
  String get vibe_nostalgia_childhood;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
