part of '../database_service.dart';

/// Recording Secretary assignment and remuneration persistence.
mixin _DbAssignmentRemuneration on _DatabaseServiceBase {
  // ===========================================================================
  // NEW ADDITION - Recording Secretary assignment + remuneration (v12)
  // Delete from this banner to end of class (before final `}`) to revert.
  // ===========================================================================

  Future<List<AppUser>> getRecordingSecretaries({bool activeOnly = false}) async {
    final users = await getAppUsers();
    return users
        .where(
          (u) =>
              !u.deleted &&
              u.isSecretary &&
              (!activeOnly || u.active),
        )
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Future<List<AppUser>> getActiveRecordingSecretaries() =>
      getRecordingSecretaries(activeOnly: true);

  Future<int> countAssignedMembers(String secretaryId) async {
    if (_memoryMode) {
      return _members.values
          .where(
            (m) =>
                !m.deleted &&
                m.assignedSecretaryId == secretaryId,
          )
          .length;
    }
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM members '
      'WHERE deleted = 0 AND assignedSecretaryId = ?',
      [secretaryId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // NEW ADDITION - RS visibility queries (Delete methods to revert)
  @override
  Future<List<Member>> getMembersAssignedToSecretary(String secretaryId) async {
    if (_memoryMode) {
      return _members.values
          .where(
            (m) =>
                !m.deleted &&
                !m.isCancelled &&
              !m.step5CredentialCardComplete &&
                m.assignedSecretaryId == secretaryId,
          )
          .toList()
        ..sort(
          (a, b) => a.surname.toLowerCase().compareTo(b.surname.toLowerCase()),
        );
    }
    final rows = await db.query(
      'members',
      where:
          'assignedSecretaryId = ? AND deleted = 0 AND '
          '(isCancelled IS NULL OR isCancelled = 0) AND '
          '(step5CredentialCardComplete IS NULL OR step5CredentialCardComplete = 0)',
      whereArgs: [secretaryId],
      orderBy: 'surname COLLATE NOCASE ASC, memberName COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<List<Reminder>> getRemindersAssignedToSecretary(
    String secretaryId,
  ) async {
    if (_memoryMode) {
      return _reminders.values
          .where(
            (r) =>
                !r.deleted &&
                r.status == 'active' &&
                r.assignedSecretaryId == secretaryId,
          )
          .toList();
    }
    final rows = await db.query(
      'reminders',
      where: 'assignedSecretaryId = ? AND status = ? AND deleted = 0',
      whereArgs: [secretaryId, 'active'],
    );
    return rows.map(Reminder.fromMap).toList();
  }

  /// Active onboarding reminders for members assigned to this secretary.
  Future<List<Reminder>> getRemindersForSecretaryAssignedMembers(
    String secretaryId,
  ) async {
    final assigned = await getMembersAssignedToSecretary(secretaryId);
    final ids = assigned.map((m) => m.id).toSet();
    if (ids.isEmpty) return const [];
    final all = await getActiveOnboardingReminders();
    return all.where((r) => ids.contains(r.memberId)).toList();
  }

  Future<Member> assignSecretaryToMember({
    required String memberId,
    String? secretaryId,
    String? assignedBy,
    String assignmentMethod = 'manual',
  }) async {
    final member = await getMemberById(memberId);
    if (member == null) {
      throw StateError('Member not found: $memberId');
    }

    String? name;
    if (secretaryId != null) {
      final users = await getAppUsers();
      for (final u in users) {
        if (u.id == secretaryId) {
          name = u.displayName;
          break;
        }
      }
    }

    final updated = secretaryId == null
        ? member.copyWith(
            clearSecretaryAssignment: true,
            lastModifiedBy: assignedBy,
            updatedAt: DateTime.now().toUtc(),
            pendingSync: true,
          )
        : member.copyWith(
            assignedSecretaryId: secretaryId,
            assignedSecretaryName: name,
            assignedDate: DateTime.now().toUtc(),
            assignedBy: assignedBy,
            assignmentMethod: assignmentMethod,
            lastModifiedBy: assignedBy,
            updatedAt: DateTime.now().toUtc(),
            pendingSync: true,
          );
    await upsertMember(updated);
    return updated;
  }

  Future<Reminder> assignSecretaryToReminder({
    required String reminderId,
    String? secretaryId,
    String assignmentMethod = 'manual',
  }) async {
    final reminder = await getReminderById(reminderId);
    if (reminder == null) {
      throw StateError('Reminder not found: $reminderId');
    }

    String? name;
    if (secretaryId != null) {
      final users = await getAppUsers();
      for (final u in users) {
        if (u.id == secretaryId) {
          name = u.displayName;
          break;
        }
      }
    }

    final updated = secretaryId == null
        ? reminder.copyWith(
            clearSecretaryAssignment: true,
            updatedAt: DateTime.now().toUtc(),
            pendingSync: true,
          )
        : reminder.copyWith(
            assignedSecretaryId: secretaryId,
            assignedSecretaryName: name,
            assignedDate: DateTime.now().toUtc(),
            assignmentMethod: assignmentMethod,
            updatedAt: DateTime.now().toUtc(),
            pendingSync: true,
          );
    await upsertReminder(updated);
    return updated;
  }

  Future<RemunerationSettings> getRemunerationSettings() async {
    if (_memoryMode) {
      if (_remunerationSettings.isEmpty) {
        final defaults = RemunerationSettings.defaults();
        _remunerationSettings[defaults.id] = defaults;
      }
      return _remunerationSettings.values.first;
    }
    final rows = await db.query('remuneration_settings', limit: 1);
    if (rows.isEmpty) {
      final defaults = RemunerationSettings.defaults();
      await db.insert('remuneration_settings', defaults.toMap());
      return defaults;
    }
    return RemunerationSettings.fromMap(rows.first);
  }

  Future<void> saveRemunerationSettings(
    RemunerationSettings settings, {
    bool markPending = true,
  }) async {
    final saved = settings.copyWith(
      lastUpdated: DateTime.now().toUtc(),
      syncStatus: markPending ? 'pending' : settings.syncStatus,
    );
    if (_memoryMode) {
      _remunerationSettings
        ..clear()
        ..[saved.id] = saved;
      return;
    }
    await db.insert(
      'remuneration_settings',
      saved.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveRemuneration(SecretaryRemuneration record) async {
    if (_memoryMode) {
      _secretaryRemunerations[record.id] = record;
      return;
    }
    await db.insert(
      'secretary_remuneration',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRemuneration(SecretaryRemuneration record) =>
      saveRemuneration(record);

  Future<SecretaryRemuneration?> getRemuneration(String id) async {
    if (_memoryMode) return _secretaryRemunerations[id];
    final rows = await db.query(
      'secretary_remuneration',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SecretaryRemuneration.fromMap(rows.first);
  }

  Future<List<SecretaryRemuneration>> getSecretaryRemuneration(
    String secretaryId,
  ) async {
    if (_memoryMode) {
      return _secretaryRemunerations.values
          .where((r) => !r.isDeleted && r.secretaryId == secretaryId)
          .toList()
        ..sort((a, b) => b.dateEarned.compareTo(a.dateEarned));
    }
    final rows = await db.query(
      'secretary_remuneration',
      where: 'isDeleted = 0 AND secretaryId = ?',
      whereArgs: [secretaryId],
      orderBy: 'dateEarned DESC',
    );
    return rows.map(SecretaryRemuneration.fromMap).toList();
  }

  Future<List<SecretaryRemuneration>> getAllRemunerationRecords() async {
    final filterCounty = _activeCountyId;
    if (_memoryMode) {
      final list = _secretaryRemunerations.values
          .where((r) => !r.isDeleted)
          .where((r) {
            if (filterCounty.isEmpty) return true;
            final m = r.memberId != null ? _members[r.memberId] : null;
            return m != null && m.countyId == filterCounty;
          })
          .toList()
        ..sort((a, b) => b.dateEarned.compareTo(a.dateEarned));
      return list;
    }
    final rows = filterCounty.isEmpty
        ? await db.query(
            'secretary_remuneration',
            where: 'isDeleted = 0',
            orderBy: 'dateEarned DESC',
          )
        : await db.rawQuery('''
            SELECT s.* FROM secretary_remuneration s
            JOIN members m ON m.id = s.memberId
            WHERE s.isDeleted = 0 AND m.countyId = ?
            ORDER BY s.dateEarned DESC
          ''', [filterCounty]);
    return rows.map(SecretaryRemuneration.fromMap).toList();
  }

  Future<bool> hasStepRemuneration({
    required String memberId,
    required String type,
  }) async {
    if (_memoryMode) {
      return _secretaryRemunerations.values.any(
        (r) => !r.isDeleted && r.memberId == memberId && r.type == type,
      );
    }
    final rows = await db.query(
      'secretary_remuneration',
      where: 'isDeleted = 0 AND memberId = ? AND type = ?',
      whereArgs: [memberId, type],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // NEW ADDITION - unassigned reminders helpers (Delete methods to revert)
  Future<List<Reminder>> getUnassignedActiveReminders() async {
    final all = await getActiveOnboardingReminders();
    return all
        .where(
          (r) =>
              r.assignedSecretaryId == null ||
              r.assignedSecretaryId!.trim().isEmpty,
        )
        .toList();
  }

  Future<int> countAssignedReminders(String secretaryId) async {
    if (_memoryMode) {
      return _reminders.values
          .where(
            (r) =>
                !r.deleted &&
                r.status == 'active' &&
                r.assignedSecretaryId == secretaryId,
          )
          .length;
    }
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM reminders '
      'WHERE deleted = 0 AND status = ? AND assignedSecretaryId = ?',
      ['active', secretaryId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
