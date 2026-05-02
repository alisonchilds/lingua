import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/conversation_models.dart';
import '../models/grok_api_models.dart';

/// Handles the persistent WebSocket connection to the Grok Realtime API.
///
/// Responsibilities:
///   - Establish / reconnect the WebSocket.
///   - Serialize outbound events and stream inbound events.
///   - No audio or state logic lives here – this is pure transport.
///
/// ── Security / Connection routing ────────────────────────────────────────────
///
///   Web (browser)
///   └─▶ [kProxyUrl] Cloudflare Worker proxy
///       The worker holds the XAI_API_KEY secret and injects the Authorization
///       header before forwarding to api.x.ai.  The browser never sees the key.
///
///   Native (iOS / Android)
///   └─▶ [kDirectUrl] wss://api.x.ai/v1/realtime  (direct)
///       dart:io supports custom headers on the WS handshake, so the key is
///       sent in the Authorization header without ever appearing in the URL.
///
/// ── How to change the proxy URL ──────────────────────────────────────────────
///   Update [kProxyUrl] below.  That is the only line you need to touch.
/// ─────────────────────────────────────────────────────────────────────────────
class GrokApiService {
  // ── URLs ────────────────────────────────────────────────────────────────────

  /// Cloudflare Worker proxy – used by web builds.
  /// The worker injects the XAI_API_KEY secret; no API key is needed client-side.
  static const kProxyUrl = 'wss://grok-voice-proxy.alison-ade.workers.dev';

  /// Direct Grok Realtime API endpoint – used by native (iOS/Android) builds.
  static const kDirectUrl = 'wss://api.x.ai/v1/realtime';

  /// Grok voice model name – passed as a query param on native direct connections.
  static const _model = 'grok-voice-think-fast-1.0';

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventController = StreamController<GrokServerEvent>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  bool _disposed = false;
  bool _connected = false;
  String? _apiKey;

  // Reconnect state
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  /// Broadcast stream of parsed server events.
  Stream<GrokServerEvent> get events => _eventController.stream;

