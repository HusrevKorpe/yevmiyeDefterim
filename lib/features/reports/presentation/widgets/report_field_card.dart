/// Rapor'daki "Tarla Maliyeti" özet kartı — dokununca tarla sayfası açılır (§8).
///
/// Detay (tarla listesi + işçi dökümü) artık raporun içinde değil, kendi
/// SAYFASINDADIR (`/rapor/tarla`): rapor akışı kısa kalır, tarla dökümü rahat
/// okunur. Bu kart bakışta özet verir — dönem işçiliğinin toplamı, kaç tarla /
/// kaç yevmiye ve tarlaların payını gösteren tek şeritlik oran çubuğu.
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../application/field_cost.dart';

class ReportFieldCard extends StatelessWidget {
  const ReportFieldCard({
    super.key,
    required this.costs,
    required this.onTap,
  });

  /// Tarla satırları (brüte göre azalan; "seçilmemiş" en sonda).
  final List<FieldCost> costs;

  /// Tarla maliyeti sayfasını açar.
  final VoidCallback onTap;

  /// Gerçek tarla sayısı (kalıntı "seçilmemiş" satırı bir tarla değildir).
  int get _fieldCount => costs.where((f) => !f.isUnassigned).length;

  /// Dönemin toplam yevmiyesi (adam-gün).
  double get _workdays =>
      costs.fold<int>(0, (sum, f) => sum + f.workdayHalves) / 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalFieldGross(costs);

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
                    child: Icon(Icons.grass,
                        size: 18, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        Text('Tarla Maliyeti', style: theme.textTheme.titleMedium),
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
                  '$_fieldCount tarla • ${formatWorkdays(_workdays)} yevmiye',
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

/// Tarlaların payını tek şeritte gösteren yığılmış oran çubuğu.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.costs, required this.totalKurus});

  final List<FieldCost> costs;
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
Color segmentColor(BuildContext context, FieldCost cost, int index) {
  final cs = Theme.of(context).colorScheme;
  if (cost.isUnassigned) return cs.outlineVariant;
  const alphas = [1.0, 0.72, 0.54, 0.40, 0.30];
  return cs.primary
      .withValues(alpha: index < alphas.length ? alphas[index] : 0.24);
}

/// Kartın altındaki mini açıklama: en pahalı üç tarla ve payları.
class _Legend extends StatelessWidget {
  const _Legend({required this.costs, required this.totalKurus});

  final List<FieldCost> costs;
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
                  shown[i].fieldName,
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
