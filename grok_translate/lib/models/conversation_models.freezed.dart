// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TranslationMessage _$TranslationMessageFromJson(Map<String, dynamic> json) {
  return _TranslationMessage.fromJson(json);
}

/// @nodoc
mixin _$TranslationMessage {
  String get id => throw _privateConstructorUsedError;
  Speaker get speaker => throw _privateConstructorUsedError;
  String get originalText => throw _privateConstructorUsedError;
  String get translatedText => throw _privateConstructorUsedError;
  String get fromLanguage => throw _privateConstructorUsedError;
  String get toLanguage => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isPartial => throw _privateConstructorUsedError;

  /// Serializes this TranslationMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TranslationMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranslationMessageCopyWith<TranslationMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranslationMessageCopyWith<$Res> {
  factory $TranslationMessageCopyWith(
          TranslationMessage value, $Res Function(TranslationMessage) then) =
      _$TranslationMessageCopyWithImpl<$Res, TranslationMessage>;
  @useResult
  $Res call(
      {String id,
      Speaker speaker,
      String originalText,
      String translatedText,
      String fromLanguage,
      String toLanguage,
      DateTime timestamp,
      bool isPartial});
}

/// @nodoc
class _$TranslationMessageCopyWithImpl<$Res, $Val extends TranslationMessage>
    implements $TranslationMessageCopyWith<$Res> {
  _$TranslationMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranslationMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? speaker = null,
    Object? originalText = null,
    Object? translatedText = null,
    Object? fromLanguage = null,
    Object? toLanguage = null,
    Object? timestamp = null,
    Object? isPartial = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      speaker: null == speaker
          ? _value.speaker
          : speaker // ignore: cast_nullable_to_non_nullable
              as Speaker,
      originalText: null == originalText
          ? _value.originalText
          : originalText // ignore: cast_nullable_to_non_nullable
              as String,
      translatedText: null == translatedText
          ? _value.translatedText
          : translatedText // ignore: cast_nullable_to_non_nullable
              as String,
      fromLanguage: null == fromLanguage
          ? _value.fromLanguage
          : fromLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      toLanguage: null == toLanguage
          ? _value.toLanguage
          : toLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isPartial: null == isPartial
          ? _value.isPartial
          : isPartial // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TranslationMessageImplCopyWith<$Res>
    implements $TranslationMessageCopyWith<$Res> {
  factory _$$TranslationMessageImplCopyWith(_$TranslationMessageImpl value,
          $Res Function(_$TranslationMessageImpl) then) =
      __$$TranslationMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      Speaker speaker,
      String originalText,
      String translatedText,
      String fromLanguage,
      String toLanguage,
      DateTime timestamp,
      bool isPartial});
}

/// @nodoc
class __$$TranslationMessageImplCopyWithImpl<$Res>
    extends _$TranslationMessageCopyWithImpl<$Res, _$TranslationMessageImpl>
    implements _$$TranslationMessageImplCopyWith<$Res> {
  __$$TranslationMessageImplCopyWithImpl(_$TranslationMessageImpl _value,
      $Res Function(_$TranslationMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of TranslationMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? speaker = null,
    Object? originalText = null,
    Object? translatedText = null,
    Object? fromLanguage = null,
    Object? toLanguage = null,
    Object? timestamp = null,
    Object? isPartial = null,
  }) {
    return _then(_$TranslationMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      speaker: null == speaker
          ? _value.speaker
          : speaker // ignore: cast_nullable_to_non_nullable
              as Speaker,
      originalText: null == originalText
          ? _value.originalText
          : originalText // ignore: cast_nullable_to_non_nullable
              as String,
      translatedText: null == translatedText
          ? _value.translatedText
          : translatedText // ignore: cast_nullable_to_non_nullable
              as String,
      fromLanguage: null == fromLanguage
          ? _value.fromLanguage
          : fromLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      toLanguage: null == toLanguage
          ? _value.toLanguage
          : toLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isPartial: null == isPartial
          ? _value.isPartial
          : isPartial // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TranslationMessageImpl implements _TranslationMessage {
  const _$TranslationMessageImpl(
      {required this.id,
      required this.speaker,
      required this.originalText,
      required this.translatedText,
      required this.fromLanguage,
      required this.toLanguage,
      required this.timestamp,
      this.isPartial = false});

  factory _$TranslationMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$TranslationMessageImplFromJson(json);

  @override
  final String id;
  @override
  final Speaker speaker;
  @override
  final String originalText;
  @override
  final String translatedText;
  @override
  final String fromLanguage;
  @override
  final String toLanguage;
  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final bool isPartial;

  @override
  String toString() {
    return 'TranslationMessage(id: $id, speaker: $speaker, originalText: $originalText, translatedText: $translatedText, fromLanguage: $fromLanguage, toLanguage: $toLanguage, timestamp: $timestamp, isPartial: $isPartial)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranslationMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.speaker, speaker) || other.speaker == speaker) &&
            (identical(other.originalText, originalText) ||
                other.originalText == originalText) &&
            (identical(other.translatedText, translatedText) ||
                other.translatedText == translatedText) &&
            (identical(other.fromLanguage, fromLanguage) ||
                other.fromLanguage == fromLanguage) &&
            (identical(other.toLanguage, toLanguage) ||
                other.toLanguage == toLanguage) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isPartial, isPartial) ||
                other.isPartial == isPartial));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, speaker, originalText,
      translatedText, fromLanguage, toLanguage, timestamp, isPartial);

  /// Create a copy of TranslationMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranslationMessageImplCopyWith<_$TranslationMessageImpl> get copyWith =>
      __$$TranslationMessageImplCopyWithImpl<_$TranslationMessageImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TranslationMessageImplToJson(
      this,
    );
  }
}

