import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:record/record.dart';

import 'web_mic_service_stub.dart'
    if (dart.library.js_interop) 'web_mic_service.dart';

/// Handles microphone capture and playback echo-gating.
///
/// Platform split:
///   Web    → AudioWorklet (audio_processor.js) captures raw PCM16 at 16 kHz.
///            The `record` package cannot produce raw PCM on browsers.
///   Native → `record` package with pcm16bits encoder at 16 kHz mono.
///
/// Echo prevention:
///   While _isPlaying is true the mic chunks are not forwarded to the API.
///   This prevents the model from translating its own speaker output.
class GrokAudioService {
  // 16 kHz is a good balance: lower bandwidth than 24 kHz, still high quality.
  static const int sampleRate = 16000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  // Native recorder
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;

  // Web recorder
  final WebMicService _webMic = WebMicService();

  final _audioChunkController = StreamController<String>.broadcast();
  final _rawBytesController = StreamController<Uint8List>.broadcast();

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _disposed = false;

  /// Base64-encoded PCM16 chunks (for Realtime API — translator mode).
  /// Gated: paused while [_isPlaying] is true.
  Stream<String> get micAudioChunks => _audioChunkController.stream;

  /// Raw PCM16 bytes (for STT streaming API — subtitles mode).
  /// Not gated by playback since subtitles mode has no audio output.
  Stream<Uint8List>? get rawMicBytes => _rawBytesController.stream;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  // ---------------------------------------------------------------------------
  // Microphone
  // ---------------------------------------------------------------------------

  Future<bool> startRecording() async {
    if (_isRecording) return true;
    return kIsWeb ? _startWeb() : _startNative();
  }

  Future<bool> _startWeb() async {
    final ok = await _webMic.start();
    if (!ok) {
      _log.w('Web mic failed to start (permission denied or unsupported).');
      return false;
    }
    _micSubscription = _webMic.micStream!.listen((bytes) {
      if (_disposed) return;
      if (!_rawBytesController.isClosed) {
        _rawBytesController.add(bytes);
      }
      if (!_isPlaying && !_audioChunkController.isClosed) {
        _audioChunkController.add(base64Encode(bytes));
      }
    });
    _isRecording = true;
    _log.i('Web mic started via AudioWorklet ($sampleRate Hz PCM16).');
    return true;
  }

  Future<bool> _startNative() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _log.w('Microphone permission denied.');
      return false;
    }
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: _channels,
        ),
      );
      _micSubscription = stream.listen((chunk) {
        if (_disposed) return;
        if (!_rawBytesController.isClosed) {
          _rawBytesController.add(chunk);
        }
        if (!_isPlaying && !_audioChunkController.isClosed) {
          _audioChunkController.add(base64Encode(chunk));
        }
      }, onError: (e) => _log.e('Mic stream error: $e'));
      _isRecording = true;
      _log.i('Native mic started ($sampleRate Hz PCM16).');
      return true;
    } catch (e) {
      _log.e('Failed to start native recording: $e');
      return false;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    await _micSubscription?.cancel();
    _micSubscription = null;
    if (kIsWeb) {
      await _webMic.stop();
    } else {
      await _recorder.stop();
    }
    _isRecording = false;
    _log.i('Microphone stopped.');
  }

  // ---------------------------------------------------------------------------
  // Playback gating
  // ---------------------------------------------------------------------------

  void setPlaying(bool value) {
    if (_isPlaying != value) {
      _isPlaying = value;
      _log.d('Playback gate: $value');
    }
  }

  void onPlaybackComplete() => setPlaying(false);

  // ---------------------------------------------------------------------------
  // PCM16 → WAV helper (for AudioPlayerService)
  // ---------------------------------------------------------------------------

  static Uint8List pcm16ToWav(Uint8List pcm,
      {int rate = sampleRate, int channels = _channels}) {
    const int bitsPerSample = _bitsPerSample;
    final dataLength = pcm.length;
    final byteRate = rate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final totalLength = 44 + dataLength;

    final h = ByteData(44);
    // RIFF
    h.setUint8(0, 0x52); h.setUint8(1, 0x49); h.setUint8(2, 0x46); h.setUint8(3, 0x46);
    h.setUint32(4, totalLength - 8, Endian.little);
    h.setUint8(8, 0x57); h.setUint8(9, 0x41); h.setUint8(10, 0x56); h.setUint8(11, 0x45);
    // fmt
    h.setUint8(12, 0x66); h.setUint8(13, 0x6D); h.setUint8(14, 0x74); h.setUint8(15, 0x20);
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little); // PCM
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, rate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, blockAlign, Endian.little);
    h.setUint16(34, bitsPerSample, Endian.little);
    // data
    h.setUint8(36, 0x64); h.setUint8(37, 0x61); h.setUint8(38, 0x74); h.setUint8(39, 0x61);
    h.setUint32(40, dataLength, Endian.little);

    return Uint8List.fromList(h.buffer.asUint8List() + pcm);
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopRecording();
    await _audioChunkController.close();
    await _rawBytesController.close();
    _recorder.dispose();
  }
}
