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
