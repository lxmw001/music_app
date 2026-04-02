class ApiConfig {
  static const String youtubeApiKey =
      String.fromEnvironment('YOUTUBE_API_KEY');

  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String youtubeBaseUrl = 'https://www.googleapis.com/youtube/v3';
  static const String searchEndpoint = '$youtubeBaseUrl/search';
  static const String videosEndpoint = '$youtubeBaseUrl/videos';
}
