import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/member.dart';
import '../../providers/providers.dart';

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
    final results = await ref.read(memberRepositoryProvider).search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });

    if (results.length == 1) {
      _openMember(results.first);
    }
  }

  void _openMember(Member member) {
    ref.read(selectedMemberIdProvider.notifier).state = member.id;
    ref.read(appSectionProvider.notifier).state = AppSection.memberInfo;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Global Search'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search all member fields…',
                prefixIcon: Icon(Icons.search),
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
              const Text('No members matched.')
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _search,
          child: const Text('Search'),
        ),
      ],
    );
  }
}
