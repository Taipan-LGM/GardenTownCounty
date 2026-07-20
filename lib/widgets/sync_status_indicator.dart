import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/sync_engine.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusProvider);
    final sync = syncAsync.valueOrNull ??
        const SyncState(status: SyncUiStatus.offline, message: 'Starting…');

    final color = switch (sync.status) {
      SyncUiStatus.synced => Colors.green,
      SyncUiStatus.syncing => Colors.amber.shade700,
      SyncUiStatus.offline => Colors.red,
      SyncUiStatus.error => Colors.orange.shade800,
    };
    final last = sync.lastSyncedAt == null
        ? 'Never'
        : DateFormat('yyyy-MM-dd HH:mm').format(sync.lastSyncedAt!.toLocal());
    final tip = sync.message ?? 'Last synced: $last';

    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tip)),
            );
            ref.read(syncEngineProvider).pushPending();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  switch (sync.status) {
                    SyncUiStatus.synced => 'Synced',
                    SyncUiStatus.syncing => 'Syncing',
                    SyncUiStatus.offline => 'Offline',
                    SyncUiStatus.error => 'Sync error',
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.forestGreen,
                    fontWeight: FontWeight.w600,
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
