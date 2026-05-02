// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grok_api_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GrokOutboundEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SessionUpdatePayload session) sessionUpdate,
    required TResult Function(String audio) audioAppend,
    required TResult Function() audioCommit,
    required TResult Function() responseCreate,
    required TResult Function() responseCancel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SessionUpdatePayload session)? sessionUpdate,
    TResult? Function(String audio)? audioAppend,
    TResult? Function()? audioCommit,
    TResult? Function()? responseCreate,
    TResult? Function()? responseCancel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SessionUpdatePayload session)? sessionUpdate,
    TResult Function(String audio)? audioAppend,
    TResult Function()? audioCommit,
    TResult Function()? responseCreate,
    TResult Function()? responseCancel,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SessionUpdate value) sessionUpdate,
    required TResult Function(_AudioAppend value) audioAppend,
    required TResult Function(_AudioCommit value) audioCommit,
    required TResult Function(_ResponseCreate value) responseCreate,
    required TResult Function(_ResponseCancel value) responseCancel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SessionUpdate value)? sessionUpdate,
    TResult? Function(_AudioAppend value)? audioAppend,
    TResult? Function(_AudioCommit value)? audioCommit,
    TResult? Function(_ResponseCreate value)? responseCreate,
    TResult? Function(_ResponseCancel value)? responseCancel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SessionUpdate value)? sessionUpdate,
    TResult Function(_AudioAppend value)? audioAppend,
    TResult Function(_AudioCommit value)? audioCommit,
    TResult Function(_ResponseCreate value)? responseCreate,
    TResult Function(_ResponseCancel value)? responseCancel,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GrokOutboundEventCopyWith<$Res> {
  factory $GrokOutboundEventCopyWith(
          GrokOutboundEvent value, $Res Function(GrokOutboundEvent) then) =
      _$GrokOutboundEventCopyWithImpl<$Res, GrokOutboundEvent>;
}

/// @nodoc
class _$GrokOutboundEventCopyWithImpl<$Res, $Val extends GrokOutboundEvent>
    implements $GrokOutboundEventCopyWith<$Res> {
  _$GrokOutboundEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$SessionUpdateImplCopyWith<$Res> {
  factory _$$SessionUpdateImplCopyWith(
          _$SessionUpdateImpl value, $Res Function(_$SessionUpdateImpl) then) =
      __$$SessionUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({SessionUpdatePayload session});

  $SessionUpdatePayloadCopyWith<$Res> get session;
}

/// @nodoc
class __$$SessionUpdateImplCopyWithImpl<$Res>
    extends _$GrokOutboundEventCopyWithImpl<$Res, _$SessionUpdateImpl>
    implements _$$SessionUpdateImplCopyWith<$Res> {
  __$$SessionUpdateImplCopyWithImpl(
      _$SessionUpdateImpl _value, $Res Function(_$SessionUpdateImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
  }) {
    return _then(_$SessionUpdateImpl(
      session: null == session
          ? _value.session
          : session // ignore: cast_nullable_to_non_nullable
              as SessionUpdatePayload,
    ));
  }

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionUpdatePayloadCopyWith<$Res> get session {
    return $SessionUpdatePayloadCopyWith<$Res>(_value.session, (value) {
      return _then(_value.copyWith(session: value));
    });
  }
}

/// @nodoc

class _$SessionUpdateImpl implements _SessionUpdate {
  const _$SessionUpdateImpl({required this.session});

  @override
  final SessionUpdatePayload session;

  @override
  String toString() {
    return 'GrokOutboundEvent.sessionUpdate(session: $session)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionUpdateImpl &&
            (identical(other.session, session) || other.session == session));
  }

  @override
  int get hashCode => Object.hash(runtimeType, session);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionUpdateImplCopyWith<_$SessionUpdateImpl> get copyWith =>
      __$$SessionUpdateImplCopyWithImpl<_$SessionUpdateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SessionUpdatePayload session) sessionUpdate,
    required TResult Function(String audio) audioAppend,
    required TResult Function() audioCommit,
    required TResult Function() responseCreate,
    required TResult Function() responseCancel,
  }) {
    return sessionUpdate(session);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SessionUpdatePayload session)? sessionUpdate,
    TResult? Function(String audio)? audioAppend,
    TResult? Function()? audioCommit,
    TResult? Function()? responseCreate,
    TResult? Function()? responseCancel,
  }) {
    return sessionUpdate?.call(session);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SessionUpdatePayload session)? sessionUpdate,
    TResult Function(String audio)? audioAppend,
    TResult Function()? audioCommit,
    TResult Function()? responseCreate,
    TResult Function()? responseCancel,
    required TResult orElse(),
  }) {
    if (sessionUpdate != null) {
      return sessionUpdate(session);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SessionUpdate value) sessionUpdate,
    required TResult Function(_AudioAppend value) audioAppend,
    required TResult Function(_AudioCommit value) audioCommit,
    required TResult Function(_ResponseCreate value) responseCreate,
    required TResult Function(_ResponseCancel value) responseCancel,
  }) {
    return sessionUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SessionUpdate value)? sessionUpdate,
    TResult? Function(_AudioAppend value)? audioAppend,
    TResult? Function(_AudioCommit value)? audioCommit,
    TResult? Function(_ResponseCreate value)? responseCreate,
    TResult? Function(_ResponseCancel value)? responseCancel,
  }) {
    return sessionUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SessionUpdate value)? sessionUpdate,
    TResult Function(_AudioAppend value)? audioAppend,
    TResult Function(_AudioCommit value)? audioCommit,
    TResult Function(_ResponseCreate value)? responseCreate,
    TResult Function(_ResponseCancel value)? responseCancel,
    required TResult orElse(),
  }) {
    if (sessionUpdate != null) {
      return sessionUpdate(this);
    }
    return orElse();
  }
}

