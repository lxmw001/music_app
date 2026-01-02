import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/music_models.dart';
import 'package:youtube_explode_dart/solvers.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  Future<List<Song>> searchSongs(String query) async {
    try {
      final searchResults = await _yt.search.search(query);
      final songs = <Song>[];

      for (var video in searchResults.take(5)) {
        if (video is Video) {
          final manifest = await _yt.videos.streamsClient.getManifest(video.id,
            fullManifest: true,
            ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr]);
          final audioStream = manifest.audioOnly.withHighestBitrate();
          
          songs.add(Song(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            album: '',
            imageUrl: video.thumbnails.highResUrl,
            audioUrl: audioStream.url.toString(),
            duration: video.duration ?? Duration.zero,
          ));
        }
      }
      return songs;
    } catch (e) {
      return [];
    }
  }

  Future<String> getAudioUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId,
        fullManifest: true,
        ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr]);
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
        if (video is Video) {
          final manifest = await _yt.videos.streamsClient.getManifest(video.id,
            fullManifest: true,
            ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr]
          );
          final audioStream = manifest.audioOnly.withHighestBitrate();
          
          songs.add(Song(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            album: '',
            imageUrl: video.thumbnails.highResUrl,
            audioUrl: audioStream.url.toString(),
            duration: video.duration ?? Duration.zero,
          ));
        }
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
        final manifest = await _yt.videos.streamsClient.getManifest(video.id,
          fullManifest: true,
          ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr]);
        final audioStream = manifest.audioOnly.withHighestBitrate();
        
        songs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: playlist.title,
          imageUrl: video.thumbnails.highResUrl,
          audioUrl: audioStream.url.toString(),
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

  void dispose() {
    // _yt.close();
  }
}
