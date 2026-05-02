// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Música';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get homeGreeting => 'Buenas noches';

  @override
  String get homeRecentlyPlayed => 'Reproducido recientemente';

  @override
  String get homeTrending => 'Música en tendencia';

  @override
  String get homeSuggested => 'Sugerido para ti';

  @override
  String get homeNoPlaylists =>
      'Sin listas aún. Busca una canción para generar una.';

  @override
  String get searchHint => 'Canciones, artistas, mezclas...';

  @override
  String get searchTabSongs => 'Canciones';

  @override
  String get searchTabMixes => 'Mezclas';

  @override
  String get searchTabArtists => 'Artistas';

  @override
  String get searchPopular => 'Búsquedas populares';

  @override
  String get searchBrowseGenre => 'Explorar por género';

  @override
  String get libraryTitle => 'Tu biblioteca';

  @override
  String get libraryLikedSongs => 'Canciones que te gustan';

  @override
  String get libraryDownloaded => 'Descargadas';

  @override
  String get libraryPlaylists => 'Listas de reproducción';

  @override
  String get libraryNoLiked => 'Aún no tienes canciones favoritas.';

  @override
  String get libraryNoDownloads =>
      'Sin canciones descargadas.\nToca ↓ en cualquier canción para descargar.';

  @override
  String get libraryPlayAll => 'Reproducir todo';

  @override
  String get playerNowPlaying => 'Reproduciendo';

  @override
  String get playerQueue => 'A continuación';

  @override
  String get playerLyrics => 'Letra';

  @override
  String get playerNoLyrics => 'No se encontró la letra.';

  @override
  String get updateAvailable => '¡Hay una nueva versión disponible!';

  @override
  String get updateButton => 'ACTUALIZAR';

  @override
  String get updateDismiss => 'IGNORAR';

  @override
  String updateDownloading(int percent) {
    return 'Descargando actualización... $percent%';
  }

  @override
  String get exitConfirm => 'Presiona atrás de nuevo para salir';

  @override
  String get connectivityTest => 'Probar conectividad con YouTube';

  @override
  String get connectivitySuccess =>
      'ÉXITO: El dispositivo puede acceder a YouTube.';

  @override
  String get connectivityFail =>
      'FALLO: El dispositivo no puede acceder a YouTube.';

  @override
  String get ok => 'OK';

  @override
  String songs(int count) {
    return '$count canciones';
  }
}
