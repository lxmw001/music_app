class Song {
  final String id;       // YouTube video ID
  final String serverId; // Firestore document ID (empty if not from server)
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  String audioUrl;
  final Duration duration;
  final List<String> genres; // genre tags from server

  Song({
    required this.id,
    this.serverId = '',
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.audioUrl,
    required this.duration,
    this.genres = const [],
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      serverId: json['serverId'] ?? '',
      title: json['title'],
      artist: json['artist'],
      album: json['album'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      duration: Duration(seconds: json['duration'] ?? 0),
      genres: List<String>.from(json['genres'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'serverId': serverId, 'title': title, 'artist': artist, 'album': album,
    'imageUrl': imageUrl, 'audioUrl': audioUrl,
    'duration': duration.inSeconds, 'genres': genres,
  };
}

class MusicSearchResult {
  final List<Song> songs;
  final List<Song> mixes;
  final List<Song> videos;
  const MusicSearchResult({this.songs = const [], this.mixes = const [], this.videos = const []});
  bool get isEmpty => songs.isEmpty && mixes.isEmpty && videos.isEmpty;
}

class Playlist {
  final String id;
  final String name;
  final String imageUrl;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.songs,
  });
}

class Album {
  final String id;
  final String name;
  final String artist;
  final String imageUrl;
  final List<Song> songs;

  Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.songs,
  });
}
