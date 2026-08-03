/// İşçiler ekranı — tür bazında gruplu liste, arama, ekle/düzenle
/// (plan §5, kural §8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/app_log.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../advances/application/advance_providers.dart';
import '../../attendance/application/attendance_providers.dart';
import '../../auth/application/user_access.dart';
import '../application/worker_purge.dart';
import '../application/worker_search.dart';
import '../application/workers_providers.dart';
import '../data/worker.dart';
import 'worker_detail_screen.dart';
import 'worker_edit_screen.dart';

part 'worker_tile.dart';

class WorkersScreen extends ConsumerStatefulWidget {
  const WorkersScreen({super.key});

  @override
  ConsumerState<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends ConsumerState<WorkersScreen> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  /// Arama çubuğu açık mı (başlıktaki "Ara" hapı ile açılır/kapanır).
  bool _searchOpen = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  String get _query => _queryCtrl.text.trim();

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) _queryCtrl.clear();
    });
    if (_searchOpen) {
      _queryFocus.requestFocus();
    } else {
      _queryFocus.unfocus();
    }
  }

  void _clearQuery() {
    setState(_queryCtrl.clear);
    _queryFocus.requestFocus();
  }

  /// Yeni işçi ekle (başlıktaki "Ekle") — doğrudan düzenleme ekranı.
  void _openAdd() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkerEditScreen(),
      ),
    );
  }

  /// İşçiye dokun → geçmiş/detay ekranı (düzenleme oradaki kalem butonunda).
  void _openDetail(Worker worker) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkerDetailScreen(worker: worker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workersStreamProvider);

    return Scaffold(
      appBar: GradientAppBar(
        actions: [
          _HeaderPill(
            icon: _searchOpen ? Icons.close : Icons.search,
            label: _searchOpen ? 'Kapat' : 'Ara',
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _HeaderPill(
              icon: Icons.add,
              label: 'Ekle',
              onPressed: _openAdd,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Açılış/kapanış yumuşak olsun diye AnimatedSize; kapalıyken
            // yer kaplamaz.
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _searchOpen
                  ? _SearchField(
                      controller: _queryCtrl,
                      focusNode: _queryFocus,
                      onChanged: (_) => setState(() {}),
                      onClear: _clearQuery,
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: AsyncRetry(
                value: workersAsync,
                onRetry: () => ref.invalidate(workersStreamProvider),
                message:
                    'İşçiler yüklenemedi. İnternet bağlantınızı kontrol edin.',
                data: (workers) {
                  if (_query.isNotEmpty) return _results(workers);
                  if (workers.isEmpty) return const _EmptyWorkers();
                  return _grouped(workers);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Normal görünüm: aktifler tür başlıkları altında, pasifler katlanır bölümde.
  Widget _grouped(List<Worker> workers) {
    final active = workers.where((w) => w.active).toList();
    final passive = workers.where((w) => !w.active).toList();
    return SlidableAutoCloseBehavior(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final type in WorkerType.values) ..._section(type, active),
          if (passive.isNotEmpty) _passiveSection(passive),
        ],
      ),
    );
  }

  /// Arama görünümü: başlıksız düz liste, en iyi eşleşme başta. Pasif işçiler
  /// de bulunur (rozetle işaretlenir).
  Widget _results(List<Worker> workers) {
    final results = searchWorkers(workers, _query);
    if (results.isEmpty) return _NoResults(query: _query);
    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 2, bottom: 96),
        itemCount: results.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _ResultCount(results.length);
          final w = results[index - 1];
          return _WorkerTile(
            worker: w,
            onTap: () => _openDetail(w),
            canDelete: true,
            showBadge: true,
          );
        },
      ),
    );
  }

  List<Widget> _section(WorkerType type, List<Worker> active) {
    final group = active.where((w) => w.type == type).toList();
    if (group.isEmpty) return const [];
    return [
      _Header('${type.label} (${group.length})'),
      for (final w in group)
        _WorkerTile(
          worker: w,
          onTap: () => _openDetail(w),
          canDelete: true,
        ),
    ];
  }

  Widget _passiveSection(List<Worker> passive) {
    return ExpansionTile(
      leading: const Icon(Icons.person_off_outlined),
      title: Text('Pasif İşçiler (${passive.length})'),
      children: [
        for (final w in passive)
          _WorkerTile(
            worker: w,
            onTap: () => _openDetail(w),
            canDelete: true,
          ),
      ],
    );
  }
}

/// Başlığın hemen altındaki yumuşak arama kutusu.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        autofocus: true,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'İşçi ara…',
          filled: true,
          fillColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Temizle',
                  onPressed: onClear,
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// "3 sonuç" — arama listesinin başındaki sessiz bilgi satırı.
class _ResultCount extends StatelessWidget {
  const _ResultCount(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: Text(
        '$count sonuç',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: SectionTitle(text),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Icon(
          Icons.search_off,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 14),
        Text(
          '“$query” bulunamadı',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Adın bir bölümünü yazmayı deneyin.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EmptyWorkers extends StatelessWidget {
  const _EmptyWorkers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.groups, size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz işçi yok',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sağ üstteki “Ekle” ile başlayın.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
