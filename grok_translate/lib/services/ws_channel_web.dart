// Web-only WebSocket implementation using package:web directly.
// web_socket_channel's browser implementation has issues in Flutter web release
// builds. This uses the native browser WebSocket API via dart:js_interop.

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// A thin wrapper around the browser WebSocket API that mimics enough of the
/// web_socket_channel interface for GrokApiService to use.
class NativeWebSocket {
  NativeWebSocket._(this._ws);

  final web.WebSocket _ws;
  final _messageController = StreamController<String>.broadcast();
  final _doneCompleter = Completer<void>();

  bool _closed = false;

  static Future<NativeWebSocket> connect(Uri uri,
      {List<String> protocols = const []}) async {
    final ws = protocols.isNotEmpty
        ? web.WebSocket(uri.toString(), protocols.toList().jsify() as JSArray)
        : web.WebSocket(uri.toString());

    final instance = NativeWebSocket._(ws);

    final readyCompleter = Completer<NativeWebSocket>();

    ws.addEventListener(
      'open',
      (web.Event _) {
        if (!readyCompleter.isCompleted) readyCompleter.complete(instance);
      }.toJS,
    );

    ws.addEventListener(
      'error',
      (web.Event e) {
        final err = WebSocketException('WebSocket connection failed: $uri');
        if (!readyCompleter.isCompleted) readyCompleter.completeError(err);
        if (!instance._doneCompleter.isCompleted) {
          instance._doneCompleter.completeError(err);
        }
      }.toJS,
    );

    ws.addEventListener(
      'message',
      (web.MessageEvent evt) {
        final data = evt.data;
        if (data != null && !instance._messageController.isClosed) {
          // data is a JSString for text frames
          final str = (data as JSString).toDart;
          instance._messageController.add(str);
        }
      }.toJS,
    );

    ws.addEventListener(
      'close',
      (web.CloseEvent evt) {
        instance._closed = true;
        if (!instance._messageController.isClosed) {
          instance._messageController.close();
        }
        if (!instance._doneCompleter.isCompleted) {
          instance._doneCompleter.complete();
        }
      }.toJS,
    );

    return readyCompleter.future;
  }

  Stream<String> get stream => _messageController.stream;
  Future<void> get done => _doneCompleter.future;
  bool get isClosed => _closed;

  void send(String data) {
    if (!_closed) _ws.send(data.toJS);
  }

  void close([int? code, String? reason]) {
    if (!_closed) {
      _closed = true;
      try {
        if (code != null) {
          _ws.close(code, reason ?? '');
        } else {
          _ws.close();
        }
      } catch (_) {}
    }
  }
}

class WebSocketException implements Exception {
  WebSocketException(this.message);
  final String message;
  @override
  String toString() => 'WebSocketException: $message';
}
