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
import 'cookie_http_client.dart';
import 'auth_http_client.dart';
import 'youtube_cookie_auth.dart';

class YouTubeRateLimitException implements Exception {
  const YouTubeRateLimitException();
  @override
  String toString() => 'YouTubeRateLimitException';
}

abstract class YoutubeGateway {
  Future<List<Video>> search(String query, {int limit = 5});
  Future<String> getAudioUrl(String videoId);
  Future<Video> getVideo(String videoId);
  Future<({String playlistTitle, List<Video> videos})> getPlaylistVideos(String playlistId);
}

class _AuthenticatedYoutubeHttpClient extends YoutubeHttpClient {
  final String cookieHeader;
  _AuthenticatedYoutubeHttpClient(this.cookieHeader, [http.Client? inner]) : super(inner);
  @override
  Map<String, String> get headers => {
    ...YoutubeHttpClient.defaultHeaders,
    'cookie': cookieHeader,
  };
}

class YoutubeExplodeGateway implements YoutubeGateway {
  YoutubeExplode _yt;
  YoutubeExplodeGateway({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  void applyOAuthToken(String accessToken) {
    final old = _yt;
    _yt = YoutubeExplode(httpClient: YoutubeHttpClient(AuthHttpClient({
      'Authorization': 'Bearer $accessToken',
    })));
    try { old.close(); } catch (_) {}
  }

  Future<void> applyAuthCookies() async {
    final cookieHeader = await YoutubeCookieAuth.loadCookieHeader();
    final old = _yt;
    if (cookieHeader != null) {
      _yt = YoutubeExplode(httpClient: _AuthenticatedYoutubeHttpClient(cookieHeader));
    } else {
      _yt = YoutubeExplode();
    }
    try { old.close(); } catch (_) {}
  }

  @override
  Future<List<Video>> search(String query, {int limit = 5}) async {
    final results = await _yt.search.search(query);
    return results.take(limit).toList();
  }

  @override
  Future<String> getAudioUrl(String videoId) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr])
            .timeout(const Duration(seconds: 80));
        final streams = manifest.audioOnly
            .where((s) => s.codec.mimeType.startsWith('audio/'))
            .toList();
        if (streams.isEmpty) throw Exception('No audio streams for $videoId');
        final aac = streams
            .where((s) => s.codec.mimeType.contains('mp4a') || s.container.name == 'mp4')
            .toList();
        final picked = aac.isNotEmpty ? (aac..sort((a, b) => b.bitrate.compareTo(a.bitrate))).first
                                      : (streams..sort((a, b) => b.bitrate.compareTo(a.bitrate))).first;
        return picked.url.toString();
      } catch (e) {
        if (e.toString().contains('RequestLimitExceeded')) {
          try { _yt.close(); } catch (_) {}
          _yt = YoutubeExplode();
          throw const YouTubeRateLimitException();
        }
        if (attempt == 0) {
          try { _yt.close(); } catch (_) {}
          _yt = YoutubeExplode();
        } else {
          rethrow;
        }
      }
    }
    throw Exception('getAudioUrl unreachable');
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

String _cleanTitle(String raw) {
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

String _extractArtistFromTitle(String cleanedTitle, String channelAuthor) {
  if (!cleanedTitle.contains(' - ')) return channelAuthor;
  final parts = cleanedTitle.split(' - ');
  final first = parts.first.trim();
  final last  = parts.last.trim();
  final channel = channelAuthor.toLowerCase()
      .replaceAll(RegExp(r'\s*(vevo|official|music|records|tv)$', caseSensitive: false), '')
      .trim();
  if (channel.contains(first.toLowerCase()) || first.toLowerCase().contains(channel)) return first;
  if (channel.contains(last.toLowerCase()) || last.toLowerCase().contains(channel)) return last;
  return first;
}

int _titleScore(String title) {
  int score = 0;
  if (title.contains(' - ')) score += 10;           
  if (!title.contains('(')) score += 3;             
  if (!title.contains('[')) score += 2;             
  if (RegExp(r'^[A-Za-záéíóúÁÉÍÓÚñÑüÜ\s\-]+$').hasMatch(title)) score += 2; 
  score -= (title.length / 20).floor();             
  return score;
}

List<Song> _deduplicateSongs(List<Song> songs) {
  final Map<String, Song> best = {};
  for (final song in songs) {
    final titlePart = song.title.contains(' - ')
        ? song.title.split(' - ').last.trim().toLowerCase()
        : song.title.toLowerCase();
    final key = '${titlePart}|${song.artist.toLowerCase()}'
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü|]'), '').trim();
    if (!best.containsKey(key) || _titleScore(song.title) > _titleScore(best[key]!.title)) {
      best[key] = song;
    }
  }
  return best.values.toList();
}

