/// Kasa düzenleme ekranı — eşzamanlı SİLİNEN kaydın "hortlaması" koruması.
///
/// Regresyon: update() `set(merge:true)` silinmiş dokümanı YENİDEN yaratır. Başka
/// cihaz kaydı silmişken onu düzenleyip Kaydet'e basmak gideri geri getirirdi
/// (Kasa/rapor toplamlarına döner). Artık currentRev==null → "Kayıt silinmiş"
/// onayı çıkar; Vazgeç yazmayı engeller (avanstaki hayalet-korumasının karşılığı).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_providers.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_repository.dart';
import 'package:yevmiye_defterim/features/ledger/presentation/ledger_edit_screen.dart';

/// currentRev'i test kontrol eder ([rev] = null → doküman silinmiş sayılır).
/// update/add çağrıları [written]'a düşer → yazma yapıldı mı diye doğrulanır.
class _FakeLedgerRepo implements LedgerRepository {
  int? rev = 3;
  final List<LedgerEntry> written = [];

  @override
  Future<int?> currentRev(String id) async => rev;

  @override
  Future<void> update(LedgerEntry entry) async => written.add(entry);

  @override
  Future<void> add(LedgerEntry entry) async => written.add(entry);

  @override
  Future<void> delete(String id) async {}

  @override
  Stream<List<LedgerEntry>> watchAll() => Stream.value(const []);

  @override
  Stream<List<LedgerEntry>> watchByRange(String s, String e) =>
      Stream.value(const []);
}

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  LedgerEntry expense(String id, int amountKurus) => LedgerEntry(
        id: id,
        category: LedgerCategory.genel,
        amountKurus: amountKurus,
        date: '2026-07-15',
        source: LedgerSource.manual,
      );

  // Editör ayrı bir rotada açılır → kaydettikten sonra pop güvenli (altta rota var).
  Widget buildApp(_FakeLedgerRepo repo, LedgerEntry entry) => ProviderScope(
        overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LedgerEditScreen(entry: entry),
                    ),
                  ),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> openEditor(WidgetTester tester, _FakeLedgerRepo repo) async {
    await tester.pumpWidget(buildApp(repo, expense('e1', 150000)));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle(); // ekran açıldı + initState _loadBaseRev (rev=3)
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.widgetWithText(FilledButton, 'Kaydet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('silinmiş kayıt: "Kayıt silinmiş" onayı çıkar; Vazgeç yazmaz',
      (tester) async {
    final repo = _FakeLedgerRepo();
    await openEditor(tester, repo);

    repo.rev = null; // başka cihaz kaydı sildi
    await tapSave(tester);

    expect(find.text('Kayıt silinmiş'), findsOneWidget);
    expect(repo.written, isEmpty, reason: 'onaydan önce yazma yok');

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repo.written, isEmpty, reason: 'Vazgeç → hortlatma yok');
  });

  testWidgets('silinmiş kayıt: "Yeniden Oluştur" onaylanırsa yazma yapılır',
      (tester) async {
    final repo = _FakeLedgerRepo();
    await openEditor(tester, repo);

    repo.rev = null;
    await tapSave(tester);
    await tester.tap(find.text('Yeniden Oluştur'));
    await tester.pumpAndSettle();

    expect(repo.written.single.id, 'e1', reason: 'onay → bilinçli yeniden oluştur');
  });

  testWidgets('değişmemiş kayıt: onay çıkmaz, doğrudan kaydeder (yanlış alarm yok)',
      (tester) async {
    final repo = _FakeLedgerRepo(); // rev=3 == baseRev
    await openEditor(tester, repo);

    await tapSave(tester);

    expect(find.text('Kayıt silinmiş'), findsNothing);
    expect(find.text('Kayıt değişmiş'), findsNothing);
    expect(repo.written.single.id, 'e1');
  });
}
