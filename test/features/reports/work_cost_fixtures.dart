/// Tarla maliyeti widget testlerinin ortak örnek verisi (özet kartı + liste).
library;

import 'package:yevmiye_defterim/features/reports/application/work_cost.dart';

const WorkCost dere = WorkCost(
  groupId: 'f1',
  groupName: 'Dere Tarlası',
  workdayHalves: 5, // 2,5 yevmiye
  dayCount: 3,
  grossKurus: 500000,
  workers: [
    WorkerCostShare(
      workerId: 'a',
      workerName: 'Ahmet',
      isCrew: false,
      workdayHalves: 4,
      grossKurus: 400000,
    ),
    WorkerCostShare(
      workerId: 'b',
      workerName: 'Veli',
      isCrew: false,
      workdayHalves: 1,
      grossKurus: 100000,
    ),
  ],
);

/// Tarlası seçilmemiş kalıntı satır (bir tarla değil).
const WorkCost bos = WorkCost(
  groupId: null,
  groupName: kUnassignedPlotLabel,
  workdayHalves: 2,
  dayCount: 1,
  grossKurus: 200000,
  workers: [],
);
