/// Yapılan iş Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/job.dart';
import '../data/job_repository.dart';

/// İş deposu. Testlerde `overrideWithValue(FakeJobRepository(...))`.
final Provider<JobRepository> jobRepositoryProvider = Provider<JobRepository>(
  (ref) => FirestoreJobRepository(ref.watch(firestoreProvider)),
);

/// Tüm işler (aktif + pasif), ada göre sıralı.
final StreamProvider<List<Job>> jobsStreamProvider = StreamProvider<List<Job>>(
  (ref) => ref.watch(jobRepositoryProvider).watchAll(),
);

/// Yalnız aktif işler — yoklamadaki iş çipleri (kural §5). Liste boşsa çip
/// satırı hiç gösterilmez (iş seçimi isteğe bağlı bir özelliktir).
final Provider<List<Job>> activeJobsProvider = Provider<List<Job>>(
  (ref) =>
      ref.watch(jobsStreamProvider).asData?.value.where((j) => j.active).toList() ??
      const [],
);
