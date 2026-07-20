// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'worker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Worker {

 String get id; String get name; WorkerType get type; Gender get gender;/// İşçiye özel günlük ücret (kuruş). Null => varsayılan ücret kullanılır.
/// Elebaşı için anlamsız (kişi başı ücret ayarlardan gelir).
 int? get dailyWageOverrideKurus;/// Elebaşının getirdiği kişi sayısı — YALNIZCA bilgi amaçlı gösterilir.
/// Listede/detayda "N kişilik ekip" olarak görünür; yoklama ve para
/// hesabına GİRMEZ (günlük kişi sayısı yoklamada ayrıca tutulur). Yalnız
/// elebaşı için anlamlı; bireysel işçide null. Null/0 => gösterilmez.
 int? get defaultHeadcount;/// Soft-delete bayrağı (kural §5): pasif işçi listede gizli, raporda görünür.
 bool get active;
/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkerCopyWith<Worker> get copyWith => _$WorkerCopyWithImpl<Worker>(this as Worker, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Worker&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.dailyWageOverrideKurus, dailyWageOverrideKurus) || other.dailyWageOverrideKurus == dailyWageOverrideKurus)&&(identical(other.defaultHeadcount, defaultHeadcount) || other.defaultHeadcount == defaultHeadcount)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,type,gender,dailyWageOverrideKurus,defaultHeadcount,active);

@override
String toString() {
  return 'Worker(id: $id, name: $name, type: $type, gender: $gender, dailyWageOverrideKurus: $dailyWageOverrideKurus, defaultHeadcount: $defaultHeadcount, active: $active)';
}


}

/// @nodoc
abstract mixin class $WorkerCopyWith<$Res>  {
  factory $WorkerCopyWith(Worker value, $Res Function(Worker) _then) = _$WorkerCopyWithImpl;
@useResult
$Res call({
 String id, String name, WorkerType type, Gender gender, int? dailyWageOverrideKurus, int? defaultHeadcount, bool active
});




}
/// @nodoc
class _$WorkerCopyWithImpl<$Res>
    implements $WorkerCopyWith<$Res> {
  _$WorkerCopyWithImpl(this._self, this._then);

  final Worker _self;
  final $Res Function(Worker) _then;

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? gender = null,Object? dailyWageOverrideKurus = freezed,Object? defaultHeadcount = freezed,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as WorkerType,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender,dailyWageOverrideKurus: freezed == dailyWageOverrideKurus ? _self.dailyWageOverrideKurus : dailyWageOverrideKurus // ignore: cast_nullable_to_non_nullable
as int?,defaultHeadcount: freezed == defaultHeadcount ? _self.defaultHeadcount : defaultHeadcount // ignore: cast_nullable_to_non_nullable
as int?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Worker].
extension WorkerPatterns on Worker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Worker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Worker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Worker value)  $default,){
final _that = this;
switch (_that) {
case _Worker():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Worker value)?  $default,){
final _that = this;
switch (_that) {
case _Worker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  WorkerType type,  Gender gender,  int? dailyWageOverrideKurus,  int? defaultHeadcount,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Worker() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.gender,_that.dailyWageOverrideKurus,_that.defaultHeadcount,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  WorkerType type,  Gender gender,  int? dailyWageOverrideKurus,  int? defaultHeadcount,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Worker():
return $default(_that.id,_that.name,_that.type,_that.gender,_that.dailyWageOverrideKurus,_that.defaultHeadcount,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  WorkerType type,  Gender gender,  int? dailyWageOverrideKurus,  int? defaultHeadcount,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Worker() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.gender,_that.dailyWageOverrideKurus,_that.defaultHeadcount,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _Worker extends Worker {
  const _Worker({required this.id, required this.name, required this.type, required this.gender, this.dailyWageOverrideKurus, this.defaultHeadcount, this.active = true}): super._();
  

@override final  String id;
@override final  String name;
@override final  WorkerType type;
@override final  Gender gender;
/// İşçiye özel günlük ücret (kuruş). Null => varsayılan ücret kullanılır.
/// Elebaşı için anlamsız (kişi başı ücret ayarlardan gelir).
@override final  int? dailyWageOverrideKurus;
/// Elebaşının getirdiği kişi sayısı — YALNIZCA bilgi amaçlı gösterilir.
/// Listede/detayda "N kişilik ekip" olarak görünür; yoklama ve para
/// hesabına GİRMEZ (günlük kişi sayısı yoklamada ayrıca tutulur). Yalnız
/// elebaşı için anlamlı; bireysel işçide null. Null/0 => gösterilmez.
@override final  int? defaultHeadcount;
/// Soft-delete bayrağı (kural §5): pasif işçi listede gizli, raporda görünür.
@override@JsonKey() final  bool active;

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkerCopyWith<_Worker> get copyWith => __$WorkerCopyWithImpl<_Worker>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Worker&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.dailyWageOverrideKurus, dailyWageOverrideKurus) || other.dailyWageOverrideKurus == dailyWageOverrideKurus)&&(identical(other.defaultHeadcount, defaultHeadcount) || other.defaultHeadcount == defaultHeadcount)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,type,gender,dailyWageOverrideKurus,defaultHeadcount,active);

@override
String toString() {
  return 'Worker(id: $id, name: $name, type: $type, gender: $gender, dailyWageOverrideKurus: $dailyWageOverrideKurus, defaultHeadcount: $defaultHeadcount, active: $active)';
}


}

/// @nodoc
abstract mixin class _$WorkerCopyWith<$Res> implements $WorkerCopyWith<$Res> {
  factory _$WorkerCopyWith(_Worker value, $Res Function(_Worker) _then) = __$WorkerCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, WorkerType type, Gender gender, int? dailyWageOverrideKurus, int? defaultHeadcount, bool active
});




}
/// @nodoc
class __$WorkerCopyWithImpl<$Res>
    implements _$WorkerCopyWith<$Res> {
  __$WorkerCopyWithImpl(this._self, this._then);

  final _Worker _self;
  final $Res Function(_Worker) _then;

/// Create a copy of Worker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? gender = null,Object? dailyWageOverrideKurus = freezed,Object? defaultHeadcount = freezed,Object? active = null,}) {
  return _then(_Worker(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as WorkerType,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender,dailyWageOverrideKurus: freezed == dailyWageOverrideKurus ? _self.dailyWageOverrideKurus : dailyWageOverrideKurus // ignore: cast_nullable_to_non_nullable
as int?,defaultHeadcount: freezed == defaultHeadcount ? _self.defaultHeadcount : defaultHeadcount // ignore: cast_nullable_to_non_nullable
as int?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
