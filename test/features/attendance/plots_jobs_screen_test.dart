/// Tarla ve İş yönetim ekranı widget testi — tek sayfa, iki bölüm.
///
/// Sayfa üstte Tarlalar, altında Yapılan İşler bölümünü aynı kaydırma akışında
/// gösterir; her bölümün kendi "Ekle" düğmesi vardır. İki liste ayrı Firestore
/// koleksiyonundan gelir → biri diğerini etkilemez (bu dosyanın asıl sözleşmesi).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yevmiye_defterim/features/attendance/application/jobs_providers.dart';
import 'package:yevmiye_defterim/features/attendance/application/plots_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/job.dart';
import 'package:yevmiye_defterim/features/attendance/data/plot.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/plots_jobs_screen.dart';

import '../../support/fake_job_repository.dart';
import '../../support/fake_plot_repository.dart';

void main() {
  (Widget, FakePlotRepository, FakeJobRepository) buildApp({
    List<Plot> plots = const [],
    List<Job> jobs = const [],
  }) {
    final plotRepo = FakePlotRepository(plots);
    final jobRepo = FakeJobRepository(jobs);
    final app = ProviderScope(
      overrides: [
        plotRepositoryProvider.overrideWithValue(plotRepo),
        jobRepositoryProvider.overrideWithValue(jobRepo),
      ],
      child: const MaterialApp(home: PlotsJobsScreen()),
    );
    return (app, plotRepo, jobRepo);
  }

  testWidgets('iki bölüm de görünür; boşken kendi ipucunu gösterir',
      (tester) async {
    final (app, _, _) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Tarlalar'), findsOneWidget);
    expect(find.text('Yapılan İşler'), findsOneWidget);
    expect(find.textContaining('Henüz tarla eklenmedi'), findsOneWidget);
    expect(find.textContaining('Henüz iş eklenmedi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Tarla Ekle" yalnız tarla listesine yazar', (tester) async {
    final (app, plotRepo, jobRepo) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tarla Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Aşağı Tarla  ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(plotRepo.all.single.name, 'Aşağı Tarla'); // kırpılmış yazıldı
    expect(plotRepo.all.single.active, isTrue);
    // Diğer liste kirlenmedi: iki koleksiyon bağımsızdır.
    expect(jobRepo.all, isEmpty);
    expect(find.text('Aşağı Tarla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"İş Ekle" yalnız iş listesine yazar', (tester) async {
    final (app, plotRepo, jobRepo) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('İş Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Çapa');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(jobRepo.all.single.name, 'Çapa');
    expect(plotRepo.all, isEmpty);
    expect(find.text('Çapa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boş ad kaydedilmez', (tester) async {
    final (app, plotRepo, _) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tarla Ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet')); // ad girilmedi
    await tester.pumpAndSettle();

    expect(plotRepo.all, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('satıra dokun → ad değiştirilir (aynı kayıt güncellenir)',
      (tester) async {
    final (app, plotRepo, _) =
        buildApp(plots: const [Plot(id: 't1', name: 'Bahçe')]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bahçe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yukarı Bağ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(plotRepo.all.single.id, 't1'); // yeni kayıt açılmadı
    expect(plotRepo.all.single.name, 'Yukarı Bağ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tarlayı sil → onayla → soft-delete (yalnız o bölüm etkilenir)',
      (tester) async {
    final (app, plotRepo, jobRepo) = buildApp(
      plots: const [Plot(id: 't1', name: 'Bahçe')],
      jobs: const [Job(id: 'i1', name: 'Çapa')],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // İlk "Sil" tarla bölümünün satırıdır (tarlalar üstte).
    await tester.tap(find.byTooltip('Sil').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last); // diyalogdaki onay butonu
    await tester.pumpAndSettle();

    expect(plotRepo.all.single.active, isFalse); // soft-delete (kural §5)
    expect(find.textContaining('Henüz tarla eklenmedi'), findsOneWidget);
    // İş listesi dokunulmadan durur.
    expect(jobRepo.all.single.active, isTrue);
    expect(find.text('Çapa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('işi sil → onayla → soft-delete', (tester) async {
    final (app, plotRepo, jobRepo) = buildApp(
      plots: const [Plot(id: 't1', name: 'Bahçe')],
      jobs: const [Job(id: 'i1', name: 'Çapa')],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sil').last); // iş bölümündeki satır
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();

    expect(jobRepo.all.single.active, isFalse);
    expect(plotRepo.all.single.active, isTrue);
    expect(find.textContaining('Henüz iş eklenmedi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
