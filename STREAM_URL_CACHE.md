# Suggestion: Cache YouTube Stream URLs on Server

## Problem

The app calls YouTube's internal API directly (`youtube_explode_dart`) to resolve audio stream URLs for each song. This causes:

- **Rate limiting** — YouTube blocks IPs that make too many requests (`RequestLimitExceededException`)
- **Slow load times** — each URL fetch takes 2–8 seconds
- **Failures** — some videos return `VideoUnplayableException` or timeout

## Suggestion

The server should cache YouTube stream URLs and serve them to the app.

### Endpoint

```
GET /songs/:id/stream-url
```

Response:
```json
{
  "youtubeId": "fX8DqAt5QVE",
  "streamUrl": "https://rr2---sn-xxx.googlevideo.com/videoplayback?...",
  "expiresAt": "2026-04-27T22:00:00Z"
}
```

### How it works

1. App requests stream URL from server instead of YouTube directly
2. Server checks cache (Redis/Firestore) — if valid URL exists, return it immediately
3. If expired or missing, server fetches from YouTube (server IP is less likely to be rate-limited)
4. Server caches the URL for its TTL (~6 hours based on `expire=` param in the URL)

### Benefits

- App never calls YouTube directly for stream URLs
- Rate limiting hits the server IP (easier to rotate/manage)
- Near-instant playback — URL served from cache
- Single place to handle YouTube client rotation and retries

### Notes

- YouTube stream URLs contain `expire=<unix_timestamp>` — use that as the cache TTL
- The URL also contains `ip=<client_ip>` — the server should fetch and serve from the same IP
- Client headers (`User-Agent`, `X-Youtube-Client-*`) must match the client used to fetch the URL
