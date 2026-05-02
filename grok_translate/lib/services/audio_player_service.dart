import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import 'grok_audio_service.dart';
import 'web_audio_helper_stub.dart'
    if (dart.library.js_interop) 'audio_player_service_web.dart';

/// Manages playback of translated audio received from Grok.
///
/// On native (iOS/Android) we accumulate the full response audio then play
/// it via just_audio using a BytesAudioSource.
///
/// On web, we use the Web Audio API via WebAudioHelper (dart:js_interop).
class AudioPlayerService {
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final AudioPlayer _player = AudioPlayer();

  // Accumulate PCM16 deltas into a full audio buffer per response
  final List<int> _pcmBuffer = [];
  bool _isBuffering = false;

  final _playingController = StreamController<bool>.broadcast();
  Stream<bool> get playingStream => _playingController.stream;

  bool get isPlaying => _player.playing;

  /// Called when the first audio delta arrives from Grok.
  void beginBuffering() {
    _pcmBuffer.clear();
    _isBuffering = true;
  }

  /// Append a base64-encoded PCM16 chunk to the current response buffer.
  void appendChunk(String base64Chunk) {
    if (!_isBuffering) return;
    final bytes = base64Decode(base64Chunk);
    _pcmBuffer.addAll(bytes);
  }

  /// Called when `response.audio.done` is received – play the full buffer.
  Future<void> finishAndPlay() async {
    if (!_isBuffering || _pcmBuffer.isEmpty) {
      _isBuffering = false;
      return;
    }
    _isBuffering = false;
    final pcm = Uint8List.fromList(_pcmBuffer);
    final wav = GrokAudioService.pcm16ToWav(pcm);
    _pcmBuffer.clear();

    try {
      _playingController.add(true);
      await _playWav(wav);
    } catch (e) {
      _log.e('Playback error: $e');
    } finally {
      _playingController.add(false);
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    if (kIsWeb) {
      final completer = Completer<void>();
      WebAudioHelper.playWav(wav, completer);
      await completer.future;
    } else {
      await _playWavNative(wav);
    }
  }

  Future<void> _playWavNative(Uint8List wav) async {
    final source = _BytesAudioSource(wav);
    await _player.setAudioSource(source);
    await _player.play();
    await _player.playerStateStream
        .firstWhere((s) => s.processingState == ProcessingState.completed);
  }

  Future<void> stop() async {
    await _player.stop();
    _pcmBuffer.clear();
    _isBuffering = false;
    _playingController.add(false);
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
    await _playingController.close();
  }
}

// ---------------------------------------------------------------------------
// Stub BytesAudioSource for just_audio on native
// ---------------------------------------------------------------------------
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes);
  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      stream: Stream.value(_bytes.sublist(s, e)),
      contentType: 'audio/wav',
    );
  }
}
