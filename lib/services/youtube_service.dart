import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';
import 'gemini_service.dart';
import 'lastfm_service.dart';
import '../utils/safe_call.dart';
import 'audio_cache_service.dart';
import 'download_service.dart';
import 'music_server_service.dart';
import 'stream_url_cache.dart';

/// Thin abstraction over YoutubeExplode to allow testing without real network calls.
abstract class YoutubeGateway {
  Future<List<Video>> search(String query, {int limit = 5});
  Future<String> getAudioUrl(String videoId);
  Future<Video> getVideo(String videoId);
  Future<({String playlistTitle, List<Video> videos})> getPlaylistVideos(String playlistId);
}

class YoutubeExplodeGateway implements YoutubeGateway {
  YoutubeExplode _yt;
  YoutubeExplodeGateway({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  @override
  Future<List<Video>> search(String query, {int limit = 5}) async {
    final results = await _yt.search.search(query);
    return results.take(limit).toList();
  }

  @override
  Future<String> getAudioUrl(String videoId) async {
    final clients = [
      YoutubeApiClient.ios,
      YoutubeApiClient.tv,
      YoutubeApiClient.androidVr,
      YoutubeApiClient.safari,
    ];
    String? opusFallback; // best Opus URL found if no AAC available

    for (final client in clients) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: [client])
            .timeout(const Duration(seconds: 5));
        final streams = manifest.audioOnly.toList();
        if (streams.isEmpty) continue;

        final aac = streams.where((s) =>
            s.codec.mimeType.contains('mp4a') || s.container.name == 'mp4').toList();
        if (aac.isNotEmpty) {
          aac.sort((a, b) => b.bitrate.compareTo(a.bitrate));
          print('[YoutubeGateway] $client AAC succeeded for $videoId');
          return aac.first.url.toString();
        }
        // No AAC — save as Opus fallback and try next client
        if (opusFallback == null) {
          streams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
          opusFallback = streams.first.url.toString();
        }
      } catch (e) {
        print('[YoutubeGateway] $client failed: $e');
        if (e.toString().contains('RequestLimitExceeded')) {
          _yt.close();
          _yt = YoutubeExplode();
          break;
        }
      }
    }
    if (opusFallback != null) {
      print('[YoutubeGateway] using Opus fallback for $videoId');
      return opusFallback;
    }
    throw Exception('All YouTube clients failed for $videoId');
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

/// Extract artist from cleaned title, using the channel name to resolve
/// "Artist - Song" vs "Song - Artist" ambiguity.
String _extractArtistFromTitle(String cleanedTitle, String channelAuthor) {
  if (!cleanedTitle.contains(' - ')) return channelAuthor;

  final parts = cleanedTitle.split(' - ');
  final first = parts.first.trim();
  final last  = parts.last.trim();
  final channel = channelAuthor.toLowerCase()
      .replaceAll(RegExp(r'\s*(vevo|official|music|records|tv)$', caseSensitive: false), '')
      .trim();

  // If the channel name matches the first segment → Artist - Song
  if (channel.contains(first.toLowerCase()) || first.toLowerCase().contains(channel)) {
    return first;
  }
  // If the channel name matches the last segment → Song - Artist
  if (channel.contains(last.toLowerCase()) || last.toLowerCase().contains(channel)) {
    return last;
  }
  // Heuristic: song titles are more likely to contain common words
  final songWords = RegExp(
    r'\b(de|la|el|los|las|mi|tu|su|amor|vida|corazon|heart|love|night|day|time|way|world|huella|quiero|eres|para)\b',
    caseSensitive: false,
  );
  final firstSongScore = songWords.allMatches(first.toLowerCase()).length;
  final lastSongScore  = songWords.allMatches(last.toLowerCase()).length;
  if (lastSongScore > firstSongScore) return first; // last looks like song → first is artist
  if (firstSongScore > lastSongScore) return last;  // first looks like song → last is artist

  // Default: assume Artist - Song
  return first;
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
  final MusicServerService _server;
  final StreamUrlCache _streamUrlCache = StreamUrlCache();
  late final DownloadService _downloadService;

  YouTubeService({YoutubeGateway? gateway, http.Client? httpClient, GeminiService? gemini, LastFmService? lastFm, DownloadService? downloadService, MusicServerService? server})
      : _gateway = gateway ?? YoutubeExplodeGateway(),
        _httpClient = httpClient ?? http.Client(),
        _gemini = gemini ?? GeminiService(),
        _lastFm = lastFm ?? LastFmService(),
        _server = server ?? MusicServerService() {
    _downloadService = downloadService ?? DownloadService();
  }

  Future<MusicSearchResult> searchSongs(String query) =>
      safeCall(() async {
        final result = await _server.searchSongs(query);
        if (!result.isEmpty) return result;

        print('[YouTubeService] server empty, using YouTube fallback');
        final songs = await _youtubeSearch(query);
        return MusicSearchResult(songs: songs);
      }, const MusicSearchResult(), tag: 'YouTubeService.searchSongs');

  Future<List<Song>> _youtubeSearch(String query) async {
    final videos = await _gateway.search(query, limit: 30);
    final ytSongs = _deduplicateSongs(videos.map(_videoToSong).toList());
    print('[YouTubeService] search "$query": ${videos.length} raw, ${ytSongs.length} after dedup');

    final lfmTracks = await _lastFm.searchTracks(query, limit: 50);
    if (lfmTracks.isEmpty) return ytSongs;

    final knownArtists = lfmTracks.map((t) => t.artist.toLowerCase()).toSet();
    final enriched = ytSongs.map((song) {
      final match = lfmTracks.firstWhere(
        (t) => _titlesMatch(song.title, t.title),
        orElse: () => (title: '', artist: '', imageUrl: ''),
      );
      if (match.title.isNotEmpty) {
        return Song(id: song.id, title: match.title, artist: match.artist,
            album: song.album, imageUrl: song.imageUrl, audioUrl: song.audioUrl, duration: song.duration);
      }
      final foundArtist = knownArtists.firstWhere(
        (a) => a.length > 3 && song.artist.toLowerCase() == a, orElse: () => '');
      if (foundArtist.isNotEmpty) {
        final properArtist = lfmTracks.firstWhere((t) => t.artist.toLowerCase() == foundArtist).artist;
        return Song(id: song.id, title: song.title, artist: properArtist,
            album: song.album, imageUrl: song.imageUrl, audioUrl: song.audioUrl, duration: song.duration);
      }
      return song;
    }).toList();
    final seen = <String>{};
    final result = enriched.where((s) {
      final key = '${s.title.toLowerCase()}|${s.artist.toLowerCase()}';
      return seen.add(key);
    }).toList();
    print('[YouTubeService] enriched: ${enriched.length}, final: ${result.length}');
    return result;
  }

  bool _titlesMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final normalize = (String s) => s.toLowerCase().replaceAll(RegExp(r'[^\w\sáéíóúñü]'), '').trim();
    final na = normalize(a);
    final nb = normalize(b);
    // Only use substring match when the shorter string has meaningful length (>3 chars)
    final shorter = na.length <= nb.length ? na : nb;
    final longer  = na.length <= nb.length ? nb : na;
    if (shorter.length > 3 && longer.contains(shorter)) return true;
    // Word overlap: at least 2 words longer than 2 chars in common
    final wordsA = na.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = nb.split(' ').where((w) => w.length > 2).toSet();
    return wordsA.intersection(wordsB).length >= 2;
  }

