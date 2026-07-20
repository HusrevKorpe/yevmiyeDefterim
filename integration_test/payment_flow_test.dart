/// Ödeme akışı — GERÇEK uygulamayı (router, shell, tüm ekranlar, ViewModel'lar,
/// saf hesaplayıcı) çalıştırır; yalnız veri katmanı (Firestore + auth) bellek-içi
/// seed'li fake'lerle değiştirilir. Cihazda sürülür ve ekran görüntüsü alınır.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/app.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/auth/application/auth_providers.dart';
import 'package:yevmiye_defterim/features/auth/data/app_user.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/payroll/application/payroll_providers.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll.dart';
import 'package:yevmiye_defterim/features/payroll/data/payroll_repository.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_auth_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

/// "Öde" batch'inin gerçek etkisini seed'li fake'lere uygular (avans kapat,
/// kısmi düşür, ödenen günleri işaretle) → UI canlı güncellenir.
class DemoPayrollRepository implements PayrollRepository {
  DemoPayrollRepository(this._advances, this._attendance);

  final FakeAdvanceRepository _advances;
  final FakeAttendanceRepository _attendance;
  final List<Payroll> _payrolls = [];
  final StreamController<void> _tick = StreamController<void>.broadcast();

  @override
  Stream<List<Payroll>> watchAll() async* {
    yield List.of(_payrolls);
    yield* _tick.stream.map((_) => List.of(_payrolls));
  }

