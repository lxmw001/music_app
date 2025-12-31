class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final String audioUrl;
  final Duration duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.audioUrl,
    required this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      duration: Duration(seconds: json['duration']),
    );
  }
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
