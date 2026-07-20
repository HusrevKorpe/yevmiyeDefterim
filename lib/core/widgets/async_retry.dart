/// Bir [AsyncValue]'yu gösteren ortak sarmalayıcı: veri gelene kadar spinner;
/// HATA olduğunda veya yükleme çok uzun sürdüğünde "Yeniden Dene" butonlu hata
/// kutusu (kural §8: büyük buton, Türkçe, düşük teknoloji dostu).
///
/// **Neden zaman aşımı var?** cloud_firestore offline persistence açıkken, izni
/// reddedilen ya da sunucuya ulaşamayan bir dinleyici `error`'a bile geçmeden
/// `loading`'de takılı kalabiliyor → spinner sonsuza döner (gözlemlendi). [timeout]
/// dolunca kullanıcı sebebi görür ve yeniden deneyebilir. Veri sonradan gelirse
/// (dinleyici hâlâ abone) ekran kendiliğinden veriye döner — zaman aşımı yapışkan
/// değildir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncRetry<T> extends StatefulWidget {
  const AsyncRetry({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
    this.message = 'Veriler yüklenemedi. İnternet bağlantınızı kontrol edin.',
    this.timeout = const Duration(seconds: 15),
  });

  /// İzlenen sağlayıcının o anki durumu.
  final AsyncValue<T> value;

  /// "Yeniden Dene" — genelde `() => ref.invalidate(...)` (taban stream'i yeniden
  /// aboneler).
  final VoidCallback onRetry;

  /// Veri hazırken gösterilecek içerik.
  final Widget Function(T data) data;

  /// Hata/zaman aşımı mesajı.
  final String message;

  /// İlk veri bu süre içinde gelmezse hata kutusuna geç.
  final Duration timeout;

  @override
  State<AsyncRetry<T>> createState() => _AsyncRetryState<T>();
}

class _AsyncRetryState<T> extends State<AsyncRetry<T>> {
  Timer? _timer;
  bool _timedOut = false;

  /// Henüz ne veri ne hata var; sadece bekliyoruz.
  bool get _waiting =>
      widget.value.isLoading &&
      !widget.value.hasValue &&
      !widget.value.hasError;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AsyncRetry<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Bekliyorsak sayacı kur; veri/hata geldiyse durdur ve bayrağı sıfırla.
  void _sync() {
    if (_waiting) {
      _timer ??= Timer(widget.timeout, () {
        if (mounted) setState(() => _timedOut = true);
      });
    } else {
      _timer?.cancel();
      _timer = null;
      _timedOut = false;
    }
  }

  void _retry() {
    _timer?.cancel();
    _timer = null;
    setState(() => _timedOut = false);
    widget.onRetry();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    // Veri her zaman öncelikli: zaman aşımından sonra veri gelse bile göster.
    if (v.hasValue) return widget.data(v.requireValue);
    if (v.hasError || _timedOut) {
      return _ErrorRetry(message: widget.message, onRetry: _retry);
    }
    // ExcludeSemantics: yüklenirken sürekli kare çizen spinner'ın semantics
    // ağacına düğüm katmasını engeller. Bu, Flutter'ın yeni semantics katmanında
    // (3.24+) sekme (IndexedStack) görünür olurken layout hâlâ oturmadan
    // flushSemantics çalışınca patlayan "!semantics.parentDataDirty" debug
    // assertion'ının tetiklenme yüzeyini daraltır. (Assertion yalnız debug'da;
    // release güvenli.) Spinner'ın erişilebilirlik etiketi bu kitle için gereksiz.
    return const ExcludeSemantics(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
