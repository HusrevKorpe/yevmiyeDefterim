// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payroll.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Payroll {

 String get id; String get workerId;/// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
 String get workerName; WorkerType get workerType;/// Kapsanan dönem (`'yyyy-MM-dd'`, uçlar dahil).
 String get periodStart; String get periodEnd;/// Ödemenin yapıldığı yerel gün.
 String get paidDate;/// Dönemde hak edilen brüt (Σ snapshot kazanç, kuruş).
 int get grossKurus;/// Bu ödemede mahsup edilen avans toplamı (kuruş).
 int get advancesDeductedKurus;/// Fiilen ödenen net (kuruş) = max(0, gross - avans).
 int get netPaidKurus;/// Bu dönemde kapatılamayıp devreden avans kalanı (kuruş).
 int get carryoverKurus; PayrollStatus get status;/// Yazılan kasa gider kaydı ID'si (net=0 ise gider yazılmaz → null).
 String? get ledgerEntryId;
/// Create a copy of Payroll
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PayrollCopyWith<Payroll> get copyWith => _$PayrollCopyWithImpl<Payroll>(this as Payroll, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Payroll&&(identical(other.id, id) || other.id == id)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.workerType, workerType) || other.workerType == workerType)&&(identical(other.periodStart, periodStart) || other.periodStart == periodStart)&&(identical(other.periodEnd, periodEnd) || other.periodEnd == periodEnd)&&(identical(other.paidDate, paidDate) || other.paidDate == paidDate)&&(identical(other.grossKurus, grossKurus) || other.grossKurus == grossKurus)&&(identical(other.advancesDeductedKurus, advancesDeductedKurus) || other.advancesDeductedKurus == advancesDeductedKurus)&&(identical(other.netPaidKurus, netPaidKurus) || other.netPaidKurus == netPaidKurus)&&(identical(other.carryoverKurus, carryoverKurus) || other.carryoverKurus == carryoverKurus)&&(identical(other.status, status) || other.status == status)&&(identical(other.ledgerEntryId, ledgerEntryId) || other.ledgerEntryId == ledgerEntryId));
}


@override
int get hashCode => Object.hash(runtimeType,id,workerId,workerName,workerType,periodStart,periodEnd,paidDate,grossKurus,advancesDeductedKurus,netPaidKurus,carryoverKurus,status,ledgerEntryId);

@override
String toString() {
  return 'Payroll(id: $id, workerId: $workerId, workerName: $workerName, workerType: $workerType, periodStart: $periodStart, periodEnd: $periodEnd, paidDate: $paidDate, grossKurus: $grossKurus, advancesDeductedKurus: $advancesDeductedKurus, netPaidKurus: $netPaidKurus, carryoverKurus: $carryoverKurus, status: $status, ledgerEntryId: $ledgerEntryId)';
}


}

