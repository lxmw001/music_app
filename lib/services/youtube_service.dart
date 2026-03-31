import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';
import '../utils/safe_call.dart';

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

Song _videoToSong(Video video, {String album = ''}) => Song(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      album: album,
      imageUrl: video.thumbnails.highResUrl,
      audioUrl: '',
      duration: video.duration ?? Duration.zero,
    );

class YouTubeService {
  final YoutubeGateway _gateway;
  final http.Client _httpClient;

  YouTubeService({YoutubeGateway? gateway, http.Client? httpClient})
      : _gateway = gateway ?? YoutubeExplodeGateway(),
        _httpClient = httpClient ?? http.Client();

  Future<List<Song>> searchSongs(String query) =>
      safeCall(() async => (await _gateway.search(query, limit: 20)).map(_videoToSong).toList(), [], tag: 'YouTubeService.searchSongs');

  Future<String> getAudioUrl(String videoId) =>
      safeCall(() => _gateway.getAudioUrl(videoId), '', tag: 'YouTubeService.getAudioUrl');

  Future<List<Song>> getTrendingMusic() =>
      safeCall(() async => (await _gateway.search('regueton 2026', limit: 20)).map(_videoToSong).toList(), [], tag: 'YouTubeService.getTrendingMusic');

  Future<List<Song>> getPlaylistSongs(String playlistId) =>
      safeCall(() async {
        final result = await _gateway.getPlaylistVideos(playlistId);
        return result.videos.map((v) => _videoToSong(v, album: result.playlistTitle)).toList();
      }, [], tag: 'YouTubeService.getPlaylistSongs');

  Future<bool> testYouTubeConnectivity() =>
      safeCall(() async => (await _httpClient.get(Uri.parse('https://www.youtube.com'))).statusCode == 200, false);

  Future<List<Song>> getSuggestedSongs(String videoId, {int maxResults = 5}) =>
      safeCall(() async {
        final video = await _gateway.getVideo(videoId);
        final videos = await _gateway.search('${video.title} ${video.author}', limit: maxResults + 1);
        return videos.skip(1).map(_videoToSong).toList();
      }, [], tag: 'YouTubeService.getSuggestedSongs');

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

  void dispose() {}
}
