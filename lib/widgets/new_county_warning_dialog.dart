import 'package:flutter/material.dart';

/// Modal warning when Admin changes all 4 county identity fields.
/// Returns true only if user types CONFIRM and taps Confirm New County.
Future<bool> showNewCountyWarningDialog(BuildContext context) async {
  var confirmText = '';
  // useRootNavigator: true — required when opened from County Settings Dialog
  // so Cancel then Save again always shows a fresh warning (not swallowed).
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final canConfirm = confirmText.trim() == 'CONFIRM';
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Expanded(child: Text('NEW COUNTY DETECTED')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You have changed ALL 4 county information fields.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This will register a NEW COUNTY and will:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• DELETE all existing member data',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '• DELETE all case data (528, 928, LRO)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '• DELETE all file uploads',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '• DELETE all reminders',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '• DELETE all users (except Admin)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '• DELETE all remuneration records',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Type "CONFIRM" to proceed:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    autofocus: true,
                    onChanged: (value) {
                      setDialogState(() => confirmText = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Type CONFIRM',
                      border: const OutlineInputBorder(),
                      errorText: confirmText.isNotEmpty && !canConfirm
                          ? 'Must type "CONFIRM" exactly'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true)
                    .pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canConfirm
                    ? () => Navigator.of(context, rootNavigator: true).pop(true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canConfirm ? Colors.red : Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm New County'),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}

/// True when all four identity values differ from originals.
bool countyAllFourFieldsChanged({
  required String name,
  required String address,
  required String contact,
  required String registration,
  required String originalName,
  required String originalAddress,
  required String originalContact,
  required String originalRegistration,
}) {
  return name.trim() != originalName.trim() &&
      address.trim() != originalAddress.trim() &&
      contact.trim() != originalContact.trim() &&
      registration.trim() != originalRegistration.trim();
}
