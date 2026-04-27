import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_app/services/youtube_service.dart';
import 'package:music_app/services/lastfm_service.dart';
import 'package:music_app/models/music_models.dart';

/// Real-network integration tests for YouTube + Last.fm matching quality.
///
/// YouTube calls are intentionally minimal (2 searches) to avoid rate limiting.
/// Last.fm calls are free — key is injected at runtime:
///
///   flutter test integration_test/matching_test.dart -d &lt;device&gt; \
///     --dart-define=LASTFM_API_KEY=0fffe55280e74f07ec60ac7510483dbd
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late YouTubeService ytService;
  late LastFmService lfmService;

  // Shared YouTube results — fetched ONCE, reused across all tests.
  // Only 2 YouTube searches total to avoid triggering rate limits.
  late List<Song> ytEnglish; // "Taylor Swift Anti-Hero"
  late List<Song> ytSpanish; // "Bad Bunny"

  setUpAll(() async {
    ytService = YouTubeService();
    lfmService = LastFmService();
    ytEnglish = (await ytService.searchSongs('Taylor Swift Anti-Hero')).songs;
    ytSpanish = (await ytService.searchSongs('Bad Bunny')).songs;
  });

  // ─── YouTube structural quality ──────────────────────────────────────────

  group('YouTube result structure', () {
    test('English query returns non-empty results', () {
      expect(ytEnglish, isNotEmpty);
    });

    test('Spanish/artist-only query returns non-empty results', () {
      expect(ytSpanish, isNotEmpty);
    });

    test('every song has id, title, and artist', () {
      for (final s in [...ytEnglish, ...ytSpanish]) {
        expect(s.id, isNotEmpty);
        expect(s.title, isNotEmpty);
        expect(s.artist, isNotEmpty);
      }
    });

    test('no duplicate ids within a result set', () {
      final ids = ytEnglish.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // ─── Last.fm search quality ───────────────────────────────────────────────

  group('Last.fm track search', () {
    // Covers: artist+song, artist-only, song-only, single word, gibberish
    final queries = {
      'Taylor Swift Anti-Hero': true,  // expect results
      'Bad Bunny':              true,
      'Blinding Lights':        true,
      'despacito':              true,
      'xzqwerty12345notareal':  false, // expect empty
    };

    for (final entry in queries.entries) {
      test('query: "${entry.key}"', () async {
        final tracks = await lfmService.searchTracks(entry.key, limit: 10);
        debugPrint('\n[LFM search] "${entry.key}": ${tracks.length} results');
        for (final t in tracks.take(3)) {
          debugPrint('  "${t.title}" — ${t.artist}');
        }
        if (entry.value) {
          expect(tracks, isNotEmpty);
          for (final t in tracks) {
            expect(t.title, isNotEmpty);
            expect(t.artist, isNotEmpty);
          }
        } else {
          // gibberish — just verify it doesn't throw
          expect(tracks, isA<List>());
        }
      });
    }
  });

  // ─── Last.fm artist enrichment ────────────────────────────────────────────

  group('Last.fm artist top tracks', () {
    final artists = ['Taylor Swift', 'Bad Bunny', 'Queen'];

    for (final artist in artists) {
      test(artist, () async {
        final tracks = await lfmService.getArtistTopTracks(artist, limit: 5);
        debugPrint('\n[LFM top tracks] $artist: $tracks');
        expect(tracks, isNotEmpty);
        expect(tracks.every((t) => t.contains(artist) || t.isNotEmpty), isTrue);
      });
    }
  });

  group('Last.fm similar artists', () {
    final artists = ['Taylor Swift', 'Bad Bunny'];

    for (final artist in artists) {
      test(artist, () async {
        final similar = await lfmService.getSimilarArtists(artist, limit: 5);
        debugPrint('\n[LFM similar] $artist → $similar');
        expect(similar, isNotEmpty);
        expect(similar.every((a) => a.isNotEmpty), isTrue);
      });
    }
  });

  // ─── Combined matching quality ────────────────────────────────────────────

  group('YouTube + Last.fm enrichment match rate', () {
    test('English results: Taylor Swift Anti-Hero', () async {
      final lfm = await lfmService.searchTracks('Taylor Swift Anti-Hero', limit: 30);
      _printMatchReport('Taylor Swift Anti-Hero', ytEnglish, lfm);

      // At least 30% of YouTube results should find a Last.fm counterpart
      final rate = _matchRate(ytEnglish, lfm);
      expect(rate, greaterThanOrEqualTo(0.3),
          reason: 'Expected ≥30% match rate, got ${(rate * 100).toStringAsFixed(0)}%');
    });

    test('Spanish results: Bad Bunny', () async {
      final lfm = await lfmService.searchTracks('Bad Bunny', limit: 30);
      _printMatchReport('Bad Bunny', ytSpanish, lfm);

      final rate = _matchRate(ytSpanish, lfm);
      expect(rate, greaterThanOrEqualTo(0.2),
          reason: 'Expected ≥20% match rate, got ${(rate * 100).toStringAsFixed(0)}%');
    });
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

double _matchRate(List<Song> ytSongs, List<({String title, String artist, String imageUrl})> lfm) {
  if (ytSongs.isEmpty) return 0;
  int matched = 0;
  for (final s in ytSongs) {
    final hit = lfm.firstWhere(
      (t) => _match(s.title, t.title) || _match(s.artist, t.artist),
      orElse: () => (title: '', artist: '', imageUrl: ''),
    );
    if (hit.title.isNotEmpty) matched++;
  }
  return matched / ytSongs.length;
}

void _printMatchReport(String label, List<Song> ytSongs,
    List<({String title, String artist, String imageUrl})> lfm) {
  int matched = 0;
  debugPrint('\n=== Match report: "$label" ===');
  for (final s in ytSongs) {
    final hit = lfm.firstWhere(
      (t) => _match(s.title, t.title) || _match(s.artist, t.artist),
      orElse: () => (title: '', artist: '', imageUrl: ''),
    );
    if (hit.title.isNotEmpty) {
      matched++;
      debugPrint('  ✓ "${s.title}/${s.artist}" → "${hit.title}/${hit.artist}"');
    } else {
      debugPrint('  ✗ "${s.title}/${s.artist}"');
    }
  }
  debugPrint('  Result: $matched/${ytSongs.length} matched (${(matched / ytSongs.length * 100).toStringAsFixed(0)}%)');
}

String _normalizeStr(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\w\sáéíóúñü]'), '').trim();

bool _match(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  final na = _normalizeStr(a), nb = _normalizeStr(b);
  final shorter = na.length <= nb.length ? na : nb;
  final longer  = na.length <= nb.length ? nb : na;
  if (shorter.length > 3 && longer.contains(shorter)) return true;
  final wa = na.split(' ').where((w) => w.length > 2).toSet();
  final wb = nb.split(' ').where((w) => w.length > 2).toSet();
  return wa.intersection(wb).length >= 2;
}
