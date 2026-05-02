// AudioWorklet processor – runs in a dedicated audio thread.
// Receives raw float32 PCM samples from the microphone, converts them to
// PCM16 little-endian, and posts them back to the main thread.
class PCM16Processor extends AudioWorkletProcessor {
  constructor() {
    super();
    // Buffer ~100ms of audio before posting (at 16kHz = 1600 samples)
    this._bufferSize = 1600;
    this._buffer = new Int16Array(this._bufferSize);
    this._offset = 0;
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0]) return true;

    const samples = input[0]; // Float32Array, mono
    for (let i = 0; i < samples.length; i++) {
      // Clamp and convert float32 → int16
      const s = Math.max(-1, Math.min(1, samples[i]));
      this._buffer[this._offset++] = s < 0 ? s * 0x8000 : s * 0x7FFF;

      if (this._offset >= this._bufferSize) {
        // Transfer a copy to the main thread (zero-copy with transfer)
        const copy = new Int16Array(this._buffer);
        this.port.postMessage(copy.buffer, [copy.buffer]);
        this._offset = 0;
        this._buffer = new Int16Array(this._bufferSize);
      }
    }
    return true; // keep processor alive
  }
}

registerProcessor('pcm16-processor', PCM16Processor);
