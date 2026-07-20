import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/settings/data/app_settings.dart';

void main() {
  group('AppSettings.fromMap', () {
    test('tam veri okunur', () {
      final s = AppSettings.fromMap({
        'defaultWageMaleKurus': 200000,
        'defaultWageFemaleKurus': 180000,
        'defaultCrewRateKurus': 150000,
      });
      expect(s.defaultWageMaleKurus, 200000);
      expect(s.defaultWageFemaleKurus, 180000);
      expect(s.defaultCrewRateKurus, 150000);
    });

    test('null veri => hepsi 0 (empty)', () {
      expect(AppSettings.fromMap(null), AppSettings.empty);
    });

    test('eksik alanlar 0 olur (offline kısmi doküman)', () {
      final s = AppSettings.fromMap({'defaultWageMaleKurus': 200000});
      expect(s.defaultWageMaleKurus, 200000);
      expect(s.defaultWageFemaleKurus, 0);
      expect(s.defaultCrewRateKurus, 0);
    });

    test('double gelen değer int kuruşa indirilir', () {
      final s = AppSettings.fromMap({'defaultWageMaleKurus': 200000.0});
      expect(s.defaultWageMaleKurus, 200000);
      expect(s.defaultWageMaleKurus, isA<int>());
    });
  });

  group('AppSettings.toMap round-trip', () {
    test('toMap -> fromMap aynı değeri verir', () {
      const s = AppSettings(
        defaultWageMaleKurus: 200000,
        defaultWageFemaleKurus: 180050,
        defaultCrewRateKurus: 150000,
      );
      expect(AppSettings.fromMap(s.toMap()), s);
    });
  });
}
