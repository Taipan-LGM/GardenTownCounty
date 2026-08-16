import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../providers/providers.dart';

/// Displays the personalized Land Recording Office (LRO) Public Notice that
/// was generated when the Member completed Step 4_LRO. It is shown to the right
/// of the Member's photo as a permanent record.
class MemberLroNoticePanel extends ConsumerWidget {
  const MemberLroNoticePanel({
    super.key,
    required this.recordingNumber,
    required this.noticeImageBase64,
  });

  final String? recordingNumber;
  final String? noticeImageBase64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final hasImage = noticeImageBase64 != null &&
        noticeImageBase64!.isNotEmpty &&
        noticeImageBase64!.startsWith('data:');
    final bytes = hasImage
        ? Uri.parse(noticeImageBase64!).data?.contentAsBytes()
        : null;

    return SizedBox(
      width: 240,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.lroPublicNotice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (bytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      strings.lroPublicNoticeNone,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              if (recordingNumber != null && recordingNumber!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Recording No: $recordingNumber',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
