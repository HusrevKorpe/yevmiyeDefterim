/// Görsel doğrulama: 2026-08-07 tarla / yapılan iş ayrımı.
///
/// İki ekran zorlanır:
///  1. Yönetim ekranı (/yoklama/tarlalar) — TEK sayfada üstte Tarlalar, altında
///     Yapılan İşler; her bölümün kendi "Ekle" düğmesi başlıkta.
///  2. Yoklama satırı — TARLA ve YAPILAN İŞ şeritleri alt alta.
///
/// Büyük sistem yazısında (x2.0) bölüm başlığı + "Ekle" düğmesi ve iki çip
/// şeridi taşmamalı (`flutter test` gerçek font metriklerini tam yakalamaz →
/// bu akış simülatörde ekran görüntüsüyle doğrulanır).
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
import 'package:yevmiye_defterim/features/attendance/presentation/plots_jobs_screen.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/widgets/tag_chips.dart';
import 'package:yevmiye_defterim/features/auth/application/user_access.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../test/support/fake_attendance_repository.dart';
import '../test/support/fake_job_repository.dart';
import '../test/support/fake_plot_repository.dart';
import '../test/support/fake_settings_repository.dart';
import '../test/support/fake_worker_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// iOS'ta ekran görüntüsü NATIVE alınır: uygulama yeni kurulduysa açılış
  /// (splash) görüntüsü birkaç yüz ms ekranda kalır ve kareye o girer. Kısa bir
  /// ısınma beklemesi Flutter yüzeyinin öne geçmesini garanti eder.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  // Uzun adlar bilerek: bölüm başlığı ve çip şeridi en sıkışık hâlinde görülsün.
  const plots = [
    Plot(id: 't1', name: 'Aşağı Tarla'),
    Plot(id: 't2', name: 'Değirmen Arkası Bağ'),
    Plot(id: 't3', name: 'Yukarı Kavaklık'),
  ];
  const jobs = [
    Job(id: 'i1', name: 'Çapa'),
    Job(id: 'i2', name: 'Sulama'),
    Job(id: 'i3', name: 'Budama'),
  ];

  final workers = <Worker>[
    const Worker(
      id: 'm1',
      name: 'Abdurrahman Küçükoğlu',
      type: WorkerType.gundelik,
      gender: Gender.male,
      dailyWageOverrideKurus: 200000,
    ),
    const Worker(
      id: 'e1',
      name: 'Usta Hüseyin',
      type: WorkerType.elebasi,
      gender: Gender.male,
      defaultHeadcount: 12,
      dailyWageOverrideKurus: 150000,
    ),
  ];

  // Tüm depolar her testte fake: yönetim ekranı worker/attendance'a dokunmaz
  // ama override'ları kurmak zararsız ve fonksiyonu tek imzada tutar.
  Future<Widget> wrap(Widget home, {required double scale}) async {
    final workerRepo = FakeWorkerRepository();
    for (final w in workers) {
      await workerRepo.add(w);
    }
    return ProviderScope(
        overrides: [
          plotRepositoryProvider.overrideWithValue(FakePlotRepository(plots)),
          jobRepositoryProvider.overrideWithValue(FakeJobRepository(jobs)),
          canSeeMoneyProvider.overrideWithValue(true),
          workerRepositoryProvider.overrideWithValue(workerRepo),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          settingsRepositoryProvider
              .overrideWithValue(FakeSettingsRepository()),
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
          home: home,
        ),
      );
  }

  testWidgets('Yönetim — tek sayfada Tarlalar üstte, Yapılan İşler altında',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(await wrap(const PlotsJobsScreen(), scale: scale));
      await settle(tester);

      expect(find.text('Tarlalar'), findsOneWidget);
      expect(find.text('Yapılan İşler'), findsOneWidget);
      expect(find.text('Tarla Ekle'), findsOneWidget);
      expect(find.text('İş Ekle'), findsOneWidget);

      // Tarlalar bölümü gerçekten YUKARIDA, işler AŞAĞIDA olmalı.
      expect(
        tester.getTopLeft(find.text('Tarlalar')).dy,
        lessThan(tester.getTopLeft(find.text('Yapılan İşler')).dy),
      );

      await binding.takeScreenshot('tarla-is-yonetim-x$scale');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Yoklama — tarla ve iş şeritleri alt alta, taşma yok',
      (tester) async {
    await initializeDateFormatting('tr_TR', null);

    for (final scale in const [1.0, 1.3, 2.0]) {
      await tester
          .pumpWidget(await wrap(const AttendanceScreen(), scale: scale));
      await settle(tester);

      // Tam seç → iki şerit birden açılır; ikisinden de birer seçim yap.
      await tester.tap(find.text('Tam').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aşağı Tarla').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çapa').first);
      await tester.pumpAndSettle();

      expect(find.byType(TagChips<Plot>), findsOneWidget);
      expect(find.byType(TagChips<Job>), findsOneWidget);
      // Tarla şeridi üstte, iş şeridi altında (yönetim ekranıyla aynı sıra).
      expect(
        tester.getTopLeft(find.byType(TagChips<Plot>)).dy,
        lessThan(tester.getTopLeft(find.byType(TagChips<Job>)).dy),
      );

      await binding.takeScreenshot('tarla-is-yoklama-x$scale');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Yoklama — elebaşı satırında da iki şerit çıkar', (tester) async {
    await initializeDateFormatting('tr_TR', null);

    await tester.pumpWidget(await wrap(const AttendanceScreen(), scale: 1.3));
    await settle(tester);

    // Elebaşı sekmesi (kişi sayısı önden dolu → şeritler zaten açık).
    await tester.tap(find.textContaining('Elebaşılar'));
    await tester.pumpAndSettle();

    expect(find.byType(TagChips<Plot>), findsOneWidget);
    expect(find.byType(TagChips<Job>), findsOneWidget);

    await tester.tap(find.text('Değirmen Arkası Bağ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budama').first);
    await tester.pumpAndSettle();

    await binding.takeScreenshot('tarla-is-elebasi-x1.3');
    expect(tester.takeException(), isNull);
  });
}
