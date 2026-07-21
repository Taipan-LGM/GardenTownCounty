import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lookup_item.dart';
import '../../models/member.dart';
import '../../models/member_form_mode.dart';
import '../../providers/providers.dart';
import '../../widgets/file_image_stub.dart'
    if (dart.library.io) '../../widgets/file_image_io.dart' as file_img;
import '../../widgets/member_lock_banners.dart';
import '../../widgets/onboarding_checklist_card.dart';
import '../../widgets/screenshot_protected_view.dart';
import '../../services/temporary_access_service.dart';
import '../../services/secure_screen_service.dart';
import 'lookup_manager_dialog.dart';
import 'member_files_dialog.dart';

class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key});

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  static const _maskValue = '********';

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
  String? _photoLocalPath;
  String? _photoUrl;
  Uint8List? _photoBytes;
  /// Stable id for new (unsaved) members so a photo can be staged.
  String? _draftId;
  List<Member> _members = const [];
  int _browseIndex = -1;
  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;
  String? _adminLinkedMemberId;
  Member? _loadedMember;
  String? _lastLoggedSecureViewId;

  bool get _viewerIsSysAdmin =>
      ref.read(authUserProvider)?.isSystemAdministrator ?? false;

  bool get _viewerIsAdmin => ref.read(authUserProvider)?.isAdmin ?? false;

  bool get _isMemberOnly =>
      ref.read(authUserProvider)?.isMemberRole ?? false;

  String? get _viewerMemberId => ref.read(authUserProvider)?.memberId;

  bool get _sessionTempAccess {
    final id = _currentId;
    if (id == null) return false;
    return ref.read(verifiedTempAccessIdsProvider).contains(id);
  }

  MemberFormMode get _formMode => determineMemberFormMode(
        member: _loadedMember,
        user: ref.read(authUserProvider),
        sessionVerifiedTempAccess: _sessionTempAccess,
      );

  bool _isProtectedAdminMember(String? memberId) {
    if (memberId == null || _adminLinkedMemberId == null) return false;
    return memberId == _adminLinkedMemberId;
  }

  bool get _fieldsMasked =>
      _isProtectedAdminMember(_currentId) && !_viewerIsSysAdmin;

  bool get _canBrowseMembers => !_isMemberOnly;

  bool get _canAddMembers => !_isMemberOnly && !_fieldsMasked;

  bool get _formReadOnly {
    if (_fieldsMasked) return true;
    // Members may only view their own profile (read-only).
    if (_isMemberOnly) return true;
    return !_formMode.canEditFields;
  }

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
    SecureScreenService.disableSecureScreen();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final dbUsers = await ref.read(databaseServiceProvider).getAppUsers();
    String? adminMemberId;
    for (final u in dbUsers) {
      if (u.isSystemAdministrator) {
        adminMemberId = u.memberId;
        break;
      }
    }

    var members = await ref.read(memberRepositoryProvider).getAll();
    final auth = ref.read(authUserProvider);
    if (auth?.isMemberRole == true) {
      final linked = auth!.memberId;
      if (linked != null) {
        members = members.where((m) => m.id == linked).toList();
      } else {
        members = [];
      }
    }

    final selectedId = ref.read(selectedMemberIdProvider);
    if (!mounted) return;
    setState(() {
      _members = members;
      _adminLinkedMemberId = adminMemberId;
      _loading = false;
    });

    if (auth?.isMemberRole == true) {
      final linked = auth!.memberId;
      if (linked != null) {
        final index = members.indexWhere((m) => m.id == linked);
        if (index >= 0) {
          _loadMember(members[index], index);
          return;
        }
      }
      _clearForm(newMember: false);
      return;
    }

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
    final masked = _isProtectedAdminMember(member.id) && !_viewerIsSysAdmin;
    setState(() {
      _loadedMember = member;
      _currentId = member.id;
      _draftId = null;
      _browseIndex = index;
      _saId.text = masked ? _maskValue : member.saId;
      _globalRecordNo.text = masked ? _maskValue : member.globalRecordNo;
      _memberName.text = masked ? _maskValue : member.memberName;
      _surname.text = masked ? _maskValue : member.surname;
      _address.text = masked ? _maskValue : member.address;
      _suburb = masked
          ? _maskValue
          : (member.suburb.isEmpty ? null : member.suburb);
      _townCity = masked
          ? _maskValue
          : (member.townCity.isEmpty ? null : member.townCity);
      _postalCode = masked
          ? _maskValue
          : (member.postalCode.isEmpty ? null : member.postalCode);
      _contactNo1.text = masked ? _maskValue : member.contactNo1;
      _contactNo2.text = masked ? _maskValue : member.contactNo2;
      _email.text = masked ? _maskValue : member.emailAddress;
      _comment.text = masked ? _maskValue : member.comment;
      _photoLocalPath = member.photoLocalPath;
      _photoUrl = member.photoUrl;
      _photoBytes = null;
    });
    ref.read(selectedMemberIdProvider.notifier).state = member.id;
    if (!masked) {
      _loadPhotoBytes(member.id, member.photoLocalPath, member.photoUrl);
    }
    _onSecureMemberView(member);
  }

  Future<void> _onSecureMemberView(Member member) async {
    if (!member.isLocked) {
      await SecureScreenService.disableSecureScreen();
      return;
    }
    final user = ref.read(authUserProvider);
    if (user == null) return;
    // Log once per browse selection while this screen is open.
    if (_lastLoggedSecureViewId != member.id) {
      _lastLoggedSecureViewId = member.id;
      await ref.read(activityServiceProvider).record(
            userName: user.displayName,
            action:
                '🔒 view_locked_member ${member.fullName} '
                '(${user.userRole.label})',
            captureGps: false,
          );
    }
  }

  Future<void> _logScreenshotAttempt(Member member) async {
    final user = ref.read(authUserProvider);
    if (user == null) return;
    await ref.read(activityServiceProvider).record(
          userName: user.displayName,
          action:
              '⚠️ screenshot_attempt on locked member ${member.fullName}',
          captureGps: false,
        );
  }

  Future<void> _loadPhotoBytes(
    String memberId,
    String? localPath,
    String? photoUrl,
  ) async {
    Uint8List? bytes;
    if (localPath != null && localPath.startsWith('web-photo://')) {
      bytes = await ref
          .read(fileStorageServiceProvider)
          .loadWebPhotoBytes(memberId);
    } else if (photoUrl != null && photoUrl.startsWith('data:')) {
      bytes = Uri.parse(photoUrl).data?.contentAsBytes();
    }
    if (!mounted) return;
    if (bytes != null) {
      setState(() => _photoBytes = bytes);
    }
  }

  void _clearForm({required bool newMember}) {
    setState(() {
      _loadedMember = null;
      _currentId = null;
      _draftId = const Uuid().v4();
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
      _photoLocalPath = null;
      _photoUrl = null;
      _photoBytes = null;
    });
    ref.read(selectedMemberIdProvider.notifier).state = null;
  }

  Future<void> _pickMemberPhoto() async {
    final memberId = _currentId ?? _draftId;
    if (memberId == null) return;

    setState(() => _photoBusy = true);
    try {
      // CRITICAL (web): open file picker in the same user-gesture turn.
      // Any await before pickImageBytesWeb()/input.click() makes the browser
      // ignore the dialog — photo "does nothing".
      final storage = ref.read(fileStorageServiceProvider);
      final result = await storage.pickMemberPhoto(memberId: memberId);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo pick cancelled or no file selected.'),
          ),
        );
        return;
      }
      if (result.bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected file had no image data. Try JPG or PNG.'),
          ),
        );
        return;
      }

      // Apply preview immediately — do not wait on list refresh.
      setState(() {
        _photoLocalPath = result.path;
        _photoUrl = result.photoUrl;
        _photoBytes = result.bytes;
        _draftId = null;
        _currentId = memberId;
      });
      ref.read(selectedMemberIdProvider.notifier).state = memberId;

      final members = await ref.read(memberRepositoryProvider).getAll();
      if (!mounted) return;
      setState(() {
        _members = members;
        _browseIndex = members.indexWhere((m) => m.id == memberId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member photo saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _clearMemberPhoto() async {
    if (_currentId == null) {
      setState(() {
        _photoLocalPath = null;
        _photoUrl = null;
        _photoBytes = null;
      });
      return;
    }
    await ref.read(databaseServiceProvider).updateMemberPhoto(
          id: _currentId!,
          photoLocalPath: null,
          photoUrl: null,
        );
    setState(() {
      _photoLocalPath = null;
      _photoUrl = null;
      _photoBytes = null;
    });
    await ref.read(syncEngineProvider).pushPending();
  }

  Widget _memberPhotoPanel() {
    ImageProvider? image;
    if (_photoBytes != null) {
      image = MemoryImage(_photoBytes!);
    } else if (_photoUrl != null &&
        _photoUrl!.isNotEmpty &&
        !_photoUrl!.startsWith('data:')) {
      image = NetworkImage(_photoUrl!);
    } else if (_photoLocalPath != null &&
        !_photoLocalPath!.startsWith('web-photo://') &&
        file_img.localFileExists(_photoLocalPath!)) {
      image = file_img.localFileImage(_photoLocalPath!);
    }

    const photoSize = 320.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: (_photoBusy || _formReadOnly) ? null : _pickMemberPhoto,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: photoSize,
            height: photoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.forestGreen, width: 2),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_photoBusy)
                        const CircularProgressIndicator()
                      else ...[
                        const Icon(
                          Icons.add_a_photo_outlined,
                          size: 44,
                          color: AppTheme.forestGreen,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Member Photo',
                          style: TextStyle(
                            color: AppTheme.forestGreen.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  )
                : _photoBusy
                    ? const ColoredBox(
                        color: Colors.black26,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : null,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: (_photoBusy || _formReadOnly) ? null : _pickMemberPhoto,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(image == null ? 'Upload Photo' : 'Change Photo'),
        ),
        if (image != null && !_formReadOnly)
          TextButton(
            onPressed: _photoBusy ? null : _clearMemberPhoto,
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Future<void> _save() async {
    if (_isMemberOnly && _currentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members cannot create new member profiles.'),
          ),
        );
      }
      return;
    }
    if (_formReadOnly || _fieldsMasked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This member profile is protected and cannot be edited.'),
          ),
        );
      }
      return;
    }
    if (_isMemberOnly &&
        _viewerMemberId != null &&
        _currentId != null &&
        _currentId != _viewerMemberId) {
      return;
    }
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
        photoLocalPath: _photoLocalPath,
        photoUrl: _photoUrl,
        updatedAt: DateTime.now().toUtc(),
        pendingSync: true,
        deleted: false,
      );

      // Keep draft id when creating so a pre-picked photo stays linked.
      final toSave = (_currentId == null && _draftId != null)
          ? member.copyWith(id: _draftId)
          : (_currentId != null ? member.copyWith(id: _currentId) : member);

      final saved = await ref.read(memberRepositoryProvider).save(toSave);
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
    if (!_canBrowseMembers || _fieldsMasked) return;
    if (_currentId == null) return;
    final member = _loadedMember;
    if (member != null && member.isLocked && !_viewerIsAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 This member is locked and cannot be deleted.',
          ),
        ),
      );
      return;
    }
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
    if (_fieldsMasked) {
      return TextFormField(
        initialValue: _maskValue,
        decoration: InputDecoration(labelText: label),
        enabled: false,
      );
    }
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
                onChanged: _formReadOnly ? null : onChanged,
              ),
            ),
            IconButton(
              tooltip: 'Manage $label',
              icon: const Icon(Icons.edit_note),
              onPressed: _formReadOnly
                  ? null
                  : () async {
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

    final body = Padding(
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
              const SizedBox(width: 12),
              _statusChip(_formMode, _loadedMember),
              const Spacer(),
              if (_canAddMembers)
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
              if (_canAddMembers) const SizedBox(width: 8),
              if (_currentId != null && !_fieldsMasked)
                OutlinedButton.icon(
                  onPressed: _formReadOnly
                      ? () {
                          final member = _members
                              .where((m) => m.id == _currentId)
                              .cast<Member?>()
                              .firstWhere(
                                (m) => m != null,
                                orElse: () => null,
                              );
                          if (member == null) return;
                          showMemberFilesDialog(context, ref, member);
                        }
                      : () {
                          final member = _members
                              .where((m) => m.id == _currentId)
                              .cast<Member?>()
                              .firstWhere(
                                (m) => m != null,
                                orElse: () => null,
                              );
                          if (member == null) return;
                          showMemberFilesDialog(context, ref, member);
                        },
                  icon: Icon(
                    _formReadOnly ? Icons.folder_open : Icons.upload_file,
                  ),
                  label: Text(_formReadOnly ? 'View Files' : 'Upload Files'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_canBrowseMembers)
                IconButton(
                  tooltip: 'Previous',
                  onPressed: _members.isEmpty ? null : () => _browse(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
              Expanded(
                child: Text(
                  _browseLabel(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_canBrowseMembers)
                IconButton(
                  tooltip: 'Next',
                  onPressed: _members.isEmpty ? null : () => _browse(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              if (_currentId != null &&
                  _canBrowseMembers &&
                  !_fieldsMasked &&
                  !(_loadedMember?.isLocked == true && !_viewerIsAdmin))
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_saving ||
                        _formReadOnly ||
                        (_isMemberOnly && _currentId == null))
                    ? null
                    : _save,
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
          if (_loadedMember != null && _formMode.showTempAccessSection)
            _buildLockChrome(_loadedMember!),
          if (_loadedMember != null && _formMode.showOnboardingChecklist)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OnboardingChecklistCard(
                member: _loadedMember!,
                readOnly: _formMode.checklistReadOnly || _formReadOnly,
                showCompleteButton: _formMode.showCompleteButton,
                onToggleStep: _toggleOnboardingStep,
                onComplete: _completeAndLock,
              ),
            ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                key: ValueKey<String>(_currentId ?? 'new-member'),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const photoSize = 320.0;
                      // 4 fields spaced evenly to match photo panel height.
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: photoSize,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextFormField(
                                    controller: _saId,
                                    enabled: !_formReadOnly,
                                    decoration: const InputDecoration(
                                      labelText: 'SA ID (max 13)',
                                      isDense: true,
                                    ),
                                    maxLength: AppConstants.saIdMaxLength,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      if (v.length >
                                          AppConstants.saIdMaxLength) {
                                        return 'Max 13 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  TextFormField(
                                    controller: _globalRecordNo,
                                    enabled: !_formReadOnly,
                                    decoration: const InputDecoration(
                                      labelText: 'Global Record No (max 14)',
                                      isDense: true,
                                    ),
                                    maxLength:
                                        AppConstants.globalRecordNoMaxLength,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      if (v.length >
                                          AppConstants
                                              .globalRecordNoMaxLength) {
                                        return 'Max 14 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  TextFormField(
                                    controller: _memberName,
                                    enabled: !_formReadOnly,
                                    decoration: const InputDecoration(
                                      labelText: 'Member Name',
                                      isDense: true,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                  TextFormField(
                                    controller: _surname,
                                    enabled: !_formReadOnly,
                                    decoration: const InputDecoration(
                                      labelText: 'Surname',
                                      isDense: true,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _memberPhotoPanel(),
                          if (constraints.maxWidth > 720)
                            const Expanded(child: SizedBox()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    enabled: !_formReadOnly,
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
                          enabled: !_formReadOnly,
                          decoration: const InputDecoration(
                            labelText: 'Contact No 1 (max 12)',
                          ),
                          maxLength: AppConstants.contactNoMaxLength,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppConstants.contactNoMaxLength,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _contactNo2,
                          enabled: !_formReadOnly,
                          decoration: const InputDecoration(
                            labelText: 'Contact No 2 (max 12)',
                          ),
                          maxLength: AppConstants.contactNoMaxLength,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AppConstants.contactNoMaxLength,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    enabled: !_formReadOnly,
                    decoration:
                        const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _comment,
                    enabled: !_formReadOnly,
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

    final member = _loadedMember;
    final user = ref.watch(authUserProvider);
    if (member != null && member.isLocked && user != null) {
      return ScreenshotProtectedView(
        member: member,
        user: user,
        onScreenshotAttempt: () => _logScreenshotAttempt(member),
        child: Padding(
          // Extra top/bottom inset so content clears red banners.
          padding: const EdgeInsets.only(top: 48, bottom: 36),
          child: body,
        ),
      );
    }
    return body;
  }

  Widget _buildLockChrome(Member member) {
    final user = ref.watch(authUserProvider);
    final verified = ref.watch(verifiedTempAccessIdsProvider).contains(member.id);
    final users = ref.watch(appUsersProvider).valueOrNull ?? const [];
    final logs = (ref.watch(temporaryAccessLogsProvider).valueOrNull ?? const [])
        .where((l) => l.memberId == member.id)
        .toList();
    String? nameOf(String? id) {
      if (id == null) return null;
      for (final u in users) {
        if (u.id == id) return u.displayName;
      }
      return id;
    }

    if (!member.isLocked) return const SizedBox.shrink();

    if (user?.isAdmin == true) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AdminLockedBanner(
          member: member,
          lockedByName: nameOf(member.lockedBy),
          recentLogs: logs,
          onUnlock: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Unlock Member'),
                content: Text('Unlock ${member.fullName}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Unlock'),
                  ),
                ],
              ),
            );
            if (ok != true || user == null) return;
            final unlocked = await ref
                .read(memberLockServiceProvider)
                .unlock(member: member, actor: user);
            setState(() => _loadedMember = unlocked);
            ref.invalidate(membersProvider);
            ref.invalidate(lockedMembersProvider);
            ref.invalidate(temporaryAccessLogsProvider);
          },
          onGrantAccess: () async {
            await showGrantTemporaryAccessDialog(
              context: context,
              ref: ref,
              member: member,
            );
            final refreshed =
                await ref.read(memberRepositoryProvider).getById(member.id);
            if (refreshed != null && mounted) {
              setState(() => _loadedMember = refreshed);
            }
            ref.invalidate(lockedMembersProvider);
            ref.invalidate(temporaryAccessLogsProvider);
          },
          onRevokeAccess: () async {
            if (user == null) return;
            final cleared = await ref
                .read(temporaryAccessServiceProvider)
                .revoke(member: member, actor: user);
            final next = {...ref.read(verifiedTempAccessIdsProvider)}
              ..remove(member.id);
            ref.read(verifiedTempAccessIdsProvider.notifier).state = next;
            setState(() => _loadedMember = cleared);
            ref.invalidate(lockedMembersProvider);
            ref.invalidate(temporaryAccessLogsProvider);
          },
        ),
      );
    }

    if (verified &&
        TemporaryAccessService.isGrantValidFor(member, user!.id)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TemporaryAccessActiveBanner(
          member: member,
          grantedByName: nameOf(member.temporaryAccessGrantedBy),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LockedMemberBanner(
        member: member,
        lockedByName: nameOf(member.lockedBy),
        onEnterCode: user == null
            ? null
            : () async {
                final ok = await showEnterTemporaryAccessCodeDialog(
                  context: context,
                  ref: ref,
                  member: member,
                  secretary: user,
                );
                if (ok) {
                  final next = {...ref.read(verifiedTempAccessIdsProvider)}
                    ..add(member.id);
                  ref.read(verifiedTempAccessIdsProvider.notifier).state =
                      next;
                  setState(() {});
                }
              },
        onRequestAccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contact the System Administrator for a temporary access code.',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(MemberFormMode mode, Member? member) {
    Color color;
    switch (mode) {
      case MemberFormMode.newMember:
        color = Colors.orange;
      case MemberFormMode.regularMember:
        color = Colors.blue;
      case MemberFormMode.lockedSecretary:
      case MemberFormMode.lockedAdmin:
        color = Colors.red;
      case MemberFormMode.tempAccessActive:
        color = Colors.green;
    }
    final label = member == null
        ? 'New'
        : '${mode.statusLabel} · ${member.registrationStatus}';
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  String _browseLabel() {
    if (_browseIndex < 0) return 'New member';
    if (!_canBrowseMembers) return 'Your member profile';
    final m = _loadedMember;
    final status = m == null
        ? ''
        : m.isLocked
            ? ' 🔒'
            : (m.registrationStatus == 'pending' ||
                    m.registrationStatus == 'in_progress'
                ? ' · onboarding'
                : '');
    return 'Browse ${_browseIndex + 1} / ${_members.length}$status'
        '${m == null ? '' : ' — ${m.fullName}'}';
  }

  Future<void> _toggleOnboardingStep(int step, bool complete) async {
    final member = _loadedMember;
    final user = ref.read(authUserProvider);
    if (member == null || user == null) return;
    try {
      final updated = await ref.read(memberLockServiceProvider).setOnboardingStep(
            member: member,
            actor: user,
            step: step,
            complete: complete,
          );
      if (!mounted) return;
      setState(() => _loadedMember = updated);
      final idx = _members.indexWhere((m) => m.id == updated.id);
      if (idx >= 0) {
        final next = [..._members];
        next[idx] = updated;
        setState(() => _members = next);
      }
      ref.invalidate(membersProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _completeAndLock() async {
    final member = _loadedMember;
    final user = ref.read(authUserProvider);
    if (member == null || user == null) return;
    if (!member.allStepsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Check all 4 onboarding steps before completing.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Member Onboarding?'),
        content: Text(
          'Are you sure ${member.fullName} has completed all requirements?\n\n'
          'This will LOCK the member. Recording Secretaries will not be able to '
          'edit this member without temporary access from the Administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final locked = await ref.read(memberLockServiceProvider).completeAndLock(
            member: member,
            actor: user,
          );
      if (!mounted) return;
      setState(() => _loadedMember = locked);
      ref.invalidate(membersProvider);
      ref.invalidate(lockedMembersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${locked.fullName} completed and locked successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}
