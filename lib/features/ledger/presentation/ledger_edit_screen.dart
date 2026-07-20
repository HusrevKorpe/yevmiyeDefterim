/// Kasa gider kaydı ekle/düzenle ekranı (kural §8: ikon+yazı, onay, ₺).
///
/// Kategori + tutar + tarih + (opsiyonel) not. Uygulama yalnız gider takip
/// eder. Yalnız elle kayıtlar açılır (otomatik hakediş kayıtları salt-okunur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/categories.dart';
import '../../../core/date/app_date.dart';
import '../../../core/ids/ids.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../application/ledger_edit_view_model.dart';
import '../application/ledger_providers.dart';
import '../data/ledger_entry.dart';

class LedgerEditScreen extends ConsumerStatefulWidget {
  const LedgerEditScreen({
    super.key,
    this.entry,
    this.initialCategory,
  });

  /// Düzenlenecek kayıt; null ise yeni kayıt.
  final LedgerEntry? entry;

  /// Yeni kayıtta ön seçili kategori (ör. Mazot ekranından mazot).
  final String? initialCategory;

  @override
  ConsumerState<LedgerEditScreen> createState() => _LedgerEditScreenState();
}

class _LedgerEditScreenState extends ConsumerState<LedgerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  late String _date;

  /// Düzenlemeye başlarken kaydın sürümü — kaydederken değişti mi diye karşılaştırılır
  /// (başka cihaz eş zamanlı düzenleme yaptıysa üzerine yazmadan önce onay). Null =
  /// bilinmiyor (henüz okunmadı / offline) → çakışma kontrolü atlanır.
  int? _baseRev;

  bool get _isNew => widget.entry == null;

  List<String> get _categories => LedgerCategory.manualExpense;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _amountCtrl = TextEditingController(
      text: e == null ? '' : formatKurusPlain(e.amountKurus),
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _category =
        e?.category ?? widget.initialCategory ?? LedgerCategory.genel;
    _date = e?.date ?? todayIso();
    if (e != null) _loadBaseRev(e.id);
  }

  Future<void> _loadBaseRev(String id) async {
    try {
      final rev = await ref.read(ledgerRepositoryProvider).currentRev(id);
      if (mounted) _baseRev = rev;
    } catch (_) {
      // Sürüm okunamadı (offline vb.) — çakışma kontrolü sessizce atlanır.
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final iso = await pickAppDate(context, initialIso: _date, helpText: 'Kayıt tarihi');
    if (iso != null) setState(() => _date = iso);
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
      category: _category,
      amountKurus: amount,
      date: _date,
      source: LedgerSource.manual,
      note: note.isEmpty ? null : note,
    );

    // Yeni kayıtta aynı gün/tutar/kategori zaten varsa çift-giriş uyarısı.
    if (_isNew && !await _confirmIfDuplicate(entry)) return;
    // Düzenlemede kayıt başka cihazda değiştiyse üzerine yazmadan önce onay.
    if (!_isNew && !await _confirmIfChanged(existing!.id)) return;

    await ref
        .read(ledgerEditViewModelProvider.notifier)
        .submit(entry: entry, isNew: _isNew);
  }

  /// Aynı gün + tutar + kategoride başka bir elle kayıt varsa kullanıcıya sorar.
  /// `true` → devam et (kayıt yok ya da kullanıcı onayladı), `false` → vazgeç.
  Future<bool> _confirmIfDuplicate(LedgerEntry entry) async {
    final all = ref.read(ledgerStreamProvider).asData?.value ?? const [];
    final duplicate = all.any((e) =>
        e.id != entry.id &&
        e.isManual &&
        e.category == entry.category &&
        e.amountKurus == entry.amountKurus &&
        e.date == entry.date);
    if (!duplicate) return true;
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aynı kayıt var'),
        content: Text(
          '${formatHumanDate(entry.date)} tarihinde '
          '${LedgerCategory.label(entry.category)} için '
          '${formatKurus(entry.amountKurus)} tutarında kayıt zaten var. '
          'Yine de eklensin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yine de Ekle'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  /// Kayıt düzenleme başladığından beri (başka cihazda) değiştiyse onay ister.
  /// `true` → devam et (değişmemiş ya da üzerine yazmayı onayladı).
  Future<bool> _confirmIfChanged(String id) async {
    final base = _baseRev;
    if (base == null) return true; // sürüm bilinmiyor → akışı bloklama
    int? now;
    try {
      now = await ref.read(ledgerRepositoryProvider).currentRev(id);
    } catch (_) {
      return true; // sürüm okunamadı (offline) → üzerine yazmaya izin ver
    }
    if (now == null || now == base) return true;
    if (!mounted) return false;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kayıt değişmiş'),
        content: const Text(
          'Bu kayıt siz düzenlerken başka bir cihazda değiştirildi. '
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
