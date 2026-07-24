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

/// Yevmiyesi girilmemiş (null veya 0) aktif işçiler — güncelleme hatırlatması
/// için (bkz. [[wageReminderSeenProvider]]). Elebaşı DAHİL: 2026-07-24'te
/// elebaşıya da kişi başı yevmiye eklendi, mevcut elebaşıların değeri boştur.
final Provider<List<Worker>> workersMissingWageProvider = Provider<List<Worker>>(
  (ref) => ref
      .watch(activeWorkersProvider)
      .where((w) => (w.dailyWageOverrideKurus ?? 0) <= 0)
      .toList(),
);
