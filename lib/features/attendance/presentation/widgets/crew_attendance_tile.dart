/// Elebaşı yoklama satırı — +/− kişi sayacı (kural §8, §10).
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../data/job.dart';
import '../../data/plot.dart';
import 'paid_lock_badge.dart';
import 'tag_chips.dart';

class CrewAttendanceTile extends StatelessWidget {
  const CrewAttendanceTile({
    super.key,
    required this.name,
    required this.headcount,
    required this.crewRateKurus,
    required this.onChanged,
    this.pending = false,
    this.maxHeadcount = 99,
    this.locked = false,
    this.showWage = true,
    this.plots = const [],
    this.plotId,
    this.plotName,
    this.onPlotChanged,
    this.jobs = const [],
    this.jobId,
    this.jobName,
    this.onJobChanged,
    this.onTap,
  });

  final String name;
  final int headcount;

  /// Ad/alt yazı alanına dokununca çağrılır (elebaşına avans ver ekranı açılır).
  /// Null ise satır dokunulamaz (para-kısıtlı hesap) ve cüzdan ipucu görünmez.
  final VoidCallback? onTap;

  /// Gösterilen sayı kaydedilmiş bir yoklamadan değil, işçiye kayıtlı ekip
  /// mevcudundan (crewSize) önden dolduruldu → henüz Firestore'da yok, "Kaydet"
  /// ile kesinleşir. Alt yazıda kullanıcıyı uyarmak için kullanılır.
  final bool pending;

  /// Kişi başı günlük ücret (kuruş). >0 ise alt yazıda "N kişi × ₺X = ₺toplam"
  /// gösterilir; 0 ise (yevmiye girilmemiş) yalnız kişi sayısı yazılır.
  final int crewRateKurus;

  /// Para tutarı (kişi başı ücret/toplam) gösterilsin mi? Kısıtlı hesapta false.
  final bool showWage;
  final ValueChanged<int> onChanged;
  final int maxHeadcount;

  /// Bu gün ödendi (hakedişe girdi) → düzenleme kapalı (kural §3, §6).
  final bool locked;

  /// Aktif tarlalar + bu günün tarla seçimi (isteğe bağlı — "ekip NEREDE
  /// çalıştı"). Çipler yalnız kişi sayısı girilmişken görünür.
  final List<Plot> plots;
  final String? plotId;
  final String? plotName;
  final ValueChanged<Plot?>? onPlotChanged;

  /// Aktif işler + bu günün iş seçimi (isteğe bağlı — "ekip NE İŞİ yaptı").
  /// Tarladan bağımsız ikinci bir şerittir.
  final List<Job> jobs;
  final String? jobId;
  final String? jobName;
  final ValueChanged<Job?>? onJobChanged;

  /// Çipler yalnız kişi sayısı > 0 iken görünür (önden dolu "pending" dahil:
  /// tarla/iş seçmek kaydı kesinleştirir — VM `setPlot`/`setJob`).
  bool get _tagsAllowed => !locked && headcount > 0;

  /// Tarla tanımlı değilse şerit hiç çıkmaz; silinmiş tarlalı eski kayıt için
  /// [plotId] doluysa açık kalır.
  bool get _showPlots =>
      onPlotChanged != null &&
      _tagsAllowed &&
      (plots.isNotEmpty || plotId != null);

  /// Yapılan iş şeridi — [_showPlots] ile aynı kural, kendi listesi üzerinden.
  bool get _showJobs =>
      onJobChanged != null && _tagsAllowed && (jobs.isNotEmpty || jobId != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Alt yazı: kişi sayısı + (para görebilen hesapta) kişi başı yevmiye çarpımı.
    // Kişi başı yevmiye işçinin kartında girilir; girilmemişse (0) yalnız sayı.
    // Para görebilen hesapta yevmiye çarpımı ("N × ₺X = ₺toplam"), aksi halde
    // sade sayı. Kişi başı yevmiye işçinin kartında girilir.
    final withMath = showWage && crewRateKurus > 0;
    final mathText = '$headcount kişi × ${formatKurus(crewRateKurus)} = '
        '${formatKurus(headcount * crewRateKurus)}';
    final String subtitle;
    if (headcount == 0) {
      subtitle = 'Bugün gelen kişi sayısını girin';
    } else if (pending) {
      // Önden dolu (henüz kaydedilmemiş) → onay ipucu.
      subtitle = '${withMath ? mathText : '$headcount kişi'} · Kaydet ile onayla';
    } else if (withMath) {
      subtitle = mathText;
    } else if (showWage) {
      // Para görebilen hesap ama yevmiye girilmemiş → kartından girmeye teşvik.
      subtitle = '$headcount kişi · Kişi başı yevmiye girilmemiş';
    } else {
      subtitle = '$headcount kişi geldi';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Ad/alt yazı alanı dokunulabilir (avans ver) — stepper düğmeleri
              // kendi dokunuşlarını yuttuğu için sayaçla çakışmaz.
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Dokunulabilirlik ipucu: küçük cüzdan ikonu.
                          if (onTap != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (locked) ...[
                Text(
                  '$headcount kişi',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                const PaidLockBadge(),
              ] else ...[
                _StepperButton(
                  icon: Icons.remove,
                  tooltip: 'Azalt',
                  onPressed:
                      headcount > 0 ? () => onChanged(headcount - 1) : null,
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$headcount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  tooltip: 'Artır',
                  onPressed: headcount < maxHeadcount
                      ? () => onChanged(headcount + 1)
                      : null,
                ),
              ],
            ],
          ),
          // Önce TARLA ("nerede"), altında YAPILAN İŞ ("ne").
          if (_showPlots) ...[
            const SizedBox(height: 4),
            TagChips<Plot>(
              items: plots,
              idOf: (p) => p.id,
              nameOf: (p) => p.name,
              selectedId: plotId,
              selectedName: plotName,
              icon: kPlotIcon,
              ghostLabel: kPlotGhostLabel,
              onChanged: onPlotChanged!,
            ),
          ],
          if (_showJobs) ...[
            const SizedBox(height: 4),
            TagChips<Job>(
              items: jobs,
              idOf: (j) => j.id,
              nameOf: (j) => j.name,
              selectedId: jobId,
              selectedName: jobName,
              icon: kJobIcon,
              ghostLabel: kJobGhostLabel,
              onChanged: onJobChanged!,
            ),
          ],
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
    );
  }
}
