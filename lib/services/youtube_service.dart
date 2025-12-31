import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import '../models/music_models.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  Future<List<Song>> searchSongs(String query) async {
    try {
      final searchResults = await _yt.search.search(query);
      final songs = <Song>[];

      for (var video in searchResults.take(20)) {
        if (video is Video) {
          final manifest = await _yt.videos.streamsClient.getManifest(video.id);
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
      print('Error searching YouTube: $e');
      return [];
    }
  }

  Future<String> getAudioUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      print('Error getting audio URL: $e');
      return '';
    }
  }

  Future<List<Song>> getTrendingMusic() async {
    try {
      final searchResults = await _yt.search.search('trending music 2024');
      final songs = <Song>[];

      for (var video in searchResults.take(10)) {
        if (video is Video) {
          final manifest = await _yt.videos.streamsClient.getManifest(video.id);
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
        final manifest = await _yt.videos.streamsClient.getManifest(video.id);
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

  void dispose() {
    _yt.close();
  }
}
