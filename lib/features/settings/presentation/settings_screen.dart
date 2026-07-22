/// Ayarlar ekranı — görünüm (koyu tema) + veri yedeği.
///
/// Sabit/varsayılan yevmiye ARTIK YOK: her işçinin yevmiyesi İşçiler ekranından
/// tek tek elle girilir (yoklamada o işçinin kendi yevmiyesi kullanılır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme_mode.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backingUp = false;

  /// Tüm veriyi JSON dosyasına aktarıp paylaşım yaprağını açar (yedek).
  Future<void> _backup() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await shareBackup(ref.read(firestoreProvider));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Yedek alınamadı. İnternet bağlantınızı kontrol edin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Ayarlar'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Görünüm'),
            const SizedBox(height: 10),
            const _DarkModeSwitch(),
            const SizedBox(height: 28),
            const SectionTitle('Veri Yedeği'),
            const SizedBox(height: 8),
            Text(
              'Tüm kayıtları (işçi, yoklama, avans, gider) tek bir dosyaya '
              'aktarır. Yanlışlıkla silmeye karşı ara sıra yedek alıp '
              'Drive’a veya e-postaya kaydedin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _backingUp ? null : _backup,
              icon: _backingUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_outlined),
              label: Text(_backingUp ? 'Hazırlanıyor…' : 'Yedek Al (JSON)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Koyu tema anahtarı. Değeri gerçekte çizilen parlaklıktan okur
/// (`Theme.of(context).brightness`) → sistem varsayılanı da doğru yansır.
/// Dokununca tercih kalıcı yazılır ve uygulama anında yeni temaya geçer.
class _DarkModeSwitch extends ConsumerWidget {
  const _DarkModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: isDark,
        onChanged: (on) => ref
            .read(themeModeControllerProvider.notifier)
            .set(on ? ThemeMode.dark : ThemeMode.light),
        secondary: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: theme.colorScheme.primary,
          ),
        ),
        title: const Text(
          'Koyu tema',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isDark ? 'Koyu görünüm açık' : 'Açık görünüm',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
