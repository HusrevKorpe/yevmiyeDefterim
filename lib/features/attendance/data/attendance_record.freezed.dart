// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AttendanceRecord {

 String get id; String get date; String get workerId; String get workerName; String? get paidPayrollId; String? get fieldId; String? get fieldName;
/// Create a copy of AttendanceRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttendanceRecordCopyWith<AttendanceRecord> get copyWith => _$AttendanceRecordCopyWithImpl<AttendanceRecord>(this as AttendanceRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttendanceRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.paidPayrollId, paidPayrollId) || other.paidPayrollId == paidPayrollId)&&(identical(other.fieldId, fieldId) || other.fieldId == fieldId)&&(identical(other.fieldName, fieldName) || other.fieldName == fieldName));
}


@override
int get hashCode => Object.hash(runtimeType,id,date,workerId,workerName,paidPayrollId,fieldId,fieldName);

@override
String toString() {
  return 'AttendanceRecord(id: $id, date: $date, workerId: $workerId, workerName: $workerName, paidPayrollId: $paidPayrollId, fieldId: $fieldId, fieldName: $fieldName)';
}


}

/// @nodoc
abstract mixin class $AttendanceRecordCopyWith<$Res>  {
  factory $AttendanceRecordCopyWith(AttendanceRecord value, $Res Function(AttendanceRecord) _then) = _$AttendanceRecordCopyWithImpl;
@useResult
$Res call({
 String id, String date, String workerId, String workerName, String? paidPayrollId, String? fieldId, String? fieldName
});




}
/// @nodoc
class _$AttendanceRecordCopyWithImpl<$Res>
    implements $AttendanceRecordCopyWith<$Res> {
  _$AttendanceRecordCopyWithImpl(this._self, this._then);

  final AttendanceRecord _self;
  final $Res Function(AttendanceRecord) _then;

/// Create a copy of AttendanceRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? date = null,Object? workerId = null,Object? workerName = null,Object? paidPayrollId = freezed,Object? fieldId = freezed,Object? fieldName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,paidPayrollId: freezed == paidPayrollId ? _self.paidPayrollId : paidPayrollId // ignore: cast_nullable_to_non_nullable
as String?,fieldId: freezed == fieldId ? _self.fieldId : fieldId // ignore: cast_nullable_to_non_nullable
as String?,fieldName: freezed == fieldName ? _self.fieldName : fieldName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AttendanceRecord].
extension AttendanceRecordPatterns on AttendanceRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( IndividualAttendance value)?  individual,TResult Function( CrewAttendance value)?  crew,required TResult orElse(),}){
final _that = this;
switch (_that) {
case IndividualAttendance() when individual != null:
return individual(_that);case CrewAttendance() when crew != null:
return crew(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( IndividualAttendance value)  individual,required TResult Function( CrewAttendance value)  crew,}){
final _that = this;
switch (_that) {
case IndividualAttendance():
return individual(_that);case CrewAttendance():
return crew(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( IndividualAttendance value)?  individual,TResult? Function( CrewAttendance value)?  crew,}){
final _that = this;
switch (_that) {
case IndividualAttendance() when individual != null:
return individual(_that);case CrewAttendance() when crew != null:
return crew(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String date,  String workerId,  String workerName,  WorkerType workerType,  AttendanceStatus status,  int wageSnapshotKurus,  String? paidPayrollId,  String? fieldId,  String? fieldName)?  individual,TResult Function( String id,  String date,  String workerId,  String workerName,  int headcount,  int crewRateSnapshotKurus,  int? agreedPayKurus,  String? paidPayrollId,  String? fieldId,  String? fieldName)?  crew,required TResult orElse(),}) {final _that = this;
switch (_that) {
case IndividualAttendance() when individual != null:
return individual(_that.id,_that.date,_that.workerId,_that.workerName,_that.workerType,_that.status,_that.wageSnapshotKurus,_that.paidPayrollId,_that.fieldId,_that.fieldName);case CrewAttendance() when crew != null:
return crew(_that.id,_that.date,_that.workerId,_that.workerName,_that.headcount,_that.crewRateSnapshotKurus,_that.agreedPayKurus,_that.paidPayrollId,_that.fieldId,_that.fieldName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String date,  String workerId,  String workerName,  WorkerType workerType,  AttendanceStatus status,  int wageSnapshotKurus,  String? paidPayrollId,  String? fieldId,  String? fieldName)  individual,required TResult Function( String id,  String date,  String workerId,  String workerName,  int headcount,  int crewRateSnapshotKurus,  int? agreedPayKurus,  String? paidPayrollId,  String? fieldId,  String? fieldName)  crew,}) {final _that = this;
switch (_that) {
case IndividualAttendance():
return individual(_that.id,_that.date,_that.workerId,_that.workerName,_that.workerType,_that.status,_that.wageSnapshotKurus,_that.paidPayrollId,_that.fieldId,_that.fieldName);case CrewAttendance():
return crew(_that.id,_that.date,_that.workerId,_that.workerName,_that.headcount,_that.crewRateSnapshotKurus,_that.agreedPayKurus,_that.paidPayrollId,_that.fieldId,_that.fieldName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String date,  String workerId,  String workerName,  WorkerType workerType,  AttendanceStatus status,  int wageSnapshotKurus,  String? paidPayrollId,  String? fieldId,  String? fieldName)?  individual,TResult? Function( String id,  String date,  String workerId,  String workerName,  int headcount,  int crewRateSnapshotKurus,  int? agreedPayKurus,  String? paidPayrollId,  String? fieldId,  String? fieldName)?  crew,}) {final _that = this;
switch (_that) {
case IndividualAttendance() when individual != null:
return individual(_that.id,_that.date,_that.workerId,_that.workerName,_that.workerType,_that.status,_that.wageSnapshotKurus,_that.paidPayrollId,_that.fieldId,_that.fieldName);case CrewAttendance() when crew != null:
return crew(_that.id,_that.date,_that.workerId,_that.workerName,_that.headcount,_that.crewRateSnapshotKurus,_that.agreedPayKurus,_that.paidPayrollId,_that.fieldId,_that.fieldName);case _:
  return null;

}
}

}

/// @nodoc


class IndividualAttendance extends AttendanceRecord {
  const IndividualAttendance({required this.id, required this.date, required this.workerId, required this.workerName, required this.workerType, required this.status, required this.wageSnapshotKurus, this.paidPayrollId, this.fieldId, this.fieldName}): super._();
  

@override final  String id;
@override final  String date;
@override final  String workerId;
@override final  String workerName;
 final  WorkerType workerType;
 final  AttendanceStatus status;
 final  int wageSnapshotKurus;
@override final  String? paidPayrollId;
@override final  String? fieldId;
@override final  String? fieldName;

/// Create a copy of AttendanceRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IndividualAttendanceCopyWith<IndividualAttendance> get copyWith => _$IndividualAttendanceCopyWithImpl<IndividualAttendance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IndividualAttendance&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.workerType, workerType) || other.workerType == workerType)&&(identical(other.status, status) || other.status == status)&&(identical(other.wageSnapshotKurus, wageSnapshotKurus) || other.wageSnapshotKurus == wageSnapshotKurus)&&(identical(other.paidPayrollId, paidPayrollId) || other.paidPayrollId == paidPayrollId)&&(identical(other.fieldId, fieldId) || other.fieldId == fieldId)&&(identical(other.fieldName, fieldName) || other.fieldName == fieldName));
}


@override
int get hashCode => Object.hash(runtimeType,id,date,workerId,workerName,workerType,status,wageSnapshotKurus,paidPayrollId,fieldId,fieldName);

@override
String toString() {
  return 'AttendanceRecord.individual(id: $id, date: $date, workerId: $workerId, workerName: $workerName, workerType: $workerType, status: $status, wageSnapshotKurus: $wageSnapshotKurus, paidPayrollId: $paidPayrollId, fieldId: $fieldId, fieldName: $fieldName)';
}


}

