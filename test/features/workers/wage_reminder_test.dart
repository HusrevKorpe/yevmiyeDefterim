import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/app/theme_mode.dart';
import 'package:yevmiye_defterim/app/update_notice.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_attendance_repository.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_worker_repository.dart';

/// Güncelleme sonrası tek-seferlik "yevmiye girin" hatırlatması (cihaz başına).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  const bosWorker = Worker(
    id: 'w1',
    name: 'Ahmet',
    type: WorkerType.gundelik,
    gender: Gender.male,
    // dailyWageOverrideKurus null → yevmiye girilmemiş.
  );
  const bosElebasi = Worker(
    id: 'e1',
    name: 'Hüsrev',
    type: WorkerType.elebasi,
    gender: Gender.male,
    defaultHeadcount: 20,
    // Kişi başı yevmiye null → girilmemiş.
  );
  const doluWorker = Worker(
    id: 'w2',
    name: 'Zehra',
    type: WorkerType.gundelik,
    gender: Gender.female,
    dailyWageOverrideKurus: 180000,
  );

  Future<Widget> appWith({
    required List<Worker> workers,
    Map<String, Object> prefs = const {},
    AppUser? user = const AppUser(uid: 'u1', email: 'a@b.c'),
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final workerRepo = FakeWorkerRepository();
    for (final w in workers) {
      await workerRepo.add(w);
    }
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(user)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
      ],
      child: const YevmiyeApp(),
    );
  }

  testWidgets('yevmiyesiz işçi/elebaşı varsa hatırlatma bir kez çıkar',
      (tester) async {
    await tester.pumpWidget(await appWith(workers: [bosWorker, bosElebasi]));
    await tester.pumpAndSettle();

    expect(find.text('Yevmiye girin'), findsOneWidget);
    expect(find.text('Hüsrev'), findsWidgets); // listede
    expect(find.text('Ahmet'), findsWidgets);
  });

  testWidgets('bütün yevmiyeler doluysa hatırlatma çıkmaz', (tester) async {
    await tester.pumpWidget(await appWith(workers: [doluWorker]));
    await tester.pumpAndSettle();

    expect(find.text('Yevmiye girin'), findsNothing);
  });

  testWidgets('görüldü işaretliyse (eski cihaz) hatırlatma çıkmaz',
      (tester) async {
    await tester.pumpWidget(await appWith(
      workers: [bosWorker],
      prefs: {kWageReminderSeenKey: true},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Yevmiye girin'), findsNothing);
  });

  testWidgets('para-kısıtlı hesapta hatırlatma çıkmaz', (tester) async {
    await tester.pumpWidget(await appWith(
      workers: [bosWorker],
      user: const AppUser(uid: 'u2', email: 'user@gmail.com'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Yevmiye girin'), findsNothing);
  });
}
