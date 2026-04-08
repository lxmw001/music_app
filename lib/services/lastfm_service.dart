import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LastFmService {
  static const _base = 'https://ws.audioscrobbler.com/2.0/';
  final http.Client _client;

  LastFmService({http.Client? client}) : _client = client ?? http.Client();

  bool get _hasApiKey => ApiConfig.lastFmApiKey.isNotEmpty;

  Map<String, String> _params(String method, Map<String, String> extra) => {
        'method': method,
        'api_key': ApiConfig.lastFmApiKey,
        'format': 'json',
        ...extra,
      };

  Future<dynamic> _get(String method, Map<String, String> extra) async {
    if (!_hasApiKey) return null;
    try {
      final uri = Uri.parse(_base).replace(queryParameters: _params(method, extra));
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (e) {
      print('[LastFm] error: $e');
      return null;
    }
  }

  /// Get top tracks for an artist — replaces "<artist> best songs" YouTube search
  Future<List<String>> getArtistTopTracks(String artist, {int limit = 10}) async {
    final data = await _get('artist.getTopTracks', {'artist': artist, 'limit': '$limit'});
    if (data == null) return [];
    final tracks = data['toptracks']?['track'] as List?;
    if (tracks == null) return [];
    return tracks.map((t) => '$artist - ${t['name']}').toList();
  }

  /// Get similar artists — replaces Gemini for artist-based suggestions
  Future<List<String>> getSimilarArtists(String artist, {int limit = 5}) async {
    final data = await _get('artist.getSimilar', {'artist': artist, 'limit': '$limit'});
    if (data == null) return [];
    final artists = data['similarartists']?['artist'] as List?;
    if (artists == null) return [];
    return artists.map((a) => a['name'] as String).toList();
  }

  /// Get genre tags for an artist
  Future<List<String>> getArtistTags(String artist, {int limit = 3}) async {
    final data = await _get('artist.getTopTags', {'artist': artist, 'limit': '$limit'});
    if (data == null) return [];
    final tags = data['toptags']?['tag'] as List?;
    if (tags == null) return [];
    return tags.map((t) => t['name'] as String).toList();
  }
}
