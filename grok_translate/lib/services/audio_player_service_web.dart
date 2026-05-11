// Web-only implementation of WebAudioHelper.
// Uses package:web + dart:js_interop (Flutter 3.29+ / Dart 3.x).
// This file is compiled only on the web target.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class WebAudioHelper {
  static void playWav(Uint8List wav, Completer<void> completer) {
    // Wrap the raw bytes in a Blob and create an object URL.
    final jsBytes = wav.buffer.toJS;
    final blobParts = [jsBytes].toJS;
    final options = web.BlobPropertyBag(type: 'audio/wav');
    final blob = web.Blob(blobParts, options);
    final url = web.URL.createObjectURL(blob);

    final audio = web.HTMLAudioElement();
    audio.src = url;

    void cleanup() => web.URL.revokeObjectURL(url);

    audio.addEventListener(
      'ended',
      (web.Event _) {
        cleanup();
        if (!completer.isCompleted) completer.complete();
      }.toJS,
    );

    audio.addEventListener(
      'error',
      (web.Event _) {
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError('Web audio playback error');
        }
      }.toJS,
    );

    // play() returns a Promise that REJECTS when autoplay is blocked by the
    // browser (e.g. AudioContext not yet resumed after a user gesture).
    // If we ignore that rejection the completer never completes, leaving the
    // app permanently stuck in the "speaking" state.
    audio.play().toDart.then<void>(
      (_) {
        // Playback started successfully — 'ended' / 'error' drive completion.
      },
      onError: (dynamic e) {
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError('Autoplay blocked: $e');
        }
      },
    );
  }
}
