import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';
import 'gemini_service.dart';
import 'lastfm_service.dart';
import '../utils/safe_call.dart';
import 'audio_cache_service.dart';

/// Thin abstraction over YoutubeExplode to allow testing without real network calls.
abstract class YoutubeGateway {
  Future<List<Video>> search(String query, {int limit = 5});
  Future<String> getAudioUrl(String videoId);
  Future<Video> getVideo(String videoId);
  Future<({String playlistTitle, List<Video> videos})> getPlaylistVideos(String playlistId);
}

class YoutubeExplodeGateway implements YoutubeGateway {
  final YoutubeExplode _yt;
  YoutubeExplodeGateway({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  @override
  Future<List<Video>> search(String query, {int limit = 5}) async {
    final results = await _yt.search.search(query);
    return results.take(limit).toList();
  }

  @override
  Future<String> getAudioUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(
      videoId,
      ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
    );
    final streams = manifest.audioOnly.toList()
      ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
    return streams.first.url.toString();
  }

  @override
  Future<Video> getVideo(String videoId) => _yt.videos.get(videoId);

  @override
  Future<({String playlistTitle, List<Video> videos})> getPlaylistVideos(
      String playlistId) async {
    final playlist = await _yt.playlists.get(playlistId);
    final videos = await _yt.playlists.getVideos(playlistId).toList();
    return (playlistTitle: playlist.title, videos: videos);
  }
}

/// Clean a YouTube video title into "Song Title" format
/// removing noise like (Official Video), [HD], ft., etc.
String _cleanTitle(String raw) {
  var title = raw
      .replaceAll(RegExp(r'\((?:official|video|audio|lyrics|letra|hd|4k|mv|music video|visualizer|lyric video|clip oficial|videoclip)[^)]*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\[(?:official|video|audio|lyrics|letra|hd|4k|mv)[^\]]*\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*[\|｜]\s*.*$'), '') // remove everything after | 
      .replaceAll(RegExp(r'\s*//.*$'), '')         // remove everything after //
      .replaceAll(RegExp(r'\bft\.?\b|\bfeat\.?\b', caseSensitive: false), 'ft.')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  // Remove trailing punctuation
  title = title.replaceAll(RegExp(r'[\s\-_]+$'), '').trim();
  return title.isEmpty ? raw : title;
}

/// Extract artist from cleaned title if it follows "Artist - Song" pattern
String _extractArtistFromTitle(String cleanedTitle, String fallback) {
  if (cleanedTitle.contains(' - ')) {
    return cleanedTitle.split(' - ').first.trim();
  }
  return fallback;
}

/// Score a title — higher = cleaner. Prefers "Artist - Song" pattern.
int _titleScore(String title) {
  int score = 0;
  if (title.contains(' - ')) score += 10;           // has artist-song separator
  if (!title.contains('(')) score += 3;             // no parentheses noise
  if (!title.contains('[')) score += 2;             // no bracket noise
  if (RegExp(r'^[A-Za-záéíóúÁÉÍÓÚñÑüÜ\s\-]+$').hasMatch(title)) score += 2; // clean chars only
  score -= (title.length / 20).floor();             // penalize very long titles
  return score;
}

/// Deduplicate songs keeping the one with the cleanest title per unique song.
List<Song> _deduplicateSongs(List<Song> songs) {
  final Map<String, Song> best = {};
  for (final song in songs) {
    final titlePart = song.title.contains(' - ')
        ? song.title.split(' - ').last.trim().toLowerCase()
        : song.title.toLowerCase();
    // Key by title + artist to avoid same song from different artists
    final key = '${titlePart}|${song.artist.toLowerCase()}'
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü|]'), '').trim();
    if (!best.containsKey(key) || _titleScore(song.title) > _titleScore(best[key]!.title)) {
      best[key] = song;
    }
  }
  return best.values.toList();
}

