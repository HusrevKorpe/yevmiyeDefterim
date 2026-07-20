/// Avans ekle/düzenle ekranı (kural §8: ikon+yazı, onay, ₺ giriş).
///
/// Yeni: işçi seç + tutar + tarih. Düzenle: işçi sabit, tutar/tarih değişir,
/// açık avans silinebilir. Elebaşıya avans yok (kural §10) → listeden hariç.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date.dart';
import '../../../core/ids/ids.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../application/advance_view_model.dart';
import '../data/advance.dart';

class AdvanceEditScreen extends ConsumerStatefulWidget {
  const AdvanceEditScreen({super.key, this.advance});

  /// Düzenlenecek avans; null ise yeni avans.
  final Advance? advance;

  @override
  ConsumerState<AdvanceEditScreen> createState() => _AdvanceEditScreenState();
}

class _AdvanceEditScreenState extends ConsumerState<AdvanceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  String? _workerId;
  late String _date;

  bool get _isNew => widget.advance == null;

  @override
  void initState() {
    super.initState();
    final a = widget.advance;
    _amountCtrl = TextEditingController(
      text: a == null ? '' : formatKurusPlain(a.amountKurus),
    );
    _workerId = a?.workerId;
    _date = a?.date ?? todayIso();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseIsoDate(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Avans tarihi',
    );
    if (picked != null) setState(() => _date = toIsoDate(picked));
  }

  Future<void> _save(List<Worker> workers) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final amount = parseTlToKurus(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final existing = widget.advance;
    final workerName = existing?.workerName ??
        workers.firstWhere((w) => w.id == _workerId).name;

    final advance = Advance(
      id: existing?.id ?? newId(),
      workerId: _workerId!,
      workerName: workerName,
      amountKurus: amount,
      date: _date,
      settledPayrollId: existing?.settledPayrollId,
    );
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
    // Elebaşı hariç aktif işçiler (avans yalnız bireysel işçiye).
    final workers = ref
        .watch(activeWorkersProvider)
        .where((w) => w.type.isIndividual)
        .toList();
    final existing = widget.advance;

    return Scaffold(
      appBar: GradientAppBar(title: _isNew ? 'Avans Ver' : 'Avansı Düzenle'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isNew)
                DropdownButtonFormField<String>(
                  initialValue: _workerId,
                  decoration: const InputDecoration(
                    labelText: 'İşçi',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final w in workers)
                      DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                  onChanged:
                      saving ? null : (v) => setState(() => _workerId = v),
                  validator: (v) => v == null ? 'İşçi seçin.' : null,
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(existing!.workerName),
                  subtitle: const Text('İşçi'),
                ),
              const SizedBox(height: 20),
              MoneyField(
                controller: _amountCtrl,
                label: 'Avans tutarı',
                enabled: !saving,
                autofocus: _isNew,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today),
                // Uzun TR tarih ("31 Ağustos 2026, Çarşamba") + büyük yazı
                // ölçeğinde buton etiketi taşmasın/satır bölünmesin diye tek
                // satırda küçültülerek sığdırılır (kesme değil, ölçekle).
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Tarih: ${formatHumanDate(_date)}',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: saving ? null : () => _save(workers),
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
              if (!_isNew && existing!.isOpen) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving ? null : _delete,
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
