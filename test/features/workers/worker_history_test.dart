import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/workers/application/worker_history.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

/// İşçi geçmişi saf özet testleri (kural §11): gün sayıları, brüt kazanç,
/// avans (açık/toplam) ve net bakiye.
void main() {
  AttendanceRecord ind(String date, AttendanceStatus status, {int wage = 200000}) =>
      AttendanceRecord.individual(
        id: '${date}_w1',
        date: date,
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: wage,
      );

  Advance adv(int amount, String date, {String? settled}) => Advance(
        id: 'a-$date',
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: amount,
        date: date,
        settledPayrollId: settled,
      );

  test('boş geçmiş → tüm toplamlar sıfır', () {
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: const [],
    );
    expect(s.workedDays, 0);
    expect(s.grossEarnedKurus, 0);
    expect(s.advancesTotalKurus, 0);
    expect(s.openAdvancesKurus, 0);
  });

  test('yoklama: tam/yarım gün sayıları + brüt kazanç (absent hariç)', () {
    final s = buildWorkerHistorySummary(
      attendance: [
        ind('2026-07-02', AttendanceStatus.full), // 200000
        ind('2026-07-03', AttendanceStatus.full), // 200000
        ind('2026-07-04', AttendanceStatus.half), // 100000
        ind('2026-07-05', AttendanceStatus.absent), // 0
      ],
      advances: const [],
    );
    expect(s.fullDays, 2);
    expect(s.halfDays, 1);
    expect(s.workedDays, 3); // absent sayılmaz
    expect(s.grossEarnedKurus, 500000);
  });

  test('elebaşı: kişi-gün ve gün sayısı', () {
    final s = buildWorkerHistorySummary(
      attendance: [
        AttendanceRecord.crew(
          id: '2026-07-02_e1',
          date: '2026-07-02',
          workerId: 'e1',
          workerName: 'Usta',
          headcount: 4,
          crewRateSnapshotKurus: 150000,
        ),
        AttendanceRecord.crew(
          id: '2026-07-03_e1',
          date: '2026-07-03',
          workerId: 'e1',
          workerName: 'Usta',
          headcount: 0, // gün girilmemiş → sayılmaz
          crewRateSnapshotKurus: 150000,
        ),
      ],
      advances: const [],
    );
    expect(s.crewDays, 1);
    expect(s.crewHeadcountTotal, 4);
    expect(s.grossEarnedKurus, 600000);
  });

  test('avans: toplam ve açık ayrı', () {
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: [
        adv(50000, '2026-07-10'), // açık
        adv(30000, '2026-06-20', settled: 'p1'), // kapanmış
      ],
    );
    expect(s.advancesTotalKurus, 80000);
    expect(s.openAdvancesKurus, 50000);
  });

  test('net bakiye: brüt > avans → işçinin alacağı (pozitif)', () {
    final s = buildWorkerHistorySummary(
      attendance: [
        ind('2026-07-02', AttendanceStatus.full), // 200000
        ind('2026-07-03', AttendanceStatus.full), // 200000
      ],
      advances: [adv(50000, '2026-07-10')], // 50000 verildi
    );
    // 400000 kazandı − 50000 avans = 350000 alacağı.
    expect(s.netBalanceKurus, 350000);
  });

  test('net bakiye: avans > brüt → işçinin borcu (negatif)', () {
    final s = buildWorkerHistorySummary(
      attendance: [ind('2026-07-02', AttendanceStatus.half)], // 100000
      advances: [adv(150000, '2026-07-10')], // 150000 verildi
    );
    // 100000 kazandı − 150000 avans = -50000 (işçi 50000 borçlu).
    expect(s.netBalanceKurus, -50000);
  });

  test('net bakiye: boş geçmiş → 0 (hesap denk)', () {
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: const [],
    );
    expect(s.netBalanceKurus, 0);
  });

  test('HESAP GÖRÜLDÜ (devirsiz): kapanıştan sonra bakiye 0 olur', () {
    // 400000 kazandı, 50000 açık avans aldı → kapanıştan önce 350000 alacağı.
    // Kapanışta (07-24) avans kapanır; 350000 elden ödenmiş sayılır → bakiye 0.
    final s = buildWorkerHistorySummary(
      attendance: [
        ind('2026-07-02', AttendanceStatus.full), // 200000
        ind('2026-07-03', AttendanceStatus.full), // 200000
      ],
      advances: [
        adv(50000, '2026-07-10',
            settled: Advance.manualSettlementId('2026-07-24')),
      ],
    );
    expect(s.grossEarnedKurus, 400000, reason: 'brüt tüm zaman aynı kalır');
    expect(s.openAdvancesKurus, 0, reason: 'kapanan avans açık değil');
    expect(s.netBalanceKurus, 0, reason: 'kapanış sonrası hesap denk olmalı');
  });

  test('HESAP GÖRÜLDÜ (devirli): borç ikiye katlanmaz, devir kadar kalır', () {
    // 100000 kazandı, 150000 açık avans → −50000 (işçinin borcu 50000).
    // Kapanışta devir 50000 girildi: eski avans kapanır, aynı gün YENİ açık
    // devir avansı oluşur. Bakiye −50000 kalmalı (−100000 DEĞİL = eski çift sayım).
    final s = buildWorkerHistorySummary(
      attendance: [ind('2026-07-02', AttendanceStatus.half)], // 100000
      advances: [
        adv(150000, '2026-07-10',
            settled: Advance.manualSettlementId('2026-07-24')),
        Advance(
          id: Advance.carryoverId('2026-07-24', 'u1'),
          workerId: 'w1',
          workerName: 'Ahmet',
          amountKurus: 50000,
          date: '2026-07-24', // devir kapanış günüyle aynı tarihli, AÇIK
          note: 'Önceki hesaptan devir',
        ),
      ],
    );
    expect(s.openAdvancesKurus, 50000, reason: 'yalnız devir açık kalır');
    expect(s.netBalanceKurus, -50000,
        reason: 'devir tek sefer sayılmalı (çift sayım yok)');
    expect(s.advancesTotalKurus, 150000,
        reason: 'devir "Verilen avans toplamı"na girmez (gerçek nakit değil, '
            'kapanıştan taşınan bakiye)');
  });

  test('HESAP GÖRÜLDÜ sonrası yeni kazanç normal işler', () {
    // Kapanış (07-24) sonrası 07-25 günü 200000 kazandı → bakiye 200000 alacağı;
    // kapanış öncesi kazanç denkleşmiş sayıldığından ona eklenmez.
    final s = buildWorkerHistorySummary(
      attendance: [
        ind('2026-07-02', AttendanceStatus.full), // kapanış öncesi (denkleşti)
        ind('2026-07-25', AttendanceStatus.full), // kapanış sonrası (taze)
      ],
      advances: [
        adv(50000, '2026-07-10',
            settled: Advance.manualSettlementId('2026-07-24')),
      ],
    );
    expect(s.netBalanceKurus, 200000,
        reason: 'yalnız kapanış sonrası kazanç bakiyeye girer');
  });

  test('SİMETRİ: kapanış GÜNÜ sonrası aynı güne kazanç DA avans DA sayılmaz', () {
    // Kapanış 07-24. Aynı gün (kapanıştan sonra) hem ₺2.000 kazanç hem ₺500 açık
    // avans girildi. Simetri (bug #3, seçenek A): kapanış günü tam denkleşmiş
    // sayılır → ikisi de bakiyeye girmez (biri sayılıp diğeri sayılmaz asimetrisi
    // yok). Gerekirse "Geri Al" ile kapanış kaldırılıp tekrar kapatılır.
    final s = buildWorkerHistorySummary(
      attendance: [
        ind('2026-07-24', AttendanceStatus.full), // kapanış günü kazancı (200000)
      ],
      advances: [
        adv(150000, '2026-07-10',
            settled: Advance.manualSettlementId('2026-07-24')),
        adv(50000, '2026-07-24'), // kapanış günü AÇIK avans (devir DEĞİL)
      ],
    );
    expect(s.openAdvancesKurus, 0,
        reason: 'kapanış günü açık avansı (devir değil) denkleşmiş sayılır');
    expect(s.unreconciledGrossKurus, 0,
        reason: 'kapanış günü kazancı denkleşmiş sayılır');
    expect(s.netBalanceKurus, 0, reason: 'kazanç↔avans simetrik → bakiye 0');
  });

  test('kapanış ÖNCESİne tarihli hâlâ açık avans (sonradan girilen) bakiyeye girer', () {
    // Kapanış 07-24. Sonradan unutulan bir avans 07-20 (kapanıştan ÖNCE) tarihiyle
    // AÇIK girilir. O an var olmadığından kapanış onu kapatmadı → gerçek borçtur.
    // Avanslar ekranı onu "açık" gösterir; bakiye de saymalı (iki ekran çelişmesin).
    // Yalnız kapanış GÜNÜNÜN kendisi denkleşmiş sayılır, öncesi değil.
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: [
        adv(150000, '2026-07-10',
            settled: Advance.manualSettlementId('2026-07-24')),
        adv(50000, '2026-07-20'), // kapanış ÖNCESİ ama AÇIK (sonradan girilmiş)
      ],
    );
    expect(s.openAdvancesKurus, 50000,
        reason: 'kapanış öncesine tarihli açık avans denkleşmemiş borçtur');
    expect(s.netBalanceKurus, -50000);
  });

  test('kapanış SONRASI (sonraki gün) açık avans bakiyeye normal girer', () {
    // Kapanış 07-24; 07-25 (sonraki gün) ₺500 açık avans → denkleşmiş DEĞİL,
    // borç yaratır. (Simetrinin diğer yüzü: gerçekten kapanıştan sonraki avans sayılır.)
    final s = buildWorkerHistorySummary(
      attendance: const [],
      advances: [
        adv(150000, '2026-07-10',
            settled: Advance.manualSettlementId('2026-07-24')),
        adv(50000, '2026-07-25'), // kapanış sonrası → açık, sayılır
      ],
    );
    expect(s.openAdvancesKurus, 50000);
    expect(s.netBalanceKurus, -50000, reason: 'kapanış sonrası avans borç yaratır');
  });
}
