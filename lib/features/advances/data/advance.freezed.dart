// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'advance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Advance {

 String get id; String get workerId;/// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
 String get workerName;/// Avans tutarı (kuruş). Kısmi mahsupta kalan tutara düşürülür (devir).
 int get amountKurus;/// Avansın verildiği yerel iş günü (`'yyyy-MM-dd'`).
 String get date;/// Mahsup edildiği hakediş ID'si. Null => kapanmamış (bir sonraki döneme
/// devreder). Doluysa kilitli/geçmiş (kural §6).
 String? get settledPayrollId;/// İsteğe bağlı kısa açıklama (ör. neden/nasıl verildiği).
 String? get note;
/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdvanceCopyWith<Advance> get copyWith => _$AdvanceCopyWithImpl<Advance>(this as Advance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Advance&&(identical(other.id, id) || other.id == id)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.amountKurus, amountKurus) || other.amountKurus == amountKurus)&&(identical(other.date, date) || other.date == date)&&(identical(other.settledPayrollId, settledPayrollId) || other.settledPayrollId == settledPayrollId)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode => Object.hash(runtimeType,id,workerId,workerName,amountKurus,date,settledPayrollId,note);

@override
String toString() {
  return 'Advance(id: $id, workerId: $workerId, workerName: $workerName, amountKurus: $amountKurus, date: $date, settledPayrollId: $settledPayrollId, note: $note)';
}


}

/// @nodoc
abstract mixin class $AdvanceCopyWith<$Res>  {
  factory $AdvanceCopyWith(Advance value, $Res Function(Advance) _then) = _$AdvanceCopyWithImpl;
@useResult
$Res call({
 String id, String workerId, String workerName, int amountKurus, String date, String? settledPayrollId, String? note
});




}
/// @nodoc
class _$AdvanceCopyWithImpl<$Res>
    implements $AdvanceCopyWith<$Res> {
  _$AdvanceCopyWithImpl(this._self, this._then);

  final Advance _self;
  final $Res Function(Advance) _then;

/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workerId = null,Object? workerName = null,Object? amountKurus = null,Object? date = null,Object? settledPayrollId = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,amountKurus: null == amountKurus ? _self.amountKurus : amountKurus // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,settledPayrollId: freezed == settledPayrollId ? _self.settledPayrollId : settledPayrollId // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Advance].
extension AdvancePatterns on Advance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Advance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Advance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Advance value)  $default,){
final _that = this;
switch (_that) {
case _Advance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Advance value)?  $default,){
final _that = this;
switch (_that) {
case _Advance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workerId,  String workerName,  int amountKurus,  String date,  String? settledPayrollId,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Advance() when $default != null:
return $default(_that.id,_that.workerId,_that.workerName,_that.amountKurus,_that.date,_that.settledPayrollId,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workerId,  String workerName,  int amountKurus,  String date,  String? settledPayrollId,  String? note)  $default,) {final _that = this;
switch (_that) {
case _Advance():
return $default(_that.id,_that.workerId,_that.workerName,_that.amountKurus,_that.date,_that.settledPayrollId,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workerId,  String workerName,  int amountKurus,  String date,  String? settledPayrollId,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _Advance() when $default != null:
return $default(_that.id,_that.workerId,_that.workerName,_that.amountKurus,_that.date,_that.settledPayrollId,_that.note);case _:
  return null;

}
}

}

/// @nodoc


class _Advance extends Advance {
  const _Advance({required this.id, required this.workerId, required this.workerName, required this.amountKurus, required this.date, this.settledPayrollId, this.note}): super._();
  

@override final  String id;
@override final  String workerId;
/// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
@override final  String workerName;
/// Avans tutarı (kuruş). Kısmi mahsupta kalan tutara düşürülür (devir).
@override final  int amountKurus;
/// Avansın verildiği yerel iş günü (`'yyyy-MM-dd'`).
@override final  String date;
/// Mahsup edildiği hakediş ID'si. Null => kapanmamış (bir sonraki döneme
/// devreder). Doluysa kilitli/geçmiş (kural §6).
@override final  String? settledPayrollId;
/// İsteğe bağlı kısa açıklama (ör. neden/nasıl verildiği).
@override final  String? note;

/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdvanceCopyWith<_Advance> get copyWith => __$AdvanceCopyWithImpl<_Advance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Advance&&(identical(other.id, id) || other.id == id)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.amountKurus, amountKurus) || other.amountKurus == amountKurus)&&(identical(other.date, date) || other.date == date)&&(identical(other.settledPayrollId, settledPayrollId) || other.settledPayrollId == settledPayrollId)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode => Object.hash(runtimeType,id,workerId,workerName,amountKurus,date,settledPayrollId,note);

@override
String toString() {
  return 'Advance(id: $id, workerId: $workerId, workerName: $workerName, amountKurus: $amountKurus, date: $date, settledPayrollId: $settledPayrollId, note: $note)';
}


}

/// @nodoc
abstract mixin class _$AdvanceCopyWith<$Res> implements $AdvanceCopyWith<$Res> {
  factory _$AdvanceCopyWith(_Advance value, $Res Function(_Advance) _then) = __$AdvanceCopyWithImpl;
@override @useResult
$Res call({
 String id, String workerId, String workerName, int amountKurus, String date, String? settledPayrollId, String? note
});




}
/// @nodoc
class __$AdvanceCopyWithImpl<$Res>
    implements _$AdvanceCopyWith<$Res> {
  __$AdvanceCopyWithImpl(this._self, this._then);

  final _Advance _self;
  final $Res Function(_Advance) _then;

/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workerId = null,Object? workerName = null,Object? amountKurus = null,Object? date = null,Object? settledPayrollId = freezed,Object? note = freezed,}) {
  return _then(_Advance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,amountKurus: null == amountKurus ? _self.amountKurus : amountKurus // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,settledPayrollId: freezed == settledPayrollId ? _self.settledPayrollId : settledPayrollId // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
