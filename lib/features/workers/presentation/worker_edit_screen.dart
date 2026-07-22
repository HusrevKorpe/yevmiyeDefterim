/// İşçi ekle/düzenle ekranı (kural §8: segment düğme, ikon+yazı, onay).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ids/ids.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/entry_form.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../../auth/application/user_access.dart';
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
        icon: Icons.person_off_outlined,
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
    required IconData icon,
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentColor = accent ?? cs.error;
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Degrade tonlu ikon rozeti — sanatsal başlık dokunuşu.
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.22),
                      accentColor.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Icon(icon, size: 30, color: accentColor),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 24),
              // Eşit genişlikte iki buton; renkle ayrılır (nötr / aksan).
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: cs.onError,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(confirmLabel),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    final canSeeMoney = ref.watch(canSeeMoneyProvider);
    final w = widget.worker;

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: GradientAppBar(title: _isNew ? 'Yeni İşçi' : 'İşçiyi Düzenle'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('İsim'),
              TextFormField(
                controller: _nameCtrl,
                enabled: !saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: entryFieldDecoration(
                  context,
                  hint: 'Ad soyad',
                  icon: Icons.person_outline,
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'İsim girin.' : null,
              ),
              const SizedBox(height: 24),
              const FieldLabel('Tür'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in WorkerType.values)
                    SelectableChip(
                      selected: _type == t,
                      label: t.label,
                      icon: _typeIcon(t),
                      onSelected: saving
                          ? null
                          : (_) => setState(() {
                                _type = t;
                                _genderError = null;
                              }),
                    ),
                ],
              ),
              if (_type.isIndividual) ...[
                const SizedBox(height: 24),
                const FieldLabel('Cinsiyet'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final g in Gender.values)
                      SelectableChip(
                        selected: _gender == g,
                        label: g.label,
                        icon: g == Gender.male ? Icons.male : Icons.female,
                        accent:
                            g == Gender.male ? maleColor(context) : femaleColor(context),
                        onSelected: saving
                            ? null
                            : (_) => setState(() {
                                  _gender = g;
                                  _genderError = null;
                                }),
                      ),
                  ],
                ),
                if (_genderError != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      _genderError!,
                      style: TextStyle(color: cs.error, fontSize: 12),
                    ),
                  ),
                ],
                // Yevmiye para bilgisidir → kısıtlı hesapta gizli. Artık sabit/
                // varsayılan yevmiye yok: her işçinin günlük ücreti burada elle
                // girilir (zorunlu) ve yoklamada o işçinin kendi ücreti kullanılır.
                if (canSeeMoney) ...[
                  const SizedBox(height: 24),
                  const FieldLabel('Yevmiye'),
                  MoneyField(
                    controller: _overrideCtrl,
                    label: 'Günlük ücret',
                    helperText: 'Bu işçinin günlük yevmiyesi.',
                    enabled: !saving,
                    allowEmpty: false,
                    filled: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _save,
                  ),
                ],
              ] else ...[
                const SizedBox(height: 24),
                const FieldLabel('Kaç kişi getiriyor? (isteğe bağlı)'),
                TextFormField(
                  controller: _headcountCtrl,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: entryFieldDecoration(
                    context,
                    hint: 'Örn. 8',
                    icon: Icons.groups_outlined,
                  ).copyWith(
                    helperText:
                        'Yalnızca bilgi için — listede görünür, para hesabına girmez.',
                    helperMaxLines: 2,
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
                _InfoNote(
                  'Elebaşı bireysel takip edilmez; yoklamada kişi sayısı '
                  'girilir, ödeme toplu yapılır.',
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
                    : const Icon(Icons.check),
                label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: saving ? null : _toggleActive,
                  style: TextButton.styleFrom(
                    foregroundColor: w!.active ? cs.error : cs.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: Icon(w.active
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

  static IconData _typeIcon(WorkerType t) => switch (t) {
        WorkerType.sabit => Icons.badge_outlined,
        WorkerType.gundelik => Icons.today_outlined,
        WorkerType.elebasi => Icons.groups_outlined,
      };
}

/// İpucu notu — yumuşak tonlu kutuda bilgi ikonu + metin (elebaşı açıklaması).
class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
