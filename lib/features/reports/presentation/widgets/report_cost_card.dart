/// Rapor'daki "Tarla / İş Maliyeti" özet kartı — dokununca döküm sayfası
/// açılır (§8).
///
/// Detay (tarla/iş listesi + işçi dökümü) artık raporun içinde değil, kendi
/// SAYFASINDADIR (`/rapor/tarla`, iki kırılım arasında geçilir): rapor akışı
/// kısa kalır, döküm rahat okunur. Bu kart bakışta özet verir — dönem
/// işçiliğinin toplamı, kaç tarla/iş, kaç yevmiye ve payları gösteren tek
/// şeritlik oran çubuğu.
///
/// Kart TEK kırılım gösterir ([kind]); çağıran dönemde dolu olanı verir (ikisi
/// de doluysa tarla). Sayfaya girince diğerine geçilir. İki kırılımın toplamı
/// zaten aynıdır — kartın tutarı hangi tarafta olursa olsun değişmez.
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../application/work_cost.dart';

class ReportCostCard extends StatelessWidget {
  const ReportCostCard({
    super.key,
    required this.costs,
    required this.kind,
    required this.onTap,
  });

  /// Döküm satırları (brüte göre azalan; "seçilmemiş" en sonda).
  final List<WorkCost> costs;

  /// Kartın gösterdiği kırılım (alt satır metnini de belirler).
  final CostGroupKind kind;

  /// Döküm sayfasını açar.
  final VoidCallback onTap;

  /// Gerçek satır sayısı (kalıntı "seçilmemiş" satırı sayılmaz).
  int get _groupCount => costs.where((f) => !f.isUnassigned).length;

  /// Dönemin toplam yevmiyesi (adam-gün).
  double get _workdays =>
      costs.fold<int>(0, (sum, f) => sum + f.workdayHalves) / 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalWorkGross(costs);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      kind == CostGroupKind.plot
                          ? Icons.grass
                          : Icons.handyman_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Tarla / İş Maliyeti',
                        style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatKurus(total),
                        maxLines: 1,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: theme.colorScheme.outline),
                ],
              ),
              // Sayılar kendi satırında: tutar/ok ile yer paylaşmadığından
              // büyük yazıda da kırpılmaz.
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 2),
                child: Text(
                  '$_groupCount ${kind == CostGroupKind.plot ? 'tarla' : 'iş'}'
                  ' • ${formatWorkdays(_workdays)} yevmiye',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ShareBar(costs: costs, totalKurus: total),
              const SizedBox(height: 8),
              _Legend(costs: costs, totalKurus: total),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarla/iş paylarını tek şeritte gösteren yığılmış oran çubuğu.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.costs, required this.totalKurus});

  final List<WorkCost> costs;
  final int totalKurus;

  @override
  Widget build(BuildContext context) {
    final segments = costs.where((f) => f.grossKurus > 0).toList();
    if (totalKurus <= 0 || segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          // stretch şart: çapraz eksende gevşek kalırsa çocuksuz [ColoredBox]
          // en küçük boyutu (0 yükseklik) alır ve şerit hiç çizilmez.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < segments.length; i++)
              Expanded(
                // flex tam sayı ve > 0 olmalı: çok küçük paylar da ince bir
                // dilim olarak görünür (kaybolmaz).
                flex: (segments[i].grossKurus / totalKurus * 1000)
                    .round()
                    .clamp(1, 1000),
                child: ColoredBox(color: segmentColor(context, segments[i], i)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Şerit/nokta rengi: sıraya göre soluklaşan yeşil; kalıntı satır nötr.
Color segmentColor(BuildContext context, WorkCost cost, int index) {
  final cs = Theme.of(context).colorScheme;
  if (cost.isUnassigned) return cs.outlineVariant;
  const alphas = [1.0, 0.72, 0.54, 0.40, 0.30];
  return cs.primary
      .withValues(alpha: index < alphas.length ? alphas[index] : 0.24);
}

/// Kartın altındaki mini açıklama: en pahalı üç satır ve payları.
class _Legend extends StatelessWidget {
  const _Legend({required this.costs, required this.totalKurus});

  final List<WorkCost> costs;
  final int totalKurus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (totalKurus <= 0 || costs.isEmpty) return const SizedBox.shrink();

    final shown = costs.take(3).toList();
    final rest = costs.length - shown.length;

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = 0; i < shown.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: segmentColor(context, shown[i], i),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  shown[i].groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '%${(shown[i].grossKurus / totalKurus * 100).round()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        if (rest > 0)
          Text(
            '+$rest',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
