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

/// Mesai (fazla çalışma) SAAT ücretini (kuruş) çözer: `işçinin kendi ücreti ??
/// herkes için geçerli genel ücret`.
///
/// Yevmiyenin TERSİ yönde çalışır (bilerek): mesai ücreti sahada herkes için
/// aynıdır → tek kaynak Yönetim ekranındaki [AppSettings.overtimeHourlyKurus].
/// İşçi kartındaki alan yalnız İSTİSNA içindir (bir işçinin mesaisi farklıysa).
///
/// 0 ya da negatif işçi değeri "girilmemiş" sayılır → genele düşer: eski
/// kayıtlarda 0 kalmış olabilir ve bunu "mesai ücreti sıfır" diye okumak
/// kullanıcının genel ücretini sessizce yok sayardı. Sonuç yoklama anında
/// `overtimeRateSnapshotKurus` olarak donar (kural §4).
int resolveOvertimeRateKurus({
  int? workerHourlyKurus,
  required int defaultHourlyKurus,
}) {
  if (workerHourlyKurus != null && workerHourlyKurus > 0) {
    return workerHourlyKurus;
  }
  return defaultHourlyKurus < 0 ? 0 : defaultHourlyKurus;
}
