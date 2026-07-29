/// Avans düzenleme ekranı — eşzamanlı SİLİNEN avansın "hortlaması" koruması.
///
/// Regresyon (review bug #2): update() `set(merge:true)` silinmiş dokümanı YENİDEN
/// yaratır. Başka cihaz avansı silmişken onu düzenleyip Kaydet'e basmak, silinen
/// avansı AÇIK avans olarak geri getirirdi (üstelik settledPayrollId yazılmadığından
/// kapalıysa bile açık doğardı). Artık currentRev==null → "Avans silinmiş" onayı
/// çıkar; Vazgeç yazmayı engeller (deponun settle/reopen'daki `_existingIds`
/// hayalet-korumasının düzenleme karşılığı — ledger_edit_screen ile aynı desen).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/advances/application/advance_providers.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';
import 'package:yevmiye_defterim/features/advances/presentation/advance_edit_screen.dart';
import 'package:yevmiye_defterim/features/workers/application/workers_providers.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

import '../../support/fake_advance_repository.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  const worker = Worker(
    id: 'w1',
    name: 'Ahmet',
    type: WorkerType.gundelik,
    gender: Gender.male,
    dailyWageOverrideKurus: 100000,
  );

  Advance adv(String id) => Advance(
        id: id,
        workerId: 'w1',
        workerName: 'Ahmet',
        amountKurus: 100000,
        date: '2026-07-10',
      );

  // Editör ayrı bir rotada açılır → kaydettikten sonra pop güvenli (altta rota var).
  Widget buildApp(FakeAdvanceRepository repo, Advance advance) => ProviderScope(
        overrides: [
          advanceRepositoryProvider.overrideWithValue(repo),
          workersStreamProvider.overrideWith((ref) => Stream.value([worker])),
        ],
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
                      builder: (_) => AdvanceEditScreen(advance: advance),
                    ),
                  ),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> openEditor(WidgetTester tester, FakeAdvanceRepository repo) async {
    await tester.pumpWidget(buildApp(repo, adv('a1')));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle(); // ekran açıldı + initState _loadBaseRev (rev=0)
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.widgetWithText(FilledButton, 'Kaydet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('silinmiş avans: "Avans silinmiş" onayı çıkar; Vazgeç hortlatmaz',
      (tester) async {
    final repo = FakeAdvanceRepository([adv('a1')]);
    await openEditor(tester, repo);

    await repo.delete('a1'); // başka cihaz avansı sildi → currentRev null döner
    await tapSave(tester);

    expect(find.text('Avans silinmiş'), findsOneWidget);
    expect(repo.count, 0, reason: 'onaydan önce yeniden yaratma yok');

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repo.count, 0, reason: 'Vazgeç → silinen avans geri gelmez');
  });

  testWidgets('silinmiş avans: "Yeniden Oluştur" onaylanınca yazma yapılır',
      (tester) async {
    final repo = FakeAdvanceRepository([adv('a1')]);
    await openEditor(tester, repo);

    await repo.delete('a1');
    await tapSave(tester);
    await tester.tap(find.text('Yeniden Oluştur'));
    await tester.pumpAndSettle();

    expect(repo.byId('a1'), isNotNull, reason: 'onay → bilinçli yeniden oluştur');
  });

  testWidgets('değişmemiş avans: onay çıkmaz, doğrudan kaydeder (yanlış alarm yok)',
      (tester) async {
    final repo = FakeAdvanceRepository([adv('a1')]); // rev=0 == baseRev
    await openEditor(tester, repo);

    await tapSave(tester);

    expect(find.text('Avans silinmiş'), findsNothing);
    expect(find.text('Avans değişmiş'), findsNothing);
    expect(repo.byId('a1'), isNotNull);
  });
}
