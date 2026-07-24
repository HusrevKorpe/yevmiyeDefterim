/// Elebaşı yoklama satırı — +/− kişi sayacı (kural §8, §10).
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../data/field.dart';
import 'field_chips.dart';
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
    this.showWage = true,
    this.fields = const [],
    this.fieldId,
    this.fieldName,
    this.onFieldChanged,
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

  /// Aktif tarlalar + bu günün tarla seçimi (isteğe bağlı — "ekip nerede
  /// çalıştı"). Çipler yalnız kişi sayısı girilmişken görünür.
  final List<Field> fields;
  final String? fieldId;
  final String? fieldName;
  final ValueChanged<Field?>? onFieldChanged;

  /// Tarla çipleri yalnız kişi sayısı > 0 iken görünür (önden dolu "pending"
  /// dahil: tarla seçmek kaydı kesinleştirir — VM `setField`). Tarla tanımlı
  /// değilse satır hiç çıkmaz; silinmiş tarlalı eski kayıt için [fieldId]
  /// doluysa açık kalır.
  bool get _showFields =>
      onFieldChanged != null &&
      !locked &&
      headcount > 0 &&
      (fields.isNotEmpty || fieldId != null);

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
          if (_showFields) ...[
            const SizedBox(height: 4),
            FieldChips(
              fields: fields,
              selectedFieldId: fieldId,
              selectedFieldName: fieldName,
              onChanged: onFieldChanged!,
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
