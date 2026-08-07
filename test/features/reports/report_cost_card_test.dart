/// Rapor'daki tarla ÖZET kartı — bakışta özet + sayfaya götürmesi.
///
/// Döküm (satır içeriği, işçi kırılımı) artık `field_cost_list_test.dart`'ta;
/// burada aranan şey kartın toplamı/sayıları doğru yazması ve dokununca
/// tarla sayfasını açan geri çağrıyı tetiklemesi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:yevmiye_defterim/features/reports/application/work_cost.dart';
import 'package:yevmiye_defterim/features/reports/presentation/widgets/report_cost_card.dart';

import 'work_cost_fixtures.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Widget app(List<WorkCost> costs, {VoidCallback? onTap}) => MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: ListView(
            children: [
              ReportCostCard(
                costs: costs,
                kind: CostGroupKind.plot,
                onTap: onTap ?? () {},
              ),
            ],
          ),
        ),
      );

  testWidgets('özet: toplam tutar, tarla sayısı ve yevmiye', (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));

    expect(find.text('Tarla / İş Maliyeti'), findsOneWidget);
    // Kalıntı satır ("seçilmemiş") tarla sayılmaz; yevmiyesi toplama girer.
    expect(find.text('1 tarla • 3,5 yevmiye'), findsOneWidget);
    // 5.000 + 2.000 = 7.000
    expect(find.textContaining('7.000,00'), findsOneWidget);
  });

  testWidgets('en pahalı tarlalar payıyla listelenir', (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));

    expect(find.text('Dere Tarlası'), findsOneWidget);
    expect(find.text('%71'), findsOneWidget); // 5.000 / 7.000
    expect(find.text(kUnassignedPlotLabel), findsOneWidget);
  });

  testWidgets('oran şeridi gerçekten çizilir', (tester) async {
    await tester.pumpWidget(app(const [dere, bos]));

    // Her tutarlı satır bir dilim. Şeridin yüksekliği 0 olursa (Row'da çapraz
    // eksen gevşek kalırsa) kart sessizce boş görünür → burada kilitli.
    final slices = find.descendant(
      of: find.byType(ReportCostCard),
      matching: find.byType(ColoredBox),
    );
    expect(slices, findsNWidgets(2));
    expect(tester.getSize(slices.first).height, 8);
    // 5.000 / 7.000 ≈ %71 → ilk dilim ikinciden belirgin geniş.
    expect(tester.getSize(slices.first).width,
        greaterThan(tester.getSize(slices.last).width));
  });

  testWidgets('karta dokununca tarla sayfası açılır', (tester) async {
    var opened = 0;
    await tester.pumpWidget(app(const [dere, bos], onTap: () => opened++));

    await tester.tap(find.text('Tarla / İş Maliyeti'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });
}
