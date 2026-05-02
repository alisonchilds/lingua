import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_models.freezed.dart';
part 'conversation_models.g.dart';

/// Which "side" of the conversation spoke / is speaking.
enum Speaker { user1, user2 }

/// Visual state of the translation pipeline.
enum ConversationStatus {
  idle,
  listening,
  translating,
  speaking,
  error,
}

/// A single translated utterance shown in the subtitle log.
@freezed
class TranslationMessage with _$TranslationMessage {
  const factory TranslationMessage({
    required String id,
    required Speaker speaker,
    required String originalText,
    required String translatedText,
    required String fromLanguage,
    required String toLanguage,
    required DateTime timestamp,
    @Default(false) bool isPartial,
  }) = _TranslationMessage;

  factory TranslationMessage.fromJson(Map<String, dynamic> json) =>
      _$TranslationMessageFromJson(json);
}

/// Language configuration for the session.
@freezed
class LanguageConfig with _$LanguageConfig {
  const factory LanguageConfig({
    @Default('auto') String lang1Code,
    @Default('auto') String lang2Code,
    @Default('Auto Detect') String lang1Name,
    @Default('Auto Detect') String lang2Name,
    @Default(true) bool autoDetect,
  }) = _LanguageConfig;

  factory LanguageConfig.fromJson(Map<String, dynamic> json) =>
      _$LanguageConfigFromJson(json);
}

/// Top-level state managed by ConversationController.
@freezed
class ConversationState with _$ConversationState {
  const factory ConversationState({
    @Default(ConversationStatus.idle) ConversationStatus status,
    @Default([]) List<TranslationMessage> messages,
    LanguageConfig? languageConfig,
    Speaker? activeSpeaker,
    @Default(true) bool subtitlesEnabled,
    @Default(false) bool isConnected,
    @Default(false) bool isSessionActive,
    @Default('') String partialTranscript,
    String? errorMessage,
    @Default(0.6) double vadThreshold,
    @Default(400) int vadSilenceDurationMs,
    // Detected languages — populated once the API identifies speech
    String? detectedLang1,   // e.g. "English"
    String? detectedLang2,   // e.g. "French"
    String? detectedLang1Flag,
    String? detectedLang2Flag,
  }) = _ConversationState;
}

/// VAD (voice activity detection) settings persisted in preferences.
@freezed
class VadSettings with _$VadSettings {
  const factory VadSettings({
    @Default(0.6) double threshold,
    @Default(400) int silenceDurationMs,
  }) = _VadSettings;

  factory VadSettings.fromJson(Map<String, dynamic> json) =>
      _$VadSettingsFromJson(json);
}

/// Supported languages (ISO 639-1 + display name).
class SupportedLanguage {
  const SupportedLanguage(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}

const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage('auto', 'Auto Detect', '🌐'),
  SupportedLanguage('en', 'English', '🇺🇸'),
  SupportedLanguage('es', 'Spanish', '🇪🇸'),
  SupportedLanguage('fr', 'French', '🇫🇷'),
  SupportedLanguage('de', 'German', '🇩🇪'),
  SupportedLanguage('it', 'Italian', '🇮🇹'),
  SupportedLanguage('pt', 'Portuguese', '🇧🇷'),
  SupportedLanguage('zh', 'Chinese', '🇨🇳'),
  SupportedLanguage('ja', 'Japanese', '🇯🇵'),
  SupportedLanguage('ko', 'Korean', '🇰🇷'),
  SupportedLanguage('ar', 'Arabic', '🇸🇦'),
  SupportedLanguage('ru', 'Russian', '🇷🇺'),
  SupportedLanguage('hi', 'Hindi', '🇮🇳'),
  SupportedLanguage('tr', 'Turkish', '🇹🇷'),
  SupportedLanguage('pl', 'Polish', '🇵🇱'),
  SupportedLanguage('nl', 'Dutch', '🇳🇱'),
  SupportedLanguage('sv', 'Swedish', '🇸🇪'),
  SupportedLanguage('uk', 'Ukrainian', '🇺🇦'),
];
