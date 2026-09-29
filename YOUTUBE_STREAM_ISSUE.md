# YouTube Stream Playback Issue — Research Log

## Device
- Android 36 (Xiaomi)
- just_audio_media_kit (MPV/libmpv) used as audio backend due to ExoPlayer AAC decoder bug on this device

## Root Cause Summary
YouTube now enforces `rqh=1` + `svpuc=1` on all stream URLs returned by the `android` API client. These URLs require the playback request to come from the **same session context** (same HTTP client instance) that fetched the manifest. Every other client (`ios`, `tv`, `mweb`, `safari`, `androidVr`) returns 403 or VideoUnavailableException.

## What We Know

### Stream URL clients tested (from Mac, same findings on device)
| Client | Result |
|--------|--------|
| `android` (default) | ✅ Returns streams, all have `rqh=1 svpuc=1` |
| `ios` | ❌ 403 |
| `tv` | ❌ VideoUnavailableException |
| `mweb` | ❌ VideoUnavailableException |
| `safari` | ❌ VideoUnavailableException |
| `androidVr` | ❌ VideoUnavailableException |

### HTTP client tests for rqh=1 URLs (from Mac)
| Client | Status |
|--------|--------|
| `YoutubeHttpClient` (fresh instance) | ✅ 206 |
| `http.Client` with YoutubeHttpClient.defaultHeaders | ✅ 206 |
| No headers at all | ✅ 206 |

Mac works without any headers. **The IP is what matters** — URL is bound to `ip=190.96.100.43` (device IP).

### HTTP client tests (on Android device)
| Client | Status |
|--------|--------|
| `YoutubeHttpClient` in `_YtStreamAudioSource` | ❌ 403 |
| `LockCachingAudioSource` (Dart HttpClient) | ❌ 403 |
| MPV native HTTP via `AudioSource.uri` + headers | ❌ 403 |
| MPV native HTTP via `AudioSource.uri` no headers | ❌ 403 |

**All Dart/MPV HTTP requests from the device get 403 on `rqh=1` URLs.**

### just_audio proxy behavior
- `AudioSource.uri` with headers → just_audio wraps URL in `http://127.0.0.1:PORT/videoplayback?...` proxy
- `StreamAudioSource` (`LockCachingAudioSource`, `_YtStreamAudioSource`) → just_audio serves via `http://127.0.0.1:PORT/id/<uuid>`
- MPV can reach the `/id/<uuid>` format ✅
- MPV can reach the real HTTPS URL directly ✅
- But all HTTP requests from the device to YouTube get 403 on rqh=1 URLs ❌

### Key finding
`youtube_explode_dart`'s own `yt.videos.streams.get(streamInfo)` uses `YoutubeHttpClient.getStream()` internally with special handling:
- Chunked range requests with `bytes=FROM-TO`
- For `c=ANDROID`, uses `Range` header (not `?range=` query param)
- Has retry/resume logic
- **This is what WORKS on Mac** and is presumably what works correctly in the library

We have NOT yet tested if `yt.videos.streams.get(streamInfo)` works on the Android device.

## What We've Tried (DO NOT RETRY)

1. ❌ Different HTTP headers (Android UA, Chrome UA, IOS UA, no UA) — all 403 on device
2. ❌ `LockCachingAudioSource` — uses Dart `dart:io HttpClient`, 403 on device
3. ❌ `_YtStreamAudioSource` with `YoutubeHttpClient.send()` — 403 on device
4. ❌ `AudioSource.uri` with headers + `useProxyForRequestHeaders=false` — MPV gets real URL but 403
5. ❌ `AudioSource.uri` with headers + `useProxyForRequestHeaders=true` — MPV gets proxy URL but redirect fails
6. ❌ Server-cached stream URLs — IP-bound, different IP on each session = 403
7. ❌ `youtube_explode_dart` 3.1.0 — returns empty URLs for some streams
8. ❌ All YouTube API clients except `android` default — don't return streams

## What To Try Next

### Option A: Use `yt.videos.streams.get(streamInfo)` via StreamAudioSource
The library's own stream fetcher handles the rqh=1 correctly (it works from Mac). Test if it works on Android device too. If yes, pipe the stream through a `StreamAudioSource` that calls `getStream()`.

```dart
class _YtLibStreamSource extends StreamAudioSource {
  final AudioStreamInfo streamInfo;
  final YoutubeExplodeGateway gateway;
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final stream = gateway.getStream(streamInfo, start: start ?? 0);
    return StreamAudioResponse(
      sourceLength: streamInfo.size.totalBytes,
      contentLength: streamInfo.size.totalBytes - (start ?? 0),
      offset: start ?? 0,
      stream: stream,
      contentType: streamInfo.codec.mimeType,
    );
  }
}
```

### Option B: Use YouTube cookies (WebView login)
If the user logs in via the in-app WebView, `YoutubeCookieAuth` stores real session cookies. These are used by `_AuthenticatedYoutubeHttpClient`. Streams fetched while authenticated may not have `rqh=1` or may be accessible with those cookies.

### Option C: Add ytdl-core to the backend server
Add a `/songs/:videoId/audio-stream` endpoint on the Node.js server that proxies the audio stream. The server (Cloud Run, Linux) can fetch it fine. The app streams from the server URL (no rqh=1 issue).

### Option D: Switch audio backend
Remove `just_audio_media_kit`. Use ExoPlayer (native just_audio Android backend) which natively handles HTTP with the OS TLS stack. Fix the AAC decoder bug with a custom `RenderersFactory` that forces software decoding.
