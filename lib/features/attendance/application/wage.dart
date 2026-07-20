/// Ücret çözümü — saf fonksiyon (kural §4, Firestore'suz → unit test).
///
/// `override ?? (erkek ? maleWage : femaleWage)`. Sonuç yoklama anında
/// `wageSnapshotKurus` olarak donar; geçmiş ücret yeniden türetilmez.
library;

import '../../workers/data/worker.dart';

/// İşçinin o günkü günlük ücretini (kuruş) çözer.
int resolveWageKurus({
  required Gender gender,
  int? overrideKurus,
  required int maleWageKurus,
  required int femaleWageKurus,
}) {
  if (overrideKurus != null) return overrideKurus;
  return gender == Gender.male ? maleWageKurus : femaleWageKurus;
}