Song _videoToSong(Video video, {String album = ''}) {
  final cleanedTitle = _cleanTitle(video.title);
  final artist = _extractArtistFromTitle(cleanedTitle, video.author);
  // Strip artist from title regardless of position (handles both "Artist - Song" and "Song - Artist")
  String songTitle = cleanedTitle;
  if (cleanedTitle.contains(' - ')) {
    final parts = cleanedTitle.split(' - ');
    final artistLower = artist.toLowerCase();
    if (parts.first.trim().toLowerCase() == artistLower) {
      songTitle = parts.skip(1).join(' - ').trim(); // Artist - Song
    } else if (parts.last.trim().toLowerCase() == artistLower) {
      songTitle = parts.take(parts.length - 1).join(' - ').trim(); // Song - Artist
    }
  }
  return Song(
    id: video.id.value,
    title: songTitle,
    artist: artist,
    album: album,
    imageUrl: video.thumbnails.highResUrl,
    audioUrl: '',
    duration: video.duration ?? Duration.zero,
  );
}

class YouTubeService {
  final YoutubeGateway _gateway;
  final http.Client _httpClient;
  final GeminiService _gemini;
  final AudioCacheService _audioCache = AudioCacheService();

  final LastFmService _lastFm;

  YouTubeService({YoutubeGateway? gateway, http.Client? httpClient, GeminiService? gemini, LastFmService? lastFm})
      : _gateway = gateway ?? YoutubeExplodeGateway(),
        _httpClient = httpClient ?? http.Client(),
        _gemini = gemini ?? GeminiService(),
        _lastFm = lastFm ?? LastFmService();

  Future<List<Song>> searchSongs(String query) =>
      safeCall(() async {
        // Get YouTube results first (single search)
        final videos = await _gateway.search(query, limit: 30);
        final ytSongs = _deduplicateSongs(videos.map(_videoToSong).toList());

        // Enrich with Last.fm metadata if available (no extra network calls)
        final lfmTracks = await _lastFm.searchTracks(query, limit: 50);
        if (lfmTracks.isEmpty) return ytSongs;

        // Enrich YouTube results with Last.fm metadata when matched, keep all results
        final enriched = ytSongs.map((song) {
          final match = lfmTracks.firstWhere(
            (t) => _titlesMatch(song.title, t.title) || _titlesMatch(song.artist, t.artist),
            orElse: () => (title: '', artist: '', imageUrl: ''),
          );
          if (match.title.isEmpty) return song; // no match — keep YouTube result as-is
          return Song(
            id: song.id,
            title: match.title,
            artist: match.artist,
            album: song.album,
            // imageUrl: match.imageUrl.isNotEmpty ? match.imageUrl : song.imageUrl,
            imageUrl: song.imageUrl,
            audioUrl: song.audioUrl,
            duration: song.duration,
          );
        }).toList();
        return _deduplicateSongs(enriched);
      }, [], tag: 'YouTubeService.searchSongs');

