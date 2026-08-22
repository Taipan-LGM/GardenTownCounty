part of '../database_service.dart';

/// Reminder persistence, including onboarding step reminders.
mixin _DbReminders on _DatabaseServiceBase {
  // ── Reminders ──────────────────────────────────────────────────────────

  Future<List<Reminder>> getReminders({bool includeCompleted = true}) async {
    final filterCounty = _activeCountyId;
    if (_memoryMode) {
      final list = _reminders.values
          .where((r) => !r.deleted && (includeCompleted || !r.isCompleted))
          .where((r) {
            if (filterCounty.isEmpty) return true;
            final m = r.memberId != null ? _members[r.memberId] : null;
            return m != null && m.countyId == filterCounty;
          })
          .toList()
        ..sort(
          (a, b) => a.reminderDateTime.compareTo(b.reminderDateTime),
        );
      return list;
    }
    final whereBuf = StringBuffer('r.deleted = 0');
    final whereArgs = <dynamic>[];
    if (!includeCompleted) whereBuf.write(' AND r.isCompleted = 0');
    if (filterCounty.isNotEmpty) {
      whereBuf.write(
        ' AND r.memberId IS NOT NULL AND m.id = r.memberId AND m.countyId = ?',
      );
      whereArgs.add(filterCounty);
    }
    final rows = filterCounty.isEmpty
        ? await db.query(
            'reminders',
            where: whereBuf.toString(),
            whereArgs: whereArgs.isEmpty ? null : whereArgs,
            orderBy: 'reminderDateTime ASC',
          )
        : await db.rawQuery('''
            SELECT r.* FROM reminders r
            JOIN members m ON m.id = r.memberId
            WHERE ${whereBuf.toString()}
            ORDER BY r.reminderDateTime ASC
          ''', whereArgs);
    return rows.map(Reminder.fromMap).toList();
  }

  @override
  Future<List<Reminder>> getActiveOnboardingReminders() async {
    final all = await getReminders(includeCompleted: false);
    final list = all
        .where(
          (r) =>
              r.isOnboarding &&
              r.status == 'active' &&
              !r.isCompleted &&
              !r.deleted,
        )
        .toList()
      ..sort((a, b) {
        final sa = a.stepNumber ?? 99;
        final sb = b.stepNumber ?? 99;
        if (sa != sb) return sa.compareTo(sb);
        final ea = a.expiryDate ?? a.reminderDateTime;
        final eb = b.expiryDate ?? b.reminderDateTime;
        return ea.compareTo(eb);
      });
    return list;
  }

  Future<List<Reminder>> getActiveRemindersByMember(String memberId) async {
    final all = await getActiveOnboardingReminders();
    return all.where((r) => r.memberId == memberId).toList();
  }

  Future<List<Reminder>> getRemindersByStep(int stepNumber) async {
    final all = await getActiveOnboardingReminders();
    return all.where((r) => r.stepNumber == stepNumber).toList();
  }

  Future<List<Reminder>> getExpiredReminders(DateTime now) async {
    final all = await getActiveOnboardingReminders();
    final clock = now.toUtc();
    return all
        .where((r) => r.expiryDate != null && r.expiryDate!.isBefore(clock))
        .toList();
  }

  Future<int> getActiveOnboardingReminderCount() async {
    final list = await getActiveOnboardingReminders();
    return list.length;
  }

  @override
  Future<Reminder?> getReminderById(String id) async {
    if (_memoryMode) {
      final reminder = _reminders[id];
      if (reminder == null || reminder.deleted) return null;
      return reminder;
    }
    final rows = await db.query(
      'reminders',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Reminder.fromMap(rows.first);
  }

  Future<List<Reminder>> getPendingReminders() async {
    if (_memoryMode) {
      return _reminders.values.where((r) => r.pendingSync).toList();
    }
    final rows = await db.query('reminders', where: 'pendingSync = 1');
    return rows.map(Reminder.fromMap).toList();
  }

  @override
  Future<void> upsertReminder(Reminder reminder) async {
    if (_memoryMode) {
      _reminders[reminder.id] = reminder;
      return;
    }
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteReminder(String id) async {
    if (_memoryMode) {
      final reminder = _reminders[id];
      if (reminder != null) {
        _reminders[id] = reminder.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'reminders',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markReminderSynced(String id) async {
    if (_memoryMode) {
      final reminder = _reminders[id];
      if (reminder != null) {
        _reminders[id] = reminder.copyWith(pendingSync: false);
      }
      return;
    }
    await db.update(
      'reminders',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
