part of 'dashboard_screen.dart';

// Bugün özeti kartları (çalışan sayısı, cinsiyet, elebaşı, boş durum).
// Ana kütüphane: dashboard_screen.dart

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent({required this.summary});
  final DaySummary summary;

  /// Özet kartından yoklamaya geç: istenen grubun sekmesi işaretlenir ve
  /// Yoklama açılır → liste doğrudan o grupla gelir (2026-08-07).
  void _open(BuildContext context, WidgetRef ref, AttendanceTab tab) {
    ref.read(attendanceTabRequestProvider.notifier).request(tab);
    context.go(AppRoutes.attendance);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        // Cinsiyet dağılımı — dokununca yoklamanın o sekmesi açılır.
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Kadın',
                value: '${summary.femaleCount}',
                color: femaleColor(context),
                icon: Icons.woman,
                onTap: () => _open(context, ref, AttendanceTab.females),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Erkek',
                value: '${summary.maleCount}',
                color: maleColor(context),
                icon: Icons.man,
                onTap: () => _open(context, ref, AttendanceTab.males),
              ),
            ),
          ],
        ),
        if (summary.crewCount > 0) ...[
          const SizedBox(height: 10),
          _CrewCard(
            crewCount: summary.crewCount,
            headcount: summary.crewHeadcount,
            onTap: () => _open(context, ref, AttendanceTab.crews),
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
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dolgu/kenarlık dıştaki Container'da kalır; dokunma dalgası görünsün diye
    // içeride saydam bir Material bulunur (aksi halde dalga zeminin ALTINDA
    // kalır ve hiç görünmez).
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
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
          ),
        ),
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
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [heroTop(context), heroBottom(context)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: heroBottom(context).withValues(alpha: 0.24),
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
  const _CrewCard({
    required this.crewCount,
    required this.headcount,
    required this.onTap,
  });
  final int crewCount;
  final int headcount;
  final VoidCallback onTap;

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
      // Dokunma dalgası kart zemininin ÜSTÜNDE çizilsin diye saydam Material.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
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
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: color.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
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
