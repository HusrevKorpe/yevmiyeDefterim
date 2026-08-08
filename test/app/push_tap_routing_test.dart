/// Bildirime dokununca doğru ekran açılıyor mu (MainShell yönlendirmesi).
///
/// Push kurulumunun kendisi (FCM) testte hiç çalışmaz; `pushTapped` değeri
/// elle verilerek gerçek dokunuş taklit edilir — MainShell'in dinleyicisi
/// buradan sonrasını yapar.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/core/notifications/push_notifications.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advances_screen.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/jobs_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/plots_providers.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/dashboard/presentation/dashboard_screen.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import '../support/fake_advance_repository.dart';
import '../support/fake_attendance_repository.dart';
import '../support/fake_auth_repository.dart';
import '../support/fake_job_repository.dart';
import '../support/fake_ledger_repository.dart';
import '../support/fake_plot_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  // Değer global bir ValueNotifier'da tutulur → testler birbirine sızmasın.
  tearDown(() => pushTapped.value = null);

  Widget app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(const AppUser(uid: 'u1', email: 'a@b.c')),
          ),
          settingsRepositoryProvider
              .overrideWithValue(FakeSettingsRepository()),
          workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
          ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
          jobRepositoryProvider.overrideWithValue(FakeJobRepository()),
          plotRepositoryProvider.overrideWithValue(FakePlotRepository()),
        ],
        child: const YevmiyeApp(),
      );

  testWidgets('avans bildirimine dokunma → Avanslar ekranı açılır',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);

    pushTapped.value = const PushTarget(tip: PushTip.avans);
    await tester.pumpAndSettle();

    expect(find.byType(AdvancesScreen), findsOneWidget);
    // Hedef bir kez tüketilir (sonraki sekme geçişlerinde geri sıçramasın).
    expect(pushTapped.value, isNull);
  });

  testWidgets('yoklama bildirimine dokunma → o gün seçili Yoklama açılır',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    pushTapped.value =
        const PushTarget(tip: PushTip.yoklama, tarih: '2026-08-03');
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AttendanceScreen)),
    );
    expect(container.read(selectedDateProvider), '2026-08-03');
    expect(pushTapped.value, isNull);
  });
}
