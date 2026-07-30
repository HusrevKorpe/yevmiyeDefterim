import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/settings/application/settings_providers.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';
import 'package:yevmiye_defterim/features/settings/presentation/settings_screen.dart';

import '../../support/fake_settings_repository.dart';

/// Yönetim ekranı — mesai saat ücreti HERKES için tek yerden girilir.
void main() {
  const seeded = AppSettings(
    defaultWageMaleKurus: 200000,
    defaultWageFemaleKurus: 180000,
    defaultCrewRateKurus: 150000,
    overtimeHourlyKurus: 10000,
  );

  late FakeSettingsRepository repo;

  Future<void> pumpScreen(WidgetTester tester, AppSettings settings) async {
    repo = FakeSettingsRepository(settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('başlık "Yönetim" ve mesai bölümü görünür', (tester) async {
    await pumpScreen(tester, AppSettings.empty);

    expect(find.text('Yönetim'), findsOneWidget);
    expect(find.text('Mesai'), findsOneWidget);
    expect(find.text('Mesai saat ücreti'), findsOneWidget);
    // Eski bölümler yerinde kalmalı.
    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Veri Yedeği'), findsOneWidget);
  });

  testWidgets('kayıtlı ücret alana önden dolar', (tester) async {
    await pumpScreen(tester, seeded);

    // İşçi kartındaki ücret alanlarıyla aynı biçim (formatKurusPlain).
    expect(find.text('100,00'), findsOneWidget);
  });

  testWidgets('ücret girilip kaydedilince ayara yazılır (₺ → kuruş)',
      (tester) async {
    await pumpScreen(tester, AppSettings.empty);

    await tester.enterText(find.byType(TextFormField), '150');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.current.overtimeHourlyKurus, 15000);
    expect(find.textContaining('Mesai saat ücreti kaydedildi'), findsOneWidget);
  });

  // Ayar TEK config dokümanıdır: mesaiyi yazarken diğer alanların (yevmiye
  // varsayılanları) ezilmemesi gerekir.
  testWidgets('kaydetmek diğer ayar alanlarını ezmez', (tester) async {
    await pumpScreen(tester, seeded);

    await tester.enterText(find.byType(TextFormField), '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.current.overtimeHourlyKurus, 25000);
    expect(repo.current.defaultWageMaleKurus, 200000);
    expect(repo.current.defaultWageFemaleKurus, 180000);
    expect(repo.current.defaultCrewRateKurus, 150000);
  });

  testWidgets('alan boşaltılıp kaydedilince ücret temizlenir (0)',
      (tester) async {
    await pumpScreen(tester, seeded);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.current.overtimeHourlyKurus, 0);
  });

  // Harfler zaten alana girilemez (MoneyField filtresi); bozuk SAYI biçimi
  // (çift virgül) doğrulamadan dönmeli ve hiçbir şey yazılmamalı.
  testWidgets('geçersiz tutar kaydedilmez, hata gösterilir', (tester) async {
    await pumpScreen(tester, seeded);

    await tester.enterText(find.byType(TextFormField), '1,2,3');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.current.overtimeHourlyKurus, 10000, reason: 'yazma olmamalı');
    expect(find.textContaining('Geçerli tutar'), findsOneWidget);
  });
}
