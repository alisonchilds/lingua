# Grok Translate

**Universal real-time voice translator** powered by the [Grok Voice Agent API](https://docs.x.ai/docs/realtime-api).

Two people speak naturally in two different languages on a single shared device. Grok detects each language automatically, translates in real-time, and plays the translation through the device speaker.

---

## Screenshots

| Language Setup | Conversation (mobile) | Conversation (desktop) |
|---|---|---|
| _Language picker + API key_ | _Waveform indicator + subtitles_ | _Wide two-column layout_ |

---

## Features

- **Automatic language detection** — no manual switching needed mid-conversation
- **Real-time voice translation** via Grok Realtime WebSocket API (server VAD)
- **Full-duplex with barge-in** — interrupt translation by speaking
- **Live subtitles** (toggleable) — translated text appears as speech is rendered
- **Echo prevention** — mic is gated while translated audio plays back
- **PWA-ready** — installable on desktop browsers and Android Chrome
- **Responsive layout** — phone, tablet, and desktop all work beautifully
- **Material 3** design with light/dark mode support

---

## Tech Stack

| Concern | Library |
|---|---|
| Cross-platform UI | Flutter 3.29+ |
| State management | Riverpod 2.5+ |
| Navigation | GoRouter 14 |
| Mic capture | `record` 5.x |
| Audio playback | `just_audio` (native), Web Audio API (web) |
| WebSocket | `web_socket_channel` 3 |
| Models | Freezed + json_serializable |
| Persistence | `shared_preferences` |
| Animations | `flutter_animate` |

---

## Prerequisites

1. **Flutter 3.29+** (`flutter --version`)
2. **An xAI API key** with Realtime API access — get one at [platform.x.ai](https://platform.x.ai)
3. Chrome / Edge 100+ for web, or a physical iOS/Android device for native

---

## Quick Start

```bash
# 1. Clone and enter the project
cd grok_translate

# 2. Install dependencies
flutter pub get

# 3a. Run on Chrome (PWA dev mode)
flutter run -d chrome

# 3b. Run on a connected Android device
flutter run -d android

# 3c. Run on iOS simulator
flutter run -d ios
```

On first launch you will be prompted to enter your xAI API key. It is stored locally on the device via `shared_preferences` and never leaves the app.

---

## Build for Production

### Web (PWA)

```bash
flutter build web --release --web-renderer canvaskit
# Output: build/web/
# Deploy to any static host (Vercel, Firebase Hosting, Netlify, etc.)
```

For HTTPS hosting (required for microphone access in browsers):
```bash
# Example: Firebase
firebase deploy --only hosting
```

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
# Then open Xcode → archive → distribute
```

---

## Running Code Generation

After modifying any `@freezed` model class run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Project Structure

```
lib/
├── main.dart                        # App entry point + ProviderScope
├── models/
│   ├── conversation_models.dart     # ConversationState, TranslationMessage, LanguageConfig, VadSettings
│   └── grok_api_models.dart         # Grok Realtime API event models
├── services/
│   ├── grok_api_service.dart        # WebSocket transport (connect/reconnect/send/receive)
│   ├── grok_audio_service.dart      # Mic capture, PCM streaming, echo gating
│   ├── audio_player_service.dart    # PCM→WAV buffering + playback (just_audio / Web Audio)
│   ├── audio_player_service_web.dart # Web-only Web Audio API implementation
│   └── preferences_service.dart    # SharedPreferences wrapper
├── controllers/
│   └── conversation_controller.dart # Riverpod StateNotifier – orchestrates the full loop
├── screens/
│   ├── language_setup_screen.dart   # Screen 1: language picker + API key
│   ├── conversation_screen.dart     # Screen 2: waveform + subtitle log
│   └── settings_screen.dart        # Screen 3: VAD tuning, subtitle toggle, about
├── widgets/
│   ├── waveform_indicator.dart      # Animated mic/waveform/speaker indicator
│   ├── status_badge.dart           # Listening / Translating / Speaking pill
│   ├── translation_bubble.dart     # Chat-bubble for subtitle log
│   ├── language_selector.dart      # Dropdown language picker
│   └── api_key_dialog.dart         # API key entry dialog
├── router/
│   └── app_router.dart             # GoRouter configuration
└── theme/
    └── app_theme.dart              # Material 3 theme, semantic colors
```

---

## Audio Architecture

```
Microphone (24 kHz PCM16 mono)
    │
    ▼  [record package – cross-platform]
GrokAudioService.micAudioChunks  (Stream<String> base64 chunks)
    │
    │  [gated: paused while isPlaying == true → echo prevention]
    │
    ▼
GrokApiService.appendAudio()  ──→  WebSocket (wss://api.x.ai/v1/realtime)
                                         │
                     server_vad detects end-of-phrase
                                         │
                     Grok translates + generates audio
                                         │
                    ←── response.audio.delta (base64 PCM16) ──
                                         │
                    AudioPlayerService.appendChunk()
                    [accumulates deltas]
                                         │
                    response.audio.done → AudioPlayerService.finishAndPlay()
                                         │
                    [PCM16 → WAV → just_audio (native) / Web Audio API (web)]
                                         │
                                  Device Speaker
```

---

## VAD Tuning

| Setting | Default | Range | Effect |
|---|---|---|---|
| Threshold | 0.60 | 0.30 – 0.90 | Lower = picks up quieter speech |
| Silence duration | 400 ms | 200 – 800 ms | How long to wait after speech stops |

The Grok API handles VAD server-side (`server_vad`). These parameters are sent in the `session.update` message. Adjust them in **Settings** if the app cuts off or delays translation.

---

## Known MVP Limitations

1. **Echo cancellation**: Uses simple playback gating (mic paused while speaker plays). True AEC is not implemented; in noisy or reverberant rooms, the mic may still pick up speaker output.
2. **Speaker identification**: Alternates between User 1 / User 2 heuristically. A production version would use language detection metadata from the Whisper transcription.
3. **Bluetooth routing**: No per-earbud audio routing. Single output stream to the default audio output device.
4. **API key storage**: The key is stored in `SharedPreferences` (plain local storage). For production, use the platform keychain / secure enclave.
5. **WebSocket on web**: Custom headers (including `Authorization`) cannot be sent from browser WebSocket connections. The MVP connects without an `Authorization` header. You **must** use a backend proxy in production to avoid exposing the API key in the browser.
6. **Partial speaker detection**: Subtitle bubbles alternate speakers as a placeholder; language detection from the transcript would be needed for accurate attribution.

---

## Environment Variables

| Variable | Usage |
|---|---|
| `XAI_API_KEY` | Not read by the app at build time – entered by the user at runtime |

---

## Contributing

PRs welcome. Please run `flutter analyze` and `flutter test` before submitting.

```bash
flutter analyze   # must return "No issues found"
flutter test      # smoke tests
```