abstract class _SessionUpdate implements GrokOutboundEvent {
  const factory _SessionUpdate({required final SessionUpdatePayload session}) =
      _$SessionUpdateImpl;

  SessionUpdatePayload get session;

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionUpdateImplCopyWith<_$SessionUpdateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AudioAppendImplCopyWith<$Res> {
  factory _$$AudioAppendImplCopyWith(
          _$AudioAppendImpl value, $Res Function(_$AudioAppendImpl) then) =
      __$$AudioAppendImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String audio});
}

/// @nodoc
class __$$AudioAppendImplCopyWithImpl<$Res>
    extends _$GrokOutboundEventCopyWithImpl<$Res, _$AudioAppendImpl>
    implements _$$AudioAppendImplCopyWith<$Res> {
  __$$AudioAppendImplCopyWithImpl(
      _$AudioAppendImpl _value, $Res Function(_$AudioAppendImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? audio = null,
  }) {
    return _then(_$AudioAppendImpl(
      audio: null == audio
          ? _value.audio
          : audio // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$AudioAppendImpl implements _AudioAppend {
  const _$AudioAppendImpl({required this.audio});

  @override
  final String audio;

  @override
  String toString() {
    return 'GrokOutboundEvent.audioAppend(audio: $audio)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioAppendImpl &&
            (identical(other.audio, audio) || other.audio == audio));
  }

  @override
  int get hashCode => Object.hash(runtimeType, audio);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioAppendImplCopyWith<_$AudioAppendImpl> get copyWith =>
      __$$AudioAppendImplCopyWithImpl<_$AudioAppendImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SessionUpdatePayload session) sessionUpdate,
    required TResult Function(String audio) audioAppend,
    required TResult Function() audioCommit,
    required TResult Function() responseCreate,
    required TResult Function() responseCancel,
  }) {
    return audioAppend(audio);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SessionUpdatePayload session)? sessionUpdate,
    TResult? Function(String audio)? audioAppend,
    TResult? Function()? audioCommit,
    TResult? Function()? responseCreate,
    TResult? Function()? responseCancel,
  }) {
    return audioAppend?.call(audio);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SessionUpdatePayload session)? sessionUpdate,
    TResult Function(String audio)? audioAppend,
    TResult Function()? audioCommit,
    TResult Function()? responseCreate,
    TResult Function()? responseCancel,
    required TResult orElse(),
  }) {
    if (audioAppend != null) {
      return audioAppend(audio);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SessionUpdate value) sessionUpdate,
    required TResult Function(_AudioAppend value) audioAppend,
    required TResult Function(_AudioCommit value) audioCommit,
    required TResult Function(_ResponseCreate value) responseCreate,
    required TResult Function(_ResponseCancel value) responseCancel,
  }) {
    return audioAppend(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SessionUpdate value)? sessionUpdate,
    TResult? Function(_AudioAppend value)? audioAppend,
    TResult? Function(_AudioCommit value)? audioCommit,
    TResult? Function(_ResponseCreate value)? responseCreate,
    TResult? Function(_ResponseCancel value)? responseCancel,
  }) {
    return audioAppend?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SessionUpdate value)? sessionUpdate,
    TResult Function(_AudioAppend value)? audioAppend,
    TResult Function(_AudioCommit value)? audioCommit,
    TResult Function(_ResponseCreate value)? responseCreate,
    TResult Function(_ResponseCancel value)? responseCancel,
    required TResult orElse(),
  }) {
    if (audioAppend != null) {
      return audioAppend(this);
    }
    return orElse();
  }
}

abstract class _AudioAppend implements GrokOutboundEvent {
  const factory _AudioAppend({required final String audio}) = _$AudioAppendImpl;

