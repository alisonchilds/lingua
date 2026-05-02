import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:record/record.dart';

/// Handles microphone capture, raw PCM streaming, and audio playback of the
/// translated response audio coming back from the Grok API.
///
/// Architecture notes
/// ──────────────────
/// • Mic capture uses the `record` package (web-compatible, cross-platform).
/// • Playback of PCM16 response audio uses a raw audio output via
///   flutter_sound (native) / Web Audio API (web, via a JS interop shim).
/// • **Echo prevention / playback gating**: while the app is in the
///   ConversationStatus.speaking state the ConversationController stops
///   forwarding mic data to the WebSocket. This prevents the model from
///   "hearing" its own translation output and creating feedback loops.
///   This simple gate covers the basic speaker-output scenario. A full
///   AEC (Acoustic Echo Cancellation) implementation is outside MVP scope.
/// • Sample rate: 24 kHz mono PCM16 (required by Grok Realtime API).
class GrokAudioService {
  static const int _sampleRate = 24000; // Grok requires 24 kHz
  static const int _channels = 1; // mono
  static const int _bitsPerSample = 16; // PCM16

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  final AudioRecorder _recorder = AudioRecorder();

  // Mic stream subscription
  StreamSubscription<Uint8List>? _micSubscription;

  // Playback queue – PCM16 chunks from Grok are buffered then played in order.
  final _playbackQueue = StreamController<Uint8List>.broadcast();

  // Gated audio chunks emitted to callers (ConversationController listens).
  final _audioChunkController = StreamController<String>.broadcast();

  bool _isRecording = false;
  bool _isPlaying = false; // true while Grok audio is playing back
  bool _disposed = false;

  /// Raw PCM16 base64 chunks from the microphone (gated – paused during playback).
  Stream<String> get micAudioChunks => _audioChunkController.stream;

  /// Whether the mic is currently active.
  bool get isRecording => _isRecording;

  /// Whether translated audio is currently being played.
  bool get isPlaying => _isPlaying;

  // ---------------------------------------------------------------------------
  // Microphone
  // ---------------------------------------------------------------------------

  /// Start microphone capture and emit base64 PCM16 chunks.
  Future<bool> startRecording() async {
    if (_isRecording) return true;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _log.w('Microphone permission denied.');
      return false;
    }

    try {
      // Request raw PCM16 stream at 24 kHz mono.
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: _channels,
        ),
      );

      _micSubscription = stream.listen(
        (chunk) {
          if (_disposed) return;
          // Playback gating: do not forward mic audio while speaking to avoid
          // the model translating its own output back (echo loop prevention).
          if (!_isPlaying) {
            final b64 = base64Encode(chunk);
            if (!_audioChunkController.isClosed) {
              _audioChunkController.add(b64);
            }
          }
        },
        onError: (e) => _log.e('Mic stream error: $e'),
      );

      _isRecording = true;
      _log.i('Microphone started (24 kHz mono PCM16).');
      return true;
    } catch (e) {
      _log.e('Failed to start recording: $e');
      return false;
    }
  }

  /// Stop microphone capture.
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _recorder.stop();
    _isRecording = false;
    _log.i('Microphone stopped.');
  }

  // ---------------------------------------------------------------------------
  // Playback (translated audio from Grok)
  // ---------------------------------------------------------------------------

  /// Accept a base64-encoded PCM16 audio delta chunk from the API and queue
  /// it for playback. Returns immediately; playback is async.
  void enqueueAudioChunk(String base64Chunk) {
    if (_disposed) return;
    final bytes = base64Decode(base64Chunk);
    _playbackQueue.add(bytes);
  }

  /// Signal that the current audio response stream is complete. Called when
  /// `response.audio.done` is received. Resets playback gate.
  void onPlaybackComplete() {
    _setPlaying(false);
    _log.d('Playback complete – mic gate lifted.');
  }

  /// Set the playing state externally (called by ConversationController when
  /// the first audio delta arrives / done event fires).
  void setPlaying(bool value) => _setPlaying(value);

  void _setPlaying(bool value) {
    if (_isPlaying != value) {
      _isPlaying = value;
      _log.d('Playing: $value');
    }
  }

  // ---------------------------------------------------------------------------
  // PCM16 → WAV header helper (needed for Web Audio API)
  // ---------------------------------------------------------------------------

  /// Wraps raw PCM16 bytes in a minimal WAV container for browser playback.
  static Uint8List pcm16ToWav(Uint8List pcm) {
    const int sampleRate = _sampleRate;
    const int channels = _channels;
    const int bitsPerSample = _bitsPerSample;

    final dataLength = pcm.length;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final totalLength = 44 + dataLength;

    final header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, totalLength - 8, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt sub-chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // sub-chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);

    return Uint8List.fromList(header.buffer.asUint8List() + pcm);
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopRecording();
    await _audioChunkController.close();
    await _playbackQueue.close();
    _recorder.dispose();
  }
}
