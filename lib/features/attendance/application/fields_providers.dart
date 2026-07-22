/// Tarla Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/field.dart';
import '../data/field_repository.dart';

/// Tarla deposu. Testlerde `overrideWithValue(FakeFieldRepository(...))`.
final Provider<FieldRepository> fieldRepositoryProvider =
    Provider<FieldRepository>(
  (ref) => FirestoreFieldRepository(ref.watch(firestoreProvider)),
);

/// Tüm tarlalar (aktif + pasif), ada göre sıralı.
final StreamProvider<List<Field>> fieldsStreamProvider =
    StreamProvider<List<Field>>(
  (ref) => ref.watch(fieldRepositoryProvider).watchAll(),
);

/// Yalnız aktif tarlalar — yoklamadaki tarla çipleri (kural §5). Liste boşsa
/// çip satırı hiç gösterilmez (tarla seçimi isteğe bağlı bir özelliktir).
final Provider<List<Field>> activeFieldsProvider = Provider<List<Field>>(
  (ref) =>
      ref
          .watch(fieldsStreamProvider)
          .asData
          ?.value
          .where((f) => f.active)
          .toList() ??
      const [],
);
