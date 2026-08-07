/// Maliyet dökümü listesi — her tarla/iş ayrı kart, dokununca işçi dökümü
/// açılır. AYNI liste iki kırılım için de kullanılır (bkz. [CostGroupKind]).
///
/// Rapor akışının içinde değil, kendi SAYFASINDA yaşar (bkz. [WorkCostScreen]):
/// rapor kısa kalsın, döküm rahat okunsun. Hesap mantığı saf
/// [buildWorkCosts]'tadır; burada yalnız gösterim var.
///
/// Satır: sıra rozeti, ad, brüt, "yevmiye • gün • işçi" ve dönem işçiliği
/// içindeki pay (şerit + yüzde). Seçim yapılmamış kayıtlar bir grup değil
/// kalıntıdır → nötr tonda ve her zaman en sonda durur.
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../application/work_cost.dart';

class WorkCostList extends StatefulWidget {
  const WorkCostList({super.key, required this.costs, this.header});

  /// Döküm satırları (brüte göre azalan; "seçilmemiş" en sonda).
  final List<WorkCost> costs;

  /// Listeyle birlikte kayan başlık (dönem özeti kartı). Boş bırakılabilir.
  final Widget? header;

  @override
  State<WorkCostList> createState() => _WorkCostListState();
}

class _WorkCostListState extends State<WorkCostList> {
  /// Dökümü açık satırın anahtarı (tarla/iş id'si; seçilmemiş satır için '').
  String? _openKey;

  static String _keyOf(WorkCost c) => c.groupId ?? '';

  @override
  Widget build(BuildContext context) {
    final total = totalWorkGross(widget.costs);
    final hasHeader = widget.header != null;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      itemCount: widget.costs.length + (hasHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) return widget.header!;
        final i = hasHeader ? index - 1 : index;
        final f = widget.costs[i];
        return WorkCostCard(
          cost: f,
          totalKurus: total,
          // Sıra numarası yalnız gerçek satırlara verilir (kalıntı sayılmaz).
          rank: f.isUnassigned ? null : i + 1,
          expanded: _openKey == _keyOf(f),
          onTap: () => setState(() {
            final key = _keyOf(f);
            _openKey = _openKey == key ? null : key;
          }),
        );
      },
    );
  }
}

/// Tek tarla/iş kartı. Dokununca [expanded] ile işçi dökümü açılır.
class WorkCostCard extends StatelessWidget {
  const WorkCostCard({
    super.key,
    required this.cost,
    required this.totalKurus,
    required this.expanded,
    required this.onTap,
    this.rank,
  });

  final WorkCost cost;
  final int totalKurus;
  final bool expanded;
  final VoidCallback onTap;

  /// Brüte göre sıra (1 = en pahalısı). Kalıntı satırda `null`.
  final int? rank;

  /// Dönem işçiliği içindeki pay (0..1). Toplam 0 ise pay yok.
  double get _share => totalKurus <= 0 ? 0 : cost.grossKurus / totalKurus;

  String get _meta => [
        '${formatWorkdays(cost.workdays)} yevmiye',
        '${cost.dayCount} gün',
        '${cost.workerCount} işçi',
      ].join(' • ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Kalıntı satır ("seçilmemiş") bir grup değil → soluk/nötr ton.
    final accent = cost.isUnassigned
        ? theme.colorScheme.outline
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: rank == null
                        ? Icon(Icons.help_outline, size: 16, color: accent)
                        : Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cost.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cost.isUnassigned
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedMoney(
                    formatKurus(cost.grossKurus),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      _meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '%${(_share * 100).round()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _share.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: accent,
                  ),
                ),
              ),
              if (expanded) _WorkerBreakdown(cost: cost),
            ],
          ),
        ),
      ),
    );
  }
}

/// Açılan bölüm: o tarlada/işte kim kaç yevmiye çalıştı, ne tahakkuk etti.
class _WorkerBreakdown extends StatelessWidget {
  const _WorkerBreakdown({required this.cost});

  final WorkCost cost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 18),
          if (cost.workers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'İşçi dökümü yok.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'İşçi dökümü',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final w in cost.workers) _WorkerLine(worker: w),
          ],
        ],
      ),
    );
  }
}

/// Döküm satırı: bir işçinin o tarladaki/işteki yevmiyesi ve tutarı.
class _WorkerLine extends StatelessWidget {
  const _WorkerLine({required this.worker});

  final WorkerCostShare worker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(
            worker.isCrew ? Icons.groups : Icons.person,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              worker.workerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 6),
          // Büyük sistem yazısında satırı taşırmasın diye küçülerek sığar.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                worker.isCrew
                    ? '${formatWorkdays(worker.workdays)} kişi-gün'
                    : '${formatWorkdays(worker.workdays)} yevmiye',
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FittedMoney(
            formatKurus(worker.grossKurus),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Satır sonundaki tutar: payına sağa yaslanır (tutarlar alt alta hizalı kalır)
/// ve büyük sistem yazısında sığmazsa küçülerek tek satırda durur (taşma yok).
/// Yalnız `Row`/`Flex` içinde kullanılır ([Flexible] döner).
class FittedMoney extends StatelessWidget {
  const FittedMoney(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(text, maxLines: 1, style: style),
        ),
      ),
    );
  }
}
