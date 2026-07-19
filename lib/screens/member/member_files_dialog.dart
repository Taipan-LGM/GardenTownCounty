import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/member.dart';
import '../../models/member_file.dart';
import '../../providers/providers.dart';

Future<void> showMemberFilesDialog(
  BuildContext context,
  WidgetRef ref,
  Member member,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => MemberFilesDialog(member: member),
  );
}

class MemberFilesDialog extends ConsumerStatefulWidget {
  const MemberFilesDialog({super.key, required this.member});

  final Member member;

  @override
  ConsumerState<MemberFilesDialog> createState() => _MemberFilesDialogState();
}

class _MemberFilesDialogState extends ConsumerState<MemberFilesDialog> {
  List<MemberFile> _files = const [];
  bool _loading = true;
  bool _uploading = false;
  final _descriptionController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final files = await ref
        .read(fileStorageServiceProvider)
        .listForMember(widget.member.id);
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _upload() async {
    final user = ref.read(authUserProvider);
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      final file = await ref.read(fileStorageServiceProvider).pickAndUpload(
            memberId: widget.member.id,
            uploadedBy: user.displayName,
            description: _descriptionController.text,
          );
      if (file != null) {
        _descriptionController.clear();
        await _reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded ${file.fileName}')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  IconData _iconFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return Icons.description;
    }
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return Icons.table_chart;
    }
    return Icons.insert_drive_file;
  }

  Future<void> _open(MemberFile file) async {
    if (file.localPath != null) {
      await OpenFilex.open(file.localPath!);
      return;
    }
    final url = file.storageUrl;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);

    return AlertDialog(
      title: Text('Files — ${widget.member.fullName}'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Brief File Description (for next upload)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Pick from Documents / File Explorer'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Logged in as: ${user?.displayName ?? 'Unknown'} · '
              'All file types supported (PDF, DOCX, XLSX, …) · Sorted A–Z',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                      ? const Center(child: Text('No files uploaded yet.'))
                      : ListView.separated(
                          itemCount: _files.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return _FileRow(
                              file: file,
                              dateLabel: _dateFormat.format(
                                file.uploadedAt.toLocal(),
                              ),
                              icon: _iconFor(file.fileName),
                              onOpen: () => _open(file),
                              onDescriptionChanged: (value) async {
                                await ref
                                    .read(fileStorageServiceProvider)
                                    .updateDescription(file, value);
                              },
                              onDelete: () async {
                                await ref
                                    .read(fileStorageServiceProvider)
                                    .deleteFile(file);
                                await _reload();
                              },
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
      ],
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.file,
    required this.dateLabel,
    required this.icon,
    required this.onOpen,
    required this.onDescriptionChanged,
    required this.onDelete,
  });

  final MemberFile file;
  final String dateLabel;
  final IconData icon;
  final VoidCallback onOpen;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onDelete;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  late final TextEditingController _desc;

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(text: widget.file.description);
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: widget.onOpen,
                  child: Text(
                    widget.file.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Uploaded: ${widget.dateLabel}'),
                Text('User: ${widget.file.uploadedBy}'),
                const SizedBox(height: 6),
                TextField(
                  controller: _desc,
                  decoration: const InputDecoration(
                    labelText: 'Brief File Description',
                    isDense: true,
                  ),
                  onEditingComplete: () =>
                      widget.onDescriptionChanged(_desc.text),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
