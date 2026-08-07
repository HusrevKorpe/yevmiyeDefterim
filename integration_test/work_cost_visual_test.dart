/// Tarla maliyet raporu görsel doğrulaması — GERÇEK uygulamada Rapor ekranına
/// gidilir, "Tarla Maliyeti" bölümü ve bir tarlanın işçi dökümü ekran
/// görüntüsüyle sabitlenir (gerçek fontla taşma kontrolü; `flutter test`
/// gerçek font taşmasını kaçırır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/reports/application/report_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_ledger_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ahmet = Worker(
      id: 'w1',
      name: 'Ahmet Yılmaz',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 200000);
  const zehra = Worker(
      id: 'w2',
      name: 'Zehra Kaya',
      type: WorkerType.sabit,
      gender: Gender.female,
      dailyWageOverrideKurus: 180000);
  const usta = Worker(
      id: 'e1',
      name: 'Usta Mehmet',
      type: WorkerType.elebasi,
      gender: Gender.male,
      dailyWageOverrideKurus: 150000);

  AttendanceRecord ind(
    Worker w,
    String date,
    AttendanceStatus s, {
    required int wage,
    String? jobId,
    String? jobName,
    String? plotId,
    String? plotName,
  }) =>
      AttendanceRecord.individual(
        id: '${date}_${w.id}',
        date: date,
        workerId: w.id,
        workerName: w.name,
        workerType: w.type,
        status: s,
        wageSnapshotKurus: wage,
        jobId: jobId,
        jobName: jobName,
        plotId: plotId,
        plotName: plotName,
      );

  testWidgets('Rapor — tarla bazlı maliyet ve işçi dökümü', (tester) async {
    await initializeDateFormatting('tr_TR', null);

    final workers = FakeWorkerRepository();
    await workers.add(ahmet);
    await workers.add(zehra);
    await workers.add(usta);

    // Temmuz 2026 — üç tarla + tarlası seçilmemiş bir gün.
    final attendance = FakeAttendanceRepository();
    Future<void> save(AttendanceRecord r) => attendance.save(r);

    await save(ind(ahmet, '2026-07-13', AttendanceStatus.full,
        wage: 200000,
        plotId: 'f1',
        plotName: 'Dere Tarlası',
        jobId: 'i1',
        jobName: 'Çapa'));
    await save(ind(ahmet, '2026-07-14', AttendanceStatus.half,
        wage: 200000,
        plotId: 'f1',
        plotName: 'Dere Tarlası',
        jobId: 'i2',
        jobName: 'Sulama'));
    await save(ind(ahmet, '2026-07-15', AttendanceStatus.full,
        wage: 200000, plotId: 'f2', plotName: 'Kavaklık', jobId: 'i1', jobName: 'Çapa'));
    await save(ind(zehra, '2026-07-13', AttendanceStatus.full,
        wage: 180000,
        plotId: 'f1',
        plotName: 'Dere Tarlası',
        jobId: 'i1',
        jobName: 'Çapa'));
    await save(ind(zehra, '2026-07-14', AttendanceStatus.full,
        wage: 180000, plotId: 'f3', plotName: 'Bağ Üstü', jobId: 'i2', jobName: 'Sulama'));
    // Hiçbiri seçilmemiş gün (kalıntı satır görünsün).
    await save(ind(zehra, '2026-07-16', AttendanceStatus.full, wage: 180000));
    // Elebaşı: kişi-gün olarak sayılır.
    await save(AttendanceRecord.crew(
      id: '2026-07-14_e1',
      date: '2026-07-14',
      workerId: 'e1',
      workerName: usta.name,
      headcount: 6,
      crewRateSnapshotKurus: 150000,
      plotId: 'f2',
      plotName: 'Kavaklık',
      jobId: 'i3',
      jobName: 'Budama',
    ));

    final ledger = FakeLedgerRepository([
      const LedgerEntry(
          id: 'l1',
          category: LedgerCategory.mazot,
          amountKurus: 150000,
          date: '2026-07-10',
          source: LedgerSource.manual),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        ledgerRepositoryProvider.overrideWithValue(ledger),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(YevmiyeApp)),
      listen: false,
    );
    // Deterministik dönem (makine saatinden bağımsız).
    container.read(reportPeriodProvider.notifier).setStart('2026-07-01');
    container.read(reportPeriodProvider.notifier).setEnd('2026-07-31');
    await tester.pumpAndSettle();

    // Ana Sayfa app bar → Rapor.
    await tester.tap(find.byTooltip('Rapor'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tarla-01-rapor-ust');

    // Rapor'daki özet kartına kaydır.
    await tester.scrollUntilVisible(find.text('Tarla / İş Maliyeti').last, 220,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tarla-02-ozet-karti');

    // Karta dokun → döküm sayfası açılır (tarla verisi dolu → tarla tarafı).
    await tester.tap(find.text('Tarla / İş Maliyeti'));
    await tester.pumpAndSettle();
    expect(find.text('Dönem Tarla İşçiliği'), findsOneWidget);
    expect(find.text('Dere Tarlası'), findsOneWidget);
    expect(find.text('Tarla seçilmemiş'), findsOneWidget);
    await binding.takeScreenshot('tarla-03-tarla-sayfasi');

    // Bir tarlaya dokun → işçi dökümü açılır.
    await tester.tap(find.text('Dere Tarlası'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsWidgets);
    await binding.takeScreenshot('tarla-04-isci-dokumu');

    // Üstteki geçişle "Yapılan İş" kırılımına geç: aynı dönem, aynı para,
    // farklı gruplama (2026-08-07 ayrımı).
    await tester.tap(find.text('Yapılan İş'));
    await tester.pumpAndSettle();
    expect(find.text('Dönem İş İşçiliği'), findsOneWidget);
    expect(find.text('Çapa'), findsOneWidget);
    expect(find.text('İş seçilmemiş'), findsOneWidget);
    await binding.takeScreenshot('tarla-05-is-kirilimi');
  });
}
