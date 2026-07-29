/// Tarla maliyeti widget testlerinin ortak örnek verisi (özet kartı + liste).
library;

import 'package:yevmiye_defterim/features/reports/application/field_cost.dart';

const FieldCost dere = FieldCost(
  fieldId: 'f1',
  fieldName: 'Dere Tarlası',
  workdayHalves: 5, // 2,5 yevmiye
  dayCount: 3,
  grossKurus: 500000,
  workers: [
    FieldWorkerCost(
      workerId: 'a',
      workerName: 'Ahmet',
      isCrew: false,
      workdayHalves: 4,
      grossKurus: 400000,
    ),
    FieldWorkerCost(
      workerId: 'b',
      workerName: 'Veli',
      isCrew: false,
      workdayHalves: 1,
      grossKurus: 100000,
    ),
  ],
);

/// Tarlası seçilmemiş kalıntı satır (bir tarla değil).
const FieldCost bos = FieldCost(
  fieldId: null,
  fieldName: kUnassignedFieldLabel,
  workdayHalves: 2,
  dayCount: 1,
  grossKurus: 200000,
  workers: [],
);
