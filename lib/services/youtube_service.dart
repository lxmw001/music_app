import "package:music_app/utils/logger.dart";
import 'dart:async';
import 'package:flutter/foundation.dart';
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
  late YoutubeExplode _yt;
  late YoutubeHttpClient _ytHttpClient;

  YoutubeHttpClient get ytHttpClient => _ytHttpClient;

  YoutubeExplodeGateway({YoutubeExplode? yt}) {
    _ytHttpClient = YoutubeHttpClient();
    _yt = yt ?? YoutubeExplode(httpClient: _ytHttpClient);
  }

  void applyOAuthToken(String accessToken) {
    final old = _yt;
    _ytHttpClient = YoutubeHttpClient(AuthHttpClient({'Authorization': 'Bearer $accessToken'}));
    _yt = YoutubeExplode(httpClient: _ytHttpClient);
    try { old.close(); } catch (_) {}
  }

  Future<void> applyAuthCookies() async {
    final cookieHeader = await YoutubeCookieAuth.loadCookieHeader();
    final old = _yt;
    if (cookieHeader != null) {
      _ytHttpClient = _AuthenticatedYoutubeHttpClient(cookieHeader);
      _yt = YoutubeExplode(httpClient: _ytHttpClient);
    } else {
      _ytHttpClient = YoutubeHttpClient();
      _yt = YoutubeExplode(httpClient: _ytHttpClient);
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
    // null = android default (only client reliably returning streams currently)
    final clientSets = <List<YoutubeApiClient>?>[
      null, // android default — must be first
      [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
      [YoutubeApiClient.tv, YoutubeApiClient.safari],
    ];
    Object? lastError;
    for (int attempt = 0; attempt < clientSets.length; attempt++) {
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: clientSets[attempt])
            .timeout(const Duration(seconds: 80));
        final streams = manifest.audioOnly
            .where((s) => s.codec.mimeType.startsWith('audio/'))
            .toList();
        if (streams.isEmpty) {
          lastError = Exception('No audio streams for $videoId (attempt ${attempt + 1})');
          continue;
        }
        final aac = streams
            .where((s) => s.codec.mimeType.contains('mp4a') || s.container.name == 'mp4')
            .toList();
        final picked = aac.isNotEmpty
            ? (aac..sort((a, b) => b.bitrate.compareTo(a.bitrate))).first
            : (streams..sort((a, b) => b.bitrate.compareTo(a.bitrate))).first;
        return picked.url.toString();
      } catch (e) {
        if (e.toString().contains('RequestLimitExceeded')) {
          try { _yt.close(); } catch (_) {}
          _yt = YoutubeExplode();
          throw const YouTubeRateLimitException();
        }
        lastError = e;
        if (attempt < clientSets.length - 1) {
          try { _yt.close(); } catch (_) {}
          _yt = YoutubeExplode();
        }
      }
    }
    throw lastError ?? Exception('getAudioUrl: all clients failed for $videoId');
  }

  /// Returns the best audio [StreamInfo] for [videoId].
  /// Use [getStream] to fetch bytes — the library handles rqh=1 correctly.
  Future<AudioStreamInfo> getAudioStreamInfo(String videoId) async {
    final manifest = await _yt.videos.streamsClient
        .getManifest(videoId)
        .timeout(const Duration(seconds: 80));
    final streams = manifest.audioOnly
        .where((s) => s.codec.mimeType.startsWith('audio/'))
        .toList();
    if (streams.isEmpty) throw Exception('No audio streams for $videoId');
    final aac = streams
        .where((s) => s.codec.mimeType.contains('mp4a') || s.container.name == 'mp4')
        .toList();
    return aac.isNotEmpty
        ? (aac..sort((a, b) => b.bitrate.compareTo(a.bitrate))).first
        : (streams..sort((a, b) => b.bitrate.compareTo(a.bitrate))).first;
  }

  /// Streams audio bytes for [streamInfo] using the library's own HTTP client.
  Stream<List<int>> getStream(AudioStreamInfo streamInfo, {int start = 0}) =>
      _ytHttpClient.getStream(streamInfo, streamClient: _yt.videos.streamsClient, start: start);

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
  final MusicServerService _server;
  final StreamUrlCache _streamUrlCache = StreamUrlCache();
  late final DownloadService _downloadService;

  YouTubeService({YoutubeGateway? gateway, http.Client? httpClient, GeminiService? gemini, LastFmService? lastFm, DownloadService? downloadService, MusicServerService? server})
      : _gateway = gateway ?? YoutubeExplodeGateway(),
        _httpClient = httpClient ?? http.Client(),
        _gemini = gemini ?? GeminiService(),
        _server = server ?? MusicServerService() {
    _downloadService = downloadService ?? DownloadService();
    if (_gateway is YoutubeExplodeGateway) {
      _initFuture = (_gateway as YoutubeExplodeGateway).applyAuthCookies();
    }
  }

  /// The YoutubeHttpClient used internally — reuse for stream playback so that
  /// rqh=1 URLs are fetched with the same session that generated them.
  YoutubeHttpClient? get ytHttpClient =>
      _gateway is YoutubeExplodeGateway ? (_gateway as YoutubeExplodeGateway).ytHttpClient : null;

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

  Future<MusicSearchResult> searchSongs(String query, {bool force = false}) =>
      safeCall(() async {
        final result = await _server.searchSongs(query, force: force);
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
      rlog('[YouTubeService.getAudioUrl] Error for $videoId: $e');
      return '';
    }
  }

  /// Returns the best [AudioStreamInfo] + a stream factory fetched by
  /// youtube_explode_dart's own HTTP client — the only method that correctly
  /// handles rqh=1/svpuc=1 signed URLs.
  Future<({AudioStreamInfo info, Stream<List<int>> Function(int start) stream})?> getAudioStreamInfo(String videoId) async {
    await _awaitInit();
    if (_gateway is! YoutubeExplodeGateway) return null;
    final gw = _gateway as YoutubeExplodeGateway;
    try {
      final info = await gw.getAudioStreamInfo(videoId);
      return (
        info: info,
        stream: (int start) => gw.getStream(info, start: start),
      );
    } catch (e) {
      rlog('[YouTubeService.getAudioStreamInfo] Error for $videoId: $e');
      return null;
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
    if (downloadedPath != null) {
      print('[YouTubeService] using downloaded file for $videoId');
      return downloadedPath;
    }
    if (song != null && song.hasValidStreamUrl) {
      rlog('[YouTubeService] using song.streamUrl ip=${Uri.tryParse(song.streamUrl!)?.queryParameters['ip']}');
      return song.streamUrl!;
    }
    final cachedUrl = await _streamUrlCache.get(videoId);
    if (cachedUrl != null) {
      rlog('[YouTubeService] using cached url ip=${Uri.tryParse(cachedUrl)?.queryParameters['ip']}');
      song?.streamUrl = cachedUrl;
      return cachedUrl;
    }
    String? url;
    // On Android, skip server-cached URLs — they are IP-bound and may have been
    // cached from a different network session, causing 403 on the current IP.
    final serverUrl = defaultTargetPlatform == TargetPlatform.android
        ? ''
        : await _server.getStreamUrl(videoId);
    if (serverUrl.isNotEmpty) {
      url = serverUrl;
    } else {
      final cachedPath = await _audioCache.getCachedAudioPath(videoId);
      if (cachedPath != null) return cachedPath;
      try {
        url = await getAudioUrl(videoId);
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          rlog('[YouTubeService] fresh url ip=${uri?.queryParameters['ip']} c=${uri?.queryParameters['c']}');
        }
      } catch (e) {
        rlog('[YouTubeService] getAudioUrl failed for $videoId: $e');
      }
    }
    if (url != null && url.isNotEmpty) {
      final expiry = _extractExpiry(url);
      await _streamUrlCache.put(videoId, url, expiry);
      song?.streamUrl = url;
      song?.streamUrlExpiresAt = expiry;
      if (serverUrl.isEmpty) {
        final isMix = song != null && song.serverId.isEmpty;
        _server.pushStreamUrl(isMix ? videoId : serverId, url, isMix: isMix);
      }
      return url;
    }
    return '';
  }

  DateTime _extractExpiry(String url) {
    final expire = Uri.parse(url).queryParameters['expire'];
    if (expire != null) return DateTime.fromMillisecondsSinceEpoch(int.parse(expire) * 1000, isUtc: true);
    return DateTime.now().toUtc().add(const Duration(hours: 6));
  }

  void cacheAudioInBackground(String videoId, String url) {
    _audioCache.cacheFromUrl(videoId, url);
  }

  Future<void> clearStreamUrlCache(String videoId) async {
    await _streamUrlCache.remove(videoId);
  }

  void dispose() {}
}
