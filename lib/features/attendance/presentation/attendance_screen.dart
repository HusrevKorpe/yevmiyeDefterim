/// Yoklama ekranı (plan §5, kural §8) — tarih seç + Tam/Yarım/Yok + elebaşı sayacı.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/routes.dart';
import '../../../core/date/app_date.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../advances/presentation/advance_edit_screen.dart';
import '../../auth/application/user_access.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../application/attendance_providers.dart';
import '../application/attendance_view_model.dart';
import '../application/jobs_providers.dart';
import '../application/plots_providers.dart';
import '../application/wage.dart';
import '../data/attendance_record.dart';
import 'widgets/crew_attendance_tile.dart';
import 'widgets/individual_attendance_tile.dart';

part 'attendance_list.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(attendanceViewModelProvider, (prev, next) {
      if (next != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next)));
      }
    });

    return Scaffold(
      appBar: const GradientAppBar(
        leading: _FieldsButton(),
        actions: [_SaveButton()],
      ),
      body: const Column(
        children: [
          _DateBar(),
          Expanded(child: _AttendanceBody()),
        ],
      ),
    );
  }
}

/// KORUMALI günlerde, yoklamadaki İLK değişiklikten önce onay diyaloğu
/// gösterir — yanlışlıkla dokunup alınmış yoklamayı bozmayı önler.
///
/// Korumalı gün iki durumda oluşur:
/// 1. "Kaydet"e basılmış gün ([selectedDaySavedProvider]) — BUGÜN dahil. Gece
///    yarısını beklemez: yoklamayı kaydettiğiniz andan itibaren her değişiklik
///    "alınmış yoklamayı değiştiriyorsunuz" diye sorar. İşaret cihazlar arası
///    ortaktır → başka telefondan kaydedilen gün burada da korumaya girer.
/// 2. Bugün dışındaki (geçmiş/ileri) günler — hiç kaydedilmemiş olsalar da.
///
/// Onaylanınca o günün kilidi açılır ([attendanceEditUnlockedDateProvider]) →
/// düzeltme turu boyunca her dokunuşta tekrar sorulmaz; "Kaydet" kilidi geri
/// kapatır. Vazgeçilirse [action] hiç çalışmaz (satırlar stream'den çizildiği
/// için görünüm bozulmaz).
Future<void> _confirmProtectedEdit(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  /// "Kaydet" düğmesinden geliyorsa onay butonu "Değiştir" değil "Kaydet" der.
  bool saving = false,
}) async {
  final date = ref.read(selectedDateProvider);
  final saved = ref.read(selectedDaySavedProvider);
  final isToday = date == todayIso();
  if ((isToday && !saved) ||
      ref.read(attendanceEditUnlockedDateProvider) == date) {
    await action();
    return;
  }
  // Diyalog beklenirken widget ağacı değişebilir → notifier'ı önden al
  // (await sonrası `ref` kullanmamak için).
  final unlock = ref.read(attendanceEditUnlockedDateProvider.notifier);
  final ok = await showConfirmDialog(
    context,
    title: saved ? 'Yoklama kaydedilmiş' : 'Geçmiş günü değiştir',
    message: saved
        ? '${formatHumanDate(date)} yoklaması kaydedilmiş. '
            'Değişiklik yapmak istiyor musunuz?'
        : '${formatHumanDate(date)} gününe ait yoklamayı değiştirmek '
            'üzeresiniz. Devam edilsin mi?',
    confirmLabel: saving ? 'Kaydet' : 'Değiştir',
    icon: saved ? Icons.edit_note : Icons.edit_calendar_outlined,
    accent: StatusColors.half,
  );
  if (ok) {
    unlock.unlock(date);
    await action();
  }
}

/// Sol üstteki "Tarla ve İşler" düğmesi → tek yönetim ekranı (üstte tarlalar,
/// altında yapılan işler). Orada tanımlananlar, yoklamada Tam/Yarım (elebaşında
/// kişi sayısı) girilince satırın altında iki ayrı çip şeridi olarak çıkar →
/// "kim nerede çalıştı" ve "ne işi yapıldı" kayıt altına alınır.
class _FieldsButton extends StatelessWidget {
  const _FieldsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.grass),
      tooltip: 'Tarla ve İşler',
      onPressed: () => context.push(AppRoutes.plotsAndJobs),
    );
  }
}

// NOT: "Aylık tablo" (Excel cetveli) düğmesi 2026-08-07'de buradan Ana
// Sayfa'daki degrade başlığa, Rapor'un yanına taşındı — yoklama üst çubuğu
// yalnız Tarlalar + Kaydet ile sade kalsın diye.

