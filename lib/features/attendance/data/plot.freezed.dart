// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Plot {

 String get id; String get name;/// Soft-delete bayrağı (kural §5): silinen tarla seçim listesinden düşer;
/// geçmiş yoklama kayıtlarındaki denormalize adı (plotName) okunur kalır.
 bool get active;
/// Create a copy of Plot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlotCopyWith<Plot> get copyWith => _$PlotCopyWithImpl<Plot>(this as Plot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Plot&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active);

@override
String toString() {
  return 'Plot(id: $id, name: $name, active: $active)';
}


}

/// @nodoc
abstract mixin class $PlotCopyWith<$Res>  {
  factory $PlotCopyWith(Plot value, $Res Function(Plot) _then) = _$PlotCopyWithImpl;
@useResult
$Res call({
 String id, String name, bool active
});




}
/// @nodoc
class _$PlotCopyWithImpl<$Res>
    implements $PlotCopyWith<$Res> {
  _$PlotCopyWithImpl(this._self, this._then);

  final Plot _self;
  final $Res Function(Plot) _then;

/// Create a copy of Plot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Plot].
extension PlotPatterns on Plot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Plot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Plot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Plot value)  $default,){
final _that = this;
switch (_that) {
case _Plot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Plot value)?  $default,){
final _that = this;
switch (_that) {
case _Plot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Plot() when $default != null:
return $default(_that.id,_that.name,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Plot():
return $default(_that.id,_that.name,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Plot() when $default != null:
return $default(_that.id,_that.name,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _Plot extends Plot {
  const _Plot({required this.id, required this.name, this.active = true}): super._();
  

@override final  String id;
@override final  String name;
/// Soft-delete bayrağı (kural §5): silinen tarla seçim listesinden düşer;
/// geçmiş yoklama kayıtlarındaki denormalize adı (plotName) okunur kalır.
@override@JsonKey() final  bool active;

/// Create a copy of Plot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlotCopyWith<_Plot> get copyWith => __$PlotCopyWithImpl<_Plot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Plot&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active);

@override
String toString() {
  return 'Plot(id: $id, name: $name, active: $active)';
}


}

/// @nodoc
abstract mixin class _$PlotCopyWith<$Res> implements $PlotCopyWith<$Res> {
  factory _$PlotCopyWith(_Plot value, $Res Function(_Plot) _then) = __$PlotCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, bool active
});




}
/// @nodoc
class __$PlotCopyWithImpl<$Res>
    implements _$PlotCopyWith<$Res> {
  __$PlotCopyWithImpl(this._self, this._then);

  final _Plot _self;
  final $Res Function(_Plot) _then;

/// Create a copy of Plot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? active = null,}) {
  return _then(_Plot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