  String get audio;

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioAppendImplCopyWith<_$AudioAppendImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AudioCommitImplCopyWith<$Res> {
  factory _$$AudioCommitImplCopyWith(
          _$AudioCommitImpl value, $Res Function(_$AudioCommitImpl) then) =
      __$$AudioCommitImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$AudioCommitImplCopyWithImpl<$Res>
    extends _$GrokOutboundEventCopyWithImpl<$Res, _$AudioCommitImpl>
    implements _$$AudioCommitImplCopyWith<$Res> {
  __$$AudioCommitImplCopyWithImpl(
      _$AudioCommitImpl _value, $Res Function(_$AudioCommitImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$AudioCommitImpl implements _AudioCommit {
  const _$AudioCommitImpl();

  @override
  String toString() {
    return 'GrokOutboundEvent.audioCommit()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$AudioCommitImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SessionUpdatePayload session) sessionUpdate,
    required TResult Function(String audio) audioAppend,
    required TResult Function() audioCommit,
    required TResult Function() responseCreate,
    required TResult Function() responseCancel,
  }) {
    return audioCommit();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SessionUpdatePayload session)? sessionUpdate,
    TResult? Function(String audio)? audioAppend,
    TResult? Function()? audioCommit,
    TResult? Function()? responseCreate,
    TResult? Function()? responseCancel,
  }) {
    return audioCommit?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SessionUpdatePayload session)? sessionUpdate,
    TResult Function(String audio)? audioAppend,
    TResult Function()? audioCommit,
    TResult Function()? responseCreate,
    TResult Function()? responseCancel,
    required TResult orElse(),
  }) {
    if (audioCommit != null) {
      return audioCommit();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SessionUpdate value) sessionUpdate,
    required TResult Function(_AudioAppend value) audioAppend,
    required TResult Function(_AudioCommit value) audioCommit,
    required TResult Function(_ResponseCreate value) responseCreate,
    required TResult Function(_ResponseCancel value) responseCancel,
  }) {
    return audioCommit(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SessionUpdate value)? sessionUpdate,
    TResult? Function(_AudioAppend value)? audioAppend,
    TResult? Function(_AudioCommit value)? audioCommit,
    TResult? Function(_ResponseCreate value)? responseCreate,
    TResult? Function(_ResponseCancel value)? responseCancel,
  }) {
    return audioCommit?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SessionUpdate value)? sessionUpdate,
    TResult Function(_AudioAppend value)? audioAppend,
    TResult Function(_AudioCommit value)? audioCommit,
    TResult Function(_ResponseCreate value)? responseCreate,
    TResult Function(_ResponseCancel value)? responseCancel,
    required TResult orElse(),
  }) {
    if (audioCommit != null) {
      return audioCommit(this);
    }
    return orElse();
  }
}

abstract class _AudioCommit implements GrokOutboundEvent {
  const factory _AudioCommit() = _$AudioCommitImpl;
}

/// @nodoc
abstract class _$$ResponseCreateImplCopyWith<$Res> {
  factory _$$ResponseCreateImplCopyWith(_$ResponseCreateImpl value,
          $Res Function(_$ResponseCreateImpl) then) =
      __$$ResponseCreateImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ResponseCreateImplCopyWithImpl<$Res>
    extends _$GrokOutboundEventCopyWithImpl<$Res, _$ResponseCreateImpl>
    implements _$$ResponseCreateImplCopyWith<$Res> {
  __$$ResponseCreateImplCopyWithImpl(
      _$ResponseCreateImpl _value, $Res Function(_$ResponseCreateImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ResponseCreateImpl implements _ResponseCreate {
  const _$ResponseCreateImpl();

  @override
  String toString() {
    return 'GrokOutboundEvent.responseCreate()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ResponseCreateImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SessionUpdatePayload session) sessionUpdate,
    required TResult Function(String audio) audioAppend,
    required TResult Function() audioCommit,
    required TResult Function() responseCreate,
    required TResult Function() responseCancel,
  }) {
    return responseCreate();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SessionUpdatePayload session)? sessionUpdate,
    TResult? Function(String audio)? audioAppend,
    TResult? Function()? audioCommit,
    TResult? Function()? responseCreate,
    TResult? Function()? responseCancel,
  }) {
    return responseCreate?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SessionUpdatePayload session)? sessionUpdate,
    TResult Function(String audio)? audioAppend,
    TResult Function()? audioCommit,
    TResult Function()? responseCreate,
    TResult Function()? responseCancel,
    required TResult orElse(),
  }) {
    if (responseCreate != null) {
      return responseCreate();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SessionUpdate value) sessionUpdate,
    required TResult Function(_AudioAppend value) audioAppend,
    required TResult Function(_AudioCommit value) audioCommit,
    required TResult Function(_ResponseCreate value) responseCreate,
    required TResult Function(_ResponseCancel value) responseCancel,
  }) {
    return responseCreate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SessionUpdate value)? sessionUpdate,
    TResult? Function(_AudioAppend value)? audioAppend,
    TResult? Function(_AudioCommit value)? audioCommit,
    TResult? Function(_ResponseCreate value)? responseCreate,
    TResult? Function(_ResponseCancel value)? responseCancel,
  }) {
    return responseCreate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SessionUpdate value)? sessionUpdate,
    TResult Function(_AudioAppend value)? audioAppend,
    TResult Function(_AudioCommit value)? audioCommit,
    TResult Function(_ResponseCreate value)? responseCreate,
    TResult Function(_ResponseCancel value)? responseCancel,
    required TResult orElse(),
  }) {
    if (responseCreate != null) {
      return responseCreate(this);
    }
    return orElse();
  }
}

