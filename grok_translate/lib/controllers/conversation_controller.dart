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

  // Prevents a second translation firing while the first is still in flight
  // (stops echo loops where speaker audio re-enters the mic).
  bool _translationInFlight = false;

  // Set to true in startSession(); cleared when session.updated is received.
  // The mic is only started after session.updated so that the server has
  // applied create_response:false before any audio arrives — prevents the
  // default assistant auto-response firing in the brief window between
  // WebSocket open and session.update being processed.
  bool _pendingSessionReady = false;

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

    // Mic is started in _onSessionReady() once session.updated is received.
    // This prevents audio reaching the server while it still has default
    // (assistant) settings — the window between WebSocket open and
    // session.update being processed can cause unwanted auto-responses.
    _pendingSessionReady = true;

    state = state.copyWith(
      isSessionActive: true,
      errorMessage: null,
      messages: [],
    );
    _setStatus(ConversationStatus.listening);
    _log.i('Session started — waiting for session.updated before mic.');
  }

  /// End the translation session and release resources.
  Future<void> endSession() async {
    _pendingSessionReady = false;
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
        _log.d('Session created (waiting for session.updated).');
        break;

      case GrokServerEventType.sessionUpdated:
        _log.d('Session updated — server has applied our settings.');
        if (_pendingSessionReady) {
          _pendingSessionReady = false;
          _onSessionReady();
        }
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
        final rawText = (event.raw?['transcript'] as String? ??
                (event.raw?['transcription'] as Map?)
                    ?.cast<String, dynamic>()['text'] as String? ??
                '')
            .trim();
        final isSubtitlesMode = state.appMode == AppMode.subtitles;
        // Skip duplicate transcriptions — VAD sometimes fires multiple
        // events for the same audio segment, which causes doubled output
        // (e.g. "Guten Tag Guten Tag" → "Good day. Good day.").
        final alreadyInAccumulator =
            _transcriptAccumulator.toString().trim() == rawText ||
            _transcriptAccumulator.toString().trim().endsWith(rawText);
        if (rawText.isNotEmpty &&
            !alreadyInAccumulator &&
            (!_translationInFlight || isSubtitlesMode)) {
          _transcriptAccumulator
            ..write(_transcriptAccumulator.isNotEmpty ? ' ' : '')
            ..write(rawText);
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
        _responseMessageAdded = false;
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
        if (event.transcriptDelta != null) {
          _transcriptBuffer.write(event.transcriptDelta);
          // Strip the LANG:[code] prefix from the streaming preview.
          // The model may use a newline OR a space after the code.
          final raw = _transcriptBuffer.toString();
          final langPrefixMatch =
              RegExp(r'^LANG:[a-zA-Z]{2,3}\s+').firstMatch(raw);
          final visible = langPrefixMatch != null
              ? raw.substring(langPrefixMatch.end)
              : raw.startsWith('LANG:')
                  ? '' // prefix still streaming, hide until complete
                  : raw;
          state = state.copyWith(partialTranscript: visible);
        }
        break;

      case GrokServerEventType.responseTextDone:
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
        if (!_responseMessageAdded && _transcriptBuffer.isNotEmpty) {
          _responseMessageAdded = true;
          _addMessage(_transcriptBuffer.toString());
          _transcriptBuffer.clear();
          state = state.copyWith(partialTranscript: '');
        }
        _responseMessageAdded = false;
        _translationInFlight = false;
        // Do NOT call clearConversationHistory() here. If the user has
        // already started speaking the next phrase, its VAD audio item may
        // be pending transcription. Deleting it here would cancel that
        // transcription and silently stop the session. Cleanup happens at
        // the start of requestTranslation() for the next phrase instead.

        if (state.appMode != AppMode.subtitles) {
          // Translator mode: clear mic echo that crept in during playback.
          _transcriptAccumulator.clear();
          _transcriptDebounce?.cancel();
        } else {
          _resetSubtitlesToListening();
        }
        break;

      case GrokServerEventType.error:
        final errMsg = event.errorMessage ?? 'Unknown API error';
        // Non-critical errors: item deletes hitting already-removed items,
        // or response.cancel with no active response. Log only — do not
        // surface as a UI error banner.
        final isNonCritical = errMsg.toLowerCase().contains('not found') ||
            errMsg.toLowerCase().contains('no response') ||
            errMsg.toLowerCase().contains('cancel');
        if (isNonCritical) {
          _log.w('Non-critical API error (suppressed): $errMsg');
          // In subtitles mode make sure we return to listening even after
          // a suppressed error so the session doesn't silently get stuck.
          if (state.appMode == AppMode.subtitles) {
            _resetSubtitlesToListening();
          }
        } else {
          _setError(errMsg);
        }
        break;

      case GrokServerEventType.inputAudioBufferCommitted:
      case GrokServerEventType.unknown:
        break;
    }
  }

  void _addMessage(String translatedText) {
    final speaker = _pendingSpeaker ?? Speaker.user1;
    final from = _pendingFrom ?? (state.languageConfig?.lang1Name ?? 'Language 1');
    final to = _pendingTo ?? (state.languageConfig?.lang2Name ?? 'Language 2');

    // Extract LANG:[code] prefix that the model adds in subtitles mode.
    // Work entirely on the trimmed string so match indices are consistent.
    String textForSanitization = translatedText.trim();
    if (textForSanitization.startsWith('LANG:')) {
      // Find the end of the language code (2-3 letters after the colon)
      final wsIdx = textForSanitization.indexOf(RegExp(r'\s'), 5);
      if (wsIdx > 5) {
        final code = textForSanitization.substring(5, wsIdx);
        if (code.length <= 3) {
          if (state.detectedLang1 == null) {
            _updateDetectedLanguage(code.toLowerCase());
          }
          textForSanitization = textForSanitization.substring(wsIdx).trimLeft();
        }
      }
    }

    // Strip any framing tags the model may accidentally echo back.
    final sanitized = _sanitizeTranslation(textForSanitization);

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
      // Use the detected language name if available; fall back to 'the spoken
      // language' so the translation command is still grammatically sensible
      // and doesn't say "from the detected language" in the subtitle log.
      fromLang = state.detectedLang1 ?? '';
      toLang = cfg.autoDetect ? 'English' : cfg.lang2Name;
      speaker = Speaker.user1;
    } else if (cfg.autoDetect) {
      // Use the speaker identity from language detection rather than a blind
      // toggle. This correctly handles the case where the same person speaks
      // twice in a row and avoids passing 'the other language' (a meaningless
      // target) to the model when only one language has been identified yet.
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
      if (_translateForward) {
        fromLang = cfg.lang1Name; toLang = cfg.lang2Name; speaker = Speaker.user1;
      } else {
        fromLang = cfg.lang2Name; toLang = cfg.lang1Name; speaker = Speaker.user2;
      }
      // Flip direction for next utterance in fixed-language mode only
      _translateForward = !_translateForward;
    }

    _pendingFrom = fromLang;
    _pendingTo = toLang;
    _pendingSpeaker = speaker;
    _responseMessageAdded = false;
    _translationInFlight = true; // block new transcriptions until response done

    final textOnly = state.appMode == AppMode.subtitles;
    _log.i('[${textOnly ? "text" : "voice"} $fromLang → $toLang] "$transcript"');

    _api.requestTranslation(
      transcript: transcript,
      fromLanguage: fromLang,
      toLanguage: toLang,
      textOnly: textOnly,
    );
  }

  /// Remove any prompt framing the model may echo back verbatim.
  String _sanitizeTranslation(String text) {
    var cleaned = text;
    // Fallback LANG: strip in case _addMessage() didn't catch it
    cleaned = cleaned.replaceAll(RegExp(r'^LANG:[a-zA-Z]{2,3}\s+', multiLine: false), '');
    // Strip trailing "end" / "END" markers the model sometimes appends
    cleaned = cleaned.replaceAll(RegExp(r'\s+[Ee][Nn][Dd]\s*$'), '');
    // Strip any injected task-header lines the model might parrot back
    cleaned = cleaned.replaceAll(RegExp(r'^SUBTITLE_TASK\s*\|[^\n]*\n?', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^TRANSLATE\s*\|[^\n]*\n?', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^INPUT:\s*', multiLine: true), '');
    // Old [TEXT_TO_TRANSLATE ...] tags
    cleaned = cleaned.replaceAll(RegExp(r'\[TEXT_TO_TRANSLATE[^\]]*\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[/TEXT_TO_TRANSLATE\]'), '');
    // Strip surrounding quotes
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

  /// Called when session.updated is received — starts the mic now that the
  /// server has applied create_response:false and our translator instructions.
  Future<void> _onSessionReady() async {
    if (_micSub != null) return; // already started (reconnect path)
    final micStarted = await _audio.startRecording();
    if (!micStarted) {
      _setError('Microphone permission denied or unavailable.');
      return;
    }
    _micSub = _audio.micAudioChunks.listen((b64chunk) {
      _api.appendAudio(b64chunk);
    });
    _log.i('Mic started after session.updated confirmed.');
  }

  /// Reset subtitles mode back to listening after a translation completes or
  /// an error occurs. Subtitles mode has no audio player, so the normal
  /// player-callback path never fires — this must be called explicitly.
  void _resetSubtitlesToListening() {
    if (!state.isSessionActive) return;
    _translationInFlight = false;
    _transcriptBuffer.clear();
    state = state.copyWith(partialTranscript: '');
    _setStatus(ConversationStatus.listening);
  }

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
