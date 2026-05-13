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

  @override
  String get vibe_chill => 'Relajado';

  @override
  String get vibe_energetic => 'Energético';

  @override
  String get vibe_party => 'Fiesta';

  @override
  String get vibe_romantic => 'Romántico';

  @override
  String get vibe_sad => 'Melancólico';

  @override
  String get vibe_focus => 'Concentración';

  @override
  String get vibe_happy => 'Alegre';

  @override
  String get vibe_latin => 'Latino';

  @override
  String get vibe_night => 'Noche';

  @override
  String get vibe_sleep => 'Dormir';

  @override
  String get vibe_chores => 'Tareas';

  @override
  String get vibe_gaming => 'Gaming';

  @override
  String get vibe_travel => 'Viaje';

  @override
  String get vibe_nostalgia => 'Nostalgia';

  @override
  String get vibe_chill_lofi => 'Lofi';

  @override
  String get vibe_chill_acoustic => 'Acústico';

  @override
  String get vibe_chill_ambient => 'Ambiental';

  @override
  String get vibe_chill_jazz => 'Jazz suave';

  @override
  String get vibe_chill_nature => 'Naturaleza';

  @override
  String get vibe_chill_piano => 'Piano';

  @override
  String get vibe_chill_yoga => 'Yoga';

  @override
  String get vibe_energetic_hiit => 'HIIT / Cardio';

  @override
  String get vibe_energetic_running => 'Correr';

  @override
  String get vibe_energetic_cycling => 'Ciclismo';

  @override
  String get vibe_energetic_sports => 'Deportes';

  @override
  String get vibe_energetic_dance => 'Baile';

  @override
  String get vibe_party_club => 'Club / Discoteca';

  @override
  String get vibe_party_birthday => 'Cumpleaños';

  @override
  String get vibe_party_babyshower => 'Baby shower';

  @override
  String get vibe_party_kids => 'Infantil';

  @override
  String get vibe_party_wedding => 'Boda';

  @override
  String get vibe_party_graduation => 'Graduación';

  @override
  String get vibe_party_bbq => 'Asado / BBQ';

  @override
  String get vibe_party_pregame => 'Previa';

  @override
  String get vibe_party_christmas => 'Navidad';

  @override
  String get vibe_party_halloween => 'Halloween';

  @override
  String get vibe_party_new_year => 'Año nuevo';

  @override
  String get vibe_romantic_date => 'Cita';

  @override
  String get vibe_romantic_ballad => 'Balada';

  @override
  String get vibe_romantic_wedding => 'Boda';

  @override
  String get vibe_romantic_anniversary => 'Aniversario';

  @override
  String get vibe_romantic_serenade => 'Serenata';

  @override
  String get vibe_sad_heartbreak => 'Desamor';

  @override
  String get vibe_sad_nostalgic => 'Nostálgico';

  @override
  String get vibe_sad_rainy => 'Día lluvioso';

  @override
  String get vibe_sad_lonely => 'Soledad';

  @override
  String get vibe_sad_cry => 'Para llorar';

  @override
  String get vibe_focus_study => 'Estudio';

  @override
  String get vibe_focus_work => 'Trabajo';

  @override
  String get vibe_focus_reading => 'Lectura';

  @override
  String get vibe_focus_coding => 'Programar';

  @override
  String get vibe_focus_meditation => 'Meditación';

  @override
  String get vibe_focus_deep_work => 'Trabajo profundo';

  @override
  String get vibe_happy_summer => 'Verano';

  @override
  String get vibe_happy_feel_good => 'Buen ánimo';

  @override
  String get vibe_happy_morning => 'Mañana positiva';

  @override
  String get vibe_happy_road_trip => 'Viaje en auto';

  @override
  String get vibe_happy_beach => 'Playa';

  @override
  String get vibe_happy_celebration => 'Celebración';

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
  String get vibe_latin_pop => 'Pop latino';

  @override
  String get vibe_latin_trap => 'Trap latino';

  @override
  String get vibe_night_late => 'Trasnoche';

  @override
  String get vibe_night_club => 'Club';

  @override
  String get vibe_night_chill => 'Noche tranquila';

  @override
  String get vibe_night_drive => 'Manejar de noche';

  @override
  String get vibe_night_rooftop => 'Terraza';

  @override
  String get vibe_sleep_deep => 'Sueño profundo';

  @override
  String get vibe_sleep_relax => 'Relajación';

  @override
  String get vibe_sleep_white_noise => 'Ruido blanco';

  @override
  String get vibe_sleep_baby => 'Para bebés';

  @override
  String get vibe_sleep_meditation => 'Meditación nocturna';

  @override
  String get vibe_chores_cleaning => 'Limpieza';

  @override
  String get vibe_chores_cooking => 'Cocinando';

  @override
  String get vibe_chores_laundry => 'Lavando ropa';

  @override
  String get vibe_chores_gardening => 'Jardín';

  @override
  String get vibe_chores_diy => 'Manualidades';

  @override
  String get vibe_gaming_rpg => 'RPG Ambiental';

  @override
  String get vibe_gaming_hype => 'Competitivo';

  @override
  String get vibe_gaming_retro => 'Retro 8-bit';

  @override
  String get vibe_travel_commute => 'Trayecto diario';

  @override
  String get vibe_travel_road_trip => 'Viaje en carretera';

  @override
  String get vibe_travel_flying => 'Volando';

  @override
  String get vibe_nostalgia_80s => 'Años 80';

  @override
  String get vibe_nostalgia_90s => 'Años 90';

  @override
  String get vibe_nostalgia_2000s => 'Años 2000';

  @override
  String get vibe_nostalgia_personal => 'Mi época';

  @override
  String get vibe_nostalgia_childhood => 'Infancia';
}
