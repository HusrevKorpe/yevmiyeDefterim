/// Doküman ID yardımcıları (kural.md §3).
///
/// ID'ler **cihazda** üretilir (sunucudan beklenmez) → tam offline yazma.
library;

import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Yeni rastgele doküman ID'si (işçi, avans, kasa, hakediş).
String newId() => _uuid.v4();

/// Yoklama dokümanı için deterministik ID: `'{date}_{workerId}'`.
///
/// Aynı gün + aynı işçi => aynı ID => `merge:true` ile çift kayıt olmaz.
String attendanceDocId(String isoDate, String workerId) =>
    '${isoDate}_$workerId';
