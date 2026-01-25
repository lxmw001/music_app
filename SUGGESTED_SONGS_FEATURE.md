# Suggested Songs Feature - Implementation Summary

## Overview
This feature automatically searches for and suggests related songs in the background when a song is playing. The suggestions are fetched 10 seconds before the current song ends and can be automatically added to the queue.

## Changes Made

### 1. YouTubeService (`lib/services/youtube_service.dart`)
**New Method: `getSuggestedSongs`**
```dart
Future<List<Song>> getSuggestedSongs(String videoId, {int maxResults = 5})
```
- Fetches related songs based on the current video ID
- Uses the video title and artist to search for similar content
- Skips the first result (likely the same song)
- Returns up to 5 suggested songs by default
- Handles errors gracefully

### 2. MusicPlayerProvider (`lib/providers/music_player_provider.dart`)

**New Properties:**
- `_youtubeService`: Instance of YouTubeService
- `_autoAddSuggestions`: Toggle for automatic queue addition (default: true)
- `_isFetchingSuggestions`: Flag to prevent duplicate fetches
- `_suggestedSongs`: List of fetched suggested songs

**New Getters:**
- `autoAddSuggestions`: Check if auto-add is enabled
- `isFetchingSuggestions`: Check if currently fetching
- `suggestedSongs`: Get the list of suggested songs

**New Methods:**
1. `toggleAutoAddSuggestions()`: Toggle auto-add feature on/off
2. `_fetchSuggestionsInBackground()`: Private method that fetches suggestions
3. `fetchSuggestions()`: Manually trigger suggestion fetch
4. `addSuggestedToQueue(Song song)`: Add a specific suggestion to queue
5. `clearSuggestions()`: Clear the suggestions list

**Modified Behavior:**
- Listens to `positionStream` to detect when song is 10 seconds from ending
- Automatically fetches suggestions in background
- Clears suggestions when a new song starts playing
- Optionally auto-adds suggestions to queue

## How It Works

### Automatic Flow:
1. User plays a song
2. When song reaches 10 seconds before end:
   - System fetches related songs in background
   - If `autoAddSuggestions` is true, adds them to queue automatically
3. Songs continue playing seamlessly with suggested content

### Manual Control:
```dart
// In your UI code
final player = Provider.of<MusicPlayerProvider>(context);

// Toggle auto-add feature
player.toggleAutoAddSuggestions();

// Manually fetch suggestions
await player.fetchSuggestions();

// Add a specific suggestion to queue
player.addSuggestedToQueue(song);

// Clear suggestions
player.clearSuggestions();

// Check status
if (player.isFetchingSuggestions) {
  // Show loading indicator
}
```

## UI Integration Example

### Display Suggestions in Player Screen:
```dart
// Add to player_screen.dart
if (player.suggestedSongs.isNotEmpty)
  Container(
    height: 200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Up Next',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              if (player.isFetchingSuggestions)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: player.suggestedSongs.length,
            itemBuilder: (context, index) {
              final song = player.suggestedSongs[index];
              return GestureDetector(
                onTap: () => player.addSuggestedToQueue(song),
                child: Container(
                  width: 120,
                  margin: EdgeInsets.only(left: 16),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.imageUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  ),
```

### Add Toggle Button:
```dart
// In settings or player controls
IconButton(
  icon: Icon(
    player.autoAddSuggestions 
      ? Icons.playlist_add_check 
      : Icons.playlist_add,
  ),
  onPressed: () => player.toggleAutoAddSuggestions(),
  tooltip: 'Auto-add suggestions',
),
```

## Benefits

1. **Seamless Experience**: Songs are fetched before current song ends
2. **Background Processing**: Doesn't interrupt playback
3. **Automatic Queue Building**: Continuously discovers new music
4. **User Control**: Can be toggled on/off
5. **Manual Override**: Users can manually trigger or clear suggestions
6. **Performance**: Only fetches once per song, 10 seconds before end

## Configuration

### Adjust Timing:
Change the threshold for when suggestions are fetched (currently 10 seconds before end):
```dart
// In _init() method, modify:
if ((duration - position).inSeconds <= 10) // Change 10 to your preference
```

### Adjust Number of Suggestions:
```dart
// In _fetchSuggestionsInBackground(), modify:
final suggestions = await _youtubeService.getSuggestedSongs(
  _currentSong!.id,
  maxResults: 5, // Change to desired number
);
```

### Disable Auto-Add by Default:
```dart
// In MusicPlayerProvider, change:
bool _autoAddSuggestions = false; // Set to false
```

## Testing

1. Play a song and wait until 10 seconds before it ends
2. Check console logs for: "Fetching suggestions for: [song title]"
3. Check console for: "Found X suggested songs for: [song title]"
4. If auto-add is enabled: "Added X suggestions to queue"
5. Suggestions should appear in the UI if implemented

## Future Enhancements

1. **Smart Suggestions**: Use user listening history to improve suggestions
2. **Caching**: Cache suggestions to avoid duplicate API calls
3. **Preferences**: Allow users to set suggestion preferences (same artist, genre, etc.)
4. **Queue Management**: Limit queue size, remove duplicates
5. **Analytics**: Track which suggestions users actually play
6. **Shuffle Suggestions**: Randomize suggestion order for variety

## Troubleshooting

**Suggestions not appearing:**
- Check console logs for errors
- Verify YouTube connectivity
- Ensure song has a valid video ID
- Check if `autoAddSuggestions` is enabled

**Performance issues:**
- Reduce `maxResults` parameter
- Increase the timing threshold (fetch earlier)
- Consider caching mechanism

**Duplicate songs:**
- Implement duplicate checking in `addSuggestedToQueue()`
- Clear queue periodically
