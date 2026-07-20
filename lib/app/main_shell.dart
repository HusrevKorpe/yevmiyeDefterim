/// Kalıcı alt menülü ana kabuk (kural.md §8 / plan §5).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 5 büyük alt menü: Ana Sayfa, Yoklama, İşçiler, Avans, Kasa.
/// (Hakediş sekmesi şimdilik rafta — aşağıdaki işaretli bloğu ve router'daki
/// eşi olan branch'i geri açınca dönecek.)
class MainShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        // Varsayılan 80 px çok boşluk bırakıyordu; barı alçaltınca ortalanan
        // ikon+etiket içeriği de aşağı kayar (bar alta sabittir).
        height: 64,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Yoklama',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'İşçiler',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Avans',
          ),
          // --- HAKEDİŞ ŞİMDİLİK RAFTA ---
          // Geri açmak için bu destination'ı ve router.dart'taki eşi olan
          // payroll branch'ini birlikte aç (ikisinin sırası eşleşmeli).
          // NavigationDestination(
          //   icon: Icon(Icons.payments_outlined),
          //   selectedIcon: Icon(Icons.payments),
          //   label: 'Hakediş',
          // ),
          // --- /HAKEDİŞ ---
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Kasa',
          ),
        ],
      ),
    );
  }
}
