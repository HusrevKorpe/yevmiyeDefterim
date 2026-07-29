import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/core/date/app_date.dart';
import 'package:yevmiye_defterim/features/attendance/application/attendance_providers.dart';

/// Gece yarısı devri (bkz. MainShell yaşam döngüsü): uygulama arka planda kalıp
/// ertesi gün öne alınınca yoklama seçili günü, kullanıcı elle başka güne
/// gitmediyse yeni güne kaymalı; elle seçilmiş gün korunmalı.
void main() {
  test('kullanıcı "bugün"deyken (seçili == önceki gün) yeni güne kayar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // "Dün" açık gibi davran: seçili gün önceki güne eşit.
    const previousDay = '2020-01-01';
    container.read(selectedDateProvider.notifier).set(previousDay);

    container.read(selectedDateProvider.notifier).rolloverIfOnDay(previousDay);

    expect(container.read(selectedDateProvider), todayIso());
  });

  test('elle seçilmiş gün (seçili != önceki gün) devirde korunur', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const manualDay = '2019-06-06';
    const previousDay = '2020-01-01';
    container.read(selectedDateProvider.notifier).set(manualDay);

    container.read(selectedDateProvider.notifier).rolloverIfOnDay(previousDay);

    // Kullanıcı bilinçli olarak başka güne gitmiş → dokunulmaz.
    expect(container.read(selectedDateProvider), manualDay);
  });
}
