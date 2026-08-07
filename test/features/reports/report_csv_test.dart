import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/reports/application/work_cost.dart';
import 'package:yevmiye_defterim/features/reports/application/period_report.dart';
import 'package:yevmiye_defterim/features/reports/application/report_csv.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// CSV dışa aktarma saf testleri (kural §11): BOM, bölümler, tutar formatı,
/// alan tırnaklama, dosya adı.
void main() {
  PeriodReport report({
    List<WorkerEarning> earnings = const [],
    List<WorkCost> jobCosts = const [],
  }) =>
      PeriodReport(
        startIso: '2026-07-01',
        endIso: '2026-07-31',
        expenseKurus: 200000,
        expenseByCategory: const {
          'mazot': 120000,
          'tamir': 50000,
          'bakkal': 30000,
        },
        grossLaborKurus: 900000,
        advancesGivenKurus: 70000,
        workerEarnings: earnings,
        jobCosts: jobCosts,
      );

  WorkCost field(
    String? id,
    String name, {
    int halves = 2,
    int days = 1,
    int gross = 200000,
  }) =>
      WorkCost(
        groupId: id,
        groupName: name,
        workdayHalves: halves,
        dayCount: days,
        grossKurus: gross,
        workers: const [],
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
    expect(csv, contains('Tamir;500,00'));
    expect(csv, contains('Bakkal;300,00'));
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
    // Mesaisiz işçide mesai kolonları 0 (brüt yine mesai dahil toplam).
    expect(csv, contains('Ahmet;Gündelik;3;1;0;0;0;0,00;7.000,00'));
  });

  test('işçi satırı: mesai saati ve tutarı ayrı kolonlarda', () {
    final csv = buildReportCsv(report(earnings: [
      const WorkerEarning(
        workerId: 'w1',
        workerName: 'Ahmet',
        type: WorkerType.gundelik,
        fullDays: 3,
        overtimeHours: 5,
        overtimeKurus: 50000,
        // Brüt mesai DAHİL: 3 gün yevmiye + ₺500 mesai.
        grossKurus: 650000,
      ),
    ]));
    expect(csv, contains('Ahmet;Gündelik;3;0;0;0;5;500,00;6.500,00'));
  });

  test('mesai girildiyse işçilik bölümüne kırılım satırı eklenir', () {
    final csv = buildReportCsv(PeriodReport(
      startIso: '2026-07-01',
      endIso: '2026-07-31',
      grossLaborKurus: 950000,
      overtimeKurus: 50000,
      overtimeHours: 5,
    ));
    expect(csv, contains('Bunun mesaisi;500,00'));
    expect(csv, contains('Mesai saati;5'));
  });

  test('mesai hiç girilmediyse kırılım satırı yazılmaz', () {
    final csv = buildReportCsv(report());
    expect(csv.contains('Bunun mesaisi'), isFalse);
    // Satır BAŞINDA "Mesai saati" yok (kolon başlığındaki geçiş sayılmaz).
    expect(csv.contains('\r\nMesai saati;'), isFalse);
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

  test('iş bölümü: yevmiye/gün/işçi/tutar satırları', () {
    final csv = buildReportCsv(report(jobCosts: [
      field('f1', 'Dere', halves: 5, days: 3, gross: 500000),
      field(null, kUnassignedJobLabel, halves: 2, gross: 200000),
    ]));
    expect(csv, contains('İŞ MALİYETİ (İŞÇİLİK)'));
    expect(csv, contains('Dere;2,5;3;0;5.000,00'));
    expect(csv, contains('$kUnassignedJobLabel;1;1;0;2.000,00'));
  });

  test('iş seçimi hiç kullanılmadıysa bölüm yazılmaz', () {
    // Yalnız "seçilmemiş" satırı olan rapor → bölüm gürültü olurdu.
    final csv = buildReportCsv(report(jobCosts: [
      field(null, kUnassignedJobLabel),
    ]));
    expect(csv.contains('İŞ MALİYETİ'), isFalse);
  });

  test('dosya adı dönem uçlarını içerir', () {
    expect(reportFileBase(report()), 'rapor_2026-07-01_2026-07-31');
  });
}
