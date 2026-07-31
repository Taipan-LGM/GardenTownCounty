import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/member.dart';
import '../../models/member_navigation_state.dart';
import '../../models/user_role.dart';
import '../../providers/member_navigation_provider.dart';
import '../../providers/providers.dart';
import '../standard_buttons.dart';

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
  final strings = ref.read(appStringsProvider);
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(value: 'view', child: Text('👁️ ${strings.viewProfile}')),
      PopupMenuItem(value: 'edit', child: Text('✏️ ${strings.editMember}')),
      PopupMenuItem(value: 'upload', child: Text('📎 ${strings.uploadFiles}')),
      if (onComplete != null)
        PopupMenuItem(
          value: 'complete',
          child: Text('🔒 ${strings.completeMember}'),
        ),
      if (isAdmin && onGrantTempAccess != null)
        PopupMenuItem(
          value: 'grant',
          child: Text('🔑 ${strings.grantTempAccess}'),
        ),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          isFavorite
              ? '⭐ ${strings.removeFavorite}'
              : '⭐ ${strings.addFavorite}',
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(value: 'copy', child: Text('📋 ${strings.copySaId}')),
      if (member.emailAddress.trim().isNotEmpty)
        PopupMenuItem(value: 'email', child: Text('📧 ${strings.sendEmail}')),
      if (member.contactNo1.trim().isNotEmpty)
        PopupMenuItem(value: 'call', child: Text('📞 ${strings.callContact}')),
      if (onDelete != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            '🗑️ ${strings.deleteMember}',
            style: const TextStyle(color: Colors.red),
          ),
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
          SnackBar(content: Text(strings.saIdCopied)),
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
    final strings = ref.watch(appStringsProvider);
    final users = ref.watch(appUsersProvider).valueOrNull ?? const [];
    // memberId → role badge for Admin/RS (AppUser.role, not Member column).
    // NEW ADDITION - role badges (Delete map + badge UI to revert)
    final roleByMemberId = <String, UserRole>{};
    for (final u in users) {
      if (u.deleted) continue;
      final mid = u.memberId?.trim();
      if (mid == null || mid.isEmpty) continue;
      if (u.isAdmin || u.isSecretary) {
        roleByMemberId[mid] = u.userRole;
      }
    }
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
                  Expanded(
                    child: Text(
                      strings.memberList,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.labelText,
                      ),
                    ),
                  ),
                  if (widget.onAddNew != null)
                    AddButton(
                      onPressed: widget.onAddNew,
                      text: strings.newLabel,
                      icon: Icons.person_add,
                      height: 35,
                      backgroundColor: AppButtonColors.newBg,
                      foregroundColor: AppButtonColors.newFg,
                      borderColor: AppButtonColors.blackRing,
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
              hintText: strings.searchByNameSurnameSaId,
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
                        '${memberStatusEmoji(m)} ${strings.memberStatusLabel(m)}',
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
                  label: Text(strings.sortLabel(sort)),
                  selected: navState.sortBy == sort,
                  onSelected: (_) => nav.setSort(sort),
                ),
              IconButton(
                tooltip: navState.sortAscending
                    ? strings.ascending
                    : strings.descending,
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
              ? Center(child: Text(strings.noMembersMatchFilter))
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
                      role: roleByMemberId[member.id],
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
                    ? strings.showingRange(0, 0, 0)
                    : strings.showingRange(start, end, filtered.length),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed:
                    navState.currentPage > 0 ? () => nav.previousPage() : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: '${strings.previous} (←)',
              ),
              Text(strings.ofTotal(navState.currentPage + 1, pages)),
              IconButton(
                onPressed: navState.currentPage < pages - 1
                    ? () => nav.nextPage(filtered.length)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: '${strings.next} (→)',
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.index,
    required this.member,
    required this.highlighted,
    required this.isFavorite,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    this.role,
  });

  final int index;
  final Member member;
  final bool highlighted;
  final bool isFavorite;
  final UserRole? role;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback onSecondaryTapDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (role == UserRole.secretary) ...[
                          const SizedBox(width: 6),
                          _RoleBadge(
                            label: '📋 RS',
                            background: Colors.green.shade900,
                            foreground: Colors.green.shade300,
                          ),
                        ],
                        if (role == UserRole.admin) ...[
                          const SizedBox(width: 6),
                          _RoleBadge(
                            label: '👑 Admin',
                            background: Colors.blue.shade900,
                            foreground: Colors.blue.shade300,
                          ),
                        ],
                      ],
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
                '${memberStatusEmoji(member)} ${strings.memberStatusLabel(member)}',
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

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          color: foreground,
          fontWeight: FontWeight.bold,
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
            child: ActionButton(
              onPressed: entries.isEmpty ? null : () => nav.clearRecent(),
              text: 'Clear History',
              height: 35,
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
