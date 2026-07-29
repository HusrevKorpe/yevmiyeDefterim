import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/workers/application/worker_search.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

Worker _w(
  String id,
  String name, {
  WorkerType type = WorkerType.gundelik,
  Gender gender = Gender.male,
  bool active = true,
}) =>
    Worker(id: id, name: name, type: type, gender: gender, active: active);

List<String> _names(List<Worker> list) => [for (final w in list) w.name];

void main() {
  final ahmet = _w('1', 'Ahmet Yılmaz', type: WorkerType.sabit);
  final mehmet = _w('2', 'Mehmet Kaya');
  final sukru = _w('3', 'Şükrü Demir');
  final zeynep = _w('4', 'Zeynep Aslan', gender: Gender.female);
  final elebasi = _w('5', 'Hasan Ekip', type: WorkerType.elebasi);
  final pasif = _w('6', 'Ahmet Çelik', active: false);
  final workers = [ahmet, mehmet, sukru, zeynep, elebasi, pasif];

  group('searchWorkers', () {
    test('boş sorgu listeyi olduğu gibi verir', () {
      expect(_names(searchWorkers(workers, '')), _names(workers));
      expect(_names(searchWorkers(workers, '   ')), _names(workers));
    });

    test('adın başı ile bulur', () {
      expect(_names(searchWorkers(workers, 'meh')), ['Mehmet Kaya']);
    });

    test('Türkçe harf yazmadan bulur', () {
      expect(_names(searchWorkers(workers, 'sukru')), ['Şükrü Demir']);
    });

    test('yanlış yazınca da benzeyeni getirir', () {
      expect(_names(searchWorkers(workers, 'mehmed')), ['Mehmet Kaya']);
      expect(_names(searchWorkers(workers, 'zeynap')), ['Zeynep Aslan']);
      expect(_names(searchWorkers(workers, 'sukru demr')), ['Şükrü Demir']);
    });

    test('aynı ada sahip aktif işçi pasiften önce gelir', () {
      final found = searchWorkers(workers, 'ahmet');
      expect(_names(found), ['Ahmet Yılmaz', 'Ahmet Çelik']);
    });

    test('pasif işçi de bulunur (silinmiş sanılmasın)', () {
      expect(_names(searchWorkers(workers, 'celik')), ['Ahmet Çelik']);
    });

    test('alakasız sorgu boş sonuç', () {
      expect(searchWorkers(workers, 'traktör'), isEmpty);
    });

    test('tür ve cinsiyet etiketiyle de aranır', () {
      expect(_names(searchWorkers(workers, 'elebaşı')), ['Hasan Ekip']);
      expect(_names(searchWorkers(workers, 'kadın')), ['Zeynep Aslan']);
      expect(_names(searchWorkers(workers, 'sabit')), ['Ahmet Yılmaz']);
    });

    test('etiket eşleşmesi ad eşleşmesinin arkasında kalır', () {
      final byName = _w('7', 'Sabit Öz');
      final found = searchWorkers([...workers, byName], 'sabit');
      expect(found.first.name, 'Sabit Öz');
      expect(_names(found), contains('Ahmet Yılmaz'));
    });

    test('2 harflik etiket parçası tüm listeyi dökmez', () {
      // "el" → "Elebaşı" etiketini tetiklememeli (yalnız ad eşleşmesi).
      expect(searchWorkers(workers, 'el'), isNot(contains(elebasi)));
    });

    test('kaynak liste değiştirilmez', () {
      final copy = [...workers];
      searchWorkers(workers, 'ahmet');
      expect(_names(workers), _names(copy));
    });
  });
}
