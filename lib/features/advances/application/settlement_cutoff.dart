/// "Hesap görüldü" kapanış sınırı — saf fonksiyon (Firestore'suz → unit test).
///
/// Bir işçinin hesabı en son ne zaman görüldüyse, o gün ve öncesi DENKLEŞMİŞ
/// sayılır: net bakiye yalnız sonrasını sayar (bkz. `worker_history.dart`) ve
/// yevmiye zammı yalnız sonrasına işler (bkz. `wage_backfill.dart`). Tek tanım
/// iki yerde de kullanılsın diye buraya alındı.
library;

import '../data/advance.dart';

/// [advances] içindeki elle kapatılmış ("Hesap görüldü") avanslardan EN SON
/// kapanış tarihini (`'yyyy-MM-dd'`) döndürür; hiç kapanış yoksa null.
///
/// Yalnız geçerli tarihli işaretler sayılır ([Advance.settledDate] bozuk işarete
/// null döner). ISO tarih → sözlüksel karşılaştırma = kronolojik.
String? lastSettlementDate(Iterable<Advance> advances) {
  String? latest;
  for (final a in advances) {
    if (!a.isManuallySettled) continue;
    final d = a.settledDate;
    if (d != null && (latest == null || d.compareTo(latest) > 0)) {
      latest = d;
    }
  }
  return latest;
}

/// TÜM avansları tek geçişte tarayıp `işçi kimliği → son kapanış tarihi`
/// haritası kurar — [lastSettlementDate]'in çok-işçili hâli.
///
/// Cetvellerde (aylık yoklama, çalışma özeti) "buraya kadar hesap görüldü"
/// renklendirmesi bunu kullanır: her satır kendi işçisinin sınırını okur, işçi
/// başına ayrı süzme yapılmaz (N işçi × M avans yerine tek geçiş). Kapanışı
/// olmayan işçi haritada BULUNMAZ (null demek "hiç hesap görülmedi").
Map<String, String> lastSettlementDateByWorker(Iterable<Advance> advances) {
  final out = <String, String>{};
  for (final a in advances) {
    if (!a.isManuallySettled) continue;
    final d = a.settledDate;
    if (d == null) continue;
    final current = out[a.workerId];
    if (current == null || d.compareTo(current) > 0) {
      out[a.workerId] = d;
    }
  }
  return out;
}
