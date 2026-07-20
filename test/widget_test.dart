import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import 'support/fake_attendance_repository.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_settings_repository.dart';
import 'support/fake_worker_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Widget appWith(AppUser? user) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(user)),
          // Firebase'siz test için Firestore'a dokunan depoları sahteler.
          settingsRepositoryProvider
              .overrideWithValue(FakeSettingsRepository()),
          workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
        ],
        child: const YevmiyeApp(),
      );

  testWidgets('Giriş yoksa Giriş ekranı gösterilir', (tester) async {
    await tester.pumpWidget(appWith(null));
    await tester.pumpAndSettle();

    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('E-posta'), findsWidgets);
  });

  testWidgets('Giriş varsa Ana Sayfa ve 5 alt menü gösterilir', (tester) async {
    await tester.pumpWidget(appWith(const AppUser(uid: 'u1', email: 'a@b.c')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Yoklama'), findsWidgets);
    expect(find.text('İşçiler'), findsWidgets);
    expect(find.text('Avans'), findsWidgets);
    expect(find.text('Kasa'), findsWidgets);
    // Hakediş sekmesi şimdilik rafta — görünmemeli.
    expect(find.text('Hakediş'), findsNothing);
  });
}
