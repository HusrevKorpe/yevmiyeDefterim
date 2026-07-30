/// Kalıcı alt menülü ana kabuk (kural.md §8 / plan §5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/date/app_date.dart';
import '../core/widgets/app_dialog.dart';
import '../features/attendance/application/attendance_providers.dart';
import '../features/auth/application/user_access.dart';
import '../features/workers/application/workers_providers.dart';
import '../features/workers/data/worker.dart';
import 'theme.dart';
import 'update_notice.dart';

/// 5 büyük alt menü: Ana Sayfa, İşçiler, Yoklama, Avans, Giderler.
///
/// Para/gider kısıtlı hesapta da BÜTÜN sekmeler görünür (2026-07-23'te Avans
/// da açıldı); kısıt yalnız yevmiye tutarı gizleme + Rapor/Yönetim
/// erişiminde kaldı (bkz. user_access.dart / router redirect). Bir sekme
/// yeniden koşullu gizlenecek olursa görünür sıra ile router branch indeksi
/// kayar → eski `branchIndexes` eşleme desenini git geçmişinden geri getir.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  /// Yevmiye hatırlatması bu oturumda değerlendirildi mi (tekrar tekrar
  /// tetiklenmesin — sekme değişimi build'i yeniden çağırır).
  bool _wageNoticeHandled = false;

  /// Uygulama öne alındığında gün değiştiyse "bugün"e bağlı sağlayıcıları
  /// tazelemek için son bilinen yerel iş günü (`'yyyy-MM-dd'`).
  late String _lastKnownDay;

  @override
  void initState() {
    super.initState();
    _lastKnownDay = todayIso();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Gece yarısı devri: telefon arka planda kalıp ertesi gün öne alınınca
  /// "bugün"e sabitlenen sağlayıcılar (Ana Sayfa özeti, bugünün yoklaması)
  /// dünü gösterir; yoklama ekranı dün açılır (sabah erken saha kullanımı).
  /// Öne gelişte gün değişmişse bunları tazeleriz. Sağlayıcı gövdeleri
  /// [todayIso]'yu kuruluşta bir kez okur → yalnız yeniden kurulunca (invalidate)
  /// yeni günü alır; arka plan/ön plan geçişi widget'ları yok etmez.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = todayIso();
    if (now == _lastKnownDay) return;
    final previousDay = _lastKnownDay;
    _lastKnownDay = now;
    // Bugüne sabitli akış yeni günü çeksin. Ana Sayfa özeti bundan TÜRETİLİR
    // (todaySummaryProvider) → ayrıca invalidate gerekmez, kendiliğinden
    // yeniden hesaplanır.
    ref.invalidate(todayAttendanceProvider);
    // Yoklama ekranı hâlâ "dünde" (kullanıcı elle başka güne gitmediyse) →
    // yeni güne kaydır; elle seçilmiş gün korunur.
    ref.read(selectedDateProvider.notifier).rolloverIfOnDay(previousDay);
  }

  void _onTap(int branchIndex) {
    widget.navigationShell.goBranch(
      branchIndex,
      // Aynı sekmeye tekrar basınca kökene dön.
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  /// Güncelleme sonrası BİR KEZ (cihaz başına): yevmiyesi girilmemiş işçi/elebaşı
  /// varsa hatırlatma diyaloğu gösterir. Yalnız para görebilen hesapta anlamlı
  /// (kısıtlı hesap yevmiye giremez → atlanır, bayrak tüketilmez).
  ///
  /// Karar ve prefs yazımı build İÇİNDE yapılamaz (Riverpod: build sırasında
  /// provider değiştirilemez) → koşullar sağlanınca iş post-frame'e ertelenir.
  void _maybeScheduleWageReminder() {
    if (_wageNoticeHandled) return;
    if (ref.read(wageReminderSeenProvider)) {
      _wageNoticeHandled = true;
      return;
    }
    // Yevmiye giremeyen (kısıtlı) hesapta hiç gösterme, bayrağı da tüketme.
    if (!ref.read(canSeeMoneyProvider)) return;
    // İşçiler yüklenene dek bekle (yükleniyorken tetikleme → hatırlatmayı kaçırma).
    if (!ref.read(workersStreamProvider).hasValue) return;

    // Yalnız bir kez zamanla (senkron guard) → build sonrası değerlendir + yaz.
    _wageNoticeHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final missing = ref.read(workersMissingWageProvider);
      // Değerlendirme yapıldı → bu güncelleme notu bir daha çıkmasın.
      ref.read(wageReminderSeenProvider.notifier).markSeen();
      if (missing.isEmpty) return;
      _showWageReminderDialog(missing);
    });
  }

  Future<void> _showWageReminderDialog(List<Worker> missing) async {
    final goToWorkers = await showDialog<bool>(
      context: context,
      builder: (_) => _WageReminderDialog(missing: missing),
    );
    if (goToWorkers ?? false) {
      // İşçiler sekmesi (branch 1) → kullanıcı hemen düzenleyebilsin.
      widget.navigationShell.goBranch(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // İşçiler yüklendiğinde (hasValue true olunca) hatırlatmayı bir kez değerlendir.
    // `.select` → yalnız yüklendi/yüklenmedi değişince bu kabuk yeniden çizilir.
    ref.watch(workersStreamProvider.select((a) => a.hasValue));
    _maybeScheduleWageReminder();

    // Router branch sırası: 0=Ana Sayfa, 1=İşçiler, 2=Yoklama, 3=Avans,
    // 4=Giderler — `destinations` ile birebir aynı sırada.
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Ana Sayfa',
      ),
      const NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: 'İşçiler',
      ),
      const NavigationDestination(
        icon: Icon(Icons.fact_check_outlined),
        selectedIcon: Icon(Icons.fact_check),
        label: 'Yoklama',
      ),
      const NavigationDestination(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments),
        label: 'Avans',
      ),
      const NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: 'Giderler',
      ),
    ];

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        // Appbar'daki hero degradesinin eşi → ekranı yeşil bir "çerçeve" içine
        // alır. Renk/indicator beyaz ayarı theme.dart navigationBarTheme'de.
        // Tema-duyarlı: koyu temada zeminle kaynaşan derin yeşil.
        decoration: BoxDecoration(gradient: heroGradient(context)),
        child: NavigationBar(
          // Varsayılan 80 px çok boşluk bırakıyordu; barı alçaltınca ortalanan
          // ikon+etiket içeriği de aşağı kayar (bar alta sabittir).
          height: 64,
          backgroundColor: Colors.transparent,
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: destinations,
        ),
      ),
    );
  }
}

/// Güncelleme hatırlatması — yevmiyesi girilmemiş işçi/elebaşıları listeler.
/// Dönüş: `true` = "İşçilere Git", aksi (null/false) = kapat.
class _WageReminderDialog extends StatelessWidget {
  const _WageReminderDialog({required this.missing});

  final List<Worker> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = cs.primary;
    return AppDialog(
      icon: Icons.request_quote_outlined,
      title: 'Yevmiye girin',
      message: 'Bu güncellemeyle elebaşılara da yevmiye girilebiliyor. '
          'Yevmiyesi girilmemiş ${missing.length} kişi var — lütfen '
          'İşçiler sekmesinden her birine yevmiyesini girin.',
      confirmLabel: 'İşçilere Git',
      cancelLabel: 'Daha sonra',
      onConfirm: () => Navigator.pop(context, true),
      onCancel: () => Navigator.pop(context, false),
      scrollable: true,
      // Yevmiyesiz kişilerin listesi — kaydırılabilir, tonlu kutu içinde.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: missing.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            itemBuilder: (_, i) {
              final w = missing[i];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  w.type.isCrew ? Icons.groups : Icons.person,
                  size: 20,
                  color: accent,
                ),
                title: Text(w.name),
                trailing: Text(
                  w.type.label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
