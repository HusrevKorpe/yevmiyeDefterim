import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/search/fuzzy_search.dart';

void main() {
  group('normalizeForSearch', () {
    test('Türkçe harfler ASCII karşılığına düşer', () {
      expect(normalizeForSearch('Şükrü Çağatay'), 'sukru cagatay');
      expect(normalizeForSearch('IĞDIR'), 'igdir');
      // Büyük İ ve küçük ı aynı harfe iner (dotless/dotted i tuzağı).
      expect(normalizeForSearch('İSMAİL'), normalizeForSearch('ismail'));
      expect(normalizeForSearch('Ilhan'), normalizeForSearch('İlhan'));
    });

    test('noktalama ve fazla boşluk temizlenir', () {
      expect(normalizeForSearch('  Ali-Veli   Oğlu. '), 'ali veli oglu');
      expect(normalizeForSearch('   '), '');
      expect(normalizeForSearch(''), '');
    });
  });

  group('editDistance', () {
    test('aynı metin => 0', () => expect(editDistance('ahmet', 'ahmet'), 0));

    test('tek harf hataları => 1', () {
      expect(editDistance('ahmet', 'ahmed'), 1); // değiştirme
      expect(editDistance('ahmet', 'ahmt'), 1); // eksik harf
      expect(editDistance('ahmet', 'ahmett'), 1); // fazla harf
      expect(editDistance('ahmte', 'ahmet'), 1); // komşu harf yer değiştirmesi
    });

    test('boş metin => diğerinin uzunluğu', () {
      expect(editDistance('', 'ali'), 3);
      expect(editDistance('ali', ''), 3);
    });

    test('maxDistance aşılırsa erken çıkar (sınır + 1 döner)', () {
      expect(editDistance('ahmet', 'zeynep', maxDistance: 2), greaterThan(2));
      // Sınır içindeyse gerçek değer döner.
      expect(editDistance('ahmet', 'ahmed', maxDistance: 1), 1);
      expect(editDistance('ali', 'veli', maxDistance: 2), 2);
    });
  });

  group('fuzzyScore — eşleşenler', () {
    test('birebir aynı en yüksek puan', () {
      expect(fuzzyScore('Ahmet Yılmaz', 'Ahmet Yılmaz'), 1000);
    });

    test('adın başını yazmak yeter', () {
      expect(fuzzyScore('ahm', 'Ahmet Yılmaz'), isNotNull);
      expect(fuzzyScore('yıl', 'Ahmet Yılmaz'), isNotNull); // soyadın başı
    });

    test('Türkçe harf yazmadan da bulunur', () {
      expect(fuzzyScore('sukru', 'Şükrü Demir'), isNotNull);
      expect(fuzzyScore('cagatay', 'Çağatay Öz'), isNotNull);
      expect(fuzzyScore('ismail', 'İsmail Kaya'), isNotNull);
    });

    test('yazım hatası affedilir', () {
      expect(fuzzyScore('ahmed', 'Ahmet Yılmaz'), isNotNull); // harf değişimi
      expect(fuzzyScore('ahmte', 'Ahmet Yılmaz'), isNotNull); // ters yazım
      expect(fuzzyScore('mehmed', 'Mehmet Ali Kaya'), isNotNull);
      expect(fuzzyScore('zeynap', 'Zeynep Demir'), isNotNull);
      expect(fuzzyScore('yilmz', 'Ahmet Yılmaz'), isNotNull); // soyadda hata
    });

    test('kelime sırası önemsiz', () {
      expect(fuzzyScore('yilmaz ahmet', 'Ahmet Yılmaz'), isNotNull);
    });

    test('baş harfler ve harf sırası', () {
      expect(fuzzyScore('ay', 'Ahmet Yılmaz'), isNotNull); // baş harfler
      expect(fuzzyScore('mhmt', 'Mehmet Kaya'), isNotNull); // sesli harfsiz
    });

    test('boşluk/noktalama farkı engel değil', () {
      expect(fuzzyScore('  AHMET  ', 'ahmet yılmaz'), isNotNull);
      expect(fuzzyScore('aliveli', 'Ali-Veli'), isNotNull);
    });
  });

  group('fuzzyScore — eşleşmeyenler', () {
    test('alakasız metin null döner', () {
      expect(fuzzyScore('zeynep', 'Ahmet Yılmaz'), isNull);
      expect(fuzzyScore('traktör', 'Mehmet Kaya'), isNull);
    });

    test('çok kısa sorguda tolerans yok (gürültü olmasın)', () {
      expect(allowedTypos(2), 0);
      expect(fuzzyScore('zx', 'Ahmet'), isNull);
    });

    test('tek harf yalnız baştan eşleşir (içinde geçen sayılmaz)', () {
      expect(fuzzyScore('a', 'Ahmet Yılmaz'), isNotNull); // adın başı
      expect(fuzzyScore('y', 'Ahmet Yılmaz'), isNotNull); // soyadın başı
      expect(fuzzyScore('m', 'Ahmet Yılmaz'), isNull); // ortada geçiyor
    });

    test('benzer ama farklı adlar karışmaz', () {
      expect(fuzzyScore('mehmet', 'Ahmet Yılmaz'), isNull);
      expect(fuzzyScore('hasan', 'Hüseyin Kaya'), isNull);
    });

    test('boş sorgu/metin null', () {
      expect(fuzzyScore('', 'Ahmet'), isNull);
      expect(fuzzyScore('ahmet', ''), isNull);
      expect(fuzzyScore('...', 'Ahmet'), isNull);
    });
  });

  group('fuzzyScore — sıralama (iyi eşleşme önde)', () {
    test('tam ad > kelime başı > içinde geçen > hatalı yazım', () {
      final exact = fuzzyScore('ahmet', 'Ahmet')!;
      final wordStart = fuzzyScore('ahmet', 'Veli Ahmetoğlu')!;
      final contains = fuzzyScore('hmet', 'Ahmet Yılmaz')!;
      final typo = fuzzyScore('ahmed', 'Ahmet Yılmaz')!;
      expect(exact, greaterThan(wordStart));
      expect(wordStart, greaterThan(contains));
      expect(contains, greaterThan(typo));
    });

    test('adın başı, ikinci kelimenin başından önce gelir', () {
      expect(
        fuzzyScore('ali', 'Ali Yılmaz')!,
        greaterThan(fuzzyScore('ali', 'Veli Ali')!),
      );
    });
  });
}
