part of '../database_service.dart';

/// Member persistence, duplicate lookups and temporary access logs.
mixin _DbMembers on _DatabaseServiceBase {
  // ── Members ────────────────────────────────────────────────────────────

  Future<List<Member>> getAllMembers() async {
    if (_memoryMode) {
      final list = _members.values
          .where((m) => !m.deleted && !m.isCancelled)
          .toList()
        ..sort((a, b) {
          final s = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
          if (s != 0) return s;
          return a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
        });
      return list;
    }
    final rows = await db.query(
      'members',
      where: 'deleted = 0 AND (isCancelled IS NULL OR isCancelled = 0)',
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  /// Paginated active members (excludes cancelled/deleted).
  Future<({List<Member> items, int total})> getMembersPage({
    int offset = 0,
    int limit = AppConstants.membersPageSize,
    String? secretaryId,
    String? query,
  }) async {
    final all = secretaryId != null && secretaryId.isNotEmpty
        ? await getMembersAssignedToSecretary(secretaryId)
        : await getAllMembers();

    var filtered = all;
    final q = query?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      filtered = all.where((m) {
        final hay = [
          m.saId,
          m.globalRecordNo,
          m.memberName,
          m.surname,
          m.emailAddress,
          m.contactNo1,
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    }

    final total = filtered.length;
    if (offset >= total) {
      return (items: <Member>[], total: total);
    }
    final end = (offset + limit).clamp(0, total);
    return (items: filtered.sublist(offset, end), total: total);
  }

  /// Soft-cancelled memberships (still retained — never hard-deleted).
  // NEW ADDITION - Delete method to revert cancelled list
  Future<List<Member>> getCancelledMembers() async {
    if (_memoryMode) {
      final list = _members.values
          .where((m) => !m.deleted && m.isCancelled)
          .toList()
        ..sort((a, b) {
          final ad = a.cancellationDate ?? a.updatedAt;
          final bd = b.cancellationDate ?? b.updatedAt;
          return bd.compareTo(ad);
        });
      return list;
    }
    final rows = await db.query(
      'members',
      where: 'deleted = 0 AND isCancelled = 1',
      orderBy: 'cancellationDate DESC',
    );
    return rows.map(Member.fromMap).toList();
  }

  @override
  Future<Member?> getMemberById(String id) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m == null || m.deleted) return null;
      return m;
    }
    final rows = await db.query(
      'members',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<Member?> getMemberBySaId(String saId) async {
    return findMemberBySaId(saId);
  }

  /// Find active member by SA ID, optionally excluding one member (edit mode).
  Future<Member?> findMemberBySaId(
    String saId, {
    String? excludeMemberId,
  }) async {
    final key = saId.trim();
    if (key.isEmpty) return null;
    if (_memoryMode) {
      for (final m in _members.values) {
        if (m.deleted) continue;
        if (excludeMemberId != null && m.id == excludeMemberId) continue;
        if (m.saId == key) return m;
      }
      return null;
    }
    final rows = await db.query(
      'members',
      where: excludeMemberId == null
          ? 'saId = ? AND deleted = 0'
          : 'saId = ? AND deleted = 0 AND id != ?',
      whereArgs: excludeMemberId == null ? [key] : [key, excludeMemberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<Member?> getMemberByGlobalRecordNo(String globalRecordNo) async {
    return findMemberByGlobalRecordNo(globalRecordNo);
  }

  /// Find active member by Global Record No., optionally excluding one member.
  Future<Member?> findMemberByGlobalRecordNo(
    String globalRecordNo, {
    String? excludeMemberId,
  }) async {
    final key = globalRecordNo.trim();
    if (key.isEmpty) return null;
    if (_memoryMode) {
      for (final m in _members.values) {
        if (m.deleted) continue;
        if (excludeMemberId != null && m.id == excludeMemberId) continue;
        if (m.globalRecordNo == key) return m;
      }
      return null;
    }
    final rows = await db.query(
      'members',
      where: excludeMemberId == null
          ? 'globalRecordNo = ? AND deleted = 0'
          : 'globalRecordNo = ? AND deleted = 0 AND id != ?',
      whereArgs: excludeMemberId == null ? [key] : [key, excludeMemberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  Future<bool> checkSaIdExists(
    String saId, {
    String? excludeMemberId,
  }) async {
    final found = await findMemberBySaId(saId, excludeMemberId: excludeMemberId);
    return found != null;
  }

  Future<bool> checkGlobalRecordExists(
    String globalRecordNo, {
    String? excludeMemberId,
  }) async {
    final found = await findMemberByGlobalRecordNo(
      globalRecordNo,
      excludeMemberId: excludeMemberId,
    );
    return found != null;
  }

  /// Groups of members sharing the same SA ID or Global Record (data repair).
  Future<List<({String field, String value, List<Member> members})>>
      findDuplicateMemberGroups() async {
    final all = await getAllMembers();
    final bySa = <String, List<Member>>{};
    final byGr = <String, List<Member>>{};
    for (final m in all) {
      bySa.putIfAbsent(m.saId, () => []).add(m);
      byGr.putIfAbsent(m.globalRecordNo, () => []).add(m);
    }
    final groups = <({String field, String value, List<Member> members})>[];
    for (final e in bySa.entries) {
      if (e.key.isEmpty || e.value.length < 2) continue;
      groups.add((field: 'SA ID', value: e.key, members: e.value));
    }
    for (final e in byGr.entries) {
      if (e.key.isEmpty || e.value.length < 2) continue;
      groups.add((field: 'Global Record No.', value: e.key, members: e.value));
    }
    return groups;
  }

  Future<AppUser?> getAppUserByMemberId(String memberId) async {
    if (_memoryMode) {
      for (final u in _appUsers.values) {
        if (!u.deleted && u.memberId == memberId) return u;
      }
      return null;
    }
    final rows = await db.query(
      'app_users',
      where: 'memberId = ? AND deleted = 0',
      whereArgs: [memberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<Member>> searchMembers(String query) async {
    if (_memoryMode) {
      final q = query.trim().toLowerCase();
      return (await getAllMembers()).where((m) {
        final hay = [
          m.saId,
          m.globalRecordNo,
          m.memberName,
          m.surname,
          m.address,
          m.suburb,
          m.townCity,
          m.postalCode,
          m.contactNo1,
          m.contactNo2,
          m.emailAddress,
          m.comment,
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'members',
      where: '''
        deleted = 0 AND (
          saId LIKE ? OR globalRecordNo LIKE ? OR memberName LIKE ? OR
          surname LIKE ? OR address LIKE ? OR suburb LIKE ? OR
          townCity LIKE ? OR postalCode LIKE ? OR contactNo1 LIKE ? OR
          contactNo2 LIKE ? OR emailAddress LIKE ? OR comment LIKE ?
        )
      ''',
      whereArgs: List<String>.filled(12, q),
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  @override
  Future<void> upsertMember(Member member) async {
    // Pre-check uniqueness (memory + SQLite) so ConflictAlgorithm.replace
    // cannot silently delete another member on saId/globalRecord clash.
    final saClash = await findMemberBySaId(
      member.saId,
      excludeMemberId: member.id,
    );
    if (saClash != null) {
      throw DuplicateException(
        'SA ID already exists',
        field: 'SA ID',
        value: member.saId,
        existingMemberId: saClash.id,
      );
    }
    // Skip uniqueness for empty / pending placeholders (many members allowed).
    final grKey = member.globalRecordNo.trim();
    if (grKey.isNotEmpty && !grKey.startsWith('__PENDING__')) {
      final grClash = await findMemberByGlobalRecordNo(
        grKey,
        excludeMemberId: member.id,
      );
      if (grClash != null) {
        throw DuplicateException(
          'Global Record No. already exists',
          field: 'Global Record No.',
          value: member.globalRecordNo,
          existingMemberId: grClash.id,
        );
      }
    }

    await _writeMemberRow(member);
  }

  /// Insert/update member without uniqueness checks (demo / data-repair only).
  Future<void> forceUpsertMember(Member member) async {
    await _writeMemberRow(member);
  }

  Future<void> _writeMemberRow(Member member) async {
    if (_memoryMode) {
      _members[member.id] = member;
      return;
    }

    final existing = await getMemberById(member.id);
    if (existing == null) {
      await db.insert(
        'members',
        member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } else {
      await db.update(
        'members',
        member.toMap(),
        where: 'id = ?',
        whereArgs: [member.id],
      );
    }
  }

  Future<void> softDeleteMember(String id) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m != null) {
        _members[id] = m.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'members',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Member>> getPendingMembers() async {
    if (_memoryMode) {
      return _members.values.where((m) => m.pendingSync).toList();
    }
    final rows = await db.query('members', where: 'pendingSync = 1');
    return rows.map(Member.fromMap).toList();
  }

  Future<void> markMemberSynced(String id) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m != null) _members[id] = m.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'members',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMemberPhoto({
    required String id,
    String? photoLocalPath,
    String? photoUrl,
  }) async {
    if (_memoryMode) {
      final m = _members[id];
      if (m != null) {
        _members[id] = m.copyWith(
          photoLocalPath: photoLocalPath,
          photoUrl: photoUrl,
          clearPhotoLocalPath: photoLocalPath == null,
          clearPhotoUrl: photoUrl == null,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'members',
      {
        'photoLocalPath': photoLocalPath,
        'photoUrl': photoUrl,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Member>> getLockedMembers() async {
    if (_memoryMode) {
      return _members.values
          .where((m) => !m.deleted && m.isLocked)
          .toList()
        ..sort((a, b) {
          final s = a.surname.toLowerCase().compareTo(b.surname.toLowerCase());
          if (s != 0) return s;
          return a.memberName.toLowerCase().compareTo(b.memberName.toLowerCase());
        });
    }
    final rows = await db.query(
      'members',
      where: 'deleted = 0 AND isLocked = 1',
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<List<Member>> getMembersWithTempAccess() async {
    final all = await getAllMembers();
    return all
        .where(
          (m) =>
              m.temporaryAccessCode != null &&
              m.temporaryAccessCode!.isNotEmpty,
        )
        .toList();
  }

  Future<List<TemporaryAccessLog>> getAllTemporaryAccessLogs() async {
    if (_memoryMode) {
      return _tempAccessLogs.values.where((l) => !l.deleted).toList()
        ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'deleted = 0',
      orderBy: 'grantedAt DESC',
    );
    return rows.map(TemporaryAccessLog.fromMap).toList();
  }

  // ── Temporary Access Logs ──────────────────────────────────────────────

  Future<void> upsertTemporaryAccessLog(TemporaryAccessLog log) async {
    if (_memoryMode) {
      _tempAccessLogs[log.id] = log;
      return;
    }
    await db.insert(
      'temporary_access_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TemporaryAccessLog>> getTemporaryAccessLogsForMember(
    String memberId,
  ) async {
    if (_memoryMode) {
      return _tempAccessLogs.values
          .where((l) => !l.deleted && l.memberId == memberId)
          .toList()
        ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'memberId = ? AND deleted = 0',
      whereArgs: [memberId],
      orderBy: 'grantedAt DESC',
    );
    return rows.map(TemporaryAccessLog.fromMap).toList();
  }

  Future<List<TemporaryAccessLog>> getPendingTemporaryAccessLogs() async {
    if (_memoryMode) {
      return _tempAccessLogs.values.where((l) => l.pendingSync).toList();
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'pendingSync = 1',
    );
    return rows.map(TemporaryAccessLog.fromMap).toList();
  }

  Future<void> markTemporaryAccessLogSynced(String id) async {
    if (_memoryMode) {
      final log = _tempAccessLogs[id];
      if (log != null) {
        _tempAccessLogs[id] = log.copyWith(pendingSync: false);
      }
      return;
    }
    await db.update(
      'temporary_access_logs',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> temporaryAccessCodeExists(String code) async {
    if (_memoryMode) {
      return _tempAccessLogs.values.any(
        (l) => !l.deleted && !l.isRevoked && l.accessCode == code,
      );
    }
    final rows = await db.query(
      'temporary_access_logs',
      where: 'accessCode = ? AND deleted = 0 AND revoked = 0',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
