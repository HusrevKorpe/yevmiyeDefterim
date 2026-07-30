// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettings {

 int get defaultWageMaleKurus; int get defaultWageFemaleKurus; int get defaultCrewRateKurus;/// HERKES için geçerli mesai (fazla çalışma) SAAT ücreti (kuruş).
///
/// Sahada mesai ücreti işçiden işçiye değişmez → tek yerden (Yönetim
/// ekranı) girilir; yoklamada girilen mesai saatiyle çarpılır. Bir işçinin
/// mesaisi farklıysa `Worker.overtimeHourlyKurus` bunu EZER (bkz.
/// `resolveOvertimeRateKurus`). 0 => girilmemiş (yoklama satırı uyarır).
///
/// Not: yevmiye varsayılanları (yukarıdaki üç alan) rafta — yevmiye tek tek
/// işçiden okunur. Mesai bilerek tersi yönde: ortak değer, tek giriş.
 int get overtimeHourlyKurus;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.defaultWageMaleKurus, defaultWageMaleKurus) || other.defaultWageMaleKurus == defaultWageMaleKurus)&&(identical(other.defaultWageFemaleKurus, defaultWageFemaleKurus) || other.defaultWageFemaleKurus == defaultWageFemaleKurus)&&(identical(other.defaultCrewRateKurus, defaultCrewRateKurus) || other.defaultCrewRateKurus == defaultCrewRateKurus)&&(identical(other.overtimeHourlyKurus, overtimeHourlyKurus) || other.overtimeHourlyKurus == overtimeHourlyKurus));
}


@override
int get hashCode => Object.hash(runtimeType,defaultWageMaleKurus,defaultWageFemaleKurus,defaultCrewRateKurus,overtimeHourlyKurus);

@override
String toString() {
  return 'AppSettings(defaultWageMaleKurus: $defaultWageMaleKurus, defaultWageFemaleKurus: $defaultWageFemaleKurus, defaultCrewRateKurus: $defaultCrewRateKurus, overtimeHourlyKurus: $overtimeHourlyKurus)';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 int defaultWageMaleKurus, int defaultWageFemaleKurus, int defaultCrewRateKurus, int overtimeHourlyKurus
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? defaultWageMaleKurus = null,Object? defaultWageFemaleKurus = null,Object? defaultCrewRateKurus = null,Object? overtimeHourlyKurus = null,}) {
  return _then(_self.copyWith(
defaultWageMaleKurus: null == defaultWageMaleKurus ? _self.defaultWageMaleKurus : defaultWageMaleKurus // ignore: cast_nullable_to_non_nullable
as int,defaultWageFemaleKurus: null == defaultWageFemaleKurus ? _self.defaultWageFemaleKurus : defaultWageFemaleKurus // ignore: cast_nullable_to_non_nullable
as int,defaultCrewRateKurus: null == defaultCrewRateKurus ? _self.defaultCrewRateKurus : defaultCrewRateKurus // ignore: cast_nullable_to_non_nullable
as int,overtimeHourlyKurus: null == overtimeHourlyKurus ? _self.overtimeHourlyKurus : overtimeHourlyKurus // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int defaultWageMaleKurus,  int defaultWageFemaleKurus,  int defaultCrewRateKurus,  int overtimeHourlyKurus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.defaultWageMaleKurus,_that.defaultWageFemaleKurus,_that.defaultCrewRateKurus,_that.overtimeHourlyKurus);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int defaultWageMaleKurus,  int defaultWageFemaleKurus,  int defaultCrewRateKurus,  int overtimeHourlyKurus)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.defaultWageMaleKurus,_that.defaultWageFemaleKurus,_that.defaultCrewRateKurus,_that.overtimeHourlyKurus);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int defaultWageMaleKurus,  int defaultWageFemaleKurus,  int defaultCrewRateKurus,  int overtimeHourlyKurus)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.defaultWageMaleKurus,_that.defaultWageFemaleKurus,_that.defaultCrewRateKurus,_that.overtimeHourlyKurus);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettings extends AppSettings {
  const _AppSettings({required this.defaultWageMaleKurus, required this.defaultWageFemaleKurus, required this.defaultCrewRateKurus, this.overtimeHourlyKurus = 0}): super._();
  

@override final  int defaultWageMaleKurus;
@override final  int defaultWageFemaleKurus;
@override final  int defaultCrewRateKurus;
/// HERKES için geçerli mesai (fazla çalışma) SAAT ücreti (kuruş).
///
/// Sahada mesai ücreti işçiden işçiye değişmez → tek yerden (Yönetim
/// ekranı) girilir; yoklamada girilen mesai saatiyle çarpılır. Bir işçinin
/// mesaisi farklıysa `Worker.overtimeHourlyKurus` bunu EZER (bkz.
/// `resolveOvertimeRateKurus`). 0 => girilmemiş (yoklama satırı uyarır).
///
/// Not: yevmiye varsayılanları (yukarıdaki üç alan) rafta — yevmiye tek tek
/// işçiden okunur. Mesai bilerek tersi yönde: ortak değer, tek giriş.
@override@JsonKey() final  int overtimeHourlyKurus;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.defaultWageMaleKurus, defaultWageMaleKurus) || other.defaultWageMaleKurus == defaultWageMaleKurus)&&(identical(other.defaultWageFemaleKurus, defaultWageFemaleKurus) || other.defaultWageFemaleKurus == defaultWageFemaleKurus)&&(identical(other.defaultCrewRateKurus, defaultCrewRateKurus) || other.defaultCrewRateKurus == defaultCrewRateKurus)&&(identical(other.overtimeHourlyKurus, overtimeHourlyKurus) || other.overtimeHourlyKurus == overtimeHourlyKurus));
}


@override
int get hashCode => Object.hash(runtimeType,defaultWageMaleKurus,defaultWageFemaleKurus,defaultCrewRateKurus,overtimeHourlyKurus);

@override
String toString() {
  return 'AppSettings(defaultWageMaleKurus: $defaultWageMaleKurus, defaultWageFemaleKurus: $defaultWageFemaleKurus, defaultCrewRateKurus: $defaultCrewRateKurus, overtimeHourlyKurus: $overtimeHourlyKurus)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 int defaultWageMaleKurus, int defaultWageFemaleKurus, int defaultCrewRateKurus, int overtimeHourlyKurus
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? defaultWageMaleKurus = null,Object? defaultWageFemaleKurus = null,Object? defaultCrewRateKurus = null,Object? overtimeHourlyKurus = null,}) {
  return _then(_AppSettings(
defaultWageMaleKurus: null == defaultWageMaleKurus ? _self.defaultWageMaleKurus : defaultWageMaleKurus // ignore: cast_nullable_to_non_nullable
as int,defaultWageFemaleKurus: null == defaultWageFemaleKurus ? _self.defaultWageFemaleKurus : defaultWageFemaleKurus // ignore: cast_nullable_to_non_nullable
as int,defaultCrewRateKurus: null == defaultCrewRateKurus ? _self.defaultCrewRateKurus : defaultCrewRateKurus // ignore: cast_nullable_to_non_nullable
as int,overtimeHourlyKurus: null == overtimeHourlyKurus ? _self.overtimeHourlyKurus : overtimeHourlyKurus // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
