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
import '../../../core/widgets/gradient_header.dart';
import '../../advances/presentation/advance_edit_screen.dart';
import '../../auth/application/user_access.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../application/attendance_providers.dart';
import '../application/attendance_view_model.dart';
import '../application/fields_providers.dart';
import '../application/wage.dart';
import '../data/attendance_record.dart';
import 'widgets/crew_attendance_tile.dart';
import 'widgets/individual_attendance_tile.dart';

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
        actions: [_MonthlyButton(), _SaveButton()],
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

/// Geçmiş güne (bugün dışındaki tarihe) ait yoklamadaki İLK değişiklikten önce
/// onay diyaloğu gösterir — yanlışlıkla dokunup geçmiş kaydı bozmayı önler
/// (bugüne dokunuş hiç sormaz). Onaylanınca o günün kilidi açılır
/// ([pastEditUnlockedDateProvider]) → aynı günde tekrar sorulmaz; vazgeçilirse
/// [action] hiç çalışmaz (satırlar stream'den çizildiği için görünüm bozulmaz).
Future<void> _confirmPastEdit(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final date = ref.read(selectedDateProvider);
  if (date == todayIso() || ref.read(pastEditUnlockedDateProvider) == date) {
    await action();
    return;
  }
  // Diyalog beklenirken widget ağacı değişebilir → notifier'ı önden al
  // (await sonrası `ref` kullanmamak için).
  final unlock = ref.read(pastEditUnlockedDateProvider.notifier);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Geçmiş günü değiştir'),
      content: Text(
        '${formatHumanDate(date)} gününe ait yoklamayı değiştirmek '
        'üzeresiniz. Devam edilsin mi?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Değiştir'),
        ),
      ],
    ),
  );
  if (ok == true) {
    unlock.unlock(date);
    await action();
  }
}

/// Sol üstteki "Tarlalar" düğmesi → tarla yönetim ekranı. Orada tanımlanan
/// tarlalar, yoklamada Tam/Yarım (elebaşında kişi sayısı) girilince satırın
/// altında çip olarak çıkar → "kim nerede çalıştı" kayıt altına alınır.
class _FieldsButton extends StatelessWidget {
  const _FieldsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.grass),
      tooltip: 'Tarlalar',
      onPressed: () => context.push(AppRoutes.fields),
    );
  }
}

