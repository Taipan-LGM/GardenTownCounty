import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'form_dialog_title.dart';

const _kConfidentialityAcceptedKey = 'gtc_confidentiality_accepted_v1';

/// Shows once until accepted. Reject signs the user out via [onReject].
Future<bool> ensureConfidentialityAccepted(
  BuildContext context, {
  required VoidCallback onReject,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kConfidentialityAcceptedKey) == true) {
    return true;
  }
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: FormDialogTitle(
        title: '⚠️ Confidentiality Agreement',
        onClose: () => Navigator.pop(ctx, false),
      ),
      titlePadding: formDialogTitlePadding,
      content: const SingleChildScrollView(
        child: Text(
          'By accessing this system, you agree to the following:\n\n'
          '1. All member information is confidential.\n'
          '2. Screenshots of locked member information are strictly prohibited.\n'
          '3. All attempts to capture or share member information will be logged.\n'
          '4. Unauthorized sharing of member information will result in '
          'disciplinary action.\n\n'
          'Do you accept these terms?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('I Accept'),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await prefs.setBool(_kConfidentialityAcceptedKey, true);
    return true;
  }
  onReject();
  return false;
}
