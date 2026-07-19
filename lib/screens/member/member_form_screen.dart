import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lookup_item.dart';
import '../../models/member.dart';
import '../../providers/providers.dart';
import 'lookup_manager_dialog.dart';
import 'member_files_dialog.dart';

class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key});

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saId = TextEditingController();
  final _globalRecordNo = TextEditingController();
  final _memberName = TextEditingController();
  final _surname = TextEditingController();
  final _address = TextEditingController();
  final _contactNo1 = TextEditingController();
  final _contactNo2 = TextEditingController();
  final _email = TextEditingController();
  final _comment = TextEditingController();

  String? _suburb;
  String? _townCity;
  String? _postalCode;
  String? _currentId;
  List<Member> _members = const [];
  int _browseIndex = -1;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _saId.dispose();
    _globalRecordNo.dispose();
    _memberName.dispose();
    _surname.dispose();
    _address.dispose();
    _contactNo1.dispose();
    _contactNo2.dispose();
    _email.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final members = await ref.read(memberRepositoryProvider).getAll();
    final selectedId = ref.read(selectedMemberIdProvider);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });

    if (selectedId != null) {
      final index = members.indexWhere((m) => m.id == selectedId);
      if (index >= 0) {
        _loadMember(members[index], index);
        return;
      }
    }
    if (members.isNotEmpty) {
      _loadMember(members.first, 0);
    } else {
      _clearForm(newMember: true);
    }
  }

  void _loadMember(Member member, int index) {
    setState(() {
      _currentId = member.id;
      _browseIndex = index;
      _saId.text = member.saId;
      _globalRecordNo.text = member.globalRecordNo;
      _memberName.text = member.memberName;
      _surname.text = member.surname;
      _address.text = member.address;
      _suburb = member.suburb.isEmpty ? null : member.suburb;
      _townCity = member.townCity.isEmpty ? null : member.townCity;
      _postalCode = member.postalCode.isEmpty ? null : member.postalCode;
      _contactNo1.text = member.contactNo1;
      _contactNo2.text = member.contactNo2;
      _email.text = member.emailAddress;
      _comment.text = member.comment;
    });
    ref.read(selectedMemberIdProvider.notifier).state = member.id;
  }

  void _clearForm({required bool newMember}) {
    setState(() {
      _currentId = null;
      if (newMember) _browseIndex = -1;
      _saId.clear();
      _globalRecordNo.clear();
      _memberName.clear();
      _surname.clear();
      _address.clear();
      _suburb = null;
      _townCity = null;
      _postalCode = null;
      _contactNo1.clear();
      _contactNo2.clear();
      _email.clear();
      _comment.clear();
    });
    ref.read(selectedMemberIdProvider.notifier).state = null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final existing = _currentId == null
          ? null
          : await ref.read(memberRepositoryProvider).getById(_currentId!);

      final member = (existing ??
              Member.create(
                saId: _saId.text.trim(),
                globalRecordNo: _globalRecordNo.text.trim(),
                memberName: _memberName.text.trim(),
                surname: _surname.text.trim(),
              ))
          .copyWith(
        saId: _saId.text.trim(),
        globalRecordNo: _globalRecordNo.text.trim(),
        memberName: _memberName.text.trim(),
        surname: _surname.text.trim(),
        address: _address.text.trim(),
        suburb: _suburb ?? '',
        townCity: _townCity ?? '',
        postalCode: _postalCode ?? '',
        contactNo1: _contactNo1.text.trim(),
        contactNo2: _contactNo2.text.trim(),
        emailAddress: _email.text.trim(),
        comment: _comment.text.trim(),
        updatedAt: DateTime.now().toUtc(),
        pendingSync: true,
        deleted: false,
      );

      final saved = await ref.read(memberRepositoryProvider).save(member);
      final user = ref.read(authUserProvider);
      if (user != null) {
        await ref.read(activityServiceProvider).record(
              userName: user.displayName,
              action: existing == null
                  ? 'Created member ${saved.fullName}'
                  : 'Updated member ${saved.fullName}',
              captureGps: false,
            );
      }

      await _bootstrap();
      final index = _members.indexWhere((m) => m.id == saved.id);
      if (index >= 0) _loadMember(_members[index], index);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member saved')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_currentId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete member?'),
        content: const Text('This soft-deletes the member and syncs to cloud.'),
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
    await ref.read(memberRepositoryProvider).delete(_currentId!);
    await _bootstrap();
  }

  void _browse(int delta) {
    if (_members.isEmpty) return;
    var next = _browseIndex + delta;
    if (_browseIndex < 0) next = 0;
    if (next < 0) next = _members.length - 1;
    if (next >= _members.length) next = 0;
    _loadMember(_members[next], next);
  }

  Widget _lookupDropdown({
    required String label,
    required LookupType type,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final asyncItems = ref.watch(lookupsProvider(type));
    return asyncItems.when(
      data: (items) {
        final values = items.map((e) => e.value).toList();
        final effective =
            value != null && values.contains(value) ? value : null;
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey(
                  '${type.storageKey}-${_currentId ?? 'new'}-$effective',
                ),
                initialValue: effective,
                decoration: InputDecoration(labelText: label),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Select —'),
                  ),
                  ...values.map(
                    (v) => DropdownMenuItem<String?>(value: v, child: Text(v)),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
            IconButton(
              tooltip: 'Manage $label',
              icon: const Icon(Icons.edit_note),
              onPressed: () async {
                await showLookupManagerDialog(context, ref, type);
                ref.invalidate(lookupsProvider(type));
              },
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Lookup error: $e'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Member Info',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestGreen,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () {
                  _clearForm(newMember: true);
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Member'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.forestGreen,
                ),
              ),
              const SizedBox(width: 8),
              if (_currentId != null)
                OutlinedButton.icon(
                  onPressed: () {
                    final member = _members
                        .where((m) => m.id == _currentId)
                        .cast<Member?>()
                        .firstWhere((m) => m != null, orElse: () => null);
                    if (member == null) return;
                    showMemberFilesDialog(context, ref, member);
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Files'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: _members.isEmpty ? null : () => _browse(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _browseIndex < 0
                    ? 'New member'
                    : 'Browse ${_browseIndex + 1} / ${_members.length}',
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: _members.isEmpty ? null : () => _browse(1),
                icon: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              if (_currentId != null)
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                key: ValueKey<String>(_currentId ?? 'new-member'),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _saId,
                          decoration: const InputDecoration(
                            labelText: 'SA ID (max 13)',
                          ),
                          maxLength: AppConstants.saIdMaxLength,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (v.length > AppConstants.saIdMaxLength) {
                              return 'Max 13 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _globalRecordNo,
                          decoration: const InputDecoration(
                            labelText: 'Global Record No (max 14)',
                          ),
                          maxLength: AppConstants.globalRecordNoMaxLength,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (v.length >
                                AppConstants.globalRecordNoMaxLength) {
                              return 'Max 14 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memberName,
                          decoration:
                              const InputDecoration(labelText: 'Member Name'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _surname,
                          decoration:
                              const InputDecoration(labelText: 'Surname'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  _lookupDropdown(
                    label: 'Suburb',
                    type: LookupType.suburb,
                    value: _suburb,
                    onChanged: (v) => setState(() => _suburb = v),
                  ),
                  const SizedBox(height: 8),
                  _lookupDropdown(
                    label: 'Town / City',
                    type: LookupType.townCity,
                    value: _townCity,
                    onChanged: (v) => setState(() => _townCity = v),
                  ),
                  const SizedBox(height: 8),
                  _lookupDropdown(
                    label: 'Postal Code',
                    type: LookupType.postalCode,
                    value: _postalCode,
                    onChanged: (v) => setState(() => _postalCode = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactNo1,
                          decoration: const InputDecoration(
                            labelText: 'Contact No 1',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _contactNo2,
                          decoration: const InputDecoration(
                            labelText: 'Contact No 2',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration:
                        const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _comment,
                    decoration: const InputDecoration(labelText: 'Comment'),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
