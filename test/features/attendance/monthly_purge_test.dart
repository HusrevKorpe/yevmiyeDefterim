/// Aylık yoklama tablosunda kalıntı satır temizliği.
///
/// Deneme amacıyla açılıp sonra silinen işçi tabloda satır bırakır (satırlar
/// yoklama kayıtlarından türetilir). Bu ekrandan uzun basma + onay ile o
/// işçinin TÜM kayıtları silinir; aktif işçilerde bu yol KAPALIDIR.
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

  // Ekran açılışta içinde bulunulan ayı gösterir → tohum kayıtlar da bu aya
  // düşmeli (gerçek saate bağımlı kalmamak için ay buradan türetilir).
  final month = currentMonthIso();
  final day2 = '$month-02';
  final day3 = '$month-03';

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

  Future<(Widget, FakeAttendanceRepository, FakeAdvanceRepository)> buildApp(
    WidgetTester tester, {
    bool canSeeMoney = true,
  }) async {
    final attendance = FakeAttendanceRepository();
    await attendance.save(ind('wTest', 'Hüsrev Deneme', day2));
    await attendance.save(ind('wTest', 'Hüsrev Deneme', day3));
    await attendance.save(ind('w1', 'Ahmet', day2));
    final advances = FakeAdvanceRepository([
      Advance(
        id: 'a1',
        workerId: 'wTest',
        workerName: 'Hüsrev Deneme',
        amountKurus: 50000,
        date: day2,
      ),
    ]);
    final workers = FakeWorkerRepository();
    // 'wTest' BİLEREK eklenmiyor: kalıcı silinmiş deneme işçisini temsil eder.
    await workers.add(const Worker(
      id: 'w1',
      name: 'Ahmet',
      type: WorkerType.gundelik,
      gender: Gender.male,
    ));

    final app = ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(advances),
        workerRepositoryProvider.overrideWithValue(workers),
        canSeeMoneyProvider.overrideWithValue(canSeeMoney),
      ],
      child: const MaterialApp(home: MonthlyAttendanceScreen()),
    );
    return (app, attendance, advances);
  }

  testWidgets('silinmiş işçinin satırı görünür ve temizleme ipucu çıkar',
      (tester) async {
    final (app, _, _) = await buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Hüsrev Deneme'), findsOneWidget);
    expect(find.textContaining('basılı tutun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uzun basma + onay → işçinin tüm kayıtları silinir, satır düşer',
      (tester) async {
    final (app, attendance, advances) = await buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Hüsrev Deneme'));
    await tester.pumpAndSettle();
    expect(find.text('Kayıtları sil'), findsOneWidget);

    await tester.tap(find.text('Kalıcı Sil'));
    await tester.pumpAndSettle();

    // Kayıtlar gitti (yoklama + avans), Ahmet'inkiler duruyor.
    expect(attendance.all.map((r) => r.workerId).toList(), ['w1']);
    expect(advances.count, 0);
    // Satır tablodan düştü, ipucu da kalktı (kalıntı kalmadı).
    expect(find.text('Hüsrev Deneme'), findsNothing);
    expect(find.text('Ahmet'), findsOneWidget);
    expect(find.textContaining('basılı tutun'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vazgeçilirse hiçbir kayıt silinmez', (tester) async {
    final (app, attendance, advances) = await buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Hüsrev Deneme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(attendance.count, 3);
    expect(advances.count, 1);
    expect(find.text('Hüsrev Deneme'), findsOneWidget);
  });

  testWidgets('aktif işçide temizleme YOKTUR (uzun basma bir şey açmaz)',
      (tester) async {
    final (app, attendance, _) = await buildApp(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Ahmet'));
    await tester.pumpAndSettle();

    expect(find.text('Kayıtları sil'), findsNothing);
    expect(attendance.count, 3);
  });

  testWidgets('para kısıtlı hesapta temizleme kapalı (ipucu da yok)',
      (tester) async {
    final (app, attendance, _) = await buildApp(tester, canSeeMoney: false);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.textContaining('basılı tutun'), findsNothing);
    await tester.longPress(find.text('Hüsrev Deneme'));
    await tester.pumpAndSettle();

    expect(find.text('Kayıtları sil'), findsNothing);
    expect(attendance.count, 3);
  });
}
