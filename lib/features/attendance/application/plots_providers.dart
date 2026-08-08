/// Tarla Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/plot.dart';
import '../data/plot_repository.dart';

/// Tarla deposu. Testlerde `overrideWithValue(FakePlotRepository(...))`.
final Provider<PlotRepository> plotRepositoryProvider = Provider<PlotRepository>(
  (ref) => FirestorePlotRepository(ref.watch(firestoreProvider)),
);

/// Tüm tarlalar (aktif + pasif), ada göre sıralı.
final StreamProvider<List<Plot>> plotsStreamProvider =
    StreamProvider<List<Plot>>(
  (ref) => ref.watch(plotRepositoryProvider).watchAll(),
);

/// Yalnız aktif tarlalar — yoklamadaki tarla çipleri (kural §5). Liste boşsa
/// çip satırı hiç gösterilmez (tarla seçimi isteğe bağlı bir özelliktir).
final Provider<List<Plot>> activePlotsProvider = Provider<List<Plot>>(
  (ref) =>
      ref.watch(plotsStreamProvider).asData?.value.where((p) => p.active).toList() ??
      const [],
);