/// @nodoc
abstract mixin class $PayrollCopyWith<$Res>  {
  factory $PayrollCopyWith(Payroll value, $Res Function(Payroll) _then) = _$PayrollCopyWithImpl;
@useResult
$Res call({
 String id, String workerId, String workerName, WorkerType workerType, String periodStart, String periodEnd, String paidDate, int grossKurus, int advancesDeductedKurus, int netPaidKurus, int carryoverKurus, PayrollStatus status, String? ledgerEntryId
});




}
/// @nodoc
class _$PayrollCopyWithImpl<$Res>
    implements $PayrollCopyWith<$Res> {
  _$PayrollCopyWithImpl(this._self, this._then);

  final Payroll _self;
  final $Res Function(Payroll) _then;

/// Create a copy of Payroll
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workerId = null,Object? workerName = null,Object? workerType = null,Object? periodStart = null,Object? periodEnd = null,Object? paidDate = null,Object? grossKurus = null,Object? advancesDeductedKurus = null,Object? netPaidKurus = null,Object? carryoverKurus = null,Object? status = null,Object? ledgerEntryId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,workerType: null == workerType ? _self.workerType : workerType // ignore: cast_nullable_to_non_nullable
as WorkerType,periodStart: null == periodStart ? _self.periodStart : periodStart // ignore: cast_nullable_to_non_nullable
as String,periodEnd: null == periodEnd ? _self.periodEnd : periodEnd // ignore: cast_nullable_to_non_nullable
as String,paidDate: null == paidDate ? _self.paidDate : paidDate // ignore: cast_nullable_to_non_nullable
as String,grossKurus: null == grossKurus ? _self.grossKurus : grossKurus // ignore: cast_nullable_to_non_nullable
as int,advancesDeductedKurus: null == advancesDeductedKurus ? _self.advancesDeductedKurus : advancesDeductedKurus // ignore: cast_nullable_to_non_nullable
as int,netPaidKurus: null == netPaidKurus ? _self.netPaidKurus : netPaidKurus // ignore: cast_nullable_to_non_nullable
as int,carryoverKurus: null == carryoverKurus ? _self.carryoverKurus : carryoverKurus // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PayrollStatus,ledgerEntryId: freezed == ledgerEntryId ? _self.ledgerEntryId : ledgerEntryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Payroll].
extension PayrollPatterns on Payroll {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Payroll value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Payroll() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Payroll value)  $default,){
final _that = this;
switch (_that) {
case _Payroll():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Payroll value)?  $default,){
final _that = this;
switch (_that) {
case _Payroll() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workerId,  String workerName,  WorkerType workerType,  String periodStart,  String periodEnd,  String paidDate,  int grossKurus,  int advancesDeductedKurus,  int netPaidKurus,  int carryoverKurus,  PayrollStatus status,  String? ledgerEntryId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Payroll() when $default != null:
return $default(_that.id,_that.workerId,_that.workerName,_that.workerType,_that.periodStart,_that.periodEnd,_that.paidDate,_that.grossKurus,_that.advancesDeductedKurus,_that.netPaidKurus,_that.carryoverKurus,_that.status,_that.ledgerEntryId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workerId,  String workerName,  WorkerType workerType,  String periodStart,  String periodEnd,  String paidDate,  int grossKurus,  int advancesDeductedKurus,  int netPaidKurus,  int carryoverKurus,  PayrollStatus status,  String? ledgerEntryId)  $default,) {final _that = this;
switch (_that) {
case _Payroll():
return $default(_that.id,_that.workerId,_that.workerName,_that.workerType,_that.periodStart,_that.periodEnd,_that.paidDate,_that.grossKurus,_that.advancesDeductedKurus,_that.netPaidKurus,_that.carryoverKurus,_that.status,_that.ledgerEntryId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workerId,  String workerName,  WorkerType workerType,  String periodStart,  String periodEnd,  String paidDate,  int grossKurus,  int advancesDeductedKurus,  int netPaidKurus,  int carryoverKurus,  PayrollStatus status,  String? ledgerEntryId)?  $default,) {final _that = this;
switch (_that) {
case _Payroll() when $default != null:
return $default(_that.id,_that.workerId,_that.workerName,_that.workerType,_that.periodStart,_that.periodEnd,_that.paidDate,_that.grossKurus,_that.advancesDeductedKurus,_that.netPaidKurus,_that.carryoverKurus,_that.status,_that.ledgerEntryId);case _:
  return null;

}
}

}

/// @nodoc


class _Payroll extends Payroll {
  const _Payroll({required this.id, required this.workerId, required this.workerName, required this.workerType, required this.periodStart, required this.periodEnd, required this.paidDate, required this.grossKurus, required this.advancesDeductedKurus, required this.netPaidKurus, this.carryoverKurus = 0, this.status = PayrollStatus.paid, this.ledgerEntryId}): super._();
  

@override final  String id;
@override final  String workerId;
/// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
@override final  String workerName;
@override final  WorkerType workerType;
/// Kapsanan dönem (`'yyyy-MM-dd'`, uçlar dahil).
@override final  String periodStart;
@override final  String periodEnd;
/// Ödemenin yapıldığı yerel gün.
@override final  String paidDate;
/// Dönemde hak edilen brüt (Σ snapshot kazanç, kuruş).
@override final  int grossKurus;
/// Bu ödemede mahsup edilen avans toplamı (kuruş).
@override final  int advancesDeductedKurus;
/// Fiilen ödenen net (kuruş) = max(0, gross - avans).
@override final  int netPaidKurus;
/// Bu dönemde kapatılamayıp devreden avans kalanı (kuruş).
@override@JsonKey() final  int carryoverKurus;
@override@JsonKey() final  PayrollStatus status;
/// Yazılan kasa gider kaydı ID'si (net=0 ise gider yazılmaz → null).
@override final  String? ledgerEntryId;

/// Create a copy of Payroll
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PayrollCopyWith<_Payroll> get copyWith => __$PayrollCopyWithImpl<_Payroll>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Payroll&&(identical(other.id, id) || other.id == id)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.workerType, workerType) || other.workerType == workerType)&&(identical(other.periodStart, periodStart) || other.periodStart == periodStart)&&(identical(other.periodEnd, periodEnd) || other.periodEnd == periodEnd)&&(identical(other.paidDate, paidDate) || other.paidDate == paidDate)&&(identical(other.grossKurus, grossKurus) || other.grossKurus == grossKurus)&&(identical(other.advancesDeductedKurus, advancesDeductedKurus) || other.advancesDeductedKurus == advancesDeductedKurus)&&(identical(other.netPaidKurus, netPaidKurus) || other.netPaidKurus == netPaidKurus)&&(identical(other.carryoverKurus, carryoverKurus) || other.carryoverKurus == carryoverKurus)&&(identical(other.status, status) || other.status == status)&&(identical(other.ledgerEntryId, ledgerEntryId) || other.ledgerEntryId == ledgerEntryId));
}


