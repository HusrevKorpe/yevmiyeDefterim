/// Ana Sayfa — sanatsal degrade başlık + kompakt bugün özeti (plan §5, kural §8).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/routes.dart';
import '../../../core/date/app_date.dart';
import '../../../core/notifications/push_notifications.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/user_access.dart';
import '../application/dashboard_providers.dart';
import '../application/day_summary.dart';

part 'dashboard_summary_cards.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Çıkış',
      message: 'Oturumu kapatmak istediğinize emin misiniz?',
      confirmLabel: 'Çıkış Yap',
      icon: Icons.logout,
    );
    if (ok) {
      // ÖNCE cihazın push kaydını bırak (oturum hâlâ açıkken — çıkıştan sonra
      // silme yetkisi kalmaz), SONRA çık. Bu cihaz artık bildirim almamalı.
      await releasePushToken();
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);
    final canSeeMoney = ref.watch(canSeeMoneyProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroHeader(
            // Rapor ve Yönetim para/gider içerir → kısıtlı hesapta gizli.
            canSeeMoney: canSeeMoney,
            onReport: () => context.push(AppRoutes.report),
            onSettings: () => context.push(AppRoutes.settings),
            onLogout: () => _confirmLogout(context, ref),
            onTakeAttendance: () => context.go(AppRoutes.attendance),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Bugün Özeti'),
                const SizedBox(height: 10),
                AsyncRetry(
                  value: summaryAsync,
                  onRetry: () => refreshTodaySummary(ref),
                  message:
                      'Özet yüklenemedi. İnternet bağlantınızı kontrol edin.',
                  data: (summary) {
                    if (summary.markedIndividuals == 0 &&
                        summary.crewCount == 0) {
                      return const _NoAttendanceYet();
                    }
                    return _SummaryContent(summary: summary);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Degrade "hero" başlık: selamlama, tarih, kısayol ikonları ve ana eylem.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.canSeeMoney,
    required this.onReport,
    required this.onSettings,
    required this.onLogout,
    required this.onTakeAttendance,
  });

  /// Para/gider görebilir mi? false → Rapor + Yönetim ikonları gizlenir.
  final bool canSeeMoney;
  final VoidCallback onReport;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final VoidCallback onTakeAttendance;

  String _greeting(int hour) {
    if (hour < 6) return 'İyi geceler';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final greeting = _greeting(DateTime.now().hour);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          gradient: heroGradient(context),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Stack(
          children: [
            // Derinlik için soluk dekoratif daireler.
            Positioned(
              top: -36,
              right: -28,
              child: _decorCircle(150, 0.09),
            ),
            Positioned(
              top: 54,
              right: 46,
              child: _decorCircle(84, 0.07),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 12, 12, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatHumanDate(todayIso()),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canSeeMoney) ...[
                        _HeaderIcon(
                          icon: Icons.assessment_outlined,
                          tooltip: 'Rapor',
                          onPressed: onReport,
                        ),
                        _HeaderIcon(
                          icon: Icons.space_dashboard_outlined,
                          tooltip: 'Yönetim',
                          onPressed: onSettings,
                        ),
                      ],
                      _HeaderIcon(
                        icon: Icons.logout,
                        tooltip: 'Çıkış',
                        onPressed: onLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AttendanceCta(onPressed: onTakeAttendance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );
}

/// Başlıktaki yarı saydam kısayol ikonu.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
      ),
    );
  }
}

/// Beyaz "hap" biçimli ana eylem — degrade üzerinde güçlü kontrast.
class _AttendanceCta extends StatelessWidget {
  const _AttendanceCta({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kHeroBottom.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.fact_check, color: kHeroBottom, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugün Yoklama Al',
                      style: TextStyle(
                        color: kHeroBottom,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'İşçileri tek tek işaretle',
                      style: TextStyle(
                        color: Color(0xFF6B7C6E),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: kHeroBottom, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

