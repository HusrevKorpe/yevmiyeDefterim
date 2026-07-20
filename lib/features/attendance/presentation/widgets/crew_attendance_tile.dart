/// Elebaşı yoklama satırı — +/− kişi sayacı (kural §8, §10).
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import 'paid_lock_badge.dart';

class CrewAttendanceTile extends StatelessWidget {
  const CrewAttendanceTile({
    super.key,
    required this.name,
    required this.headcount,
    required this.crewRateKurus,
    required this.onChanged,
    this.maxHeadcount = 99,
    this.locked = false,
  });

  final String name;
  final int headcount;
  final int crewRateKurus;
  final ValueChanged<int> onChanged;
  final int maxHeadcount;

  /// Bu gün ödendi (hakedişe girdi) → düzenleme kapalı (kural §3, §6).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyKurus = headcount * crewRateKurus;
    final subtitle = crewRateKurus == 0
        ? 'Kişi başı ücret girilmemiş'
        : '$headcount kişi × ${formatKurus(crewRateKurus)} = '
            '${formatKurus(dailyKurus)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: crewRateKurus == 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