  @override
  Future<void> pay({
    required Payroll payroll,
    LedgerEntry? ledgerEntry,
    required List<String> settledAdvanceIds,
    ({String id, int remainingKurus})? partialAdvance,
    required List<String> paidAttendanceIds,
  }) async {
    _payrolls.add(payroll);
    for (final id in settledAdvanceIds) {
      final a = _advances.byId(id);
      if (a != null) {
        await _advances.update(a.copyWith(settledPayrollId: payroll.id));
      }
    }
    final partial = partialAdvance;
    if (partial != null) {
      final a = _advances.byId(partial.id);
      if (a != null) {
        await _advances.update(a.copyWith(amountKurus: partial.remainingKurus));
      }
    }
    final byId = {for (final r in _attendance.all) r.id: r};
    for (final id in paidAttendanceIds) {
      final rec = byId[id];
      if (rec != null) {
        await _attendance.save(rec.copyWith(paidPayrollId: payroll.id));
      }
    }
    _tick.add(null);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const male = 200000; // 2.000 ₺
  const female = 180000; // 1.800 ₺
  const crewRate = 150000; // 1.500 ₺ / kişi

  const workers = [
    Worker(id: 'w1', name: 'Ahmet Yılmaz', type: WorkerType.gundelik, gender: Gender.male),
    Worker(id: 'w2', name: 'Zehra Demir', type: WorkerType.sabit, gender: Gender.female),
    Worker(id: 'e1', name: 'Mehmet Usta', type: WorkerType.elebasi, gender: Gender.male),
  ];

  AttendanceRecord ind(String wid, String name, String date,
          AttendanceStatus st, int wage, WorkerType type) =>
      AttendanceRecord.individual(
        id: '${date}_$wid',
        date: date,
        workerId: wid,
        workerName: name,
        workerType: type,
        status: st,
        wageSnapshotKurus: wage,
      );

  AttendanceRecord crew(String date, int headcount) => AttendanceRecord.crew(
        id: '${date}_e1',
        date: date,
        workerId: 'e1',
        workerName: 'Mehmet Usta',
        headcount: headcount,
        crewRateSnapshotKurus: crewRate,
      );

  // HAKEDİŞ + ÖDEME KİLİDİ ŞİMDİLİK RAFTA: "Hakediş" sekmesi ve "Öde" batch'i
  // UI'dan kaldırıldı; bu uçtan-uca akış geri açılana kadar atlanır. Hakedişi
  // geri getirince skip'i kaldır.
  testWidgets('Hakediş → Öde akışı (gerçek uygulama, seed veri)',
      skip: true, (tester) async {
    await initializeDateFormatting('tr_TR', null);

    final attendance = FakeAttendanceRepository();
    // Ahmet: 3 tam + 1 yarım = 700.000 kuruş brüt.
    await attendance.save(ind('w1', 'Ahmet Yılmaz', '2026-07-14', AttendanceStatus.full, male, WorkerType.gundelik));
    await attendance.save(ind('w1', 'Ahmet Yılmaz', '2026-07-15', AttendanceStatus.full, male, WorkerType.gundelik));
    await attendance.save(ind('w1', 'Ahmet Yılmaz', '2026-07-16', AttendanceStatus.full, male, WorkerType.gundelik));
    await attendance.save(ind('w1', 'Ahmet Yılmaz', '2026-07-17', AttendanceStatus.half, male, WorkerType.gundelik));
    // Zehra: 2 tam = 360.000 kuruş.
    await attendance.save(ind('w2', 'Zehra Demir', '2026-07-14', AttendanceStatus.full, female, WorkerType.sabit));
    await attendance.save(ind('w2', 'Zehra Demir', '2026-07-15', AttendanceStatus.full, female, WorkerType.sabit));
    // Elebaşı: 4 + 3 kişi = 1.050.000 kuruş.
    await attendance.save(crew('2026-07-14', 4));
    await attendance.save(crew('2026-07-15', 3));

    // Ahmet'e 2.000 ₺ avans → net = 7.000 − 2.000 = 5.000 ₺.
    final advances = FakeAdvanceRepository([
      const Advance(
        id: 'a1',
        workerId: 'w1',
        workerName: 'Ahmet Yılmaz',
        amountKurus: 200000,
        date: '2026-07-10',
      ),
    ]);

    final workerRepo = FakeWorkerRepository();
    for (final w in workers) {
      await workerRepo.add(w);
    }

    final payrollRepo = DemoPayrollRepository(advances, attendance);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(const AppUser(uid: 'u1', email: 'demo@ciftlik.tr')),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
          const AppSettings(
            defaultWageMaleKurus: male,
            defaultWageFemaleKurus: female,
            defaultCrewRateKurus: crewRate,
          ),
        )),
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(advances),
        payrollRepositoryProvider.overrideWithValue(payrollRepo),
      ],
      child: const YevmiyeApp(),
    ));
    await tester.pumpAndSettle();

    // Dönemi deterministik yap (makine saatinden bağımsız).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(YevmiyeApp)),
      listen: false,
    );
    container.read(payrollPeriodProvider.notifier).setStart('2026-07-01');
    container.read(payrollPeriodProvider.notifier).setEnd('2026-07-31');
    await tester.pumpAndSettle();

    await binding.takeScreenshot('01-ana-sayfa');

    // Hakediş sekmesine geç.
    await tester.tap(find.text('Hakediş').last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-hakedis-listesi');

    // Ahmet'in satırındaki "Öde" düğmesine bas → onay diyaloğu.
    final ahmetTile = find.ancestor(
      of: find.text('Ahmet Yılmaz'),
      matching: find.byType(Card),
    );
    final ahmetPay = find.descendant(
      of: ahmetTile,
      matching: find.widgetWithText(FilledButton, 'Öde'),
    );
    await tester.tap(ahmetPay);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-onay-diyalogu');

    // Diyalogdaki "Öde"yi onayla.
    final dialogPay = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Öde'),
    );
    await tester.tap(dialogPay);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-odeme-sonrasi');

    // Ödeme sonrası Ahmet listeden düşer (günleri ödendi, avansı kapandı).
    expect(find.text('Ahmet Yılmaz'), findsNothing);
    expect(find.text('Zehra Demir'), findsOneWidget);

    // Avanslar ekranını aç (Ahmet'in avansı artık "kapanmış").
    await tester.tap(find.widgetWithText(TextButton, 'Avanslar'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('05-avanslar');
  });
}
