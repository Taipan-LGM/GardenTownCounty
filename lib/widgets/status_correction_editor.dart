import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_strings.dart';
import '../../models/lro_status_correction.dart' as sc;
import '../../providers/providers.dart';

/// Status correction list editor — descriptions only, with toggleable ✅.
///
/// Each row carries a description and an on/off switch. The row always renders
/// with a leading "✅ " when it is enabled; the switch lets the Admin disable a
/// row without deleting it.
class _StatusCorrectionEditor extends ConsumerStatefulWidget {
  final List<sc.LroStatusCorrection> corrections;
  final ValueChanged<List<sc.LroStatusCorrection>> onChanged;

  const _StatusCorrectionEditor({
    required this.corrections,
    required this.onChanged,
  });

  @override
  ConsumerState<_StatusCorrectionEditor> createState() =>
      _StatusCorrectionEditorState();
}

class _StatusCorrectionEditorState
    extends ConsumerState<_StatusCorrectionEditor> {
  late List<sc.LroStatusCorrection> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.corrections.toList();
  }

  void _notify() => widget.onChanged(_rows);

  void _add() {
    setState(() {
      _rows.add(const sc.LroStatusCorrection(description: ''));
      _notify();
    });
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() {
      _rows.removeAt(index);
      _notify();
    });
  }

  void _updateDescription(int index, String value) {
    setState(() {
      _rows[index] = _rows[index].copyWith(description: value.trim());
      _notify();
    });
  }

  void _toggleChecked(int index) {
    setState(() {
      _rows[index] =
          _rows[index].copyWith(isChecked: !_rows[index].isChecked);
      _notify();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(ref.watch(appLanguageProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          children: [
            const Icon(Icons.checklist, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.statusCorrections,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          strings.statusCorrectionsDesc,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        // List of rows
        ...List.generate(_rows.length, (index) {
          final row = _rows[index];
          final canDelete = _rows.length > 1;
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ label (always shown when non-empty)
                  SizedBox(
                    width: 30,
                    child: Text(
                      row.description.isNotEmpty ? '✅' : '   ',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  // Description textField (inline editing)
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: TextEditingController(text: row.description),
                      onChanged: (v) => _updateDescription(index, v),
                      decoration: InputDecoration(
                        hintText: 'Status correction description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Check toggle
                  Switch(
                    value: row.isChecked,
                    onChanged: (v) => _toggleChecked(index),
                    activeColor: const Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 8),
                  // Delete button
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.orangeAccent, size: 20),
                      onPressed: () => _removeAt(index),
                      tooltip: strings.delete,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
          );
        }),
        // Add button
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 18),
          label: Text(strings.addStatus),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black87,
          ),
        ),
      ],
    );
  }
}
