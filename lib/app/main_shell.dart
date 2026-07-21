/// Kalıcı alt menülü ana kabuk (kural.md §8 / plan §5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/user_access.dart';
import 'theme.dart';

/// 5 büyük alt menü: Ana Sayfa, İşçiler, Yoklama, Avans, Kasa.
/// (Hakediş sekmesi şimdilik rafta — aşağıdaki işaretli bloğu ve router'daki
/// eşi olan branch'i geri açınca dönecek.)
///
/// Para/gider kısıtlı hesapta son iki sekme (Avans, Kasa) gizlenir. Bunlar
/// listenin SONUNDA olduğu için kaldırılınca kalan sekmelerin indeksi (0,1,2)
/// router branch'leriyle hizalı kalır — kayma olmaz.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Aynı sekmeye tekrar basınca kökene dön.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSeeMoney = ref.watch(canSeeMoneyProvider);
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
      if (canSeeMoney)
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Kasa',
        ),
    ];

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
          // Kısıtlı hesapta sekme sayısı düşer; güvenlik için currentIndex'i
          // geçerli aralığa sıkıştır (assert koruması).
          selectedIndex:
              navigationShell.currentIndex.clamp(0, destinations.length - 1),
          onDestinationSelected: _onTap,
          destinations: destinations,
        ),
      ),
    );
  }
}
