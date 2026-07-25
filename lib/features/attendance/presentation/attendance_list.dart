part of 'attendance_screen.dart';

// Yoklama liste gövdesi (sekmeler + işçi/elebaşı satırları, boş durum).
// Ana kütüphane: attendance_screen.dart

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
      // Ödeme kilidi yok (hakediş kaldırıldı) — her gün düzenlenebilir.
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
      // Kişi başı ücret artık işçinin kendi yevmiyesinden (girilmemişse ayar).
      crewRateKurus:
          worker.dailyWageOverrideKurus ?? settings.defaultCrewRateKurus,
      // Para/gider kısıtlı hesap tutarı görmez (kişi sayısı açık kalır).
      showWage: ref.watch(canSeeMoneyProvider),
      // Ödeme kilidi yok (hakediş kaldırıldı) — her gün düzenlenebilir.
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
      // Avans kısıtlı hesaba da açık (2026-07-23) → herkes kullanabilir.
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => AdvanceEditScreen(initialWorkerId: worker.id),
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
