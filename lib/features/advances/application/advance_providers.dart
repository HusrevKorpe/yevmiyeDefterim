/// Avans Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/advance.dart';
import '../data/advance_repository.dart';

/// Avans deposu. Testlerde `overrideWithValue(FakeAdvanceRepository(...))`.
final Provider<AdvanceRepository> advanceRepositoryProvider =
    Provider<AdvanceRepository>(
  (ref) => FirestoreAdvanceRepository(ref.watch(firestoreProvider)),
);

/// Tüm avanslar (açık + kapanmış). Ekranlar/hakediş bunu izler.
final StreamProvider<List<Advance>> advancesStreamProvider =
    StreamProvider<List<Advance>>(
  (ref) => ref.watch(advanceRepositoryProvider).watchAll(),
);

/// Yalnız kapanmamış (açık) avanslar — hakediş mahsubu ve "Avanslar" listesi.
final Provider<List<Advance>> openAdvancesProvider = Provider<List<Advance>>(
  (ref) =>
      ref.watch(advancesStreamProvider).asData?.value.where((a) => a.isOpen).toList() ??
      const [],
);
