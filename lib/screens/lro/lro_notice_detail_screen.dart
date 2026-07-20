import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/lro/lro_theme.dart';
import '../../models/lro_history.dart';
import '../../models/lro_notice.dart';
import '../../providers/providers.dart';
import '../../widgets/lro/lro_status_badge.dart';
import 'lro_notice_form_screen.dart';

/// Full detail view for a single public notice. Always reached via
/// [Navigator.push].
class LroNoticeDetailScreen extends ConsumerStatefulWidget {
  const LroNoticeDetailScreen({super.key, required this.noticeId});

  final String noticeId;

  @override
  ConsumerState<LroNoticeDetailScreen> createState() =>
      _LroNoticeDetailScreenState();
}

class _LroNoticeDetailScreenState extends ConsumerState<LroNoticeDetailScreen> {
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  LroNotice? _notice;
  List<LroHistory> _history = const [];
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(lroRepositoryProvider);
    final notices = await repo.listNotices();
    final notice = notices.firstWhereOrNull((n) => n.id == widget.noticeId);
    final history = notice == null
        ? <LroHistory>[]
        : await repo.listHistory('notice', widget.noticeId);
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _history = history;
      _loading = false;
    });
  }

  void _invalidateLists() {
    ref.invalidate(lroNoticesProvider);
    ref.invalidate(lroNoticeFeedProvider);
    ref.invalidate(lroStatsProvider);
  }

  Future<void> _edit() async {
    final current = _notice;
    if (current == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LroNoticeFormScreen(existing: current),
      ),
    );
    if (saved == true) {
      _invalidateLists();
      await _load();
    }
  }

  Future<void> _delete() async {
    final current = _notice;
    if (current == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notice?'),
        content: Text(
          'This will remove "${current.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(lroRepositoryProvider).deleteNotice(widget.noticeId);
      _invalidateLists();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final notice = _notice;

    return LroThemed(
      child: Scaffold(
      appBar: AppBar(
        title: Text(notice?.title ?? 'Notice Detail'),
        actions: notice == null
            ? null
            : [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _edit,
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                  onPressed: _deleting ? null : _delete,
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : notice == null
              ? const Center(child: Text('Notice not found.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    LroStatusBadge(
                      status: notice.status,
                      label: notice.statusEnum.label,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _field(
                              'Publication Date',
                              notice.publicationDate != null
                                  ? _dateFmt.format(
                                      notice.publicationDate!.toLocal(),
                                    )
                                  : '—',
                            ),
                            _field(
                              'Expiry Date',
                              notice.expiryDate != null
                                  ? _dateFmt.format(notice.expiryDate!.toLocal())
                                  : '—',
                            ),
                            _field('Related Member', notice.memberId ?? '—'),
                            const SizedBox(height: 8),
                            Text(
                              'Content',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(notice.content.isEmpty ? '—' : notice.content),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Audit History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: LroTheme.text(context),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_history.isEmpty)
                      const Text('No history yet.')
                    else
                      ..._history.map(
                        (h) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, size: 20),
                          title: Text(h.action),
                          subtitle: Text(
                            '${h.fromStatus != null ? '${h.fromStatus} → ' : ''}${h.toStatus ?? ''}\n'
                            '${_dateFmt.format(h.changedAt.toLocal())} by ${h.changedBy}',
                          ),
                        ),
                      ),
                  ],
                ),
    ),
    );
  }
}
