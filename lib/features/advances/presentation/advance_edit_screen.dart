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
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/entry_form.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../application/advance_providers.dart';
import '../application/advance_view_model.dart';
import '../data/advance.dart';
import 'widgets/settle_account_dialog.dart';

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
    return showConfirmDialog(
      context,
      title: 'Avans değişmiş',
      message: 'Bu avans siz düzenlerken başka bir cihazda değiştirildi. '
          'Kaydederseniz onların değişikliği kaybolur. Yine de kaydedilsin mi?',
      confirmLabel: 'Üzerine Yaz',
      icon: Icons.sync_problem,
      accent: StatusColors.half,
    );
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
    final ok = await showConfirmDialog(
      context,
      title: 'Avansı sil',
      message:
          '${a.workerName} için ${formatKurus(a.amountKurus)} avans silinsin mi?',
      confirmLabel: 'Sil',
      icon: Icons.delete_outline,
    );
    if (ok) {
      await ref.read(advanceEditViewModelProvider.notifier).delete(a);
    }
  }

  /// "Hesap görüldü" — işçinin TÜM açık avanslarını bugünkü tarihle kapatır →
  /// alacağı kalmadı. Onay ister, geri al (SnackBar) sunar. Hem düzenlemeden
  /// (eldeki avans [fallback]) hem yeni "Avans Ver" ekranından çağrılır.
  Future<void> _markAccountSeen({
    required String workerId,
    required String workerName,
    Advance? fallback,
  }) async {
    // İşçinin bütün açık avansları — hepsi tek seferde kapanır. Liste akışı
    // henüz veri vermediyse (ekran akış dışı açıldı) sessiz kalmak yerine en
    // azından eldeki avans kapatılır.
    final all = ref.read(advancesStreamProvider).asData?.value;
    final open = all == null
        ? <Advance>[?fallback]
        : all.where((a) => a.workerId == workerId && a.isOpen).toList();

    // Kök ScaffoldMessenger'ı async gap'ten önce yakala: ekran kapansa da
    // SnackBar (Geri Al) avanslar ekranında güvenle görünür.
    final messenger = ScaffoldMessenger.of(context);

    if (open.isEmpty) {
      // Bu arada başka cihazda kapatılmış/silinmiş — sessiz kalma, bildir.
      messenger.showSnackBar(
        const SnackBar(content: Text('Kapatılacak açık avans kalmamış.')),
      );
      return;
    }
    final ids = open.map((a) => a.id).toList();
    final total = open.fold<int>(0, (s, a) => s + a.amountKurus);

    // Onay + isteğe bağlı "devreden alacağımız" (null = vazgeçti, 0 = devirsiz).
    final devirKurus = await showSettleAccountDialog(
      context,
      workerName: workerName,
      openTotalKurus: total,
      openCount: open.length,
    );
    if (devirKurus == null) return;

    final today = todayIso();
    // Devreden alacağımız: kapanışla AYNI batch'te yeni açık avans yazılır →
    // sonraki hesapta/yoklamada devam eder. Geri almada birlikte silinir.
    final carryover = devirKurus <= 0
        ? null
        : Advance(
            id: Advance.carryoverId(today, newId()),
            workerId: workerId,
            workerName: workerName,
            amountKurus: devirKurus,
            date: today,
            note: 'Önceki hesaptan devir',
          );

    // Notifier'ı önden yakala: ekran kapansa da "Geri Al" güvenle çalışsın.
    final vm = ref.read(accountSettlementViewModelProvider.notifier);
    final success = await vm.settle(ids, today, carryover: carryover);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(carryover == null
              ? '$workerName için hesap görüldü.'
              : '$workerName için hesap görüldü · '
                  '${formatKurus(carryover.amountKurus)} devretti.'),
          action: SnackBarAction(
            label: 'Geri Al',
            onPressed: () => vm.reopen(
              ids,
              deleteIds: [if (carryover != null) carryover.id],
            ),
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
    // listede olmayan değer alanda hayalet seçim olarak görünmesin.
    final selectedId =
        workers.any((w) => w.id == _workerId) ? _workerId : null;
    // Yeni avansta seçili işçinin açık avansları — varsa "Hesap Görüldü"
    // butonu doğrudan bu ekranda çıkar (mevcut avansa girmeye gerek yok).
    final openForSelected = _isNew && selectedId != null
        ? ref
            .watch(openAdvancesProvider)
            .where((a) => a.workerId == selectedId)
            .toList()
        : const <Advance>[];

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
                // DropdownMenu menüyü HER ZAMAN alanın altına açar (eski
                // DropdownButtonFormField seçili öğeyi alanın üstüne getirmek
                // için bir yukarı bir aşağı açılıyordu). Uzun liste menü
                // içinde kayar (menuHeight).
                DropdownMenuFormField<String>(
                  initialSelection: selectedId,
                  enabled: !saving,
                  requestFocusOnTap: false,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: 320,
                  hintText: 'İşçi seçin',
                  leadingIcon: const Icon(Icons.person_outline),
                  inputDecorationTheme: entryFieldDecorationTheme(context),
                  menuStyle: MenuStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  dropdownMenuEntries: [
                    for (final w in workers)
                      DropdownMenuEntry(
                        value: w.id,
                        label: w.type.isCrew ? '${w.name} (Elebaşı)' : w.name,
                      ),
                  ],
                  onSelected: (v) => setState(() => _workerId = v),
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
              if (_isNew && openForSelected.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _markAccountSeen(
                            workerId: selectedId!,
                            workerName: workers
                                .firstWhere((w) => w.id == selectedId)
                                .name,
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: incomeColor(context),
                    side: BorderSide(
                        color: incomeColor(context).withValues(alpha: 0.6)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  // Uzun tutar + büyük sistem yazısında taşmasın — tek satıra sığdır.
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Hesap Görüldü '
                      '(${formatKurus(openForSelected.fold<int>(0, (s, a) => s + a.amountKurus))} açık)',
                    ),
                  ),
                ),
              ],
              if (!_isNew && existing!.isOpen) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _markAccountSeen(
                            workerId: existing.workerId,
                            workerName: existing.workerName,
                            fallback: existing,
                          ),
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
