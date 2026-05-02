// Web-only WebSocket wrapper using package:web + dart:js_interop.
// Replaces web_socket_channel on web builds — it has known failures in
// Flutter web release (dart2js) mode.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class NativeWebSocket {
  NativeWebSocket._(this._ws);

  final web.WebSocket _ws;
  final _messageController = StreamController<String>.broadcast();
  final _doneCompleter = Completer<void>();
  bool _closed = false;

  static Future<NativeWebSocket> connect(Uri uri,
      {List<String> protocols = const []}) async {
    // Pass protocols as a JS string (single protocol) or JS array
    final web.WebSocket ws;
    if (protocols.isEmpty) {
      ws = web.WebSocket(uri.toString());
    } else if (protocols.length == 1) {
      ws = web.WebSocket(uri.toString(), protocols.first.toJS);
    } else {
      final jsProtos = protocols.map((p) => p.toJS).toList().toJS;
      ws = web.WebSocket(uri.toString(), jsProtos);
    }

    final instance = NativeWebSocket._(ws);
    final readyCompleter = Completer<NativeWebSocket>();

    ws.addEventListener('open', (web.Event _) {
      if (!readyCompleter.isCompleted) readyCompleter.complete(instance);
    }.toJS);

    ws.addEventListener('error', (web.Event _) {
      final err = Exception('WebSocket failed to connect: $uri');
      if (!readyCompleter.isCompleted) readyCompleter.completeError(err);
      if (!instance._doneCompleter.isCompleted) {
        instance._doneCompleter.completeError(err);
      }
    }.toJS);

    ws.addEventListener('message', (web.MessageEvent evt) {
      if (!instance._messageController.isClosed) {
        // evt.data is a JSString for text frames
        final raw = evt.data;
        if (raw != null) {
          instance._messageController.add((raw as JSString).toDart);
        }
      }
    }.toJS);

    ws.addEventListener('close', (web.CloseEvent _) {
      instance._closed = true;
      if (!instance._messageController.isClosed) {
        instance._messageController.close();
      }
      if (!instance._doneCompleter.isCompleted) {
        instance._doneCompleter.complete();
      }
    }.toJS);

    return readyCompleter.future;
  }

  Stream<String> get stream => _messageController.stream;
  Future<void> get done => _doneCompleter.future;
  bool get isClosed => _closed;

  void send(String data) {
    if (!_closed && _ws.readyState == web.WebSocket.OPEN) {
      _ws.send(data.toJS);
    }
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
