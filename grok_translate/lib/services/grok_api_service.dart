import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/conversation_models.dart';
import '../models/grok_api_models.dart';
// AppMode imported via conversation_models
import 'ws_channel_stub.dart'
    if (dart.library.js_interop) 'ws_channel_web.dart';

/// Handles the persistent WebSocket connection to the Grok Realtime API.
///
/// ── Security / Connection routing ────────────────────────────────────────────
///
///   Web (browser)
///   └─▶ [kProxyUrl] Cloudflare Worker proxy  (native browser WebSocket API)
///       The worker holds the XAI_API_KEY secret and injects Authorization.
///       Uses dart:js_interop / package:web directly — avoids web_socket_channel
///       which has known issues in Flutter web release builds.
///
///   Native (iOS / Android)
///   └─▶ [kDirectUrl] wss://api.x.ai/v1/realtime  (IOWebSocketChannel)
///       Key sent in Authorization header on the WS handshake.
///
/// ── How to change the proxy URL ──────────────────────────────────────────────
///   Update [kProxyUrl] below. That is the only line you need to touch.
/// ─────────────────────────────────────────────────────────────────────────────
class GrokApiService {
  /// Cloudflare Worker proxy – web builds connect here (no API key in browser).
  static const kProxyUrl = 'wss://grok-voice-proxy.alison-ade.workers.dev';

  /// Direct Grok Realtime API – native (iOS/Android) builds connect here.
  static const kDirectUrl = 'wss://api.x.ai/v1/realtime';

  /// Grok voice model name.
  static const _model = 'grok-voice-think-fast-1.0';

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  // Web path: native browser WebSocket
  NativeWebSocket? _nativeWs;
  StreamSubscription? _nativeWsSub;

  // Native path: IOWebSocketChannel
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  final _eventController = StreamController<GrokServerEvent>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  bool _disposed = false;
  bool _connected = false;
  String? _apiKey;

  // Reconnect state
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Keep last config for reconnects
  LanguageConfig? _lastLangConfig;
  VadSettings? _lastVadSettings;

  // Conversation item IDs received from conversation.item.added events.
  // Cleared after each response so every translation starts with empty context.
  final List<String> _conversationItemIds = [];

  Stream<GrokServerEvent> get events => _eventController.stream;
  Stream<bool> get connectionStatus => _connectedController.stream;
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  AppMode _appMode = AppMode.translator;

