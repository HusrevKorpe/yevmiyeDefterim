/// İşçi Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/worker.dart';
import '../data/worker_repository.dart';

/// İşçi deposu. Testlerde `overrideWithValue(FakeWorkerRepository(...))`.
final Provider<WorkerRepository> workerRepositoryProvider =
    Provider<WorkerRepository>(
  (ref) => FirestoreWorkerRepository(ref.watch(firestoreProvider)),
);

/// Tüm işçiler (aktif + pasif), tür/ad sıralı.
final StreamProvider<List<Worker>> workersStreamProvider =
    StreamProvider<List<Worker>>(
  (ref) => ref.watch(workerRepositoryProvider).watchAll(),
);

/// Yalnız aktif işçiler — yoklama ve seçim listeleri (kural §5).
final Provider<List<Worker>> activeWorkersProvider = Provider<List<Worker>>(
  (ref) =>
      ref.watch(workersStreamProvider).asData?.value.where((w) => w.active).toList() ??
      const [],
);
