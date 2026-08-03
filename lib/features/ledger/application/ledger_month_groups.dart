/// Gider kayıtlarını AYA göre gruplar — saf fonksiyon (Firestore'suz, kural §11).
///
/// Giderler ekranı yalnız seçili dönemi değil geçmişi de tek listede gösterir;
/// ay değişince araya "Temmuz 2026 · ₺X" başlık satırı girer. Gruplama burada
/// saf yapılır ki unit test edilebilsin, widget yalnız çizsin.
library;

import '../data/ledger_entry.dart';

/// Bir ayın kayıtları + o ayın toplamları.
class LedgerMonthGroup {
  const LedgerMonthGroup({
    required this.monthIso,
    required this.entries,
    required this.expenseKurus,
    required this.tahsilatKurus,
  });

  /// Ay anahtarı `'yyyy-MM'`. Bozuk/eksik tarihli kayıtta ham `date` değeri
  /// (gösterim tarafı bunu da güvenle yazar — ekran çökmez).
  final String monthIso;

  /// Ayın kayıtları, yeni→eski.
  final List<LedgerEntry> entries;

  /// Ayın toplam gideri (tahsilat HARİÇ — [summarizeLedger] ile aynı kural §6:
  /// esnafa önden verilen para harcama kayıtlarıyla sayılır).
  final int expenseKurus;

  /// Ayda verilen tahsilat toplamı (bilgi amaçlı; gidere eklenmez).
  final int tahsilatKurus;
}

/// `'yyyy-MM-dd'` tarihinden ay anahtarı; bozuk değerde ham string döner.
String monthKeyOfIso(String iso) => iso.length >= 7 ? iso.substring(0, 7) : iso;

/// [entries] kayıtlarını aylara böler. Hem gruplar hem grup içi kayıtlar
/// yeni→eski sıralıdır (giriş sırası ne olursa olsun burada güvenceye alınır —
/// `'yyyy-MM-dd'` sözlük sırası = kronolojik sıra).
List<LedgerMonthGroup> groupLedgerByMonth(List<LedgerEntry> entries) {
  final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));

  // Ekleme sırası korunur (LinkedHashMap) → ay anahtarları da yeni→eski gelir.
  final byMonth = <String, List<LedgerEntry>>{};
  for (final e in sorted) {
    byMonth.putIfAbsent(monthKeyOfIso(e.date), () => <LedgerEntry>[]).add(e);
  }

  final groups = <LedgerMonthGroup>[];
  for (final MapEntry(key: month, value: monthEntries) in byMonth.entries) {
    var expense = 0, tahsilat = 0;
    for (final e in monthEntries) {
      if (e.isTahsilat) {
        tahsilat += e.amountKurus;
      } else {
        expense += e.amountKurus;
      }
    }
    groups.add(LedgerMonthGroup(
      monthIso: month,
      entries: monthEntries,
      expenseKurus: expense,
      tahsilatKurus: tahsilat,
    ));
  }
  return groups;
}
