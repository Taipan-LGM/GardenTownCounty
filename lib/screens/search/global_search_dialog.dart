import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/member.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';
import '../../widgets/form_dialog_title.dart';

Future<void> showGlobalSearchDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => const GlobalSearchDialog(),
  );
}

class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key});

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final _controller = TextEditingController();
  List<Member> _results = const [];
  bool _searched = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    final user = ref.read(authUserProvider);
    final access = ref.read(dataAccessServiceProvider);

    // Role-scoped page query avoids loading the entire member roster.
    final page = await access.getVisibleMembersPage(
      user,
      offset: 0,
      limit: 100,
      query: query,
    );
    var scoped = page.items;

    // Fallback: repository search + per-member access check (broader match).
    if (scoped.isEmpty) {
      final results = await ref.read(memberRepositoryProvider).search(query);
      final filtered = <Member>[];
      for (final m in results) {
        if (await access.canAccessMember(user, m.id)) {
          filtered.add(m);
        }
      }
      scoped = filtered;
    }

    if (!mounted) return;
    setState(() {
      _results = scoped;
      _loading = false;
    });

    if (scoped.length == 1) {
      _openMember(scoped.first);
    }
  }

  void _openMember(Member member) {
    ref.read(selectedMemberIdProvider.notifier).state = member.id;
    ref.read(appSectionProvider.notifier).state = AppSection.memberInfo;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    return AlertDialog(
      title: FormDialogTitle(title: strings.globalSearch),
      titlePadding: formDialogTitlePadding,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_searched && _results.isEmpty)
              Text(strings.noMembersMatched)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final member = _results[index];
                    return ListTile(
                      title: Text(member.fullName),
                      subtitle: Text(
                        '${member.saId} · ${member.globalRecordNo}',
                      ),
                      onTap: () => _openMember(member),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        ActionButton(
          onPressed: () => Navigator.of(context).pop(),
          text: strings.close,
          backgroundColor: AppButtonColors.closeBg,
          foregroundColor: AppButtonColors.closeFg,
          borderColor: AppButtonColors.whiteRing,
        ),
        ActionButton(
          onPressed: _search,
          text: strings.search,
        ),
      ],
    );
  }
}
