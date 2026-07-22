/// Tarla yönetim ekranı widget testi — ekle / yeniden adlandır / soft-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yevmiye_defterim/features/attendance/application/fields_providers.dart';
import 'package:yevmiye_defterim/features/attendance/data/field.dart';
import 'package:yevmiye_defterim/features/attendance/presentation/fields_screen.dart';

import '../../support/fake_field_repository.dart';

void main() {
  (Widget, FakeFieldRepository) buildApp({List<Field> seed = const []}) {
    final repo = FakeFieldRepository(seed);
    final app = ProviderScope(
      overrides: [fieldRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: FieldsScreen()),
    );
    return (app, repo);
  }

  testWidgets('tarla yokken boş durum görünür', (tester) async {
    final (app, _) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Tarla eklenmemiş'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB → diyalogla tarla eklenir ve listede görünür',
      (tester) async {
    final (app, repo) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tarla Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Aşağı Tarla  ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.all.single.name, 'Aşağı Tarla'); // kırpılmış yazıldı
    expect(repo.all.single.active, isTrue);
    expect(find.text('Aşağı Tarla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boş ad kaydedilmez', (tester) async {
    final (app, repo) = buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tarla Ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet')); // ad girilmedi
    await tester.pumpAndSettle();

    expect(repo.all, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('satıra dokun → ad değiştirilir (aynı kayıt güncellenir)',
      (tester) async {
    const tarla = Field(id: 't1', name: 'Bahçe');
    final (app, repo) = buildApp(seed: const [tarla]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bahçe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yukarı Bağ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repo.all.single.id, 't1'); // yeni kayıt açılmadı
    expect(repo.all.single.name, 'Yukarı Bağ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sil → onayla → soft-delete (listeden düşer, kayıt durur)',
      (tester) async {
    const tarla = Field(id: 't1', name: 'Bahçe');
    final (app, repo) = buildApp(seed: const [tarla]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last); // diyalogdaki onay butonu
    await tester.pumpAndSettle();

    expect(repo.all.single.active, isFalse); // soft-delete (kural §5)
    expect(find.text('Tarla eklenmemiş'), findsOneWidget); // listeden düştü
    expect(tester.takeException(), isNull);
  });
}
