import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation_models.dart';
import '../models/grok_api_models.dart';
import '../services/audio_player_service.dart';
import '../services/grok_api_service.dart';
import '../services/grok_audio_service.dart';
import '../services/preferences_service.dart';
import '../utils/transcript_correction.dart';
import '../utils/transcript_language_hint.dart';
import '../utils/translation_guard.dart';
import '../utils/translation_text_cleanup.dart';

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
  String? _pendingTranscript;     // original spoken/typed text shown small in the bubble
  String? _previousOriginalText; // transcript of the last completed translation (biDir context)
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

  /// Whether the current utterance already used a strict-prompt retry.
  bool _strictRetryUsed = false;

  /// Translator mode: translation text held until audio is ready to play.
  String? _pendingTranslatedText;

  bool _translatorMessageCommitted = false;

  /// Only the first audio transcript.done per response is staged (xAI may send
  /// both response.audio_transcript.done and response.output_audio_transcript.done).
  bool _translatorTranscriptDoneHandled = false;

  // Replay cache: maps message ID → WAV bytes so the user can re-hear any
  // past translation. Capped at 50 entries to keep memory bounded.
  final _audioCache = <String, Uint8List>{};

  // Post-playback echo gate: after audio playback finishes, room reverberation
  // picked up by the mic can trigger a phantom second translation. This timer
  // blocks new transcriptions for a short window after playing=false so that
  // the acoustic echo has time to die down before VAD starts listening again.
  Timer? _postPlaybackTimer;

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
        // Start the post-playback echo gate. Room reverberation from the
        // speaker can persist for several hundred ms after audio ends — block
        // new transcriptions for this window to prevent phantom translations.
        _postPlaybackTimer?.cancel();
        _postPlaybackTimer = Timer(const Duration(milliseconds: 800), () {});
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
      voiceId: _prefs.getVoiceId(),
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
    _postPlaybackTimer?.cancel();
    _transcriptAccumulator.clear();
    _lastTranslatedText = null;
    _strictRetryUsed = false;
    _audioCache.clear();
    _previousOriginalText = null;
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

  /// Update VAD threshold (persisted). Applies to the live session when active.
  Future<void> setVadThreshold(double threshold) async {
    state = state.copyWith(vadThreshold: threshold);
    await _prefs.setVadSettings(VadSettings(
      threshold: threshold,
      silenceDurationMs: state.vadSilenceDurationMs,
    ));
    _applySessionSettingsIfActive();
  }

  /// Update VAD silence duration (persisted). Applies to the live session when active.
  Future<void> setVadSilenceDuration(int ms) async {
    state = state.copyWith(vadSilenceDurationMs: ms);
    await _prefs.setVadSettings(VadSettings(
      threshold: state.vadThreshold,
      silenceDurationMs: ms,
    ));
    _applySessionSettingsIfActive();
  }

  Future<void> setVoiceId(String voiceId) async {
    await _prefs.setVoiceId(voiceId);
    _applySessionSettingsIfActive(voiceId: voiceId);
  }

  void _applySessionSettingsIfActive({String? voiceId}) {
    if (!state.isSessionActive) return;
    final langCfg = state.languageConfig ?? const LanguageConfig();
    _api.updateSession(
      languageConfig: langCfg,
      vadSettings: VadSettings(
        threshold: state.vadThreshold,
        silenceDurationMs: state.vadSilenceDurationMs,
      ),
      voiceId: voiceId ?? _prefs.getVoiceId(),
    );
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
                    state.appMode == AppMode.subtitles ? 200 : 300),
            () {
              var full = _transcriptAccumulator.toString().trim();
              _transcriptAccumulator.clear();
              full = _cleanInputTranscript(full);
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
        // Drop transcriptions that arrive during the post-playback echo window.
        if (state.appMode == AppMode.translator &&
            (_postPlaybackTimer?.isActive ?? false)) {
          _log.d('Post-playback echo suppressed: "$rawText"');
          break;
        }

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
        // Subtitles: 500 ms. Translator: 700 ms (was 1200 ms — tightened
        // now that the architecture no longer needs the full accumulation window).
        _transcriptDebounce = Timer(
          Duration(
              milliseconds:
                  state.appMode == AppMode.subtitles ? 500 : 700),
          () {
            var full = _transcriptAccumulator.toString().trim();
            _transcriptAccumulator.clear();
            full = _cleanInputTranscript(full);
            if (full.isNotEmpty && !_translationInFlight) {
              _triggerTranslation(full);
            }
          },
        );
        break;

      case GrokServerEventType.responseCreated:
        _setStatus(ConversationStatus.translating);
        _responseMessageAdded = false;
        _translatorTranscriptDoneHandled = false;
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
        unawaited(_onResponseAudioDone());
        break;

      case GrokServerEventType.responseAudioTranscriptDelta:
        if (event.transcriptDelta != null) {
          final merged = TranslationTextCleanup.appendTranscriptDelta(
            _transcriptBuffer.toString(),
            event.transcriptDelta!,
          );
          _transcriptBuffer
            ..clear()
            ..write(merged);
          state = state.copyWith(partialTranscript: merged);
        }
        break;

      case GrokServerEventType.responseAudioTranscriptDone:
        if (_translatorTranscriptDoneHandled) break;
        _translatorTranscriptDoneHandled = true;
        final rawDone =
            event.transcriptText ?? _transcriptBuffer.toString();
        final text = TranslationTextCleanup.deduplicateRepeatedPhrase(
          rawDone.trim(),
        );
        if (text.isNotEmpty && !_responseMessageAdded) {
          if (state.appMode == AppMode.translator) {
            if (_stageTranslatorOutput(text)) {
              _responseMessageAdded = true;
            }
          } else if (_addMessage(text)) {
            _responseMessageAdded = true;
          }
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
          if (_addMessage(textDone)) _responseMessageAdded = true;
        }
        state = state.copyWith(partialTranscript: '');
        _transcriptBuffer.clear();
        break;

      case GrokServerEventType.responseDone:
        // Translator commits on audio transcript + audio.done — never here.
        if (state.appMode == AppMode.subtitles &&
            !_responseMessageAdded &&
            _transcriptBuffer.isNotEmpty) {
          if (_addMessage(_transcriptBuffer.toString())) {
            _responseMessageAdded = true;
          }
          _transcriptBuffer.clear();
          state = state.copyWith(partialTranscript: '');
        }
        _transcriptBuffer.clear();
        if (state.appMode == AppMode.translator &&
            _pendingTranslatedText != null &&
            !_translatorMessageCommitted) {
          unawaited(_flushTranslatorCommit());
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

  /// Commits a translation to the message list after sanitization.
  ///
  /// Returns false when a strict retry was triggered (caller must not mark the
  /// response as committed yet).
  bool _addMessage(String translatedText) {
    final speaker = _pendingSpeaker ?? Speaker.user1;
    final from = _pendingFrom ?? (state.languageConfig?.lang1Name ?? 'Language 1');
    final to = _pendingTo ?? (state.languageConfig?.lang2Name ?? 'Language 2');
    final original = _pendingTranscript ?? '';

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

    if (!_strictRetryUsed &&
        TranslationGuard.shouldRetryStrict(
          output: sanitized,
          originalInput: original,
          targetLanguage: to,
        )) {
      _strictRetryUsed = true;
      _log.w(
        'Assistant-like translation detected; strict retry ($from → $to): '
        '"$sanitized"',
      );
      _abortBadTranslationResponse();
      _retryTranslationStrict();
      return false;
    }

    if (_strictRetryUsed &&
        TranslationGuard.shouldRetryStrict(
          output: sanitized,
          originalInput: original,
          targetLanguage: to,
        )) {
      _log.w(
        'Strict retry still produced assistant-like output; showing anyway: '
        '"$sanitized"',
      );
    }

    final msg = TranslationMessage(
      id: _uuid.v4(),
      speaker: speaker,
      originalText: original,
      translatedText: sanitized,
      fromLanguage: from,
      toLanguage: to,
      timestamp: DateTime.now(),
    );

    // Associate any pending WAV (built in finishAndPlay) with this message so
    // the user can replay it later. The pending reference is cleared here to
    // avoid holding it in both the cache and the AudioPlayerService.
    final wav = _player.pendingWav;
    if (wav != null) {
      _audioCache[msg.id] = wav;
      _player.clearPendingWav();
      // Keep the cache bounded — drop the oldest entry when over 50 messages.
      if (_audioCache.length > 50) {
        _audioCache.remove(_audioCache.keys.first);
      }
    }

    state = state.copyWith(
      messages: [...state.messages, msg],
      activeSpeaker: speaker,
    );
    return true;
  }

  /// Discard a bad model response (assistant drift) before a strict retry.
  void _abortBadTranslationResponse() {
    // Mark handled so a trailing response.done cannot commit duplicate text.
    _responseMessageAdded = true;
    _pendingTranslatedText = null;
    _translatorTranscriptDoneHandled = true;
    _transcriptBuffer.clear();
    _player.clearPendingWav();
    unawaited(_player.stop());
    _api.cancelResponse();
    state = state.copyWith(partialTranscript: '');
    if (state.appMode == AppMode.translator) {
      _setStatus(ConversationStatus.translating);
    }
  }

  /// Translator: validate output, stage text, and commit once audio is ready.
  bool _stageTranslatorOutput(String translatedText) {
    final original = _pendingTranscript ?? '';
    final to = _pendingTo ?? _prefs.getMyLanguageName();
    final sanitized = TranslationTextCleanup.deduplicateRepeatedPhrase(
      _sanitizeTranslation(translatedText.trim()),
    );

    if (!_strictRetryUsed &&
        TranslationGuard.shouldRetryStrict(
          output: sanitized,
          originalInput: original,
          targetLanguage: to,
        )) {
      _strictRetryUsed = true;
      _log.w('Assistant-like translation detected; strict retry: "$sanitized"');
      _abortBadTranslationResponse();
      _retryTranslationStrict();
      return false;
    }

    _pendingTranslatedText = sanitized;
    state = state.copyWith(partialTranscript: sanitized);
    return true;
  }

  Future<void> _onResponseAudioDone() async {
    if (_player.hasBufferedAudio) {
      await _player.finishAndPlay();
    }
    await _flushTranslatorCommit();
  }

  Future<void> _flushTranslatorCommit() async {
    if (state.appMode != AppMode.translator ||
        _translatorMessageCommitted ||
        _pendingTranslatedText == null) {
      return;
    }
    // Claim before any await so response.done cannot double-commit.
    _translatorMessageCommitted = true;
    final text = _pendingTranslatedText!;
    if (!_player.hasBufferedAudio && _player.pendingWav == null) {
      // Text arrived but no audio — still show the translation.
      _log.w('Translator response had no audio; showing text only.');
    }
    _finalizePendingLanguages(
      _pendingTranscript ?? '',
      _pendingFrom ?? 'auto',
      _pendingTo ?? _prefs.getMyLanguageName(),
      _prefs.getMyLanguageName(),
    );
    _addMessageDirect(text);
    _pendingTranslatedText = null;
    state = state.copyWith(partialTranscript: '');
  }

  /// Add a validated translation to the message list (no guard re-check).
  void _addMessageDirect(String translatedText) {
    final speaker = _pendingSpeaker ?? Speaker.user1;
    final from = _pendingFrom ?? (state.languageConfig?.lang1Name ?? 'Language 1');
    final to = _pendingTo ?? (state.languageConfig?.lang2Name ?? 'Language 2');
    final original = _cleanInputTranscript(_pendingTranscript ?? '');

    final msg = TranslationMessage(
      id: _uuid.v4(),
      speaker: speaker,
      originalText: original,
      translatedText: translatedText,
      fromLanguage: from,
      toLanguage: to,
      timestamp: DateTime.now(),
    );

    final wav = _player.pendingWav;
    if (wav != null) {
      _audioCache[msg.id] = wav;
      _player.clearPendingWav();
      if (_audioCache.length > 50) {
        _audioCache.remove(_audioCache.keys.first);
      }
    }

    state = state.copyWith(
      messages: [...state.messages, msg],
      activeSpeaker: speaker,
    );
  }

  /// Re-issue the current utterance with [GrokApiService.requestTranslation] strict mode.
  void _retryTranslationStrict() {
    final transcript = _pendingTranscript?.trim();
    if (transcript == null || transcript.isEmpty) {
      _translationInFlight = false;
      _resetToListening();
      return;
    }

    final fromLang = _pendingFrom ?? (state.languageConfig?.lang1Name ?? 'Language 1');
    final toLang = _pendingTo ?? (state.languageConfig?.lang2Name ?? 'Language 2');
    final textOnly = state.appMode == AppMode.subtitles;
    _responseMessageAdded = false;
    _pendingTranslatedText = null;
    _translatorMessageCommitted = false;
    _translationInFlight = true;
    _log.i('[STRICT RETRY ${textOnly ? "subtitle" : "voice"} '
        '$fromLang → $toLang] "$transcript"');

    final myLang = _prefs.getMyLanguageName();
    _api.requestTranslation(
      transcript: transcript,
      fromLanguage: fromLang,
      toLanguage: toLang,
      textOnly: textOnly,
      myLanguage: fromLang == 'auto' ? myLang : null,
      strict: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Test / debug API
  // ---------------------------------------------------------------------------

  /// Inject arbitrary text directly into the translation pipeline, bypassing
  /// the microphone and VAD. Useful for testing translation logic without
  /// needing to speak. No-op if no session is active or a translation is
  /// already in flight.
  void translateText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !state.isSessionActive || _translationInFlight) {
      return;
    }
    _log.i('[TEST INPUT] "$trimmed"');
    _triggerTranslation(trimmed);
  }

  // ---------------------------------------------------------------------------
  // Replay API
  // ---------------------------------------------------------------------------

  /// Whether [messageId] has cached audio that can be replayed.
  bool hasAudio(String messageId) => _audioCache.containsKey(messageId);

  /// Replay the audio for [messageId]. No-op if audio is unavailable or a
  /// translation is currently in flight.
  Future<void> replayMessage(String messageId) async {
    final wav = _audioCache[messageId];
    if (wav == null || _translationInFlight) return;
    await _player.playWav(wav);
  }

  /// Called once we have a full transcript — fires one translation request.
  ///
  /// Both Translator and Subtitles modes call this method.
  ///   Translator: audio + text response, bidirectional speaker alternation.
  ///   Subtitles:  text-only response, always FROM detected lang TO target.
  void _triggerTranslation(String transcript) {
    transcript = _cleanInputTranscript(transcript);
    if (transcript.isEmpty) return;
    _applyTranscriptLanguageHint(transcript);

    // Backstop: if the accumulator dedup lets the same text through twice
    // (e.g. a race between the speechStopped shortcut and the 1200 ms timer),
    // silently drop the second call rather than firing a duplicate request.
    if (transcript == _lastTranslatedText) {
      _log.d('Duplicate transcript suppressed: "$transcript"');
      return;
    }
    _lastTranslatedText = transcript;

    final cfg = state.languageConfig ?? const LanguageConfig();
    final textOnly = state.appMode == AppMode.subtitles;
    final myLang = _prefs.getMyLanguageName();

    final String fromLang;
    final String toLang;
    final Speaker speaker;

    if (state.appMode == AppMode.subtitles) {
      fromLang = state.detectedLang1 ?? _prefs.getMyLanguageName();
      toLang = cfg.autoDetect ? _prefs.getMyLanguageName() : cfg.lang2Name;
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
      if (state.detectedLang1 == null) {
        // ── Pre-detection: neither speaker's language is confirmed yet ───────
        final isForwardTurn = _translateForward;
        if (isForwardTurn) {
          fromLang = 'auto';
          toLang = myLang;
          speaker = Speaker.user1;
        } else {
          fromLang = myLang;
          toLang = _partnerLanguageName(myLang);
          speaker = Speaker.user2;
        }
        _translateForward = !_translateForward;

        // Previously skipped the first forward-biDir turn to avoid assistant
        // mode. With the new architecture (transcript in response.create
        // instructions, not conversation.item.create), this skip is no longer
        // needed — the model receives a command, not a chat message, so it
        // cannot drift into assistant mode regardless of input language.
      } else {
        // ── Post-detection: use activeSpeaker set by _updateDetectedLanguage ─
        // activeSpeaker is Speaker.user1 when the current input matches
        // detectedLang1, Speaker.user2 when it matches detectedLang2.
        final d1 = state.detectedLang1!;
        final d2 = state.detectedLang2 ??
            (d1.toLowerCase() == 'english' ? 'French' : 'English');

        if (state.activeSpeaker == Speaker.user2) {
          fromLang = d2; toLang = myLang; speaker = Speaker.user2;
        } else {
          fromLang = d1;
          toLang = TranslationGuard.languageNamesMatch(d1, myLang)
              ? (state.detectedLang2 ?? _partnerLanguageName(myLang))
              : myLang;
          speaker = Speaker.user1;
        }
        // Sync _translateForward to match reality so barge-in / reconnect
        // keep the right direction.
        _translateForward = speaker == Speaker.user1 ? false : true;
      }
    } else {
      // Translator fixed-language: alternate speakers.
      if (_translateForward) {
        fromLang = cfg.lang1Name; toLang = cfg.lang2Name; speaker = Speaker.user1;
      } else {
        fromLang = cfg.lang2Name; toLang = cfg.lang1Name; speaker = Speaker.user2;
      }
      _translateForward = !_translateForward;
    }

    // Never call the model with identical from/to in translator mode.
    if (!textOnly &&
        cfg.autoDetect &&
        (fromLang == 'auto' ||
            TranslationGuard.languageNamesMatch(fromLang, toLang))) {
      toLang = _partnerLanguageName(myLang);
      if (fromLang == 'auto') {
        fromLang = state.detectedLang1 ?? myLang;
      }
    }

    _pendingSpeaker = speaker;
    _pendingTranscript = transcript;
    _finalizePendingLanguages(transcript, fromLang, toLang, myLang);
    _pendingTranslatedText = null;
    _translatorMessageCommitted = false;
    _translatorTranscriptDoneHandled = false;
    _responseMessageAdded = false;
    _strictRetryUsed = false;
    _translationInFlight = true;

    _log.i('[${textOnly ? "subtitle" : "voice"} $fromLang → $toLang] "$transcript"');

    _api.requestTranslation(
      transcript: transcript,
      fromLanguage: fromLang,
      toLanguage: toLang,
      textOnly: textOnly,
      myLanguage: fromLang == 'auto' ? myLang : null,
    );

    // Save for the next call's context (used by the reverse-direction biDir)
    _previousOriginalText = transcript;
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
    return TranslationTextCleanup.deduplicateRepeatedPhrase(cleaned);
  }

  /// Resolve pill / bubble language labels from transcript + session state.
  void _finalizePendingLanguages(
    String transcript,
    String fromLang,
    String toLang,
    String myLang,
  ) {
    final inferredCode = TranscriptLanguageHint.inferIsoCode(transcript);
    if (inferredCode != null) {
      _pendingFrom = _languageNameFromIso(inferredCode);
      _pendingTo = myLang;
      return;
    }

    var from = fromLang == 'auto' ? (state.detectedLang1 ?? myLang) : fromLang;
    var to = toLang;

    if (TranslationGuard.languageNamesMatch(from, to)) {
      if (!TranslationGuard.languageNamesMatch(from, myLang)) {
        to = myLang;
      } else {
        from = _partnerLanguageName(myLang);
        to = myLang;
      }
    }

    _pendingFrom = from;
    _pendingTo = to;
  }

  String _languageNameFromIso(String isoCode) {
    final code = isoCode.toLowerCase().split('-').first;
    return kSupportedLanguages
        .firstWhere(
          (l) => l.code == code,
          orElse: () => SupportedLanguage(code, _capitalize(code), '🌐'),
        )
        .name;
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

  /// Override Whisper language metadata using obvious words in the transcript.
  void _applyTranscriptLanguageHint(String transcript) {
    final code = TranscriptLanguageHint.inferIsoCode(transcript);
    if (code != null) {
      _log.i('Transcript language hint: $code for "$transcript"');
      _updateDetectedLanguage(code);
    }
  }

  /// Best-effort partner language when auto-detect has only heard one side so far.
  String _partnerLanguageName(String myLang) {
    final d2 = state.detectedLang2;
    if (d2 != null && !TranslationGuard.languageNamesMatch(d2, myLang)) {
      return d2;
    }
    final d1 = state.detectedLang1;
    if (d1 != null && !TranslationGuard.languageNamesMatch(d1, myLang)) {
      return d1;
    }
    final cfg = state.languageConfig;
    if (cfg != null &&
        cfg.lang2Code != 'auto' &&
        !TranslationGuard.languageNamesMatch(cfg.lang2Name, myLang)) {
      return cfg.lang2Name;
    }
    return myLang.toLowerCase() == 'english' ? 'German' : 'English';
  }

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

  /// Whisper echo + misheard French + repeated phrases (all modes).
  String _cleanInputTranscript(String text) {
    final trimmed = text.trim();
    final corrected = TranscriptCorrection.correct(
      trimmed,
      languageConfig: state.languageConfig,
      detectedLang1: state.detectedLang1,
      detectedLang2: state.detectedLang2,
    );
    return TranslationTextCleanup.deduplicateRepeatedPhrase(
      TranslationTextCleanup.deduplicateConsecutiveEcho(corrected),
    );
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
    _postPlaybackTimer?.cancel();
    _apiEventSub?.cancel();
    _micSub?.cancel();
    _connectionSub?.cancel();
    _playerSub?.cancel();
    super.dispose();
  }
}
