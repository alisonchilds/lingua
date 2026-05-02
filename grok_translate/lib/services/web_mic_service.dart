// Web-only microphone capture using the Web Audio API (AudioWorklet).
// Loaded via conditional import in grok_audio_service.dart.
//
// Why not use the `record` package on web?
// The `record` package captures audio as Opus/WebM on browsers — it cannot
// produce raw PCM16. The Grok Voice API requires raw PCM16 at 16 kHz.
// We use an AudioWorklet to get raw float32 samples directly from the mic
// and convert them to PCM16 in the worklet thread.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class WebMicService {
  web.AudioContext? _audioCtx;
  web.MediaStream? _stream;
  web.AudioWorkletNode? _workletNode;
  web.MediaStreamAudioSourceNode? _sourceNode;
  StreamController<Uint8List>? _controller;

  Stream<Uint8List>? _micStream;
  Stream<Uint8List>? get micStream => _micStream;

  static const int _sampleRate = 16000; // 16 kHz – good quality, lower bandwidth

  Future<bool> start() async {
    try {
      // Request microphone permission
      final mediaDevices = web.window.navigator.mediaDevices;
      final constraints = web.MediaStreamConstraints(
        audio: true.toJS,
        video: false.toJS,
      );
      _stream = await mediaDevices.getUserMedia(constraints).toDart;

      // Create AudioContext at 16 kHz
      final ctxOptions = web.AudioContextOptions(sampleRate: _sampleRate);
      _audioCtx = web.AudioContext(ctxOptions);

      // Load the AudioWorklet processor script
      await _audioCtx!.audioWorklet
          .addModule('audio_processor.js')
          .toDart;

      // Create worklet node (mono input, no output needed)
      final nodeOptions = web.AudioWorkletNodeOptions(
        numberOfInputs: 1,
        numberOfOutputs: 0,
        channelCount: 1,
        channelCountMode: 'explicit',
        channelInterpretation: 'discrete',
      );
      _workletNode =
          web.AudioWorkletNode(_audioCtx!, 'pcm16-processor', nodeOptions);

      // Create a broadcast stream from the worklet messages
      _controller = StreamController<Uint8List>.broadcast();
      _workletNode!.port.onmessage = (web.MessageEvent evt) {
        final data = evt.data;
        // data is an ArrayBuffer containing Int16 PCM samples
        if (data != null && !_controller!.isClosed) {
          final byteList = (data as JSArrayBuffer).toDart.asUint8List();
          _controller!.add(byteList);
        }
      }.toJS;

      // Connect mic → worklet
      _sourceNode = _audioCtx!.createMediaStreamSource(_stream!);
      _sourceNode!.connect(_workletNode!);

      _micStream = _controller!.stream;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    _sourceNode?.disconnect();
    _workletNode?.disconnect();
    _stream?.getTracks().toDart.forEach((t) => t.stop());
    await _audioCtx?.close().toDart;
    await _controller?.close();
    _audioCtx = null;
    _stream = null;
    _workletNode = null;
    _sourceNode = null;
    _controller = null;
    _micStream = null;
  }
}
