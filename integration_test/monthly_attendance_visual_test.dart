/// Görsel doğrulama: Aylık Yoklama cetveli (işçi × gün matrisi).
///
/// Donuk sol işçi sütunu + donuk gün başlığı + iki eksenli kaydırılan gövde.
/// Hücreler ✓/½/· ve elebaşı kişi sayısı; en sağda Toplam sütunu. Yoğun tablo
/// büyük sistem yazısında da okunaklı kalmalı (tablo içi ölçek 1.1'e sınırlı),
/// çevre öğeler (ay çubuğu, açıklama, özet) taşmamalı. `flutter test` gerçek font
/// metriklerini tam yakalamaz → simülatörde ekran görüntüsüyle doğrulanır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/theme.dart';
import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/attendance_record.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/monthly_attendance_screen.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_advance_repository.dart';
import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final month = currentMonthIso();
  String day(int d) => '$month-${d.toString().padLeft(2, '0')}';

  Worker w(String id, String name, WorkerType type, Gender gender,
          {int? headcount}) =>
      Worker(
        id: id,
        name: name,
        type: type,
        gender: gender,
        defaultHeadcount: headcount,
      );

  AttendanceRecord ind(Worker worker, int d, AttendanceStatus status,
          {int overtimeHours = 0}) =>
      AttendanceRecord.individual(
        id: '${day(d)}_${worker.id}',
        date: day(d),
        workerId: worker.id,
        workerName: worker.name,
        workerType: worker.type,
        status: status,
        wageSnapshotKurus: 200000,
        // Mesai girilen gün hücrede küçük saat üst simgesiyle çıkar ("✓2").
        overtimeHours: overtimeHours,
        overtimeRateSnapshotKurus: overtimeHours > 0 ? 10000 : 0,
      );

  AttendanceRecord crew(Worker worker, int d, int headcount) =>
      AttendanceRecord.crew(
        id: '${day(d)}_${worker.id}',
        date: day(d),
        workerId: worker.id,
        workerName: worker.name,
        headcount: headcount,
        crewRateSnapshotKurus: 150000,
      );

  final workers = <Worker>[
    w('m1', 'Ahmet Yılmaz', WorkerType.sabit, Gender.male),
    w('m2', 'Mehmet Demir', WorkerType.gundelik, Gender.male),
    w('m3', 'Ali Kaya', WorkerType.gundelik, Gender.male),
    w('f1', 'Fatma Şahin', WorkerType.sabit, Gender.female),
    w('f2', 'Ayşe Çelik', WorkerType.gundelik, Gender.female),
    w('f3', 'Zeynep Arslan', WorkerType.gundelik, Gender.female),
    w('e1', 'Hasan Usta', WorkerType.elebasi, Gender.male, headcount: 6),
    w('e2', 'Mustafa Usta', WorkerType.elebasi, Gender.male, headcount: 4),
  ];

  Future<ProviderScope> app({
    required double scale,
    bool dark = false,
  }) async {
    final workerRepo = FakeWorkerRepository();
    for (final worker in workers) {
      await workerRepo.add(worker);
    }

    final attRepo = FakeAttendanceRepository();
    // İlk 20 gün: bireyseller çoğunlukla tam, ara ara yarım/yok; elebaşılar
    // birkaç gün değişen kişi sayısıyla. Yatay + dikey kaydırmayı zorlar.
    for (var d = 1; d <= 20; d++) {
      for (final ind0 in workers.where((x) => x.type.isIndividual)) {
        final status = (d % 7 == 0)
            ? AttendanceStatus.absent
            : (d % 3 == 0 ? AttendanceStatus.half : AttendanceStatus.full);
        // Bazı günlerde mesai: hücredeki saat üst simgesi ve ay toplamına etkisi
        // yoğun tabloda da okunaklı kalmalı.
        final overtime = (d % 5 == 0 && status != AttendanceStatus.absent) ? 2 : 0;
        await attRepo.save(ind(ind0, d, status, overtimeHours: overtime));
      }
    }
    for (final d in const [2, 3, 5, 9, 12, 16, 19]) {
      await attRepo.save(crew(workers[6], d, 5 + (d % 3))); // Hasan Usta
      await attRepo.save(crew(workers[7], d, 3 + (d % 2))); // Mustafa Usta
    }

    // "Hesap görüldü": iki işçinin hesabı ayın içinde farklı günlerde kapandı →
    // cetvelde kapanış gününe kadarki günler yeşil banda döner, kapanış günü
    // sınır çizgisini taşır. Üçüncüsü (açık avans) BİLEREK işaretsiz kalır.
    final advRepo = FakeAdvanceRepository([
      Advance(
        id: 'adv-m2',
        workerId: 'm2',
        workerName: 'Mehmet Demir',
        amountKurus: 50000,
        date: day(3),
        // Kapanış ayın başında → sınır çizgisi ilk ekranda görünür.
        settledPayrollId: Advance.manualSettlementId(day(5)),
      ),
      Advance(
        id: 'adv-e1',
        workerId: 'e1',
        workerName: 'Hasan Usta',
        amountKurus: 80000,
        date: day(2),
        settledPayrollId: Advance.manualSettlementId(day(9)),
      ),
      Advance(
        id: 'adv-f2',
        workerId: 'f2',
        workerName: 'Ayşe Çelik',
        amountKurus: 30000,
        date: day(4),
      ),
    ]);

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider.overrideWithValue(attRepo),
        advanceRepositoryProvider.overrideWithValue(advRepo),
        // Tablo tutarları bu sağlayıcıya bağlı; override'sız kalınca auth →
        // Firebase'e uzanıp ekran hata durumuna düşüyor (bu test o yüzden
        // kırıktı). Testte "para görebilir" olarak sabitlenir.
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? buildDarkTheme() : buildAppTheme(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: child!,
        ),
        home: const MonthlyAttendanceScreen(),
      ),
    );
  }

  testWidgets('Aylık yoklama cetveli — matris + toplamlar, taşma yok',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(await app(scale: scale));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('monthly-attendance-x$scale');
    }

    // Elebaşının kapanışı (ayın 9'u) ilk ekranın dışında → gövdeyi yatay
    // kaydırıp o sınırı da görüntüle (donuk ad sütunu yerinde kalmalı).
    // Gövdenin yatay kaydırıcısı (başlıktakinden sonraki ikinci tanesi).
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(-150, 0));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('monthly-attendance-hesap-kesim');

    // Koyu temada da yeşil bant durum renklerini boğmamalı.
    await tester.pumpWidget(await app(scale: 1.0, dark: true));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('monthly-attendance-koyu');

    // Tablo iskeleti + özet görünür.
    expect(find.text('İşçi'), findsOneWidget);
    expect(find.text('Toplam'), findsOneWidget);
    expect(find.textContaining('Toplam işçilik'), findsOneWidget);
    expect(find.text('8 işçi'), findsOneWidget);

    // Hesabı görülen iki işçi: adlarının yanında onay + açıklama şeridinde
    // yeşil bant anlatımı.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.text('hesabı görüldü'), findsOneWidget);

    // Hard RenderFlex taşması olmamalı (herhangi bir ölçekte).
    expect(tester.takeException(), isNull);
  });
}