  /// Broadcast stream of connection status changes.
  Stream<bool> get connectionStatus => _connectedController.stream;

  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Connect to the Grok Realtime API and send initial session config.
  ///
  /// [apiKey] is only required on native builds (used in the Authorization
  /// header). On web the Cloudflare Worker proxy supplies the key; pass null.
  Future<void> connect({
    String? apiKey,
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) async {
    _apiKey = apiKey;
    await _connect(languageConfig: languageConfig, vadSettings: vadSettings);
  }

  /// Append a chunk of base64-encoded PCM16 audio to the input buffer.
  void appendAudio(String base64Audio) {
    _sendRaw({
      'type': 'input_audio_buffer.append',
      'audio': base64Audio,
    });
  }

  /// Commit the audio buffer (manual VAD mode – unused in server_vad).
  void commitAudio() {
    _sendRaw({'type': 'input_audio_buffer.commit'});
  }

  /// Request the model to generate a response (typically after commit).
  void requestResponse() {
    _sendRaw({'type': 'response.create'});
  }

  /// Cancel the in-progress response (barge-in).
  void cancelResponse() {
    _sendRaw({'type': 'response.cancel'});
  }

  /// Update VAD / session settings mid-conversation.
  void updateSession({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    _sendSessionUpdate(languageConfig: languageConfig, vadSettings: vadSettings);
  }

  /// Close the WebSocket cleanly.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts; // prevent auto-reconnect
    await _closeChannel();
    _setConnected(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventController.close();
    await _connectedController.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _connect({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) async {
    // On web we use the Cloudflare Worker proxy — no API key needed client-side.
    // On native we still require the key for the direct Authorization header.
    if (!kIsWeb && _apiKey == null) return;
    await _closeChannel();

    try {
      _log.i('Connecting to Grok Realtime API…');
      _channel = _buildChannel();

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Wait briefly for the connection to succeed before sending the session
      // update (the channel does not expose an explicit 'connected' event).
      await Future.delayed(const Duration(milliseconds: 300));
      _setConnected(true);
      _reconnectAttempts = 0;

      _sendSessionUpdate(
          languageConfig: languageConfig, vadSettings: vadSettings);
      _log.i('Connected & session configured.');
    } catch (e) {
      _log.e('Connection error: $e');
      _scheduleReconnect(languageConfig: languageConfig, vadSettings: vadSettings);
    }
  }

  void _sendSessionUpdate({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    final instructions = _buildSystemPrompt(languageConfig);
    _sendRaw({
      'type': 'session.update',
      'session': {
        'instructions': instructions,
        'voice': 'eve',
        // xAI audio format schema (different from OpenAI's flat field names)
        'audio': {
          'input': {'format': {'type': 'audio/pcm', 'rate': 16000}},
          'output': {'format': {'type': 'audio/pcm', 'rate': 16000}},
        },
        'turn_detection': {
          'type': 'server_vad',
          'threshold': vadSettings.threshold,
          'prefix_padding_ms': 300,
          'silence_duration_ms': vadSettings.silenceDurationMs,
          'create_response': true,
        },
      },
    });
  }

  String _buildSystemPrompt(LanguageConfig cfg) {
    final l1 = cfg.autoDetect ? 'auto-detected language' : cfg.lang1Name;
    final l2 = cfg.autoDetect ? 'auto-detected language' : cfg.lang2Name;
    return 'You are an impartial real-time translator. '
        'Detect the spoken language automatically. '
        'Translate accurately and naturally into the other language of the conversation. '
        'Output ONLY the translated speech — no commentary, no explanations. '
        'Preserve tone, emphasis, and natural prosody. '
        'The two languages are $l1 and $l2.';
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final typeStr = json['type'] as String? ?? '';
      final eventType = grokEventTypeFromString(typeStr);

      final event = GrokServerEvent(
        type: eventType,
        eventId: json['event_id'] as String?,
        audioDelta: json['delta'] as String?,
        transcriptDelta: (eventType ==
                    GrokServerEventType.responseAudioTranscriptDelta ||
                eventType == GrokServerEventType.responseAudioTranscriptDone)
            ? json['delta'] as String?
            : null,
        transcriptText:
            (eventType == GrokServerEventType.responseAudioTranscriptDone)
                ? json['transcript'] as String?
                : null,
        errorMessage: (eventType == GrokServerEventType.error)
            ? (json['error'] as Map?)?.cast<String, dynamic>()['message']
                    as String? ??
                raw.toString()
            : null,
        raw: json,
      );

      // Log unknown events so we can discover any API naming differences
      if (eventType == GrokServerEventType.unknown) {
        _log.d('Unknown event type: $typeStr | raw: $raw');
      }

      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
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
    // Attempt reconnect if not intentionally disconnected
    if (!_disposed && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect(
        languageConfig: const LanguageConfig(),
        vadSettings: const VadSettings(),
      );
    }
  }

  void _scheduleReconnect({
    required LanguageConfig languageConfig,
    required VadSettings vadSettings,
  }) {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    _log.i('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _connect(languageConfig: languageConfig, vadSettings: vadSettings);
    });
  }

  /// Build the correct [WebSocketChannel] for the current platform.
  ///
  /// Web  → connects to [kProxyUrl] (Cloudflare Worker).
  ///         The worker adds `Authorization: Bearer <secret>` before forwarding
  ///         to api.x.ai.  No API key is present anywhere in the browser.
  ///
  /// Native → connects directly to [kDirectUrl] with the Authorization header.
  ///          dart:io supports custom headers on the WS handshake.
  WebSocketChannel _buildChannel() {
    if (kIsWeb) {
      // ── Web: route through the Cloudflare Worker proxy ───────────────────
      // The proxy URL (kProxyUrl) is the ONLY change needed to point at a
      // different worker — all session/audio/VAD logic is untouched.
      _log.i('Web: connecting via Cloudflare proxy → $kProxyUrl');
      return WebSocketChannel.connect(
        Uri.parse(kProxyUrl),
        protocols: ['realtime'],
      );
    } else {
      // ── Native: direct connection with Authorization header ───────────────
      final uri = Uri.parse('$kDirectUrl?model=$_model');
      _log.i('Native: connecting directly → $kDirectUrl');
      return IOWebSocketChannel.connect(
        uri,
        protocols: ['realtime'],
        headers: {'Authorization': 'Bearer $_apiKey'},
      );
    }
  }

  void _sendRaw(Map<String, dynamic> payload) {
    if (!_connected || _channel == null) {
      _log.w('Cannot send – not connected.');
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      _log.e('Send error: $e');
    }
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_connectedController.isClosed) {
        _connectedController.add(value);
      }
    }
  }
}
