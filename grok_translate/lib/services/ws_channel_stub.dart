// Native implementation of the shared NativeWebSocket interface.
// Uses web_socket_channel (dart:io under the hood) to connect to the
// Cloudflare proxy — no API key required on device.
//
// On web, ws_channel_web.dart is loaded instead via conditional import.
import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class NativeWebSocket {
  NativeWebSocket._(this._channel, this._ctrl);

  final WebSocketChannel _channel;
  final StreamController<String> _ctrl;
  bool _closed = false;

  static Future<NativeWebSocket> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    final ctrl = StreamController<String>.broadcast();
    final instance = NativeWebSocket._(channel, ctrl);

    channel.stream.listen(
      (data) {
        if (!ctrl.isClosed) ctrl.add(data as String);
      },
      onError: (error) {
        if (!ctrl.isClosed) ctrl.addError(error);
      },
      onDone: () {
        instance._closed = true;
        if (!ctrl.isClosed) ctrl.close();
      },
    );

    // Wait until the WebSocket handshake completes (throws on failure).
    await channel.ready;
    return instance;
  }

  Stream<String> get stream => _ctrl.stream;
  bool get isClosed => _closed;

  void send(String data) {
    if (!_closed) _channel.sink.add(data);
  }

  void sendBytes(Uint8List bytes) {
    if (!_closed) _channel.sink.add(bytes);
  }

  void close([int? code, String? reason]) {
    if (!_closed) {
      _closed = true;
      _channel.sink.close(code, reason);
    }
  }
}
