import 'package:freezed_annotation/freezed_annotation.dart';

part 'grok_api_models.freezed.dart';
part 'grok_api_models.g.dart';

// ---------------------------------------------------------------------------
// Outbound messages → Grok Realtime API
// ---------------------------------------------------------------------------

/// Base class for all outbound Grok Realtime events.
@freezed
class GrokOutboundEvent with _$GrokOutboundEvent {
  /// session.update – send configuration including system prompt & VAD params.
  const factory GrokOutboundEvent.sessionUpdate({
    required SessionUpdatePayload session,
  }) = _SessionUpdate;

  /// input_audio_buffer.append – stream raw audio bytes (base64-encoded).
  const factory GrokOutboundEvent.audioAppend({
    required String audio, // base64 PCM16 @ 24 kHz mono
  }) = _AudioAppend;

  /// input_audio_buffer.commit – signal end-of-utterance in manual VAD mode.
  const factory GrokOutboundEvent.audioCommit() = _AudioCommit;

  /// response.create – request translation response.
  const factory GrokOutboundEvent.responseCreate() = _ResponseCreate;

  /// response.cancel – barge-in: cancel the current response.
  const factory GrokOutboundEvent.responseCancel() = _ResponseCancel;
}

@freezed
class SessionUpdatePayload with _$SessionUpdatePayload {
  const factory SessionUpdatePayload({
    required String model,
    required String instructions,
    @Default('both') String modalities, // 'text', 'audio', or 'both'
    @Default('alloy') String voice,
    @Default('pcm16') String inputAudioFormat,
    @Default('pcm16') String outputAudioFormat,
    TurnDetectionConfig? turnDetection,
  }) = _SessionUpdatePayload;

  factory SessionUpdatePayload.fromJson(Map<String, dynamic> json) =>
      _$SessionUpdatePayloadFromJson(json);
}

@freezed
class TurnDetectionConfig with _$TurnDetectionConfig {
  const factory TurnDetectionConfig({
    @Default('server_vad') String type,
    @Default(0.6) double threshold,
    @Default(300) int prefixPaddingMs,
    @Default(400) int silenceDurationMs,
    @Default(true) bool createResponse,
  }) = _TurnDetectionConfig;

  factory TurnDetectionConfig.fromJson(Map<String, dynamic> json) =>
      _$TurnDetectionConfigFromJson(json);
}

// ---------------------------------------------------------------------------
// Inbound messages ← Grok Realtime API
// ---------------------------------------------------------------------------

/// All server event types we care about.
enum GrokServerEventType {
  sessionCreated,
  sessionUpdated,
  inputAudioBufferSpeechStarted,
  inputAudioBufferSpeechStopped,
  inputAudioBufferCommitted,
  responseCreated,
  responseAudioDelta,
  responseAudioDone,
  responseAudioTranscriptDelta,
  responseAudioTranscriptDone,
  responseDone,
  error,
  unknown,
}

GrokServerEventType grokEventTypeFromString(String type) {
  return const {
    'session.created': GrokServerEventType.sessionCreated,
    'session.updated': GrokServerEventType.sessionUpdated,
    // VAD events
    'input_audio_buffer.speech_started':
        GrokServerEventType.inputAudioBufferSpeechStarted,
    'input_audio_buffer.speech_stopped':
        GrokServerEventType.inputAudioBufferSpeechStopped,
    'input_audio_buffer.committed':
        GrokServerEventType.inputAudioBufferCommitted,
    'response.created': GrokServerEventType.responseCreated,
    // xAI uses response.output_audio.delta / .done (not response.audio.*)
    'response.output_audio.delta': GrokServerEventType.responseAudioDelta,
    'response.output_audio.done': GrokServerEventType.responseAudioDone,
    // Transcript events
    'response.audio_transcript.delta':
        GrokServerEventType.responseAudioTranscriptDelta,
    'response.audio_transcript.done':
        GrokServerEventType.responseAudioTranscriptDone,
    'response.done': GrokServerEventType.responseDone,
    'error': GrokServerEventType.error,
  }[type] ??
      GrokServerEventType.unknown;
}

/// Parsed inbound event from the server.
@freezed
class GrokServerEvent with _$GrokServerEvent {
  const factory GrokServerEvent({
    required GrokServerEventType type,
    String? eventId,
    String? audioDelta, // base64 PCM16
    String? transcriptDelta,
    String? transcriptText,
    String? errorMessage,
    Map<String, dynamic>? raw,
  }) = _GrokServerEvent;
}
