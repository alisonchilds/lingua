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

  bool _translateForward = true;
  String? _pendingFrom;
  String? _pendingTo;
  Speaker? _pendingSpeaker;
  bool _responseMessageAdded = false;

  // Monotonically-increasing counter; incremented on every _triggerTranslation.
  // Events arriving with a stale generation are silently ignored.
  int _currentGeneration = 0;
  int _activeGeneration = 0;

  // Prevents a second translation firing while the first is still in flight
  // (stops echo loops where speaker audio re-enters the mic).
  bool _translationInFlight = false;

  Timer? _transcriptDebounce;
  final StringBuffer _transcriptAccumulator = StringBuffer();

  void _init() {
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
      appMode: state.appMode,
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

  /// Switch between translator and subtitles mode.
  void setAppMode(AppMode mode) {
    state = state.copyWith(appMode: mode);
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

  /// Manually toggle which speaker is currently active.
  ///
  /// In auto-detect mode language detection still runs, but after a manual
  /// toggle the override takes priority until the next manual switch.
  void toggleSpeaker() {
    final current = state.activeSpeaker ?? Speaker.user1;
    final next = current == Speaker.user1 ? Speaker.user2 : Speaker.user1;
    state = state.copyWith(
      activeSpeaker: next,
      speakerOverrideActive: true,
    );
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
        _setStatus(ConversationStatus.translating);
        _transcriptBuffer.clear();
        // Shorten the debounce window now that speech has definitively stopped.
        // If we already have accumulated text, fire sooner (400ms) rather than
        // waiting the full 1.2s — the transcription event(s) should arrive shortly.
        if (_transcriptAccumulator.isNotEmpty) {
          _transcriptDebounce?.cancel();
          _transcriptDebounce = Timer(const Duration(milliseconds: 400), () {
            final full = _transcriptAccumulator.toString().trim();
            _transcriptAccumulator.clear();
            if (full.isNotEmpty) _triggerTranslation(full);
          });
        }
        break;

      case GrokServerEventType.inputAudioTranscriptionCompleted:
        if (event.detectedLanguage != null) {
          _updateDetectedLanguage(event.detectedLanguage!);
        }
        final rawText = event.raw?['transcript'] as String? ??
            (event.raw?['transcription'] as Map?)
                ?.cast<String, dynamic>()['text'] as String? ??
            '';
        // In subtitles mode there is no audio playback so there is no echo
        // risk — allow transcripts to accumulate even while a translation is
        // in flight so that back-to-back phrases are not dropped.
        final isSubtitlesMode = state.appMode == AppMode.subtitles;
        if (rawText.isNotEmpty && (!_translationInFlight || isSubtitlesMode)) {
          _transcriptAccumulator
            ..write(_transcriptAccumulator.isNotEmpty ? ' ' : '')
            ..write(rawText.trim());
          _transcriptDebounce?.cancel();
          _transcriptDebounce =
              Timer(const Duration(milliseconds: 1200), () {
            final full = _transcriptAccumulator.toString().trim();
            _transcriptAccumulator.clear();
            if (full.isNotEmpty) _triggerTranslation(full);
          });
        }
        break;

      case GrokServerEventType.responseCreated:
        _setStatus(ConversationStatus.translating);
        // Accept this response only if it belongs to the current translation
        // request.  Stale responses (e.g. a delayed reply from a request that
        // was cancelled) will have _activeGeneration < _currentGeneration.
        _activeGeneration = _currentGeneration;
        _responseMessageAdded = false;
        _transcriptBuffer.clear();
        break;

      case GrokServerEventType.responseAudioDelta:
        // Discard audio from stale/cancelled responses.
        if (_activeGeneration != _currentGeneration) break;
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
        if (_activeGeneration != _currentGeneration) break;
        // All audio deltas received – play the assembled buffer
        _player.finishAndPlay();
        break;

      case GrokServerEventType.responseAudioTranscriptDelta:
        if (_activeGeneration != _currentGeneration) break;
        if (event.transcriptDelta != null) {
          _transcriptBuffer.write(event.transcriptDelta);
          state = state.copyWith(
              partialTranscript: _transcriptBuffer.toString());
        }
        break;

      case GrokServerEventType.responseAudioTranscriptDone:
        if (_activeGeneration != _currentGeneration) break;
        final text = event.transcriptText ?? _transcriptBuffer.toString();
        if (text.isNotEmpty && !_responseMessageAdded) {
          _responseMessageAdded = true;
          _addMessage(text);
        }
        state = state.copyWith(partialTranscript: '');
        _transcriptBuffer.clear();
        break;

      // Text-only mode (subtitles): stream translated text directly
      case GrokServerEventType.responseTextDelta:
        if (_activeGeneration != _currentGeneration) break;
        if (event.transcriptDelta != null) {
          _transcriptBuffer.write(event.transcriptDelta);
          state = state.copyWith(
              partialTranscript: _transcriptBuffer.toString());
        }
        break;

      case GrokServerEventType.responseTextDone:
        if (_activeGeneration != _currentGeneration) break;
        final textDone =
            event.transcriptText ?? _transcriptBuffer.toString();
        if (textDone.isNotEmpty && !_responseMessageAdded) {
          _responseMessageAdded = true;
          _addMessage(textDone);
        }
        state = state.copyWith(partialTranscript: '');
        _transcriptBuffer.clear();
        break;

      case GrokServerEventType.responseDone:
        // Only process the completion of the current generation.
        if (_activeGeneration != _currentGeneration) break;
        if (!_responseMessageAdded && _transcriptBuffer.isNotEmpty) {
          _responseMessageAdded = true;
          _addMessage(_transcriptBuffer.toString());
          _transcriptBuffer.clear();
          state = state.copyWith(partialTranscript: '');
        }
        // Do NOT reset _responseMessageAdded here — it must stay true until
        // the next _triggerTranslation (which increments _currentGeneration
        // and resets _responseMessageAdded via responseCreated). This prevents
        // a spurious second bubble if responseDone arrives after the
        // transcript-done event already added the message.
        _translationInFlight = false; // allow next utterance

        // In translator (voice) mode clear any mic echo that crept in while
        // audio was playing back. In subtitles mode there is no playback, so
        // we must NOT clear the accumulator — it may already contain the next
        // phrase that arrived while the previous translation was in flight.
        if (state.appMode != AppMode.subtitles) {
          _transcriptAccumulator.clear();
          _transcriptDebounce?.cancel();
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
    // Use the speaker/language that _triggerTranslation set before this response
    final speaker = _pendingSpeaker ?? Speaker.user1;
    final from = _pendingFrom ?? (state.languageConfig?.lang1Name ?? 'Language 1');
    final to = _pendingTo ?? (state.languageConfig?.lang2Name ?? 'Language 2');

    // Strip any framing tags the model may accidentally echo back.
    final sanitized = _sanitizeTranslation(translatedText);

    final msg = TranslationMessage(
      id: _uuid.v4(),
      speaker: speaker,
      originalText: '',
      translatedText: sanitized,
      fromLanguage: from,
      toLanguage: to,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, msg],
      activeSpeaker: speaker,
    );
  }

  /// Called once we have a full transcript — fires one translation request.
  void _triggerTranslation(String transcript) {
    final cfg = state.languageConfig ?? const LanguageConfig();
    final isSubtitles = state.appMode == AppMode.subtitles;

    final String fromLang;
    final String toLang;
    final Speaker speaker;

    if (isSubtitles) {
      fromLang = state.detectedLang1 ?? 'the detected language';
      toLang = cfg.autoDetect ? 'English' : cfg.lang2Name;
      speaker = Speaker.user1;
    } else if (cfg.autoDetect) {
      // Prefer the manually-set speaker when the user has toggled it;
      // otherwise fall back to the auto-detected speaker.
      final currentSpeaker = state.activeSpeaker ?? Speaker.user1;
      final d1 = state.detectedLang1 ?? 'the detected language';
      // If the second language hasn't been detected yet, fall back to English
      // (or French if the first language is already English). This gives the
      // model a concrete, unambiguous target language.
      final d2 = state.detectedLang2 ??
          (d1.toLowerCase() == 'english' ? 'French' : 'English');

      if (currentSpeaker == Speaker.user1) {
        fromLang = d1; toLang = d2; speaker = Speaker.user1;
      } else {
        fromLang = d2; toLang = d1; speaker = Speaker.user2;
      }
    } else {
      // Fixed-language mode: honour manual speaker override when active.
      if (state.speakerOverrideActive) {
        final currentSpeaker = state.activeSpeaker ?? Speaker.user1;
        if (currentSpeaker == Speaker.user1) {
          fromLang = cfg.lang1Name; toLang = cfg.lang2Name; speaker = Speaker.user1;
        } else {
          fromLang = cfg.lang2Name; toLang = cfg.lang1Name; speaker = Speaker.user2;
        }
      } else {
        if (_translateForward) {
          fromLang = cfg.lang1Name; toLang = cfg.lang2Name; speaker = Speaker.user1;
        } else {
          fromLang = cfg.lang2Name; toLang = cfg.lang1Name; speaker = Speaker.user2;
        }
        // Flip direction for next utterance in fixed-language mode only
        _translateForward = !_translateForward;
      }
    }

    _pendingFrom = fromLang;
    _pendingTo = toLang;
    _pendingSpeaker = speaker;
    _responseMessageAdded = false;
    _translationInFlight = true; // block new transcriptions until response done
    _currentGeneration++; // invalidate any in-flight response from previous request

    final textOnly = state.appMode == AppMode.subtitles;
    _log.i('[${textOnly ? "text" : "voice"} $fromLang → $toLang] "$transcript"');

    _api.requestTranslation(
      transcript: transcript,
      fromLanguage: fromLang,
      toLanguage: toLang,
      textOnly: textOnly,
    );
  }

  /// Remove framing tags that the model sometimes echoes back verbatim.
  String _sanitizeTranslation(String text) {
    // Remove [TEXT_TO_TRANSLATE ...] opening tags and [/TEXT_TO_TRANSLATE] closing tags
    var cleaned = text.replaceAll(RegExp(r'\[TEXT_TO_TRANSLATE[^\]]*\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[/TEXT_TO_TRANSLATE\]'), '');
    // Strip any surrounding quotes the model may have preserved from the framing
    cleaned = cleaned.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length >= 2) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    return cleaned;
  }

  /// Map ISO-639-1 code → display name + flag using the supported languages list.
  void _updateDetectedLanguage(String isoCode) {
    final code = isoCode.toLowerCase().split('-').first; // 'en-US' → 'en'
    final match = kSupportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => SupportedLanguage(code, _capitalize(code), '🌐'),
    );

    // Register newly encountered languages regardless of manual override.
    String? newLang1 = state.detectedLang1;
    String? newLang1Flag = state.detectedLang1Flag;
    String? newLang2 = state.detectedLang2;
    String? newLang2Flag = state.detectedLang2Flag;

    if (state.detectedLang1 == null) {
      newLang1 = match.name;
      newLang1Flag = match.flag;
    } else if (match.name != state.detectedLang1 && state.detectedLang2 == null) {
      newLang2 = match.name;
      newLang2Flag = match.flag;
    }

    // If the user has manually set the speaker, respect that choice and do not
    // auto-reassign based on language detection.  The manual override persists
    // until the user taps the toggle again.
    if (state.speakerOverrideActive) {
      state = state.copyWith(
        detectedLang1: newLang1,
        detectedLang1Flag: newLang1Flag,
        detectedLang2: newLang2,
        detectedLang2Flag: newLang2Flag,
      );
      return;
    }

    // Automatic speaker assignment based on detected language.
    Speaker nextSpeaker;
    if (state.detectedLang1 == null) {
      // First detection → User 1
      nextSpeaker = Speaker.user1;
    } else if (match.name == state.detectedLang1) {
      nextSpeaker = Speaker.user1;
    } else if (state.detectedLang2 == null) {
      // Second distinct language → User 2
      nextSpeaker = Speaker.user2;
    } else {
      nextSpeaker = match.name == state.detectedLang2
          ? Speaker.user2
          : Speaker.user1;
    }

    state = state.copyWith(
      detectedLang1: newLang1,
      detectedLang1Flag: newLang1Flag,
      detectedLang2: newLang2,
      detectedLang2Flag: newLang2Flag,
      activeSpeaker: nextSpeaker,
    );
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
    _transcriptDebounce?.cancel();
    _apiEventSub?.cancel();
    _micSub?.cancel();
    _connectionSub?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }
}