@override
int get hashCode => Object.hash(runtimeType,id,workerId,workerName,workerType,periodStart,periodEnd,paidDate,grossKurus,advancesDeductedKurus,netPaidKurus,carryoverKurus,status,ledgerEntryId);

@override
String toString() {
  return 'Payroll(id: $id, workerId: $workerId, workerName: $workerName, workerType: $workerType, periodStart: $periodStart, periodEnd: $periodEnd, paidDate: $paidDate, grossKurus: $grossKurus, advancesDeductedKurus: $advancesDeductedKurus, netPaidKurus: $netPaidKurus, carryoverKurus: $carryoverKurus, status: $status, ledgerEntryId: $ledgerEntryId)';
}


}

/// @nodoc
abstract mixin class _$PayrollCopyWith<$Res> implements $PayrollCopyWith<$Res> {
  factory _$PayrollCopyWith(_Payroll value, $Res Function(_Payroll) _then) = __$PayrollCopyWithImpl;
@override @useResult
$Res call({
 String id, String workerId, String workerName, WorkerType workerType, String periodStart, String periodEnd, String paidDate, int grossKurus, int advancesDeductedKurus, int netPaidKurus, int carryoverKurus, PayrollStatus status, String? ledgerEntryId
});




}
/// @nodoc
class __$PayrollCopyWithImpl<$Res>
    implements _$PayrollCopyWith<$Res> {
  __$PayrollCopyWithImpl(this._self, this._then);

  final _Payroll _self;
  final $Res Function(_Payroll) _then;

/// Create a copy of Payroll
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workerId = null,Object? workerName = null,Object? workerType = null,Object? periodStart = null,Object? periodEnd = null,Object? paidDate = null,Object? grossKurus = null,Object? advancesDeductedKurus = null,Object? netPaidKurus = null,Object? carryoverKurus = null,Object? status = null,Object? ledgerEntryId = freezed,}) {
  return _then(_Payroll(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,workerType: null == workerType ? _self.workerType : workerType // ignore: cast_nullable_to_non_nullable
as WorkerType,periodStart: null == periodStart ? _self.periodStart : periodStart // ignore: cast_nullable_to_non_nullable
as String,periodEnd: null == periodEnd ? _self.periodEnd : periodEnd // ignore: cast_nullable_to_non_nullable
as String,paidDate: null == paidDate ? _self.paidDate : paidDate // ignore: cast_nullable_to_non_nullable
as String,grossKurus: null == grossKurus ? _self.grossKurus : grossKurus // ignore: cast_nullable_to_non_nullable
as int,advancesDeductedKurus: null == advancesDeductedKurus ? _self.advancesDeductedKurus : advancesDeductedKurus // ignore: cast_nullable_to_non_nullable
as int,netPaidKurus: null == netPaidKurus ? _self.netPaidKurus : netPaidKurus // ignore: cast_nullable_to_non_nullable
as int,carryoverKurus: null == carryoverKurus ? _self.carryoverKurus : carryoverKurus // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PayrollStatus,ledgerEntryId: freezed == ledgerEntryId ? _self.ledgerEntryId : ledgerEntryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
