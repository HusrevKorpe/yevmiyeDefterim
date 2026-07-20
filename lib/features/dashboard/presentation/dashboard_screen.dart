/// Ana Sayfa — sanatsal degrade başlık + kompakt bugün özeti (plan §5, kural §8).
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
import '../../auth/application/auth_providers.dart';
import '../application/dashboard_providers.dart';
import '../application/day_summary.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroHeader(
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
                  onRetry: () => ref.invalidate(todaySummaryProvider),
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
    required this.onReport,
    required this.onSettings,
    required this.onLogout,
    required this.onTakeAttendance,
  });

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kHeroTop, kHeroBottom],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                      _HeaderIcon(
                        icon: Icons.assessment_outlined,
                        tooltip: 'Rapor',
                        onPressed: onReport,
                      ),
                      _HeaderIcon(
                        icon: Icons.settings_outlined,
                        tooltip: 'Ayarlar',
                        onPressed: onSettings,
                      ),
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

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Kaç işçi çalıştı" — degrade vurgu kartı (eski işçilik kartının yerine).
        _WorkedHeadlineCard(
          present: summary.presentIndividuals,
          female: summary.femaleCount,
          male: summary.maleCount,
        ),
        const SizedBox(height: 10),
        // Cinsiyet dağılımı.
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Kadın',
                value: '${summary.femaleCount}',
                color: femaleColor(context),
                icon: Icons.woman,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Erkek',
                value: '${summary.maleCount}',
                color: maleColor(context),
                icon: Icons.man,
              ),
            ),
          ],
        ),
        if (summary.crewCount > 0) ...[
          const SizedBox(height: 10),
          _CrewCard(
            crewCount: summary.crewCount,
            headcount: summary.crewHeadcount,
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bugün fiilen çalışan işçi sayısı — başlıkla uyumlu degrade vurgu kart
/// (eski işçilik/para kartının yerine; para gösterilmez).
class _WorkedHeadlineCard extends StatelessWidget {
  const _WorkedHeadlineCard({
    required this.present,
    required this.female,
    required this.male,
  });

  final int present;
  final int female;
  final int male;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [kHeroTop, kHeroBottom],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kHeroBottom.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bugün çalışan',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$present işçi',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          _MiniPill(icon: Icons.woman, count: female),
          const SizedBox(width: 6),
          _MiniPill(icon: Icons.man, count: male),
        ],
      ),
    );
  }
}

/// Degrade kart üzerinde küçük yarı saydam cinsiyet rozeti (ikon + sayı).
class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(height: 1),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elebaşı özeti — kaç elebaşı ve toplam kaç kişi getirdikleri (para yok).
class _CrewCard extends StatelessWidget {
  const _CrewCard({required this.crewCount, required this.headcount});
  final int crewCount;
  final int headcount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Marka yeşili — açıkta 2E7D32 (canlı), koyuda parlak yeşil (koyu zeminde
    // okunur). Yeşil tint yeşil-krem arka planda kayboluyordu → açık temada
    // beyaz kart net ayrışır; koyu temada düz beyaz göze batar → koyu yüzey.
    final color = incomeColor(context);
    final cardColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.white;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.engineering, color: color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$crewCount elebaşı',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Toplam $headcount kişi getirdi',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAttendanceYet extends StatelessWidget {
  const _NoAttendanceYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available,
              size: 30,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bugün henüz yoklama alınmadı',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Yukarıdaki butondan başlayabilirsin.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
