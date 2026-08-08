/// "Aylık tablo" (Excel cetveli) kısayolunun yeri: Ana Sayfa başlığı.
///
/// 2026-08-07'de Yoklama üst çubuğundan Ana Sayfa'ya, Rapor'un yanına taşındı.
/// Bu test iki şeyi kilitler: (1) kısayol artık Ana Sayfa'da ve çalışıyor,
/// (2) Yoklama ekranında ARTIK YOK. Ayrıca kısıtlı ("para göremez") hesapta da
/// görünür kalmalı — aylık tabloda tutarlar zaten gizlenir, cetvelin kendisi
/// herkese açıktır (bkz. router'daki `blocked` listesi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_ledger_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Widget appFor(String email) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(AppUser(uid: 'u1', email: email)),
          ),
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
          workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
          ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
        ],
        child: const YevmiyeApp(),
      );

  testWidgets('Ana Sayfa kısayolu aylık cetveli açar', (tester) async {
    await tester.pumpWidget(appFor('patron@ciftlik.tr'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Aylık tablo'), findsOneWidget);
    await tester.tap(find.byTooltip('Aylık tablo'));
    await tester.pumpAndSettle();

    expect(find.text('Aylık Yoklama'), findsOneWidget);
  });

  testWidgets('kısıtlı hesapta da görünür (Rapor gizliyken)', (tester) async {
    await tester.pumpWidget(appFor(kMoneyRestrictedEmails.first));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Rapor'), findsNothing);
    expect(find.byTooltip('Aylık tablo'), findsOneWidget);
  });

  testWidgets('Yoklama ekranında artık yok', (tester) async {
    await tester.pumpWidget(appFor('patron@ciftlik.tr'));
    await tester.pumpAndSettle();

    // Alt menüden Yoklama sekmesine geç.
    await tester.tap(find.byIcon(Icons.fact_check_outlined));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Tarla ve İşler'), findsOneWidget,
        reason: 'yerinde kaldı');
    expect(find.byTooltip('Aylık tablo'), findsNothing);
  });
}
