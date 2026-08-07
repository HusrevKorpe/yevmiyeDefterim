import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/data/job.dart';
import 'package:yevmiye_defterim/features/attendance/data/plot.dart';

void main() {
  group('Job fromDoc / toMap', () {
    test('round-trip', () {
      const f = Job(id: 't1', name: 'Aşağı Tarla');
      expect(Job.fromDoc(f.id, f.toMap()), f);
    });

    test('eksik/bozuk alanlar güvenli varsayılana düşer', () {
      final f = Job.fromDoc('t1', null);
      expect(f.name, '');
      expect(f.active, isTrue); // varsayılan aktif
    });

    test('ad kırpılır, active okunur', () {
      final f = Job.fromDoc('t1', {'name': '  Yukarı Bağ  ', 'active': false});
      expect(f.name, 'Yukarı Bağ');
      expect(f.active, isFalse);
    });
  });

  test('compareJobs: ada göre, büyük/küçük harf duyarsız', () {
    final list = [
      const Job(id: '1', name: 'zeytinlik'),
      const Job(id: '2', name: 'Aşağı Tarla'),
      const Job(id: '3', name: 'bahçe'),
    ]..sort(compareJobs);
    expect(list.map((f) => f.name).toList(),
        ['Aşağı Tarla', 'bahçe', 'zeytinlik']);
  });

  // Tarla, iş ile birebir aynı sözleşmeye sahiptir ama AYRI bir tiptir: ikisi
  // birbirinin yerine geçemesin diye (yoklamada iki bağımsız şerit var).
  group('Plot fromDoc / toMap', () {
    test('round-trip', () {
      const p = Plot(id: 't1', name: 'Aşağı Tarla');
      expect(Plot.fromDoc(p.id, p.toMap()), p);
    });

    test('eksik/bozuk alanlar güvenli varsayılana düşer', () {
      final p = Plot.fromDoc('t1', null);
      expect(p.name, '');
      expect(p.active, isTrue);
    });

    test('ad kırpılır, active okunur', () {
      final p = Plot.fromDoc('t1', {'name': '  Yukarı Bağ  ', 'active': false});
      expect(p.name, 'Yukarı Bağ');
      expect(p.active, isFalse);
    });
  });

  test('comparePlots: ada göre, büyük/küçük harf duyarsız', () {
    final list = [
      const Plot(id: '1', name: 'zeytinlik'),
      const Plot(id: '2', name: 'Aşağı Tarla'),
      const Plot(id: '3', name: 'bahçe'),
    ]..sort(comparePlots);
    expect(list.map((p) => p.name).toList(),
        ['Aşağı Tarla', 'bahçe', 'zeytinlik']);
  });
}
