/// Regresyon: Giderler'deki gider formundan açılan Material takvim diyaloğu,
/// uygulamanın GERÇEK MediaQuery yapılandırması (app.dart, tavansız min 1.10x)
/// altında AÇILDIĞINDA taşmamalı/assert atmamalı.
///
/// Geçmiş hata: app.dart tabanı `withClampedTextScaling(min:1.10, max:∞)` ile
/// uyguluyordu → ambient `_ClampedTextScaler(1.10, ∞)`. Tarih seçici metni kendi
/// tavanıyla yeniden clamp'leyince min==max çakışıp `assert(maxScale > minScale)`
/// atıyor, takvim düzeni yarım kalıp RenderFlex ~99k px taşıyordu (ölçek 1.0'da
/// bile). Düzeltme: app.dart tabanı DÜZ linear ölçekle verir; ayrıca `pickAppDate`
/// seçici metnini 1.6'ya kırpar. Bu test her iki tarafı da korur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_ledger_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openKasaCalendar(WidgetTester tester, double scale) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
          const AppSettings(
            defaultWageMaleKurus: 200000,
            defaultWageFemaleKurus: 180000,
            defaultCrewRateKurus: 150000,
          ),
        )),
        workerRepositoryProvider.overrideWithValue(FakeWorkerRepository()),
        attendanceRepositoryProvider
            .overrideWithValue(FakeAttendanceRepository()),
        advanceRepositoryProvider.overrideWithValue(FakeAdvanceRepository()),
        ledgerRepositoryProvider.overrideWithValue(FakeLedgerRepository()),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giderler').last);
    await tester.pumpAndSettle();

    // Gider ekleme formunu aç (Giderler listesinde artık dönem pili yok;
    // aynı `pickAppDate` takvimi buradaki "Tarih" alanından açılır).
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Ekle'),
    ));
    await tester.pumpAndSettle();

    // "Tarih" alanına dokun → takvim diyaloğu açılır.
    await tester.tap(find.byIcon(Icons.event));
    await tester.pumpAndSettle();

    // Takvim gerçekten açıldı mı?
    expect(find.byType(Dialog), findsOneWidget);
  }

  // Gerçekçi ölçekler: orijinal hata 1.0'da bile tetikleniyordu.
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('Kasa takvim diyaloğu ölçek $scale — taşma/assert yok',
        (tester) async {
      await initializeDateFormatting('tr_TR', null);
      await openKasaCalendar(tester, scale);
      expect(tester.takeException(), isNull);
    });
  }
}
