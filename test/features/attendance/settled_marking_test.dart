/// Aylık cetvelde "hesabı görüldü" renklendirmesi.
///
/// Bir işçinin hesabı görüldüğünde o güne KADARKİ günleri yeşil banda döner,
/// kapanış gününün sağ kenarına sınır çizgisi çizilir ve adının yanına onay
/// işareti gelir. Kapanış yoksa hiçbir iz olmaz (açıklama şeridi de temiz).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/monthly_attendance_screen.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  // Ekran açılışta içinde bulunulan ayı gösterir → tohum kayıtlar bu aya düşmeli.
  final month = currentMonthIso();
  final day05 = '$month-05';
  final day10 = '$month-10';
  final day20 = '$month-20';

  AttendanceRecord ind(String workerId, String name, String date) =>
      AttendanceRecord.individual(
        id: '${date}_$workerId',
        date: date,
        workerId: workerId,
        workerName: name,
        workerType: WorkerType.gundelik,
        status: AttendanceStatus.full,
        wageSnapshotKurus: 200000,
      );

  Future<Widget> buildApp({List<Advance> advances = const []}) async {
    final attendance = FakeAttendanceRepository();
    // Ahmet: kapanış öncesi (05), kapanış günü (10) ve sonrası (20).
    await attendance.save(ind('w1', 'Ahmet', day05));
    await attendance.save(ind('w1', 'Ahmet', day10));
    await attendance.save(ind('w1', 'Ahmet', day20));
    // Mehmet: hesabı hiç görülmemiş ikinci satır (kontrol grubu).
    await attendance.save(ind('w2', 'Mehmet', day05));

    final workers = FakeWorkerRepository();
    await workers.add(const Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
    ));
    await workers.add(const Worker(
      id: 'w2',
      name: 'Mehmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
    ));

    return ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider
            .overrideWithValue(FakeAdvanceRepository(advances)),
        workerRepositoryProvider.overrideWithValue(workers),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(home: MonthlyAttendanceScreen()),
    );
  }

  Advance settledAdvance(String settledDate) => Advance(
        id: 'a1',
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: 50000,
        date: day05,
        settledPayrollId: Advance.manualSettlementId(settledDate),
      );

  /// Kapanış gününün sağ kenarındaki kalın (2 px) sınır çizgisi sayısı.
  int cutoffBorderCount(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .where((d) {
        final border = d.border;
        return border is Border && border.right.width == 2;
      })
      .length;

  testWidgets('hesap görülünce onay işareti + açıklama + kapanış çizgisi çıkar',
      (tester) async {
    await tester.pumpWidget(await buildApp(advances: [settledAdvance(day10)]));
    await tester.pumpAndSettle();

    // Yalnız Ahmet'in adının yanında onay (Mehmet'in hesabı görülmedi).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // Açıklama şeridi yeşil bandın ne olduğunu söyler.
    expect(find.text('hesabı görüldü'), findsOneWidget);
    // Kapanış günü tek: sınır çizgisi de tek.
    expect(cutoffBorderCount(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kapanış yoksa ne onay ne açıklama ne çizgi olur', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('hesabı görüldü'), findsNothing);
    expect(cutoffBorderCount(tester), 0);
  });

  testWidgets('kapanış başka aya düşerse ay içinde çizgi olmaz, onay durur',
      (tester) async {
    // Geçen ayın 10'unda kapanmış: bu ayın hiçbir günü sınırın gerisinde değil.
    final lastMonth = shiftMonthIso(month, -1);
    await tester
        .pumpWidget(await buildApp(advances: [settledAdvance('$lastMonth-10')]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(cutoffBorderCount(tester), 0);
  });
}
