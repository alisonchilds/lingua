// Native stub – NativeWebSocket is only used on web.
// On native, GrokApiService uses IOWebSocketChannel directly.

import 'dart:typed_data';

class NativeWebSocket {
  NativeWebSocket._();
  static Future<NativeWebSocket> connect(Uri uri) {
    throw UnsupportedError('NativeWebSocket is web-only');
  }

  Stream<String> get stream => throw UnsupportedError('web-only');
  Future<void> get done => throw UnsupportedError('web-only');
  bool get isClosed => true;
  void send(String data) {}
  void sendBytes(Uint8List bytes) {}
  void close([int? code, String? reason]) {}
}
