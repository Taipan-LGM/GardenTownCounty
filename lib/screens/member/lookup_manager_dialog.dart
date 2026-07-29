import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lookup_item.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';
import '../../widgets/form_dialog_title.dart';

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
          CancelButton(
            onPressed: () => Navigator.pop(context, false),
            text: 'Cancel',
          ),
          DeleteButton(
            onPressed: () => Navigator.pop(context, true),
            text: 'Delete',
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
      titlePadding: formDialogTitlePadding,
      title: FormDialogTitle(title: 'Manage ${widget.type.label}'),
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
                _editing == null
                    ? AddButton(
                        onPressed: _save,
                        text: 'Add',
                      )
                    : SaveButton(
                        onPressed: _save,
                        text: 'Save',
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
                            icon: Icon(Icons.edit, color: AppButtonColors.editBg),
                            onPressed: () {
                              setState(() {
                                _editing = item;
                                _controller.text = item.value;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppButtonColors.deleteBg,
                            ),
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
        ActionButton(
          onPressed: () => Navigator.of(context).pop(),
          text: 'Close',
        ),
      ],
    );
  }
}
