import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../models/member_navigation_state.dart';
import '../../providers/member_navigation_provider.dart';

final _relativeFmt = DateFormat('yyyy-MM-dd HH:mm');

Color memberStatusColor(Member m) {
  if (m.isLocked) return Colors.red;
  if (m.registrationStatus == 'pending' ||
      m.registrationStatus == 'in_progress') {
    return Colors.orange;
  }
  return Colors.green;
}

String memberStatusEmoji(Member m) {
  if (m.isLocked) return '🔒';
  if (m.registrationStatus == 'pending' ||
      m.registrationStatus == 'in_progress') {
    return '🟡';
  }
  return '🟢';
}

Future<void> showMemberContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Member member,
  required Offset globalPosition,
  required List<Member> allMembers,
  required VoidCallback onView,
  required VoidCallback onEdit,
  required VoidCallback onUpload,
  VoidCallback? onComplete,
  VoidCallback? onGrantTempAccess,
  VoidCallback? onDelete,
  VoidCallback? onToggleFavorite,
  bool isFavorite = false,
  bool isAdmin = false,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      const PopupMenuItem(value: 'view', child: Text('👁️ View Profile')),
      const PopupMenuItem(value: 'edit', child: Text('✏️ Edit Member')),
      const PopupMenuItem(value: 'upload', child: Text('📎 Upload Files')),
      if (onComplete != null)
        const PopupMenuItem(
          value: 'complete',
          child: Text('🔒 Complete Member'),
        ),
      if (isAdmin && onGrantTempAccess != null)
        const PopupMenuItem(
          value: 'grant',
          child: Text('🔑 Grant Temp Access'),
        ),
      PopupMenuItem(
        value: 'favorite',
        child: Text(isFavorite ? '⭐ Remove Favorite' : '⭐ Add Favorite'),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'copy', child: Text('📋 Copy SA ID')),
      if (member.emailAddress.trim().isNotEmpty)
        const PopupMenuItem(value: 'email', child: Text('📧 Send Email')),
      if (member.contactNo1.trim().isNotEmpty)
        const PopupMenuItem(value: 'call', child: Text('📞 Call Contact')),
      if (onDelete != null) ...[
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('🗑️ Delete Member', style: TextStyle(color: Colors.red)),
        ),
      ],
    ],
  );

  switch (selected) {
    case 'view':
      onView();
    case 'edit':
      onEdit();
    case 'upload':
      onUpload();
    case 'complete':
      onComplete?.call();
    case 'grant':
      onGrantTempAccess?.call();
    case 'favorite':
      onToggleFavorite?.call();
    case 'copy':
      await Clipboard.setData(ClipboardData(text: member.saId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SA ID copied')),
        );
      }
    case 'email':
      final uri = Uri(scheme: 'mailto', path: member.emailAddress.trim());
      await launchUrl(uri);
    case 'call':
      final uri = Uri(scheme: 'tel', path: member.contactNo1.trim());
      await launchUrl(uri);
    case 'delete':
      onDelete?.call();
    default:
      break;
  }
}

class MemberListPanel extends ConsumerStatefulWidget {
  const MemberListPanel({
    super.key,
    required this.allMembers,
    required this.searchFocusNode,
    required this.onOpen,
    required this.onEdit,
    required this.onUpload,
    this.onComplete,
    this.onGrantTempAccess,
    this.onDelete,
    this.onAddNew,
    this.isAdmin = false,
  });

  final List<Member> allMembers;
  final FocusNode searchFocusNode;
  final void Function(Member member, {bool forceEdit}) onOpen;
  final void Function(Member member) onEdit;
  final void Function(Member member) onUpload;
  final void Function(Member member)? onComplete;
  final void Function(Member member)? onGrantTempAccess;
  final void Function(Member member)? onDelete;
  final VoidCallback? onAddNew;
  final bool isAdmin;

  @override
  ConsumerState<MemberListPanel> createState() => _MemberListPanelState();
}

