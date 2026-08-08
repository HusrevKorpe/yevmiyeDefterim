/// İşçi detay özet kartındaki elebaşı kutucuğu.
///
/// Elebaşının hesabında "Açık avans" kutucuğu YOKTUR; onun yerine bugüne kadar
/// getirdiği toplam kişi (kişi-gün) gösterilir — sahada asıl merak edilen bu.
/// Bireysel işçide açık avans kutucuğu eskisi gibi durur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/presentation/worker_detail_screen.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Worker worker(WorkerType type) => Worker(
        id: 'w1',
        name: type.isCrew ? 'Usta Ali' : 'Ahmet Yılmaz',
        type: type,
        gender: Gender.male,
        dailyWageOverrideKurus: 100000,
        defaultHeadcount: type.isCrew ? 5 : null,
      );

  Future<Widget> buildApp(WorkerType type) async {
    final w = worker(type);
    final workers = FakeWorkerRepository();
    await workers.add(w);

    final attendance = FakeAttendanceRepository();
    if (type.isCrew) {
      await attendance.save(
        AttendanceRecord.crew(
          id: '2026-08-05_w1',
          date: '2026-08-05',
          workerId: 'w1',
          workerName: w.name,
          headcount: 4,
          crewRateSnapshotKurus: 100000,
        ),
      );
      await attendance.save(
        AttendanceRecord.crew(
          id: '2026-08-06_w1',
          date: '2026-08-06',
          workerId: 'w1',
          workerName: w.name,
          headcount: 3,
          crewRateSnapshotKurus: 100000,
        ),
      );
    }

    // Her iki tipte de açık avans var → kutucuk yalnız bireyselde çıkmalı.
    final advances = FakeAdvanceRepository([
      Advance(
        id: 'a1',
        workerId: 'w1',
        workerName: w.name,
        amountKurus: 50000,
        date: '2026-08-06',
      ),
    ]);

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(advances),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WorkerDetailScreen(worker: w),
      ),
    );
  }

  testWidgets('elebaşında açık avans yerine toplam kişi gösterilir',
      (tester) async {
    await tester.pumpWidget(await buildApp(WorkerType.elebasi));
    await tester.pumpAndSettle();

    expect(find.text('Açık avans'), findsNothing);
    expect(find.text('Toplam kişi'), findsOneWidget);
    expect(find.text('7 kişi'), findsOneWidget); // 4 + 3 kişi-gün
  });

  testWidgets('bireysel işçide açık avans kutucuğu durur', (tester) async {
    await tester.pumpWidget(await buildApp(WorkerType.gundelik));
    await tester.pumpAndSettle();

    expect(find.text('Açık avans'), findsOneWidget);
    expect(find.text('Toplam kişi'), findsNothing);
  });
}
