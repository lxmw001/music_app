enum SongType { song, mix, video }

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
  String? streamUrl;
  DateTime? streamUrlExpiresAt;
  final SongType type;

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
    this.streamUrl,
    this.streamUrlExpiresAt,
    this.type = SongType.song,
  });

  bool get hasValidStreamUrl =>
      streamUrl != null &&
      streamUrl!.isNotEmpty &&
      (streamUrlExpiresAt == null || streamUrlExpiresAt!.isAfter(DateTime.now()));

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
      streamUrl: json['streamUrl'] as String?,
      streamUrlExpiresAt: json['streamUrlExpiresAt'] != null
          ? DateTime.tryParse(json['streamUrlExpiresAt'])
          : null,
      type: SongType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'song'),
        orElse: () => SongType.song,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'serverId': serverId, 'title': title, 'artist': artist, 'album': album,
    'imageUrl': imageUrl, 'audioUrl': audioUrl,
    'duration': duration.inSeconds, 'genres': genres,
    'type': type.name,
    if (streamUrl != null) 'streamUrl': streamUrl,
    if (streamUrlExpiresAt != null) 'streamUrlExpiresAt': streamUrlExpiresAt!.toIso8601String(),
  };

  Song copyWith({
    String? id,
    String? serverId,
    String? title,
    String? artist,
    String? album,
    String? imageUrl,
    String? audioUrl,
    Duration? duration,
    List<String>? genres,
    String? streamUrl,
    DateTime? streamUrlExpiresAt,
    SongType? type,
  }) {
    return Song(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      genres: genres ?? this.genres,
      streamUrl: streamUrl ?? this.streamUrl,
      streamUrlExpiresAt: streamUrlExpiresAt ?? this.streamUrlExpiresAt,
      type: type ?? this.type,
    );
  }
}

class MusicSearchResult {
  final List<Song> songs;
  final List<Song> mixes;
  final List<Song> videos;
  final List<String> artists; // artist names for now, expand later
  final bool hasMoreSongs;
  const MusicSearchResult({
    this.songs = const [],
    this.mixes = const [],
    this.videos = const [],
    this.artists = const [],
    this.hasMoreSongs = false,
  });
  bool get isEmpty => songs.isEmpty && mixes.isEmpty && videos.isEmpty && artists.isEmpty;
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
