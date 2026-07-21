/// Kasa Riverpod sağlayıcıları (kural §7).
///
/// Dönem seçimi → o dönemin kayıtları (aralık sorgusu). Dönem özeti ekranda,
/// veri hazır olunca saf `summarizeLedger` ile türetilir (yükleniyor/hata
/// durumunda ₺0 boş özet gösterilmez). Mazot ekranı için tüm mazot kayıtları
/// ayrıca sunulur.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/categories.dart';
import '../../../core/date/app_date.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../data/ledger_entry.dart';
import '../data/ledger_repository.dart';

/// Kasa deposu. Testlerde `overrideWithValue(FakeLedgerRepository(...))`.
final Provider<LedgerRepository> ledgerRepositoryProvider =
    Provider<LedgerRepository>(
  (ref) => FirestoreLedgerRepository(ref.watch(firestoreProvider)),
);

/// Tüm kayıtlar (elle + otomatik) — Mazot ekranı ve genel izleme.
final StreamProvider<List<LedgerEntry>> ledgerStreamProvider =
    StreamProvider<List<LedgerEntry>>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchAll(),
);

/// Seçili Kasa dönemi (uçlar dahil, `'yyyy-MM-dd'`).
class LedgerPeriod {
  const LedgerPeriod(this.start, this.end);

  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      other is LedgerPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Dönem seçimi. Varsayılan: içinde bulunulan ayın 1'i → bugün.
class LedgerPeriodNotifier extends Notifier<LedgerPeriod> {
  @override
  LedgerPeriod build() => LedgerPeriod(firstDayOfMonthIso(), todayIso());

  void setStart(String iso) {
    // Başlangıç bitişten sonra olamaz.
    final end = iso.compareTo(state.end) > 0 ? iso : state.end;
    state = LedgerPeriod(iso, end);
  }

  void setEnd(String iso) {
    final start = iso.compareTo(state.start) < 0 ? iso : state.start;
    state = LedgerPeriod(start, iso);
  }

  /// Preset: içinde bulunulan ay (1'i → bugün).
  void thisMonth() => state = LedgerPeriod(firstDayOfMonthIso(), todayIso());

  /// Preset: içinde bulunulan hafta (Pazartesi → bugün).
  void thisWeek() => state = LedgerPeriod(startOfWeekIso(), todayIso());
}

final NotifierProvider<LedgerPeriodNotifier, LedgerPeriod> ledgerPeriodProvider =
    NotifierProvider<LedgerPeriodNotifier, LedgerPeriod>(
  LedgerPeriodNotifier.new,
);

/// Seçili dönemin kayıtları (aralık sorgusu), tarihe göre yeni→eski sıralı.
final StreamProvider<List<LedgerEntry>> ledgerInPeriodProvider =
    StreamProvider<List<LedgerEntry>>((ref) {
  final period = ref.watch(ledgerPeriodProvider);
  return ref
      .watch(ledgerRepositoryProvider)
      .watchByRange(period.start, period.end)
      .map((entries) {
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  });
});

/// Tüm mazot gider kayıtları (dönemden bağımsız), yeni→eski — Mazot ekranı.
final Provider<List<LedgerEntry>> mazotEntriesProvider =
    Provider<List<LedgerEntry>>((ref) {
  final all = ref.watch(ledgerStreamProvider).asData?.value ?? const [];
  final mazot = all
      .where((e) => e.category == LedgerCategory.mazot)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return mazot;
});
