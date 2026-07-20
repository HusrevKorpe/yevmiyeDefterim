/// Ana Sayfa "Bugün Özeti" sağlayıcısı (kural §7).
///
/// Bugünün yoklamasını işçi cinsiyetleriyle birleştirir. Cinsiyet yoklama
/// kaydında tutulmaz; işçi listesinden (workerId → Gender) çözülür. İşçi listesi
/// (cinsiyet haritası) yüklenene kadar EMIT ETMEZ → "6 işçi / 0 kadın" gibi
/// yanlış ara durum görünmez; onun yerine yükleniyor göstergesi kalır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import 'day_summary.dart';

/// Bugünün özeti (cinsiyet ayrıştırılmış). Seçili tarihten bağımsız.
final StreamProvider<DaySummary> todaySummaryProvider =
    StreamProvider<DaySummary>((ref) async* {
  // Cinsiyet haritasını kurmak için işçilerin ilk yüklenişini bekle (böylece
  // kadın/erkek sayıları hiç 0'dan başlamaz). Not: harita bu ilk anla dondurulur;
  // gün içinde işçi ekleme/düzenlemesi sonraki açılışta yansır (Ana Sayfa için
  // yeterli — reaktiflik gerekirse iki akış combineLatest ile birleştirilmeli).
  final workers = await ref.watch(workerRepositoryProvider).watchAll().first;
  final genderById = <String, Gender>{for (final w in workers) w.id: w.gender};

  yield* ref
      .watch(attendanceRepositoryProvider)
      .watchByDate(todayIso())
      .map((records) => summarizeDay(records, genderById: genderById));
});
