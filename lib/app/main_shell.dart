/// Kalıcı alt menülü ana kabuk (kural.md §8 / plan §5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/user_access.dart';
import 'theme.dart';

/// 5 büyük alt menü: Ana Sayfa, İşçiler, Yoklama, Avans, Giderler.
/// (Hakediş sekmesi şimdilik rafta — aşağıdaki işaretli bloğu ve router'daki
/// eşi olan branch'i geri açınca dönecek.)
///
/// Para/gider kısıtlı hesapta yalnız Avans sekmesi gizlenir; Giderler AÇIK
/// kalır (kısıtlı hesap gider girebilsin diye). Avans ortadan kalkınca görünür
/// sekme sırası ile router branch indeksi kayar → `branchIndexes` eşlemesi
/// görünür sekmeyi doğru branch'e çevirir.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int branchIndex) {
    navigationShell.goBranch(
      branchIndex,
      // Aynı sekmeye tekrar basınca kökene dön.
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeMoney = ref.watch(canSeeMoneyProvider);
    // Router branch sırası: 0=Ana Sayfa, 1=İşçiler, 2=Yoklama, 3=Avans,
    // 4=Giderler. `destinations` ile birebir aynı koşullarla kurulmalı.
    final branchIndexes = <int>[0, 1, 2, if (canSeeMoney) 3, 4];
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
      // --- HAKEDİŞ ŞİMDİLİK RAFTA ---
      // Geri açmak için router.dart'taki payroll branch'i ile birlikte, buraya
      // İşçiler'den sonraki uygun sıraya Hakediş destination'ı ekle.
      // --- /HAKEDİŞ ---
      if (canSeeMoney)
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

    // Aktif branch görünür sekmelerden birine denk gelmiyorsa (ör. kısıtlı
    // hesapta Avans branch'i) ilk sekmeyi işaretle.
    final selectedIndex = branchIndexes.indexOf(navigationShell.currentIndex);

    return Scaffold(
      body: navigationShell,
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
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          // Görünür sekme indeksini gerçek branch indeksine çevir.
          onDestinationSelected: (i) => _onTap(branchIndexes[i]),
          destinations: destinations,
        ),
      ),
    );
  }
}
