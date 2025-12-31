# Environment Configuration

## YouTube API Setup (Optional)

The app currently uses `youtube_explode_dart` which doesn't require an API key. However, if you want to use the official YouTube Data API v3:

### Steps to get YouTube API Key:

1. Go to [Google Cloud Console](https://console.developers.google.com/)
2. Create a new project or select existing one
3. Enable "YouTube Data API v3"
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Copy the API key

### Add API Key:

Replace `YOUR_YOUTUBE_API_KEY_HERE` in `/lib/config/api_config.dart` with your actual API key:

```dart
static const String youtubeApiKey = 'AIzaSyC4E1Pxxx...'; // Your actual key
```

### API Limits:
- YouTube Data API v3 has quota limits (10,000 units/day by default)
- Each search request costs ~100 units
- Consider the current `youtube_explode_dart` approach for unlimited usage

### Current Implementation:
The app uses `youtube_explode_dart` which:
- ✅ No API key required
- ✅ No quota limits
- ✅ Direct audio stream access
- ⚠️ May break if YouTube changes their structure
