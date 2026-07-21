import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/money/money.dart';

void main() {
  group('parseTlToKurus — geçerli girişler', () {
    test('"2000" tam sayı TL => 200000 kuruş', () {
      expect(parseTlToKurus('2000'), 200000);
    });

    test('binlik ayırıcı nokta: "2.000" => 200000', () {
      expect(parseTlToKurus('2.000'), 200000);
    });

    test('virgül ondalık: "2000,50" => 200050', () {
      expect(parseTlToKurus('2000,50'), 200050);
    });

    test('nokta binlik + virgül ondalık: "2.000,50" => 200050', () {
      expect(parseTlToKurus('2.000,50'), 200050);
    });

    test('tek ondalık hane = 50 kuruş: "2000,5" => 200050', () {
      expect(parseTlToKurus('2000,5'), 200050);
    });

    test('büyük sayı çoklu binlik: "1.234.567,89" => 123456789', () {
      expect(parseTlToKurus('1.234.567,89'), 123456789);
    });

    test('sıfır: "0" => 0', () {
      expect(parseTlToKurus('0'), 0);
    });

    test('yalnız kuruş: "0,05" => 5', () {
      expect(parseTlToKurus('0,05'), 5);
    });

    test('lira kısmı olmadan: ",5" => 50', () {
      expect(parseTlToKurus(',5'), 50);
    });

    test('₺ sembolü ve boşluk temizlenir: "₺ 2.000,50" => 200050', () {
      expect(parseTlToKurus('₺ 2.000,50'), 200050);
    });

    test('baştaki/sondaki boşluk: "  2000  " => 200000', () {
      expect(parseTlToKurus('  2000  '), 200000);
    });

    test('sondaki virgül tolere edilir: "2000," => 200000', () {
      expect(parseTlToKurus('2000,'), 200000);
    });

    test('negatif: "-2000" => -200000', () {
      expect(parseTlToKurus('-2000'), -200000);
    });

    test('artı işareti: "+2000" => 200000', () {
      expect(parseTlToKurus('+2000'), 200000);
    });

    // Nokta ondalık düzeltmesi: sayısal klavye '.' üretince 100x/10x olmasın.
    test('nokta ondalık 2 hane: "1500.50" => 150050 (100x değil)', () {
      expect(parseTlToKurus('1500.50'), 150050);
    });

    test('nokta ondalık 1 hane: "0.5" => 50', () {
      expect(parseTlToKurus('0.5'), 50);
    });

    test('nokta ondalık: "2.00" => 200 (2,00 TL, binlik değil)', () {
      expect(parseTlToKurus('2.00'), 200);
    });

    test('nokta ondalık: "1.5" => 150', () {
      expect(parseTlToKurus('1.5'), 150);
    });

    // Binlik davranışı korunur: nokta sonrası tam 3 hane.
    test('nokta binlik korunur: "12.500" => 1250000', () {
      expect(parseTlToKurus('12.500'), 1250000);
    });

    test('çoklu nokta binlik (virgülsüz): "1.234.567" => 123456700', () {
      expect(parseTlToKurus('1.234.567'), 123456700);
    });
  });

  group('parseTlToKurus — geçersiz girişler (null)', () {
    test('boş string', () {
      expect(parseTlToKurus(''), isNull);
    });

    test('yalnız boşluk', () {
      expect(parseTlToKurus('   '), isNull);
    });

    test('harf içeren', () {
      expect(parseTlToKurus('abc'), isNull);
    });

    test('lira kısmı harf: "abc,50"', () {
      expect(parseTlToKurus('abc,50'), isNull);
    });

    test('2\'den fazla ondalık: "2000,555"', () {
      expect(parseTlToKurus('2000,555'), isNull);
    });

    test('3 haneli ondalık: "12,345"', () {
      expect(parseTlToKurus('12,345'), isNull);
    });

    test('birden fazla virgül: "2,00,0"', () {
      expect(parseTlToKurus('2,00,0'), isNull);
    });

    test('yalnız ayraç: ","', () {
      expect(parseTlToKurus(','), isNull);
    });

    test('yalnız işaret: "-"', () {
      expect(parseTlToKurus('-'), isNull);
    });

    test('tek nokta + 4 hane (ne binlik ne ondalık): "1.2345"', () {
      expect(parseTlToKurus('1.2345'), isNull);
    });

    test('hatalı binlik gruplaması: "1.23.456"', () {
      expect(parseTlToKurus('1.23.456'), isNull);
    });
  });

  group('halfWage — yarım gün (tam sayı bölme)', () {
    test('200000 => 100000', () => expect(halfWage(200000), 100000));
    test('150000 => 75000', () => expect(halfWage(150000), 75000));
    test('100000 => 50000', () => expect(halfWage(100000), 50000));
    test('0 => 0', () => expect(halfWage(0), 0));
    test('tek kuruş aşağı yuvarlanır: 1 => 0', () => expect(halfWage(1), 0));
  });

  group('formatKurus / formatKurusPlain — gösterim geri-dönüş (round-trip)', () {
    test('₺ formatı geri parse edilince aynı kuruşu verir (200050)', () {
      expect(parseTlToKurus(formatKurus(200050)), 200050);
    });

    test('₺ formatı geri parse edilince aynı kuruşu verir (200000)', () {
      expect(parseTlToKurus(formatKurus(200000)), 200000);
    });

    test('₺ formatı küçük kuruş (5) round-trip', () {
      expect(parseTlToKurus(formatKurus(5)), 5);
    });

    test('sembolsüz format büyük sayı round-trip', () {
      expect(parseTlToKurus(formatKurusPlain(123456789)), 123456789);
    });
  });
}
