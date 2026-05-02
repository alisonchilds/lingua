// Native stub – NativeWebSocket is only used on web.
// On native, GrokApiService uses IOWebSocketChannel directly.

class NativeWebSocket {
  NativeWebSocket._();
  static Future<NativeWebSocket> connect(Uri uri) {
    throw UnsupportedError('NativeWebSocket is web-only');
  }

  Stream<String> get stream => throw UnsupportedError('web-only');
  Future<void> get done => throw UnsupportedError('web-only');
  bool get isClosed => true;
  void send(String data) {}
  void close([int? code, String? reason]) {}
}
