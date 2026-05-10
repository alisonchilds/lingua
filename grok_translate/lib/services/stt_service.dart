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
    this.language,
  });

  /// The transcript text (may be partial).
  final String text;

  /// True when this chunk is locked (won't change). False while still in flux.
  final bool isFinal;

  /// True when the speaker has paused / stopped — use to trigger translation.
  final bool speechFinal;

  /// ISO-639-1 language code detected by the STT API, if provided.
  final String? language;
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
  bool _disposed = false;
  // When true, the service reconnects automatically after each utterance.
  // The xAI STT API closes the connection after every transcript.done event
  // ("each connection handles a single utterance"). Auto-reconnect keeps
  // the session alive indefinitely for continuous live captioning.
  bool _autoReconnect = false;
  String? _apiKey;
  String? _queryString; // cached so reconnect uses same params
  // True once a final transcript event has been emitted for the current
  // utterance — prevents a duplicate when both transcript.partial {is_final}
  // and transcript.done carry the same text.
  bool _finalEmitted = false;

  Stream<SttTranscriptEvent> get transcripts => _transcriptController.stream;
  Stream<bool> get connectionStatus => _connectedController.stream;
  bool get isConnected => _connected;

  // ── Connection ────────────────────────────────────────────────────────────

  Future<void> connect({String? apiKey}) async {
    _apiKey = apiKey;
    _autoReconnect = true;
    _disposed = false;

    _queryString = Uri(queryParameters: {
      'sample_rate': '16000',
      'encoding': 'pcm',
      'interim_results': 'true',
      'endpointing': '300', // ms silence before speech_final
    }).query;

    await _openConnection();
  }

  Future<void> _openConnection() async {
    await _close(permanent: false); // close existing but keep auto-reconnect

    final uri = kIsWeb
        ? Uri.parse('$kSttProxyUrl?$_queryString')
        : Uri.parse('$kSttDirectBase?$_queryString');

    _log.i('STT connecting → $uri');

    try {
      _ws = await NativeWebSocket.connect(uri);

      _wsSub = _ws!.stream.listen(
        _onMessage,
        onError: (e) {
          _log.e('STT WebSocket error: $e');
          _setConnected(false);
          if (_autoReconnect && !_disposed) {
            _log.i('STT reconnecting after stream error…');
            Future.delayed(const Duration(milliseconds: 500), _openConnection);
          }
        },
        onDone: () {
          _log.w('STT utterance complete — connection closed.');
          _setConnected(false);
          // The xAI STT API closes after every utterance ("each connection
          // handles a single utterance"). Reconnect so the next phrase
          // is captured without any action from the caller.
          if (_autoReconnect && !_disposed) {
            _log.i('STT auto-reconnecting for next utterance…');
            _openConnection();
          }
        },
      );
      // transcript.created signals the server is ready; _setConnected(true)
      // is called from _onMessage when that event arrives.
    } catch (e) {
      _log.e('STT connect failed: $e');
      _setConnected(false);
      // Retry after a brief delay
      if (_autoReconnect && !_disposed) {
        await Future.delayed(const Duration(seconds: 1));
        _openConnection();
      }
    }
  }

  /// Send a raw PCM16 audio chunk to the STT endpoint.
  /// The STT API expects raw binary frames, NOT base64.
  /// We send as soon as the socket is open — no need to wait for
  /// transcript.created, the server buffers audio until it's ready.
  void sendAudio(Uint8List bytes) {
    if (_ws == null) return;
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

  Future<void> disconnect() async {
    _autoReconnect = false;
    await _close(permanent: true);
  }

  Future<void> dispose() async {
    _disposed = true;
    _autoReconnect = false;
    await _close(permanent: true);
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
        // The xAI API sometimes delivers the final transcript only here,
        // without a preceding transcript.partial {is_final: true}.
        // Emit it as a definitive final event unless we already did so.
        final text = (json['text'] as String? ??
                (json['transcript'] as Map?)
                    ?.cast<String, dynamic>()['text'] as String? ??
                '')
            .trim();
        final language = json['language'] as String?;
        if (text.isNotEmpty && !_finalEmitted) {
          _finalEmitted = true;
          _log.i('STT transcript.done — emitting final: "$text"');
          if (!_transcriptController.isClosed) {
            _transcriptController.add(SttTranscriptEvent(
              text: text,
              isFinal: true,
              speechFinal: true,
              language: language,
            ));
          }
        }
        _finalEmitted = false; // reset for next utterance
        return;
      }

      if (type == 'transcript.partial') {
        final text = json['text'] as String? ?? '';
        final isFinal = json['is_final'] as bool? ?? false;
        final speechFinal = json['speech_final'] as bool? ?? false;
        final language = json['language'] as String?;

        if (text.isNotEmpty) {
          if (isFinal) _finalEmitted = true; // suppress duplicate from transcript.done
          final event = SttTranscriptEvent(
            text: text,
            isFinal: isFinal,
            speechFinal: speechFinal,
            language: language,
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

  Future<void> _close({bool permanent = true}) async {
    await _wsSub?.cancel();
    _wsSub = null;
    _ws?.close(1000);
    _ws = null;
    if (permanent) _setConnected(false);
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_connectedController.isClosed) _connectedController.add(value);
    }
  }
}