  Future<String> getAudioUrl(String videoId) =>
      safeCall(() => _gateway.getAudioUrl(videoId), '', tag: 'YouTubeService.getAudioUrl');

  Future<List<Song>> generatePlaylist(Song song, {String? search}) =>
      safeCall(() => _server.generatePlaylist(
            song.serverId.isNotEmpty ? song.serverId : song.id,
            limit: 30,
            search: search,
          ), [], tag: 'YouTubeService.generatePlaylist');

  Future<List<Song>> getTrendingMusic() =>
      safeCall(() async {
        final serverSongs = await _server.getTrending(limit: 20);
        if (serverSongs.isNotEmpty) return serverSongs;

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

  Future<String> getPlayableAudioPath(String videoId, {String serverId = '', Song? song}) async {
    // 1. Permanent downloads
    final downloadedPath = await _downloadService.getDownloadedPathById(videoId);
    if (downloadedPath != null) {
      print('[YouTubeService] Using downloaded file for $videoId');
      return downloadedPath;
    }
    // 2. In-memory stream URL on song object (set this session)
    if (song != null && song.hasValidStreamUrl) {
      print('[YouTubeService] Using in-memory stream URL for $videoId');
      return song.streamUrl!;
    }
    // 3. Persisted stream URL cache (survives restarts)
    final cachedUrl = await _streamUrlCache.get(videoId);
    if (cachedUrl != null) {
      print('[YouTubeService] Using persisted stream URL for $videoId');
      song?.streamUrl = cachedUrl;
      return cachedUrl;
    }
    // 4. Server-cached stream URL
    final serverUrl = await _server.getStreamUrl(videoId);
    if (serverUrl.isNotEmpty) {
      print('[YouTubeService] Using server stream URL for $videoId');
      final expiry = _extractExpiry(serverUrl);
      await _streamUrlCache.put(videoId, serverUrl, expiry);
      song?.streamUrl = serverUrl;
      song?.streamUrlExpiresAt = expiry;
      return serverUrl;
    }
    // 5. Temp audio cache
    final cachedPath = await _audioCache.getCachedAudioPath(videoId);
    if (cachedPath != null) {
      print('[YouTubeService] Using cached audio for $videoId');
      return cachedPath;
    }
    // 6. Resolve from YouTube, persist locally and push to server
    final url = await getAudioUrl(videoId);
    print('[YouTubeService] Using online audio URL for $videoId: $url');
    if (url.isNotEmpty) {
      final expiry = _extractExpiry(url);
      await _streamUrlCache.put(videoId, url, expiry);
      song?.streamUrl = url;
      song?.streamUrlExpiresAt = expiry;
      final isMix = song != null && song.serverId.isEmpty;
      _server.pushStreamUrl(isMix ? videoId : serverId, url, isMix: isMix);
    }
    return url;
  }

  DateTime _extractExpiry(String url) {
    final expire = Uri.parse(url).queryParameters['expire'];
    if (expire != null) return DateTime.fromMillisecondsSinceEpoch(int.parse(expire) * 1000, isUtc: true);
    return DateTime.now().toUtc().add(const Duration(hours: 6));
  }

  void dispose() {}
}
