/// Kasa Riverpod sağlayıcıları (kural §7).
///
/// Giderler ekranı TÜM kayıtları gösterir (ekranda ay ay gruplanır) — dönem
/// süzgeci yoktur, dönem raporu Rapor ekranındadır. Toplam ekranda, veri hazır
/// olunca saf `summarizeLedger` ile türetilir (yükleniyor/hata durumunda ₺0 boş
/// özet gösterilmez). Kategori ekranları (Mazot/Tamir/Bakkal) için kategorinin
/// kayıtları ayrıca sunulur.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_providers.dart';
import '../data/ledger_entry.dart';
import '../data/ledger_repository.dart';

/// Kasa deposu. Testlerde `overrideWithValue(FakeLedgerRepository(...))`.
final Provider<LedgerRepository> ledgerRepositoryProvider =
    Provider<LedgerRepository>(
  (ref) => FirestoreLedgerRepository(ref.watch(firestoreProvider)),
);

/// Tüm kayıtlar (elle + otomatik) — kategori ekranları ve genel izleme.
final StreamProvider<List<LedgerEntry>> ledgerStreamProvider =
    StreamProvider<List<LedgerEntry>>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchAll(),
);

/// Giderler ekranının listesi: tüm kayıtlar, yeni→eski sıralı (ekranda ay ay
/// gruplanır). Yükleniyor/hata durumu olduğu gibi geçer — ekran spinner ya da
/// "Yeniden Dene" gösterir, boş sanılmaz (kural §8).
final Provider<AsyncValue<List<LedgerEntry>>> ledgerSortedProvider =
    Provider<AsyncValue<List<LedgerEntry>>>((ref) {
  return ref.watch(ledgerStreamProvider).whenData((entries) {
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  });
});

/// Bir kategorinin tüm gider kayıtları (dönemden bağımsız), yeni→eski —
/// kategori ekranları (Mazot/Tamir/Bakkal).
final categoryEntriesProvider =
    Provider.family<List<LedgerEntry>, String>((ref, category) {
  final all = ref.watch(ledgerStreamProvider).asData?.value ?? const [];
  final entries = all.where((e) => e.category == category).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return entries;
});
