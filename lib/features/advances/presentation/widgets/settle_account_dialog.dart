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
import '../../../../core/widgets/app_dialog.dart';
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
    final countText = widget.openCount > 1 ? ' · ${widget.openCount} kayıt' : '';

    return AppDialog(
      icon: Icons.handshake_outlined,
      title: 'Hesap görüldü',
      message:
          '${widget.workerName} için hesap görüldü olarak işaretlensin mi?\n\n'
          'Açık avansları (${formatKurus(widget.openTotalKurus)}$countText) '
          'kapanacak. Geri alınabilir.',
      confirmLabel: 'Hesap Görüldü',
      onConfirm: _confirm,
      scrollable: true,
      // Devreden alacağımız — boş = alacak kalmadı. Doluysa kapanışla
      // birlikte aynı tutarda yeni açık avans (devir) oluşur.
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        ],
      ),
    );
  }
}
