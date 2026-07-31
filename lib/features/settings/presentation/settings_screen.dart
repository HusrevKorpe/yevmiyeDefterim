/// Yönetim ekranı — mesai saat ücreti + görünüm (koyu tema) + veri yedeği.
///
/// Sabit/varsayılan YEVMİYE burada YOK: her işçinin yevmiyesi İşçiler
/// ekranından tek tek elle girilir (yoklamada o işçinin kendi yevmiyesi
/// kullanılır). MESAİ saat ücreti bilerek tersi yönde: sahada herkes için aynı
/// olduğundan tek yerden burada girilir, tüm işçilere uygulanır; bir işçininki
/// farklıysa işçi kartındaki alan bunu ezer (bkz. `resolveOvertimeRateKurus`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/theme_mode.dart';
import '../../../core/diagnostics/app_log.dart';
import '../../../core/firestore/firestore_providers.dart';
import '../../../core/firestore/write_ack.dart';
import '../../../core/money/money.dart';
import '../../../core/notifications/push_notifications.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/money_field.dart';
import '../application/backup_service.dart';
import '../application/settings_providers.dart';
import '../data/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backingUp = false;

  /// Tüm veriyi JSON dosyasına aktarıp paylaşım yaprağını açar (yedek).
  Future<void> _backup() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fromCache = await shareBackup(ref.read(firestoreProvider));
      // Çevrimdışı alınan yedek cihaz önbelleğinden gelir → en güncel/eksiksiz
      // veriyi içermeyebilir. Sessiz kalma; kullanıcı bilsin ki internete
      // bağlanıp yeniden alsın (yedek tek güvenlik ağı).
      if (fromCache) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Çevrimdışısınız — yedek cihazdaki önbellekten alındı, en '
              'güncel veriyi içermeyebilir. İnternete bağlanıp tekrar alın.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e, s) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Yedek alınamadı. İnternet bağlantınızı kontrol edin.'),
        ),
      );
      await logHandledError(e, s, reason: 'yedek-al');
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Yönetim'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Mesai'),
            const SizedBox(height: 8),
            const _OvertimeRateSection(),
            const SizedBox(height: 28),
            const SectionTitle('Görünüm'),
            const SizedBox(height: 10),
            const _DarkModeSwitch(),
            const _NotificationStatus(),
            const SizedBox(height: 28),
            const SectionTitle('Veri Yedeği'),
            const SizedBox(height: 8),
            Text(
              'Tüm kayıtları (işçi, yoklama, avans, gider) tek bir dosyaya '
              'aktarır. Yanlışlıkla silmeye karşı ara sıra yedek alıp '
              'Drive’a veya e-postaya kaydedin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _backingUp ? null : _backup,
              icon: _backingUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_outlined),
              label: Text(_backingUp ? 'Hazırlanıyor…' : 'Yedek Al (JSON)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mesai saat ücreti — HERKES için tek giriş.
///
/// Ücret [AppSettings.overtimeHourlyKurus] alanında tek config dokümanında
/// tutulur; yoklamada mesai saatiyle çarpılır. Kaydedilen ücret GEÇMİŞ günleri
/// oynatmaz: her yoklama kaydı kendi saat ücretini o an dondurur (kural §4) →
/// buradaki değişiklik yalnız bundan SONRA girilen mesailere işler.
class _OvertimeRateSection extends ConsumerStatefulWidget {
  const _OvertimeRateSection();

  @override
  ConsumerState<_OvertimeRateSection> createState() =>
      _OvertimeRateSectionState();
}

class _OvertimeRateSectionState extends ConsumerState<_OvertimeRateSection> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  /// Alan kayıtlı değerle BİR KEZ doldurulur. Sonraki akış olayları (başka
  /// cihazdan yazma) alanı EZMEZ — kullanıcı o sırada yazıyor olabilir.
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Doldurma build'de DEĞİL dinleyicide yapılır: build sırasında controller
    // metnini değiştirmek, çoktan çizilmiş TextField'ı build içinde yeniden
    // çizmeye zorlar (markNeedsBuild hatası).
    ref.listenManual<AsyncValue<AppSettings>>(
      settingsStreamProvider,
      (_, next) {
        final s = next.asData?.value;
        if (s == null || _seeded) return;
        _seeded = true;
        _ctrl.text = s.overtimeHourlyKurus == 0
            ? ''
            : formatKurusPlain(s.overtimeHourlyKurus);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppSettings current) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    // Boş bırakmak "ücret girilmemiş" demektir (0) → mesai girilse bile tutar
    // 0 kalır ve yoklama satırı uyarır (yevmiyesi girilmemiş işçiyle aynı desen).
    final kurus = parseTlToKurus(_ctrl.text.trim()) ?? 0;
    try {
      // Offline'da yazım yerel kuyruğa girer; onayı sonsuza dek bekleyip
      // düğmeyi kilitlemeyiz (awaitWriteAck deseni).
      await awaitWriteAck(
        ref
            .read(settingsRepositoryProvider)
            .save(current.copyWith(overtimeHourlyKurus: kurus)),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(kurus == 0
              ? 'Mesai saat ücreti temizlendi.'
              : 'Mesai saat ücreti kaydedildi: ${formatKurus(kurus)}'),
        ),
      );
    } catch (e, s) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kaydedilemedi. İnternet bağlantınızı kontrol edin.'),
        ),
      );
      await logHandledError(e, s, reason: 'mesai-ucreti-kaydet');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ayarlar henüz yüklenmediyse (null) kayda izin verme: mevcut dokümanı
    // okumadan yazmak diğer alanları (yevmiye varsayılanları) ezme riski taşır.
    final settingsAsync = ref.watch(settingsStreamProvider);
    final settings = settingsAsync.asData?.value;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mesaiye kalınan her saat için ödenecek ücret. Bir kez burada '
            'girilir, TÜM işçilere uygulanır — yoklamada yalnız saat basılır. '
            'Bir işçininki farklıysa o işçinin kartındaki ücret geçerli olur.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          MoneyField(
            controller: _ctrl,
            label: 'Mesai saat ücreti',
            // İki satırla sınırlı (MoneyField helperMaxLines: 2) → büyük sistem
            // yazısında kırpılmasın diye KISA tutulur; kalan bilgi alttaki nota.
            helperText: 'Örn. 100 → 2 saat mesai ₺200.',
            enabled: !_saving && settings != null,
            allowEmpty: true,
            filled: true,
            textInputAction: TextInputAction.done,
            onSubmitted: settings == null ? null : () => _save(settings),
          ),
          // Ayar okunamadıysa alan/düğme kapalı kalır → sebebini söyle ve
          // yeniden denemeyi sun (diğer ekranlardaki AsyncRetry deseni).
          if (settings == null && settingsAsync.hasError) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ayar yüklenemedi. İnternet bağlantınızı kontrol edin.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(settingsStreamProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                (_saving || settings == null) ? null : () => _save(settings),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
          ),
          const SizedBox(height: 10),
          Text(
            'Boş bırakırsanız mesai tutarı hesaplanmaz. Ücreti değiştirmek '
            'geçmiş günleri etkilemez — her gün kendi ücretini kaydedildiği '
            'anda dondurur.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bildirim izni durumu — yalnız durum BİLİNİYORSA görünür.
///
/// Sistem izin diyaloğu bir kez reddedilince bir daha çıkmaz: kullanıcı
/// bildirimlerin neden gelmediğini anlayamaz. Bu satır durumu söyler ve
/// kapalıysa nereden açacağını tarif eder. [pushPermissionGranted] yalnız
/// gerçek cihazda (push kurulumu çalışınca) dolar; testlerde/masaüstünde `null`
/// kalır → hiçbir şey çizilmez, ekranın mevcut düzeni değişmez.
class _NotificationStatus extends StatelessWidget {
  const _NotificationStatus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool?>(
      valueListenable: pushPermissionGranted,
      builder: (context, granted, _) {
        if (granted == null) return const SizedBox.shrink();
        final ok = granted;
        final renk = ok ? theme.colorScheme.primary : StatusColors.half;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ok ? Icons.notifications_active : Icons.notifications_off,
                  color: renk,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ok ? 'Bildirimler açık' : 'Bildirimler kapalı',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ok
                            ? 'Başka bir cihazda yoklama kaydedilince '
                                'haberiniz olur.'
                            : 'Yoklama kaydedildiğinde haberiniz olmaz. '
                                'Telefon Ayarları → Bildirimler → Yevmiye '
                                'Defterim yolundan açabilirsiniz.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Koyu tema anahtarı. Değeri gerçekte çizilen parlaklıktan okur
/// (`Theme.of(context).brightness`) → sistem varsayılanı da doğru yansır.
/// Dokununca tercih kalıcı yazılır ve uygulama anında yeni temaya geçer.
class _DarkModeSwitch extends ConsumerWidget {
  const _DarkModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: isDark,
        onChanged: (on) => ref
            .read(themeModeControllerProvider.notifier)
            .set(on ? ThemeMode.dark : ThemeMode.light),
        secondary: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: theme.colorScheme.primary,
          ),
        ),
        title: const Text(
          'Koyu tema',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isDark ? 'Koyu görünüm açık' : 'Açık görünüm',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
