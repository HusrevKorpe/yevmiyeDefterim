/// Elebaşı yoklama satırı — +/− kişi sayacı (kural §8, §10).
library;

import 'package:flutter/material.dart';

import 'paid_lock_badge.dart';

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
  });

  final String name;
  final int headcount;

  /// Gösterilen sayı kaydedilmiş bir yoklamadan değil, işçiye kayıtlı ekip
  /// mevcudundan (crewSize) önden dolduruldu → henüz Firestore'da yok, "Kaydet"
  /// ile kesinleşir. Alt yazıda kullanıcıyı uyarmak için kullanılır.
  final bool pending;

  /// Kişi başı ücret — para satırı şu an rafta (bkz. build). Değer hâlâ
  /// ayarlardan geçiliyor ki para hesabı geri açılınca çağrı yeri değişmesin.
  final int crewRateKurus;
  final ValueChanged<int> onChanged;
  final int maxHeadcount;

  /// Bu gün ödendi (hakedişe girdi) → düzenleme kapalı (kural §3, §6).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // --- ELEBAŞI PARA SATIRI ŞİMDİLİK RAFTA ---
    // Elebaşıya sabit/kişi-başı ücret girilmiyor; ödeme elden toplu yapılıyor.
    // Yoklamada yalnız gelen kişi sayısı tutulur (para hesabı yok). Geri açmak
    // için: `import '../../../../core/money/money.dart';` ekle ve subtitle'ı
    // crewRateKurus==0 iken 'Kişi başı ücret girilmemiş', aksi halde
    // '$headcount kişi × ${formatKurus(crewRateKurus)} = ${formatKurus(headcount*crewRateKurus)}' yap.
    final subtitle = headcount == 0
        ? 'Bugün gelen kişi sayısını girin'
        : pending
            ? '$headcount kişi · Kaydet ile onayla'
            : '$headcount kişi geldi';

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
                        color: theme.colorScheme.onSurfaceVariant,
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
