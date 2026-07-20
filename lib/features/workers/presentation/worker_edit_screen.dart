/// İşçi ekle/düzenle ekranı (kural §8: segment düğme, ikon+yazı, onay).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/ids.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../application/worker_edit_view_model.dart';
import '../data/worker.dart';

class WorkerEditScreen extends ConsumerStatefulWidget {
  const WorkerEditScreen({super.key, this.worker});

  /// Düzenlenecek işçi; null ise yeni işçi eklenir.
  final Worker? worker;

  @override
  ConsumerState<WorkerEditScreen> createState() => _WorkerEditScreenState();
}

class _WorkerEditScreenState extends ConsumerState<WorkerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _overrideCtrl;
  late final TextEditingController _headcountCtrl;
  late WorkerType _type;

  /// Cinsiyet zorunlu ve varsayılansız: yeni işçide null başlar, kullanıcı
  /// açıkça seçmeden kayda izin verilmez. [_genderError] seçim yapılmadan
  /// kaydetmeye çalışıldığında segment altında gösterilir.
  Gender? _gender;
  String? _genderError;

  bool get _isNew => widget.worker == null;

  @override
  void initState() {
    super.initState();
    final w = widget.worker;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _overrideCtrl = TextEditingController(
      text: (w?.dailyWageOverrideKurus == null)
          ? ''
          : formatKurusPlain(w!.dailyWageOverrideKurus!),
    );
    _headcountCtrl = TextEditingController(
      text: (w == null || w.crewSize == 0) ? '' : '${w.crewSize}',
    );
    _type = w?.type ?? WorkerType.gundelik;
    // Mevcut işçide cinsiyet zaten kayıtlı; yeni işçide seçim beklenir (null).
    _gender = w?.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _overrideCtrl.dispose();
    _headcountCtrl.dispose();
    super.dispose();
  }

  /// Elebaşı ekip mevcudu: boş => öneri yok (null). Aksi halde 0–99 tam sayı.
  int? _parseHeadcount() {
    final t = _headcountCtrl.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n <= 0) return null;
    return n;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState!.validate();
    // Cinsiyet yalnız bireysel işçi için zorunlu (elebaşıda anlamsız — kural §10).
    final genderMissing = _type.isIndividual && _gender == null;
    setState(() => _genderError = genderMissing ? 'Cinsiyet seçin.' : null);
    if (!formOk || genderMissing) return;
    final worker = Worker(
      id: widget.worker?.id ?? newId(),
      name: _nameCtrl.text.trim(),
      type: _type,
      // Elebaşı için cinsiyet/ücret override anlamsız (kural §10).
      gender: _type.isCrew ? Gender.male : _gender!,
      dailyWageOverrideKurus:
          _type.isCrew ? null : parseTlToKurus(_overrideCtrl.text.trim()),
      // Kişi sayısı yalnız elebaşıda saklanır; bireysele geçilirse temizlenir.
      defaultHeadcount: _type.isCrew ? _parseHeadcount() : null,
      active: widget.worker?.active ?? true,
    );
    await ref
        .read(workerEditViewModelProvider.notifier)
        .submit(worker: worker, isNew: _isNew);
  }

  Future<void> _toggleActive() async {
    final w = widget.worker!;
    if (w.active) {
      final ok = await _confirm(
        title: 'İşçiyi pasif yap',
        message:
            '${w.name} pasif yapılsın mı? Yoklama ve seçim listelerinde görünmez, '
            'ama geçmiş kayıtları korunur.',
        confirmLabel: 'Pasif Yap',
      );
      if (ok != true) return;
    }
    await ref
        .read(workerEditViewModelProvider.notifier)
        .setActive(id: w.id, active: !w.active);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WorkerEditState>(workerEditViewModelProvider, (prev, next) {
      if (!mounted) return;
      if (next.done) {
        Navigator.of(context).pop();
      } else if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final saving = ref.watch(workerEditViewModelProvider).saving;
    final w = widget.worker;

    return Scaffold(
      appBar: GradientAppBar(title: _isNew ? 'Yeni İşçi' : 'İşçiyi Düzenle'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                enabled: !saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'İsim',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'İsim girin.' : null,
              ),
              const SizedBox(height: 24),
              const Text('Tür', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<WorkerType>(
                segments: const [
                  ButtonSegment(
                    value: WorkerType.sabit,
                    label: Text('Sabit'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                  ButtonSegment(
                    value: WorkerType.gundelik,
                    label: Text('Gündelik'),
                    icon: Icon(Icons.today_outlined),
                  ),
                  ButtonSegment(
                    value: WorkerType.elebasi,
                    label: Text('Elebaşı'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: saving
                    ? null
                    : (s) => setState(() {
                          _type = s.first;
                          _genderError = null;
                        }),
              ),
              if (_type.isIndividual) ...[
                const SizedBox(height: 24),
                const Text('Cinsiyet',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<Gender>(
                  // Varsayılan seçim yok: kullanıcı Erkek/Kadın'ı açıkça
                  // seçmeden kaydedemez (boş seçime izin verilir).
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(
                      value: Gender.male,
                      label: Text('Erkek'),
                      icon: Icon(Icons.male),
                    ),
                    ButtonSegment(
                      value: Gender.female,
                      label: Text('Kadın'),
                      icon: Icon(Icons.female),
                    ),
                  ],
                  selected: _gender == null ? const {} : {_gender!},
                  onSelectionChanged: saving
                      ? null
                      : (s) => setState(() {
                            _gender = s.isEmpty ? null : s.first;
                            _genderError = null;
                          }),
                ),
                if (_genderError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _genderError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                MoneyField(
                  controller: _overrideCtrl,
                  label: 'Özel yevmiye (isteğe bağlı)',
                  helperText: 'Boş bırakılırsa varsayılan ücret kullanılır.',
                  enabled: !saving,
                  allowEmpty: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _save,
                ),
              ] else ...[
                const SizedBox(height: 24),
                TextFormField(
                  controller: _headcountCtrl,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Kaç kişi getiriyor? (isteğe bağlı)',
                    helperText:
                        'Yalnızca bilgi için — listede görünür, para hesabına girmez.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.groups_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null; // isteğe bağlı
                    final n = int.tryParse(t);
                    if (n == null || n < 0) return 'Geçerli bir sayı girin.';
                    if (n > 99) return 'En fazla 99 kişi.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Elebaşı bireysel takip edilmez; yoklamada kişi sayısı girilir, '
                  'ödeme toplu yapılır.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
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
              if (!_isNew) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving ? null : _toggleActive,
                  icon: Icon(w!.active
                      ? Icons.person_off_outlined
                      : Icons.person_add_outlined),
                  label: Text(w.active ? 'Pasif Yap' : 'Aktif Yap'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