abstract class _ResponseCreate implements GrokOutboundEvent {
  const factory _ResponseCreate() = _$ResponseCreateImpl;
}

/// @nodoc
abstract class _$$ResponseCancelImplCopyWith<$Res> {
  factory _$$ResponseCancelImplCopyWith(_$ResponseCancelImpl value,
          $Res Function(_$ResponseCancelImpl) then) =
      __$$ResponseCancelImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ResponseCancelImplCopyWithImpl<$Res>
    extends _$GrokOutboundEventCopyWithImpl<$Res, _$ResponseCancelImpl>
    implements _$$ResponseCancelImplCopyWith<$Res> {
  __$$ResponseCancelImplCopyWithImpl(
      _$ResponseCancelImpl _value, $Res Function(_$ResponseCancelImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrokOutboundEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ResponseCancelImpl implements _ResponseCancel {
  const _$ResponseCancelImpl();

  @override
  String toString() {
    return 'GrokOutboundEvent.responseCancel()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ResponseCancelImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SessionUpdatePayload session) sessionUpdate,
    required TResult Function(String audio) audioAppend,
    required TResult Function() audioCommit,
    required TResult Function() responseCreate,
    required TResult Function() responseCancel,
  }) {
    return responseCancel();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SessionUpdatePayload session)? sessionUpdate,
    TResult? Function(String audio)? audioAppend,
    TResult? Function()? audioCommit,
    TResult? Function()? responseCreate,
    TResult? Function()? responseCancel,
  }) {
    return responseCancel?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SessionUpdatePayload session)? sessionUpdate,
    TResult Function(String audio)? audioAppend,
    TResult Function()? audioCommit,
    TResult Function()? responseCreate,
    TResult Function()? responseCancel,
    required TResult orElse(),
  }) {
    if (responseCancel != null) {
      return responseCancel();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_SessionUpdate value) sessionUpdate,
    required TResult Function(_AudioAppend value) audioAppend,
    required TResult Function(_AudioCommit value) audioCommit,
    required TResult Function(_ResponseCreate value) responseCreate,
    required TResult Function(_ResponseCancel value) responseCancel,
  }) {
    return responseCancel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_SessionUpdate value)? sessionUpdate,
    TResult? Function(_AudioAppend value)? audioAppend,
    TResult? Function(_AudioCommit value)? audioCommit,
    TResult? Function(_ResponseCreate value)? responseCreate,
    TResult? Function(_ResponseCancel value)? responseCancel,
  }) {
    return responseCancel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_SessionUpdate value)? sessionUpdate,
    TResult Function(_AudioAppend value)? audioAppend,
    TResult Function(_AudioCommit value)? audioCommit,
    TResult Function(_ResponseCreate value)? responseCreate,
    TResult Function(_ResponseCancel value)? responseCancel,
    required TResult orElse(),
  }) {
    if (responseCancel != null) {
      return responseCancel(this);
    }
    return orElse();
  }
}

abstract class _ResponseCancel implements GrokOutboundEvent {
  const factory _ResponseCancel() = _$ResponseCancelImpl;
}

SessionUpdatePayload _$SessionUpdatePayloadFromJson(Map<String, dynamic> json) {
  return _SessionUpdatePayload.fromJson(json);
}

/// @nodoc
mixin _$SessionUpdatePayload {
  String get model => throw _privateConstructorUsedError;
  String get instructions => throw _privateConstructorUsedError;
  String get modalities =>
      throw _privateConstructorUsedError; // 'text', 'audio', or 'both'
  String get voice => throw _privateConstructorUsedError;
  String get inputAudioFormat => throw _privateConstructorUsedError;
  String get outputAudioFormat => throw _privateConstructorUsedError;
  TurnDetectionConfig? get turnDetection => throw _privateConstructorUsedError;

  /// Serializes this SessionUpdatePayload to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionUpdatePayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionUpdatePayloadCopyWith<SessionUpdatePayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionUpdatePayloadCopyWith<$Res> {
  factory $SessionUpdatePayloadCopyWith(SessionUpdatePayload value,
          $Res Function(SessionUpdatePayload) then) =
      _$SessionUpdatePayloadCopyWithImpl<$Res, SessionUpdatePayload>;
  @useResult
  $Res call(
      {String model,
      String instructions,
      String modalities,
      String voice,
      String inputAudioFormat,
      String outputAudioFormat,
      TurnDetectionConfig? turnDetection});

  $TurnDetectionConfigCopyWith<$Res>? get turnDetection;
}

