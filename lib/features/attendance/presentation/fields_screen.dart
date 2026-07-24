/// Tarla yönetim ekranı (/yoklama/tarlalar) — yoklamadaki tarla seçiminin kaynağı.
///
/// Kullanıcı tarlaları burada tanımlar; yoklamada Tam/Yarım (elebaşında kişi
/// sayısı) girilince bu liste satırın altında çip olarak çıkar → "kim nerede
/// çalıştı" kayıt altına alınır. Silme soft-delete'tir (kural §5): geçmiş
/// yoklama kayıtlarındaki denormalize tarla adı okunur kalır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/ids.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_retry.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../application/fields_providers.dart';
import '../data/field.dart';

class FieldsScreen extends ConsumerWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsStreamProvider);
    return Scaffold(
      appBar: const GradientAppBar(title: 'Tarlalar'),
      floatingActionButton: FloatingActionButton.extended(
        // Kök navigator'da üst üste binen ekranlarla Hero tag çakışmasın.
        heroTag: 'tarla-ekle-fab',
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tarla Ekle'),
      ),
      body: AsyncRetry(
        value: fieldsAsync,
        onRetry: () => ref.invalidate(fieldsStreamProvider),
        message: 'Tarlalar yüklenemedi. İnternet bağlantınızı kontrol edin.',
        data: (fields) {
          final active = fields.where((f) => f.active).toList();
          if (active.isEmpty) return const _EmptyFields();
          return ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            itemCount: active.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return const _HintRow();
              final field = active[i - 1];
              final tile = _FieldTile(
                field: field,
                onEdit: () => _edit(context, ref, field),
                onDelete: () => _delete(context, ref, field),
              );
              // Satırları birbirinden ayıran ince çizgi (son satırdan sonra yok).
              if (i - 1 == active.length - 1) return tile;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tile,
                  const Divider(height: 1, thickness: 0.5, indent: 68, endIndent: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Ekle (existing null) / ad düzenle diyaloğu — ortak sanatsal [showInputDialog].
  Future<void> _edit(BuildContext context, WidgetRef ref,
      [Field? existing]) async {
    final name = await showInputDialog(
      context,
      title: existing == null ? 'Tarla Ekle' : 'Tarlayı Düzenle',
      icon: Icons.grass,
      initialValue: existing?.name ?? '',
      label: 'Tarla adı',
      hint: 'Örn. Aşağı Tarla',
      textCapitalization: TextCapitalization.words,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final repo = ref.read(fieldRepositoryProvider);
    if (existing == null) {
      await repo.add(Field(id: newId(), name: trimmed));
    } else {
      await repo.update(existing.copyWith(name: trimmed));
    }
  }

  /// Onaylı soft-delete: geçmiş yoklama kayıtlarındaki tarla bilgisi silinmez.
  Future<void> _delete(BuildContext context, WidgetRef ref, Field field) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tarlayı Sil',
      message: '"${field.name}" listeden kaldırılacak. Geçmiş yoklama '
          'kayıtlarındaki tarla bilgisi silinmez.',
      confirmLabel: 'Sil',
      icon: Icons.delete_outline,
    );
    if (ok) {
      await ref.read(fieldRepositoryProvider).setActive(field.id, active: false);
    }
  }
}

/// Liste başındaki kısa kullanım ipucu (kompakt, kart şişkinliği yok).
class _HintRow extends StatelessWidget {
  const _HintRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Yoklamada Tam/Yarım seçilince tarla seçebilirsiniz.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.field,
    required this.onEdit,
    required this.onDelete,
  });

  final Field field;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onEdit,
      visualDensity: VisualDensity.compact,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.grass, size: 19, color: theme.colorScheme.primary),
      ),
      title: Text(
        field.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Düzenle',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
            tooltip: 'Sil',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyFields extends StatelessWidget {
  const _EmptyFields();

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.grass,
                  size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Tarla eklenmemiş',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Tarla ekleyin; yoklamada Tam/Yarım seçilen işçi için tarla '
              'seçilebilir olur. Böylece kimin nerede çalıştığı kayıt altına '
              'alınır.',
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
