/// İşçi detay (özet) ekranındaki "Avans Ver" kısayolu.
///
/// Arattığı işçinin özetine giren kullanıcı, Avans sekmesine gidip listeden
/// aynı işçiyi yeniden aramak zorunda kalmadan avans verebilmeli: buton özet
/// kartının altında durur ve işçi ÖN-SEÇİLİ avans ekranını açar. Pasif işçi
/// avans seçim listesinde olmadığından (activeWorkersProvider) buton çıkmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advance_edit_screen.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';
import 'package:yevmiye_defterim/features/workers/presentation/worker_detail_screen.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Worker w({bool active = true}) => Worker(
        id: 'w1',
        name: 'Ahmet Yılmaz',
        type: WorkerType.gundelik,
        gender: Gender.male,
        dailyWageOverrideKurus: 100000,
        active: active,
      );

  Future<Widget> buildApp({
    bool active = true,
    bool canSeeMoney = true,
  }) async {
    final worker = w(active: active);
    final workers = FakeWorkerRepository();
    await workers.add(worker);

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        canSeeMoneyProvider.overrideWithValue(canSeeMoney),
      ],
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WorkerDetailScreen(worker: worker),
      ),
    );
  }

  testWidgets('özet ekranında "Avans Ver" butonu vardır', (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Avans Ver'), findsOneWidget);
  });

  testWidgets('butona basınca işçi ön-seçili avans ekranı açılır',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Avans Ver'));
    await tester.pumpAndSettle();

    expect(find.byType(AdvanceEditScreen), findsOneWidget);
    // İşçi alanı önden dolu gelmeli — listeden yeniden seçmeye gerek yok.
    expect(
      find.descendant(
        of: find.byType(AdvanceEditScreen),
        matching: find.text('Ahmet Yılmaz'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('para kısıtlı hesapta da buton görünür (avans herkese açık)',
      (tester) async {
    await tester.pumpWidget(await buildApp(canSeeMoney: false));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Avans Ver'), findsOneWidget);
  });

  testWidgets('pasif işçide buton çıkmaz', (tester) async {
    await tester.pumpWidget(await buildApp(active: false));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Avans Ver'), findsNothing);
  });
}
