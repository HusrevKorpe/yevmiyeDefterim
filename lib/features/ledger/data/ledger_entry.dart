/// Kasa (gider) kaydı (plan §3 `ledger/{uuid}`, kural §6).
///
/// Uygulama yalnız gider takip eder — gelir kavramı yoktur. Faz 2'de hakediş
/// "Öde" akışı, Faz 3'te elle CRUD bunu yazar. Para = tam sayı kuruş (kural §1).
/// Kaynak (`source`) çifte sayımı izler (kural §6). freezed/değişmez.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/categories.dart';

part 'ledger_entry.freezed.dart';

@freezed
abstract class LedgerEntry with _$LedgerEntry {
  const LedgerEntry._();

  const factory LedgerEntry({
    required String id,

    /// Kategori — [LedgerCategory] (mazot/maas/elebasi/genel).
    required String category,
    required int amountKurus,
    required String date,

    /// Kayıt kaynağı — [LedgerSource] (manual/payroll/elebasi), çifte sayım izi.
    required String source,
    String? note,

    /// Kaynağı hakedişse ilgili payroll ID'si (izlenebilirlik).
    String? payrollId,

    /// İlişkili işçi/elebaşı (denormalize isim — kural §5).
    String? workerId,
    String? workerName,
  }) = _LedgerEntry;

  /// Elle eklenmiş kayıt mı? Yalnız bunlar düzenlenir/silinir; hakediş "Öde"
  /// akışının yazdığı (payroll/elebasi) kayıtlar dondurulur (kural §6).
  bool get isManual => source == LedgerSource.manual;

  factory LedgerEntry.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return LedgerEntry(
      id: id,
      category: (m['category'] as String?) ?? LedgerCategory.genel,
      amountKurus: _asInt(m['amountKurus']),
      date: (m['date'] as String?) ?? '',
      source: (m['source'] as String?) ?? LedgerSource.manual,
      note: m['note'] as String?,
      payrollId: m['payrollId'] as String?,
      workerId: m['workerId'] as String?,
      workerName: (m['workerName'] as String?)?.trim(),
    );
  }

  /// Domain alanları (ts/zaman damgaları repository'de eklenir — kural §2).
  Map<String, dynamic> toMap() => {
        'category': category,
        'amountKurus': amountKurus,
        'date': date,
        'source': source,
        'note': note,
        'payrollId': payrollId,
        'workerId': workerId,
        'workerName': workerName,
      };
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}
