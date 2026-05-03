// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TranslationMessageImpl _$$TranslationMessageImplFromJson(
        Map<String, dynamic> json) =>
    _$TranslationMessageImpl(
      id: json['id'] as String,
      speaker: $enumDecode(_$SpeakerEnumMap, json['speaker']),
      originalText: json['originalText'] as String,
      translatedText: json['translatedText'] as String,
      fromLanguage: json['fromLanguage'] as String,
      toLanguage: json['toLanguage'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isPartial: json['isPartial'] as bool? ?? false,
    );

Map<String, dynamic> _$$TranslationMessageImplToJson(
        _$TranslationMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'speaker': _$SpeakerEnumMap[instance.speaker]!,
      'originalText': instance.originalText,
      'translatedText': instance.translatedText,
      'fromLanguage': instance.fromLanguage,
      'toLanguage': instance.toLanguage,
      'timestamp': instance.timestamp.toIso8601String(),
      'isPartial': instance.isPartial,
    };

const _$SpeakerEnumMap = {
  Speaker.user1: 'user1',
  Speaker.user2: 'user2',
};

_$LanguageConfigImpl _$$LanguageConfigImplFromJson(Map<String, dynamic> json) =>
    _$LanguageConfigImpl(
      lang1Code: json['lang1Code'] as String? ?? 'auto',
      lang2Code: json['lang2Code'] as String? ?? 'auto',
      lang1Name: json['lang1Name'] as String? ?? 'Auto Detect',
      lang2Name: json['lang2Name'] as String? ?? 'Auto Detect',
      autoDetect: json['autoDetect'] as bool? ?? true,
    );

Map<String, dynamic> _$$LanguageConfigImplToJson(
        _$LanguageConfigImpl instance) =>
    <String, dynamic>{
      'lang1Code': instance.lang1Code,
      'lang2Code': instance.lang2Code,
      'lang1Name': instance.lang1Name,
      'lang2Name': instance.lang2Name,
      'autoDetect': instance.autoDetect,
    };

_$VadSettingsImpl _$$VadSettingsImplFromJson(Map<String, dynamic> json) =>
    _$VadSettingsImpl(
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.6,
      silenceDurationMs: (json['silenceDurationMs'] as num?)?.toInt() ?? 700,
    );

Map<String, dynamic> _$$VadSettingsImplToJson(_$VadSettingsImpl instance) =>
    <String, dynamic>{
      'threshold': instance.threshold,
      'silenceDurationMs': instance.silenceDurationMs,
    };
