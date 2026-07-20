/// Ayarlar ekranı — varsayılan yevmiyeler (plan §5, kural §8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
