/// Kasa (gelir/gider) kaydı (plan §3 `ledger/{uuid}`, kural §6).
///
/// Faz 2'de yalnız hakediş "Öde" akışı bunu yazar (gider = net ücret). Tam
/// CRUD ve Kasa ekranı Faz 3'te gelir. Para = tam sayı kuruş (kural §1).
/// Kaynak (`source`) çifte sayımı izler (kural §6). freezed/değişmez.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/categories.dart';

part 'ledger_entry.freezed.dart';

/// Kayıt yönü. Enum adı = Firestore'da saklanan değer.
enum LedgerType { income, expense }

@freezed
abstract class LedgerEntry with _$LedgerEntry {
  const LedgerEntry._();

  const factory LedgerEntry({
    required String id,
    required LedgerType type,

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

  /// Gelir kaydı mı? (Değilse gider.)
  bool get isIncome => type == LedgerType.income;

  factory LedgerEntry.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return LedgerEntry(
      id: id,
      type: _typeFromName(m['type']),
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
        'type': type.name,
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

LedgerType _typeFromName(Object? v) => LedgerType.values.firstWhere(
      (t) => t.name == v,
      orElse: () => LedgerType.expense,
    );

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}
