/// Dönem (başlangıç→bitiş) seçici — sağlayıcıdan bağımsız (kural §7, §8).
///
/// Sade "dönem pili": tek satırda başlangıç → bitiş, her iki uç ayrı ayrı
/// dokunularak tarih seçtirir. Değeri ve geri çağrıları dışarıdan alır; Hakediş,
/// Kasa ve Rapor aynı widget'ı kendi dönem sağlayıcılarıyla kullanır. Presetler
/// (Bu Hafta/Bu Ay) yalnız ilgili callback verilirse gösterilir.
library;

import 'package:flutter/material.dart';

import '../date/app_date.dart';
import 'app_date_picker.dart';

class PeriodRangeSelector extends StatelessWidget {
  const PeriodRangeSelector({
    super.key,
    required this.startIso,
    required this.endIso,
    required this.onSetStart,
    required this.onSetEnd,
    this.onThisWeek,
    this.onThisMonth,
  });

  final String startIso;
  final String endIso;
  final ValueChanged<String> onSetStart;
  final ValueChanged<String> onSetEnd;
  final VoidCallback? onThisWeek;
  final VoidCallback? onThisMonth;

  Future<void> _pick(BuildContext context, {required bool isStart}) async {
    final iso = await pickAppDate(
      context,
      initialIso: isStart ? startIso : endIso,
      helpText: isStart ? 'Başlangıç tarihi' : 'Bitiş tarihi',
    );
    if (iso == null) return;
    if (isStart) {
      onSetStart(iso);
    } else {
      onSetEnd(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPresets = onThisWeek != null || onThisMonth != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tek parça sade "dönem pili": başlangıç → bitiş, her iki uç dokunulur.
          // Material kullanılır ki InkWell dalgası tint'li zemin üstünde görünsün.
          Material(
            color: cs.primary.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.primary.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
                    child: Icon(Icons.date_range, size: 22, color: cs.primary),
                  ),
                  Expanded(
                    child: _DateSegment(
                      value: formatShortDate(startIso),
                      onTap: () => _pick(context, isStart: true),
                    ),
                  ),
                  Icon(Icons.arrow_right_alt,
                      size: 24, color: cs.onSurfaceVariant),
                  Expanded(
                    child: _DateSegment(
                      value: formatShortDate(endIso),
                      onTap: () => _pick(context, isStart: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasPresets) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (onThisWeek != null)
                  ActionChip(
                    avatar: const Icon(Icons.calendar_view_week, size: 18),
                    label: const Text('Bu Hafta'),
                    onPressed: onThisWeek,
                  ),
                if (onThisMonth != null)
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Bu Ay'),
                    onPressed: onThisMonth,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateSegment extends StatelessWidget {
  const _DateSegment({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        // Büyük yazı ölçeğinde tarih "29 Ağ…" diye kesilmesin diye küçülterek
        // sığdırılır (kesme yerine ölçekle) → tarih hep okunur, satır taşmaz.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
