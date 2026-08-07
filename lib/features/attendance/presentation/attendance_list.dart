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

/// İşçileri sekmelere ayırır (Erkekler / Kadınlar / Elebaşılar). Yoklama
/// akışını İZLEMEZ → bir işçiye dokunmak bu ağacı yeniden kurmaz; yalnız
/// `active`/`settings` değişince (nadir) yeniden çizilir. Her satırın güncel
/// durumu, satırın kendi `Consumer`'ında `.select` ile alınır.
///
/// Sekme denetleyicisi elde tutulur (DefaultTabController yerine): Ana Sayfa
/// özet kartından gelen [attendanceTabRequestProvider] isteğiyle doğru sekme
/// açılabilsin diye (ekran yeniyse `initialIndex`, zaten açıksa `animateTo`).
class _List extends ConsumerStatefulWidget {
  const _List({required this.active, required this.settings});

  final List<Worker> active;
  final AppSettings settings;

  @override
  ConsumerState<_List> createState() => _ListState();
}

class _ListState extends ConsumerState<_List> with TickerProviderStateMixin {
  // Bireysel işçiler cinsiyete göre ayrı sekmelere düşer (Erkekler / Kadınlar).
  // Her grup kendi içinde ada göre sıralı kalır (compareWorkers).
  late List<Worker> _males;
  late List<Worker> _females;
  late List<Worker> _crews;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _split();
    // Ana Sayfa kartından gelindiyse ekran DOĞRUDAN o sekmeyle açılır (Yoklama
    // ilk kez açılıyorsa bu yol çalışır; zaten açıksa build'deki dinleyici).
    _tabs = TabController(
      length: _tabCount,
      initialIndex: _indexOf(ref.read(attendanceTabRequestProvider)),
      vsync: this,
    );
    // İsteği tüketmek provider yazmaktır → build sırasında değil, kare sonunda.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(attendanceTabRequestProvider.notifier).consume();
    });
  }

  @override
  void didUpdateWidget(covariant _List oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _tabCount;
    _split();
    // Elebaşı sekmesi belirip kaybolabilir → uzunluk değişince denetleyici
    // yenilenir, seçili sekme sınır içinde korunur.
    if (previous != _tabCount) {
      final index = _tabs.index.clamp(0, _tabCount - 1);
      _tabs.dispose();
      _tabs = TabController(
        length: _tabCount,
        initialIndex: index,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _split() {
    final active = widget.active;
    _males = active
        .where((w) => w.type.isIndividual && w.gender == Gender.male)
        .toList();
    _females = active
        .where((w) => w.type.isIndividual && w.gender == Gender.female)
        .toList();
    _crews = active.where((w) => w.type.isCrew).toList();
  }

  /// Erkekler + Kadınlar her zaman; Elebaşılar yalnız elebaşı işçi varsa.
  int get _tabCount => _crews.isEmpty ? 2 : 3;

  /// İstenen grubun sekme sırası. İstek yoksa (ya da elebaşı sekmesi yokken
  /// elebaşı istendiyse) varsayılan ilk sekmede kalınır.
  int _indexOf(AttendanceTab? tab) => switch (tab) {
        AttendanceTab.males || null => 0,
        AttendanceTab.females => 1,
        AttendanceTab.crews => _crews.isEmpty ? 0 : 2,
      };

  @override
  Widget build(BuildContext context) {
    // Yoklama ZATEN açıkken gelen istek (Ana Sayfa kartı → alt sekme değişimi)
    // → o sekmeye kayar ve istek tüketilir.
    ref.listen<AttendanceTab?>(attendanceTabRequestProvider, (_, next) {
      if (next == null) return;
      final index = _indexOf(next);
      if (_tabs.index != index) _tabs.animateTo(index);
      ref.read(attendanceTabRequestProvider.notifier).consume();
    });

    final tabTitles = <String>[
      'Erkekler (${_males.length})',
      'Kadınlar (${_females.length})',
      if (_crews.isNotEmpty) 'Elebaşılar (${_crews.length})',
    ];
    final tabViews = <Widget>[
      _WorkerTabList(
        workers: _males,
        tileBuilder: (w) =>
            _IndividualTile(worker: w, settings: widget.settings),
      ),
      _WorkerTabList(
        workers: _females,
        tileBuilder: (w) =>
            _IndividualTile(worker: w, settings: widget.settings),
      ),
      if (_crews.isNotEmpty)
        _WorkerTabList(
          workers: _crews,
          tileBuilder: (w) => _CrewTile(worker: w, settings: widget.settings),
        ),
    ];

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [for (final t in tabTitles) Tab(text: t)],
        ),
        Expanded(child: TabBarView(controller: _tabs, children: tabViews)),
      ],
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
      // Kayıt varsa DONDURULMUŞ ücret okunur (kural §4: geçmiş ücret yeniden
      // türetilmez → rapor/aylık tablo/net bakiye ile aynı sayı). Kaydı yoksa
      // güncel yevmiye önden gösterilir.
      resolvedWageKurus: record?.wageSnapshotKurus ??
          resolveWageKurus(
            gender: worker.gender,
            overrideKurus: worker.dailyWageOverrideKurus,
            maleWageKurus: settings.defaultWageMaleKurus,
            femaleWageKurus: settings.defaultWageFemaleKurus,
          ),
      // Para/gider kısıtlı hesap yevmiye tutarını görmez (yoklama açık kalır).
      showWage: ref.watch(canSeeMoneyProvider),
      // Ödeme kilidi yok (hakediş kaldırıldı) — her gün düzenlenebilir.
      locked: false,
      // Kaydedilmiş ya da geçmiş günde ilk dokunuş onaydan geçer (yanlışlıkla
      // değişiklik koruması).
      onChanged: (s) =>
          _confirmProtectedEdit(context, ref, () => vm.setStatus(worker, s)),
      onCleared: () =>
          _confirmProtectedEdit(context, ref, () => vm.clearStatus(worker)),
      // Tarla + yapılan iş (ikisi de isteğe bağlı, birbirinden bağımsız):
      // Tam/Yarım seçilince iki çip şeridi görünür.
      plots: ref.watch(activePlotsProvider),
      plotId: record?.plotId,
      plotName: record?.plotName,
      onPlotChanged: (p) =>
          _confirmProtectedEdit(context, ref, () => vm.setPlot(worker, p)),
      jobs: ref.watch(activeJobsProvider),
      jobId: record?.jobId,
      jobName: record?.jobName,
      onJobChanged: (j) =>
          _confirmProtectedEdit(context, ref, () => vm.setJob(worker, j)),
      // Mesai (isteğe bağlı): Tam/Yarım seçilince saat çipleri görünür.
      overtimeHours: record?.overtimeHours ?? 0,
      // Kayıtta mesai varsa DONDURULMUŞ saat ücreti okunur (kural §4 — yevmiye
      // snapshot'ıyla aynı); yoksa güncel ücret önden gösterilir: Yönetim'deki
      // genel mesai ücreti, işçinin kendi istisnası varsa o (hiçbiri yoksa 0 →
      // şeritte uyarı çıkar).
      overtimeRateKurus: (record != null && record.overtimeRateSnapshotKurus > 0)
          ? record.overtimeRateSnapshotKurus
          : resolveOvertimeRateKurus(
              workerHourlyKurus: worker.overtimeHourlyKurus,
              defaultHourlyKurus: settings.overtimeHourlyKurus,
            ),
      onOvertimeChanged: (h) =>
          _confirmProtectedEdit(context, ref, () => vm.setOvertimeHours(worker, h)),
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
      // Kayıt varsa DONDURULMUŞ kişi-başı ücret okunur (kural §4: geçmiş ücret
      // yeniden türetilmez → satırdaki "N × ₺X = ₺toplam" rapor/net bakiye ile
      // aynı). Kaydı yoksa işçinin güncel yevmiyesi (girilmemişse ayar) önden.
      crewRateKurus: crew?.crewRateSnapshotKurus ??
          (worker.dailyWageOverrideKurus ?? settings.defaultCrewRateKurus),
      // Para/gider kısıtlı hesap tutarı görmez (kişi sayısı açık kalır).
      showWage: ref.watch(canSeeMoneyProvider),
      // Ödeme kilidi yok (hakediş kaldırıldı) — her gün düzenlenebilir.
      locked: false,
      // Kaydedilmiş ya da geçmiş günde ilk dokunuş onaydan geçer (yanlışlıkla
      // değişiklik koruması).
      onChanged: (c) =>
          _confirmProtectedEdit(context, ref, () => vm.setHeadcount(worker, c)),
      // Tarla + yapılan iş (ikisi de isteğe bağlı): kişi sayısı girilince iki
      // çip şeridi görünür.
      plots: ref.watch(activePlotsProvider),
      plotId: crew?.plotId,
      plotName: crew?.plotName,
      onPlotChanged: (p) =>
          _confirmProtectedEdit(context, ref, () => vm.setPlot(worker, p)),
      jobs: ref.watch(activeJobsProvider),
      jobId: crew?.jobId,
      jobName: crew?.jobName,
      onJobChanged: (j) =>
          _confirmProtectedEdit(context, ref, () => vm.setJob(worker, j)),
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
