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

  test('AYNI GÜN zincir: yalnız devri kapatan (son) kapanış geri alınabilir', () {
    // C1 (u1) A1'i kapatır → devir kaydı (devir-u1-x) oluşur.
    // Aynı gün C2 (u2) o devir kaydını da kapatır (zincir).
    // İkisinin de tarihi aynı (07-13) → yalnız tarihe bakınca ikisi de "en son"
    // görünürdü; devir zinciri C1'i "aşılmış" işaretler → yalnız C2 geri alınabilir.
    final groups = buildSettlementGroups([
      settled('a1', 'wA', '2026-07-13', uid: 'u1'),
      settled(Advance.carryoverId('u1', 'x'), 'wA', '2026-07-13', uid: 'u2'),
    ]);
    expect(groups.length, 2);
    final c1 = groups.firstWhere((g) => g.key == 'wA|u1');
    final c2 = groups.firstWhere((g) => g.key == 'wA|u2');
    expect(c2.reopenable, isTrue, reason: 'devri kapatan son olay geri alınabilir');
    expect(c1.reopenable, isFalse,
        reason: 'aşılmış (devri sonra kapatıldı) → geri almak çift devir yaratırdı');
  });

  test('AÇIK devir bırakan aynı-gün kapanış geri alınabilir kalır', () {
    // C1 (u1) A1'i kapatır, devir AÇIK kalır (yeniden kapatılmadı) → aşılmamış.
    // Devir kaydı settled listesinde YOK (açık) → C1 zincirin ucu, geri alınabilir.
    final groups = buildSettlementGroups([
      settled('a1', 'wA', '2026-07-13', uid: 'u1'),
    ]);
    expect(groups.single.reopenable, isTrue);
  });

  test('aynı gün BAĞIMSIZ iki kapanış: ikisi de geri alınabilir (zincir yok)', () {
    // İki ayrı avans, aynı gün ayrı olaylarla kapatıldı; aralarında devir yok →
    // birini geri almak diğerini etkilemez → ikisi de geri alınabilir kalmalı.
    final groups = buildSettlementGroups([
      settled('a1', 'wA', '2026-07-13', uid: 'u1'),
      settled('a2', 'wA', '2026-07-13', uid: 'u2'),
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