/// Üst çubuktaki "Aylık tablo" düğmesi → aylık yoklama cetveli ekranı.
class _MonthlyButton extends StatelessWidget {
  const _MonthlyButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.calendar_view_month),
      tooltip: 'Aylık tablo',
      onPressed: () => context.push(AppRoutes.monthlyAttendance),
    );
  }
}

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
    // Geçmiş günde "Kaydet" de onaydan geçer — yanlış dokunuşla geçmiş güne
    // elebaşı öntanımlıları yazılmasın / diğer cihazlara bildirim gitmesin.
    await _confirmPastEdit(context, ref, _doSave);
  }

  Future<void> _doSave() async {
    final vm = ref.read(attendanceViewModelProvider.notifier);
    // Günün "yoklama alındı" işaretini yaz → diğer cihazlara push bildirimi
    // gider (Cloud Function). Bilerek await'siz: offline'da UI'ı bekletmesin.
    unawaited(vm.markDaySaved());
    // Önden dolu (henüz kaydı olmayan) elebaşı mevcutlarını şimdi kalıcı yaz —
    // bu ekranda yoklama verisine gerçekten yazan tek nokta budur.
    await vm.commitCrewDefaults();
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
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              child: Text(
                'Kaydet',
                style: TextStyle(
                  color: StatusColors.full,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
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

class _AttendanceBody extends ConsumerWidget {
  const _AttendanceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(workersStreamProvider);
    final settingsAsync = ref.watch(settingsStreamProvider);

    return AsyncRetry(
      value: workersAsync,
      onRetry: () => ref.invalidate(workersStreamProvider),
      message: 'İşçiler yüklenemedi. İnternet bağlantınızı kontrol edin.',
      data: (workers) {
        final active = workers.where((w) => w.active).toList();
        if (active.isEmpty) return const _NoActiveWorkers();
        return AsyncRetry(
          value: settingsAsync,
          onRetry: () => ref.invalidate(settingsStreamProvider),
          message: 'Ayarlar yüklenemedi. İnternet bağlantınızı kontrol edin.',
          data: (settings) => _List(active: active, settings: settings),
        );
      },
    );
  }
}

/// İşçileri sekmelere ayırır (Erkekler / Kadınlar / Elebaşılar). Artık yoklama
/// akışını İZLEMEZ (StatelessWidget) → bir işçiye dokunmak bu ağacı yeniden
/// kurmaz; yalnız `active`/`settings` değişince (nadir) yeniden çizilir.
/// Her satırın güncel durumu, satırın kendi `Consumer`'ında `.select` ile alınır.
class _List extends StatelessWidget {
  const _List({required this.active, required this.settings});

  final List<Worker> active;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    // Bireysel işçiler cinsiyete göre ayrı sekmelere düşer (Erkekler / Kadınlar).
    // Her grup kendi içinde ada göre sıralı kalır (compareWorkers).
    final males = active
        .where((w) => w.type.isIndividual && w.gender == Gender.male)
        .toList();
    final females = active
        .where((w) => w.type.isIndividual && w.gender == Gender.female)
        .toList();
    final crews = active.where((w) => w.type.isCrew).toList();

    // Erkekler + Kadınlar her zaman; Elebaşılar yalnız elebaşı işçi varsa.
    final tabTitles = <String>[
      'Erkekler (${males.length})',
      'Kadınlar (${females.length})',
    ];
    final tabViews = <Widget>[
      _WorkerTabList(
        workers: males,
        tileBuilder: (w) => _IndividualTile(worker: w, settings: settings),
      ),
      _WorkerTabList(
        workers: females,
        tileBuilder: (w) => _IndividualTile(worker: w, settings: settings),
      ),
    ];
    if (crews.isNotEmpty) {
      tabTitles.add('Elebaşılar (${crews.length})');
      tabViews.add(_WorkerTabList(
        workers: crews,
        tileBuilder: (w) => _CrewTile(worker: w, settings: settings),
      ));
    }

    return DefaultTabController(
      length: tabTitles.length,
      child: Column(
        children: [
          TabBar(
            tabs: [for (final t in tabTitles) Tab(text: t)],
          ),
          Expanded(child: TabBarView(children: tabViews)),
        ],
      ),
    );
  }
}

/// Bir sekmenin gövdesi: dolu ise işçi kartları (tembel `ListView.builder` →
/// yalnız görünür kartlar inşa edilir), boşsa kısa bilgi.
class _WorkerTabList extends StatelessWidget {
  const _WorkerTabList({required this.workers, required this.tileBuilder});

  final List<Worker> workers;
  final Widget Function(Worker worker) tileBuilder;

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Bu grupta aktif işçi yok.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: workers.length,
      itemBuilder: (context, i) => tileBuilder(workers[i]),
    );
  }
}

/// Tek bir bireysel işçi satırı — YALNIZ kendi kaydını dinler.
///
/// `attendanceByWorkerForDateProvider.select` ile sadece bu işçinin durumunu
/// izler → başka bir işçiye dokunmak (stream re-emit) bu tile'ı yeniden ÇİZMEZ;
/// yalnız bu işçinin durumu değişince çizilir (kural §7).
class _IndividualTile extends ConsumerWidget {
  const _IndividualTile({required this.worker, required this.settings});