/// Sağ üstteki "Kaydet" düğmesi.
///
/// Bireysel yoklama ve elle değiştirilen elebaşı sayısı zaten her dokunuşta
/// otomatik kaydedilir (bkz. [attendanceViewModelProvider]). Bu düğmenin tek
/// İŞLEVSEL görevi: önden dolu ama henüz kaydı olmayan elebaşı öntanımlı
/// mevcutlarını (crewSize) o güne yazmak (commitCrewDefaults). Ayrıca kullanıcıya
/// "günün yoklaması kaydedildi" görsel/dokunsal onayı verir.
class _SaveButton extends ConsumerStatefulWidget {
  const _SaveButton();

  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton> {
  // Basma hissini görünür kılmak için basılıyken kartı küçültüp gölgesini
  // düşürürüz (yeşil header üzerinde beyaz hap "buton" gibi okunur).
  bool _pressed = false;

  Future<void> _confirm() async {
    HapticFeedback.mediumImpact();
    // Korumalı günde (kaydedilmiş ya da geçmiş gün) "Kaydet" de onaydan geçer —
    // yanlış dokunuşla elebaşı öntanımlıları yazılmasın / diğer cihazlara
    // gereksiz bildirim gitmesin.
    await _confirmProtectedEdit(context, ref, _doSave, saving: true);
  }

  Future<void> _doSave() async {
    final vm = ref.read(attendanceViewModelProvider.notifier);
    // Günün "yoklama alındı" işaretini yaz → diğer cihazlara push bildirimi
    // gider (Cloud Function) VE bu gün korumaya girer: bundan sonraki her
    // değişiklik "yoklama kaydedilmiş, değiştirilsin mi?" onayından geçer
    // (bkz. _confirmProtectedEdit). Bilerek await'siz: offline'da UI'ı
    // bekletmesin — yerel yazım anında görünür, işaret sonra senkronlanır.
    unawaited(vm.markDaySaved());
    // Önden dolu (henüz kaydı olmayan) elebaşı mevcutlarını şimdi kalıcı yaz —
    // bu ekranda yoklama verisine gerçekten yazan tek nokta budur.
    await vm.commitCrewDefaults();
    // Kaydetmeden önce açılmış onay kilidini geri kapat → kaydedilen günde
    // yapılacak SONRAKİ düzeltme yeniden sorar (art arda düzeltmelerde diyalog
    // yağmuru olmaması için kilit yalnız bir tur açık kalır).
    ref.read(attendanceEditUnlockedDateProvider.notifier).relock();
    if (!mounted) return;
    final date = ref.read(selectedDateProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: StatusColors.full,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${formatHumanDateNoWeekday(date)} yoklaması kaydedildi',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Bu gün daha önce kaydedildi mi? İki işi birden görür:
    // (1) düğmede küçük ✓ → "bu günün yoklaması alınmış" görsel işareti,
    // (2) işaret akışını ekran açıkken CANLI tutar → satıra dokunulduğu anda
    //     _confirmProtectedEdit değeri hazır okur (ilk dokunuş korumasız kalmaz).
    final saved = ref.watch(selectedDaySavedProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.white,
          elevation: _pressed ? 0 : 3,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            splashColor: StatusColors.full.withValues(alpha: 0.22),
            highlightColor: StatusColors.full.withValues(alpha: 0.10),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () {
              setState(() => _pressed = false);
              _confirm();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (saved) ...[
                    const Icon(Icons.check_circle,
                        size: 14, color: StatusColors.full),
                    const SizedBox(width: 5),
                  ],
                  const Text(
                    'Kaydet',
                    style: TextStyle(
                      color: StatusColors.full,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar();

  Future<void> _pick(BuildContext context, WidgetRef ref, String date) async {
    final iso = await pickAppDate(context, initialIso: date, helpText: 'Yoklama tarihi');
    if (iso != null) {
      ref.read(selectedDateProvider.notifier).set(iso);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final notifier = ref.read(selectedDateProvider.notifier);
    final isToday = date == todayIso();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 28,
            tooltip: 'Önceki gün',
            onPressed: () => notifier.shift(-1),
          ),
          // Tarih iki satıra ayrıldı: "29 Ağustos 2026" + "Cumartesi". Böylece
          // uzun gün adı satırı şişirmez, büyük yazı ölçeğinde de taşmaz.
          Expanded(
            child: InkWell(
              onTap: () => _pick(context, ref, date),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                // Büyük yazı ölçeğinde tam tarih kesilmesin/satır bölünmesin diye
                // iki satır birlikte küçültülerek sığdırılır (ellipsis yerine).
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatHumanDateNoWeekday(date),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatWeekday(date),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 28,
            tooltip: 'Sonraki gün',
            onPressed: isToday ? null : () => notifier.shift(1),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Bugün',
            onPressed: isToday ? null : notifier.today,
          ),
        ],
      ),
    );
  }
}

