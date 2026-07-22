/// Avans ekle/düzenle ekranı (kural §8: ikon+yazı, onay, ₺ giriş).
///
/// Yeni: işçi seç + tutar + tarih. Düzenle: işçi sabit, tutar/tarih değişir,
/// açık avans silinebilir. Elebaşı da avans alabilir (2026-07-22: kural §10
/// gevşetildi — yoklamadaki elebaşı kartından da açılır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/date/app_date.dart';
import '../../../core/ids/ids.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/entry_form.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../application/advance_providers.dart';
import '../application/advance_view_model.dart';
import '../data/advance.dart';

class AdvanceEditScreen extends ConsumerStatefulWidget {
  const AdvanceEditScreen({super.key, this.advance, this.initialWorkerId});

  /// Düzenlenecek avans; null ise yeni avans.
  final Advance? advance;

  /// Yeni avansta işçi ön-seçili gelsin (yoklamadaki elebaşı kartından açılış).
  /// Yalnız [advance] null iken anlamlı; düzenlemede işçi zaten sabittir.
  final String? initialWorkerId;

  @override
  ConsumerState<AdvanceEditScreen> createState() => _AdvanceEditScreenState();
}

class _AdvanceEditScreenState extends ConsumerState<AdvanceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  String? _workerId;
  late String _date;

  /// Düzenlemeye başlarken avansın sürümü — kaydederken başka cihazda değişti mi
  /// diye karşılaştırılır. Null = bilinmiyor → çakışma kontrolü atlanır.
  int? _baseRev;

  bool get _isNew => widget.advance == null;

  @override
  void initState() {
    super.initState();
    final a = widget.advance;
    _amountCtrl = TextEditingController(
      text: a == null ? '' : formatKurusPlain(a.amountKurus),
    );
    _noteCtrl = TextEditingController(text: a?.note ?? '');
    _workerId = a?.workerId ?? widget.initialWorkerId;
    _date = a?.date ?? todayIso();
    if (a != null) _loadBaseRev(a.id);
  }

  Future<void> _loadBaseRev(String id) async {
    try {
      final rev = await ref.read(advanceRepositoryProvider).currentRev(id);
      if (mounted) _baseRev = rev;
    } catch (_) {
      // Sürüm okunamadı (offline vb.) — çakışma kontrolü sessizce atlanır.
    }
  }

  /// Avans düzenleme başladığından beri başka cihazda değiştiyse onay ister.
  /// `true` → devam et (değişmemiş ya da üzerine yazmayı onayladı).
  Future<bool> _confirmIfChanged(String id) async {
    final base = _baseRev;
    if (base == null) return true;
    int? now;
    try {
      now = await ref.read(advanceRepositoryProvider).currentRev(id);
    } catch (_) {
      return true;
    }
    if (now == null || now == base) return true;
    if (!mounted) return false;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avans değişmiş'),
        content: const Text(
          'Bu avans siz düzenlerken başka bir cihazda değiştirildi. '
          'Kaydederseniz onların değişikliği kaybolur. Yine de kaydedilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Üzerine Yaz'),
          ),
        ],
      ),
    );
    return overwrite == true;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final iso = await pickAppDate(context, initialIso: _date, helpText: 'Avans tarihi');
    if (iso != null) setState(() => _date = iso);
  }

  Future<void> _save(List<Worker> workers) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final amount = parseTlToKurus(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final existing = widget.advance;
    final workerName = existing?.workerName ??
        workers.firstWhere((w) => w.id == _workerId).name;
    final note = _noteCtrl.text.trim();

    final advance = Advance(
      id: existing?.id ?? newId(),
      workerId: _workerId!,
      workerName: workerName,
      amountKurus: amount,
      date: _date,
      settledPayrollId: existing?.settledPayrollId,
      note: note.isEmpty ? null : note,
    );

    // Düzenlemede avans başka cihazda değiştiyse üzerine yazmadan önce onay.
    if (!_isNew && !await _confirmIfChanged(existing!.id)) return;

    await ref
        .read(advanceEditViewModelProvider.notifier)
        .submit(advance: advance, isNew: _isNew);
  }

  Future<void> _delete() async {
    final a = widget.advance!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avansı sil'),
        content: Text(
          '${a.workerName} için ${formatKurus(a.amountKurus)} avans silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(advanceEditViewModelProvider.notifier).delete(a);
    }
  }

  /// "Hesap görüldü" — işçinin TÜM açık avanslarını (bu avans dahil) bugünkü
  /// tarihle kapatır → alacağı kalmadı. Onay ister, geri al (SnackBar) sunar.
  Future<void> _markAccountSeen(Advance existing) async {
    // İşçinin bütün açık avansları — hepsi tek seferde kapanır.
    final all =
        ref.read(advancesStreamProvider).asData?.value ?? const <Advance>[];
    final open = all
        .where((a) => a.workerId == existing.workerId && a.isOpen)
        .toList();
    if (open.isEmpty) return;
    final ids = open.map((a) => a.id).toList();
    final total = open.fold<int>(0, (s, a) => s + a.amountKurus);
    final countText = open.length > 1 ? ' · ${open.length} kayıt' : '';

    // Kök ScaffoldMessenger'ı async gap'ten önce yakala: ekran kapansa da
    // SnackBar (Geri Al) avanslar ekranında güvenle görünür.
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesap görüldü'),
        content: Text(
          '${existing.workerName} için hesap görüldü olarak işaretlensin mi?\n\n'
          'Açık avansları (${formatKurus(total)}$countText) kapanacak ve '
          '“alacağı kalmadı” olarak görünecek. Geri alınabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text('Hesap Görüldü'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Notifier'ı önden yakala: ekran kapansa da "Geri Al" güvenle çalışsın.
    final vm = ref.read(accountSettlementViewModelProvider.notifier);
    final success = await vm.settle(ids, todayIso());
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${existing.workerName} için hesap görüldü.'),
          action: SnackBarAction(
            label: 'Geri Al',
            onPressed: () => vm.reopen(ids),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('İşaretlenemedi. İnternet bağlantınızı kontrol edin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AdvanceEditState>(advanceEditViewModelProvider, (prev, next) {
      if (!mounted) return;
      if (next.done) {
        Navigator.of(context).pop();
      } else if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final saving = ref.watch(advanceEditViewModelProvider).saving;
    // "Hesap görüldü" işlemi sürerken de butonlar kilitlenir.
    final settling = ref.watch(accountSettlementViewModelProvider);
    final busy = saving || settling;
    // Tüm aktif işçiler — elebaşı dahil (elebaşı da avans alabilir).
    final workers = ref.watch(activeWorkersProvider);
    final existing = widget.advance;
    // Ön-seçili işçi listede yoksa (ör. bu arada pasife alındı) seçimi düşür —
    // dropdown initialValue listede olmayan değerle assert atar.
    final selectedId =
        workers.any((w) => w.id == _workerId) ? _workerId : null;

    return Scaffold(
      appBar: GradientAppBar(title: _isNew ? 'Avans Ver' : 'Avansı Düzenle'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('İşçi'),
              if (_isNew)
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: entryFieldDecoration(
                    context,
                    hint: 'İşçi seçin',
                    icon: Icons.person_outline,
                  ),
                  items: [
                    for (final w in workers)
                      DropdownMenuItem(
                        value: w.id,
                        child: Text(
                          w.type.isCrew ? '${w.name} (Elebaşı)' : w.name,
                        ),
                      ),
                  ],
                  onChanged:
                      saving ? null : (v) => setState(() => _workerId = v),
                  validator: (v) => v == null ? 'İşçi seçin.' : null,
                )
              else
                _WorkerTile(name: existing!.workerName),
              const SizedBox(height: 24),
              AmountHeroField(
                controller: _amountCtrl,
                label: 'Avans tutarı',
                enabled: !saving,
                autofocus: _isNew,
              ),
              const SizedBox(height: 24),
              const FieldLabel('Tarih'),
              PickerTile(
                icon: Icons.event,
                value: formatHumanDateNoWeekday(_date),
                onTap: saving ? null : _pickDate,
              ),
              const SizedBox(height: 24),
              const FieldLabel('Açıklama (isteğe bağlı)'),
              TextFormField(
                controller: _noteCtrl,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: entryFieldDecoration(
                  context,
                  hint: 'Kısa açıklama ekleyin',
                  icon: Icons.notes,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: busy ? null : () => _save(workers),
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
              if (!_isNew && existing!.isOpen) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _markAccountSeen(existing),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: incomeColor(context),
                    side: BorderSide(
                        color: incomeColor(context).withValues(alpha: 0.6)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Hesap Görüldü (alacağı kalmadı)'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: busy ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Avansı Sil'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Düzenlemede sabit işçi satırı — avatar + ad (işçi değiştirilemez).
class _WorkerTile extends StatelessWidget {
  const _WorkerTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