abstract class _TranslationMessage implements TranslationMessage {
  const factory _TranslationMessage(
      {required final String id,
      required final Speaker speaker,
      required final String originalText,
      required final String translatedText,
      required final String fromLanguage,
      required final String toLanguage,
      required final DateTime timestamp,
      final bool isPartial}) = _$TranslationMessageImpl;

  factory _TranslationMessage.fromJson(Map<String, dynamic> json) =
      _$TranslationMessageImpl.fromJson;

  @override
  String get id;
  @override
  Speaker get speaker;
  @override
  String get originalText;
  @override
  String get translatedText;
  @override
  String get fromLanguage;
  @override
  String get toLanguage;
  @override
  DateTime get timestamp;
  @override
  bool get isPartial;

  /// Create a copy of TranslationMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranslationMessageImplCopyWith<_$TranslationMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LanguageConfig _$LanguageConfigFromJson(Map<String, dynamic> json) {
  return _LanguageConfig.fromJson(json);
}

/// @nodoc
mixin _$LanguageConfig {
  String get lang1Code => throw _privateConstructorUsedError;
  String get lang2Code => throw _privateConstructorUsedError;
  String get lang1Name => throw _privateConstructorUsedError;
  String get lang2Name => throw _privateConstructorUsedError;
  bool get autoDetect => throw _privateConstructorUsedError;

  /// Serializes this LanguageConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LanguageConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LanguageConfigCopyWith<LanguageConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LanguageConfigCopyWith<$Res> {
  factory $LanguageConfigCopyWith(
          LanguageConfig value, $Res Function(LanguageConfig) then) =
      _$LanguageConfigCopyWithImpl<$Res, LanguageConfig>;
  @useResult
  $Res call(
      {String lang1Code,
      String lang2Code,
      String lang1Name,
      String lang2Name,
      bool autoDetect});
}

