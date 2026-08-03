/// Ay gruplama saf fonksiyonu — Giderler listesinin "Temmuz 2026" ayraçları.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:yevmiye_defterim/core/constants/categories.dart';
import 'package:yevmiye_defterim/features/ledger/application/ledger_month_groups.dart';
import 'package:yevmiye_defterim/features/ledger/data/ledger_entry.dart';

LedgerEntry entry(
  String id,
  String date,
  int amountKurus, {
  String kind = LedgerKind.gider,
}) =>
    LedgerEntry(
      id: id,
      category: LedgerCategory.genel,
      amountKurus: amountKurus,
      date: date,
      source: LedgerSource.manual,
      kind: kind,
    );

void main() {
  test('boş liste → grup yok', () {
    expect(groupLedgerByMonth(const []), isEmpty);
  });

  test('aylara böler; gruplar ve grup içi kayıtlar yeni→eski sıralı', () {
    // Bilerek karışık sırada verilir: sıralamayı fonksiyon garantiler.
    final groups = groupLedgerByMonth([
      entry('t1', '2026-07-05', 1000),
      entry('a1', '2026-08-03', 2000),
      entry('t2', '2026-07-28', 3000),
      entry('h1', '2026-06-30', 4000),
    ]);

    expect(groups.map((g) => g.monthIso).toList(), ['2026-08', '2026-07', '2026-06']);
    expect(groups[1].entries.map((e) => e.id).toList(), ['t2', 't1']);
  });

  test('yıl atlayan aylar doğru sırada (Ocak 2027 → Aralık 2026)', () {
    final groups = groupLedgerByMonth([
      entry('d1', '2026-12-31', 1000),
      entry('o1', '2027-01-02', 2000),
    ]);

    expect(groups.map((g) => g.monthIso).toList(), ['2027-01', '2026-12']);
  });

  test('ay toplamı tahsilatı SAYMAZ, ayrı alanda tutar (kural §6)', () {
    final groups = groupLedgerByMonth([
      entry('g1', '2026-07-10', 15000),
      entry('g2', '2026-07-11', 5000),
      entry('th1', '2026-07-12', 100000, kind: LedgerKind.tahsilat),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.expenseKurus, 20000);
    expect(groups.single.tahsilatKurus, 100000);
    expect(groups.single.entries, hasLength(3));
  });

  test('bozuk tarihli kayıt ekranı çökertmez, kendi grubunda toplanır', () {
    final groups = groupLedgerByMonth([
      entry('ok', '2026-07-10', 1000),
      entry('bozuk', '', 2000),
    ]);

    expect(groups.map((g) => g.monthIso), containsAll(<String>['2026-07', '']));
    expect(groups.fold<int>(0, (sum, g) => sum + g.expenseKurus), 3000);
  });
}
