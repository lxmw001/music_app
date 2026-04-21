import 'package:flutter_test/flutter_test.dart';

// Mirrors the private functions from youtube_service.dart for isolated testing.
// If those functions are ever made public/exported, replace these with direct imports.

String cleanTitle(String raw) {
  var title = raw
      .replaceAll(RegExp(r'\((?:official|video|audio|lyrics|letra|hd|4k|mv|music video|visualizer|lyric video|clip oficial|videoclip)[^)]*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[(?:official|video|audio|lyrics|letra|hd|4k|mv)[^\]]*\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*[\|｜]\s*.*$'), '')
      .replaceAll(RegExp(r'\s*//.*$'), '')
      .replaceAll(RegExp(r'\bft\.?\b|\bfeat\.?\b', caseSensitive: false), 'ft.')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  title = title.replaceAll(RegExp(r'[\s\-_]+$'), '').trim();
  return title.isEmpty ? raw : title;
}

String extractArtist(String cleanedTitle, String channelAuthor) {
  if (!cleanedTitle.contains(' - ')) return channelAuthor;

  final parts = cleanedTitle.split(' - ');
  final first = parts.first.trim();
  final last  = parts.last.trim();
  final channel = channelAuthor.toLowerCase()
      .replaceAll(RegExp(r'\s*(vevo|official|music|records|tv)$', caseSensitive: false), '')
      .trim();

  if (channel.contains(first.toLowerCase()) || first.toLowerCase().contains(channel)) return first;
  if (channel.contains(last.toLowerCase()) || last.toLowerCase().contains(channel)) return last;

  final songWords = RegExp(
    r'\b(de|la|el|los|las|mi|tu|su|amor|vida|corazon|heart|love|night|day|time|way|world|huella|quiero|eres|para)\b',
    caseSensitive: false,
  );
  final firstSongScore = songWords.allMatches(first.toLowerCase()).length;
  final lastSongScore  = songWords.allMatches(last.toLowerCase()).length;
  if (lastSongScore > firstSongScore) return first;
  if (firstSongScore > lastSongScore) return last;

  return first;
}

String stripArtistFromTitle(String title, String artist) {
  final lower = title.toLowerCase();
  final artistLower = artist.toLowerCase();
  final separators = [' - ', ' – ', '–', ' -', '- '];
  for (final sep in separators) {
    if (lower.startsWith('$artistLower$sep')) {
      return title.substring(artistLower.length + sep.length).trim();
    }
    if (lower.endsWith('$sep$artistLower')) {
      return title.substring(0, title.length - sep.length - artistLower.length).trim();
    }
  }
  return title;
}

bool titlesMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  final normalize = (String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\w\sáéíóúñü]'), '').trim();
  final na = normalize(a);
  final nb = normalize(b);
  final shorter = na.length <= nb.length ? na : nb;
  final longer  = na.length <= nb.length ? nb : na;
  if (shorter.length > 3 && longer.contains(shorter)) return true;
  final wordsA = na.split(' ').where((w) => w.length > 2).toSet();
  final wordsB = nb.split(' ').where((w) => w.length > 2).toSet();
  return wordsA.intersection(wordsB).length >= 2;
}

