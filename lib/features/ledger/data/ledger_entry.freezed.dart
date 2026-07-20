// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ledger_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LedgerEntry {

 String get id; LedgerType get type;/// Kategori — [LedgerCategory] (mazot/maas/elebasi/genel).
 String get category; int get amountKurus; String get date;/// Kayıt kaynağı — [LedgerSource] (manual/payroll/elebasi), çifte sayım izi.
 String get source; String? get note;/// Kaynağı hakedişse ilgili payroll ID'si (izlenebilirlik).
 String? get payrollId;/// İlişkili işçi/elebaşı (denormalize isim — kural §5).
 String? get workerId; String? get workerName;
/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LedgerEntryCopyWith<LedgerEntry> get copyWith => _$LedgerEntryCopyWithImpl<LedgerEntry>(this as LedgerEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LedgerEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.category, category) || other.category == category)&&(identical(other.amountKurus, amountKurus) || other.amountKurus == amountKurus)&&(identical(other.date, date) || other.date == date)&&(identical(other.source, source) || other.source == source)&&(identical(other.note, note) || other.note == note)&&(identical(other.payrollId, payrollId) || other.payrollId == payrollId)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,category,amountKurus,date,source,note,payrollId,workerId,workerName);

@override
String toString() {
  return 'LedgerEntry(id: $id, type: $type, category: $category, amountKurus: $amountKurus, date: $date, source: $source, note: $note, payrollId: $payrollId, workerId: $workerId, workerName: $workerName)';
}


}

/// @nodoc
abstract mixin class $LedgerEntryCopyWith<$Res>  {
  factory $LedgerEntryCopyWith(LedgerEntry value, $Res Function(LedgerEntry) _then) = _$LedgerEntryCopyWithImpl;
@useResult
$Res call({
 String id, LedgerType type, String category, int amountKurus, String date, String source, String? note, String? payrollId, String? workerId, String? workerName
});




}
/// @nodoc
class _$LedgerEntryCopyWithImpl<$Res>
    implements $LedgerEntryCopyWith<$Res> {
  _$LedgerEntryCopyWithImpl(this._self, this._then);

  final LedgerEntry _self;
  final $Res Function(LedgerEntry) _then;

/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? category = null,Object? amountKurus = null,Object? date = null,Object? source = null,Object? note = freezed,Object? payrollId = freezed,Object? workerId = freezed,Object? workerName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LedgerType,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,amountKurus: null == amountKurus ? _self.amountKurus : amountKurus // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,payrollId: freezed == payrollId ? _self.payrollId : payrollId // ignore: cast_nullable_to_non_nullable
as String?,workerId: freezed == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String?,workerName: freezed == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LedgerEntry].
extension LedgerEntryPatterns on LedgerEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LedgerEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LedgerEntry value)  $default,){
final _that = this;
switch (_that) {
case _LedgerEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LedgerEntry value)?  $default,){
final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  LedgerType type,  String category,  int amountKurus,  String date,  String source,  String? note,  String? payrollId,  String? workerId,  String? workerName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
return $default(_that.id,_that.type,_that.category,_that.amountKurus,_that.date,_that.source,_that.note,_that.payrollId,_that.workerId,_that.workerName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  LedgerType type,  String category,  int amountKurus,  String date,  String source,  String? note,  String? payrollId,  String? workerId,  String? workerName)  $default,) {final _that = this;
switch (_that) {
case _LedgerEntry():
return $default(_that.id,_that.type,_that.category,_that.amountKurus,_that.date,_that.source,_that.note,_that.payrollId,_that.workerId,_that.workerName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  LedgerType type,  String category,  int amountKurus,  String date,  String source,  String? note,  String? payrollId,  String? workerId,  String? workerName)?  $default,) {final _that = this;
switch (_that) {
case _LedgerEntry() when $default != null:
return $default(_that.id,_that.type,_that.category,_that.amountKurus,_that.date,_that.source,_that.note,_that.payrollId,_that.workerId,_that.workerName);case _:
  return null;

}
}

}

/// @nodoc


class _LedgerEntry extends LedgerEntry {
  const _LedgerEntry({required this.id, required this.type, required this.category, required this.amountKurus, required this.date, required this.source, this.note, this.payrollId, this.workerId, this.workerName}): super._();
  

@override final  String id;
@override final  LedgerType type;
/// Kategori — [LedgerCategory] (mazot/maas/elebasi/genel).
@override final  String category;
@override final  int amountKurus;
@override final  String date;
/// Kayıt kaynağı — [LedgerSource] (manual/payroll/elebasi), çifte sayım izi.
@override final  String source;
@override final  String? note;
/// Kaynağı hakedişse ilgili payroll ID'si (izlenebilirlik).
@override final  String? payrollId;
/// İlişkili işçi/elebaşı (denormalize isim — kural §5).
@override final  String? workerId;
@override final  String? workerName;

/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LedgerEntryCopyWith<_LedgerEntry> get copyWith => __$LedgerEntryCopyWithImpl<_LedgerEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LedgerEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.category, category) || other.category == category)&&(identical(other.amountKurus, amountKurus) || other.amountKurus == amountKurus)&&(identical(other.date, date) || other.date == date)&&(identical(other.source, source) || other.source == source)&&(identical(other.note, note) || other.note == note)&&(identical(other.payrollId, payrollId) || other.payrollId == payrollId)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,category,amountKurus,date,source,note,payrollId,workerId,workerName);

@override
String toString() {
  return 'LedgerEntry(id: $id, type: $type, category: $category, amountKurus: $amountKurus, date: $date, source: $source, note: $note, payrollId: $payrollId, workerId: $workerId, workerName: $workerName)';
}


}

/// @nodoc
abstract mixin class _$LedgerEntryCopyWith<$Res> implements $LedgerEntryCopyWith<$Res> {
  factory _$LedgerEntryCopyWith(_LedgerEntry value, $Res Function(_LedgerEntry) _then) = __$LedgerEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, LedgerType type, String category, int amountKurus, String date, String source, String? note, String? payrollId, String? workerId, String? workerName
});




}
/// @nodoc
class __$LedgerEntryCopyWithImpl<$Res>
    implements _$LedgerEntryCopyWith<$Res> {
  __$LedgerEntryCopyWithImpl(this._self, this._then);

  final _LedgerEntry _self;
  final $Res Function(_LedgerEntry) _then;

/// Create a copy of LedgerEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? category = null,Object? amountKurus = null,Object? date = null,Object? source = null,Object? note = freezed,Object? payrollId = freezed,Object? workerId = freezed,Object? workerName = freezed,}) {
  return _then(_LedgerEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LedgerType,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,amountKurus: null == amountKurus ? _self.amountKurus : amountKurus // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,payrollId: freezed == payrollId ? _self.payrollId : payrollId // ignore: cast_nullable_to_non_nullable
as String?,workerId: freezed == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String?,workerName: freezed == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
