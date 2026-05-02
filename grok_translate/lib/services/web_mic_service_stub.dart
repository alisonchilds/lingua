// Native stub – WebMicService is only used on web.
import 'dart:typed_data';

class WebMicService {
  Stream<Uint8List>? get micStream => null;
  Future<bool> start() async => false;
  Future<void> stop() async {}
}
