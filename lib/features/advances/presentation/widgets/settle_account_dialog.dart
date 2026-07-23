/// "Hesap görüldü" onay diyaloğu — isteğe bağlı devreden alacak tutarı ile.
///
/// [ConfirmDialog] görünümünü (degrade ikon rozeti + ortalanmış metin + eşit
/// iki buton) temel alır; farkı, alta eklenen isteğe bağlı "devreden
/// alacağımız" alanıdır: işçiye tüm borcumuz ödendi ama bizim ondan alacağımız
/// kaldıysa (ör. avans fazlası) tutar buraya yazılır → kapanışla birlikte aynı
/// tutarda YENİ açık avans (devir kaydı) oluşur ve sonraki hesaba devreder.
library;

import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/widgets/entry_form.dart';

/// Diyaloğu açar. Dönüş: `null` = vazgeçti; `0` = devirsiz onay (alacak
/// kalmadı); `> 0` = onay + devreden alacağımız (kuruş).
Future<int?> showSettleAccountDialog(
  BuildContext context, {
  required String workerName,
  required int openTotalKurus,
  required int openCount,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => SettleAccountDialog(
      workerName: workerName,
      openTotalKurus: openTotalKurus,
      openCount: openCount,
    ),
  );
}

class SettleAccountDialog extends StatefulWidget {
  const SettleAccountDialog({
    super.key,
    required this.workerName,
    required this.openTotalKurus,
    required this.openCount,
  });

  final String workerName;
  final int openTotalKurus;
  final int openCount;

  @override
  State<SettleAccountDialog> createState() => _SettleAccountDialogState();
}

class _SettleAccountDialogState extends State<SettleAccountDialog> {
  final _amountCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final t = _amountCtrl.text.trim();
    if (t.isEmpty) {
      Navigator.pop(context, 0); // devirsiz — alacak kalmadı
      return;
    }
    final kurus = parseTlToKurus(t);
    if (kurus == null || kurus <= 0) {
      setState(() => _error = 'Geçerli tutar girin (örn. 2.000).');
      return;
    }
    Navigator.pop(context, kurus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = cs.primary;
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final countText = widget.openCount > 1 ? ' · ${widget.openCount} kayıt' : '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Icon(Icons.handshake_outlined, size: 30, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              'Hesap görüldü',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.workerName} için hesap görüldü olarak işaretlensin mi?\n\n'
              'Açık avansları (${formatKurus(widget.openTotalKurus)}$countText) '
              'kapanacak. Geri alınabilir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 18),
            // Devreden alacağımız — boş = alacak kalmadı. Doluysa kapanışla
            // birlikte aynı tutarda yeni açık avans (devir) oluşur.
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Devreden alacağımız (isteğe bağlı)',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('devir-amount'),
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _confirm(),
              decoration: entryFieldDecoration(
                context,
                hint: 'Boş = alacağı kalmadı',
                icon: Icons.currency_lira,
              ).copyWith(errorText: _error),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'İşçinin size borcu kaldıysa yazın — yeni hesaba devreder.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        backgroundColor: cs.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Vazgeç'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Hesap Görüldü'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
