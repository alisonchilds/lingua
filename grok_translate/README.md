# Grok Translate

**Universal real-time voice translator** powered by the [Grok Voice Agent API](https://docs.x.ai/docs/realtime-api).

Two people speak naturally in two different languages on a single shared device. Grok detects each language automatically, translates in real-time, and plays the translation through the device speaker — no internet latency, no manual switching.

---

## Features

- **Automatic language detection** — no manual switching needed mid-conversation
- **Real-time voice translation** via Grok Realtime WebSocket API (server VAD)
- **Full-duplex with barge-in** — interrupt a translation by speaking
- **Live subtitles** (toggleable) — translated text appears as speech is rendered
- **Echo prevention** — mic is gated while translated audio plays back
- **PWA-ready** — installable on desktop browsers and Android Chrome from the same codebase
- **Responsive layout** — phone, tablet, and desktop all work from one build
- **Material 3** design with automatic light/dark mode

---

## Security Architecture

**No API key is ever stored on the user's device.**

All platforms (web, iOS, Android) connect to a **Cloudflare Worker proxy** that holds the `XAI_API_KEY` secret server-side. The proxy injects the `Authorization` header before forwarding requests to `api.x.ai`. The Flutter app never sees the key.

```
Flutter app (any platform)
    │
    │  WebSocket / HTTPS  (no auth header)
    ▼
Cloudflare Worker  ←── XAI_API_KEY (secret, server-side only)
    │
    │  WebSocket / HTTPS  (Authorization: Bearer $XAI_API_KEY)
    ▼
api.x.ai  (Grok Realtime + STT + Chat)
```

See [`cloudflare-worker/worker.js`](cloudflare-worker/worker.js) for the full proxy source and deploy instructions.

---

## Tech Stack

| Concern | Library |
|---|---|
| Cross-platform UI | Flutter 3.29+ |
| State management | Riverpod 2.5+ |
| Navigation | GoRouter 14 |
| Mic capture | `record` 5.x (native), AudioWorklet (web) |
| Audio playback | `just_audio` (native), Web Audio API (web) |
| WebSocket | `web_socket_channel` 3 + native browser WS |
| Models | Freezed + json\_serializable |
| Persistence | `shared_preferences` (VAD settings, language config) |
| Animations | `flutter_animate` |

---

## Prerequisites

1. **Flutter 3.29+** — verify with `flutter --version`
2. **A deployed Cloudflare Worker** — see [Deploy the Proxy](#deploy-the-proxy) below
3. Chrome / Edge 100+ for web, or a physical iOS / Android device for native

---

## Deploy the Proxy

The app will not work without a running proxy. Deploy once, then point all builds at it.

### Option A — Cloudflare Dashboard (5 minutes)

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → **Workers & Pages → Create Worker**
2. Paste the contents of [`cloudflare-worker/worker.js`](cloudflare-worker/worker.js)
3. Click **Save and Deploy**
4. Go to **Settings → Variables → Secrets** and add:
   - Name: `XAI_API_KEY`
   - Value: your xAI key from [platform.x.ai](https://platform.x.ai)
5. Note your worker URL, e.g. `your-worker.your-account.workers.dev`

### Option B — Wrangler CLI

```bash
npm install -g wrangler
wrangler login
cd cloudflare-worker
wrangler secret put XAI_API_KEY   # paste your xAI key when prompted
wrangler deploy
```

### After deploying

Add your production domain to `ALLOWED_WEB_ORIGINS` in `worker.js` if you are hosting the web build on a **custom domain** (non-`*.pages.dev`):

```js
const ALLOWED_WEB_ORIGINS = new Set([
  "https://your-production-domain.com",
]);
```

---

## Quick Start

```bash
cd grok_translate
flutter pub get

# Run on Chrome — uses the default proxy URL
flutter run -d chrome

# Run with your own proxy
flutter run -d chrome --dart-define=PROXY_HOST=your-worker.your-account.workers.dev

# Run on a connected Android device
flutter run -d android --dart-define=PROXY_HOST=your-worker.your-account.workers.dev
```

---

## Build for Production

All builds accept a single `--dart-define` flag that sets the proxy for all three
endpoints (Realtime WebSocket, STT WebSocket, translation REST) at once.

### Web (PWA)

```bash
flutter build web --release \
  --dart-define=PROXY_HOST=your-worker.your-account.workers.dev
# Output: build/web/ — deploy to Cloudflare Pages, Firebase Hosting, Netlify, etc.
```

### Android

```bash
flutter build apk --release \
  --dart-define=PROXY_HOST=your-worker.your-account.workers.dev
# or
flutter build appbundle --release \
  --dart-define=PROXY_HOST=your-worker.your-account.workers.dev
```

### iOS

```bash
flutter build ios --release \
  --dart-define=PROXY_HOST=your-worker.your-account.workers.dev
# Then open Xcode → archive → distribute
```

### Storing the flag in CI / VS Code

```yaml
# GitHub Actions
- name: Build web
  run: flutter build web --release --dart-define=PROXY_HOST=${{ secrets.PROXY_HOST }}
```

```jsonc
// .vscode/launch.json
{
  "configurations": [{
    "name": "Chrome (prod proxy)",
    "toolArgs": ["--dart-define=PROXY_HOST=your-worker.your-account.workers.dev"]
  }]
}
```

---

## Running Code Generation

After modifying any `@freezed` model class:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point + ProviderScope
├── config/
│   └── app_config.dart                # PROXY_HOST dart-define → all endpoint URLs
├── models/
│   ├── conversation_models.dart       # ConversationState, TranslationMessage, LanguageConfig …
│   └── grok_api_models.dart           # Grok Realtime API event types + parsing
├── services/
│   ├── grok_api_service.dart          # WebSocket transport — connect/reconnect/send/receive
│   ├── grok_audio_service.dart        # Mic capture, PCM streaming, echo gating
│   ├── audio_player_service.dart      # PCM→WAV buffering + playback
│   ├── audio_player_service_web.dart  # Web Audio API playback (web target only)
│   ├── stt_service.dart               # STT WebSocket for live captions (subtitles mode)
│   ├── chat_translation_service.dart  # REST translation for subtitles mode
│   ├── preferences_service.dart       # SharedPreferences wrapper (VAD, language config)
│   ├── web_mic_service.dart           # AudioWorklet mic capture (web target only)
│   ├── ws_channel_stub.dart           # web_socket_channel native WebSocket adapter
│   └── ws_channel_web.dart            # Browser-native WebSocket adapter (web target only)
├── controllers/
│   └── conversation_controller.dart   # Riverpod StateNotifier — orchestrates the full loop
├── screens/
│   ├── language_setup_screen.dart     # Screen 1: mode + language picker
│   ├── conversation_screen.dart       # Screen 2: waveform + subtitle log
│   ├── subtitles_screen.dart          # Screen 3: full-screen live captions
│   └── settings_screen.dart          # Screen 4: VAD tuning, subtitle toggle, about
├── widgets/
│   ├── waveform_indicator.dart        # Animated mic/translate/speaker indicator
│   ├── status_badge.dart              # Listening / Translating / Speaking pill
│   ├── translation_bubble.dart        # Chat-bubble for subtitle log
│   └── language_selector.dart         # Dropdown language picker
├── router/
│   └── app_router.dart                # GoRouter configuration
└── theme/
    └── app_theme.dart                 # Material 3 theme, semantic colors

cloudflare-worker/
└── worker.js                          # Cloudflare Worker proxy (deploy this first)
```

---

## Audio Architecture

```
Microphone (16 kHz PCM16 mono)
    │
    ▼  [record (native) / AudioWorklet (web)]
GrokAudioService.micAudioChunks  (Stream<String> base64 chunks)
    │
    │  [gated: paused while _isPlaying == true → echo prevention]
    │
    ▼
GrokApiService.appendAudio()  ──→  Cloudflare Worker  ──→  wss://api.x.ai/v1/realtime
                                                                    │
                                              server_vad detects end-of-phrase
                                                                    │
                                              Grok translates + generates audio
                                                                    │
                                    ←── response.output_audio.delta (base64 PCM16) ──
                                                                    │
                                    AudioPlayerService.appendChunk()
                                    [accumulates deltas in List<Uint8List>]
                                                                    │
                                    response.output_audio.done → finishAndPlay()
                                                                    │
                                    [PCM16 → WAV → just_audio (native) / Web Audio (web)]
                                                                    │
                                                            Device Speaker
```

---

## VAD Tuning

| Setting | Default | Range | Effect |
|---|---|---|---|
| Threshold | 0.70 | 0.30 – 0.90 | Lower = picks up quieter speech |
| Silence duration | 300 ms | 200 – 800 ms | How long to wait after speech stops |

Adjust in **Settings** if translation cuts off early or lags. Changes take effect for the next session.

---

## Known MVP Limitations

1. **Echo cancellation** — mic is gated (paused) while translated audio plays. True AEC is not implemented; in reverberant rooms the mic may still pick up speaker output.
2. **Speaker alternation** — each translation turn is attributed to alternate speakers (User 1 → User 2 → User 1 …). If one person speaks multiple phrases in a row, the attribution will drift. A production version would verify direction via language-detection metadata from Whisper.
3. **Bluetooth routing** — no per-earbud audio routing. Single output stream to the default audio device.
4. **Rate limiting** — the Cloudflare proxy has no built-in rate limiter. Set a spend alert on your xAI account and add Cloudflare rate limiting before public launch.

---

## Environment Variables

| Variable | Where | Purpose |
|---|---|---|
| `PROXY_HOST` | `--dart-define` at build/run time | Cloudflare Worker hostname (no protocol) |
| `XAI_API_KEY` | Cloudflare Worker secret | xAI API key — **never in the app** |
