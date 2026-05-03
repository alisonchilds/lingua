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

  /// Inject the transcribed text directly into response.create as a stateless
  /// translation request.
  ///
  /// Using `input` + `instructions` on `response.create` (rather than
  /// `conversation.item.create`) keeps each translation fully independent from
  /// the persistent conversation history.  This prevents the model from drifting
  /// into "assistant" mode as the history grows, and eliminates doubled output
  /// caused by stale history items.
  void requestTranslation({
    required String transcript,
    required String fromLanguage,
    required String toLanguage,
    bool textOnly = false,
  }) {
    // Cancel any response Grok may have auto-started.
    _send({'type': 'response.cancel'});

    _send({
      'type': 'response.create',
      'response': {
        'modalities': textOnly ? ['text'] : ['audio', 'text'],
        // Per-response instruction override — takes precedence over the session
        // system prompt and gives the model an explicit, unambiguous directive.
        'instructions': 'Translate the following text from $fromLanguage into '
            '$toLanguage. Output ONLY the $toLanguage translation. '
            'Do not greet, explain, or add any words of your own.',
        // Provide the transcript as a standalone input item rather than via
        // conversation.item.create so it does not accumulate in history.
        'input': [
          {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': transcript},
            ],
          }
        ],
      },
    });
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
    // Each response.create carries its own per-response `instructions` with the
    // exact source/target language pair.  The session-level system prompt acts
    // purely as a backstop persona so the model never defaults to an assistant.
    if (_appMode == AppMode.subtitles) {
      return 'You are a translation engine. '
          'You receive text and output ONLY the translation. '
          'You do not converse, greet, or explain anything.';
    }

    return 'You are a translation engine. '
        'Each request will tell you which language to translate FROM and INTO. '
        'Output ONLY the translation — no greetings, no explanations, no added words.';
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
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_connectedController.isClosed) _connectedController.add(value);
    }
  }
}
