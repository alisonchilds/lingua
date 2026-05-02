// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grok_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SessionUpdatePayloadImpl _$$SessionUpdatePayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$SessionUpdatePayloadImpl(
      model: json['model'] as String,
      instructions: json['instructions'] as String,
      modalities: json['modalities'] as String? ?? 'both',
      voice: json['voice'] as String? ?? 'alloy',
      inputAudioFormat: json['inputAudioFormat'] as String? ?? 'pcm16',
      outputAudioFormat: json['outputAudioFormat'] as String? ?? 'pcm16',
      turnDetection: json['turnDetection'] == null
          ? null
          : TurnDetectionConfig.fromJson(
              json['turnDetection'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$SessionUpdatePayloadImplToJson(
        _$SessionUpdatePayloadImpl instance) =>
    <String, dynamic>{
      'model': instance.model,
      'instructions': instance.instructions,
      'modalities': instance.modalities,
      'voice': instance.voice,
      'inputAudioFormat': instance.inputAudioFormat,
      'outputAudioFormat': instance.outputAudioFormat,
      'turnDetection': instance.turnDetection,
    };

_$TurnDetectionConfigImpl _$$TurnDetectionConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$TurnDetectionConfigImpl(
      type: json['type'] as String? ?? 'server_vad',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.6,
      prefixPaddingMs: (json['prefixPaddingMs'] as num?)?.toInt() ?? 300,
      silenceDurationMs: (json['silenceDurationMs'] as num?)?.toInt() ?? 400,
      createResponse: json['createResponse'] as bool? ?? true,
    );

Map<String, dynamic> _$$TurnDetectionConfigImplToJson(
        _$TurnDetectionConfigImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'threshold': instance.threshold,
      'prefixPaddingMs': instance.prefixPaddingMs,
      'silenceDurationMs': instance.silenceDurationMs,
      'createResponse': instance.createResponse,
    };
