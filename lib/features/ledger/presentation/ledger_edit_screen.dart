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
import '../../../app/theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/entry_form.dart';
import '../../../core/widgets/gradient_header.dart';
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
  late String _kind;
  late String _date;

  /// Düzenlemeye başlarken kaydın sürümü — kaydederken değişti mi diye karşılaştırılır
  /// (başka cihaz eş zamanlı düzenleme yaptıysa üzerine yazmadan önce onay). Null =
  /// bilinmiyor (henüz okunmadı / offline) → çakışma kontrolü atlanır.
  int? _baseRev;

  bool get _isNew => widget.entry == null;

  List<String> get _categories => LedgerCategory.manualExpense;

  /// Seçili kategoride tahsilat girilebilir mi? (Mazot/Tamir/Bakkal — esnafa
  /// önden para verilen kategoriler; Genel'de tür seçici görünmez.)
  bool get _canTahsilat => LedgerKind.tahsilatCategories.contains(_category);

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
    _kind = e?.kind ?? LedgerKind.gider;
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
      // Tahsilat yalnız kendi ekranı olan kategorilerde girilebilir.
      kind: _canTahsilat ? _kind : LedgerKind.gider,
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
        e.kind == entry.kind &&
        e.amountKurus == entry.amountKurus &&
        e.date == entry.date);
    if (!duplicate) return true;
    if (!mounted) return false;
    return showConfirmDialog(
      context,
      title: 'Aynı kayıt var',
      message: '${formatHumanDate(entry.date)} tarihinde '
          '${LedgerCategory.label(entry.category)} için '
          '${formatKurus(entry.amountKurus)} tutarında '
          '${entry.isTahsilat ? 'tahsilat' : 'kayıt'} zaten var. '
          'Yine de eklensin mi?',
      confirmLabel: 'Yine de Ekle',
      icon: Icons.warning_amber_rounded,
      accent: StatusColors.half,
    );
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
    return showConfirmDialog(
      context,
      title: 'Kayıt değişmiş',
      message: 'Bu kayıt siz düzenlerken başka bir cihazda değiştirildi. '
          'Kaydederseniz onların değişikliği kaybolur. Yine de kaydedilsin mi?',
      confirmLabel: 'Üzerine Yaz',
      icon: Icons.sync_problem,
      accent: StatusColors.half,
    );
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    final ok = await showConfirmDialog(
      context,
      title: 'Kaydı sil',
      message:
          '${LedgerCategory.label(e.category)}${e.isTahsilat ? ' tahsilatı' : ''} '
          '${formatKurus(e.amountKurus)} kaydı silinsin mi?',
      confirmLabel: 'Sil',
      icon: Icons.delete_outline,
    );
    if (ok) {
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AmountHeroField(
                controller: _amountCtrl,
                enabled: !saving,
                autofocus: _isNew,
              ),
              const SizedBox(height: 26),
              const FieldLabel('Kategori'),
              _CategoryPicker(
                categories: _categories,
                selected: _category,
                onSelected: saving
                    ? null
                    : (c) => setState(() {
                          _category = c;
                          // Tahsilat girilemeyen kategoriye geçince tür sıfırlanır.
                          if (!_canTahsilat) _kind = LedgerKind.gider;
                        }),
              ),
              // Tür seçici — yalnız esnafa önden para verilen kategorilerde
              // (Mazot/Tamir/Bakkal). Tahsilat gider toplamına girmez.
              if (_canTahsilat) ...[
                const SizedBox(height: 24),
                const FieldLabel('Tür'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SelectableChip(
                      selected: _kind == LedgerKind.gider,
                      label: 'Gider',
                      icon: Icons.arrow_downward,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => _kind = LedgerKind.gider),
                    ),
                    SelectableChip(
                      selected: _kind == LedgerKind.tahsilat,
                      label: 'Tahsilat',
                      icon: Icons.savings_outlined,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => _kind = LedgerKind.tahsilat),
                    ),
                  ],
                ),
                if (_kind == LedgerKind.tahsilat) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Esnafa önden verilen para. Gider toplamına eklenmez; '
                    '${LedgerCategory.label(_category)} ekranında '
                    '"kalan" olarak izlenir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              const FieldLabel('Tarih'),
              PickerTile(
                icon: Icons.event,
                value: formatHumanDateNoWeekday(_date),
                onTap: saving ? null : _pickDate,
              ),
              const SizedBox(height: 24),
              const FieldLabel('Not (isteğe bağlı)'),
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
                  onPressed: saving ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
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

/// Kategori seçici — düz dropdown yerine ikonlu seçim çipleri (kural §8).
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in categories)
          SelectableChip(
            selected: selected == c,
            label: LedgerCategory.label(c),
            icon: categoryIcon(c),
            onSelected: onSelected == null ? null : (_) => onSelected!(c),
          ),
      ],
    );
  }
}
