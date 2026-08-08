/// Avans Riverpod sağlayıcıları (kural §7).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/advance.dart';
import '../data/advance_repository.dart';
import 'settlement_cutoff.dart';

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

/// İşçi kimliği → son "Hesap görüldü" tarihi (`'yyyy-MM-dd'`). Cetvellerdeki
/// "hesabı görüldü" renklendirmesinin tek kaynağı — aylık yoklama ve çalışma
/// özeti aynı haritayı okur (tek hesap, iki ekran).
///
/// Avanslar henüz yüklenmediyse (ya da hata verdiyse) BOŞ harita döner: tablo
/// renksiz ama eksiksiz çizilir, avanslar gelince renk kendiliğinden oturur —
/// yoklama cetveli avansı beklemez.
final Provider<Map<String, String>> settledThroughByWorkerProvider =
    Provider<Map<String, String>>(
  (ref) => lastSettlementDateByWorker(
    ref.watch(advancesStreamProvider).value ?? const <Advance>[],
  ),
);
