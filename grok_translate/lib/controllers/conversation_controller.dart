import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/conversation_models.dart';
// kSupportedLanguages used for ISO code → display name lookup
import '../models/grok_api_models.dart';
import '../services/audio_player_service.dart';
import '../services/grok_api_service.dart';
import '../services/grok_audio_service.dart';
import '../services/preferences_service.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final grokApiServiceProvider = Provider<GrokApiService>((ref) {
  final svc = GrokApiService();
  ref.onDispose(svc.dispose);
  return svc;
});

final grokAudioServiceProvider = Provider<GrokAudioService>((ref) {
  final svc = GrokAudioService();
  ref.onDispose(svc.dispose);
  return svc;
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final svc = AudioPlayerService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Main conversation state provider.
final conversationControllerProvider =
    StateNotifierProvider<ConversationController, ConversationState>((ref) {
  return ConversationController(
    apiService: ref.watch(grokApiServiceProvider),
    audioService: ref.watch(grokAudioServiceProvider),
    playerService: ref.watch(audioPlayerServiceProvider),
    prefsService: ref.watch(preferencesServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Orchestrates the full translation loop:
///   Mic → GrokApiService → Audio delta stream → AudioPlayerService
///
/// State machine transitions:
///   idle → listening (session started, VAD waiting for speech)
///   listening → translating (VAD detected speech end / response.created)
///   translating → speaking (first audio delta received)
///   speaking → listening (response.audio.done, playback finished)
///   * → error (on unrecoverable error)
class ConversationController extends StateNotifier<ConversationState> {
  ConversationController({
    required GrokApiService apiService,
    required GrokAudioService audioService,
    required AudioPlayerService playerService,
    required PreferencesService prefsService,
  })  : _api = apiService,
        _audio = audioService,
        _player = playerService,
        _prefs = prefsService,
        super(const ConversationState()) {
    _init();
  }

  final GrokApiService _api;
  final GrokAudioService _audio;
  final AudioPlayerService _player;
  final PreferencesService _prefs;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final _uuid = const Uuid();

  StreamSubscription? _apiEventSub;
  StreamSubscription? _micSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _playerSub;

  // Accumulate transcript deltas for the current utterance
  final StringBuffer _transcriptBuffer = StringBuffer();

  void _init() {
    // Load persisted settings
    final langCfg = _prefs.getLanguageConfig();
    final vadSettings = _prefs.getVadSettings();
    final subtitles = _prefs.getSubtitlesEnabled();

    state = state.copyWith(
      languageConfig: langCfg,
      vadThreshold: vadSettings.threshold,
      vadSilenceDurationMs: vadSettings.silenceDurationMs,
      subtitlesEnabled: subtitles,
    );

    // Listen to WebSocket events
    _apiEventSub = _api.events.listen(_handleApiEvent);
    // Listen to connection status
    _connectionSub = _api.connectionStatus.listen((connected) {
      state = state.copyWith(isConnected: connected);
    });
    // Listen to playback state to update UI
    _playerSub = _player.playingStream.listen((playing) {
      if (playing) {
        _audio.setPlaying(true);
        _setStatus(ConversationStatus.speaking);
      } else {
        _audio.setPlaying(false);
        if (state.isSessionActive) {
          _setStatus(ConversationStatus.listening);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Start a translation session.
  ///
  /// On web the Cloudflare Worker proxy holds the API key, so no key is needed
  /// from the user. On native (iOS/Android) a key must be stored in Settings.
  Future<void> startSession({String? apiKey}) async {
    // Web: proxy handles auth — skip the key check entirely.
    // Native: require a locally stored key for the direct Authorization header.
    final key = apiKey ?? _prefs.getApiKey();
    if (!kIsWeb && (key == null || key.isEmpty)) {
      _setError('API key not configured. Please enter it in Settings.');
      return;
    }

    final langCfg = state.languageConfig ?? const LanguageConfig();
    final vadSettings = VadSettings(
      threshold: state.vadThreshold,
      silenceDurationMs: state.vadSilenceDurationMs,
    );

    // Connect to Grok API
    await _api.connect(
      apiKey: key,
      languageConfig: langCfg,
      vadSettings: vadSettings,
    );

    // Start mic
    final micStarted = await _audio.startRecording();
    if (!micStarted) {
      _setError('Microphone permission denied or unavailable.');
      return;
    }

    // Forward mic chunks to the API
    _micSub = _audio.micAudioChunks.listen((b64chunk) {
      _api.appendAudio(b64chunk);
    });

    state = state.copyWith(
      isSessionActive: true,
      errorMessage: null,
      messages: [],
    );
    _setStatus(ConversationStatus.listening);
    _log.i('Session started.');
  }

  /// End the translation session and release resources.
  Future<void> endSession() async {
    await _micSub?.cancel();
    _micSub = null;
    await _audio.stopRecording();
    await _api.disconnect();
    await _player.stop();

    state = state.copyWith(
      isSessionActive: false,
      isConnected: false,
      status: ConversationStatus.idle,
      activeSpeaker: null,
      partialTranscript: '',
    );
    _log.i('Session ended.');
  }

  /// Update language config (persisted).
  Future<void> setLanguageConfig(LanguageConfig cfg) async {
    state = state.copyWith(languageConfig: cfg);
    await _prefs.setLanguageConfig(cfg);
    // If session is active, update Grok with new language config
    if (state.isSessionActive) {
      _api.updateSession(
        languageConfig: cfg,
        vadSettings: VadSettings(
          threshold: state.vadThreshold,
          silenceDurationMs: state.vadSilenceDurationMs,
        ),
      );
    }
  }

  /// Toggle subtitle visibility (persisted).
  Future<void> toggleSubtitles() async {
    final newVal = !state.subtitlesEnabled;
    state = state.copyWith(subtitlesEnabled: newVal);
    await _prefs.setSubtitlesEnabled(newVal);
  }

  /// Update VAD threshold (persisted).
  Future<void> setVadThreshold(double threshold) async {
    state = state.copyWith(vadThreshold: threshold);
    await _prefs.setVadSettings(VadSettings(
      threshold: threshold,
      silenceDurationMs: state.vadSilenceDurationMs,
    ));
  }

  /// Update VAD silence duration (persisted).
  Future<void> setVadSilenceDuration(int ms) async {
    state = state.copyWith(vadSilenceDurationMs: ms);
    await _prefs.setVadSettings(VadSettings(
      threshold: state.vadThreshold,
      silenceDurationMs: ms,
    ));
  }

  // ---------------------------------------------------------------------------
  // Event handling
  // ---------------------------------------------------------------------------

  void _handleApiEvent(GrokServerEvent event) {
    switch (event.type) {
      case GrokServerEventType.sessionCreated:
      case GrokServerEventType.sessionUpdated:
        _log.d('Session ready.');
        break;

      case GrokServerEventType.inputAudioBufferSpeechStarted:
        // Server VAD detected voice – barge-in: cancel any in-progress response
        if (state.status == ConversationStatus.speaking) {
          _api.cancelResponse();
          _player.stop();
        }
        _setStatus(ConversationStatus.listening);
        break;

      case GrokServerEventType.inputAudioBufferSpeechStopped:
        // VAD detected end of speech — wait for transcription before translating
        _setStatus(ConversationStatus.translating);
        _transcriptBuffer.clear();
        break;

      case GrokServerEventType.inputAudioTranscriptionCompleted:
        // We now have the spoken text. Fire an explicit translation command.
        // This is better than letting Grok auto-respond to raw audio.
        if (event.detectedLanguage != null) {
          _updateDetectedLanguage(event.detectedLanguage!);
        }
        final rawText = event.raw?['transcript'] as String? ??
            event.raw?['transcription']?['text'] as String? ?? '';
        if (rawText.isNotEmpty) {
          _triggerTranslation(rawText);
        }
        break;

      case GrokServerEventType.responseCreated:
        _setStatus(ConversationStatus.translating);
        break;

      case GrokServerEventType.responseAudioDelta:
        if (event.audioDelta != null && event.audioDelta!.isNotEmpty) {
          // First delta: begin buffering
          if (state.status != ConversationStatus.speaking) {
            _player.beginBuffering();
            _setStatus(ConversationStatus.speaking);
          }
          _player.appendChunk(event.audioDelta!);
        }
        break;

      case GrokServerEventType.responseAudioDone:
        // All audio deltas received – play the assembled buffer
        _player.finishAndPlay();
        break;

      case GrokServerEventType.responseAudioTranscriptDelta:
        if (event.transcriptDelta != null) {
          _transcriptBuffer.write(event.transcriptDelta);
          state = state.copyWith(
              partialTranscript: _transcriptBuffer.toString());
        }
        break;

      case GrokServerEventType.responseAudioTranscriptDone:
        final transcriptText =
            event.transcriptText ?? _transcriptBuffer.toString();
        if (transcriptText.isNotEmpty) {
          _addMessage(transcriptText);
        }
        state = state.copyWith(partialTranscript: '');
        _transcriptBuffer.clear();
        break;

      case GrokServerEventType.responseDone:
        // Fallback: extract transcript from response.done output array
        // in case response.audio_transcript.done was not sent.
        if (_transcriptBuffer.isNotEmpty) {
          _addMessage(_transcriptBuffer.toString());
          _transcriptBuffer.clear();
          state = state.copyWith(partialTranscript: '');
        } else {
          // Try to pull text from the raw event's output array
          final raw = event.raw;
          if (raw != null) {
            final response = raw['response'] as Map?;
            final output = response?['output'] as List?;
            if (output != null) {
              for (final item in output) {
                final content = ((item as Map?)?.cast<String, dynamic>())?['content'] as List?;
                if (content != null) {
                  for (final part in content) {
                    final transcript = ((part as Map?)?.cast<String, dynamic>())?['transcript'] as String?;
                    if (transcript != null && transcript.isNotEmpty) {
                      _addMessage(transcript);
                    }
                  }
                }
              }
            }
          }
        }
        break;

      case GrokServerEventType.error:
        _setError(event.errorMessage ?? 'Unknown API error');
        break;

      case GrokServerEventType.inputAudioBufferCommitted:
      case GrokServerEventType.unknown:
        break;
    }
  }

  void _addMessage(String translatedText) {
    // Determine speaker based on language detection heuristic.
    // In a real app this would use the detected language from the transcript.
    // For MVP we alternate or use a simple last-speaker tracker.
    final speaker = _inferSpeaker();
    final langCfg = state.languageConfig ?? const LanguageConfig();

    final msg = TranslationMessage(
      id: _uuid.v4(),
      speaker: speaker,
      originalText: '',
      translatedText: translatedText,
      fromLanguage: langCfg.lang1Name,
      toLanguage: langCfg.lang2Name,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, msg],
      activeSpeaker: speaker,
    );
  }

  Speaker _inferSpeaker() {
    // Simple heuristic: alternate between speakers for MVP.
    // A production version would use the detected language code from the API.
    if (state.messages.isEmpty) return Speaker.user1;
    final last = state.messages.last.speaker;
    return last == Speaker.user1 ? Speaker.user2 : Speaker.user1;
  }

  /// Called once we have a transcription — injects a text translation command.
  void _triggerTranslation(String transcript) {
    final cfg = state.languageConfig ?? const LanguageConfig();
    String fromLang;
    String toLang;

    if (cfg.autoDetect) {
      // Use detected languages if available, otherwise fallback labels
      final d1 = state.detectedLang1 ?? 'Language A';
      final d2 = state.detectedLang2 ?? 'Language B';
      // Alternate: if last speaker was lang1, translate to lang2 and vice versa
      final lastSpeaker = state.activeSpeaker;
      if (lastSpeaker == Speaker.user2) {
        fromLang = d2;
        toLang = d1;
      } else {
        fromLang = d1;
        toLang = d2;
      }
    } else {
      // Explicit pair — detect which language was spoken by checking last
      // detected language code against lang1Code
      final lastDetected = state.detectedLang1;
      if (lastDetected != null && lastDetected == cfg.lang2Name) {
        fromLang = cfg.lang2Name;
        toLang = cfg.lang1Name;
      } else {
        fromLang = cfg.lang1Name;
        toLang = cfg.lang2Name;
      }
    }

    _log.i('Translating from $fromLang → $toLang: "$transcript"');
    _api.requestTranslation(
      transcript: transcript,
      fromLanguage: fromLang,
      toLanguage: toLang,
    );
  }

  /// Map ISO-639-1 code → display name + flag using the supported languages list.
  void _updateDetectedLanguage(String isoCode) {
    final code = isoCode.toLowerCase().split('-').first; // 'en-US' → 'en'
    final match = kSupportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => SupportedLanguage(code, _capitalize(code), '🌐'),
    );

    // Assign alternately: first detection → lang1, second different → lang2
    if (state.detectedLang1 == null) {
      state = state.copyWith(
        detectedLang1: match.name,
        detectedLang1Flag: match.flag,
        activeSpeaker: Speaker.user1,
      );
    } else if (match.name == state.detectedLang1) {
      state = state.copyWith(activeSpeaker: Speaker.user1);
    } else if (state.detectedLang2 == null) {
      state = state.copyWith(
        detectedLang2: match.name,
        detectedLang2Flag: match.flag,
        activeSpeaker: Speaker.user2,
      );
    } else {
      // Both languages known — track which one is speaking
      state = state.copyWith(
        activeSpeaker: match.name == state.detectedLang2
            ? Speaker.user2
            : Speaker.user1,
      );
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _setStatus(ConversationStatus status) {
    if (state.status != status) {
      state = state.copyWith(status: status);
    }
  }

  void _setError(String message) {
    _log.e('Error: $message');
    state = state.copyWith(
      status: ConversationStatus.error,
      errorMessage: message,
    );
  }

  @override
  void dispose() {
    _apiEventSub?.cancel();
    _micSub?.cancel();
    _connectionSub?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }
}
