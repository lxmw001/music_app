import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<Song>> searchSongs(String query) async {
    try {
      final searchResults = await _yt.search.search(query);
      final songs = <Song>[];

      for (var video in searchResults.take(5)) {
        // Only basic info, do not fetch manifest here
        songs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: '',
          imageUrl: video.thumbnails.highResUrl,
          audioUrl: '', // Will be fetched before play
          duration: video.duration ?? Duration.zero,
        ));
      }
      return songs;
    } catch (e) {
      return [];
    }
  }

  Future<String> getAudioUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
      );
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      print('Error getting audio URL: $e');
      return '';
    }
  }

  Future<List<Song>> getTrendingMusic() async {
    try {
      final searchResults = await _yt.search.search('regueton 2026');
      final songs = <Song>[];

      for (var video in searchResults.take(2)) {
        // Only basic info, do not fetch manifest here
        songs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: '',
          imageUrl: video.thumbnails.highResUrl,
          audioUrl: '', // Will be fetched before play
          duration: video.duration ?? Duration.zero,
        ));
      }
      return songs;
    } catch (e) {
      print('Error getting trending music: $e');
      return [];
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    try {
      final playlist = await _yt.playlists.get(playlistId);
      final videos = await _yt.playlists.getVideos(playlistId).toList();
      final songs = <Song>[];

      for (var video in videos) {
        // Only basic info, do not fetch manifest here
        songs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: playlist.title,
          imageUrl: video.thumbnails.highResUrl,
          audioUrl: '', // Will be fetched before play
          duration: video.duration ?? Duration.zero,
        ));
      }
      return songs;
    } catch (e) {
      print('Error getting playlist songs: $e');
      return [];
    }
  }

  /// Step 7: Minimal network test to check connectivity to YouTube
  Future<bool> testYouTubeConnectivity() async {
    try {
      final response = await http.get(Uri.parse('https://www.youtube.com'));
      if (response.statusCode == 200) {
        print('YouTube connectivity test: SUCCESS');
        return true;
      } else {
        print('YouTube connectivity test: FAILED with status \\${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('YouTube connectivity test: ERROR - \\${e.toString()}');
      return false;
    }
  }

  /// Get suggested songs based on a video ID
  Future<List<Song>> getSuggestedSongs(String videoId, {int maxResults = 5}) async {
    try {
      // Get the video details first
      final video = await _yt.videos.get(videoId);
      
      // Search for related content using the video title and artist
      final searchQuery = '${video.title} ${video.author}';
      final searchResults = await _yt.search.search(searchQuery);
      final songs = <Song>[];

      // Skip the first result as it's likely the same song
      for (var result in searchResults.skip(1).take(maxResults)) {
        // Only basic info, do not fetch manifest here
        songs.add(Song(
          id: result.id.value,
          title: result.title,
          artist: result.author,
          album: '',
          imageUrl: result.thumbnails.highResUrl,
          audioUrl: '', // Will be fetched before play
          duration: result.duration ?? Duration.zero,
        ));
      }
      
      print('Found \\${songs.length} suggested songs for: \\${video.title}');
      return songs;
    } catch (e) {
      print('Error getting suggested songs: $e');
      return [];
    }
  }

  void dispose() {
    // _yt.close();
  }
}
