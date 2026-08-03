/// İşçiler ekranındaki iki aşamalı silme:
/// 1. Aktif işçiyi kaydır → soft-delete (kaydı/geçmişi durur, "Pasif İşçiler"e iner).
/// 2. Pasif işçiyi kaydır → KALICI silme: işçi + TÜM yoklama ve avans kayıtları
///    gider (aylık tablo/Excel ve raporlar da bu kayıtlardan türediği için işçi
///    her yerden kalkar). Başka işçilerin kayıtlarına dokunulmaz.
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
import 'package:yevmiye_defterim/features/workers/presentation/workers_screen.dart';

import '../../support/fake_advance_repository.dart';
import '../../support/fake_attendance_repository.dart';
import '../../support/fake_worker_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

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

  Advance adv(String id, String workerId, String name) => Advance(
        id: id,
        workerId: workerId,
        workerName: name,
        amountKurus: 50000,
        date: '2026-07-10',
      );

  Worker w(String id, String name, {bool active = true}) => Worker(
        id: id,
        name: name,
        type: WorkerType.gundelik,
        gender: Gender.male,
        dailyWageOverrideKurus: 100000,
        active: active,
      );

  late FakeAttendanceRepository attendance;
  late FakeAdvanceRepository advances;
  late FakeWorkerRepository workers;

  /// 'Hüsrev Deneme' pasif (bir kez silinmiş), 'Ahmet' aktif; ikisinin de
  /// yoklama + avans kaydı var.
  Future<Widget> buildApp({bool canSeeMoney = true}) async {
    attendance = FakeAttendanceRepository();
    await attendance.save(ind('wTest', 'Hüsrev Deneme', '2026-06-30'));
    await attendance.save(ind('wTest', 'Hüsrev Deneme', '2026-07-02'));
    await attendance.save(ind('w1', 'Ahmet', '2026-07-02'));
    advances = FakeAdvanceRepository([
      adv('a1', 'wTest', 'Hüsrev Deneme'),
      adv('a2', 'w1', 'Ahmet'),
    ]);
    workers = FakeWorkerRepository();
    await workers.add(w('w1', 'Ahmet'));
    await workers.add(w('wTest', 'Hüsrev Deneme', active: false));

    return ProviderScope(
      overrides: [
        attendanceRepositoryProvider.overrideWithValue(attendance),
        advanceRepositoryProvider.overrideWithValue(advances),
        workerRepositoryProvider.overrideWithValue(workers),
        canSeeMoneyProvider.overrideWithValue(canSeeMoney),
      ],
      child: const MaterialApp(
        locale: Locale('tr', 'TR'),
        supportedLocales: [Locale('tr', 'TR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WorkersScreen(),
      ),
    );
  }

  /// Pasif bölüm katlanmış açılır → içindeki karta erişmek için önce açılır.
  Future<void> openPassive(WidgetTester tester) async {
    await tester.tap(find.textContaining('Pasif İşçiler'));
    await tester.pumpAndSettle();
  }

  /// Kartı sola kaydırır ve açılan çöp kutusu butonuna basar.
  Future<void> swipeDelete(WidgetTester tester, String name) async {
    await tester.drag(find.text(name), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_forever).last);
    await tester.pumpAndSettle();
  }

  testWidgets('aktif işçide kaydırma yalnız pasife alır (kayıtlar durur)',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();

    await tester.drag(find.text('Ahmet'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('İşçiyi kaldır'), findsOneWidget);
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();

    // Yalnız `active` işareti değişti; işçi dokümanı duruyor.
    expect(workers.all.length, 2);
    expect(workers.all.firstWhere((x) => x.id == 'w1').active, isFalse);
    expect(attendance.count, 3);
    expect(advances.count, 2);
  });

  testWidgets('pasif işçide kaydırma → işçi VE tüm kayıtları silinir',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openPassive(tester);

    await swipeDelete(tester, 'Hüsrev Deneme');
    expect(find.text('Kalıcı olarak sil'), findsOneWidget);
    await tester.tap(find.text('Kalıcı Sil'));
    await tester.pumpAndSettle();

    // İşçi listeden, yoklama ve avans kayıtları da veriden gitti.
    expect(workers.all.map((x) => x.id).toList(), ['w1']);
    expect(attendance.all.map((r) => r.workerId).toList(), ['w1']);
    expect(advances.all.map((a) => a.id).toList(), ['a2']);
    expect(find.text('Hüsrev Deneme'), findsNothing);
    // Silinen kayıt sayısı kullanıcıya özetlenir.
    expect(find.textContaining('2 yoklama, 1 avans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kalıcı silmede vazgeçilirse hiçbir şey silinmez',
      (tester) async {
    await tester.pumpWidget(await buildApp());
    await tester.pumpAndSettle();
    await openPassive(tester);

    await swipeDelete(tester, 'Hüsrev Deneme');
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(workers.all.length, 2);
    expect(attendance.count, 3);
    expect(advances.count, 2);
  });

  testWidgets('para kısıtlı hesapta kalıcı silme yok (pasife alma var)',
      (tester) async {
    await tester.pumpWidget(await buildApp(canSeeMoney: false));
    await tester.pumpAndSettle();
    await openPassive(tester);

    // Pasif işçide kaydırma bir şey açmaz → geçmiş silinemez.
    await tester.drag(find.text('Hüsrev Deneme'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_forever), findsNothing);

    // Aktif işçide soft-delete hâlâ açık.
    await tester.drag(find.text('Ahmet'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(attendance.count, 3);
    expect(advances.count, 2);
  });
}
