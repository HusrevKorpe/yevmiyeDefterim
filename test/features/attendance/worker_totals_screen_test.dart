/// Çalışma Özeti ekranı + aylık cetveldeki tablo ikonu.
///
/// Ekran takvimsizdir: ay/hafta seçici YOKTUR, her işçi tüm zamanın toplamıyla
/// tek satırdır. Para kısıtlı hesapta gün sayıları kalır, Kazanç sütunu gider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/monthly_attendance_screen.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/worker_totals_screen.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  AttendanceRecord ind(String date, AttendanceStatus status) =>
      AttendanceRecord.individual(
        id: '${date}_w1',
        date: date,
        workerId: 'w1',
        workerName: 'Ahmet',
        workerType: WorkerType.gundelik,
        status: status,
        wageSnapshotKurus: 200000,
      );

  Future<Widget> buildApp({
    bool canSeeMoney = true,
    List<Advance> advances = const [],
  }) async {
    final attendance = FakeAttendanceRepository();
    // BİLEREK farklı aylar: ekran ay seçmez, hepsini toplar.
    await attendance.save(ind('2026-06-30', AttendanceStatus.full));
    await attendance.save(ind('2026-07-01', AttendanceStatus.full));
    await attendance.save(ind('2026-08-05', AttendanceStatus.half));
    await attendance.save(AttendanceRecord.crew(
      id: '2026-07-01_c1',
      date: '2026-07-01',
      workerId: 'c1',
      workerName: 'Hasan',
      headcount: 20,
      crewRateSnapshotKurus: 100000,
    ));

    final workers = FakeWorkerRepository();
    await workers.add(const Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
    ));
    await workers.add(const Worker(
      id: 'c1',
      name: 'Hasan',
      type: WorkerType.elebasi,
      gender: Gender.male,
    ));

    return ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider
            .overrideWithValue(FakeAdvanceRepository(advances)),
        workerRepositoryProvider.overrideWithValue(workers),
        canSeeMoneyProvider.overrideWithValue(canSeeMoney),
      ],
      child: const MaterialApp(home: WorkerTotalsScreen()),
    );
  }

  testWidgets('her işçi tek satır: tüm ayların günü ve kazancı toplanır',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    // Başlıklar (takvim yok, üç sütun).
    expect(find.text('İşçi'), findsOneWidget);
    expect(find.text('Gün'), findsOneWidget);
    expect(find.text('Kazanç'), findsOneWidget);

    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('Hasan'), findsOneWidget);

    // Ahmet: 2 tam + 1 yarım = 2,5 gün, ₺5.000,00 (haziran+temmuz+ağustos).
    expect(find.text('2,5'), findsOneWidget);
    expect(find.text('2 tam • 1 yarım'), findsOneWidget);
    expect(find.text('₺5.000,00'), findsOneWidget);

    // Hasan (elebaşı): 1 gün, 20 kişi-gün, ₺20.000,00.
    expect(find.text('1 gün • 20 kişi-gün'), findsOneWidget);
    expect(find.text('₺20.000,00'), findsOneWidget);

    // Alt şerit: işçi sayısı + gün toplamı + genel toplam.
    expect(find.text('2 işçi • 3,5 gün'), findsOneWidget);
    expect(find.text('₺25.000,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('para kısıtlı hesapta Kazanç sütunu yok, günler durur',
      (tester) async {
    await tester.pumpWidget(await buildApp(canSeeMoney: false));
    await tester.pumpAndSettle();

    expect(find.text('Kazanç'), findsNothing);
    expect(find.text('₺5.000,00'), findsNothing);
    expect(find.text('₺25.000,00'), findsNothing);

    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.text('2,5'), findsOneWidget);
    expect(find.text('2 işçi • 3,5 gün'), findsOneWidget);
  });

  testWidgets('hesabı görülen işçinin satırı işaretlenir, ötekinde iz yok',
      (tester) async {
    await tester.pumpWidget(await buildApp(advances: [
      Advance(
        id: 'a1',
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: 50000,
        date: '2026-07-20',
        settledPayrollId: Advance.manualSettlementId('2026-07-22'),
      ),
      // Elebaşının açık avansı: kapanış YOK → satırı işaretlenmez.
      Advance(
        id: 'a2',
        workerId: 'c1',
        workerName: 'Hasan',
        amountKurus: 30000,
        date: '2026-07-21',
      ),
    ]));
    await tester.pumpAndSettle();

    // Kapanış tarihi alt satırda; gün dökümü yerine kapanış yazar.
    expect(find.text('hesap görüldü • 22 Temmuz'), findsOneWidget);
    expect(find.text('2 tam • 1 yarım'), findsNothing);
    // Yalnız Ahmet'in adının yanında onay işareti (Hasan'da yok).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // Toplamlar kapanıştan etkilenmez.
    expect(find.text('2,5'), findsOneWidget);
    expect(find.text('₺5.000,00'), findsOneWidget);
    expect(find.text('1 gün • 20 kişi-gün'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kapanış yoksa onay işareti de kapanış yazısı da yok',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.textContaining('hesap görüldü'), findsNothing);
    expect(find.text('2 tam • 1 yarım'), findsOneWidget);
  });

  testWidgets('kayıt yoksa boş durum çıkar', (tester) async {
    final app = ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(home: WorkerTotalsScreen()),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Henüz yoklama kaydı yok'), findsOneWidget);
  });

  testWidgets('aylık cetvelin sağ üstünde özet tablosu ikonu var',
      (tester) async {
    final app = ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(home: MonthlyAttendanceScreen()),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Çalışma özeti'), findsOneWidget);
    expect(find.byIcon(Icons.table_view), findsOneWidget);
  });
}
