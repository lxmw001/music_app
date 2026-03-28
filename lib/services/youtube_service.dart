import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';

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

  Future<List<Song>> searchSongs(String query) async {
    try {
      final videos = await _gateway.search(query, limit: 20);
      return videos.map(_videoToSong).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> getAudioUrl(String videoId) async {
    try {
      return await _gateway.getAudioUrl(videoId);
    } catch (e) {
      print('Error getting audio URL: $e');
      return '';
    }
  }

  Future<List<Song>> getTrendingMusic() async {
    try {
      final videos = await _gateway.search('regueton 2026', limit: 20);
      return videos.map(_videoToSong).toList();
    } catch (e) {
      print('Error getting trending music: $e');
      return [];
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    try {
      final result = await _gateway.getPlaylistVideos(playlistId);
      return result.videos
          .map((v) => _videoToSong(v, album: result.playlistTitle))
          .toList();
    } catch (e) {
      print('Error getting playlist songs: $e');
      return [];
    }
  }

  Future<bool> testYouTubeConnectivity() async {
    try {
      final response = await _httpClient.get(Uri.parse('https://www.youtube.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Song>> getSuggestedSongs(String videoId, {int maxResults = 5}) async {
    try {
      final video = await _gateway.getVideo(videoId);
      final videos = await _gateway.search(
        '${video.title} ${video.author}',
        limit: maxResults + 1,
      );
      return videos.skip(1).map(_videoToSong).toList();
    } catch (e) {
      print('Error getting suggested songs: $e');
      return [];
    }
  }

  Future<List<Song>> getSuggestionsFromHistory(List<Song> likedSongs, {int maxResults = 10}) async {
    if (likedSongs.isEmpty) return [];
    try {
      // Use top 3 liked songs to build a search query
      final topSongs = likedSongs.take(3).toList();
      final query = topSongs.map((s) => s.artist).toSet().take(2).join(' ');
      final videos = await _gateway.search(query, limit: maxResults + topSongs.length);
      // Exclude songs already in liked list
      final likedIds = likedSongs.map((s) => s.id).toSet();
      return videos
          .where((v) => !likedIds.contains(v.id.value))
          .take(maxResults)
          .map(_videoToSong)
          .toList();
    } catch (e) {
      print('Error getting suggestions from history: $e');
      return [];
    }
  }

  void dispose() {}
}
