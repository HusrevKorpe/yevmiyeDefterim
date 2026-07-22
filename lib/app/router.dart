/// Yönlendirme — go_router `StatefulShellRoute` + auth kapısı (plan §1, kural §9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/routes.dart';
import '../features/advances/presentation/advances_screen.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/attendance/presentation/fields_screen.dart';
import '../features/attendance/presentation/monthly_attendance_screen.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/application/user_access.dart';
import '../features/auth/data/app_user.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/ledger/presentation/ledger_screen.dart';
// Hakediş şimdilik rafta — geri açınca bu import'u da aç.
// import '../features/payroll/presentation/payroll_screen.dart';
import '../features/reports/presentation/report_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/workers/presentation/workers_screen.dart';
import 'main_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Uygulama router'ı. Auth durumu değiştikçe `refreshListenable` ile yeniden
/// değerlendirilir; giriş yoksa `/giris`'e, giriş varsa ana sayfaya yönlendirir.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  // Başlangıç durumu senkron currentUser'dan (offline'da diskten gelir),
  // sonraki değişiklikler authStateProvider akışından.
  final authNotifier = ValueNotifier<AppUser?>(
    ref.read(authRepositoryProvider).currentUser,
  );
  ref.onDispose(authNotifier.dispose);
  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, next) {
    authNotifier.value = next.asData?.value;
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = authNotifier.value;
      final loggedIn = user != null;
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn) return atLogin ? null : AppRoutes.login;
      if (atLogin) return AppRoutes.home;
      // Para/gider kısıtlı hesap para ekranlarına giremez — derin link ya da
      // geri tuşuyla da sızmasın diye ana sayfaya döndürülür (sekmeleri zaten
      // main_shell gizler; bu router katmanı ikinci güvenlik hattıdır).
      // Aylık yoklama BİLEREK listede yok: erişilebilir kalır, sadece
      // içindeki tutarlar gizlenir (bkz. monthly_attendance_screen).
      // Giderler (/kasa) da BİLEREK listede yok: kısıtlı hesap gider
      // girebilsin/görebilsin diye açıldı (main_shell'de sekmesi de görünür).
      if (isMoneyRestricted(user.email)) {
        const blocked = <String>{
          AppRoutes.advances,
          AppRoutes.report,
          AppRoutes.settings,
          AppRoutes.payroll,
        };
        if (blocked.contains(state.matchedLocation)) return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.report,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.monthlyAttendance,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MonthlyAttendanceScreen(),
      ),
      // Tarlalar BİLEREK kısıtlı-hesap engel listesinde yok: para içermez,
      // yoklama gibi herkese açıktır (bkz. redirect'teki `blocked`).
      GoRoute(
        path: AppRoutes.fields,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FieldsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.workers,
                builder: (context, state) => const WorkersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.attendance,
                builder: (context, state) => const AttendanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.advances,
                builder: (context, state) => const AdvancesScreen(),
              ),
            ],
          ),
          // --- HAKEDİŞ ŞİMDİLİK RAFTA ---
          // Geri açmak için bu branch'i ve main_shell.dart'taki eşi olan
          // Hakediş destination'ını birlikte aç (ikisinin sırası eşleşmeli).
          // StatefulShellBranch(
          //   routes: [
          //     GoRoute(
          //       path: AppRoutes.payroll,
          //       builder: (context, state) => const PayrollScreen(),
          //     ),
          //   ],
          // ),
          // --- /HAKEDİŞ ---
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ledger,
                builder: (context, state) => const LedgerScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