  bool _titlesMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final normalize = (String s) => s.toLowerCase().replaceAll(RegExp(r'[^\w\sáéíóúñü]'), '').trim();
    final na = normalize(a);
    final nb = normalize(b);
    if (na.contains(nb) || nb.contains(na)) return true;
    // Word overlap: at least 2 words in common
    final wordsA = na.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = nb.split(' ').where((w) => w.length > 2).toSet();
    return wordsA.intersection(wordsB).length >= 2;
  }

  Future<String> getAudioUrl(String videoId) =>
      safeCall(() => _gateway.getAudioUrl(videoId), '', tag: 'YouTubeService.getAudioUrl');

  Future<List<Song>> getTrendingMusic() =>
      safeCall(() async {
        final videos = await _gateway.search('regueton 2026', limit: 20);
        return _deduplicateSongs(videos.map(_videoToSong).toList());
      }, [], tag: 'YouTubeService.getTrendingMusic');

  Future<List<Song>> getPlaylistSongs(String playlistId) =>
      safeCall(() async {
        final result = await _gateway.getPlaylistVideos(playlistId);
        return result.videos.map((v) => _videoToSong(v, album: result.playlistTitle)).toList();
      }, [], tag: 'YouTubeService.getPlaylistSongs');

  Future<bool> testYouTubeConnectivity() =>
      safeCall(() async => (await _httpClient.get(Uri.parse('https://www.youtube.com'))).statusCode == 200, false);

  Future<SongMetadata?> getMetadata(String title) => _gemini.getSongMetadata(title);

  Future<List<Song>> searchByQuery(String query, {int maxResults = 20}) =>
      safeCall(() async {
        final videos = await _gateway.search(query, limit: maxResults);
        return _deduplicateSongs(videos.map(_videoToSong).toList());
      }, [], tag: 'YouTubeService.searchByQuery');

  Future<List<Song>> getSuggestedSongs(String videoId, {int maxResults = 5, String? knownTitle}) =>
      safeCall(() async {
        final title = knownTitle ?? (await _gateway.getVideo(videoId)).title;
        final metadata = await _gemini.getSongMetadata(title);
        final query = metadata?.randomQuery() ?? _extractSearchQuery(title, '');
        print('[YouTubeService] suggestions query: "$query"');
        final videos = await _gateway.search(query, limit: maxResults + 3);
        return videos
            .where((v) => v.id.value != videoId)
            .take(maxResults)
            .map(_videoToSong)
            .toList();
      }, [], tag: 'YouTubeService.getSuggestedSongs');

  /// Extract a meaningful search query from the video title.
  /// Most music titles follow "Artist - Song" or "Song - Artist" patterns.
  String _extractSearchQuery(String title, String channelAuthor) {
    // Remove common noise: (Official Video), [HD], etc.
    final cleaned = title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'official|video|audio|lyrics|hd|4k|ft\.?|feat\.?', caseSensitive: false), '')
        .trim();

    // If title contains " - ", the part before is likely the artist
    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      final artist = parts.first.trim();
      // Use artist name for broader suggestions
      return artist.isNotEmpty ? '$artist music' : cleaned;
    }

    // Fall back to first few words of the title (avoid full title = same song)
    final words = cleaned.split(' ').where((w) => w.isNotEmpty).take(4).join(' ');
    return words.isNotEmpty ? words : channelAuthor;
  }

  Future<List<Song>> getSuggestionsFromHistory(List<Song> likedSongs, {int maxResults = 10}) {
    if (likedSongs.isEmpty) return Future.value([]);
    return safeCall(() async {
      // Count plays per artist
      final artistCount = <String, int>{};
      for (final s in likedSongs) {
        artistCount[s.artist] = (artistCount[s.artist] ?? 0) + 1;
      }
      // Sort artists by play count, take top ones
      final topArtists = (artistCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .take(3)
          .toList();

      final likedIds = likedSongs.map((s) => s.id).toSet();
      final results = <Song>[];

      // Fetch suggestions for each artist proportionally
      for (final artist in topArtists) {
        final limit = (maxResults / topArtists.length).ceil();
        final videos = await _gateway.search(artist, limit: limit + 2);
        results.addAll(
          videos.where((v) => !likedIds.contains(v.id.value)).take(limit).map(_videoToSong),
        );
      }

      return (results..shuffle()).take(maxResults).toList();
    }, [], tag: 'YouTubeService.getSuggestionsFromHistory');
  }

  /// Returns a local file path to the cached audio, downloading if needed.
  Future<String> getCachedOrDownloadAudio(String videoId) async {
    final yt = _gateway is YoutubeExplodeGateway
        ? (_gateway as YoutubeExplodeGateway)._yt
        : YoutubeExplode();
    if (await _audioCache.isCached(videoId)) {
      return (await _audioCache.getCachedFile(videoId)).path;
    }
    return await _audioCache.downloadAndCacheAudio(videoId, yt);
  }

  /// Returns a local file path to the cached audio if available, otherwise fetches the online URL.
  Future<String> getPlayableAudioPath(String videoId) async {
    final cachedPath = await _audioCache.getCachedAudioPath(videoId);
    if (cachedPath != null) {
      print('[YouTubeService] Using cached audio for $videoId: $cachedPath');
      return cachedPath;
    }
    final url = await getAudioUrl(videoId);
    print('[YouTubeService] Using online audio URL for $videoId: $url');
    return url;
  }

  void dispose() {}
}
