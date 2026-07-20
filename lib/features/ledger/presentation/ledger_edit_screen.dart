/// Kasa kaydı ekle/düzenle ekranı (kural §8: segment, ikon+yazı, onay, ₺).
///
/// Gelir/Gider segmenti + kategori + tutar + tarih + (opsiyonel) not. Yalnız
/// elle kayıtlar açılır (otomatik hakediş kayıtları salt-okunur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/categories.dart';
import '../../../core/date/app_date.dart';
import '../../../core/ids/ids.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../application/ledger_edit_view_model.dart';
import '../data/ledger_entry.dart';

class LedgerEditScreen extends ConsumerStatefulWidget {
  const LedgerEditScreen({
    super.key,
    this.entry,
    this.initialType,
    this.initialCategory,
  });

  /// Düzenlenecek kayıt; null ise yeni kayıt.
  final LedgerEntry? entry;

  /// Yeni kayıtta ön seçili tür (ör. Mazot ekranından gider). Yoksa gider.
  final LedgerType? initialType;

  /// Yeni kayıtta ön seçili kategori (ör. Mazot ekranından mazot).
  final String? initialCategory;

  @override
  ConsumerState<LedgerEditScreen> createState() => _LedgerEditScreenState();
}

class _LedgerEditScreenState extends ConsumerState<LedgerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late LedgerType _type;
  late String _category;
  late String _date;

  bool get _isNew => widget.entry == null;

  List<String> get _categories => _type == LedgerType.income
      ? LedgerCategory.manualIncome
      : LedgerCategory.manualExpense;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _amountCtrl = TextEditingController(
      text: e == null ? '' : formatKurusPlain(e.amountKurus),
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _type = e?.type ?? widget.initialType ?? LedgerType.expense;
    _category = e?.category ??
        widget.initialCategory ??
        (_type == LedgerType.income
            ? LedgerCategory.manualIncome.first
            : LedgerCategory.genel);
    _date = e?.date ?? todayIso();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _setType(LedgerType type) {
    setState(() {
      _type = type;
      // Kategori yeni tür için geçersizse ilk geçerliye çek.
      if (!_categories.contains(_category)) _category = _categories.first;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseIsoDate(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Kayıt tarihi',
    );
    if (picked != null) setState(() => _date = toIsoDate(picked));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final amount = parseTlToKurus(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final existing = widget.entry;
    final note = _noteCtrl.text.trim();
    final entry = LedgerEntry(
      id: existing?.id ?? newId(),
      type: _type,
      category: _category,
      amountKurus: amount,
      date: _date,
      source: LedgerSource.manual,
      note: note.isEmpty ? null : note,
    );
    await ref
        .read(ledgerEditViewModelProvider.notifier)
        .submit(entry: entry, isNew: _isNew);
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text(
          '${LedgerCategory.label(e.category)} '
          '${formatKurus(e.amountKurus)} kaydı silinsin mi?',
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
      await ref.read(ledgerEditViewModelProvider.notifier).delete(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LedgerEditState>(ledgerEditViewModelProvider, (prev, next) {
      if (!mounted) return;
      if (next.done) {
        Navigator.of(context).pop();
      } else if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final saving = ref.watch(ledgerEditViewModelProvider).saving;

    return Scaffold(
      appBar: GradientAppBar(title: _isNew ? 'Yeni Kayıt' : 'Kaydı Düzenle'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<LedgerType>(
                segments: const [
                  ButtonSegment(
                    value: LedgerType.expense,
                    icon: Icon(Icons.arrow_downward),
                    label: Text('Gider'),
                  ),
                  ButtonSegment(
                    value: LedgerType.income,
                    icon: Icon(Icons.arrow_upward),
                    label: Text('Gelir'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged:
                    saving ? null : (s) => _setType(s.first),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(
                        value: c, child: Text(LedgerCategory.label(c))),
                ],
                onChanged: saving
                    ? null
                    : (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 20),
              MoneyField(
                controller: _amountCtrl,
                label: 'Tutar',
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _noteCtrl,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
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
                  onPressed: saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Kaydı Sil'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
