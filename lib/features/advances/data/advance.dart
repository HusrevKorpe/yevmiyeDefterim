/// Avans modeli (plan §3 `advances/{uuid}`, kural §6 çifte sayım yasak).
///
/// Avanslar TEK kaynak: `advances` koleksiyonu; ayrıca ledger'a yazılmaz.
/// Hakedişte mahsup edilince [settledPayrollId] dolar (kapanır). Para = tam sayı
/// kuruş (kural §1). İsim denormalize saklanır (kural §5). freezed/değişmez.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'advance.freezed.dart';

@freezed
abstract class Advance with _$Advance {
  const Advance._();

  const factory Advance({
    required String id,
    required String workerId,

    /// Denormalize işçi adı (pasif/silinmiş işçide bile gösterim — kural §5).
    required String workerName,

    /// Avans tutarı (kuruş). Kısmi mahsupta kalan tutara düşürülür (devir).
    required int amountKurus,

    /// Avansın verildiği yerel iş günü (`'yyyy-MM-dd'`).
    required String date,

    /// Mahsup edildiği hakediş ID'si. Null => kapanmamış (bir sonraki döneme
    /// devreder). Doluysa kilitli/geçmiş (kural §6).
    String? settledPayrollId,
  }) = _Advance;

  /// Kapanmamış (henüz bir hakedişte mahsup edilmemiş) avans mı?
  bool get isOpen => settledPayrollId == null;

  /// Firestore dokümanından okur. Eksik/bozuk alanlar güvenli varsayılana düşer
  /// (offline'da kısmi doküman gelebilir — çökme yerine güvenli varsayılan).
  factory Advance.fromDoc(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Advance(
      id: id,
      workerId: (m['workerId'] as String?) ?? '',
      workerName: (m['workerName'] as String?)?.trim() ?? '',
      amountKurus: _asInt(m['amountKurus']),
      date: (m['date'] as String?) ?? '',
      settledPayrollId: m['settledPayrollId'] as String?,
    );
  }

  /// Domain alanları (ts/zaman damgaları repository'de eklenir — kural §2).
  Map<String, dynamic> toMap() => {
        'workerId': workerId,
        'workerName': workerName,
        'amountKurus': amountKurus,
        'date': date,
        'settledPayrollId': settledPayrollId,
      };
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}
