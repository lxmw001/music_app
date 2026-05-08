# Backend: Server-Side YouTube Stream URL Resolution

## Problem

The Flutter app resolves YouTube stream URLs directly from the device using `youtube_explode_dart`.
YouTube rate-limits by IP — when the device IP gets throttled, playback fails.

## Solution

The server should resolve stream URLs on behalf of clients. The server IP is shared across all users
and can be rotated/proxied, making it much harder to rate-limit.

## Current Behavior

`GET /songs/:id/stream-url` — returns cached URL if available, empty string if not.  
`POST /songs/:id/stream-url` — client pushes a URL it resolved itself.

## Required Change

**`GET /songs/:id/stream-url`** should:
1. Check DB/cache for a valid (non-expired) stream URL → return it if found
2. If not found or expired → **resolve it server-side from YouTube** → cache it → return it

The client should never need to call YouTube directly for stream URLs.

---

## Implementation

### Dependency

Use [`ytdl-core`](https://github.com/fent/node-ytdl-core) or [`yt-dlp` via child_process] to resolve stream URLs.

Recommended: `ytdl-core` (pure Node.js, no binary needed):

```bash
npm install ytdl-core
```

### Service: `YoutubeStreamService`

```typescript
// youtube-stream.service.ts
import { Injectable, Logger } from '@nestjs/common';
import * as ytdl from 'ytdl-core';

@Injectable()
export class YoutubeStreamService {
  private readonly logger = new Logger(YoutubeStreamService.name);

  async resolveStreamUrl(videoId: string): Promise<string | null> {
    try {
      const info = await ytdl.getInfo(videoId);
      const format = ytdl.chooseFormat(info.formats, {
        quality: 'highestaudio',
        filter: 'audioonly',
      });
      return format?.url ?? null;
    } catch (e) {
      this.logger.warn(`Failed to resolve stream URL for ${videoId}: ${e.message}`);
      return null;
    }
  }
}
```

### Updated Controller/Service: `GET /songs/:id/stream-url`

```typescript
async getStreamUrl(id: string): Promise<{ streamUrl: string }> {
  // 1. Check cache
  const cached = await this.songRepo.findStreamUrl(id); // your existing cache lookup
  if (cached && new Date(cached.expiresAt) > new Date()) {
    return { streamUrl: cached.streamUrl };
  }

  // 2. Resolve server-side
  const streamUrl = await this.youtubeStreamService.resolveStreamUrl(id);
  if (!streamUrl) {
    throw new NotFoundException(`Could not resolve stream URL for ${id}`);
  }

  // 3. Cache it
  const expireMatch = streamUrl.match(/expire=(\d+)/);
  const expiresAt = expireMatch
    ? new Date(parseInt(expireMatch[1]) * 1000)
    : new Date(Date.now() + 6 * 60 * 60 * 1000); // 6h fallback

  await this.songRepo.saveStreamUrl(id, streamUrl, expiresAt);

  return { streamUrl };
}
```

### Response shape (unchanged)

```json
{ "streamUrl": "https://rr1---sn-....googlevideo.com/videoplayback?..." }
```

---

## Client behavior after this change

`getPlayableAudioPath` already checks the server at step 4 before hitting YouTube:

```
1. Permanent download (local file)
2. In-memory stream URL (this session)
3. Persisted stream URL cache (SharedPreferences)
4. Server → GET /songs/:id/stream-url  ← server resolves here if needed
5. Audio file cache
6. YouTube direct (fallback only)
```

Once the server resolves URLs, step 4 will almost always succeed and step 6 (device-side YouTube) will rarely be needed.

---

## Notes

- `ytdl-core` is unmaintained but still works for audio-only streams. Alternative: shell out to `yt-dlp` binary which is actively maintained.
- Stream URLs expire in ~6 hours. The server cache TTL should match the `expire` param in the URL.
- For mixes (non-server songs), the endpoint is `GET /songs/mixes/:id/stream-url` — same logic applies.
- Consider rate-limiting the endpoint per user to prevent abuse.
