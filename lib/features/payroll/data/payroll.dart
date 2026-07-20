/// Hakediş modeli — dondurulmuş ödeme kaydı (plan §3 `payrolls/{uuid}`, §4).
///
/// "Öde" anında dondurulur; geçmiş ücret/avans yeniden türetilmez (kural §4).
/// `net = gross - avansMahsup`, negatifse net=0 ve kalan avans devreder
/// (`carryoverKurus`). Para = tam sayı kuruş (kural §1). freezed/değişmez.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../workers/data/worker.dart';

part 'payroll.freezed.dart';

/// Hakediş durumu. Şimdilik yalnız ödendi (Faz 2). Enum adı = saklanan değer.
enum PayrollStatus { paid }

@freezed
abstract class Payroll with _$Payroll {
  const Payroll._();

  const factory Payroll({
    required String id,
    required String workerId,

    /// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
    required String workerName,
    required WorkerType workerType,

    /// Kapsanan dönem (`'yyyy-MM-dd'`, uçlar dahil).
    required String periodStart,
    required String periodEnd,

    /// Ödemenin yapıldığı yerel gün.
    required String paidDate,

    /// Dönemde hak edilen brüt (Σ snapshot kazanç, kuruş).
    required int grossKurus,

    /// Bu ödemede mahsup edilen avans toplamı (kuruş).
    required int advancesDeductedKurus,

    /// Fiilen ödenen net (kuruş) = max(0, gross - avans).
    required int netPaidKurus,

    /// Bu dönemde kapatılamayıp devreden avans kalanı (kuruş).
    @Default(0) int carryoverKurus,
    @Default(PayrollStatus.paid) PayrollStatus status,

    /// Yazılan kasa gider kaydı ID'si (net=0 ise gider yazılmaz → null).
    String? ledgerEntryId,
  }) = _Payroll;

  bool get isCrew => workerType == WorkerType.elebasi;

  factory Payroll.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Payroll(
      id: id,
      workerId: (m['workerId'] as String?) ?? '',
      workerName: (m['workerName'] as String?)?.trim() ?? '',
      workerType: _typeFromName(m['workerType']),
      periodStart: (m['periodStart'] as String?) ?? '',
      periodEnd: (m['periodEnd'] as String?) ?? '',
      paidDate: (m['paidDate'] as String?) ?? '',
      grossKurus: _asInt(m['grossKurus']),
      advancesDeductedKurus: _asInt(m['advancesDeductedKurus']),
      netPaidKurus: _asInt(m['netPaidKurus']),
      carryoverKurus: _asInt(m['carryoverKurus']),
      status: PayrollStatus.paid,
      ledgerEntryId: m['ledgerEntryId'] as String?,
    );
  }

  /// Domain alanları (ts/zaman damgaları repository'de eklenir — kural §2).
  Map<String, dynamic> toMap() => {
        'workerId': workerId,
        'workerName': workerName,
        'workerType': workerType.name,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'paidDate': paidDate,
        'grossKurus': grossKurus,
        'advancesDeductedKurus': advancesDeductedKurus,
        'netPaidKurus': netPaidKurus,
        'carryoverKurus': carryoverKurus,
        'status': status.name,
        'ledgerEntryId': ledgerEntryId,
      };
}

WorkerType _typeFromName(Object? v) => WorkerType.values.firstWhere(
      (t) => t.name == v,
      orElse: () => WorkerType.gundelik,
    );

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}