  final Worker worker;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kaydı olmayan işçi → null (hiçbir segment seçili değil). Yoklama
    // alınmayan gün otomatik "Yok" işaretlenmez, hiç sayılmaz. Kayıt bütün
    // olarak izlenir (durum + tarla) ama `.select` sayesinde yalnız BU işçinin
    // kaydı değişince yeniden çizilir.
    final saved = ref.watch(
      attendanceByWorkerForDateProvider
          .select((byWorker) => byWorker[worker.id]),
    );
    final record = saved is IndividualAttendance ? saved : null;
    final vm = ref.read(attendanceViewModelProvider.notifier);
    return IndividualAttendanceTile(
      worker: worker,
      status: record?.status,
      resolvedWageKurus: resolveWageKurus(
        gender: worker.gender,
        overrideKurus: worker.dailyWageOverrideKurus,
        maleWageKurus: settings.defaultWageMaleKurus,
        femaleWageKurus: settings.defaultWageFemaleKurus,
      ),
      // Para/gider kısıtlı hesap yevmiye tutarını görmez (yoklama açık kalır).
      showWage: ref.watch(canSeeMoneyProvider),
      // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
      // Hakedişi geri açınca: `locked: byWorker[worker.id]?.isPaid ?? false`.
      locked: false,
      // Geçmiş günde ilk dokunuş onaydan geçer (yanlışlıkla değişiklik koruması).
      onChanged: (s) =>
          _confirmPastEdit(context, ref, () => vm.setStatus(worker, s)),
      onCleared: () =>
          _confirmPastEdit(context, ref, () => vm.clearStatus(worker)),
      // Tarla seçimi (isteğe bağlı): Tam/Yarım seçilince çipler görünür.
      fields: ref.watch(activeFieldsProvider),
      fieldId: record?.fieldId,
      fieldName: record?.fieldName,
      onFieldChanged: (f) =>
          _confirmPastEdit(context, ref, () => vm.setField(worker, f)),
    );
  }
}

/// Tek bir elebaşı satırı — YALNIZ kendi kaydını dinler.
class _CrewTile extends ConsumerWidget {
  const _CrewTile({required this.worker, required this.settings});

  final Worker worker;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kaydı olan gün kayıtlı sayıyı gösterir; kaydı yoksa işçiye girilen ekip
    // mevcudu (crewSize) ile ÖNDEN DOLU gelir (henüz kaydedilmedi → "Kaydet"
    // kesinleştirir, bkz. _SaveButton.commitCrewDefaults). crewSize==0 ise 0.
    final saved = ref.watch(
      attendanceByWorkerForDateProvider
          .select((byWorker) => byWorker[worker.id]),
    );
    final crew = saved is CrewAttendance ? saved : null;
    final headcount = crew?.headcount ?? worker.crewSize;
    final vm = ref.read(attendanceViewModelProvider.notifier);
    return CrewAttendanceTile(
      name: worker.name,
      headcount: headcount,
      pending: crew == null && headcount > 0,
      crewRateKurus: settings.defaultCrewRateKurus,
      // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
      // Hakedişi geri açınca: `locked: crew?.isPaid ?? false`.
      locked: false,
      // Geçmiş günde ilk dokunuş onaydan geçer (yanlışlıkla değişiklik koruması).
      onChanged: (c) =>
          _confirmPastEdit(context, ref, () => vm.setHeadcount(worker, c)),
      // Tarla seçimi (isteğe bağlı): kişi sayısı girilince çipler görünür.
      fields: ref.watch(activeFieldsProvider),
      fieldId: crew?.fieldId,
      fieldName: crew?.fieldName,
      onFieldChanged: (f) =>
          _confirmPastEdit(context, ref, () => vm.setField(worker, f)),
      // Karta (ad alanına) dokun → bu elebaşı ön-seçili "Avans Ver" ekranı.
      // Avans para → para-kısıtlı hesapta kapalı (ipucu ikonu da görünmez).
      onTap: ref.watch(canSeeMoneyProvider)
          ? () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AdvanceEditScreen(initialWorkerId: worker.id),
                ),
              )
          : null,
    );
  }
}

class _NoActiveWorkers extends StatelessWidget {
  const _NoActiveWorkers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.groups_outlined,
                  size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Aktif işçi yok',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Yoklama almak için İşçiler sekmesinden işçi ekleyin.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