/// @nodoc
class _$SessionUpdatePayloadCopyWithImpl<$Res,
        $Val extends SessionUpdatePayload>
    implements $SessionUpdatePayloadCopyWith<$Res> {
  _$SessionUpdatePayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionUpdatePayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
    Object? instructions = null,
    Object? modalities = null,
    Object? voice = null,
    Object? inputAudioFormat = null,
    Object? outputAudioFormat = null,
    Object? turnDetection = freezed,
  }) {
    return _then(_value.copyWith(
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      instructions: null == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String,
      modalities: null == modalities
          ? _value.modalities
          : modalities // ignore: cast_nullable_to_non_nullable
              as String,
      voice: null == voice
          ? _value.voice
          : voice // ignore: cast_nullable_to_non_nullable
              as String,
      inputAudioFormat: null == inputAudioFormat
          ? _value.inputAudioFormat
          : inputAudioFormat // ignore: cast_nullable_to_non_nullable
              as String,
      outputAudioFormat: null == outputAudioFormat
          ? _value.outputAudioFormat
          : outputAudioFormat // ignore: cast_nullable_to_non_nullable
              as String,
      turnDetection: freezed == turnDetection
          ? _value.turnDetection
          : turnDetection // ignore: cast_nullable_to_non_nullable
              as TurnDetectionConfig?,
    ) as $Val);
  }

  /// Create a copy of SessionUpdatePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TurnDetectionConfigCopyWith<$Res>? get turnDetection {
    if (_value.turnDetection == null) {
      return null;
    }

    return $TurnDetectionConfigCopyWith<$Res>(_value.turnDetection!, (value) {
      return _then(_value.copyWith(turnDetection: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SessionUpdatePayloadImplCopyWith<$Res>
    implements $SessionUpdatePayloadCopyWith<$Res> {
  factory _$$SessionUpdatePayloadImplCopyWith(_$SessionUpdatePayloadImpl value,
          $Res Function(_$SessionUpdatePayloadImpl) then) =
      __$$SessionUpdatePayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String model,
      String instructions,
      String modalities,
      String voice,
      String inputAudioFormat,
      String outputAudioFormat,
      TurnDetectionConfig? turnDetection});

  @override
  $TurnDetectionConfigCopyWith<$Res>? get turnDetection;
}

/// @nodoc
class __$$SessionUpdatePayloadImplCopyWithImpl<$Res>
    extends _$SessionUpdatePayloadCopyWithImpl<$Res, _$SessionUpdatePayloadImpl>
    implements _$$SessionUpdatePayloadImplCopyWith<$Res> {
  __$$SessionUpdatePayloadImplCopyWithImpl(_$SessionUpdatePayloadImpl _value,
      $Res Function(_$SessionUpdatePayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionUpdatePayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
    Object? instructions = null,
    Object? modalities = null,
    Object? voice = null,
    Object? inputAudioFormat = null,
    Object? outputAudioFormat = null,
    Object? turnDetection = freezed,
  }) {
    return _then(_$SessionUpdatePayloadImpl(
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      instructions: null == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String,
      modalities: null == modalities
          ? _value.modalities
          : modalities // ignore: cast_nullable_to_non_nullable
              as String,
      voice: null == voice
          ? _value.voice
          : voice // ignore: cast_nullable_to_non_nullable
              as String,
      inputAudioFormat: null == inputAudioFormat
          ? _value.inputAudioFormat
          : inputAudioFormat // ignore: cast_nullable_to_non_nullable
              as String,
      outputAudioFormat: null == outputAudioFormat
          ? _value.outputAudioFormat
          : outputAudioFormat // ignore: cast_nullable_to_non_nullable
              as String,
      turnDetection: freezed == turnDetection
          ? _value.turnDetection
          : turnDetection // ignore: cast_nullable_to_non_nullable
              as TurnDetectionConfig?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionUpdatePayloadImpl implements _SessionUpdatePayload {
  const _$SessionUpdatePayloadImpl(
      {required this.model,
      required this.instructions,
      this.modalities = 'both',
      this.voice = 'alloy',
      this.inputAudioFormat = 'pcm16',
      this.outputAudioFormat = 'pcm16',
      this.turnDetection});

  factory _$SessionUpdatePayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionUpdatePayloadImplFromJson(json);

  @override
  final String model;
  @override
  final String instructions;
  @override
  @JsonKey()
  final String modalities;
// 'text', 'audio', or 'both'
  @override
  @JsonKey()
  final String voice;
  @override
  @JsonKey()
  final String inputAudioFormat;
  @override
  @JsonKey()
  final String outputAudioFormat;
  @override
  final TurnDetectionConfig? turnDetection;

  @override
  String toString() {
    return 'SessionUpdatePayload(model: $model, instructions: $instructions, modalities: $modalities, voice: $voice, inputAudioFormat: $inputAudioFormat, outputAudioFormat: $outputAudioFormat, turnDetection: $turnDetection)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionUpdatePayloadImpl &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.modalities, modalities) ||
                other.modalities == modalities) &&
            (identical(other.voice, voice) || other.voice == voice) &&
            (identical(other.inputAudioFormat, inputAudioFormat) ||
                other.inputAudioFormat == inputAudioFormat) &&
            (identical(other.outputAudioFormat, outputAudioFormat) ||
                other.outputAudioFormat == outputAudioFormat) &&
            (identical(other.turnDetection, turnDetection) ||
                other.turnDetection == turnDetection));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, model, instructions, modalities,
      voice, inputAudioFormat, outputAudioFormat, turnDetection);

  /// Create a copy of SessionUpdatePayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionUpdatePayloadImplCopyWith<_$SessionUpdatePayloadImpl>
      get copyWith =>
          __$$SessionUpdatePayloadImplCopyWithImpl<_$SessionUpdatePayloadImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionUpdatePayloadImplToJson(
      this,
    );
  }
}

abstract class _SessionUpdatePayload implements SessionUpdatePayload {
  const factory _SessionUpdatePayload(
      {required final String model,
      required final String instructions,
      final String modalities,
      final String voice,
      final String inputAudioFormat,
      final String outputAudioFormat,
      final TurnDetectionConfig? turnDetection}) = _$SessionUpdatePayloadImpl;

  factory _SessionUpdatePayload.fromJson(Map<String, dynamic> json) =
      _$SessionUpdatePayloadImpl.fromJson;

  @override
  String get model;
  @override
  String get instructions;
  @override
  String get modalities; // 'text', 'audio', or 'both'
  @override
  String get voice;
  @override
  String get inputAudioFormat;
  @override
  String get outputAudioFormat;
  @override
  TurnDetectionConfig? get turnDetection;

  /// Create a copy of SessionUpdatePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionUpdatePayloadImplCopyWith<_$SessionUpdatePayloadImpl>
      get copyWith => throw _privateConstructorUsedError;
}

TurnDetectionConfig _$TurnDetectionConfigFromJson(Map<String, dynamic> json) {
  return _TurnDetectionConfig.fromJson(json);
}

/// @nodoc
mixin _$TurnDetectionConfig {
  String get type => throw _privateConstructorUsedError;
  double get threshold => throw _privateConstructorUsedError;
  int get prefixPaddingMs => throw _privateConstructorUsedError;
  int get silenceDurationMs => throw _privateConstructorUsedError;
  bool get createResponse => throw _privateConstructorUsedError;

  /// Serializes this TurnDetectionConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TurnDetectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TurnDetectionConfigCopyWith<TurnDetectionConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TurnDetectionConfigCopyWith<$Res> {
  factory $TurnDetectionConfigCopyWith(
          TurnDetectionConfig value, $Res Function(TurnDetectionConfig) then) =
      _$TurnDetectionConfigCopyWithImpl<$Res, TurnDetectionConfig>;
  @useResult
  $Res call(
      {String type,
      double threshold,
      int prefixPaddingMs,
      int silenceDurationMs,
      bool createResponse});
}

/// @nodoc
class _$TurnDetectionConfigCopyWithImpl<$Res, $Val extends TurnDetectionConfig>
    implements $TurnDetectionConfigCopyWith<$Res> {
  _$TurnDetectionConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TurnDetectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? threshold = null,
    Object? prefixPaddingMs = null,
    Object? silenceDurationMs = null,
    Object? createResponse = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      threshold: null == threshold
          ? _value.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
      prefixPaddingMs: null == prefixPaddingMs
          ? _value.prefixPaddingMs
          : prefixPaddingMs // ignore: cast_nullable_to_non_nullable
              as int,
      silenceDurationMs: null == silenceDurationMs
          ? _value.silenceDurationMs
          : silenceDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
      createResponse: null == createResponse
          ? _value.createResponse
          : createResponse // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TurnDetectionConfigImplCopyWith<$Res>
    implements $TurnDetectionConfigCopyWith<$Res> {
  factory _$$TurnDetectionConfigImplCopyWith(_$TurnDetectionConfigImpl value,
          $Res Function(_$TurnDetectionConfigImpl) then) =
      __$$TurnDetectionConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      double threshold,
      int prefixPaddingMs,
      int silenceDurationMs,
      bool createResponse});
}

/// @nodoc
class __$$TurnDetectionConfigImplCopyWithImpl<$Res>
    extends _$TurnDetectionConfigCopyWithImpl<$Res, _$TurnDetectionConfigImpl>
    implements _$$TurnDetectionConfigImplCopyWith<$Res> {
  __$$TurnDetectionConfigImplCopyWithImpl(_$TurnDetectionConfigImpl _value,
      $Res Function(_$TurnDetectionConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of TurnDetectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? threshold = null,
    Object? prefixPaddingMs = null,
    Object? silenceDurationMs = null,
    Object? createResponse = null,
  }) {
    return _then(_$TurnDetectionConfigImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      threshold: null == threshold
          ? _value.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
      prefixPaddingMs: null == prefixPaddingMs
          ? _value.prefixPaddingMs
          : prefixPaddingMs // ignore: cast_nullable_to_non_nullable
              as int,
      silenceDurationMs: null == silenceDurationMs
          ? _value.silenceDurationMs
          : silenceDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
      createResponse: null == createResponse
          ? _value.createResponse
          : createResponse // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TurnDetectionConfigImpl implements _TurnDetectionConfig {
  const _$TurnDetectionConfigImpl(
      {this.type = 'server_vad',
      this.threshold = 0.6,
      this.prefixPaddingMs = 300,
      this.silenceDurationMs = 400,
      this.createResponse = true});

  factory _$TurnDetectionConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$TurnDetectionConfigImplFromJson(json);

  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey()
  final double threshold;
  @override
  @JsonKey()
  final int prefixPaddingMs;
  @override
  @JsonKey()
  final int silenceDurationMs;
  @override
  @JsonKey()
  final bool createResponse;

  @override
  String toString() {
    return 'TurnDetectionConfig(type: $type, threshold: $threshold, prefixPaddingMs: $prefixPaddingMs, silenceDurationMs: $silenceDurationMs, createResponse: $createResponse)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TurnDetectionConfigImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.prefixPaddingMs, prefixPaddingMs) ||
                other.prefixPaddingMs == prefixPaddingMs) &&
            (identical(other.silenceDurationMs, silenceDurationMs) ||
                other.silenceDurationMs == silenceDurationMs) &&
            (identical(other.createResponse, createResponse) ||
                other.createResponse == createResponse));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, threshold, prefixPaddingMs,
      silenceDurationMs, createResponse);

  /// Create a copy of TurnDetectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TurnDetectionConfigImplCopyWith<_$TurnDetectionConfigImpl> get copyWith =>
      __$$TurnDetectionConfigImplCopyWithImpl<_$TurnDetectionConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TurnDetectionConfigImplToJson(
      this,
    );
  }
}

abstract class _TurnDetectionConfig implements TurnDetectionConfig {
  const factory _TurnDetectionConfig(
      {final String type,
      final double threshold,
      final int prefixPaddingMs,
      final int silenceDurationMs,
      final bool createResponse}) = _$TurnDetectionConfigImpl;

  factory _TurnDetectionConfig.fromJson(Map<String, dynamic> json) =
      _$TurnDetectionConfigImpl.fromJson;

  @override
  String get type;
  @override
  double get threshold;
  @override
  int get prefixPaddingMs;
  @override
  int get silenceDurationMs;
  @override
  bool get createResponse;

  /// Create a copy of TurnDetectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TurnDetectionConfigImplCopyWith<_$TurnDetectionConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$GrokServerEvent {
  GrokServerEventType get type => throw _privateConstructorUsedError;
  String? get eventId => throw _privateConstructorUsedError;
  String? get audioDelta => throw _privateConstructorUsedError; // base64 PCM16
  String? get transcriptDelta => throw _privateConstructorUsedError;
  String? get transcriptText => throw _privateConstructorUsedError;
  String? get detectedLanguage =>
      throw _privateConstructorUsedError; // ISO language code from transcription event
  String? get errorMessage => throw _privateConstructorUsedError;
  Map<String, dynamic>? get raw => throw _privateConstructorUsedError;

  /// Create a copy of GrokServerEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GrokServerEventCopyWith<GrokServerEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GrokServerEventCopyWith<$Res> {
  factory $GrokServerEventCopyWith(
          GrokServerEvent value, $Res Function(GrokServerEvent) then) =
      _$GrokServerEventCopyWithImpl<$Res, GrokServerEvent>;
  @useResult
  $Res call(
      {GrokServerEventType type,
      String? eventId,
      String? audioDelta,
      String? transcriptDelta,
      String? transcriptText,
      String? detectedLanguage,
      String? errorMessage,
      Map<String, dynamic>? raw});
}

/// @nodoc
class _$GrokServerEventCopyWithImpl<$Res, $Val extends GrokServerEvent>
    implements $GrokServerEventCopyWith<$Res> {
  _$GrokServerEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GrokServerEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? eventId = freezed,
    Object? audioDelta = freezed,
    Object? transcriptDelta = freezed,
    Object? transcriptText = freezed,
    Object? detectedLanguage = freezed,
    Object? errorMessage = freezed,
    Object? raw = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as GrokServerEventType,
      eventId: freezed == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String?,
      audioDelta: freezed == audioDelta
          ? _value.audioDelta
          : audioDelta // ignore: cast_nullable_to_non_nullable
              as String?,
      transcriptDelta: freezed == transcriptDelta
          ? _value.transcriptDelta
          : transcriptDelta // ignore: cast_nullable_to_non_nullable
              as String?,
      transcriptText: freezed == transcriptText
          ? _value.transcriptText
          : transcriptText // ignore: cast_nullable_to_non_nullable
              as String?,
      detectedLanguage: freezed == detectedLanguage
          ? _value.detectedLanguage
          : detectedLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      raw: freezed == raw
          ? _value.raw
          : raw // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GrokServerEventImplCopyWith<$Res>
    implements $GrokServerEventCopyWith<$Res> {
  factory _$$GrokServerEventImplCopyWith(_$GrokServerEventImpl value,
          $Res Function(_$GrokServerEventImpl) then) =
      __$$GrokServerEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {GrokServerEventType type,
      String? eventId,
      String? audioDelta,
      String? transcriptDelta,
      String? transcriptText,
      String? detectedLanguage,
      String? errorMessage,
      Map<String, dynamic>? raw});
}

/// @nodoc
class __$$GrokServerEventImplCopyWithImpl<$Res>
    extends _$GrokServerEventCopyWithImpl<$Res, _$GrokServerEventImpl>
    implements _$$GrokServerEventImplCopyWith<$Res> {
  __$$GrokServerEventImplCopyWithImpl(
      _$GrokServerEventImpl _value, $Res Function(_$GrokServerEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of GrokServerEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? eventId = freezed,
    Object? audioDelta = freezed,
    Object? transcriptDelta = freezed,
    Object? transcriptText = freezed,
    Object? detectedLanguage = freezed,
    Object? errorMessage = freezed,
    Object? raw = freezed,
  }) {
    return _then(_$GrokServerEventImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as GrokServerEventType,
      eventId: freezed == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String?,
      audioDelta: freezed == audioDelta
          ? _value.audioDelta
          : audioDelta // ignore: cast_nullable_to_non_nullable
              as String?,
      transcriptDelta: freezed == transcriptDelta
          ? _value.transcriptDelta
          : transcriptDelta // ignore: cast_nullable_to_non_nullable
              as String?,
      transcriptText: freezed == transcriptText
          ? _value.transcriptText
          : transcriptText // ignore: cast_nullable_to_non_nullable
              as String?,
      detectedLanguage: freezed == detectedLanguage
          ? _value.detectedLanguage
          : detectedLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      raw: freezed == raw
          ? _value._raw
          : raw // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc

class _$GrokServerEventImpl implements _GrokServerEvent {
  const _$GrokServerEventImpl(
      {required this.type,
      this.eventId,
      this.audioDelta,
      this.transcriptDelta,
      this.transcriptText,
      this.detectedLanguage,
      this.errorMessage,
      final Map<String, dynamic>? raw})
      : _raw = raw;

  @override
  final GrokServerEventType type;
  @override
  final String? eventId;
  @override
  final String? audioDelta;
// base64 PCM16
  @override
  final String? transcriptDelta;
  @override
  final String? transcriptText;
  @override
  final String? detectedLanguage;
// ISO language code from transcription event
  @override
  final String? errorMessage;
  final Map<String, dynamic>? _raw;
  @override
  Map<String, dynamic>? get raw {
    final value = _raw;
    if (value == null) return null;
    if (_raw is EqualUnmodifiableMapView) return _raw;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'GrokServerEvent(type: $type, eventId: $eventId, audioDelta: $audioDelta, transcriptDelta: $transcriptDelta, transcriptText: $transcriptText, detectedLanguage: $detectedLanguage, errorMessage: $errorMessage, raw: $raw)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GrokServerEventImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.audioDelta, audioDelta) ||
                other.audioDelta == audioDelta) &&
            (identical(other.transcriptDelta, transcriptDelta) ||
                other.transcriptDelta == transcriptDelta) &&
            (identical(other.transcriptText, transcriptText) ||
                other.transcriptText == transcriptText) &&
            (identical(other.detectedLanguage, detectedLanguage) ||
                other.detectedLanguage == detectedLanguage) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            const DeepCollectionEquality().equals(other._raw, _raw));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      type,
      eventId,
      audioDelta,
      transcriptDelta,
      transcriptText,
      detectedLanguage,
      errorMessage,
      const DeepCollectionEquality().hash(_raw));

  /// Create a copy of GrokServerEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GrokServerEventImplCopyWith<_$GrokServerEventImpl> get copyWith =>
      __$$GrokServerEventImplCopyWithImpl<_$GrokServerEventImpl>(
          this, _$identity);
}

abstract class _GrokServerEvent implements GrokServerEvent {
  const factory _GrokServerEvent(
      {required final GrokServerEventType type,
      final String? eventId,
      final String? audioDelta,
      final String? transcriptDelta,
      final String? transcriptText,
      final String? detectedLanguage,
      final String? errorMessage,
      final Map<String, dynamic>? raw}) = _$GrokServerEventImpl;

  @override
  GrokServerEventType get type;
  @override
  String? get eventId;
  @override
  String? get audioDelta; // base64 PCM16
  @override
  String? get transcriptDelta;
  @override
  String? get transcriptText;
  @override
  String? get detectedLanguage; // ISO language code from transcription event
  @override
  String? get errorMessage;
  @override
  Map<String, dynamic>? get raw;

  /// Create a copy of GrokServerEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GrokServerEventImplCopyWith<_$GrokServerEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
