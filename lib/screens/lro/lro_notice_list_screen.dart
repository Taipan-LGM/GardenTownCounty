import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/lro_notice.dart';
import '../../providers/providers.dart';
import '../../widgets/lro/lro_theme.dart';
import '../../widgets/lro/lro_search_bar.dart';
import '../../widgets/lro/lro_status_badge.dart';
import 'lro_notice_detail_screen.dart';
import 'lro_notice_form_screen.dart';

/// Full CRUD list of LRO public notices (all statuses). Always reached via
/// [Navigator.push].
class LroNoticeListScreen extends ConsumerStatefulWidget {
  const LroNoticeListScreen({super.key});

  @override
  ConsumerState<LroNoticeListScreen> createState() =>
      _LroNoticeListScreenState();
}

class _LroNoticeListScreenState extends ConsumerState<LroNoticeListScreen> {
  String _query = '';
  String? _statusFilter;

  List<LroNotice> _filterAndSort(List<LroNotice> notices) {
    var result = notices.where((n) => !n.deleted).toList();
    if (_statusFilter != null) {
      result = result.where((n) => n.status == _statusFilter).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where(
            (n) =>
                n.title.toLowerCase().contains(query) ||
                n.content.toLowerCase().contains(query),
          )
          .toList();
    }
    result.sort(
      (a, b) => (b.publicationDate ?? b.createdAt)
          .compareTo(a.publicationDate ?? a.createdAt),
    );
    return result;
  }

  void _refresh() {
    ref.invalidate(lroNoticesProvider);
    ref.invalidate(lroNoticeFeedProvider);
  }

  Future<void> _openForm({LroNotice? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LroNoticeFormScreen(existing: existing),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openDetail(LroNotice notice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LroNoticeDetailScreen(noticeId: notice.id),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(lroNoticesProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');

    return LroThemed(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Public Notices'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Notice'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: LroSearchBar(
                    hintText: 'Search notices...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...LroNoticeStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s.code,
                          child: Text(s.label),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: noticesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (notices) {
                  final filtered = _filterAndSort(notices);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No notices found.'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      return ListTile(
                        title: Text(
                          n.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          n.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            LroStatusBadge(
                              status: n.status,
                              label: n.statusEnum.label,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.publicationDate != null
                                  ? dateFmt.format(n.publicationDate!.toLocal())
                                  : '—',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () => _openDetail(n),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
