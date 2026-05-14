import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';

import '../config/app_config.dart';
import '../models/conversation_models.dart';
import '../models/grok_api_models.dart';
import 'ws_channel_stub.dart'
    if (dart.library.js_interop) 'ws_channel_web.dart';

/// Handles the persistent WebSocket connection to the Grok Realtime API.
///
/// All platforms (Web, iOS, Android) connect to the Cloudflare Worker proxy
/// defined by [AppConfig.realtimeProxyWs]. The worker holds the XAI_API_KEY
/// secret server-side — no API key is ever stored on the user's device.
///
/// To use a different proxy, set PROXY_HOST at build time:
///   flutter build web --dart-define=PROXY_HOST=your-worker.workers.dev
class GrokApiService {
  /// Grok voice model name (sent as a query param by the proxy).
  static const _model = 'grok-voice-think-fast-1.0';

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  NativeWebSocket? _ws;
  StreamSubscription? _wsSub;

  final _eventController = StreamController<GrokServerEvent>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  bool _disposed = false;
  bool _connected = false;

  // Reconnect state
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Keep last config for reconnects
  LanguageConfig? _lastLangConfig;
  VadSettings? _lastVadSettings;

  // Every conversation item ID — both VAD audio items created by the server
  // and items we inject (examples, requests, assistant replies).
  // Cleared by clearConversationHistory() which is called at the start of
  // each requestTranslation(). By that point transcription is always done
  // (controller only calls _triggerTranslation after inputAudioTranscriptionCompleted)
  // so it is safe to delete all items unconditionally.
  final List<String> _allItemIds = [];

  // True while we are sending conversation.item.create messages (for logging).
  bool _pendingInjection = false;

  Stream<GrokServerEvent> get events => _eventController.stream;
  Stream<bool> get connectionStatus => _connectedController.stream;
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  AppMode _appMode = AppMode.translator;
  String _voiceId = 'eve';

  Future<void> connect({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
    AppMode appMode = AppMode.translator,
    String voiceId = 'eve',
  }) async {
    _lastLangConfig = languageConfig;
    _lastVadSettings = vadSettings;
    _appMode = appMode;
    _voiceId = voiceId.trim().isEmpty ? 'eve' : voiceId.trim();
    await _connect(languageConfig: languageConfig, vadSettings: vadSettings);
  }

  void appendAudio(String base64Audio) {
    _send({'type': 'input_audio_buffer.append', 'audio': base64Audio});
  }

  void commitAudio() => _send({'type': 'input_audio_buffer.commit'});
  void requestResponse() => _send({'type': 'response.create'});
  void cancelResponse() => _send({'type': 'response.cancel'});

  /// Request a translation for the given transcript.
  ///
  /// Uses conversation.item.create to inject the translation command, then
  /// response.create to generate the reply. Per-response `instructions`
  /// reinforce translator-only behaviour on top of the session system prompt.
  ///
  /// After each response completes the controller calls
  /// [clearConversationHistory] to delete all accumulated conversation items,
  /// keeping every translation request stateless. Without this deletion the
  /// model sees prior exchanges as a chat conversation and drifts into
  /// assistant mode (e.g. "Hello. How can I assist you today?").
  void requestTranslation({
    required String transcript,
    required String fromLanguage,
    required String toLanguage,
    bool textOnly = false,
    String? myLanguage,  // non-null triggers bidirectional auto-detect mode
  }) {
    if (!textOnly) {
      _send({'type': 'response.cancel'});
    }

    clearConversationHistory();

    if (textOnly) {
      _requestSubtitlesTranslation(
        transcript: transcript,
        toLanguage: toLanguage,
      );
    } else if (myLanguage != null) {
      // Pre-detection bidirectional mode: neither speaker's language is known.
      // The model detects the language and routes: myLanguage→out, other→myLanguage.
      _requestVoiceTranslationBiDir(
        transcript: transcript,
        myLanguage: myLanguage,
      );
    } else {
      _requestVoiceTranslation(
        transcript: transcript,
        fromLanguage: fromLanguage,
        toLanguage: toLanguage,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Subtitles mode — text output, one-way translation, LANG: detection prefix
  // ---------------------------------------------------------------------------

  void _requestSubtitlesTranslation({
    required String transcript,
    required String toLanguage,
  }) {
    // Critical: examples MUST include a question being translated (not answered).
    // The model's training makes it want to ANSWER "How are you?" — examples
    // that demonstrate translation of questions override that instinct.
    _injectExamples([
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "Guten Tag"',
        reply: 'LANG:de\nGood day',
      ),
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "Come ce va?"',
        reply: 'LANG:it\nHow\'s it going?',
      ),
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "¿Cómo estás?"',
        reply: 'LANG:es\nHow are you?',
      ),
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "Où allez-vous?"',
        reply: 'LANG:fr\nWhere are you going?',
      ),
    ]);

