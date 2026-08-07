/// Görsel doğrulama: yoklama satırındaki mesai (fazla çalışma) şeridi.
///
/// Tam/Yarım seçilince saat çipleri (1s·2s·3s·4s·Diğer) + altında "N saat mesai
/// · ₺X" özeti çıkar. Şerit tarla çiplerinin altına gelir; büyük sistem yazısında
/// da taşmamalı (`flutter test` gerçek font metriklerini tam yakalamaz → bu akış
/// simülatörde ekran görüntüsüyle doğrulanır — bkz. aylık tablo testi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/app/theme.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/jobs_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/plots_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/job.dart';
import 'package:yevmiye_defterim/features/attendance/data/plot.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/attendance_screen.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/widgets/overtime_chips.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/reports/application/period_report.dart';
import 'package:yevmiye_defterim/features/reports/presentation/widgets/report_labor_card.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/settings/presentation/settings_screen.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_job_repository.dart';
import '../test/support/fake_plot_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Uzun ad + tarla seçimi + mesai aynı satırda: en sıkışık hâli zorlar.
  final workers = <Worker>[
    const Worker(
      id: 'm1',
      name: 'Abdurrahman Küçükoğlu',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 200000,
      overtimeHourlyKurus: 10000, // ₺100/saat
    ),
    const Worker(
      id: 'm2',
      name: 'Ali Kaya',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 180000,
      // Mesai saat ücreti YOK → şerit "saat ücreti girilmemiş" uyarısı verir.
    ),
  ];

  Future<ProviderScope> app({required double scale}) async {
    final workerRepo = FakeWorkerRepository();
    for (final w in workers) {
      await workerRepo.add(w);
    }

    return ProviderScope(
      overrides: [
        workerRepositoryProvider.overrideWithValue(workerRepo),
        attendanceRepositoryProvider.overrideWithValue(FakeAttendanceRepository()),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        // En sıkışık hâl: satırın altında TARLA + YAPILAN İŞ + mesai şeritleri
        // alt alta gelir (2026-08-07 ayrımından sonra üç şerit birden).
        plotRepositoryProvider.overrideWithValue(FakePlotRepository(
          const [
            Plot(id: 't1', name: 'Aşağı Tarla'),
            Plot(id: 't2', name: 'Yukarı Bağ'),
          ],
        )),
        jobRepositoryProvider.overrideWithValue(FakeJobRepository(
          const [Job(id: 'i1', name: 'Çapa'), Job(id: 'i2', name: 'Sulama')],
        )),
        canSeeMoneyProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
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
        home: const AttendanceScreen(),
      ),
    );
  }

  testWidgets('Yoklama — mesai şeridi: saat çipleri + tutar özeti, taşma yok',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(await app(scale: scale));
      await tester.pumpAndSettle();

      // Mesaisi olan işçi: Tam → tarla + iş seç → 2 saat mesai.
      await tester.tap(find.text('Tam').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aşağı Tarla').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çapa').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 s').first);
      await tester.pumpAndSettle();

      // Saat ücreti girilmemiş işçi: Tam → 3 saat (uyarı satırı görünür).
      await tester.tap(find.text('Tam').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 s').last);
      await tester.pumpAndSettle();

      expect(find.byType(OvertimeChips), findsNWidgets(2));
      expect(find.textContaining('2 saat mesai'), findsOneWidget);
      expect(find.textContaining('saat ücreti girilmemiş'), findsOneWidget);

      await binding.takeScreenshot('overtime-yoklama-x$scale');

      // Hard RenderFlex taşması hiçbir ölçekte olmamalı.
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Rapor — İşçilik kartındaki mesai kırılım satırı taşmaz',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    const report = PeriodReport(
      startIso: '2026-07-01',
      endIso: '2026-07-31',
      grossLaborKurus: 12750000,
      overtimeKurus: 750000,
      overtimeHours: 75,
      advancesGivenKurus: 3200000,
    );

    for (final scale in const [1.0, 2.0]) {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
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
        home: const Scaffold(
          body: SafeArea(child: ReportLaborCard(report: report)),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mesai (75 saat)'), findsOneWidget);
      await binding.takeScreenshot('overtime-rapor-karti-x$scale');
      expect(tester.takeException(), isNull);
    }
  });

  // Mesai saat ücreti HERKES için tek yerden girilir: Yönetim ekranı. Uzun
  // açıklama metinleri + para alanı + düğme büyük yazıda da taşmamalı.
  testWidgets('Yönetim — mesai saat ücreti bölümü taşmaz', (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
            const AppSettings(
              defaultWageMaleKurus: 0,
              defaultWageFemaleKurus: 0,
              defaultCrewRateKurus: 0,
              overtimeHourlyKurus: 10000, // ₺100/saat — alana önden dolar
            ),
          )),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
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
          home: const SettingsScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Yönetim'), findsOneWidget);
      expect(find.text('100,00'), findsOneWidget); // kayıtlı ücret önden dolu
      await binding.takeScreenshot('overtime-yonetim-x$scale');
      expect(tester.takeException(), isNull);
    }
  });
}
