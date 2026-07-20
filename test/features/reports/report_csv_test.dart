import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/reports/application/period_report.dart';
import 'package:yevmiye_defterim/features/reports/application/report_csv.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// CSV dışa aktarma saf testleri (kural §11): BOM, bölümler, tutar formatı,
/// alan tırnaklama, dosya adı.
void main() {
  PeriodReport report({List<WorkerEarning> earnings = const []}) => PeriodReport(
        startIso: '2026-07-01',
        endIso: '2026-07-31',
        expenseKurus: 200000,
        expenseByCategory: const {'mazot': 120000},
        grossLaborKurus: 900000,
        netPaidKurus: 400000,
        advancesGivenKurus: 70000,
        workerEarnings: earnings,
      );

  test('UTF-8 BOM ile başlar', () {
    expect(buildReportCsv(report()).startsWith('﻿'), isTrue);
  });

  test('kasa ve işçilik bölümleri, tutarlar TR formatında', () {
    final csv = buildReportCsv(report());
    expect(csv, contains('KASA'));
    expect(csv, contains('İŞÇİLİK'));
    expect(csv, contains('Toplam gider;2.000,00')); // 200000 kuruş = 2000 TL
    expect(csv, contains('Mazot;1.200,00'));
    expect(csv, contains('Tahakkuk eden brüt;9.000,00'));
  });

  test('işçi satırı: tür etiketi, gün sayıları, brüt', () {
    final csv = buildReportCsv(report(earnings: [
      const WorkerEarning(
        workerId: 'w1',
        workerName: 'Ahmet',
        type: WorkerType.gundelik,
        fullDays: 3,
        halfDays: 1,
        grossKurus: 700000,
      ),
    ]));
    expect(csv, contains('Ahmet;Gündelik;3;1;0;0;7.000,00'));
  });

  test('noktalı virgül içeren isim tırnaklanır', () {
    final csv = buildReportCsv(report(earnings: [
      const WorkerEarning(
        workerId: 'w1',
        workerName: 'Ali;Veli',
        type: WorkerType.sabit,
        fullDays: 1,
        grossKurus: 200000,
      ),
    ]));
    expect(csv, contains('"Ali;Veli"'));
  });

  test('dosya adı dönem uçlarını içerir', () {
    expect(reportFileBase(report()), 'rapor_2026-07-01_2026-07-31');
  });
}