/// @nodoc
class _$LanguageConfigCopyWithImpl<$Res, $Val extends LanguageConfig>
    implements $LanguageConfigCopyWith<$Res> {
  _$LanguageConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LanguageConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lang1Code = null,
    Object? lang2Code = null,
    Object? lang1Name = null,
    Object? lang2Name = null,
    Object? autoDetect = null,
  }) {
    return _then(_value.copyWith(
      lang1Code: null == lang1Code
          ? _value.lang1Code
          : lang1Code // ignore: cast_nullable_to_non_nullable
              as String,
      lang2Code: null == lang2Code
          ? _value.lang2Code
          : lang2Code // ignore: cast_nullable_to_non_nullable
              as String,
      lang1Name: null == lang1Name
          ? _value.lang1Name
          : lang1Name // ignore: cast_nullable_to_non_nullable
              as String,
      lang2Name: null == lang2Name
          ? _value.lang2Name
          : lang2Name // ignore: cast_nullable_to_non_nullable
              as String,
      autoDetect: null == autoDetect
          ? _value.autoDetect
          : autoDetect // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LanguageConfigImplCopyWith<$Res>
    implements $LanguageConfigCopyWith<$Res> {
  factory _$$LanguageConfigImplCopyWith(_$LanguageConfigImpl value,
          $Res Function(_$LanguageConfigImpl) then) =
      __$$LanguageConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String lang1Code,
      String lang2Code,
      String lang1Name,
      String lang2Name,
      bool autoDetect});
}

/// @nodoc
class __$$LanguageConfigImplCopyWithImpl<$Res>
    extends _$LanguageConfigCopyWithImpl<$Res, _$LanguageConfigImpl>
    implements _$$LanguageConfigImplCopyWith<$Res> {
  __$$LanguageConfigImplCopyWithImpl(
      _$LanguageConfigImpl _value, $Res Function(_$LanguageConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of LanguageConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lang1Code = null,
    Object? lang2Code = null,
    Object? lang1Name = null,
    Object? lang2Name = null,
    Object? autoDetect = null,
  }) {
    return _then(_$LanguageConfigImpl(
      lang1Code: null == lang1Code
          ? _value.lang1Code
          : lang1Code // ignore: cast_nullable_to_non_nullable
              as String,
      lang2Code: null == lang2Code
          ? _value.lang2Code
          : lang2Code // ignore: cast_nullable_to_non_nullable
              as String,
      lang1Name: null == lang1Name
          ? _value.lang1Name
          : lang1Name // ignore: cast_nullable_to_non_nullable
              as String,
      lang2Name: null == lang2Name
          ? _value.lang2Name
          : lang2Name // ignore: cast_nullable_to_non_nullable
              as String,
      autoDetect: null == autoDetect
          ? _value.autoDetect
          : autoDetect // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LanguageConfigImpl implements _LanguageConfig {
  const _$LanguageConfigImpl(
      {this.lang1Code = 'auto',
      this.lang2Code = 'auto',
      this.lang1Name = 'Auto Detect',
      this.lang2Name = 'Auto Detect',
      this.autoDetect = true});

  factory _$LanguageConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$LanguageConfigImplFromJson(json);

  @override
  @JsonKey()
  final String lang1Code;
  @override
  @JsonKey()
  final String lang2Code;
  @override
  @JsonKey()
  final String lang1Name;
  @override
  @JsonKey()
  final String lang2Name;
  @override
  @JsonKey()
  final bool autoDetect;

  @override
  String toString() {
    return 'LanguageConfig(lang1Code: $lang1Code, lang2Code: $lang2Code, lang1Name: $lang1Name, lang2Name: $lang2Name, autoDetect: $autoDetect)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LanguageConfigImpl &&
            (identical(other.lang1Code, lang1Code) ||
                other.lang1Code == lang1Code) &&
            (identical(other.lang2Code, lang2Code) ||
                other.lang2Code == lang2Code) &&
            (identical(other.lang1Name, lang1Name) ||
                other.lang1Name == lang1Name) &&
            (identical(other.lang2Name, lang2Name) ||
                other.lang2Name == lang2Name) &&
            (identical(other.autoDetect, autoDetect) ||
                other.autoDetect == autoDetect));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, lang1Code, lang2Code, lang1Name, lang2Name, autoDetect);

  /// Create a copy of LanguageConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LanguageConfigImplCopyWith<_$LanguageConfigImpl> get copyWith =>
      __$$LanguageConfigImplCopyWithImpl<_$LanguageConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LanguageConfigImplToJson(
      this,
    );
  }
}

abstract class _LanguageConfig implements LanguageConfig {
  const factory _LanguageConfig(
      {final String lang1Code,
      final String lang2Code,
      final String lang1Name,
      final String lang2Name,
      final bool autoDetect}) = _$LanguageConfigImpl;

  factory _LanguageConfig.fromJson(Map<String, dynamic> json) =
      _$LanguageConfigImpl.fromJson;

  @override
  String get lang1Code;
  @override
  String get lang2Code;
  @override
  String get lang1Name;
  @override
  String get lang2Name;
  @override
  bool get autoDetect;

  /// Create a copy of LanguageConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LanguageConfigImplCopyWith<_$LanguageConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ConversationState {
  ConversationStatus get status => throw _privateConstructorUsedError;
  List<TranslationMessage> get messages => throw _privateConstructorUsedError;
  LanguageConfig? get languageConfig => throw _privateConstructorUsedError;
  Speaker? get activeSpeaker => throw _privateConstructorUsedError;
  bool get subtitlesEnabled => throw _privateConstructorUsedError;
  bool get isConnected => throw _privateConstructorUsedError;
  bool get isSessionActive => throw _privateConstructorUsedError;
  String get partialTranscript => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  double get vadThreshold => throw _privateConstructorUsedError;
  int get vadSilenceDurationMs => throw _privateConstructorUsedError;

  /// Create a copy of ConversationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationStateCopyWith<ConversationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationStateCopyWith<$Res> {
  factory $ConversationStateCopyWith(
          ConversationState value, $Res Function(ConversationState) then) =
      _$ConversationStateCopyWithImpl<$Res, ConversationState>;
  @useResult
  $Res call(
      {ConversationStatus status,
      List<TranslationMessage> messages,
      LanguageConfig? languageConfig,
      Speaker? activeSpeaker,
      bool subtitlesEnabled,
      bool isConnected,
      bool isSessionActive,
      String partialTranscript,
      String? errorMessage,
      double vadThreshold,
      int vadSilenceDurationMs});

  $LanguageConfigCopyWith<$Res>? get languageConfig;
}

/// @nodoc
class _$ConversationStateCopyWithImpl<$Res, $Val extends ConversationState>
    implements $ConversationStateCopyWith<$Res> {
  _$ConversationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? messages = null,
    Object? languageConfig = freezed,
    Object? activeSpeaker = freezed,
    Object? subtitlesEnabled = null,
    Object? isConnected = null,
    Object? isSessionActive = null,
    Object? partialTranscript = null,
    Object? errorMessage = freezed,
    Object? vadThreshold = null,
    Object? vadSilenceDurationMs = null,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ConversationStatus,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<TranslationMessage>,
      languageConfig: freezed == languageConfig
          ? _value.languageConfig
          : languageConfig // ignore: cast_nullable_to_non_nullable
              as LanguageConfig?,
      activeSpeaker: freezed == activeSpeaker
          ? _value.activeSpeaker
          : activeSpeaker // ignore: cast_nullable_to_non_nullable
              as Speaker?,
      subtitlesEnabled: null == subtitlesEnabled
          ? _value.subtitlesEnabled
          : subtitlesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isConnected: null == isConnected
          ? _value.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      isSessionActive: null == isSessionActive
          ? _value.isSessionActive
          : isSessionActive // ignore: cast_nullable_to_non_nullable
              as bool,
      partialTranscript: null == partialTranscript
          ? _value.partialTranscript
          : partialTranscript // ignore: cast_nullable_to_non_nullable
              as String,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      vadThreshold: null == vadThreshold
          ? _value.vadThreshold
          : vadThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      vadSilenceDurationMs: null == vadSilenceDurationMs
          ? _value.vadSilenceDurationMs
          : vadSilenceDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of ConversationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LanguageConfigCopyWith<$Res>? get languageConfig {
    if (_value.languageConfig == null) {
      return null;
    }

    return $LanguageConfigCopyWith<$Res>(_value.languageConfig!, (value) {
      return _then(_value.copyWith(languageConfig: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ConversationStateImplCopyWith<$Res>
    implements $ConversationStateCopyWith<$Res> {
  factory _$$ConversationStateImplCopyWith(_$ConversationStateImpl value,
          $Res Function(_$ConversationStateImpl) then) =
      __$$ConversationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ConversationStatus status,
      List<TranslationMessage> messages,
      LanguageConfig? languageConfig,
      Speaker? activeSpeaker,
      bool subtitlesEnabled,
      bool isConnected,
      bool isSessionActive,
      String partialTranscript,
      String? errorMessage,
      double vadThreshold,
      int vadSilenceDurationMs});

  @override
  $LanguageConfigCopyWith<$Res>? get languageConfig;
}

/// @nodoc
class __$$ConversationStateImplCopyWithImpl<$Res>
    extends _$ConversationStateCopyWithImpl<$Res, _$ConversationStateImpl>
    implements _$$ConversationStateImplCopyWith<$Res> {
  __$$ConversationStateImplCopyWithImpl(_$ConversationStateImpl _value,
      $Res Function(_$ConversationStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ConversationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? messages = null,
    Object? languageConfig = freezed,
    Object? activeSpeaker = freezed,
    Object? subtitlesEnabled = null,
    Object? isConnected = null,
    Object? isSessionActive = null,
    Object? partialTranscript = null,
    Object? errorMessage = freezed,
    Object? vadThreshold = null,
    Object? vadSilenceDurationMs = null,
  }) {
    return _then(_$ConversationStateImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ConversationStatus,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<TranslationMessage>,
      languageConfig: freezed == languageConfig
          ? _value.languageConfig
          : languageConfig // ignore: cast_nullable_to_non_nullable
              as LanguageConfig?,
      activeSpeaker: freezed == activeSpeaker
          ? _value.activeSpeaker
          : activeSpeaker // ignore: cast_nullable_to_non_nullable
              as Speaker?,
      subtitlesEnabled: null == subtitlesEnabled
          ? _value.subtitlesEnabled
          : subtitlesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isConnected: null == isConnected
          ? _value.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      isSessionActive: null == isSessionActive
          ? _value.isSessionActive
          : isSessionActive // ignore: cast_nullable_to_non_nullable
              as bool,
      partialTranscript: null == partialTranscript
          ? _value.partialTranscript
          : partialTranscript // ignore: cast_nullable_to_non_nullable
              as String,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      vadThreshold: null == vadThreshold
          ? _value.vadThreshold
          : vadThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      vadSilenceDurationMs: null == vadSilenceDurationMs
          ? _value.vadSilenceDurationMs
          : vadSilenceDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$ConversationStateImpl implements _ConversationState {
  const _$ConversationStateImpl(
      {this.status = ConversationStatus.idle,
      final List<TranslationMessage> messages = const [],
      this.languageConfig,
      this.activeSpeaker,
      this.subtitlesEnabled = true,
      this.isConnected = false,
      this.isSessionActive = false,
      this.partialTranscript = '',
      this.errorMessage,
      this.vadThreshold = 0.6,
      this.vadSilenceDurationMs = 400})
      : _messages = messages;

  @override
  @JsonKey()
  final ConversationStatus status;
  final List<TranslationMessage> _messages;
  @override
  @JsonKey()
  List<TranslationMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  final LanguageConfig? languageConfig;
  @override
  final Speaker? activeSpeaker;
  @override
  @JsonKey()
  final bool subtitlesEnabled;
  @override
  @JsonKey()
  final bool isConnected;
  @override
  @JsonKey()
  final bool isSessionActive;
  @override
  @JsonKey()
  final String partialTranscript;
  @override
  final String? errorMessage;
  @override
  @JsonKey()
  final double vadThreshold;
  @override
  @JsonKey()
  final int vadSilenceDurationMs;

  @override
  String toString() {
    return 'ConversationState(status: $status, messages: $messages, languageConfig: $languageConfig, activeSpeaker: $activeSpeaker, subtitlesEnabled: $subtitlesEnabled, isConnected: $isConnected, isSessionActive: $isSessionActive, partialTranscript: $partialTranscript, errorMessage: $errorMessage, vadThreshold: $vadThreshold, vadSilenceDurationMs: $vadSilenceDurationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.languageConfig, languageConfig) ||
                other.languageConfig == languageConfig) &&
            (identical(other.activeSpeaker, activeSpeaker) ||
                other.activeSpeaker == activeSpeaker) &&
            (identical(other.subtitlesEnabled, subtitlesEnabled) ||
                other.subtitlesEnabled == subtitlesEnabled) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.isSessionActive, isSessionActive) ||
                other.isSessionActive == isSessionActive) &&
            (identical(other.partialTranscript, partialTranscript) ||
                other.partialTranscript == partialTranscript) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.vadThreshold, vadThreshold) ||
                other.vadThreshold == vadThreshold) &&
            (identical(other.vadSilenceDurationMs, vadSilenceDurationMs) ||
                other.vadSilenceDurationMs == vadSilenceDurationMs));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_messages),
      languageConfig,
      activeSpeaker,
      subtitlesEnabled,
      isConnected,
      isSessionActive,
      partialTranscript,
      errorMessage,
      vadThreshold,
      vadSilenceDurationMs);

  /// Create a copy of ConversationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationStateImplCopyWith<_$ConversationStateImpl> get copyWith =>
      __$$ConversationStateImplCopyWithImpl<_$ConversationStateImpl>(
          this, _$identity);
}

abstract class _ConversationState implements ConversationState {
  const factory _ConversationState(
      {final ConversationStatus status,
      final List<TranslationMessage> messages,
      final LanguageConfig? languageConfig,
      final Speaker? activeSpeaker,
      final bool subtitlesEnabled,
      final bool isConnected,
      final bool isSessionActive,
      final String partialTranscript,
      final String? errorMessage,
      final double vadThreshold,
      final int vadSilenceDurationMs}) = _$ConversationStateImpl;

  @override
  ConversationStatus get status;
  @override
  List<TranslationMessage> get messages;
  @override
  LanguageConfig? get languageConfig;
  @override
  Speaker? get activeSpeaker;
  @override
  bool get subtitlesEnabled;
  @override
  bool get isConnected;
  @override
  bool get isSessionActive;
  @override
  String get partialTranscript;
  @override
  String? get errorMessage;
  @override
  double get vadThreshold;
  @override
  int get vadSilenceDurationMs;

  /// Create a copy of ConversationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationStateImplCopyWith<_$ConversationStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VadSettings _$VadSettingsFromJson(Map<String, dynamic> json) {
  return _VadSettings.fromJson(json);
}

/// @nodoc
mixin _$VadSettings {
  double get threshold => throw _privateConstructorUsedError;
  int get silenceDurationMs => throw _privateConstructorUsedError;

  /// Serializes this VadSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VadSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VadSettingsCopyWith<VadSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VadSettingsCopyWith<$Res> {
  factory $VadSettingsCopyWith(
          VadSettings value, $Res Function(VadSettings) then) =
      _$VadSettingsCopyWithImpl<$Res, VadSettings>;
  @useResult
  $Res call({double threshold, int silenceDurationMs});
}

/// @nodoc
class _$VadSettingsCopyWithImpl<$Res, $Val extends VadSettings>
    implements $VadSettingsCopyWith<$Res> {
  _$VadSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VadSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? threshold = null,
    Object? silenceDurationMs = null,
  }) {
    return _then(_value.copyWith(
      threshold: null == threshold
          ? _value.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
      silenceDurationMs: null == silenceDurationMs
          ? _value.silenceDurationMs
          : silenceDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VadSettingsImplCopyWith<$Res>
    implements $VadSettingsCopyWith<$Res> {
  factory _$$VadSettingsImplCopyWith(
          _$VadSettingsImpl value, $Res Function(_$VadSettingsImpl) then) =
      __$$VadSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double threshold, int silenceDurationMs});
}

/// @nodoc
class __$$VadSettingsImplCopyWithImpl<$Res>
    extends _$VadSettingsCopyWithImpl<$Res, _$VadSettingsImpl>
    implements _$$VadSettingsImplCopyWith<$Res> {
  __$$VadSettingsImplCopyWithImpl(
      _$VadSettingsImpl _value, $Res Function(_$VadSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of VadSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? threshold = null,
    Object? silenceDurationMs = null,
  }) {
    return _then(_$VadSettingsImpl(
      threshold: null == threshold
          ? _value.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
      silenceDurationMs: null == silenceDurationMs
          ? _value.silenceDurationMs
          : silenceDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VadSettingsImpl implements _VadSettings {
  const _$VadSettingsImpl({this.threshold = 0.6, this.silenceDurationMs = 400});

  factory _$VadSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$VadSettingsImplFromJson(json);

  @override
  @JsonKey()
  final double threshold;
  @override
  @JsonKey()
  final int silenceDurationMs;

  @override
  String toString() {
    return 'VadSettings(threshold: $threshold, silenceDurationMs: $silenceDurationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VadSettingsImpl &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.silenceDurationMs, silenceDurationMs) ||
                other.silenceDurationMs == silenceDurationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, threshold, silenceDurationMs);

  /// Create a copy of VadSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VadSettingsImplCopyWith<_$VadSettingsImpl> get copyWith =>
      __$$VadSettingsImplCopyWithImpl<_$VadSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VadSettingsImplToJson(
      this,
    );
  }
}

abstract class _VadSettings implements VadSettings {
  const factory _VadSettings(
      {final double threshold,
      final int silenceDurationMs}) = _$VadSettingsImpl;

  factory _VadSettings.fromJson(Map<String, dynamic> json) =
      _$VadSettingsImpl.fromJson;

  @override
  double get threshold;
  @override
  int get silenceDurationMs;

  /// Create a copy of VadSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VadSettingsImplCopyWith<_$VadSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
