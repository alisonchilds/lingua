import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

import 'ws_channel_stub.dart'
    if (dart.library.js_interop) 'ws_channel_web.dart';

/// Event emitted by [SttService] for every transcript update.
class SttTranscriptEvent {
  const SttTranscriptEvent({
    required this.text,
    required this.isFinal,
    required this.speechFinal,
  });

  /// The transcript text (may be partial).
  final String text;

  /// True when this chunk is locked (won't change). False while still in flux.
  final bool isFinal;

  /// True when the speaker has paused / stopped — use to trigger translation.
  final bool speechFinal;
}

/// Streams real-time partial and final transcripts from the xAI STT API.
///
/// The STT endpoint accepts raw binary PCM16 audio frames and emits
/// transcript.partial events approximately every 500 ms, making it possible
/// to show live captions while the speaker is still talking.
///
/// Web builds connect through the Cloudflare proxy at [kSttProxyUrl].
/// Native builds connect directly using the API key header.
class SttService {
  static const kSttProxyUrl = 'wss://grok-voice-proxy.alison-ade.workers.dev/stt';
  static const kSttDirectBase = 'wss://api.x.ai/v1/stt';

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  NativeWebSocket? _ws;
  StreamSubscription? _wsSub;

  final _transcriptController =
      StreamController<SttTranscriptEvent>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  bool _connected = false;
  String? _apiKey;

  Stream<SttTranscriptEvent> get transcripts => _transcriptController.stream;
  Stream<bool> get connectionStatus => _connectedController.stream;
  bool get isConnected => _connected;

  // ── Connection ────────────────────────────────────────────────────────────

  Future<void> connect({String? apiKey}) async {
    _apiKey = apiKey;
    await _close();

    final params = Uri(queryParameters: {
      'sample_rate': '16000',
      'encoding': 'pcm',
      'interim_results': 'true',
      'endpointing': '300', // ms silence before speech_final
    }).query;

    final uri = kIsWeb
        ? Uri.parse('$kSttProxyUrl?$params')
        : Uri.parse('$kSttDirectBase?$params');

    _log.i('STT connecting → $uri');

    try {
      if (kIsWeb) {
        _ws = await NativeWebSocket.connect(uri);
      } else {
        // Native: NativeWebSocket stub; fall back if needed.
        // For now use the same web path — native direct needs IOWebSocketChannel.
        _ws = await NativeWebSocket.connect(uri);
      }

      _wsSub = _ws!.stream.listen(
        _onMessage,
        onError: (e) {
          _log.e('STT WebSocket error: $e');
          _setConnected(false);
        },
        onDone: () {
          _log.w('STT WebSocket closed.');
          _setConnected(false);
        },
      );

      // Wait for transcript.created before marking connected.
    } catch (e) {
      _log.e('STT connect failed: $e');
      _setConnected(false);
    }
  }

  /// Send a raw PCM16 audio chunk to the STT endpoint.
  /// The STT API expects raw binary frames, NOT base64.
  void sendAudio(Uint8List bytes) {
    if (!_connected) return;
    try {
      _ws?.sendBytes(bytes);
    } catch (e) {
      _log.e('STT send error: $e');
    }
  }

  /// Signal that all audio has been sent (triggers final flush on the server).
  void finishAudio() {
    if (!_connected) return;
    try {
      _ws?.send(jsonEncode({'type': 'audio.done'}));
    } catch (e) {
      _log.e('STT finish error: $e');
    }
  }

  Future<void> disconnect() async => _close();

  Future<void> dispose() async {
    await _close();
    await _transcriptController.close();
    await _connectedController.close();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';

      if (type == 'transcript.created') {
        _log.i('STT ready — server initialized.');
        _setConnected(true);
        return;
      }

      if (type == 'transcript.done') {
        _log.i('STT session complete.');
        return;
      }

      if (type == 'transcript.partial') {
        final text = json['text'] as String? ?? '';
        final isFinal = json['is_final'] as bool? ?? false;
        final speechFinal = json['speech_final'] as bool? ?? false;

        if (text.isNotEmpty) {
          final event = SttTranscriptEvent(
            text: text,
            isFinal: isFinal,
            speechFinal: speechFinal,
          );
          if (!_transcriptController.isClosed) {
            _transcriptController.add(event);
          }
        }
        return;
      }

      if (type == 'error') {
        _log.e('STT error: $json');
      }
    } catch (e) {
      _log.w('STT parse error: $e');
    }
  }

  Future<void> _close() async {
    await _wsSub?.cancel();
    _wsSub = null;
    _ws?.close(1000);
    _ws = null;
    _setConnected(false);
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_connectedController.isClosed) _connectedController.add(value);
    }
  }
}