void main() {
  group('cleanTitle', () {
    // Artist - Song (standard)
    test('Artist - Song stays intact', () {
      expect(cleanTitle('Queen - Bohemian Rhapsody'), 'Queen - Bohemian Rhapsody');
    });

    // Song - Artist (reversed)
    test('Song - Artist stays intact', () {
      expect(cleanTitle('Bohemian Rhapsody - Queen'), 'Bohemian Rhapsody - Queen');
    });

    // With noise in parens
    test('Artist - Song (Official Video) strips parens noise', () {
      expect(cleanTitle('Queen - Bohemian Rhapsody (Official Video)'), 'Queen - Bohemian Rhapsody');
    });

    test('Artist - Song [HD] strips bracket noise', () {
      expect(cleanTitle('Queen - Bohemian Rhapsody [HD]'), 'Queen - Bohemian Rhapsody');
    });

    // Song only (no artist)
    test('Song only — no separator', () {
      expect(cleanTitle('Bohemian Rhapsody (Official Audio)'), 'Bohemian Rhapsody');
    });

    // Artist - Song ft. feature
    test('feat. normalized to ft.', () {
      final result = cleanTitle('Drake - Passionfruit feat. PartyNextDoor');
      expect(result, contains('ft.'));
    });

    // Pipe separator
    test('everything after | is removed', () {
      expect(cleanTitle('Bad Bunny - Tití Me Preguntó | Official'), 'Bad Bunny - Tití Me Preguntó');
    });

    // Double slash
    test('everything after // is removed', () {
      expect(cleanTitle('Dua Lipa - Levitating // Lyrics'), 'Dua Lipa - Levitating');
    });

    // Mix / DJ set title
    test('Mix title with no separator stays as-is', () {
      final result = cleanTitle('Top Hits 2024 Mix (Official Playlist)');
      expect(result, isNotEmpty);
      expect(result, isNot(contains('Official')));
    });

    // Empty / whitespace
    test('empty string returns empty', () {
      expect(cleanTitle(''), '');
    });

    // Trailing dash
    test('trailing dash is removed', () {
      final result = cleanTitle('Taylor Swift - Anti-Hero -');
      expect(result, isNot(endsWith('-')));
    });
  });

  group('extractArtist', () {
    test('Artist - Song, channel matches artist → returns artist', () {
      expect(extractArtist('Grupo Firme - La huella de tu amor', 'Grupo Firme VEVO'), 'Grupo Firme');
    });

    test('Song - Artist, channel matches last segment → returns last as artist', () {
      expect(extractArtist('La huella de tu amor - Grupo Firme', 'Grupo Firme VEVO'), 'Grupo Firme');
    });

    test('Song - Artist, heuristic: song words in first segment', () {
      // "La huella de tu amor" has song words (de, tu, amor) → first is song → last is artist
      expect(extractArtist('La huella de tu amor - Grupo Firme', 'Unknown Channel'), 'Grupo Firme');
    });

    test('Artist - Song, heuristic: song words in last segment', () {
      // "Amor de mi vida" has song words → last is song → first is artist
      expect(extractArtist('Grupo Firme - Amor de mi vida', 'Unknown Channel'), 'Grupo Firme');
    });

    test('No separator → returns channel author', () {
      expect(extractArtist('Bohemian Rhapsody', 'Queen'), 'Queen');
    });

    test('Channel with VEVO suffix stripped before matching', () {
      expect(extractArtist('Queen - Bohemian Rhapsody', 'QueenVEVO'), 'Queen');
    });

    test('Multi-dash: Taylor Swift - Anti-Hero → first segment is artist', () {
      expect(extractArtist('Taylor Swift - Anti-Hero', 'Taylor Swift'), 'Taylor Swift');
    });

    test('Empty title → returns channel author', () {
      expect(extractArtist('', 'Grupo Firme'), 'Grupo Firme');
    });
  });

  group('stripArtistFromTitle', () {
    test('Artist - Song → returns song', () {
      expect(stripArtistFromTitle('Queen - Bohemian Rhapsody', 'Queen'), 'Bohemian Rhapsody');
    });

    test('Song - Artist → returns song', () {
      expect(stripArtistFromTitle('Bohemian Rhapsody - Queen', 'Queen'), 'Bohemian Rhapsody');
    });

    test('No artist in title → returns title unchanged', () {
      expect(stripArtistFromTitle('Bohemian Rhapsody', 'Queen'), 'Bohemian Rhapsody');
    });

    test('Artist - Song ft. feature → song part preserved', () {
      final result = stripArtistFromTitle('Drake - Passionfruit ft. PartyNextDoor', 'Drake');
      expect(result, contains('Passionfruit'));
    });

    test('Case-insensitive match', () {
      expect(stripArtistFromTitle('QUEEN - Bohemian Rhapsody', 'Queen'), 'Bohemian Rhapsody');
    });

    test('En-dash separator', () {
      expect(stripArtistFromTitle('Queen–Bohemian Rhapsody', 'Queen'), 'Bohemian Rhapsody');
    });
  });

  group('titlesMatch', () {
    // Exact
    test('identical strings match', () {
      expect(titlesMatch('Bohemian Rhapsody', 'Bohemian Rhapsody'), isTrue);
    });

    // Case insensitive
    test('case-insensitive match', () {
      expect(titlesMatch('bohemian rhapsody', 'Bohemian Rhapsody'), isTrue);
    });

    // Substring
    test('one contains the other', () {
      expect(titlesMatch('Bohemian Rhapsody', 'Bohemian Rhapsody (Remaster)'), isTrue);
    });

    // Word overlap ≥ 2
    test('2+ shared words match', () {
      expect(titlesMatch('Blinding Lights The Weeknd', 'The Weeknd Blinding Lights'), isTrue);
    });

    // Artist - Song vs Song only
    test('Artist - Song vs Song only matches via word overlap', () {
      expect(titlesMatch('Queen - Bohemian Rhapsody', 'Bohemian Rhapsody'), isTrue);
    });

    // Song - Artist vs Artist only
    test('Song - Artist vs artist name matches', () {
      expect(titlesMatch('Bohemian Rhapsody - Queen', 'Queen'), isTrue);
    });

    // No match
    test('completely different strings do not match', () {
      expect(titlesMatch('Bohemian Rhapsody', 'Blinding Lights'), isFalse);
    });

    // Empty
    test('empty string never matches', () {
      expect(titlesMatch('', 'Bohemian Rhapsody'), isFalse);
      expect(titlesMatch('Bohemian Rhapsody', ''), isFalse);
    });

    // Short words — "la la" (4 chars) is a substring of "la la land", so it matches.
    // This is a known limitation: very short repeated words can cause false positives.
    test('short repeated words can match via substring (known limitation)', () {
      expect(titlesMatch('La La', 'La La Land'), isTrue); // "la la" ⊂ "la la land"
    });

    // Spanish / accented
    test('accented characters match', () {
      expect(titlesMatch('Tití Me Preguntó', 'Tití Me Preguntó'), isTrue);
    });

    // Mix title vs song
    test('mix title does not falsely match unrelated song', () {
      expect(titlesMatch('Top Hits 2024 Mix', 'Bohemian Rhapsody'), isFalse);
    });
  });

  group('full pipeline: cleanTitle → extractArtist → stripArtistFromTitle', () {
    ({String title, String artist}) parse(String raw, String channelAuthor) {
      final cleaned = cleanTitle(raw);
      final artist = extractArtist(cleaned, channelAuthor);
      final title = cleaned.contains(' - ')
          ? stripArtistFromTitle(cleaned, artist)
          : cleaned;
      return (title: title, artist: artist);
    }

    test('Artist - Song (Official Video)', () {
      final r = parse('Queen - Bohemian Rhapsody (Official Video)', 'Queen');
      expect(r.artist, 'Queen');
      expect(r.title, 'Bohemian Rhapsody');
    });

    test('Song - Artist [HD] — channel resolves correct artist', () {
      final r = parse('Bohemian Rhapsody - Queen [HD]', 'QueenVEVO');
      expect(r.artist, 'Queen');
      expect(r.title, 'Bohemian Rhapsody');
    });

    test('Song only, no separator', () {
      final r = parse('Bohemian Rhapsody (Official Audio)', 'Queen');
      expect(r.artist, 'Queen');
      expect(r.title, 'Bohemian Rhapsody');
    });

    test('Artist - Song ft. feature', () {
      final r = parse('Drake - Passionfruit feat. PartyNextDoor (Official)', 'Drake');
      expect(r.artist, 'Drake');
      expect(r.title, contains('Passionfruit'));
    });

    test('Artist - Multi-word Song', () {
      final r = parse('Taylor Swift - Anti-Hero (Official Music Video)', 'Taylor Swift');
      expect(r.artist, 'Taylor Swift');
      expect(r.title, contains('Anti-Hero'));
    });

    test('Spanish Song - Artist (the original bug)', () {
      final r = parse('La huella de tu amor - Grupo Firme', 'Grupo Firme VEVO');
      expect(r.artist, 'Grupo Firme');
      expect(r.title, 'La huella de tu amor');
    });

    test('Spanish Song - Artist, unknown channel (heuristic)', () {
      final r = parse('La huella de tu amor - Grupo Firme', 'Unknown Channel');
      expect(r.artist, 'Grupo Firme');
      expect(r.title, 'La huella de tu amor');
    });

    test('Spanish: Artist - Song with accents', () {
      final r = parse('Bad Bunny - Tití Me Preguntó | Official Video', 'Bad Bunny');
      expect(r.artist, 'Bad Bunny');
      expect(r.title, contains('Tití'));
    });

    test('Mix title — no separator, channel as artist', () {
      final r = parse('Top Hits 2024 Mix (Official Playlist)', 'Various Artists');
      expect(r.artist, 'Various Artists');
      expect(r.title, isNotEmpty);
    });
  });
}