class _MemberListPanelState extends ConsumerState<MemberListPanel> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: ref.read(memberNavigationProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(memberNavigationProvider);
    final nav = ref.read(memberNavigationProvider.notifier);
    final filtered = nav.filtered(widget.allMembers);
    final page = nav.pageMembers(widget.allMembers);
    final pages = MemberNavigationLogic.pageCount(
      filtered.length,
      navState.itemsPerPage,
    );
    final start = filtered.isEmpty
        ? 0
        : navState.currentPage * navState.itemsPerPage + 1;
    final end = filtered.isEmpty
        ? 0
        : (start + page.length - 1).clamp(0, filtered.length);

    final suggestions = navState.searchQuery.trim().isEmpty
        ? const <Member>[]
        : filtered.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Material(
            color: AppTheme.forestGreen,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MEMBER LIST',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.labelText,
                      ),
                    ),
                  ),
                  if (widget.onAddNew != null)
                    FilledButton.tonalIcon(
                      onPressed: widget.onAddNew,
                      style: FilledButton.styleFrom(
                        foregroundColor: AppTheme.labelText,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('New'),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchCtrl,
            focusNode: widget.searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search by Name, Surname, or SA ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: navState.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        nav.setSearchQuery('');
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: nav.setSearchQuery,
            onSubmitted: (_) {
              if (suggestions.isNotEmpty) {
                widget.onOpen(suggestions.first);
              }
            },
          ),
        ),
        if (suggestions.isNotEmpty && navState.searchQuery.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Card(
              child: Column(
                children: [
                  for (final m in suggestions)
                    ListTile(
                      dense: true,
                      title: Text(m.fullName),
                      subtitle: Text('SA ID: ${m.saId}'),
                      trailing: Text(
                        '${memberStatusEmoji(m)} ${MemberNavigationLogic.statusLabel(m)}',
                      ),
                      onTap: () => widget.onOpen(m),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sort in MemberSortBy.values)
                ChoiceChip(
                  label: Text(_sortLabel(sort)),
                  selected: navState.sortBy == sort,
                  onSelected: (_) => nav.setSort(sort),
                ),
              IconButton(
                tooltip: navState.sortAscending ? 'Ascending' : 'Descending',
                onPressed: () => nav.setSort(
                  navState.sortBy,
                  ascending: !navState.sortAscending,
                ),
                icon: Icon(
                  navState.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: page.isEmpty
              ? const Center(child: Text('No members match this filter.'))
              : ListView.builder(
                  itemCount: page.length,
                  itemBuilder: (context, i) {
                    final member = page[i];
                    final globalIndex =
                        navState.currentPage * navState.itemsPerPage + i;
                    final highlighted = navState.highlightIndex == i;
                    final isFav =
                        navState.favoriteIds.contains(member.id);
                    return _MemberRow(
                      index: globalIndex + 1,
                      member: member,
                      highlighted: highlighted,
                      isFavorite: isFav,
                      onTap: () {
                        nav.setHighlightIndex(i);
                        widget.onOpen(member);
                      },
                      onDoubleTap: () => widget.onEdit(member),
                      onSecondaryTapDown: (details) async {
                        await showMemberContextMenu(
                          context: context,
                          ref: ref,
                          member: member,
                          globalPosition: details.globalPosition,
                          allMembers: widget.allMembers,
                          onView: () => widget.onOpen(member),
                          onEdit: () => widget.onEdit(member),
                          onUpload: () => widget.onUpload(member),
                          onComplete: widget.onComplete == null ||
                                  member.isLocked ||
                                  !(member.registrationStatus == 'pending' ||
                                      member.registrationStatus ==
                                          'in_progress')
                              ? null
                              : () => widget.onComplete!(member),
                          onGrantTempAccess: widget.onGrantTempAccess == null ||
                                  !member.isLocked
                              ? null
                              : () => widget.onGrantTempAccess!(member),
                          onDelete: widget.onDelete == null
                              ? null
                              : () => widget.onDelete!(member),
                          onToggleFavorite: () =>
                              nav.toggleFavorite(member.id),
                          isFavorite: isFav,
                          isAdmin: widget.isAdmin,
                        );
                      },
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(
                filtered.isEmpty
                    ? 'Showing 0 of 0'
                    : 'Showing $start-$end of ${filtered.length}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed:
                    navState.currentPage > 0 ? () => nav.previousPage() : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page (←)',
              ),
              Text('${navState.currentPage + 1} / $pages'),
              IconButton(
                onPressed: navState.currentPage < pages - 1
                    ? () => nav.nextPage(filtered.length)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page (→)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sortLabel(MemberSortBy sort) {
    switch (sort) {
      case MemberSortBy.name:
        return 'Name';
      case MemberSortBy.surname:
        return 'Surname';
      case MemberSortBy.saId:
        return 'SA ID';
      case MemberSortBy.date:
        return 'Updated';
    }
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.index,
    required this.member,
    required this.highlighted,
    required this.isFavorite,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
  });

  final int index;
  final Member member;
  final bool highlighted;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AppTheme.forestGreen.withValues(alpha: 0.12)
          : (index.isEven ? Colors.white : Colors.grey.shade50),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$index',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: memberStatusColor(member),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'SA ID: ${member.saId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.emailAddress,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      member.contactNo1,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${memberStatusEmoji(member)} ${MemberNavigationLogic.statusLabel(member)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (isFavorite)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('⭐', style: TextStyle(fontSize: 12)),
                ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentlyViewedPanel extends ConsumerWidget {
  const RecentlyViewedPanel({
    super.key,
    required this.allMembers,
    required this.onOpen,
  });

  final List<Member> allMembers;
  final void Function(Member member) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(memberNavigationProvider);
    final nav = ref.read(memberNavigationProvider.notifier);
    final byId = {for (final m in allMembers) m.id: m};
    final entries = navState.recentlyViewed
        .where((e) => byId.containsKey(e.memberId))
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              '🕐 RECENTLY VIEWED',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.bodyText,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'No recent views yet.',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final member = byId[entry.memberId]!;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline, size: 20),
                        title: Text(
                          member.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _relative(entry.viewedAt),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow, size: 18),
                          tooltip: 'Open',
                          onPressed: () => onOpen(member),
                        ),
                        onTap: () => onOpen(member),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: entries.isEmpty ? null : () => nav.clearRecent(),
              child: const Text('Clear History'),
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime viewedAt) {
    final local = viewedAt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Viewed: just now';
    if (diff.inMinutes < 60) return 'Viewed: ${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return 'Viewed: ${diff.inHours} hours ago';
    return 'Viewed: ${_relativeFmt.format(local)}';
  }
}
