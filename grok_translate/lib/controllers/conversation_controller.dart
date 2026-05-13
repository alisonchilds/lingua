import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation_models.dart';
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

/// Orchestrates the full translation loop for both Translator and Subtitles
/// modes through a single persistent Realtime API WebSocket.
///
/// ── Unified architecture ──────────────────────────────────────────────────
///
///   Both modes use the same pipeline:
///     Mic → GrokApiService (Realtime WS) → VAD → Whisper transcript
///       → _triggerTranslation() → requestTranslation()
///         Translator: audio + text response → AudioPlayerService → speaker
///         Subtitles:  text-only response   → partialTranscript → messages
///
///   The previous separate STT WebSocket + REST translate path for Subtitles
///   has been removed. The Realtime API handles both modes natively.
///
/// ── State machine ─────────────────────────────────────────────────────────
///   idle       → listening   (session started, VAD waiting for speech)
///   listening  → translating (VAD speech-stop / transcript accumulator fires)
///   translating→ speaking    (first audio delta received — Translator only)
///   speaking   → listening   (audio.done + playback complete)
///   *          → error       (unrecoverable error)
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

  // Translator mode: true while a response is in-flight (including audio
  // playback). Prevents echo from the speaker triggering a second translation.
  // Subtitles mode: true while the text response is being generated.
  bool _translationInFlight = false;

  // Set to true when the session starts; cleared when session.updated is
  // received. The mic only starts after session.updated so the server has
  // applied create_response:false before any audio arrives.
  bool _pendingSessionReady = false;

  Timer? _transcriptDebounce;
  final StringBuffer _transcriptAccumulator = StringBuffer();

  // Last text passed to _triggerTranslation. Backstop against duplicate calls
  // that slip through the accumulator dedup. Cleared after each completed
  // translation cycle so the same phrase can be translated again next utterance.
  String? _lastTranslatedText;

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

    _apiEventSub = _api.events.listen(_handleApiEvent);

    // Both modes use the Realtime API — track connection status for both.
    _connectionSub = _api.connectionStatus.listen((connected) {
      state = state.copyWith(isConnected: connected);
    });

    // _translationInFlight is cleared here (not in responseDone) for
    // Translator mode so the lock persists through full audio playback.
    // Any audio that slips past the mic gate before playing=false would
    // otherwise trigger a phantom second translation.
    _playerSub = _player.playingStream.listen((playing) {
      if (playing) {
        _audio.setPlaying(true);
        _setStatus(ConversationStatus.speaking);
      } else {
        _audio.setPlaying(false);
        _translationInFlight = false;
        _lastTranslatedText = null; // allow same phrase on the next utterance
        if (state.isSessionActive) {
          _setStatus(ConversationStatus.listening);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Start a session. Both Translator and Subtitles modes connect to the same
  /// Grok Realtime WebSocket; the session `appMode` drives the system prompt,
  /// response modalities, and translation direction logic.
  Future<void> startSession() async {
    if (state.isSessionActive) await endSession();

    state = state.copyWith(
      isSessionActive: true,
      errorMessage: null,
      messages: [],
    );
    _setStatus(ConversationStatus.listening);

    final langCfg = state.languageConfig ?? const LanguageConfig();
    final vadSettings = VadSettings(
      threshold: state.vadThreshold,
      silenceDurationMs: state.vadSilenceDurationMs,
    );

    await _api.connect(
      languageConfig: langCfg,
      vadSettings: vadSettings,
      appMode: state.appMode,
    );

    // Mic starts in _onSessionReady() once session.updated is received,
    // ensuring create_response:false is applied before any audio arrives.
    _pendingSessionReady = true;
    _log.i('Session starting (${state.appMode.name}) — '
        'waiting for session.updated before mic.');
  }

  /// End the session and release all resources.
  Future<void> endSession() async {
    _pendingSessionReady = false;
    _transcriptDebounce?.cancel();
    _transcriptAccumulator.clear();
    _lastTranslatedText = null;
    // Always reset speaker alternation so the next session opens with User1.
    _translateForward = true;

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
      // Clear detected languages so stale badges don't show on next session.
      detectedLang1: null,
      detectedLang2: null,
      detectedLang1Flag: null,
      detectedLang2Flag: null,
    );
    _log.i('Session ended.');
  }

  /// Switch between Translator and Subtitles mode.
  void setAppMode(AppMode mode) {
    state = state.copyWith(appMode: mode);
  }

  /// Update language config (persisted). Updates the live session if active.
  Future<void> setLanguageConfig(LanguageConfig cfg) async {
    state = state.copyWith(languageConfig: cfg);
    await _prefs.setLanguageConfig(cfg);
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
        // Barge-in (Translator): cancel any in-progress audio response.
        if (state.status == ConversationStatus.speaking) {
          _api.cancelResponse();
          _player.stop();
        }
        // Subtitles: reset to listening and clear the previous translation's
        // streamed text so the screen is clean before the new phrase arrives.
        if (state.appMode == AppMode.subtitles) {
          _resetToListening();
        } else {
          _setStatus(ConversationStatus.listening);
        }
        break;

      case GrokServerEventType.inputAudioBufferSpeechStopped:
        _setStatus(ConversationStatus.translating);
        _transcriptBuffer.clear();
        // If we already have accumulated text, fire a shorter debounce now
        // that speech has definitively stopped (transcription should arrive soon).
        if (_transcriptAccumulator.isNotEmpty) {
          _transcriptDebounce?.cancel();
          _transcriptDebounce = Timer(
            Duration(
                milliseconds:
                    state.appMode == AppMode.subtitles ? 300 : 400),
            () {
              var full = _transcriptAccumulator.toString().trim();
              _transcriptAccumulator.clear();
              if (state.appMode == AppMode.subtitles) {
                full = _deduplicateEcho(full);
              }
              if (full.isNotEmpty) _triggerTranslation(full);
            },
          );
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

        if (rawText.isEmpty || _translationInFlight) break;

        if (state.appMode == AppMode.subtitles) {
          // Subtitles: each VAD commit is one complete phrase — use the most
          // recent (most accurate) event, never accumulate multiple events.
          _transcriptAccumulator.clear();
          _transcriptAccumulator.write(rawText);
        } else {
          // Translator: accumulate across multi-commit phrases with dedup.
          // Three cases:
          //   (1) exact dup          → skip
          //   (2) new is subset      → skip (accumulated is more complete)
          //   (3) new is superset    → replace (so we don't get "Yeah Yeah yeah.")
          //   (4) genuinely new text → append
          final accumulated = _transcriptAccumulator.toString().trim();
          if (accumulated == rawText) break;                                // (1)
          if (accumulated.isNotEmpty && accumulated.endsWith(rawText)) break; // (2)
          if (accumulated.isNotEmpty && rawText.startsWith(accumulated)) {
            _transcriptAccumulator.clear(); // (3) replace
          }
          _transcriptAccumulator // (4)
            ..write(_transcriptAccumulator.isNotEmpty ? ' ' : '')
            ..write(rawText);
        }

        _transcriptDebounce?.cancel();
        // Subtitles phrases are short → 600 ms is enough.
        // Translator allows 1 200 ms so multi-commit phrases can accumulate.
        _transcriptDebounce = Timer(
          Duration(
              milliseconds:
                  state.appMode == AppMode.subtitles ? 600 : 1200),
          () {
            var full = _transcriptAccumulator.toString().trim();
            _transcriptAccumulator.clear();
            if (state.appMode == AppMode.subtitles) {
              full = _deduplicateEcho(full);
            }
            if (full.isNotEmpty && !_translationInFlight) {
              _triggerTranslation(full);
            }
          },
        );
        break;

      case GrokServerEventType.responseCreated:
        _setStatus(ConversationStatus.translating);
        _responseMessageAdded = false;
        break;

      case GrokServerEventType.responseAudioDelta:
        if (event.audioDelta != null && event.audioDelta!.isNotEmpty) {
          if (state.status != ConversationStatus.speaking) {
            _player.beginBuffering();
            _setStatus(ConversationStatus.speaking);
          }
          _player.appendChunk(event.audioDelta!);
        }
        break;

      case GrokServerEventType.responseAudioDone:
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

      // Text-only response (Subtitles mode): stream translated text directly.
      case GrokServerEventType.responseTextDelta:
        if (event.transcriptDelta != null) {
          _transcriptBuffer.write(event.transcriptDelta);
          // Strip the LANG:[code] prefix while streaming — hide it until the
          // full code is received, then show only the translated text.
          final raw = _transcriptBuffer.toString();
          final langPrefixMatch =
              RegExp(r'^LANG:[a-zA-Z]{2,3}\s+').firstMatch(raw);
          final visible = langPrefixMatch != null
              ? raw.substring(langPrefixMatch.end)
              : raw.startsWith('LANG:')
                  ? ''
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
        // Accumulated text for THIS turn is done — clear it so a new
        // utterance starts fresh. Do NOT call clearConversationHistory() here:
        // it is called at the start of the NEXT requestTranslation(), by which
        // point transcription is guaranteed complete. Calling it here risks
        // deleting a VAD item that is mid-transcription if the user speaks
        // while the current response is still being generated.
        _transcriptAccumulator.clear();
        _transcriptDebounce?.cancel();

        if (state.appMode == AppMode.subtitles) {
          // Text-only: no audio playback, release the lock immediately.
          _translationInFlight = false;
          _resetToListening();
        }
        // Translator: _translationInFlight is released by the playing=false
        // listener after audio finishes — not here.
        break;

      case GrokServerEventType.error:
        final errMsg = event.errorMessage ?? 'Unknown API error';
        final isNonCritical = errMsg.toLowerCase().contains('not found') ||
            errMsg.toLowerCase().contains('no response') ||
            errMsg.toLowerCase().contains('cancel');
        if (isNonCritical) {
          _log.w('Non-critical API error (suppressed): $errMsg');
          // Ensure the session returns to listening regardless of mode so it
          // doesn't silently deadlock with _translationInFlight stuck true.
          _resetToListening();
        } else {
          // Also release the in-flight lock on hard errors so the session
          // can be restarted cleanly without requiring endSession().
          _translationInFlight = false;
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

    // Extract LANG:[code] prefix the model adds in Subtitles mode.
    String textForSanitization = translatedText.trim();
    if (textForSanitization.startsWith('LANG:')) {
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
  ///
  /// Both Translator and Subtitles modes call this method.
  ///   Translator: audio + text response, bidirectional speaker alternation.
  ///   Subtitles:  text-only response, always FROM detected lang TO target.
  void _triggerTranslation(String transcript) {
    // Backstop: if the accumulator dedup lets the same text through twice
    // (e.g. a race between the speechStopped shortcut and the 1200 ms timer),
    // silently drop the second call rather than firing a duplicate request.
    if (transcript == _lastTranslatedText) {
      _log.d('Duplicate transcript suppressed: "$transcript"');
      return;
    }
    _lastTranslatedText = transcript;

    final cfg = state.languageConfig ?? const LanguageConfig();

    final String fromLang;
    final String toLang;
    final Speaker speaker;

    if (state.appMode == AppMode.subtitles) {
      fromLang = state.detectedLang1 ?? 'the detected language';
      toLang = cfg.autoDetect ? 'English' : cfg.lang2Name;
      speaker = Speaker.user1;

      // When the detected language matches the target there is nothing to
      // translate. Show the raw transcript directly and skip the model call —
      // avoids "I appreciate that." / "Sure!" commentary from the model when
      // it is asked to translate English → English.
      if (state.detectedLang1 != null &&
          state.detectedLang1!.toLowerCase() == toLang.toLowerCase()) {
        _pendingFrom = fromLang;
        _pendingTo = toLang;
        _pendingSpeaker = speaker;
        _addMessage(transcript);
        _resetToListening();
        return;
      }
    } else if (cfg.autoDetect) {
      // Translator auto-detect: _translateForward gives reliable alternation
      // regardless of whether the API returns a language code.
      final d1 = state.detectedLang1 ?? 'the detected language';
      final d2 = state.detectedLang2 ??
          (d1.toLowerCase() == 'english' ? 'French' : 'English');
      if (_translateForward) {
        fromLang = d1; toLang = d2; speaker = Speaker.user1;
      } else {
        fromLang = d2; toLang = d1; speaker = Speaker.user2;
      }
      _translateForward = !_translateForward;
    } else {
      // Translator fixed-language: alternate speakers.
      if (_translateForward) {
        fromLang = cfg.lang1Name; toLang = cfg.lang2Name; speaker = Speaker.user1;
      } else {
        fromLang = cfg.lang2Name; toLang = cfg.lang1Name; speaker = Speaker.user2;
      }
      _translateForward = !_translateForward;
    }

    _pendingFrom = fromLang;
    _pendingTo = toLang;
    _pendingSpeaker = speaker;
    _responseMessageAdded = false;
    _translationInFlight = true;

    final textOnly = state.appMode == AppMode.subtitles;
    _log.i('[${textOnly ? "subtitle" : "voice"} $fromLang → $toLang] "$transcript"');

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
    // Strip LANG:[code] markers wherever they appear in the string.
    // The model sometimes places them mid-output ("Heh LANG:en Heh") instead
    // of always at the start, so a global replace is safer than ^-anchored.
    cleaned = cleaned.replaceAll(RegExp(r'LANG:[a-zA-Z]{2,5}\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+[Ee][Nn][Dd]\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^SUBTITLE_TASK\s*\|[^\n]*\n?', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^TRANSLATE\s*\|[^\n]*\n?', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^INPUT:\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[TEXT_TO_TRANSLATE[^\]]*\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[/TEXT_TO_TRANSLATE\]'), '');
    cleaned = cleaned.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length >= 2) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    return cleaned;
  }

  /// Map ISO-639-1 code → display name + flag using the supported languages list.
  void _updateDetectedLanguage(String isoCode) {
    final code = isoCode.toLowerCase().split('-').first;
    final match = kSupportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => SupportedLanguage(code, _capitalize(code), '🌐'),
    );

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
  /// server has applied create_response:false and the session instructions.
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

  /// Remove consecutive sentence repetitions caused by microphone echo.
  ///
  /// When the device mic picks up room echo, Whisper transcribes the original
  /// speech and its reflection as one segment: "anything, Jeff? anything, Jeff?"
  /// This strips the duplicate so only one copy reaches the subtitle display.
  ///
  /// Heuristic: find the first sentence boundary ([.!?] followed by whitespace),
  /// then check whether the remainder of the string matches the first sentence.
  /// Applies only to subtitles mode where each VAD commit is one phrase.
  String _deduplicateEcho(String text) {
    final t = text.trim();
    if (t.length < 6) return t;

    final boundary = RegExp(r'[.!?]\s+');
    final m = boundary.firstMatch(t);
    if (m == null) return t;

    final first = t.substring(0, m.end).trim();
    final rest = t.substring(m.end).trim();

    // Strip trailing punctuation for a looser comparison so
    // "Yeah?" vs "Yeah" (or period vs question mark) still deduplicate.
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

    if (norm(rest) == norm(first) ||
        norm(rest).startsWith(norm(first))) {
      return first;
    }
    return t;
  }

  /// Reset back to listening after a Subtitles translation completes or an
  /// error occurs (no audio playback path exists to trigger the reset).
  void _resetToListening() {
    if (!state.isSessionActive) return;
    _translationInFlight = false;
    _lastTranslatedText = null; // allow same phrase on the next utterance
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