Song _videoToSong(Video video, {String album = '', SongType type = SongType.song}) {
  final cleanedTitle = _cleanTitle(video.title);
  final artist = _extractArtistFromTitle(cleanedTitle, video.author);
  String songTitle = cleanedTitle;
  if (cleanedTitle.contains(' - ')) {
    final parts = cleanedTitle.split(' - ');
    final artistLower = artist.toLowerCase();
    if (parts.first.trim().toLowerCase() == artistLower) {
      songTitle = parts.skip(1).join(' - ').trim(); 
    } else if (parts.last.trim().toLowerCase() == artistLower) {
      songTitle = parts.take(parts.length - 1).join(' - ').trim(); 
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
    type: type,
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
    if (_gateway is YoutubeExplodeGateway) {
      _initFuture = (_gateway as YoutubeExplodeGateway).applyAuthCookies();
    }
  }

  Future<void>? _initFuture;

  Future<void> _awaitInit() async {
    if (_initFuture != null) {
      await _initFuture;
      _initFuture = null;
    }
  }

  Future<void> reloadAuthCookies() async {
    if (_gateway is YoutubeExplodeGateway) {
      _initFuture = (_gateway as YoutubeExplodeGateway).applyAuthCookies();
      await _initFuture;
      _initFuture = null;
    }
  }

  Future<MusicSearchResult> searchSongs(String query) =>
      safeCall(() async {
        final result = await _server.searchSongs(query);
        if (!result.isEmpty) return result;

        final videos = await _gateway.search(query, limit: 30);
        // Simple heuristic for type in basic search
        final songs = _deduplicateSongs(videos.map((v) {
          var type = SongType.song;
          if (v.duration != null && v.duration!.inMinutes > 15) type = SongType.mix;
          return _videoToSong(v, type: type);
        }).toList());
        
        return MusicSearchResult(songs: songs);
      }, const MusicSearchResult(), tag: 'YouTubeService.searchSongs');

  Future<String> getAudioUrl(String videoId) async {
    await _awaitInit();
    try {
      return await _gateway.getAudioUrl(videoId);
    } on YouTubeRateLimitException {
      rethrow;
    } catch (e) {
      return '';
    }
  }

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
        final videos = await _gateway.search('trending music', limit: 20);
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
        final videos = await _gateway.search(query, limit: maxResults + 3);
        return videos
            .where((v) => v.id.value != videoId)
            .take(maxResults)
            .map(_videoToSong)
            .toList();
      }, [], tag: 'YouTubeService.getSuggestedSongs');

  String _extractSearchQuery(String title, String channelAuthor) {
    final cleaned = title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'official|video|audio|lyrics|hd|4k|ft\.?|feat\.?', caseSensitive: false), '')
        .trim();
    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      final artist = parts.first.trim();
      return artist.isNotEmpty ? '$artist music' : cleaned;
    }
    final words = cleaned.split(' ').where((w) => w.isNotEmpty).take(4).join(' ');
    return words.isNotEmpty ? words : channelAuthor;
  }

  Future<List<Song>> getSuggestionsFromHistory(List<Song> likedSongs, {int maxResults = 10}) {
    if (likedSongs.isEmpty) return Future.value([]);
    return safeCall(() async {
      final artistCount = <String, int>{};
      for (final s in likedSongs) {
        artistCount[s.artist] = (artistCount[s.artist] ?? 0) + 1;
      }
      final topArtists = (artistCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key)
          .take(3)
          .toList();
      final likedIds = likedSongs.map((s) => s.id).toSet();
      final results = <Song>[];
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

  Future<String> getPlayableAudioPath(String videoId, {String serverId = '', Song? song}) async {
    await _awaitInit();
    final downloadedPath = await _downloadService.getDownloadedPathById(videoId);
    if (downloadedPath != null) return downloadedPath;
    if (song != null && song.hasValidStreamUrl) return song.streamUrl!;
    final cachedUrl = await _streamUrlCache.get(videoId);
    if (cachedUrl != null) {
      song?.streamUrl = cachedUrl;
      return cachedUrl;
    }
    final serverUrl = await _server.getStreamUrl(videoId);
    if (serverUrl.isNotEmpty) {
      final expiry = _extractExpiry(serverUrl);
      await _streamUrlCache.put(videoId, serverUrl, expiry);
      song?.streamUrl = serverUrl;
      song?.streamUrlExpiresAt = expiry;
      return serverUrl;
    }
    final cachedPath = await _audioCache.getCachedAudioPath(videoId);
    if (cachedPath != null) return cachedPath;
    final url = await getAudioUrl(videoId);
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

  void cacheAudioInBackground(String videoId, String url) {
    _audioCache.cacheFromUrl(videoId, url);
  }

  void dispose() {}
}