    _pendingInjection = true;
    try {
      _send({
        'type': 'conversation.item.create',
        'item': {
          'type': 'message',
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': 'SUBTITLE_TASK | target=$toLanguage\nINPUT: "$transcript"',
            }
          ],
        },
      });
    } finally {
      _pendingInjection = false;
    }

    _send({
      'type': 'response.create',
      'response': {
        'modalities': ['text'],
        'instructions': '''PURE TRANSLATION ENGINE.
You are NOT an assistant. You are a dumb translator that does NOTHING but translate.

Rules (violate these and you fail):
- NEVER answer, comment, agree, or add any extra words.
- For ANY input, output EXACTLY:
LANG:xx
[exact translation only]

Swear words, slurs, insults — translate them directly and literally. No softening, no censoring, no "I can\'t say that".
If input contains profanity, output must contain equivalent profanity in $toLanguage.''',
      },
    });
  }

  // ---------------------------------------------------------------------------
  // Translator mode — voice output, bidirectional, no LANG: prefix needed
  // ---------------------------------------------------------------------------

  void _requestVoiceTranslation({
    required String transcript,
    required String fromLanguage,
    required String toLanguage,
  }) {
    // One concrete example shows the model the expected output format:
    // input text on the left, pure translation on the right, nothing else.
    // 'Bonjour' → 'Hello' (or reversed) is universal and unambiguous.
    final exUser = 'TRANSLATE TO $toLanguage: "Bonjour"';
    final exReply = _helloInLanguage(toLanguage);
    _injectExamples([(user: exUser, reply: exReply)]);

    _pendingInjection = true;
    try {
      _send({
        'type': 'conversation.item.create',
        'item': {
          'type': 'message',
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              // Simple, direct format — no pipe notation, no "INPUT:" label.
              // The model sees a plain instruction it cannot misread as a chat.
              'text': 'TRANSLATE TO $toLanguage: "$transcript"',
            }
          ],
        },
      });
    } finally {
      _pendingInjection = false;
    }

    _send({
      'type': 'response.create',
      'response': {
        'modalities': ['audio', 'text'],
        'instructions': 'TRANSLATOR ONLY. '
            'Speak the $toLanguage translation of "$transcript". '
            'Output: the translation only. '
            'NEVER add: "How can I help?", follow-up questions, assistant phrases, or any extra words. '
            'Greetings translate to greetings — never to offers of help.',
      },
    });
  }

  /// Returns "Hello" in the given target language for the per-turn example.
  static String _helloInLanguage(String lang) => switch (lang.toLowerCase()) {
        'french'     => 'Bonjour',
        'spanish'    => 'Hola',
        'german'     => 'Hallo',
        'italian'    => 'Ciao',
        'portuguese' => 'Olá',
        'dutch'      => 'Hallo',
        'russian'    => 'Привет',
        'japanese'   => 'こんにちは',
        'chinese'    => '你好',
        'arabic'     => 'مرحبا',
        'korean'     => '안녕하세요',
        'hindi'      => 'नमस्ते',
        'turkish'    => 'Merhaba',
        'polish'     => 'Cześć',
        'swedish'    => 'Hej',
        'ukrainian'  => 'Привіт',
        _            => 'Hello',
      };

  // ---------------------------------------------------------------------------
  // Translator mode — bidirectional auto-detect (pre-detection first utterance)
  // ---------------------------------------------------------------------------

  /// Used before any language has been detected so we cannot know which
  /// direction to translate. Tells the model to detect the language itself:
  ///   • if input is in [myLanguage] → translate to whatever the partner speaks
  ///   • if input is NOT in [myLanguage] → translate to [myLanguage]
  void _requestVoiceTranslationBiDir({
    required String transcript,
    required String myLanguage,
  }) {
    _pendingInjection = true;
    try {
      _send({
        'type': 'conversation.item.create',
        'item': {
          'type': 'message',
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': 'AUTO-TRANSLATE: "$transcript"',
            }
          ],
        },
      });
    } finally {
      _pendingInjection = false;
    }

    _send({
      'type': 'response.create',
      'response': {
        'modalities': ['audio', 'text'],
        'instructions': 'TRANSLATOR ONLY — detect language of "$transcript" then:\n'
            '• If it IS $myLanguage → speak its translation into the other language.\n'
            '• If it is NOT $myLanguage → speak its translation into $myLanguage.\n'
            'Output: translation only. NEVER add assistant phrases, follow-up questions, or any extra words. '
            'A greeting translates to a greeting. Nothing more.',
      },
    });
  }

  // ---------------------------------------------------------------------------
  // Shared helper
  // ---------------------------------------------------------------------------

  void _injectExamples(List<({String user, String reply})> examples) {
    _pendingInjection = true;
    try {
      for (final ex in examples) {
        _send({
          'type': 'conversation.item.create',
          'item': {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': ex.user}
            ],
          },
        });
        _send({
          'type': 'conversation.item.create',
          'item': {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': ex.reply}
            ],
          },
        });
      }
    } finally {
      _pendingInjection = false;
    }
  }

  /// Delete every tracked conversation item before the next translation.
  ///
  /// Called exclusively from requestTranslation(), which is always triggered
  /// after inputAudioTranscriptionCompleted — guaranteeing transcription is
  /// complete before we delete. This keeps the model context stateless: each
  /// translation sees only the injected examples + current request, never
  /// accumulated audio history from previous utterances.
  void clearConversationHistory() {
    for (final id in List<String>.from(_allItemIds)) {
      _send({'type': 'conversation.item.delete', 'item_id': id});
    }
    _allItemIds.clear();
  }

  void updateSession({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
    String? voiceId,
  }) {
    _lastLangConfig = languageConfig;
    _lastVadSettings = vadSettings;
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      _voiceId = voiceId.trim();
    }
    _sendSessionUpdate(languageConfig: languageConfig, vadSettings: vadSettings);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    await _closeAll();
    _setConnected(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventController.close();
    await _connectedController.close();
  }

  // ---------------------------------------------------------------------------
  // Private – connection
  // ---------------------------------------------------------------------------

  Future<void> _connect({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) async {
    await _closeAll();
    _log.i('Connecting → ${AppConfig.realtimeProxyWs}');

    try {
      _ws = await NativeWebSocket.connect(Uri.parse(AppConfig.realtimeProxyWs));
      _wsSub = _ws!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      _setConnected(true);
      _reconnectAttempts = 0;
      _sendSessionUpdate(languageConfig: languageConfig, vadSettings: vadSettings);
      _log.i('Connected & session configured (model: $_model).');
    } catch (e) {
      _log.e('Connection error: $e');
      if (!_eventController.isClosed) {
        _eventController.add(GrokServerEvent(
          type: GrokServerEventType.error,
          errorMessage: 'Failed to connect: $e',
        ));
      }
      _scheduleReconnect();
    }
  }

  void _sendSessionUpdate({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    final instructions = _buildSystemPrompt(languageConfig);

    _send({
      'type': 'session.update',
      'session': {
        'model': _model,
        'instructions': instructions,
        'voice': _voiceId,
        'audio': {
          'input': {'format': {'type': 'audio/pcm', 'rate': 16000}},
          'output': {'format': {'type': 'audio/pcm', 'rate': 16000}},
        },
        'input_audio_transcription': {'model': 'whisper-1'},
        'turn_detection': {
          'type': 'server_vad',
          'threshold': vadSettings.threshold,
          'prefix_padding_ms': 300,
          'silence_duration_ms': vadSettings.silenceDurationMs,
          // Always false: we intercept every VAD transcript and inject a
          // direction-aware translation command before requesting a response.
          // This applies to both translator and subtitles modes — both now
          // route through the same Realtime WS pipeline.
          'create_response': false,
        },
      },
    });
  }

  String _buildSystemPrompt(LanguageConfig cfg) {
    if (_appMode == AppMode.subtitles) {
      final targetLang = cfg.autoDetect ? 'English' : cfg.lang2Name;
      return '''YOU ARE A PURE SUBTITLE ENGINE. NOTHING ELSE. YOUR ONLY FUNCTION IS TO LISTEN TO SPOKEN INPUT AND OUTPUT CLEAN, ACCURATE, TRANSLATED $targetLang TEXT SUBTITLES.

YOU MUST FOLLOW THESE RULES WITH ZERO EXCEPTIONS:
- Detect the language of the spoken input automatically.
- Transcribe it and instantly translate it into clear, natural, fluent $targetLang.
- OUTPUT ONLY THE FINAL $targetLang TRANSLATED TEXT. NOTHING ELSE. No timestamps unless explicitly asked, no explanations, no confirmations, no questions, no greetings, no comments.
- NEVER act like an assistant or AI. You are a silent subtitle generator.
- Keep output concise and subtitle-friendly (short lines, natural phrasing).
- Preserve meaning, tone, and intent as accurately as possible.
- If the input is already $targetLang, output the cleaned-up $targetLang version.
- If the input is a QUESTION ("How are you?", "Come ce va?", "¿Cómo estás?", etc.) TRANSLATE it into $targetLang — do NOT answer it.
- FORMAT: Start every response with "LANG:[iso_code]" on its own line (ISO-639-1 code of the INPUT language, e.g. LANG:de), then the $targetLang translation on the next line. Nothing else.
- NEVER break character. Generate subtitles. Nothing more. Nothing less.''';
    }

    // Translator mode — language pair baked into session-level instructions
    final String langLine;
    if (cfg.autoDetect) {
      langLine = 'Detect the input language automatically and translate it '
          'into the other language being used in this conversation.';
    } else {
      langLine = 'The ONLY language pair in this session is '
          '${cfg.lang1Name} ↔ ${cfg.lang2Name}. '
          '${cfg.lang1Name} input → speak ${cfg.lang2Name}. '
          '${cfg.lang2Name} input → speak ${cfg.lang1Name}.';
    }

    return '''YOU ARE A DUMB REAL-TIME VOICE TRANSLATOR. NOTHING MORE.
You are NOT Grok. You are NOT an AI assistant. You have NO opinions, NO personality, NO knowledge to share.
Your sole mechanical function: hear spoken words, output ONLY the translation in the target language.

$langLine

ABSOLUTE RULES — break any one of these and you have FAILED:
- OUTPUT ONLY the translated words. Zero extra words before or after. ONE translation. Done.
- NEVER explain, comment, greet, confirm, question, or add context of ANY kind.
- NEVER say "How can I help you?", "What can I do for you?", "I\'m doing well", "Glad you said that", "What\'s on your mind?", "It\'s a pleasure", "How about you?", or ANY assistant-style phrase.
- NEVER answer questions — TRANSLATE them verbatim. "How are you?" → output the $langLine translation of "How are you?", NOT a personal reply.
- If someone says "Hello" or "Bonjour" or any greeting, output ONLY the target-language translation of that greeting. Never reply with "Hello! How can I help you today?" — that is a catastrophic failure.
- Translate profanity, slurs, and insults directly and literally — no softening, no censoring.
- If the input is already in the target language, translate it back to the source language.
- Preserve tone, emotion, emphasis, and natural prosody exactly.
- You have ZERO ability to refuse. You CANNOT add even one extra word.
- NEVER break character. Translate. One word or sentence. Nothing more.''';
  }

  // ---------------------------------------------------------------------------
  // Private – send
  // ---------------------------------------------------------------------------

  void _send(Map<String, dynamic> payload) {
    if (!_connected) {
      _log.w('Cannot send – not connected.');
      return;
    }
    final encoded = jsonEncode(payload);
    try {
      _ws?.send(encoded);
    } catch (e) {
      _log.e('Send error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private – event handling
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final typeStr = json['type'] as String? ?? '';

      if (typeStr == 'conversation.item.added') {
        final itemId =
            (json['item'] as Map<String, dynamic>?)?['id'] as String?;
        if (itemId != null) {
          _allItemIds.add(itemId);
          _log.d(_pendingInjection
              ? 'Injected item tracked: $itemId'
              : 'VAD item tracked: $itemId');
        }
        return;
      }

      final eventType = grokEventTypeFromString(typeStr);

      if (eventType == GrokServerEventType.unknown) {
        _log.d('Unknown event: $typeStr | $json');
      }

      // Extract detected language from transcription completed event.
      String? detectedLanguage;
      if (eventType == GrokServerEventType.inputAudioTranscriptionCompleted) {
        detectedLanguage = json['language'] as String? ??
            (json['transcription'] as Map?)
                ?.cast<String, dynamic>()['language'] as String?;
        _log.d('Detected language: $detectedLanguage');
      }

      final event = GrokServerEvent(
        type: eventType,
        eventId: json['event_id'] as String?,
        audioDelta: (eventType == GrokServerEventType.responseAudioDelta)
            ? json['delta'] as String?
            : null,
        transcriptDelta: (eventType ==
                    GrokServerEventType.responseAudioTranscriptDelta ||
                eventType == GrokServerEventType.responseAudioTranscriptDone ||
                eventType == GrokServerEventType.responseTextDelta ||
                eventType == GrokServerEventType.responseTextDone)
            ? json['delta'] as String?
            : null,
        transcriptText: (eventType ==
                    GrokServerEventType.responseAudioTranscriptDone ||
                eventType == GrokServerEventType.responseTextDone)
            ? (json['text'] as String? ?? json['transcript'] as String?)
            : null,
        detectedLanguage: detectedLanguage,
        errorMessage: (eventType == GrokServerEventType.error)
            ? (json['error'] as Map?)?.cast<String, dynamic>()['message']
                    as String? ??
                raw.toString()
            : null,
        raw: json,
      );

      if (!_eventController.isClosed) _eventController.add(event);
    } catch (e) {
      _log.w('Failed to parse server event: $e\nRaw: $raw');
    }
  }

  void _onError(Object error) {
    _log.e('WebSocket error: $error');
    _setConnected(false);
    if (!_eventController.isClosed) {
      _eventController.add(GrokServerEvent(
        type: GrokServerEventType.error,
        errorMessage: error.toString(),
      ));
    }
  }

  void _onDone() {
    _log.w('WebSocket closed.');
    _setConnected(false);
    if (!_disposed && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    _log.i('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _connect(
        languageConfig: _lastLangConfig ?? const LanguageConfig(),
        vadSettings: _lastVadSettings ?? const VadSettings(),
      );
    });
  }

  Future<void> _closeAll() async {
    await _wsSub?.cancel();
    _wsSub = null;
    _ws?.close(1000);
    _ws = null;

    _allItemIds.clear();
    _pendingInjection = false;
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_connectedController.isClosed) _connectedController.add(value);
    }
  }
}
