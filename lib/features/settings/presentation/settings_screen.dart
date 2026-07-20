/// Ayarlar ekranı — varsayılan yevmiyeler (plan §5, kural §8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme_mode.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../application/backup_service.dart';
import '../application/settings_providers.dart';
import '../application/settings_view_model.dart';
import '../data/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maleCtrl = TextEditingController();
  final _femaleCtrl = TextEditingController();
  final _crewCtrl = TextEditingController();
  bool _initialized = false;
  bool _backingUp = false;

  @override
  void dispose() {
    _maleCtrl.dispose();
    _femaleCtrl.dispose();
    _crewCtrl.dispose();
    super.dispose();
  }

  void _prefill(AppSettings s) {
    _maleCtrl.text = _initial(s.defaultWageMaleKurus);
    _femaleCtrl.text = _initial(s.defaultWageFemaleKurus);
    _crewCtrl.text = _initial(s.defaultCrewRateKurus);
  }

  // 0 => boş (kullanıcı ilk kez girsin), aksi halde biçimli ön dolum.
  String _initial(int kurus) => kurus == 0 ? '' : formatKurusPlain(kurus);

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref.read(settingsViewModelProvider.notifier).save(
          maleKurus: parseTlToKurus(_maleCtrl.text.trim()) ?? 0,
          femaleKurus: parseTlToKurus(_femaleCtrl.text.trim()) ?? 0,
          crewRateKurus: parseTlToKurus(_crewCtrl.text.trim()) ?? 0,
        );
  }

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
    ref.listen<SettingsFormState>(settingsViewModelProvider, (prev, next) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (next.saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ayarlar kaydedildi.')),
        );
      } else if (next.error != null) {
        messenger.showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final settingsAsync = ref.watch(settingsStreamProvider);
    final saving = ref.watch(settingsViewModelProvider).saving;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Ayarlar'),
      body: AsyncRetry(
        value: settingsAsync,
        onRetry: () => ref.invalidate(settingsStreamProvider),
        message: 'Ayarlar yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (settings) {
          if (!_initialized) {
            _prefill(settings);
            _initialized = true;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Görünüm'),
                  const SizedBox(height: 10),
                  const _DarkModeSwitch(),
                  const SizedBox(height: 28),
                  const SectionTitle('Varsayılan Yevmiyeler'),
                  const SizedBox(height: 8),
                  Text(
                    'Yoklama alınırken bu ücretler kullanılır. İşçi bazında ayrı '
                    'ücret, İşçiler ekranından verilebilir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  MoneyField(
                    controller: _maleCtrl,
                    label: 'Erkek yevmiye (günlük)',
                    enabled: !saving,
                    allowEmpty: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  MoneyField(
                    controller: _femaleCtrl,
                    label: 'Kadın yevmiye (günlük)',
                    enabled: !saving,
                    allowEmpty: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _save,
                  ),
                  // --- ELEBAŞI KİŞİ BAŞI ÜCRETİ ŞİMDİLİK RAFTA ---
                  // Elebaşıya sabit ücret girilmiyor; ödeme elden toplu
                  // veriliyor. Alan gizli ama _crewCtrl prefill/save'e bağlı
                  // kaldı → kayıtlı değer korunur. Geri açmak için aşağıdaki
                  // MoneyField'ı geri koy (textInputAction.next → female).
                  // const SizedBox(height: 16),
                  // MoneyField(
                  //   controller: _crewCtrl,
                  //   label: 'Elebaşı kişi başı (günlük)',
                  //   helperText: 'Elebaşıya bağlı her kişi için günlük ücret.',
                  //   enabled: !saving,
                  //   allowEmpty: true,
                  //   textInputAction: TextInputAction.done,
                  //   onSubmitted: _save,
                  // ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                  const SizedBox(height: 28),
                  const SectionTitle('Veri Yedeği'),
                  const SizedBox(height: 8),
                  Text(
                    'Tüm kayıtları (işçi, yoklama, avans, kasa) tek bir dosyaya '
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
        },
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
