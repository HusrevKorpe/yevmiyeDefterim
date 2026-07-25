import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/advances/application/settlement_groups.dart';
import 'package:yevmiye_defterim/features/advances/data/advance.dart';

/// "Hesap görüldü" ile kapatılmış bir avans (kapanış tarihi [settleDate],
/// olay kimliği [uid]). Grup sırası ve geri-alınabilirlik kapanış tarihinden
/// türetilir; avansın kendi [date]'i alakasız.
Advance settled(String id, String workerId, String settleDate, {String? uid}) =>
    Advance(
      id: id,
      workerId: workerId,
      workerName: workerId,
      amountKurus: 10000,
      date: '2026-01-01',
      settledPayrollId: Advance.manualSettlementId(settleDate, uid),
    );

void main() {
  test('aynı işçi çok kapanış: yalnız EN SON kapanış geri alınabilir', () {
    final groups = buildSettlementGroups([
      settled('a1', 'wA', '2026-07-10', uid: 'evt1'),
      settled('a2', 'wA', '2026-07-13', uid: 'evt2'),
    ]);
    expect(groups.length, 2);
    expect(groups.first.settledDate, '2026-07-13'); // en yeni önce sıralı
    expect(groups.first.reopenable, isTrue);
    expect(groups.last.settledDate, '2026-07-10');
    expect(groups.last.reopenable, isFalse,
        reason: 'eski kapanışı geri almak devir zincirini bozar → net bakiye çift');
  });

  test('tek kapanış geri alınabilir', () {
    final groups =
        buildSettlementGroups([settled('a1', 'wA', '2026-07-10', uid: 'e1')]);
    expect(groups.single.reopenable, isTrue);
  });

  test('farklı işçiler bağımsız: her birinin en sonu geri alınabilir', () {
    final groups = buildSettlementGroups([
      settled('a1', 'wA', '2026-07-10', uid: 'e1'),
      settled('a2', 'wB', '2026-07-05', uid: 'e2'),
    ]);
    expect(groups.length, 2);
    expect(groups.every((g) => g.reopenable), isTrue);
  });

  test('aynı kapanış olayının birden çok avansı tek grupta toplanır', () {
    final groups = buildSettlementGroups([
      settled('a1', 'wA', '2026-07-10', uid: 'e1'),
      settled('a2', 'wA', '2026-07-10', uid: 'e1'),
    ]);
    expect(groups.single.advances.length, 2);
    expect(groups.single.reopenable, isTrue);
  });

  test('hakediş mahsubu (manuel olmayan kapanış) gruplara girmez', () {
    const legacy = Advance(
      id: 'a1',
      workerId: 'wA',
      workerName: 'wA',
      amountKurus: 10000,
      date: '2026-07-10',
      settledPayrollId: 'p-uuid-123', // 'hesap-goruldu:' öneki yok
    );
    expect(buildSettlementGroups([legacy]), isEmpty);
  });
}
