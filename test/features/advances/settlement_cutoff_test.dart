/// Son "Hesap görüldü" tarihi — net bakiyenin ve yevmiye zammının ortak sınırı.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/application/settlement_cutoff.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';

Advance _adv(String id, {String? settled, String workerId = 'w1'}) => Advance(
      id: id,
      workerId: workerId,
      workerName: 'Ali',
      amountKurus: 50000,
      date: '2026-08-01',
      settledPayrollId: settled,
    );

void main() {
  test('hiç kapanış yoksa null', () {
    expect(lastSettlementDate([_adv('a1'), _adv('a2')]), isNull);
  });

  test('en son kapanış tarihini döndürür', () {
    final out = lastSettlementDate([
      _adv('a1', settled: Advance.manualSettlementId('2026-07-10')),
      _adv('a2', settled: Advance.manualSettlementId('2026-08-02', 'uid-1')),
      _adv('a3', settled: Advance.manualSettlementId('2026-07-25')),
      _adv('a4'), // açık
    ]);

    expect(out, '2026-08-02');
  });

  test('hakediş mahsubu (elle olmayan kapanış) sayılmaz', () {
    expect(lastSettlementDate([_adv('a1', settled: 'payroll-uuid-123')]), isNull);
  });

  test('bozuk tarihli işaret yok sayılır', () {
    final out = lastSettlementDate([
      _adv('a1', settled: '${Advance.manualSettlementPrefix}bozuk'),
      _adv('a2', settled: Advance.manualSettlementId('2026-07-10')),
    ]);

    expect(out, '2026-07-10');
  });

  test('boş listede null', () {
    expect(lastSettlementDate(const []), isNull);
  });

  group('lastSettlementDateByWorker (cetvel renklendirmesi)', () {
    test('her işçi kendi son kapanışını alır', () {
      final out = lastSettlementDateByWorker([
        _adv('a1', workerId: 'w1', settled: Advance.manualSettlementId('2026-07-10')),
        _adv('a2', workerId: 'w1', settled: Advance.manualSettlementId('2026-08-02')),
        _adv('a3', workerId: 'w2', settled: Advance.manualSettlementId('2026-06-30')),
      ]);

      expect(out, {'w1': '2026-08-02', 'w2': '2026-06-30'});
    });

    test('kapanışı olmayan işçi haritada BULUNMAZ', () {
      final out = lastSettlementDateByWorker([
        _adv('a1', workerId: 'w1', settled: Advance.manualSettlementId('2026-07-10')),
        _adv('a2', workerId: 'w2'), // açık avans
      ]);

      expect(out.containsKey('w2'), isFalse);
      expect(out['w1'], '2026-07-10');
    });

    test('hakediş mahsubu ve bozuk tarih sayılmaz', () {
      final out = lastSettlementDateByWorker([
        _adv('a1', workerId: 'w1', settled: 'payroll-uuid-123'),
        _adv('a2', workerId: 'w1', settled: '${Advance.manualSettlementPrefix}bozuk'),
        _adv('a3', workerId: 'w1', settled: Advance.manualSettlementId('2026-07-10')),
      ]);

      expect(out, {'w1': '2026-07-10'});
    });

    test('boş listede boş harita', () {
      expect(lastSettlementDateByWorker(const []), isEmpty);
    });
  });
}
