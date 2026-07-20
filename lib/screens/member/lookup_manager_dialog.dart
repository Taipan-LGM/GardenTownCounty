import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lookup_item.dart';
import '../../providers/providers.dart';

Future<void> showLookupManagerDialog(
  BuildContext context,
  WidgetRef ref,
  LookupType type,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => LookupManagerDialog(type: type),
  );
}

class LookupManagerDialog extends ConsumerStatefulWidget {
  const LookupManagerDialog({super.key, required this.type});

  final LookupType type;

  @override
  ConsumerState<LookupManagerDialog> createState() =>
      _LookupManagerDialogState();
}

class _LookupManagerDialogState extends ConsumerState<LookupManagerDialog> {
  final _controller = TextEditingController();
  LookupItem? _editing;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    final repo = ref.read(memberRepositoryProvider);
    if (_editing != null) {
      await repo.saveLookup(
        _editing!.copyWith(
          value: value,
          updatedAt: DateTime.now().toUtc(),
          pendingSync: true,
        ),
      );
    } else {
      await repo.saveLookup(
        LookupItem.create(type: widget.type, value: value),
      );
    }

    _controller.clear();
    _editing = null;
    ref.invalidate(lookupsProvider(widget.type));
    setState(() {});
  }

  Future<void> _delete(LookupItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete lookup?'),
        content: Text('Remove "${item.value}"?'),
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
    await ref.read(memberRepositoryProvider).deleteLookup(item.id);
    ref.invalidate(lookupsProvider(widget.type));
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(lookupsProvider(widget.type));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
      title: Row(
        children: [
          Expanded(
            child: Text('Manage ${widget.type.label}'),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: _editing == null ? 'Add new' : 'Edit value',
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(_editing == null ? 'Add' : 'Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncItems.when(
                data: (items) => ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.value),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              setState(() {
                                _editing = item;
                                _controller.text = item.value;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
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
      ],
    );
  }
}
