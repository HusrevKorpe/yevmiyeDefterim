/// Yoklama ekranı (plan §5, kural §8) — tarih seç + Tam/Yarım/Yok + elebaşı sayacı.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/routes.dart';
import '../../../core/date/app_date.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/app_settings.dart';
import '../../workers/application/workers_providers.dart';
import '../../workers/data/worker.dart';
import '../application/attendance_providers.dart';
import '../application/attendance_view_model.dart';
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
        title: 'Yoklama',
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

/// Sağ üstteki "Kaydet" düğmesi.
///
/// NOT: Yoklama zaten her dokunuşta otomatik kaydediliyor (bkz.
/// [attendanceViewModelProvider] → setStatus/setHeadcount doğrudan Firestore'a
/// yazar). Bu düğme fiilen kayıt tetiklemez; kullanıcıya "günün yoklaması
/// kaydedildi" güvencesi vermek için görsel/dokunsal onay üretir.
class _SaveButton extends ConsumerWidget {
  const _SaveButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.mediumImpact();
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
      },
      icon: const Icon(Icons.check, color: Colors.white, size: 20),
      label: const Text(
        'Kaydet',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar();

  Future<void> _pick(BuildContext context, WidgetRef ref, String date) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseIsoDate(date),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Yoklama tarihi',
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).set(toIsoDate(picked));
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

class _List extends ConsumerWidget {
  const _List({required this.active, required this.settings});

  final List<Worker> active;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records =
        ref.watch(attendanceForSelectedDateProvider).asData?.value ?? const [];
    final byWorker = {for (final r in records) r.workerId: r};
    final vm = ref.read(attendanceViewModelProvider.notifier);

    // Bireysel işçiler cinsiyete göre ayrı sekmelere düşer (Erkekler / Kadınlar).
    // Her grup kendi içinde ada göre sıralı kalır (compareWorkers).
    final males = active
        .where((w) => w.type.isIndividual && w.gender == Gender.male)
        .toList();
    final females = active
        .where((w) => w.type.isIndividual && w.gender == Gender.female)
        .toList();
    final crews = active.where((w) => w.type.isCrew).toList();

    Widget individualTile(Worker w) => IndividualAttendanceTile(
          worker: w,
          status: switch (byWorker[w.id]) {
            IndividualAttendance(:final status) => status,
            _ => AttendanceStatus.absent,
          },
          resolvedWageKurus: resolveWageKurus(
            gender: w.gender,
            overrideKurus: w.dailyWageOverrideKurus,
            maleWageKurus: settings.defaultWageMaleKurus,
            femaleWageKurus: settings.defaultWageFemaleKurus,
          ),
          // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
          // Hakedişi geri açınca: `locked: byWorker[w.id]?.isPaid ?? false`.
          locked: false,
          onChanged: (s) => vm.setStatus(w, s),
        );

    Widget crewTile(Worker w) => CrewAttendanceTile(
          name: w.name,
          headcount: switch (byWorker[w.id]) {
            CrewAttendance(:final headcount) => headcount,
            _ => 0,
          },
          crewRateKurus: settings.defaultCrewRateKurus,
          // --- ÖDEME KİLİDİ ŞİMDİLİK RAFTA (hakediş ile birlikte) ---
          // Hakedişi geri açınca: `locked: byWorker[w.id]?.isPaid ?? false`.
          locked: false,
          onChanged: (c) => vm.setHeadcount(w, c),
        );

    // Erkekler + Kadınlar her zaman; Elebaşılar yalnız elebaşı işçi varsa.
    final tabTitles = <String>[
      'Erkekler (${males.length})',
      'Kadınlar (${females.length})',
    ];
    final tabViews = <Widget>[
      _TabList(tiles: [for (final w in males) individualTile(w)]),
      _TabList(tiles: [for (final w in females) individualTile(w)]),
    ];
    if (crews.isNotEmpty) {
      tabTitles.add('Elebaşılar (${crews.length})');
      tabViews.add(_TabList(tiles: [for (final w in crews) crewTile(w)]));
    }

    return DefaultTabController(
      length: tabTitles.length,
      child: Column(
        children: [
          if (settings == AppSettings.empty) const _WagesUnsetBanner(),
          TabBar(
            tabs: [for (final t in tabTitles) Tab(text: t)],
          ),
          Expanded(child: TabBarView(children: tabViews)),
        ],
      ),
    );
  }
}

/// Tek bir sekmenin gövdesi: dolu ise işçi kartları listesi, boşsa kısa bilgi.
class _TabList extends StatelessWidget {
  const _TabList({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
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
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: tiles,
    );
  }
}

class _WagesUnsetBanner extends StatelessWidget {
  const _WagesUnsetBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Yevmiyeler henüz girilmemiş. Doğru hesap için Ayarlardan girin.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.settings),
              child: const Text('Ayarlar'),
            ),
          ],
        ),
      ),
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
