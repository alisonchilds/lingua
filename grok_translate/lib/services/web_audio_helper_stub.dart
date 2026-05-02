// Stub implementation used on native platforms (iOS / Android / desktop).
// On web, audio_player_service_web.dart is loaded instead via conditional import.
import 'dart:async';
import 'dart:typed_data';

class WebAudioHelper {
  static void playWav(Uint8List wav, Completer<void> completer) {
    // No-op on native – just_audio handles playback directly.
    completer.complete();
  }
}
