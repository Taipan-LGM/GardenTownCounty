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
import '../../l10n/app_strings.dart';
import '../../models/lookup_item.dart';
import '../../models/member.dart';
import '../../models/member_form_mode.dart';
import '../../models/member_navigation_state.dart';
import '../../providers/member_navigation_provider.dart';
import '../../providers/providers.dart';
import '../../services/member_form_save_gate.dart';
import '../../services/record_field_policy.dart';
import '../../services/sa_id_validator.dart';
import '../../services/step1_validator.dart';
import '../../services/secure_screen_service.dart';
import '../../widgets/standard_buttons.dart';
import '../../widgets/cancel_membership_dialog.dart';
import '../../widgets/duplicate_warning_widget.dart';
import '../../widgets/member_form/member_contact_details_section.dart';
import '../../widgets/member_form/member_edit_mode_banner.dart';
import '../../widgets/member_form/member_identity_form_section.dart';
import '../../widgets/member_form/member_lock_chrome.dart';
import '../../widgets/member_form/member_lookup_section.dart';
import '../../widgets/member_form/member_onboarding_summary.dart';
import '../../widgets/member_form/member_profile_header.dart';
import '../../widgets/member_form/member_photo_panel.dart';
import '../../widgets/member_form/member_profile_nav_section.dart';
import '../../widgets/member_lock_banners.dart';
import '../../widgets/member_nav/keyboard_shortcut_handler.dart';
import '../../widgets/member_nav/member_filter_panel.dart';
import '../../widgets/member_nav/member_list_panel.dart';
import '../../widgets/member_nav/profile_navigation_bar.dart';
import '../../widgets/member_nav/unsaved_changes_dialog.dart';
import '../../widgets/onboarding_checklist_card.dart';
import '../../widgets/record_visibility_dialog.dart';
import '../../widgets/screenshot_protected_view.dart';
import '../../widgets/smart_record_field.dart';
import 'lookup_manager_dialog.dart';
import 'member_files_dialog.dart';
import 'member_form_admin_filter.dart';
import 'member_form_snapshot.dart';

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
  // NEW ADDITION - LRO Record No. (Delete controller + usages to revert)
  final _lroRecordNo = TextEditingController();
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
  // NEW ADDITION - RS radio in nav bar (always OFF until Admin activates)
  bool _rsRadioOn = false;
  bool _rsRadioBusy = false;
  String? _lastLoggedSecureViewId;
  final _searchFocusNode = FocusNode();
  bool _navForward = true;

  /// Explicit Edit Mode — fields stay read-only until user clicks Edit.
  bool _isEditing = false;

  /// Admin top-bar view: All / New / RS.
  // NEW ADDITION - Delete field + filter UI to revert
  AdminViewFilter _adminViewFilter = AdminViewFilter.all;
  Set<String> _secretaryMemberIds = const {};
  bool _hasUnsavedChanges = false;
  bool _suppressDirty = false;
  MemberFormSnapshot? _snapshot;

  String? _saIdError;
  String? _saIdWarning;
  String? _globalRecordError;
  String? _lroRecordError;
  bool _isCheckingSaId = false;
  bool _isCheckingGlobalRecord = false;
  String? _duplicateSaIdMemberId;
  String? _duplicateGlobalRecordMemberId;
  Timer? _saIdDebounce;
  Timer? _globalRecordDebounce;

  bool get _viewerIsSysAdmin =>
      ref.read(authUserProvider)?.isSystemAdministrator ?? false;

  bool get _viewerIsAdmin => ref.read(authUserProvider)?.isAdmin ?? false;

  bool get _viewerIsSecretary =>
      ref.read(authUserProvider)?.isSecretary ?? false;

  bool get _isMemberOnly =>
      ref.read(authUserProvider)?.isMemberRole ?? false;

  String? get _persistedGlobalRecord => _loadedMember?.globalRecordNo;

  String? get _persistedLroRecord => _loadedMember?.lroRecordNo;

  bool get _showGlobalRecordField => RecordFieldPolicy.shouldShow(
        isAdmin: _viewerIsAdmin,
        isSecretary: _viewerIsSecretary,
        value: _persistedGlobalRecord ?? _globalRecordNo.text,
      );

  bool get _globalRecordReadOnly => RecordFieldPolicy.isReadOnly(
        isAdmin: _viewerIsAdmin,
        isSecretary: _viewerIsSecretary,
        persistedValue: _persistedGlobalRecord,
        formReadOnly: _formReadOnly,
      );

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
    _lroRecordNo.addListener(_onFormFieldChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _saIdDebounce?.cancel();
    _globalRecordDebounce?.cancel();
    _saId.dispose();
    _globalRecordNo.dispose();
    _lroRecordNo.dispose();
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
    // Rebuild so Save button green/gray updates on every keystroke.
    // MODIFIED - always setState for Save enable (Delete comment to revert)
    setState(() => _hasUnsavedChanges = true);
    assert(() {
      debugPrint(
        '📝 Save enable=${_canPressSave} missing=${_missingSaveLabels}',
      );
      return true;
    }());
  }

  void _markDirty() {
    if (_suppressDirty || !_isEditing) return;
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  MemberFormSnapshot _takeSnapshot() {
    return MemberFormSnapshot(
      saId: _saId.text,
      globalRecordNo: _globalRecordNo.text,
      lroRecordNo: _lroRecordNo.text,
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

  void _applySnapshot(MemberFormSnapshot snap) {
    _suppressDirty = true;
    _saId.text = snap.saId;
    _globalRecordNo.text =
        GlobalRecordValidator.displayValue(snap.globalRecordNo);
    _lroRecordNo.text = snap.lroRecordNo;
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

  bool get _step1FormComplete => Step1Validator.isFormComplete(
        saId: _saId.text,
        globalRecordNo: _globalRecordNo.text,
        lroRecordNo: _lroRecordNo.text,
        memberName: _memberName.text,
        surname: _surname.text,
        address: _address.text,
        suburb: _suburb,
        townCity: _townCity,
        postalCode: _postalCode,
        contactNo1: _contactNo1.text,
        contactNo2: _contactNo2.text,
        emailAddress: _email.text,
      );

  InputDecoration _fieldDecoration(
    String label, {
    bool isDense = false,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
    bool filled = false,
  }) {
    return InputDecoration(
      labelText: label,
      isDense: isDense,
      errorText: errorText,
      helperText: helperText,
      helperMaxLines: 2,
      errorMaxLines: 3,
      suffixIcon: suffixIcon ??
          (filled
              ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
              : Icon(
                  _isEditing && !_formReadOnly ? Icons.edit : Icons.lock,
                  size: 16,
                  color:
                      _isEditing && !_formReadOnly ? Colors.blue : Colors.grey,
                )),
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

    try {
      final hardError = SaIdValidator.validate(value);
      if (hardError != null) {
        if (!mounted) return;
        setState(() => _saIdError = hardError);
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
        _saIdWarning = soft;
        if (result.isDuplicate) {
          _saIdError = result.errorMessage;
          _duplicateSaIdMemberId = result.existingMember?.id;
        }
      });
    } catch (e) {
      debugPrint('SA ID live check failed: $e');
      // Do not leave Save blocked on transient check failures.
    } finally {
      if (mounted) setState(() => _isCheckingSaId = false);
    }
  }

  Future<void> _validateGlobalRecordLive(String value) async {
    if (!mounted) return;
    // Empty GR is allowed — clear errors so Save is not blocked.
    // MODIFIED - optional GR (Delete early-return to revert required GR)
    if (value.trim().isEmpty) {
      setState(() {
        _isCheckingGlobalRecord = false;
        _globalRecordError = null;
        _duplicateGlobalRecordMemberId = null;
      });
      return;
    }
    setState(() {
      _isCheckingGlobalRecord = true;
      _globalRecordError = null;
      _duplicateGlobalRecordMemberId = null;
    });

    try {
      final formatError = GlobalRecordValidator.validate(
        value,
        required: false,
      );
      if (formatError != null) {
        if (!mounted) return;
        setState(() => _globalRecordError = formatError);
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
        if (result.isDuplicate) {
          _globalRecordError = result.errorMessage;
          _duplicateGlobalRecordMemberId = result.existingMember?.id;
        }
      });
    } catch (e) {
      debugPrint('Global Record live check failed: $e');
    } finally {
      if (mounted) setState(() => _isCheckingGlobalRecord = false);
    }
  }

  /// Labels still missing/invalid for Save (real-time).
  /// Global Record is optional — does not keep Save gray.
  /// // MODIFIED - GR optional for enable (Delete requireGlobalRecord:false)
  List<String> get _missingSaveLabels =>
      MemberFormSaveGate.missingRequiredLabels(
        saId: _saId.text,
        globalRecordNo: _globalRecordNo.text,
        memberName: _memberName.text,
        surname: _surname.text,
        address: _address.text,
        suburb: _suburb,
        townCity: _townCity,
        postalCode: _postalCode,
        contactNo1: _contactNo1.text,
        email: _email.text,
        requireGlobalRecord: false,
        saIdLiveError: _saIdError,
        globalRecordLiveError: _globalRecordError,
      );

  bool get _canPressSave => MemberFormSaveGate.canEnableSave(
        isEditing: _isEditing,
        saving: _saving,
        formReadOnly: _formReadOnly,
        fieldsMasked: _fieldsMasked,
        missingLabels: _missingSaveLabels,
      );

  /// Admin All / New / RS filter applied before list search/sort.
  // NEW ADDITION - Delete getter to revert admin view filter
  List<Member> get _adminViewMembers {
    if (!_viewerIsAdmin) return _members;
    switch (_adminViewFilter) {
      case AdminViewFilter.all:
        return _members;
      case AdminViewFilter.newMembers:
        // New only — never include Recording Secretaries.
        // MODIFIED - exclude RS from New (Delete && !contains to revert)
        return _members
            .where(
              (m) =>
                  (m.registrationStatus == 'pending' ||
                      m.registrationStatus == 'in_progress') &&
                  !_secretaryMemberIds.contains(m.id),
            )
            .toList();
      case AdminViewFilter.rs:
        return _members
            .where((m) => _secretaryMemberIds.contains(m.id))
            .toList();
    }
  }

  int get _countAll => _members.length;

  int get _countNew => _members
      .where(
        (m) =>
            (m.registrationStatus == 'pending' ||
                m.registrationStatus == 'in_progress') &&
            !_secretaryMemberIds.contains(m.id),
      )
      .length;

  int get _countRs =>
      _members.where((m) => _secretaryMemberIds.contains(m.id)).length;

  Widget _adminViewRadio({
    required String label,
    required int count,
    required AdminViewFilter value,
  }) {
    final selected = _adminViewFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _adminViewFilter = value);
        ref.read(memberNavigationProvider.notifier).setPage(0);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.lightBlueAccent : Colors.white54,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 4),
            Text(
              '$label ($count)',
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _bootstrap() async {
    final db = ref.read(databaseServiceProvider);
    final auth = ref.read(authUserProvider);
    // Admin must see every Member, including Recording Secretaries.
    if (auth != null && (auth.isAdmin || auth.isSystemAdministrator)) {
      await db.ensureRecordingSecretaryMemberLinks();
    }

    final dbUsers = await db.getAppUsers();
    String? adminMemberId;
    final secretaryIds = <String>{};
    for (final u in dbUsers) {
      if (u.deleted) continue;
      final mid = u.memberId?.trim();
      if (mid != null && mid.isNotEmpty && u.isSecretary) {
        secretaryIds.add(mid);
      }
      if (u.isSystemAdministrator) {
        adminMemberId = u.memberId;
      }
    }

    var members =
        await ref.read(dataAccessServiceProvider).getVisibleMembers(auth);
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
      _secretaryMemberIds = secretaryIds;
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
      // Cancelled members are excluded from the active list — still open by id.
      final cancelled = await ref
          .read(databaseServiceProvider)
          .getMemberById(selectedId);
      if (cancelled != null && mounted) {
        _loadMember(cancelled, -1);
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
      // RS radio always OFF when opening a member — Admin must activate
      _rsRadioOn = false;
      _rsRadioBusy = false;
      _saId.text = masked ? _maskValue : member.saId;
      _globalRecordNo.text = masked
          ? _maskValue
          : GlobalRecordValidator.displayValue(member.globalRecordNo);
      _lroRecordNo.text = masked ? _maskValue : (member.lroRecordNo ?? '');
      _lroRecordError = null;
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
      _rsRadioOn = false;
      _rsRadioBusy = false;
      _saId.clear();
      _globalRecordNo.clear();
      _lroRecordNo.clear();
      _lroRecordError = null;
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

      final members = await ref
          .read(dataAccessServiceProvider)
          .getVisibleMembers(ref.read(authUserProvider));
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
    if (_saIdError != null ||
        (_globalRecordNo.text.trim().isNotEmpty &&
            _globalRecordError != null) ||
        _lroRecordError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _saIdError ??
                  _globalRecordError ??
                  _lroRecordError ??
                  'Fix SA ID / Record fields before saving.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
    final typedGlobal = _globalRecordReadOnly
        ? GlobalRecordValidator.displayValue(
            _persistedGlobalRecord ?? _globalRecordNo.text,
          )
        : GlobalRecordValidator.displayValue(_globalRecordNo.text);
    final nextLroRaw = RecordFieldPolicy.isReadOnly(
      isAdmin: _viewerIsAdmin,
      isSecretary: _viewerIsSecretary,
      persistedValue: _persistedLroRecord,
      formReadOnly: _formReadOnly,
    )
        ? (_persistedLroRecord ?? _lroRecordNo.text)
        : _lroRecordNo.text;
    final nextLro = nextLroRaw.trim().isEmpty ? null : nextLroRaw.trim();
    // MODIFIED - SA ID required; Global Record optional for new saves
    if (_saId.text.trim().isEmpty) {
      return false;
    }

    setState(() => _saving = true);

    try {
      final existing = _currentId == null
          ? null
          : await ref.read(memberRepositoryProvider).getById(_currentId!);

      // Keep draft id when creating so a pre-picked photo stays linked.
      final memberId = _currentId ??
          _draftId ??
          existing?.id ??
          const Uuid().v4();

      // UNIQUE(globalRecordNo) forbids multiple ''; use per-member pending token.
      // MODIFIED - pending GR token (Delete to require real GR again)
      final nextGlobal = typedGlobal.isEmpty
          ? GlobalRecordValidator.pendingFor(memberId)
          : typedGlobal;

      RecordFieldPolicy.assertCanSave(
        isAdmin: _viewerIsAdmin,
        existingGlobalRecordNo: existing?.globalRecordNo,
        nextGlobalRecordNo: nextGlobal,
        existingLroRecordNo: existing?.lroRecordNo,
        nextLroRecordNo: nextLro,
      );

      final member = (existing ??
              Member.create(
                saId: _saId.text.trim(),
                globalRecordNo: nextGlobal,
                memberName: _memberName.text.trim(),
                surname: _surname.text.trim(),
                lroRecordNo: nextLro,
              ))
          .copyWith(
        id: memberId,
        saId: _saId.text.trim(),
        globalRecordNo: nextGlobal,
        lroRecordNo: nextLro,
        clearLroRecordNo: nextLro == null,
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

      final toSave = member;

      var saved = await ref.read(memberRepositoryProvider).save(toSave);
      final user = ref.read(authUserProvider);
      if (user != null) {
        await ref.read(activityServiceProvider).record(
              userName: user.displayName,
              action: existing == null
                  ? 'Created member ${saved.fullName}'
                  : 'Updated member ${saved.fullName}',
              captureGps: false,
            );
        // NEW ADDITION - audit record number entry/changes
        for (final line in RecordFieldPolicy.auditLines(
          memberName: saved.fullName,
          oldGlobal: existing?.globalRecordNo,
          newGlobal: saved.globalRecordNo,
          oldLro: existing?.lroRecordNo,
          newLro: saved.lroRecordNo,
        )) {
          await ref.read(activityServiceProvider).record(
                userName: user.displayName,
                action: line,
                captureGps: false,
              );
        }
      }

      // NEW ADDITION - Step 1 auto-activation when all required fields filled
      final beforeStep1 = saved.step1MemberInfoComplete;
      saved = await ref
          .read(stepActivationServiceProvider)
          .checkAndActivateStep1(saved);
      final step1JustActivated =
          !beforeStep1 && saved.step1MemberInfoComplete;

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

      if (step1JustActivated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Step 1 (Member Info) auto-activated — all required fields complete.',
            ),
            backgroundColor: Colors.green,
          ),
        );
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

  /// Soft-cancel membership (Admin). Never permanently deletes member data.
  // MODIFIED - Delete → Cancel Membership (Delete method body to revert)
  Future<void> _cancelMembership() async {
    if (!_viewerIsAdmin || _fieldsMasked) return;
    final member = _loadedMember;
    if (member == null) return;
    if (member.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.fullName} is already cancelled.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final ok = await CancelMembershipDialog.show(context, member);
    if (ok != true || !mounted) return;
    ref.invalidate(cancelledMembersProvider);
    ref.invalidate(membersProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Membership cancelled for ${member.fullName}'),
        backgroundColor: Colors.green,
      ),
    );
    ref.read(memberNavigationProvider.notifier).goBackToList();
    await _bootstrap();
  }

  Future<void> _delete() async {
    // Permanent delete removed — route Admin through soft-cancel.
    await _cancelMembership();
  }

  Widget _lookupDropdown({
    required String label,
    required LookupType type,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool required = false,
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
                decoration: _fieldDecoration(
                  required ? '$label *' : label,
                  filled: value != null && value.trim().isNotEmpty,
                ),
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
                validator: required
                    ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                    : null,
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
    final strings = AppStrings(ref.watch(appLanguageProvider));
    final authUser = ref.read(authUserProvider);
    final isMemberOnly = _isMemberOnly;
    final showList = !isMemberOnly && navState.currentView == MemberNavView.list;
    final listSource = _adminViewMembers;
    final filtered = nav.filtered(listSource);
    final page = nav.pageMembers(listSource);
    final counts = MemberNavigationLogic.counts(
      listSource,
      favoriteIds: navState.favoriteIds,
    );
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    // Admin Cancel target: open profile, else list highlight / selection.
    Member? cancelTarget;
    if (_viewerIsAdmin) {
      final loaded = _loadedMember;
      if (loaded != null && !loaded.isCancelled) {
        cancelTarget = loaded;
      } else if (showList && page.isNotEmpty) {
        final hi = navState.highlightIndex.clamp(0, page.length - 1);
        final candidate = page[hi];
        if (!candidate.isCancelled) cancelTarget = candidate;
      } else {
        final sid =
            navState.selectedMemberId ?? ref.watch(selectedMemberIdProvider);
        if (sid != null) {
          for (final m in _members) {
            if (m.id == sid && !m.isCancelled) {
              cancelTarget = m;
              break;
            }
          }
        }
      }
    }

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
              CancelButton(
                onPressed: () => Navigator.pop(ctx, false),
                text: 'Cancel',
              ),
              SaveButton(
                onPressed: () => Navigator.pop(ctx, true),
                text: '💾 Save First',
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

    Future<void> guardedCancelMembership() async {
      if (_isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please save or cancel edits first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await _cancelMembership();
    }

    Future<void> goFirst() async {
      if (!await _ensureCanNavigate()) return;
      await nav.navigateFirst(all: _members);
      final id = ref.read(memberNavigationProvider).selectedMemberId;
      final idx = _members.indexWhere((m) => m.id == id);
      if (idx >= 0) _loadMember(_members[idx], idx);
    }

    Future<void> goLast() async {
      if (!await _ensureCanNavigate()) return;
      await nav.navigateLast(all: _members);
      final id = ref.read(memberNavigationProvider).selectedMemberId;
      final idx = _members.indexWhere((m) => m.id == id);
      if (idx >= 0) _loadMember(_members[idx], idx);
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
      onDelete: (_loadedMember != null && _viewerIsAdmin)
          ? () => guardedCancelMembership()
          : null,
      onUpload: () => guardedUpload(),
      onRefresh: () async {
        if (!await _ensureCanNavigate()) return;
        await refreshApp(ref);
        await _bootstrap();
      },
      onHome: () => goFirst(),
      onEnd: () => goLast(),
      onOpenHighlighted: openHighlighted,
      onCancelMembership: (_viewerIsAdmin &&
              _loadedMember != null &&
              !_loadedMember!.isCancelled)
          ? () => guardedCancelMembership()
          : null,
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
                    const Text(
                      '👥 MEMBER MANAGEMENT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.labelText,
                      ),
                    ),
                    // Far right: View Members → Cancel → Search
                    // MODIFIED - controls aligned end (Delete Spacer block to revert)
                    const Spacer(),
                    if (_viewerIsAdmin) ...[
                      Text(
                        strings.viewMembers,
                        style: const TextStyle(
                          color: AppTheme.labelText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _adminViewRadio(
                        label: strings.filterAll,
                        count: _countAll,
                        value: AdminViewFilter.all,
                      ),
                      _adminViewRadio(
                        label: strings.filterNew,
                        count: _countNew,
                        value: AdminViewFilter.newMembers,
                      ),
                      _adminViewRadio(
                        label: strings.filterRs,
                        count: _countRs,
                        value: AdminViewFilter.rs,
                      ),
                    ],
                    if (_viewerIsAdmin && cancelTarget != null)
                      ActionButton(
                        onPressed: () async {
                          final target = cancelTarget!;
                          if (_loadedMember?.id != target.id) {
                            await openMember(target);
                          }
                          if (!mounted) return;
                          await guardedCancelMembership();
                        },
                        text: strings.cancelMembership,
                        icon: Icons.cancel_outlined,
                      ),
                    if (!isMemberOnly)
                      IconButton(
                        tooltip: strings.focusSearch,
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
                                        allMembers: listSource,
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
                                  onFirst: goFirst,
                                  onLast: goLast,
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
      _rsRadioOn = false;
    });
  }

  // NEW ADDITION - nav-bar RS radio promote/demote (Delete method to revert)
  Future<void> _onRsRadioChanged(bool turnOn) async {
    if (_rsRadioBusy) return;
    final isAdmin = ref.read(isAdminProvider);
    if (!isAdmin) return;
    final strings = ref.read(appStringsProvider);

    final member = _loadedMember;
    if (member == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.saveOrCancelFirst)),
      );
      return;
    }

    final admin = ref.read(authUserProvider);
    if (admin == null) return;

    setState(() => _rsRadioBusy = true);
    try {
      if (turnOn) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(strings.activateRs),
            content: Text(
              'Promote ${member.fullName} to Recording Secretary?',
            ),
            actions: [
              CancelButton(
                onPressed: () => Navigator.pop(ctx, false),
                text: strings.cancel,
              ),
              EnableButton(
                onPressed: () => Navigator.pop(ctx, true),
                text: strings.activateRsBtn,
              ),
            ],
          ),
        );
        if (confirm != true) return;

        await ref.read(promotionServiceProvider).promoteToRecordingSecretary(
              member: member,
              admin: admin,
            );
        if (!mounted) return;
        setState(() => _rsRadioOn = true);
        ref.invalidate(appUsersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.fullName} is now a Recording Secretary'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(strings.deactivateRs),
            content: Text(
              'Demote ${member.fullName} to Regular Member?',
            ),
            actions: [
              CancelButton(
                onPressed: () => Navigator.pop(ctx, false),
                text: strings.cancel,
              ),
              ActionButton(
                onPressed: () => Navigator.pop(ctx, true),
                text: strings.deactivateRsBtn,
              ),
            ],
          ),
        );
        if (confirm != true) return;

        await ref.read(promotionServiceProvider).demoteToMember(
              member: member,
              admin: admin,
            );
        if (!mounted) return;
        setState(() => _rsRadioOn = false);
        ref.invalidate(appUsersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.fullName} is now a Regular Member'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _rsRadioBusy = false);
    }
  }

  Widget _buildProfilePane({
    required List<Member> filtered,
    required MemberNavigationState navState,
    required Future<void> Function() onBack,
    required Future<void> Function() onPrev,
    required Future<void> Function() onNext,
    required Future<void> Function() onFirst,
    required Future<void> Function() onLast,
  }) {
    final strings = ref.watch(appStringsProvider);
    final member = _loadedMember;
    final idx = navState.currentIndex;
    String? prevName;
    String? nextName;
    if (idx > 0 && idx < filtered.length) {
      prevName = filtered[idx - 1].fullName;
    }
    // MODIFIED - from draft, Next targets first filtered member
    if (idx < 0 && filtered.isNotEmpty) {
      nextName = filtered.first.fullName;
      prevName = filtered.first.fullName;
    } else if (idx >= 0 && idx < filtered.length - 1) {
      nextName = filtered[idx + 1].fullName;
    }

    final modeLabel = _isEditing ? 'EDIT MODE' : 'VIEW MODE';

    Widget buildNavHeader() {
      // MODIFIED - always show ProfileNavigationBar (incl. New Member draft)
      // so Previous/Next stay visible.
      final displayMember = member ??
          Member(
            id: 'draft',
            saId: '',
            globalRecordNo: '',
            memberName: 'New',
            surname: 'Member',
            updatedAt: DateTime.now().toUtc(),
          );
      return MemberProfileNavSection(
        currentMember: displayMember,
        currentIndex: idx,
        totalMembers: filtered.length,
        previousName: prevName,
        nextName: nextName,
        onBack: () => onBack(),
        onPrevious: () => onPrev(),
        onNext: () => onNext(),
        onFirst: () => onFirst(),
        onLast: () => onLast(),
        canEdit: member != null && _canEnterEditMode && !_isEditing,
        canNew: _canAddMembers,
        showRsRadio: ref.watch(isAdminProvider),
        rsRadioOn: _rsRadioOn,
        rsRadioEnabled: ref.watch(isAdminProvider) &&
            member != null &&
            !_rsRadioBusy,
        onEdit: (member != null && _canEnterEditMode && !_isEditing)
            ? _enterEditMode
            : null,
        onNew: _canAddMembers
            ? () async {
                if (!await _ensureCanNavigate()) return;
                openMemberDraft();
              }
            : null,
        onUpload: member == null
            ? null
            : () async {
                if (_isEditing && _hasUnsavedChanges) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('⚠️ Unsaved Changes'),
                      content: const Text(
                        'You have unsaved changes. Please save before uploading files.',
                      ),
                      actions: [
                        CancelButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          text: 'Cancel',
                        ),
                        SaveButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          text: '💾 Save First',
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
        onRsRadioChanged: _onRsRadioChanged,
      );
    }

    final formChrome = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEditing)
            MemberEditModeBanner(hasUnsavedChanges: _hasUnsavedChanges),
          const SizedBox(height: 8),
          MemberProfileHeader(
            modeLabel: modeLabel,
            formMode: _formMode,
            member: _loadedMember,
            isEditing: _isEditing,
            hasUnsavedChanges: _hasUnsavedChanges,
            saving: _saving,
            canEnterEditMode: _canEnterEditMode,
            fieldsMasked: _fieldsMasked,
            canPressSave: _canPressSave,
            currentId: _currentId,
            strings: strings,
            onEnterEdit: _enterEditMode,
            onCancelEdit: _cancelEdit,
            onSave: _save,
            onUploadFiles: () async {
              final m = _loadedMember;
              if (m == null) return;
              if (_isEditing && _hasUnsavedChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Save or cancel edits before opening files.'),
                  ),
                );
                return;
              }
              await showMemberFilesDialog(context, ref, m);
            },
          ),
          const Divider(),
          if (_loadedMember != null && _formMode.showTempAccessSection)
            MemberLockChrome(
              member: _loadedMember!,
              onMemberUpdated: _onLockedMemberUpdated,
              onAccessVerified: () {
                if (mounted) setState(() {});
              },
            ),
          if (_loadedMember != null && _formMode.showOnboardingChecklist)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MemberOnboardingSummary(
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
                                MemberIdentityFormSection(
                                  saIdController: _saId,
                                  globalRecordNoController: _globalRecordNo,
                                  lroRecordNoController: _lroRecordNo,
                                  memberNameController: _memberName,
                                  surnameController: _surname,
                                  strings: strings,
                                  isEditing: _isEditing,
                                  formReadOnly: _formReadOnly,
                                  viewerIsAdmin: _viewerIsAdmin,
                                  viewerIsSecretary: _viewerIsSecretary,
                                  isMemberOnly: _isMemberOnly,
                                  showGlobalRecordField: _showGlobalRecordField,
                                  globalRecordReadOnly: _globalRecordReadOnly,
                                  isCheckingSaId: _isCheckingSaId,
                                  isCheckingGlobalRecord:
                                      _isCheckingGlobalRecord,
                                  saIdError: _saIdError,
                                  saIdWarning: _saIdWarning,
                                  globalRecordError: _globalRecordError,
                                  lroRecordError: _lroRecordError,
                                  duplicateSaIdMemberId: _duplicateSaIdMemberId,
                                  duplicateGlobalRecordMemberId:
                                      _duplicateGlobalRecordMemberId,
                                  persistedGlobalRecord: _persistedGlobalRecord,
                                  persistedLroRecord: _persistedLroRecord,
                                  fieldDecorationBuilder: _fieldDecoration,
                                  saIdValidator: (v) =>
                                      SaIdValidator.validate(v ?? ''),
                                  globalRecordValidator: (v) {
                                    if (_globalRecordReadOnly) return null;
                                    final err = GlobalRecordValidator.validate(
                                      v ?? '',
                                      required: false,
                                    );
                                    if (err != null) return err;
                                    if (_globalRecordError != null &&
                                        _duplicateGlobalRecordMemberId != null) {
                                      return _globalRecordError;
                                    }
                                    return null;
                                  },
                                  lroValidator: (v) =>
                                      LroRecordValidator.validate(v ?? ''),
                                  memberNameValidator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? strings.requiredField
                                          : null,
                                  surnameValidator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? strings.requiredField
                                          : null,
                                  onManageRecordVisibility: () =>
                                      RecordVisibilityDialog.show(context),
                                  onViewExistingSaIdDuplicate: () =>
                                      _openExistingDuplicate(
                                    _duplicateSaIdMemberId,
                                  ),
                                  onViewExistingGlobalRecordDuplicate: () =>
                                      _openExistingDuplicate(
                                    _duplicateGlobalRecordMemberId,
                                  ),
                                  onLroChanged: (value) {
                                    setState(() {
                                      _lroRecordError =
                                          LroRecordValidator.validate(value);
                                    });
                                    _markDirty();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          MemberPhotoPanel(
                            photoBytes: _photoBytes,
                            photoUrl: _photoUrl,
                            photoLocalPath: _photoLocalPath,
                            busy: _photoBusy,
                            readOnly: _formReadOnly,
                            onPick: _pickMemberPhoto,
                            onClear: _clearMemberPhoto,
                          ),
                          if (constraints.maxWidth > 720)
                            const Expanded(child: SizedBox()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  MemberContactDetailsSection(
                    addressController: _address,
                    contactNo1Controller: _contactNo1,
                    contactNo2Controller: _contactNo2,
                    emailController: _email,
                    commentController: _comment,
                    strings: strings,
                    formReadOnly: _formReadOnly,
                    fieldDecorationBuilder: _fieldDecoration,
                    addressValidator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                    contactNo1Validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? strings.requiredField
                            : null,
                    emailValidator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return strings.requiredField;
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value)) {
                        return strings.enterValidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  MemberLookupSection(
                    strings: strings,
                    formReadOnly: _formReadOnly,
                    fieldDecorationBuilder: _fieldDecoration,
                    suburb: _suburb,
                    townCity: _townCity,
                    postalCode: _postalCode,
                    onSuburbChanged: (v) {
                      setState(() => _suburb = v);
                      _markDirty();
                    },
                    onTownCityChanged: (v) {
                      setState(() => _townCity = v);
                      _markDirty();
                    },
                    onPostalCodeChanged: (v) {
                      setState(() => _postalCode = v);
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 8),
                  // NEW ADDITION - Step 1 completion banner (Delete block to revert)
                  if (_step1FormComplete &&
                      !(_loadedMember?.step1MemberInfoComplete ?? false))
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All required fields complete! Step 1 (Member Info) '
                              'will auto-activate when you save.',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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
    final authUser = ref.read(authUserProvider);
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

  void _onLockedMemberUpdated(Member updated) {
    if (!mounted) return;
    setState(() => _loadedMember = updated);
  }

  Future<void> _toggleOnboardingStep(int step, bool complete) async {
    final member = _loadedMember;
    final user = ref.read(authUserProvider);
    if (member == null || user == null) return;
    if (complete && !(user.isSecretary || user.isAdmin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Recording Secretaries or Administrators can record payments.'),
        ),
      );
      return;
    }
    try {
      if (complete) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Record payment for this step?'),
            content: Text(
              'This will log a manual payment for Step $step and unlock the next onboarding milestone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  backgroundColor: AppButtonColors.cancelBg,
                  foregroundColor: AppButtonColors.cancelFg,
                  side: const BorderSide(
                    color: AppButtonColors.whiteRing,
                    width: 2,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppButtonColors.saveBg,
                  foregroundColor: AppButtonColors.saveFg,
                  side: const BorderSide(
                    color: AppButtonColors.whiteRing,
                    width: 2,
                  ),
                ),
                child: const Text('Record payment'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        final paidAt = DateTime.now();
        await ref.read(remunerationServiceProvider).recordManualPayment(
          memberId: member.id,
          memberName: member.fullName,
          secretaryId: user.id,
          stepNumber: step,
          paymentDateTime: paidAt,
          receiptNumber: 'AUTO-${paidAt.millisecondsSinceEpoch}',
          notes: 'Manual payment recorded in member form',
        );
        await ref.read(activityServiceProvider).record(
          userName: user.displayName,
          action:
              '[ACT-PAY-MEMBER-FORM] 💳 recorded_manual_payment for ${member.fullName} step_$step',
          captureGps: false,
        );
      }
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
          content: Text('⚠️ Check all 5 onboarding steps before completing.'),
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
          CancelButton(
            onPressed: () => Navigator.pop(ctx, false),
            text: 'Cancel',
          ),
          SubmitButton(
            onPressed: () => Navigator.pop(ctx, true),
            text: 'Yes, Complete',
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
