import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/exceptions/duplicate_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lookup_item.dart';
import '../../models/member.dart';
import '../../models/member_form_mode.dart';
import '../../models/member_navigation_state.dart';
import '../../providers/member_navigation_provider.dart';
import '../../providers/providers.dart';
import '../../services/sa_id_validator.dart';
import '../../services/secure_screen_service.dart';
import '../../services/temporary_access_service.dart';
import '../../widgets/duplicate_warning_widget.dart';
import '../../widgets/file_image_stub.dart'
    if (dart.library.io) '../../widgets/file_image_io.dart' as file_img;
import '../../widgets/member_lock_banners.dart';
import '../../widgets/member_nav/keyboard_shortcut_handler.dart';
import '../../widgets/member_nav/member_filter_panel.dart';
import '../../widgets/member_nav/member_list_panel.dart';
import '../../widgets/member_nav/profile_navigation_bar.dart';
import '../../widgets/member_nav/unsaved_changes_dialog.dart';
import '../../widgets/onboarding_checklist_card.dart';
import '../../widgets/screenshot_protected_view.dart';
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
  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;
  String? _adminLinkedMemberId;
  Member? _loadedMember;
  String? _lastLoggedSecureViewId;
  final _searchFocusNode = FocusNode();
  bool _navForward = true;

  /// Explicit Edit Mode — fields stay read-only until user clicks Edit.
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _suppressDirty = false;
  _FormSnapshot? _snapshot;

  String? _saIdError;
  String? _saIdWarning;
  String? _globalRecordError;
  bool _isCheckingSaId = false;
  bool _isCheckingGlobalRecord = false;
  String? _duplicateSaIdMemberId;
  String? _duplicateGlobalRecordMemberId;
  Timer? _saIdDebounce;
  Timer? _globalRecordDebounce;

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

  /// Whether this user may enter Edit Mode for the current profile.
  bool get _canEnterEditMode {
    if (_fieldsMasked) return false;
    if (_isMemberOnly) {
      return _viewerMemberId != null &&
          _currentId != null &&
          _currentId == _viewerMemberId;
    }
    if (_loadedMember == null) return _canAddMembers;
    return _formMode.canEditFields;
  }

  /// Fields enabled only while Edit Mode is active and permitted.
  bool get _formReadOnly {
    if (_fieldsMasked) return true;
    if (!_isEditing) return true;
    return !_canEnterEditMode;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [
      _memberName,
      _surname,
      _address,
      _contactNo1,
      _contactNo2,
      _email,
      _comment,
    ]) {
      c.addListener(_onFormFieldChanged);
    }
    _saId.addListener(_onSaIdChanged);
    _globalRecordNo.addListener(_onGlobalRecordChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _saIdDebounce?.cancel();
    _globalRecordDebounce?.cancel();
    _saId.dispose();
    _globalRecordNo.dispose();
    _memberName.dispose();
    _surname.dispose();
    _address.dispose();
    _contactNo1.dispose();
    _contactNo2.dispose();
    _email.dispose();
    _comment.dispose();
    _searchFocusNode.dispose();
    SecureScreenService.disableSecureScreen();
    super.dispose();
  }

  void _onFormFieldChanged() {
    if (_suppressDirty || !_isEditing) return;
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _markDirty() {
    if (_suppressDirty || !_isEditing) return;
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  _FormSnapshot _takeSnapshot() {
    return _FormSnapshot(
      saId: _saId.text,
      globalRecordNo: _globalRecordNo.text,
      memberName: _memberName.text,
      surname: _surname.text,
      address: _address.text,
      suburb: _suburb,
      townCity: _townCity,
      postalCode: _postalCode,
      contactNo1: _contactNo1.text,
      contactNo2: _contactNo2.text,
      email: _email.text,
      comment: _comment.text,
      photoLocalPath: _photoLocalPath,
      photoUrl: _photoUrl,
    );
  }

  void _applySnapshot(_FormSnapshot snap) {
    _suppressDirty = true;
    _saId.text = snap.saId;
    _globalRecordNo.text = snap.globalRecordNo;
    _memberName.text = snap.memberName;
    _surname.text = snap.surname;
    _address.text = snap.address;
    _suburb = snap.suburb;
    _townCity = snap.townCity;
    _postalCode = snap.postalCode;
    _contactNo1.text = snap.contactNo1;
    _contactNo2.text = snap.contactNo2;
    _email.text = snap.email;
    _comment.text = snap.comment;
    _photoLocalPath = snap.photoLocalPath;
    _photoUrl = snap.photoUrl;
    _suppressDirty = false;
  }

  void _exitEditMode({required bool restoreSnapshot}) {
    if (restoreSnapshot && _snapshot != null) {
      _applySnapshot(_snapshot!);
      if (_loadedMember != null && !_fieldsMasked) {
        _loadPhotoBytes(
          _loadedMember!.id,
          _photoLocalPath,
          _photoUrl,
        );
      }
    }
    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
      _snapshot = _takeSnapshot();
    });
  }

  void _enterEditMode() {
    if (!_canEnterEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 You do not have permission to edit this member.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _snapshot = _takeSnapshot();
      _isEditing = true;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _cancelEdit() async {
    if (!_isEditing) return;
    if (_hasUnsavedChanges) {
      final ok = await showDiscardEditsDialog(context);
      if (ok != true || !mounted) return;
    }
    _exitEditMode(restoreSnapshot: true);
  }

  /// Returns true if navigation away is allowed.
  Future<bool> _ensureCanNavigate() async {
    if (!_isEditing) return true;
    if (!_hasUnsavedChanges) {
      _exitEditMode(restoreSnapshot: false);
      return true;
    }
    final action = await showUnsavedChangesDialog(context);
    if (!mounted) return false;
    switch (action) {
      case UnsavedChangesAction.save:
        final ok = await _save();
        return ok;
      case UnsavedChangesAction.discard:
        _exitEditMode(restoreSnapshot: true);
        return true;
      case UnsavedChangesAction.stay:
      case null:
        return false;
    }
  }

  InputDecoration _fieldDecoration(
    String label, {
    bool isDense = false,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      isDense: isDense,
      errorText: errorText,
      helperText: helperText,
      helperMaxLines: 2,
      errorMaxLines: 3,
      suffixIcon: suffixIcon ??
          Icon(
            _isEditing && !_formReadOnly ? Icons.edit : Icons.lock,
            size: 16,
            color: _isEditing && !_formReadOnly ? Colors.blue : Colors.grey,
          ),
      enabledBorder: _isEditing && !_formReadOnly
          ? OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue.shade300),
            )
          : null,
      focusedBorder: _isEditing && !_formReadOnly
          ? OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            )
          : null,
    );
  }

  void _clearDuplicateState() {
    _saIdDebounce?.cancel();
    _globalRecordDebounce?.cancel();
    _saIdError = null;
    _saIdWarning = null;
    _globalRecordError = null;
    _isCheckingSaId = false;
    _isCheckingGlobalRecord = false;
    _duplicateSaIdMemberId = null;
    _duplicateGlobalRecordMemberId = null;
  }

  void _onSaIdChanged() {
    _onFormFieldChanged();
    if (!_isEditing || _formReadOnly || _fieldsMasked) return;
    _saIdDebounce?.cancel();
    _saIdDebounce = Timer(const Duration(milliseconds: 400), () {
      _validateSaIdLive(_saId.text);
    });
  }

  void _onGlobalRecordChanged() {
    _onFormFieldChanged();
    if (!_isEditing || _formReadOnly || _fieldsMasked) return;
    _globalRecordDebounce?.cancel();
    _globalRecordDebounce = Timer(const Duration(milliseconds: 400), () {
      _validateGlobalRecordLive(_globalRecordNo.text);
    });
  }

  Future<void> _validateSaIdLive(String value) async {
    if (!mounted) return;
    setState(() {
      _isCheckingSaId = true;
      _saIdError = null;
      _saIdWarning = null;
      _duplicateSaIdMemberId = null;
    });

    final hardError = SaIdValidator.validate(value);
    if (hardError != null) {
      if (!mounted) return;
      setState(() {
        _saIdError = hardError;
        _isCheckingSaId = false;
      });
      return;
    }

    final soft = SaIdValidator.softWarning(value);
    final excludeId = _currentId ?? _draftId;
    final result = await ref.read(memberDuplicateServiceProvider).checkSaId(
          value.trim(),
          excludeMemberId: excludeId,
        );
    if (!mounted) return;
    setState(() {
      _isCheckingSaId = false;
      _saIdWarning = soft;
      if (result.isDuplicate) {
        _saIdError = result.errorMessage;
        _duplicateSaIdMemberId = result.existingMember?.id;
      }
    });
  }

  Future<void> _validateGlobalRecordLive(String value) async {
    if (!mounted) return;
    setState(() {
      _isCheckingGlobalRecord = true;
      _globalRecordError = null;
      _duplicateGlobalRecordMemberId = null;
    });

    final formatError = GlobalRecordValidator.validate(value);
    if (formatError != null) {
      if (!mounted) return;
      setState(() {
        _globalRecordError = formatError;
        _isCheckingGlobalRecord = false;
      });
      return;
    }

    final excludeId = _currentId ?? _draftId;
    final result =
        await ref.read(memberDuplicateServiceProvider).checkGlobalRecord(
              value.trim(),
              excludeMemberId: excludeId,
            );
    if (!mounted) return;
    setState(() {
      _isCheckingGlobalRecord = false;
      if (result.isDuplicate) {
        _globalRecordError = result.errorMessage;
        _duplicateGlobalRecordMemberId = result.existingMember?.id;
      }
    });
  }

  /// Hard blockers only (empty / length / digits / confirmed duplicate / in-flight check).
  bool get _uniqueFieldsOk =>
      _saIdError == null &&
      _globalRecordError == null &&
      !_isCheckingSaId &&
      !_isCheckingGlobalRecord &&
      _saId.text.trim().isNotEmpty &&
      _globalRecordNo.text.trim().isNotEmpty;

  bool get _canPressSave =>
      _isEditing &&
      !_saving &&
      !_formReadOnly &&
      !_fieldsMasked &&
      _uniqueFieldsOk;

  Future<void> _openExistingDuplicate(String? memberId) async {
    if (memberId == null) return;
    if (!await _ensureCanNavigate()) return;
    final idx = _members.indexWhere((m) => m.id == memberId);
    if (idx < 0) {
      await _bootstrap();
    }
    final refreshed = _members.indexWhere((m) => m.id == memberId);
    if (refreshed < 0) return;
    await ref.read(memberNavigationProvider.notifier).openMember(
          _members[refreshed],
          all: _members,
        );
    _loadMember(_members[refreshed], refreshed);
  }

  Widget _buildEditModeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '✏️ EDIT MODE ACTIVE - Changes will be saved when you click Save',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'Unsaved Changes: ${_hasUnsavedChanges ? 'Yes' : 'No'}',
            style: TextStyle(
              color: _hasUnsavedChanges
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
          await ref.read(memberNavigationProvider.notifier).openMember(
                members[index],
                all: members,
              );
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
        await ref.read(memberNavigationProvider.notifier).openMember(
              members[index],
              all: members,
            );
        return;
      }
    }

    final nav = ref.read(memberNavigationProvider);
    if (nav.currentView == MemberNavView.profile &&
        nav.selectedMemberId != null) {
      final index = members.indexWhere((m) => m.id == nav.selectedMemberId);
      if (index >= 0) {
        _loadMember(members[index], index);
        return;
      }
    }

    // Staff: show blank New Member form (editable) — no need to press New first.
    if (_canAddMembers) {
      openMemberDraft();
      return;
    }
    ref.read(memberNavigationProvider.notifier).goBackToList();
    _clearForm(newMember: false);
  }

  void _loadMember(Member member, int index, {bool enterEdit = false}) {
    final masked = _isProtectedAdminMember(member.id) && !_viewerIsSysAdmin;
    _suppressDirty = true;
    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
      _clearDuplicateState();
      _loadedMember = member;
      _currentId = member.id;
      _draftId = null;
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
      _snapshot = _takeSnapshot();
    });
    _suppressDirty = false;
    ref.read(selectedMemberIdProvider.notifier).state = member.id;
    ref.read(memberNavigationProvider.notifier).syncSelection(member, _members);
    if (!masked) {
      _loadPhotoBytes(member.id, member.photoLocalPath, member.photoUrl);
    }
    _onSecureMemberView(member);
    if (enterEdit && _canEnterEditMode) {
      _enterEditMode();
    }
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
    _suppressDirty = true;
    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
      _clearDuplicateState();
      _loadedMember = null;
      _currentId = null;
      _draftId = const Uuid().v4();
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
      _snapshot = _takeSnapshot();
    });
    _suppressDirty = false;
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
      _markDirty();
      ref.read(selectedMemberIdProvider.notifier).state = memberId;

      final members = await ref.read(memberRepositoryProvider).getAll();
      if (!mounted) return;
      setState(() {
        _members = members;
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
                          color: AppTheme.bodyText,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Member Photo',
                          style: TextStyle(
                            color: AppTheme.bodyText,
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

  Future<bool> _save() async {
    if (_isMemberOnly && _currentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members cannot create new member profiles.'),
          ),
        );
      }
      return false;
    }
    if (!_isEditing || _formReadOnly || _fieldsMasked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Click Edit to make changes before saving.',
            ),
          ),
        );
      }
      return false;
    }
    if (_isMemberOnly &&
        _viewerMemberId != null &&
        _currentId != null &&
        _currentId != _viewerMemberId) {
      return false;
    }
    if (!_formKey.currentState!.validate()) return false;
    // Finish any in-flight uniqueness checks before save.
    if (_isCheckingSaId || _isCheckingGlobalRecord) {
      await _validateSaIdLive(_saId.text);
      await _validateGlobalRecordLive(_globalRecordNo.text);
    }
    if (_saIdError != null || _globalRecordError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _saIdError ??
                  _globalRecordError ??
                  'Fix SA ID / Global Record before saving.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
    if (_saId.text.trim().isEmpty || _globalRecordNo.text.trim().isEmpty) {
      return false;
    }

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

      // Automated onboarding reminders (step 1–4, 24h expiry).
      try {
        final reminders = ref.read(reminderServiceProvider);
        if (existing == null) {
          await reminders.onMemberCreated(saved, actor: user?.id);
        } else {
          await reminders.syncFromMember(saved, actor: user?.id);
        }
        ref.invalidate(activeOnboardingRemindersProvider);
        ref.invalidate(reminderStatsProvider);
        ref.invalidate(activeReminderCountProvider);
      } catch (e) {
        debugPrint('Reminder sync after save failed: $e');
      }

      // Keep selection so bootstrap reloads this member (not a blank draft).
      ref.read(selectedMemberIdProvider.notifier).state = saved.id;

      await _bootstrap();
      final index = _members.indexWhere((m) => m.id == saved.id);
      if (index >= 0) {
        await ref.read(memberNavigationProvider.notifier).openMember(
              _members[index],
              all: _members,
            );
        _loadMember(_members[index], index);
      }
      setState(() {
        _isEditing = false;
        _hasUnsavedChanges = false;
        _snapshot = _takeSnapshot();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Member saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } on DuplicateException catch (e) {
      if (mounted) {
        await DuplicateErrorHandler.showDuplicateError(
          context,
          field: e.field ?? 'field',
          value: e.value ?? '',
          onViewExisting: e.existingMemberId == null
              ? null
              : () => _openExistingDuplicate(e.existingMemberId),
        );
      }
      return false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
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
    ref.read(memberNavigationProvider.notifier).goBackToList();
    await _bootstrap();
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
                decoration: _fieldDecoration(label),
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

    final navState = ref.watch(memberNavigationProvider);
    final nav = ref.read(memberNavigationProvider.notifier);
    final isMemberOnly = _isMemberOnly;
    final showList = !isMemberOnly && navState.currentView == MemberNavView.list;
    final filtered = nav.filtered(_members);
    final page = nav.pageMembers(_members);
    final counts = MemberNavigationLogic.counts(
      _members,
      favoriteIds: navState.favoriteIds,
    );
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    Future<void> openMember(Member m, {bool forceEdit = false}) async {
      if (!await _ensureCanNavigate()) return;
      setState(() => _navForward = true);
      await nav.openMember(m, all: _members, forceEdit: forceEdit);
      final idx = _members.indexWhere((x) => x.id == m.id);
      if (idx >= 0) {
        _loadMember(_members[idx], idx, enterEdit: forceEdit);
      }
    }

    Future<void> goPrev() async {
      if (showList) {
        nav.moveListHighlight(-1, pageLength: page.length);
        return;
      }
      if (!await _ensureCanNavigate()) return;
      setState(() => _navForward = false);
      await nav.navigateRelative(-1, all: _members);
      final id = ref.read(memberNavigationProvider).selectedMemberId;
      final idx = _members.indexWhere((m) => m.id == id);
      if (idx >= 0) _loadMember(_members[idx], idx);
    }

    Future<void> goNext() async {
      if (showList) {
        nav.moveListHighlight(1, pageLength: page.length);
        return;
      }
      if (!await _ensureCanNavigate()) return;
      setState(() => _navForward = true);
      await nav.navigateRelative(1, all: _members);
      final id = ref.read(memberNavigationProvider).selectedMemberId;
      final idx = _members.indexWhere((m) => m.id == id);
      if (idx >= 0) _loadMember(_members[idx], idx);
    }

    void openHighlighted() {
      if (!showList || page.isEmpty) return;
      final i = navState.highlightIndex.clamp(0, page.length - 1);
      openMember(page[i]);
    }

    Future<void> goBackToList() async {
      if (!showList) {
        if (!await _ensureCanNavigate()) return;
        nav.goBackToList();
        _clearForm(newMember: false);
      }
    }

    Future<void> guardedUpload() async {
      final m = _loadedMember;
      if (m == null) return;
      if (_isEditing && _hasUnsavedChanges) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Please save before uploading files.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('💾 Save First'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final ok = await _save();
          if (!ok || !mounted) return;
        } else {
          return;
        }
      }
      if (!mounted) return;
      await showMemberFilesDialog(context, ref, m);
    }

    Future<void> guardedDelete() async {
      if (_isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please save or cancel before deleting'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await _delete();
    }

    final shell = KeyboardShortcutHandler(
      enabled: !isMemberOnly,
      onPrevious: () => goPrev(),
      onNext: () => goNext(),
      onPagePrevious: showList
          ? () => nav.previousPage()
          : () => goPrev(),
      onPageNext: showList
          ? () => nav.nextPage(filtered.length)
          : () => goNext(),
      onBack: () => goBackToList(),
      onSearch: () => _searchFocusNode.requestFocus(),
      onEdit: () {
        if (_isEditing) return;
        _enterEditMode();
      },
      onSave: _isEditing ? () => _save() : null,
      onNew: _canAddMembers
          ? () async {
              if (!await _ensureCanNavigate()) return;
              openMemberDraft();
            }
          : null,
      onDelete: (_loadedMember != null) ? () => guardedDelete() : null,
      onUpload: () => guardedUpload(),
      onRefresh: () async {
        if (!await _ensureCanNavigate()) return;
        await refreshApp(ref);
        await _bootstrap();
      },
      onHome: () async {
        if (!await _ensureCanNavigate()) return;
        await nav.navigateFirst(all: _members);
        final id = ref.read(memberNavigationProvider).selectedMemberId;
        final idx = _members.indexWhere((m) => m.id == id);
        if (idx >= 0) _loadMember(_members[idx], idx);
      },
      onEnd: () async {
        if (!await _ensureCanNavigate()) return;
        await nav.navigateLast(all: _members);
        final id = ref.read(memberNavigationProvider).selectedMemberId;
        final idx = _members.indexWhere((m) => m.id == id);
        if (idx >= 0) _loadMember(_members[idx], idx);
      },
      onOpenHighlighted: openHighlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Material(
              color: AppTheme.forestGreen,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '👥 MEMBER MANAGEMENT',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.labelText,
                        ),
                      ),
                    ),
                    if (!isMemberOnly)
                      IconButton(
                        tooltip: 'Focus Search (Ctrl+F)',
                        color: AppTheme.labelText,
                        onPressed: () async {
                          if (showList) {
                            _searchFocusNode.requestFocus();
                          } else {
                            await goBackToList();
                            if (!mounted) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _searchFocusNode.requestFocus();
                            });
                          }
                        },
                        icon: const Icon(Icons.search),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMemberOnly && wide)
                    SizedBox(
                      width: 200,
                      child: MemberFilterPanel(counts: counts),
                    ),
                  if (!isMemberOnly && wide) const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Card(
                      margin: EdgeInsets.zero,
                      // Do not clip — profile nav buttons must stay visible.
                      clipBehavior: Clip.none,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: showList
                            ? KeyedSubtree(
                                key: const ValueKey('list'),
                                child: Column(
                                  children: [
                                    if (!wide)
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: MemberFilterPanel(
                                          counts: counts,
                                          compact: true,
                                        ),
                                      ),
                                    Expanded(
                                      child: MemberListPanel(
                                        allMembers: _members,
                                        searchFocusNode: _searchFocusNode,
                                        isAdmin: _viewerIsAdmin,
                                        onAddNew: _canAddMembers
                                            ? openMemberDraft
                                            : null,
                                        onOpen: (m, {forceEdit = false}) =>
                                            openMember(
                                          m,
                                          forceEdit: forceEdit,
                                        ),
                                        onEdit: (m) =>
                                            openMember(m, forceEdit: true),
                                        onUpload: (m) => showMemberFilesDialog(
                                          context,
                                          ref,
                                          m,
                                        ),
                                        onComplete: (m) async {
                                          await openMember(m);
                                          await _completeAndLock();
                                        },
                                        onGrantTempAccess: (m) async {
                                          await openMember(m);
                                          await showGrantTemporaryAccessDialog(
                                            context: context,
                                            ref: ref,
                                            member: m,
                                          );
                                        },
                                        onDelete: (m) async {
                                          await openMember(m);
                                          await _delete();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : KeyedSubtree(
                                key: ValueKey(
                                  'profile-${_loadedMember?.id ?? 'new'}',
                                ),
                                child: _buildProfilePane(
                                  filtered: filtered,
                                  navState: navState,
                                  onBack: goBackToList,
                                  onPrev: goPrev,
                                  onNext: goNext,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (!isMemberOnly && wide) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 240,
                      child: RecentlyViewedPanel(
                        allMembers: _members,
                        onOpen: (m) => openMember(m),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return shell;
  }

  void openMemberDraft() {
    _clearForm(newMember: true);
    ref.read(memberNavigationProvider.notifier).beginNewMember();
    setState(() {
      _isEditing = true;
      _hasUnsavedChanges = false;
      _snapshot = _takeSnapshot();
    });
  }

  Widget _buildProfilePane({
    required List<Member> filtered,
    required MemberNavigationState navState,
    required Future<void> Function() onBack,
    required Future<void> Function() onPrev,
    required Future<void> Function() onNext,
  }) {
    final member = _loadedMember;
    final idx = navState.currentIndex;
    String? prevName;
    String? nextName;
    if (idx > 0 && idx < filtered.length) {
      prevName = filtered[idx - 1].fullName;
    }
    if (idx >= 0 && idx < filtered.length - 1) {
      nextName = filtered[idx + 1].fullName;
    }

    final modeLabel = _isEditing ? 'EDIT MODE' : 'VIEW MODE';

    Widget buildNavHeader() {
      if (member != null) {
        return ProfileNavigationBar(
          currentMember: member,
          currentIndex: idx,
          totalMembers: filtered.length,
          previousName: prevName,
          nextName: nextName,
          onBack: () => onBack(),
          onPrevious: () => onPrev(),
          onNext: () => onNext(),
          canEdit: _canEnterEditMode && !_isEditing,
          canDelete: !_isEditing &&
              !(_loadedMember?.isLocked == true && !_viewerIsAdmin) &&
              !_isMemberOnly,
          onEdit: (_canEnterEditMode && !_isEditing) ? _enterEditMode : null,
          onNew: _canAddMembers
              ? () async {
                  if (!await _ensureCanNavigate()) return;
                  openMemberDraft();
                }
              : null,
          canNew: _canAddMembers,
          onUpload: () async {
            if (_isEditing && _hasUnsavedChanges) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('⚠️ Unsaved Changes'),
                  content: const Text(
                    'You have unsaved changes. Please save before uploading files.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('💾 Save First'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final ok = await _save();
                if (!ok || !mounted) return;
              } else {
                return;
              }
            }
            if (!mounted) return;
            await showMemberFilesDialog(context, ref, member);
          },
          onDelete: (!_isEditing &&
                  !(_loadedMember?.isLocked == true && !_viewerIsAdmin) &&
                  !_isMemberOnly)
              ? _delete
              : null,
        );
      }
      return Material(
        color: AppTheme.forestGreen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onBack(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back to List (Esc)',
              ),
              Expanded(
                child: Text(
                  'New Member ($modeLabel)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.labelText,
                  ),
                ),
              ),
              if (_canAddMembers)
                TextButton.icon(
                  onPressed: () async {
                    if (!await _ensureCanNavigate()) return;
                    openMemberDraft();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('New'),
                ),
              if (_isEditing) ...[
                TextButton(
                  onPressed: _cancelEdit,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _canPressSave ? () => _save() : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
              IconButton(
                tooltip: 'Close',
                onPressed: () => onBack(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final formChrome = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEditing) _buildEditModeBanner(),
          const SizedBox(height: 8),
          Row(
            children: [
              _statusChip(_formMode, _loadedMember),
              const SizedBox(width: 8),
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: _isEditing
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                label: Text(
                  modeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: _isEditing ? Colors.orange.shade800 : Colors.black54,
                  ),
                ),
              ),
              const Spacer(),
              if (_currentId != null && !_fieldsMasked)
                OutlinedButton.icon(
                  onPressed: () async {
                    final m = _loadedMember;
                    if (m == null) return;
                    if (_isEditing && _hasUnsavedChanges) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Save or cancel edits before opening files.',
                          ),
                        ),
                      );
                      return;
                    }
                    await showMemberFilesDialog(context, ref, m);
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Upload Files'),
                ),
              const SizedBox(width: 8),
              if (!_isEditing && _canEnterEditMode)
                FilledButton.icon(
                  onPressed: _enterEditMode,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (_isEditing) ...[
                TextButton(
                  onPressed: _saving ? null : _cancelEdit,
                  child: const Text('❌ Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _canPressSave ? () => _save() : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
                readOnly: _formMode.checklistReadOnly || !_isEditing,
                showCompleteButton:
                    _formMode.showCompleteButton && !_isEditing,
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
                  Container(
                    width: double.infinity,
                    color: AppTheme.forestGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      _isEditing
                          ? '📋 MEMBER INFORMATION (Editable)'
                          : '📋 MEMBER INFORMATION (Read-Only)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.labelText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  TextFormField(
                                    controller: _saId,
                                    enabled: !_formReadOnly,
                                    decoration: _fieldDecoration(
                                      'SA ID No.',
                                      isDense: true,
                                      errorText: _saIdError,
                                      helperText: _saIdError == null
                                          ? _saIdWarning
                                          : null,
                                      suffixIcon: _isCheckingSaId
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : _saIdError == null &&
                                                  _saId.text.isNotEmpty &&
                                                  _isEditing
                                              ? Icon(
                                                  _saIdWarning == null
                                                      ? Icons.check_circle
                                                      : Icons.warning_amber,
                                                  color: _saIdWarning == null
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  size: 18,
                                                )
                                              : null,
                                    ),
                                    maxLength: AppConstants.saIdMaxLength,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) =>
                                        SaIdValidator.validate(v ?? ''),
                                  ),
                                  DuplicateWarningWidget(
                                    field: 'SA ID',
                                    value: _saId.text.trim(),
                                    isDuplicate: _duplicateSaIdMemberId != null,
                                    onViewExisting: () =>
                                        _openExistingDuplicate(
                                      _duplicateSaIdMemberId,
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _globalRecordNo,
                                    enabled: !_formReadOnly,
                                    decoration: _fieldDecoration(
                                      'Global Record No.',
                                      isDense: true,
                                      errorText: _globalRecordError,
                                      suffixIcon: _isCheckingGlobalRecord
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : _globalRecordError == null &&
                                                  _globalRecordNo
                                                      .text.isNotEmpty &&
                                                  _isEditing
                                              ? const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 18,
                                                )
                                              : null,
                                    ),
                                    maxLength: AppConstants
                                        .globalRecordNoMaxLength,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) {
                                      final err =
                                          GlobalRecordValidator.validate(
                                        v ?? '',
                                      );
                                      if (err != null) return err;
                                      if (_globalRecordError != null &&
                                          _duplicateGlobalRecordMemberId !=
                                              null) {
                                        return _globalRecordError;
                                      }
                                      return null;
                                    },
                                  ),
                                  DuplicateWarningWidget(
                                    field: 'Global Record No.',
                                    value: _globalRecordNo.text.trim(),
                                    isDuplicate:
                                        _duplicateGlobalRecordMemberId != null,
                                    onViewExisting: () =>
                                        _openExistingDuplicate(
                                      _duplicateGlobalRecordMemberId,
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _memberName,
                                    enabled: !_formReadOnly,
                                    decoration: _fieldDecoration(
                                      'Member Name',
                                      isDense: true,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _surname,
                                    enabled: !_formReadOnly,
                                    decoration: _fieldDecoration(
                                      'Surname',
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
                    decoration: _fieldDecoration('Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  _lookupDropdown(
                    label: 'Suburb',
                    type: LookupType.suburb,
                    value: _suburb,
                    onChanged: (v) {
                      setState(() => _suburb = v);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 8),
                  _lookupDropdown(
                    label: 'Town / City',
                    type: LookupType.townCity,
                    value: _townCity,
                    onChanged: (v) {
                      setState(() => _townCity = v);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 8),
                  _lookupDropdown(
                    label: 'Postal Code',
                    type: LookupType.postalCode,
                    value: _postalCode,
                    onChanged: (v) {
                      setState(() => _postalCode = v);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactNo1,
                          enabled: !_formReadOnly,
                          decoration: _fieldDecoration('Contact No 1 (max 12)'),
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
                          decoration: _fieldDecoration('Contact No 2 (max 12)'),
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
                    decoration: _fieldDecoration('Email Address'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _comment,
                    enabled: !_formReadOnly,
                    decoration: _fieldDecoration('Comment'),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final lockedMember = _loadedMember;
    final authUser = ref.watch(authUserProvider);
    Widget formArea = formChrome;
    if (lockedMember != null &&
        lockedMember.isLocked &&
        authUser != null) {
      formArea = SizedBox.expand(
        child: ScreenshotProtectedView(
          member: lockedMember,
          user: authUser,
          onScreenshotAttempt: () => _logScreenshotAttempt(lockedMember),
          child: Padding(
            padding: const EdgeInsets.only(top: 48, bottom: 36),
            child: formChrome,
          ),
        ),
      );
    }

    // Nav bar stays ABOVE lock watermark/banner so Previous/Next always visible.
    final pane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildNavHeader(),
        Expanded(child: formArea),
      ],
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(
        key: ValueKey(lockedMember?.id ?? 'new-$_navForward'),
        child: pane,
      ),
    );
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
      try {
        await ref.read(reminderServiceProvider).syncFromMember(
              updated,
              actor: user.id,
            );
        ref.invalidate(activeOnboardingRemindersProvider);
        ref.invalidate(reminderStatsProvider);
        ref.invalidate(activeReminderCountProvider);
      } catch (e) {
        debugPrint('Reminder sync after step toggle failed: $e');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _completeAndLock() async {
    if (_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please save or cancel before completing.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
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
      try {
        await ref.read(reminderServiceProvider).onLROCompleted(
              locked,
              actor: user.id,
            );
        ref.invalidate(activeOnboardingRemindersProvider);
        ref.invalidate(reminderStatsProvider);
        ref.invalidate(activeReminderCountProvider);
      } catch (e) {
        debugPrint('Reminder sync after complete/lock failed: $e');
      }
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

class _FormSnapshot {
  const _FormSnapshot({
    required this.saId,
    required this.globalRecordNo,
    required this.memberName,
    required this.surname,
    required this.address,
    required this.suburb,
    required this.townCity,
    required this.postalCode,
    required this.contactNo1,
    required this.contactNo2,
    required this.email,
    required this.comment,
    required this.photoLocalPath,
    required this.photoUrl,
  });

  final String saId;
  final String globalRecordNo;
  final String memberName;
  final String surname;
  final String address;
  final String? suburb;
  final String? townCity;
  final String? postalCode;
  final String contactNo1;
  final String contactNo2;
  final String email;
  final String comment;
  final String? photoLocalPath;
  final String? photoUrl;
}
