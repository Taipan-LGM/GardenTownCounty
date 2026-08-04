import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/member.dart';
import '../../models/member_file.dart';
import '../../models/remuneration_settings.dart';
import '../../providers/providers.dart';
import '../../widgets/standard_buttons.dart';

class MemberFilesScreen extends ConsumerStatefulWidget {
  const MemberFilesScreen({super.key, required this.member});

  final Member member;

  @override
  ConsumerState<MemberFilesScreen> createState() => _MemberFilesScreenState();
}

class _MemberFilesScreenState extends ConsumerState<MemberFilesScreen> {
  List<MemberFile> _files = const [];
  late Member _member;
  bool _loading = true;
  final Set<int> _uploadingSteps = <int>{};
  final Set<int> _savingDescriptionSteps = <int>{};
  final Set<int> _editingDescriptionSteps = <int>{};
  final Map<int, List<_DraftFileRow>> _drafts = {};
  Map<int, List<String>> _descriptionTemplates = const {};
  final Map<String, String> _fileTemplateKeys = {};
  String? _selectedRowId;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _reload();
  }

  @override
  void dispose() {
    for (final rows in _drafts.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    final database = ref.read(databaseServiceProvider);
    final results = await Future.wait([
      ref.read(fileStorageServiceProvider).listForMember(widget.member.id),
      database.getMemberById(widget.member.id),
      ref.read(remunerationServiceProvider).getSettings(),
    ]);
    if (!mounted) return;
    setState(() {
      _files = results[0] as List<MemberFile>;
      _member = (results[1] as Member?) ?? _member;
      final settings = results[2] as RemunerationSettings;
      _descriptionTemplates = {
        for (final entry in settings.descriptionTemplates.entries)
          entry.key: List<String>.from(entry.value),
      };
      _materializeTemplateDrafts();
      _loading = false;
    });
  }

  void _materializeTemplateDrafts() {
    _fileTemplateKeys.clear();
    for (final entry in _drafts.entries) {
      final currentTemplates = _descriptionTemplates[entry.key]?.toSet() ?? {};
      entry.value.removeWhere((draft) {
        final templateKey = draft.templateKey;
        if (templateKey == null || currentTemplates.contains(templateKey)) {
          return false;
        }
        final description = draft.description.text.trim();
        if (currentTemplates.contains(description)) {
          draft.templateKey = description;
          return false;
        }
        if (_selectedRowId == draft.id) _selectedRowId = null;
        draft.dispose();
        return true;
      });
    }
    for (final entry in _descriptionTemplates.entries) {
      final stepFiles = _files.where((file) => file.stepNumber == entry.key);
      final stepDrafts = _drafts[entry.key] ??= [];
      for (final template in entry.value) {
        final matchingFiles = stepFiles.where(
          (file) => file.description == template,
        );
        if (matchingFiles.isNotEmpty) {
          _fileTemplateKeys[matchingFiles.first.id] = template;
          continue;
        }
        final matchingDrafts = stepDrafts.where(
          (draft) =>
              draft.templateKey == template ||
              draft.description.text.trim() == template,
        );
        if (matchingDrafts.isNotEmpty) {
          matchingDrafts.first.templateKey = template;
          continue;
        }
        stepDrafts.add(
          _DraftFileRow(description: template, templateKey: template),
        );
      }
    }
  }

  void _addDraft(int stepNumber) {
    setState(() {
      (_drafts[stepNumber] ??= []).add(_DraftFileRow());
    });
  }

  void _updateLocalDescription(MemberFile file, String description) {
    final index = _files.indexWhere((item) => item.id == file.id);
    if (index < 0) return;
    setState(() {
      _files[index] = _files[index].copyWith(description: description);
    });
  }

  Future<void> _handleDescriptionAction(int stepNumber) async {
    final user = ref.read(authUserProvider);
    if (user == null || !user.isAdmin) return;
    final oldTemplates = _descriptionTemplates[stepNumber] ?? const [];
    if (oldTemplates.isNotEmpty &&
        !_editingDescriptionSteps.contains(stepNumber)) {
      setState(() => _editingDescriptionSteps.add(stepNumber));
      return;
    }

    final stepFiles = _files
        .where((file) => file.stepNumber == stepNumber)
        .toList(growable: false);
    final stepDrafts = _drafts[stepNumber] ?? const <_DraftFileRow>[];
    final descriptions = <String>[];
    final replacements = <String, String>{};

    for (final oldTemplate in oldTemplates) {
      final matchingFiles = stepFiles.where(
        (file) => _fileTemplateKeys[file.id] == oldTemplate,
      );
      final matchingDrafts = stepDrafts.where(
        (draft) => draft.templateKey == oldTemplate,
      );
      final edited = matchingFiles.isNotEmpty
          ? matchingFiles.first.description.trim()
          : matchingDrafts.isNotEmpty
          ? matchingDrafts.first.description.text.trim()
          : '';
      if (edited.isNotEmpty) {
        descriptions.add(edited);
        replacements[oldTemplate] = edited;
      }
    }
    for (final file in stepFiles.where(
      (file) => !_fileTemplateKeys.containsKey(file.id),
    )) {
      final description = file.description.trim();
      if (description.isNotEmpty) descriptions.add(description);
    }
    for (final draft in stepDrafts.where(
      (draft) => draft.templateKey == null,
    )) {
      final description = draft.description.text.trim();
      if (description.isNotEmpty) descriptions.add(description);
    }

    final uniqueDescriptions = <String>[];
    for (final description in descriptions) {
      if (!uniqueDescriptions.contains(description)) {
        uniqueDescriptions.add(description);
      }
    }
    if (uniqueDescriptions.isEmpty) {
      _showMessage(
        'Add at least one Brief Description before saving.',
        isError: true,
      );
      return;
    }

    setState(() => _savingDescriptionSteps.add(stepNumber));
    try {
      final currentSettings = await ref
          .read(remunerationServiceProvider)
          .getSettings();
      final updatedTemplates = <int, List<String>>{
        for (final entry in currentSettings.descriptionTemplates.entries)
          entry.key: List<String>.from(entry.value),
        stepNumber: uniqueDescriptions,
      };
      await ref
          .read(fileStorageServiceProvider)
          .updateTemplateDescriptions(stepNumber, replacements);
      await ref
          .read(remunerationSettingsProvider.notifier)
          .save(
            currentSettings.copyWith(descriptionTemplates: updatedTemplates),
          );
      if (!mounted) return;
      setState(() {
        _descriptionTemplates = updatedTemplates;
        _editingDescriptionSteps.remove(stepNumber);
        for (final file in stepFiles) {
          final oldKey = _fileTemplateKeys[file.id];
          if (oldKey != null) {
            _fileTemplateKeys[file.id] = replacements[oldKey] ?? oldKey;
          }
        }
        for (final draft in stepDrafts) {
          final oldKey = draft.templateKey;
          if (oldKey != null) {
            draft.templateKey = replacements[oldKey] ?? oldKey;
          } else if (draft.description.text.trim().isNotEmpty) {
            draft.templateKey = draft.description.text.trim();
          }
        }
      });
      await _reload();
      _showMessage('Step $stepNumber descriptions saved for all members.');
    } catch (error) {
      _showMessage('Could not save descriptions: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _savingDescriptionSteps.remove(stepNumber));
      }
    }
  }

  void _deleteDraft(int stepNumber, _DraftFileRow draft) {
    draft.dispose();
    setState(() {
      _drafts[stepNumber]?.remove(draft);
      if (_selectedRowId == draft.id) _selectedRowId = null;
    });
  }

  Future<void> _upload(int stepNumber) async {
    final user = ref.read(authUserProvider);
    if (user == null || (!user.isAdmin && !user.isSecretary)) return;
    final drafts = _drafts[stepNumber] ?? const <_DraftFileRow>[];
    final draft = drafts.isEmpty ? null : drafts.last;

    setState(() => _uploadingSteps.add(stepNumber));
    try {
      final file = await ref
          .read(fileStorageServiceProvider)
          .pickAndUpload(
            memberId: widget.member.id,
            uploadedBy: user.displayName,
            description: draft?.description.text ?? '',
            stepNumber: stepNumber,
          );
      if (file == null) return;
      if (draft != null) {
        draft.dispose();
        _drafts[stepNumber]?.remove(draft);
      }
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Uploaded ${file.fileName}')));
      }
    } catch (error) {
      _showMessage('Upload failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingSteps.remove(stepNumber));
    }
  }

  Future<void> _openExternal(MemberFile file) async {
    if (file.localPath != null && file.localPath!.isNotEmpty) {
      await OpenFile.open(file.localPath!);
      return;
    }
    final url = file.storageUrl;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _preview(MemberFile file) async {
    final storage = ref.read(fileStorageServiceProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MemberFilePreviewScreen(
          file: file,
          loadBytes: () => storage.loadMemberFileBytes(file),
          onOpenExternal: () => _openExternal(file),
        ),
      ),
    );
  }

  Future<void> _toggleConfirmation(MemberFile file, bool confirmed) async {
    final user = ref.read(authUserProvider);
    if (user == null || (!user.isAdmin && !user.isSecretary)) return;

    try {
      if (!confirmed && _member.isStepCompleteAt(file.stepNumber)) {
        _member = await ref
            .read(memberLockServiceProvider)
            .setOnboardingStep(
              member: _member,
              actor: user,
              step: file.stepNumber,
              complete: false,
            );
      }

      final updated = await ref
          .read(fileStorageServiceProvider)
          .updateConfirmation(file, confirmed);
      final index = _files.indexWhere((item) => item.id == file.id);
      if (index >= 0 && mounted) {
        setState(() => _files[index] = updated);
      }

      if (confirmed) await _completeStepIfReady(file.stepNumber);
      ref.invalidate(membersProvider);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _completeStepIfReady(int stepNumber) async {
    final stepFiles = _files
        .where((file) => file.stepNumber == stepNumber)
        .toList(growable: false);
    final templates = _descriptionTemplates[stepNumber] ?? const [];
    final allRowsConfirmed = templates.isNotEmpty
        ? templates.every(
            (template) => stepFiles.any(
              (file) => file.description == template && file.uploadConfirmed,
            ),
          )
        : stepFiles.isNotEmpty &&
              (_drafts[stepNumber]?.isEmpty ?? true) &&
              stepFiles.every((file) => file.uploadConfirmed);
    if (!allRowsConfirmed) {
      return;
    }
    if (_member.isStepCompleteAt(stepNumber)) return;

    final user = ref.read(authUserProvider);
    if (user == null) return;
    try {
      _member = await ref
          .read(memberLockServiceProvider)
          .setOnboardingStep(
            member: _member,
            actor: user,
            step: stepNumber,
            complete: true,
          );
      ref.invalidate(membersProvider);
      if (mounted) setState(() {});
      _showMessage('Step $stepNumber completed.');
    } catch (error) {
      _showMessage(
        'All uploads confirmed. ${_cleanError(error)}',
        isError: false,
      );
    }
  }

  Future<void> _deleteUpload(MemberFile file, String description) async {
    final user = ref.read(authUserProvider);
    if (user == null || (!user.isAdmin && !user.isSecretary)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete uploaded file?'),
        content: Text(
          'Delete ${file.fileName}? The description row will remain so another file can be uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete File'),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(fileStorageServiceProvider).deleteFile(file);
    if (!mounted) return;
    setState(() {
      _files = _files.where((item) => item.id != file.id).toList();
      (_drafts[file.stepNumber] ??= []).add(
        _DraftFileRow(description: description),
      );
      if (_selectedRowId == file.id) _selectedRowId = null;
    });
    _showMessage('${file.fileName} deleted. The description row was kept.');
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^(Exception|Bad state): '), '');

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_cleanError(message)),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final canManage = isAdmin || (user?.isSecretary ?? false);
    final settings =
        ref.watch(remunerationSettingsProvider).valueOrNull ??
        RemunerationSettings.defaults();
    final steps = settings.allSteps
        .where((step) => step.number >= 1 && step.number <= 5)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Upload Files - ${widget.member.fullName.toUpperCase()}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !canManage
          ? const Center(
              child: Text(
                'Only Admin and Recording Secretary can upload files.',
              ),
            )
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MemberHeader(member: widget.member),
                  const Divider(height: 1),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            itemCount: steps.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final step = steps[index];
                              final files = _files
                                  .where(
                                    (file) => file.stepNumber == step.number,
                                  )
                                  .toList(growable: false);
                              final templates =
                                  _descriptionTemplates[step.number] ??
                                  const <String>[];
                              final drafts =
                                  _drafts[step.number] ??
                                  const <_DraftFileRow>[];
                              final allConfirmed = templates.isNotEmpty
                                  ? templates.every(
                                      (template) => files.any(
                                        (file) =>
                                            file.description == template &&
                                            file.uploadConfirmed,
                                      ),
                                    )
                                  : files.isNotEmpty &&
                                        drafts.isEmpty &&
                                        files.every(
                                          (file) => file.uploadConfirmed,
                                        );
                              return _StepFilesSection(
                                step: step,
                                files: files,
                                drafts: drafts,
                                isAdmin: isAdmin,
                                selectedRowId: _selectedRowId,
                                uploading: _uploadingSteps.contains(
                                  step.number,
                                ),
                                savingDescriptions: _savingDescriptionSteps
                                    .contains(step.number),
                                descriptionsSaved: templates.isNotEmpty,
                                editingDescriptions: _editingDescriptionSteps
                                    .contains(step.number),
                                allConfirmed: allConfirmed,
                                onDescriptionAction: () =>
                                    _handleDescriptionAction(step.number),
                                onUpload: () => _upload(step.number),
                                onNew: () => _addDraft(step.number),
                                onSelect: (id) => setState(() {
                                  _selectedRowId = _selectedRowId == id
                                      ? null
                                      : id;
                                }),
                                onOpen: _preview,
                                onDescriptionChanged: _updateLocalDescription,
                                onConfirmationChanged: _toggleConfirmation,
                                onDeleteUpload: _deleteUpload,
                                onDeleteDraft: (draft) =>
                                    _deleteDraft(step.number, draft),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 26),
          Text(
            'Member Name: ${member.memberName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Surname: ${member.surname}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _StepFilesSection extends StatelessWidget {
  const _StepFilesSection({
    required this.step,
    required this.files,
    required this.drafts,
    required this.isAdmin,
    required this.selectedRowId,
    required this.uploading,
    required this.savingDescriptions,
    required this.descriptionsSaved,
    required this.editingDescriptions,
    required this.allConfirmed,
    required this.onDescriptionAction,
    required this.onUpload,
    required this.onNew,
    required this.onSelect,
    required this.onOpen,
    required this.onDescriptionChanged,
    required this.onConfirmationChanged,
    required this.onDeleteUpload,
    required this.onDeleteDraft,
  });

  final RemunerationStep step;
  final List<MemberFile> files;
  final List<_DraftFileRow> drafts;
  final bool isAdmin;
  final String? selectedRowId;
  final bool uploading;
  final bool savingDescriptions;
  final bool descriptionsSaved;
  final bool editingDescriptions;
  final bool allConfirmed;
  final VoidCallback onDescriptionAction;
  final VoidCallback onUpload;
  final VoidCallback onNew;
  final ValueChanged<String> onSelect;
  final ValueChanged<MemberFile> onOpen;
  final void Function(MemberFile, String) onDescriptionChanged;
  final void Function(MemberFile, bool) onConfirmationChanged;
  final void Function(MemberFile, String) onDeleteUpload;
  final ValueChanged<_DraftFileRow> onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_ZA',
      symbol: 'R ',
      decimalDigits: 2,
    );
    final descriptionsEditable =
        isAdmin && (!descriptionsSaved || editingDescriptions);
    final descriptionActionText = descriptionsSaved && !editingDescriptions
        ? 'Edit Description'
        : 'Save Description';
    final stepInfo = Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(step.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Amount: ${currency.format(step.amount)}'),
        if (allConfirmed)
          const Text(
            '✓ Completed',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700),
          ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        AddButton(
          onPressed: isAdmin && !savingDescriptions
              ? onDescriptionAction
              : null,
          text: savingDescriptions ? 'Saving...' : descriptionActionText,
          icon: descriptionsSaved && !editingDescriptions
              ? Icons.edit_outlined
              : Icons.save_outlined,
          height: 36,
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        AddButton(
          onPressed: uploading ? null : onUpload,
          text: 'Upload File',
          icon: Icons.upload_file,
          height: 36,
        ),
        AddButton(
          onPressed: descriptionsEditable ? onNew : null,
          text: 'New',
          icon: Icons.add,
          height: 36,
          backgroundColor: AppButtonColors.newBg,
          foregroundColor: AppButtonColors.newFg,
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [stepInfo, const SizedBox(height: 10), actions],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: stepInfo),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
          if (files.isEmpty && drafts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No files in this step. Select New to add a row.'),
            ),
          for (final file in files)
            _UploadedFileRow(
              key: ValueKey(file.id),
              file: file,
              descriptionEditable: descriptionsEditable,
              onOpen: () => onOpen(file),
              onDescriptionChanged: (value) =>
                  onDescriptionChanged(file, value),
              onConfirmationChanged: (value) =>
                  onConfirmationChanged(file, value),
              onDeleteUpload: (description) =>
                  onDeleteUpload(file, description),
            ),
          for (final draft in drafts)
            _DraftRow(
              key: ValueKey(draft.id),
              draft: draft,
              isAdmin: isAdmin,
              descriptionEditable: descriptionsEditable,
              selected: selectedRowId == draft.id,
              onSelect: () => onSelect(draft.id),
              onDelete: () => onDeleteDraft(draft),
            ),
        ],
      ),
    );
  }
}

class _UploadedFileRow extends StatefulWidget {
  const _UploadedFileRow({
    super.key,
    required this.file,
    required this.descriptionEditable,
    required this.onOpen,
    required this.onDescriptionChanged,
    required this.onConfirmationChanged,
    required this.onDeleteUpload,
  });

  final MemberFile file;
  final bool descriptionEditable;
  final VoidCallback onOpen;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<bool> onConfirmationChanged;
  final ValueChanged<String> onDeleteUpload;

  @override
  State<_UploadedFileRow> createState() => _UploadedFileRowState();
}

class _UploadedFileRowState extends State<_UploadedFileRow> {
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.file.description);
  }

  @override
  void didUpdateWidget(covariant _UploadedFileRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.description != widget.file.description &&
        _description.text != widget.file.description) {
      _description.text = widget.file.description;
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final description = TextField(
      controller: _description,
      enabled: widget.descriptionEditable,
      decoration: const InputDecoration(
        labelText: 'Brief Description',
        isDense: true,
      ),
      onChanged: widget.onDescriptionChanged,
    );
    final fileLink = Row(
      children: [
        Expanded(
          child: Tooltip(
            message: 'Double-click to view full screen',
            child: InkWell(
              onDoubleTap: widget.onOpen,
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.file.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'View uploaded file',
          onPressed: widget.onOpen,
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: 'Delete uploaded file',
          onPressed: () => widget.onDeleteUpload(_description.text),
          color: Colors.red.shade700,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
    final confirmation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: widget.file.uploadConfirmed,
          onChanged: (value) => widget.onConfirmationChanged(value ?? false),
        ),
        const Text('Confirmed'),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                SizedBox(width: double.infinity, child: description),
                const SizedBox(height: 10),
                fileLink,
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [confirmation],
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 520, child: description),
              const SizedBox(width: 14),
              Expanded(child: fileLink),
              const SizedBox(width: 12),
              confirmation,
            ],
          );
        },
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    super.key,
    required this.draft,
    required this.isAdmin,
    required this.descriptionEditable,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final _DraftFileRow draft;
  final bool isAdmin;
  final bool descriptionEditable;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final selector = SizedBox(
      width: 40,
      child: isAdmin
          ? IconButton(
              tooltip: selected ? 'Deselect row' : 'Select row',
              onPressed: onSelect,
              icon: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
            )
          : const SizedBox.shrink(),
    );
    final description = TextField(
      controller: draft.description,
      enabled: descriptionEditable,
      decoration: const InputDecoration(
        labelText: 'Brief Description',
        isDense: true,
      ),
    );
    const fileName = Row(
      children: [
        Icon(Icons.insert_drive_file_outlined, size: 20),
        SizedBox(width: 8),
        Text('No file selected'),
      ],
    );
    const confirmation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Checkbox(value: false, onChanged: null), Text('Confirmed')],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final deleteButton = isAdmin && descriptionEditable
              ? DeleteButton(
                  onPressed: selected ? onDelete : null,
                  text: 'Delete',
                  icon: Icons.delete_outline,
                  width: 105,
                  height: 36,
                )
              : null;
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                Row(
                  children: [
                    selector,
                    const SizedBox(width: 8),
                    Expanded(child: description),
                  ],
                ),
                const SizedBox(height: 10),
                fileName,
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    confirmation,
                    if (deleteButton != null) ...[
                      const SizedBox(width: 12),
                      deleteButton,
                    ],
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              selector,
              SizedBox(width: 520, child: description),
              const SizedBox(width: 14),
              const Expanded(child: fileName),
              const SizedBox(width: 12),
              confirmation,
              if (deleteButton != null) ...[
                const SizedBox(width: 12),
                deleteButton,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DraftFileRow {
  _DraftFileRow({String description = '', this.templateKey})
    : id = 'draft_${DateTime.now().microsecondsSinceEpoch}',
      description = TextEditingController(text: description);

  final String id;
  final TextEditingController description;
  String? templateKey;

  void dispose() => description.dispose();
}

class _MemberFilePreviewScreen extends StatefulWidget {
  const _MemberFilePreviewScreen({
    required this.file,
    required this.loadBytes,
    required this.onOpenExternal,
  });

  final MemberFile file;
  final Future<Uint8List?> Function() loadBytes;
  final VoidCallback onOpenExternal;

  @override
  State<_MemberFilePreviewScreen> createState() =>
      _MemberFilePreviewScreenState();
}

class _MemberFilePreviewScreenState extends State<_MemberFilePreviewScreen> {
  late final Future<Uint8List?> _bytes = widget.loadBytes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.file.fileName),
        actions: [
          IconButton(
            tooltip: 'Open externally',
            onPressed: widget.onOpenExternal,
            icon: const Icon(Icons.open_in_new),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SizedBox.expand(
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _PreviewUnavailable(
                message: 'Could not load this file: ${snapshot.error}',
                onOpenExternal: widget.onOpenExternal,
              );
            }
            final bytes = snapshot.data;
            if (bytes == null || bytes.isEmpty) {
              return _PreviewUnavailable(
                message: 'This upload is not available in local storage.',
                onOpenExternal: widget.onOpenExternal,
              );
            }

            final extension = widget.file.fileName
                .split('.')
                .last
                .toLowerCase();
            if (widget.file.contentType.startsWith('image/') ||
                const {
                  'jpg',
                  'jpeg',
                  'png',
                  'gif',
                  'webp',
                  'bmp',
                }.contains(extension)) {
              return InteractiveViewer(
                minScale: 0.25,
                maxScale: 8,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              );
            }
            if (widget.file.contentType == 'application/pdf' ||
                extension == 'pdf') {
              return PdfViewer.data(bytes, sourceName: widget.file.fileName);
            }
            if (widget.file.contentType.startsWith('text/') ||
                const {
                  'txt',
                  'csv',
                  'json',
                  'xml',
                  'md',
                  'log',
                }.contains(extension)) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  utf8.decode(bytes, allowMalformed: true),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                ),
              );
            }
            return _PreviewUnavailable(
              message:
                  'A full-screen preview is not available for .$extension files. Open it in the installed application.',
              onOpenExternal: widget.onOpenExternal,
            );
          },
        ),
      ),
    );
  }
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({
    required this.message,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 72),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenExternal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Externally'),
            ),
          ],
        ),
      ),
    );
  }
}
