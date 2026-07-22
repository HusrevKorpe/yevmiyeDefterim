import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/attendance/data/field.dart';

void main() {
  group('Field fromDoc / toMap', () {
    test('round-trip', () {
      const f = Field(id: 't1', name: 'Aşağı Tarla');
      expect(Field.fromDoc(f.id, f.toMap()), f);
    });

    test('eksik/bozuk alanlar güvenli varsayılana düşer', () {
      final f = Field.fromDoc('t1', null);
      expect(f.name, '');
      expect(f.active, isTrue); // varsayılan aktif
    });

    test('ad kırpılır, active okunur', () {
      final f = Field.fromDoc('t1', {'name': '  Yukarı Bağ  ', 'active': false});
      expect(f.name, 'Yukarı Bağ');
      expect(f.active, isFalse);
    });
  });

  test('compareFields: ada göre, büyük/küçük harf duyarsız', () {
    final list = [
      const Field(id: '1', name: 'zeytinlik'),
      const Field(id: '2', name: 'Aşağı Tarla'),
      const Field(id: '3', name: 'bahçe'),
    ]..sort(compareFields);
    expect(list.map((f) => f.name).toList(),
        ['Aşağı Tarla', 'bahçe', 'zeytinlik']);
  });
}