/// @nodoc
abstract mixin class $IndividualAttendanceCopyWith<$Res> implements $AttendanceRecordCopyWith<$Res> {
  factory $IndividualAttendanceCopyWith(IndividualAttendance value, $Res Function(IndividualAttendance) _then) = _$IndividualAttendanceCopyWithImpl;
@override @useResult
$Res call({
 String id, String date, String workerId, String workerName, WorkerType workerType, AttendanceStatus status, int wageSnapshotKurus, String? paidPayrollId, String? fieldId, String? fieldName
});




}
/// @nodoc
class _$IndividualAttendanceCopyWithImpl<$Res>
    implements $IndividualAttendanceCopyWith<$Res> {
  _$IndividualAttendanceCopyWithImpl(this._self, this._then);

  final IndividualAttendance _self;
  final $Res Function(IndividualAttendance) _then;

/// Create a copy of AttendanceRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? date = null,Object? workerId = null,Object? workerName = null,Object? workerType = null,Object? status = null,Object? wageSnapshotKurus = null,Object? paidPayrollId = freezed,Object? fieldId = freezed,Object? fieldName = freezed,}) {
  return _then(IndividualAttendance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,workerType: null == workerType ? _self.workerType : workerType // ignore: cast_nullable_to_non_nullable
as WorkerType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AttendanceStatus,wageSnapshotKurus: null == wageSnapshotKurus ? _self.wageSnapshotKurus : wageSnapshotKurus // ignore: cast_nullable_to_non_nullable
as int,paidPayrollId: freezed == paidPayrollId ? _self.paidPayrollId : paidPayrollId // ignore: cast_nullable_to_non_nullable
as String?,fieldId: freezed == fieldId ? _self.fieldId : fieldId // ignore: cast_nullable_to_non_nullable
as String?,fieldName: freezed == fieldName ? _self.fieldName : fieldName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class CrewAttendance extends AttendanceRecord {
  const CrewAttendance({required this.id, required this.date, required this.workerId, required this.workerName, required this.headcount, required this.crewRateSnapshotKurus, this.agreedPayKurus, this.paidPayrollId, this.fieldId, this.fieldName}): super._();
  

@override final  String id;
@override final  String date;
@override final  String workerId;
@override final  String workerName;
 final  int headcount;
 final  int crewRateSnapshotKurus;
 final  int? agreedPayKurus;
@override final  String? paidPayrollId;
@override final  String? fieldId;
@override final  String? fieldName;

/// Create a copy of AttendanceRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CrewAttendanceCopyWith<CrewAttendance> get copyWith => _$CrewAttendanceCopyWithImpl<CrewAttendance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CrewAttendance&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.workerId, workerId) || other.workerId == workerId)&&(identical(other.workerName, workerName) || other.workerName == workerName)&&(identical(other.headcount, headcount) || other.headcount == headcount)&&(identical(other.crewRateSnapshotKurus, crewRateSnapshotKurus) || other.crewRateSnapshotKurus == crewRateSnapshotKurus)&&(identical(other.agreedPayKurus, agreedPayKurus) || other.agreedPayKurus == agreedPayKurus)&&(identical(other.paidPayrollId, paidPayrollId) || other.paidPayrollId == paidPayrollId)&&(identical(other.fieldId, fieldId) || other.fieldId == fieldId)&&(identical(other.fieldName, fieldName) || other.fieldName == fieldName));
}


@override
int get hashCode => Object.hash(runtimeType,id,date,workerId,workerName,headcount,crewRateSnapshotKurus,agreedPayKurus,paidPayrollId,fieldId,fieldName);

@override
String toString() {
  return 'AttendanceRecord.crew(id: $id, date: $date, workerId: $workerId, workerName: $workerName, headcount: $headcount, crewRateSnapshotKurus: $crewRateSnapshotKurus, agreedPayKurus: $agreedPayKurus, paidPayrollId: $paidPayrollId, fieldId: $fieldId, fieldName: $fieldName)';
}


}

/// @nodoc
abstract mixin class $CrewAttendanceCopyWith<$Res> implements $AttendanceRecordCopyWith<$Res> {
  factory $CrewAttendanceCopyWith(CrewAttendance value, $Res Function(CrewAttendance) _then) = _$CrewAttendanceCopyWithImpl;
@override @useResult
$Res call({
 String id, String date, String workerId, String workerName, int headcount, int crewRateSnapshotKurus, int? agreedPayKurus, String? paidPayrollId, String? fieldId, String? fieldName
});




}
/// @nodoc
class _$CrewAttendanceCopyWithImpl<$Res>
    implements $CrewAttendanceCopyWith<$Res> {
  _$CrewAttendanceCopyWithImpl(this._self, this._then);

  final CrewAttendance _self;
  final $Res Function(CrewAttendance) _then;

/// Create a copy of AttendanceRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? date = null,Object? workerId = null,Object? workerName = null,Object? headcount = null,Object? crewRateSnapshotKurus = null,Object? agreedPayKurus = freezed,Object? paidPayrollId = freezed,Object? fieldId = freezed,Object? fieldName = freezed,}) {
  return _then(CrewAttendance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,workerId: null == workerId ? _self.workerId : workerId // ignore: cast_nullable_to_non_nullable
as String,workerName: null == workerName ? _self.workerName : workerName // ignore: cast_nullable_to_non_nullable
as String,headcount: null == headcount ? _self.headcount : headcount // ignore: cast_nullable_to_non_nullable
as int,crewRateSnapshotKurus: null == crewRateSnapshotKurus ? _self.crewRateSnapshotKurus : crewRateSnapshotKurus // ignore: cast_nullable_to_non_nullable
as int,agreedPayKurus: freezed == agreedPayKurus ? _self.agreedPayKurus : agreedPayKurus // ignore: cast_nullable_to_non_nullable
as int?,paidPayrollId: freezed == paidPayrollId ? _self.paidPayrollId : paidPayrollId // ignore: cast_nullable_to_non_nullable
as String?,fieldId: freezed == fieldId ? _self.fieldId : fieldId // ignore: cast_nullable_to_non_nullable
as String?,fieldName: freezed == fieldName ? _self.fieldName : fieldName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