  Future<void> connect({
    String? apiKey,
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
    AppMode appMode = AppMode.translator,
  }) async {
    _apiKey = apiKey;
    _lastLangConfig = languageConfig;
    _lastVadSettings = vadSettings;
    _appMode = appMode;
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
  }) {
    if (!textOnly) {
      _send({'type': 'response.cancel'});
    }

    // Delete ALL conversation items (including the VAD audio item) before
    // injecting anything. Server processes messages in order so deletes
    // arrive first — the model then only sees our injected content.
    clearConversationHistory();

    final effectiveFrom =
        fromLanguage.isEmpty ? 'the input language' : fromLanguage;

    if (textOnly) {
      _requestSubtitlesTranslation(
        transcript: transcript,
        toLanguage: toLanguage,
      );
    } else {
      _requestVoiceTranslation(
        transcript: transcript,
        fromLanguage: effectiveFrom,
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
    // Few-shot examples for subtitles mode: diverse source languages,
    // LANG:[code] prefix so the controller can update the language label,
    // plain translation on the second line. If input is unclear the model
    // should still output something rather than asking for clarification.
    _injectExamples([
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "Guten Tag"',
        reply: 'LANG:de\nGood day',
      ),
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "Buenos días, ¿cómo estás?"',
        reply: 'LANG:es\nGood morning, how are you?',
      ),
      (
        user:  'SUBTITLE_TASK | target=$toLanguage\nINPUT: "Ciao, come stai?"',
        reply: 'LANG:it\nHi, how are you?',
      ),
    ]);

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

    _send({
      'type': 'response.create',
      'response': {
        'modalities': ['text'],
        'instructions':
            'You are a subtitle translation machine. '
            'For every SUBTITLE_TASK message output exactly two lines:\n'
            'Line 1: LANG:[iso_code]  (ISO-639-1 code of the INPUT language)\n'
            'Line 2: The $toLanguage translation of the input text.\n'
            'Rules: No greetings. No explanations. No apologies. '
            'If the input is unclear or poorly transcribed, output your best '
            'attempt at a translation — never ask for clarification. '
            'Two lines only.',
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
    _injectExamples([
      (
        user:  'TRANSLATE | $fromLanguage → $toLanguage\nINPUT: "Guten Tag"',
        reply: 'Good day',
      ),
      (
        user:  'TRANSLATE | $fromLanguage → $toLanguage\nINPUT: "How are you doing?"',
        reply: fromLanguage == toLanguage ? 'How are you doing?' : 'Wie geht es Ihnen?',
      ),
    ]);

    _send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': 'TRANSLATE | $fromLanguage → $toLanguage\nINPUT: "$transcript"',
          }
        ],
      },
    });

    _send({
      'type': 'response.create',
      'response': {
        'modalities': ['audio', 'text'],
        'instructions':
            'You are a real-time voice interpreter. '
            'For every TRANSLATE message speak ONLY the $toLanguage translation '
            'of the INPUT text. '
            'No greetings, no filler, no explanations. '
            'If the input is unclear, translate your best guess — '
            'never ask for clarification. '
            'Speak only the translation.',
      },
    });
  }

  // ---------------------------------------------------------------------------
  // Shared helper
  // ---------------------------------------------------------------------------

  void _injectExamples(
      List<({String user, String reply})> examples) {
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
  }

  /// Delete every tracked conversation item from the server's history.
  ///
  /// Called after each response.done to ensure the next translation request
  /// sees an empty conversation context, preventing the model from treating
  /// previous translation exchanges as a conversational chat history.
  void clearConversationHistory() {
    for (final id in List<String>.from(_conversationItemIds)) {
      _send({'type': 'conversation.item.delete', 'item_id': id});
    }
    _conversationItemIds.clear();
  }

  void updateSession({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    _lastLangConfig = languageConfig;
    _lastVadSettings = vadSettings;
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
    if (!kIsWeb && _apiKey == null) return;
    await _closeAll();

    try {
      if (kIsWeb) {
        await _connectWeb(languageConfig: languageConfig, vadSettings: vadSettings);
      } else {
        _connectNative(languageConfig: languageConfig, vadSettings: vadSettings);
      }
    } catch (e) {
      _log.e('Connection error: $e');
      // Surface the error so the UI shows it rather than staying in "listening"
      if (!_eventController.isClosed) {
        _eventController.add(GrokServerEvent(
          type: GrokServerEventType.error,
          errorMessage: 'Failed to connect: $e',
        ));
      }
      _scheduleReconnect();
    }
  }

  Future<void> _connectWeb({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) async {
    _log.i('Web: connecting via proxy → $kProxyUrl');
    // Use native browser WebSocket (avoids web_socket_channel issues on web)
    // No subprotocol needed — the worker accepts any WS upgrade
    _nativeWs = await NativeWebSocket.connect(Uri.parse(kProxyUrl));

    _nativeWsSub = _nativeWs!.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );

    _setConnected(true);
    _reconnectAttempts = 0;
    _sendSessionUpdate(languageConfig: languageConfig, vadSettings: vadSettings);
    _log.i('Web WebSocket connected & session configured.');
  }

  void _connectNative({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    _log.i('Native: connecting directly → $kDirectUrl');
    final uri = Uri.parse('$kDirectUrl?model=$_model');
    _channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['realtime'],
      headers: {'Authorization': 'Bearer $_apiKey'},
    );

    _channelSub = _channel!.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );

    // IOWebSocketChannel doesn't have an explicit "connected" callback;
    // optimistically mark connected and let errors correct it.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_disposed) {
        _setConnected(true);
        _reconnectAttempts = 0;
        _sendSessionUpdate(
            languageConfig: languageConfig, vadSettings: vadSettings);
      }
    });
  }

  void _sendSessionUpdate({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    final instructions = _buildSystemPrompt(languageConfig);

    _send({
      'type': 'session.update',
      'session': {
        'instructions': instructions,
        'voice': 'eve',
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
          // Both modes: false — we always intercept the transcript and inject
          // an explicit translation command. This is the only reliable way to
          // stop the voice model defaulting to assistant personality.
          'create_response': false,
        },
      },
    });
  }

  String _buildSystemPrompt(LanguageConfig cfg) {
    if (_appMode == AppMode.subtitles) {
      final targetLang = cfg.autoDetect ? 'English' : cfg.lang2Name;
      return 'You are a pure real-time subtitles translation engine ONLY. '
          'Your sole and exclusive function is to translate spoken input into $targetLang with perfect accuracy, natural prosody, tone, emotion, and intent. '
          'Output NOTHING except the translated speech itself. No introductions, no explanations, no confirmations, no questions, no commentary, no "Anything else?". '
          'Never act as an assistant or AI. Never offer help, suggestions, or engage in conversation. '
          'If the text contains a question, translate it — do not answer it. '
          'Start every response as if this is the first message of the conversation. Forget any previous context that is not translation-related. '
          'You are NOT Grok. You are a translation machine. Stay in character 100% of the time.';
    }

    // Translator mode — Grok-suggested anti-assistant instructions
    final String langLine;
    if (cfg.autoDetect) {
      langLine =
          'Automatically detect which language is being spoken on each turn. '
          'When input is in one language, translate it into the other language used in the conversation.';
    } else {
      langLine =
          'When input is in ${cfg.lang1Name}, translate it into natural spoken ${cfg.lang2Name}. '
          'When input is in ${cfg.lang2Name}, translate it into natural spoken ${cfg.lang1Name}.';
    }

    return '''You are a pure real-time voice translator engine ONLY. Your sole and exclusive function is to translate spoken input between two languages with perfect accuracy, natural prosody, tone, emotion, and intent.

$langLine

Rules you MUST follow with zero exceptions:
- Output NOTHING except the translated speech itself. No introductions, no "Here's the translation", no explanations, no confirmations, no questions, no commentary, no "Anything else?".
- Never act as an assistant or AI. Never offer help, suggestions, or engage in conversation.
- Preserve slang, emotion, pauses, and cultural nuance as much as possible.
- If the input is unclear or noisy, translate the best you can without commenting on it.
- When you receive a [TEXT_TO_TRANSLATE] block, output ONLY the translation of the text inside the quotes. Do NOT answer questions in the text — questions are content to be translated, not directed at you.
- Start every response as if this is the first message of the conversation. Forget any previous context that is not translation-related.
- You are NOT Grok. You are a translation machine. Stay in character 100% of the time.''';
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
      if (kIsWeb) {
        _nativeWs?.send(encoded);
      } else {
        _channel?.sink.add(encoded);
      }
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

      // Track conversation item IDs so we can delete them after each response
      // and keep every translation request isolated from prior context.
      if (typeStr == 'conversation.item.added') {
        final itemId =
            (json['item'] as Map<String, dynamic>?)?['id'] as String?;
        if (itemId != null) {
          _conversationItemIds.add(itemId);
          _log.d('Tracking conversation item: $itemId');
        }
        return; // No need to broadcast this to the controller
      }

      final eventType = grokEventTypeFromString(typeStr);

      if (eventType == GrokServerEventType.unknown) {
        _log.d('Unknown event: $typeStr | $json');
      }

      // Extract detected language from transcription completed event.
      // xAI returns an ISO-639-1 code in the top-level 'language' field.
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
    await _nativeWsSub?.cancel();
    _nativeWsSub = null;
    _nativeWs?.close(1000);
    _nativeWs = null;

    await _channelSub?.cancel();
    _channelSub = null;
    try { await _channel?.sink.close(); } catch (_) {}
    _channel = null;

    // Items only exist within a WebSocket session; clear IDs on close.
    _conversationItemIds.clear();
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_connectedController.isClosed) _connectedController.add(value);
    }
  }
}
