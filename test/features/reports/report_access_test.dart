/// Kısıtlı ("para göremez") hesap tarla maliyetini de göremez.
///
/// Tarla maliyeti Rapor ekranının içindedir; Rapor kısıtlı hesapta hem Ana
/// Sayfa kısayolundan gizli hem de router'da engellidir (derin link/geri tuşu).
/// Bu test o iki hattı tarla bölümü üzerinden kilitler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/app/router.dart';
import 'package:yevmiye_defterim/core/constants/routes.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/reports/application/report_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_ledger_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  const ahmet = Worker(
    id: 'w1',
    name: 'Ahmet Yılmaz',
    type: WorkerType.gundelik,
    gender: Gender.male,
    dailyWageOverrideKurus: 200000,
  );

  /// Tarlası seçilmiş tek bir yoklama günü → Rapor'da tarla bölümü çıkar.
  Future<Widget> appFor(String email) async {
    final workers = FakeWorkerRepository();
    await workers.add(ahmet);

    final attendance = FakeAttendanceRepository();
    await attendance.save(const AttendanceRecord.individual(
      id: '2026-07-13_w1',
      date: '2026-07-13',
      workerId: 'w1',
      workerName: 'Ahmet Yılmaz',
      workerType: WorkerType.gundelik,
      status: AttendanceStatus.full,
      wageSnapshotKurus: 200000,
      fieldId: 'f1',
      fieldName: 'Dere Tarlası',
    ));

    return ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(AppUser(uid: 'u1', email: email))),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        workerRepositoryProvider.overrideWithValue(workers),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
      ],
      child: const YevmiyeApp(),
    );
  }

  /// Uygulamayı kurar ve rapor dönemini deterministik yapar (makine saatinden
  /// bağımsız: seed'lenen gün her zaman dönem içinde kalsın).
  Future<ProviderContainer> pumpApp(WidgetTester tester, String email) async {
    await tester.pumpWidget(await appFor(email));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(YevmiyeApp)),
      listen: false,
    );
    container.read(reportPeriodProvider.notifier).setStart('2026-07-01');
    container.read(reportPeriodProvider.notifier).setEnd('2026-07-31');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('kısıtlı hesap: Rapor kısayolu yok, /rapor ana sayfaya döner',
      (tester) async {
    final container = await pumpApp(tester, kMoneyRestrictedEmails.first);

    // 1. hat: Ana Sayfa'daki Rapor kısayolu hiç çizilmez.
    expect(find.byTooltip('Rapor'), findsNothing);

    // 2. hat: derin link / geri tuşuyla zorlansa bile ekran açılmaz.
    container.read(goRouterProvider).push(AppRoutes.report);
    await tester.pumpAndSettle();

    expect(find.text('Tarla Maliyeti'), findsNothing);
    expect(find.text('Dere Tarlası'), findsNothing);
    expect(find.text('Bugün Özeti'), findsWidgets, reason: 'ana sayfada kalır');

    // Tarla maliyeti kendi sayfası olduğundan ayrıca engellenmeli.
    container.read(goRouterProvider).push(AppRoutes.fieldCosts);
    await tester.pumpAndSettle();

    expect(find.text('Dere Tarlası'), findsNothing);
    expect(find.text('Bugün Özeti'), findsWidgets, reason: 'ana sayfada kalır');
  });

  testWidgets('yetkili hesap: Rapor açılır, tarla maliyeti görünür',
      (tester) async {
    await pumpApp(tester, 'patron@ciftlik.tr');

    expect(find.byTooltip('Rapor'), findsOneWidget);
    await tester.tap(find.byTooltip('Rapor'));
    await tester.pumpAndSettle();

    // Rapor'da yalnız özet kartı; döküm kendi sayfasında.
    expect(find.text('Tarla Maliyeti'), findsOneWidget);
    expect(find.text('1 tarla • 1 yevmiye'), findsOneWidget);

    await tester.tap(find.text('Tarla Maliyeti'));
    await tester.pumpAndSettle();

    // Sayfa açıldı: başlık + tarla satırı + dönem özeti.
    expect(find.text('Dönem Tarla İşçiliği'), findsOneWidget);
    expect(find.text('Dere Tarlası'), findsOneWidget);
    expect(find.text('1 yevmiye • 1 gün • 1 işçi'), findsOneWidget);
  });
}
