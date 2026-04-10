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
    if (!_hasApiKey) {
      print('[LastFm] no API key set, skipping $method');
      return null;
    }
    print('[LastFm] calling $method');
    try {
      final uri = Uri.parse(_base).replace(queryParameters: _params(method, extra));
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      print('[LastFm] $method response: ${response.statusCode}');
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (e) {
      print('[LastFm] $method error: $e');
      return null;
    }
  }

  /// Get top tracks for an artist — replaces "<artist> best songs" YouTube search
  Future<List<({String title, String artist, String imageUrl})>> searchTracks(String query, {int limit = 20}) async {
    final data = await _get('track.search', {'track': query, 'limit': '$limit'});
    if (data == null) return [];
    final tracks = data['results']?['trackmatches']?['track'] as List?;
    if (tracks == null) return [];
    final result = tracks.map((t) => (
      title: t['name'] as String,
      artist: t['artist'] as String,
      imageUrl: _bestImage(t['image'] as List?),
    )).toList();
    print('[LastFm] search "$query": ${result.length} results');
    return result;
  }

  String _bestImage(List? images) {
    if (images == null || images.isEmpty) return '';
    // Last.fm images: small, medium, large, extralarge
    final large = images.lastWhere((i) => (i['#text'] as String).isNotEmpty, orElse: () => images.first);
    return large['#text'] as String? ?? '';
  }
    final data = await _get('artist.getTopTracks', {'artist': artist, 'limit': '$limit'});
    if (data == null) { print('[LastFm] no API key or error for top tracks: $artist'); return []; }
    final tracks = data['toptracks']?['track'] as List?;
    if (tracks == null) return [];
    final result = tracks.map((t) => '$artist - ${t['name']}').toList();
    print('[LastFm] top tracks for "$artist": $result');
    return result;
  }

  /// Get similar artists — replaces Gemini for artist-based suggestions
  Future<List<String>> getSimilarArtists(String artist, {int limit = 5}) async {
    final data = await _get('artist.getSimilar', {'artist': artist, 'limit': '$limit'});
    if (data == null) { print('[LastFm] no API key or error for similar artists: $artist'); return []; }
    final artists = data['similarartists']?['artist'] as List?;
    if (artists == null) return [];
    final result = artists.map((a) => a['name'] as String).toList();
    print('[LastFm] similar artists for "$artist": $result');
    return result;
  }

  /// Get genre tags for an artist
  Future<List<String>> getArtistTags(String artist, {int limit = 3}) async {
    final data = await _get('artist.getTopTags', {'artist': artist, 'limit': '$limit'});
    if (data == null) return [];
    final tags = data['toptags']?['tag'] as List?;
    if (tags == null) return [];
    final result = tags.map((t) => t['name'] as String).toList();
    print('[LastFm] tags for "$artist": $result');
    return result;
  }
}
