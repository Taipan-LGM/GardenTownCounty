import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Onboarding step numbers shown on active reminders.
class ReminderStep {
  static const int step1MemberInfo = 1;
  static const int step2Global528 = 2;
  static const int step3Global928 = 3;
  static const int step4LRO = 4;

  static String getDescription(int step) {
    switch (step) {
      case 1:
        return 'Member Info';
      case 2:
        return 'Global 528';
      case 3:
        return 'Global 928';
      case 4:
        return 'LRO';
      default:
        return 'Unknown';
    }
  }

  /// FINAL palette: 1 red, 2 orange, 3 blue, 4 green.
  static Color getColor(int step) {
    switch (step) {
      case 1:
        return Colors.red.shade700;
      case 2:
        return Colors.orange.shade800;
      case 3:
        return Colors.blue.shade700;
      case 4:
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  static IconData getIcon(int step) {
    switch (step) {
      case 1:
        return Icons.person;
      case 2:
        return Icons.numbers;
      case 3:
        return Icons.numbers;
      case 4:
        return Icons.gavel;
      default:
        return Icons.help_outline;
    }
  }

  static String getEmoji(int step) {
    switch (step) {
      case 1:
        return '🔴';
      case 2:
        return '🟠';
      case 3:
        return '🔵';
      case 4:
        return '🟢';
      default:
        return '⚪';
    }
  }
}

/// Manual calendar reminder or automated onboarding step tracker.
class Reminder {
  final String id;
  final String? firestoreId;
  final String memberId;
  final String createdBy;
  final String title;
  final String description;
  final DateTime reminderDateTime;
  final String priority; // High | Medium | Low (manual)
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  /// `manual` | `onboarding`
  final String kind;
  final int? stepNumber;
  final String? stepDescription;
  final String? memberName;
  final String? surname;
  final String? saId;
  final DateTime? expiryDate;
  /// `active` | `completed` | `expired`
  final String status;
  final DateTime? completedDate;
  final String? completedBy;

  const Reminder({
    required this.id,
    this.firestoreId,
    required this.memberId,
    required this.createdBy,
    required this.title,
    this.description = '',
    required this.reminderDateTime,
    this.priority = 'Medium',
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
    this.kind = 'manual',
    this.stepNumber,
    this.stepDescription,
    this.memberName,
    this.surname,
    this.saId,
    this.expiryDate,
    this.status = 'active',
    this.completedDate,
    this.completedBy,
  });

  bool get isOnboarding => kind == 'onboarding';
  bool get isActive => status == 'active' && !isCompleted && !deleted;

  String get displayName {
    final n = memberName?.trim() ?? '';
    final s = surname?.trim() ?? '';
    if (n.isEmpty && s.isEmpty) return title;
    return '$n $s'.trim();
  }

  Duration? get timeRemaining {
    final exp = expiryDate;
    if (exp == null) return null;
    return exp.difference(DateTime.now().toUtc());
  }

  bool get isUrgent {
    final rem = timeRemaining;
    if (rem == null) return false;
    return rem.inHours < 6;
  }

  factory Reminder.create({
    required String memberId,
    required String createdBy,
    required String title,
    String description = '',
    required DateTime reminderDateTime,
    String priority = 'Medium',
  }) {
    final now = DateTime.now().toUtc();
    return Reminder(
      id: const Uuid().v4(),
      memberId: memberId,
      createdBy: createdBy,
      title: title.trim(),
      description: description.trim(),
      reminderDateTime: reminderDateTime.toUtc(),
      priority: priority,
      createdAt: now,
      updatedAt: now,
      kind: 'manual',
      status: 'active',
    );
  }

  factory Reminder.createOnboarding({
    required String memberId,
    required String memberName,
    required String surname,
    required String saId,
    required int stepNumber,
    String createdBy = 'system',
  }) {
    final now = DateTime.now().toUtc();
    final desc = ReminderStep.getDescription(stepNumber);
    final expiry = now.add(const Duration(hours: 24));
    return Reminder(
      id: const Uuid().v4(),
      memberId: memberId,
      createdBy: createdBy,
      title: 'Step $stepNumber: $desc',
      description: 'Onboarding reminder — $desc',
      reminderDateTime: expiry,
      priority: stepNumber == 1 ? 'High' : 'Medium',
      createdAt: now,
      updatedAt: now,
      kind: 'onboarding',
      stepNumber: stepNumber,
      stepDescription: desc,
      memberName: memberName,
      surname: surname,
      saId: saId,
      expiryDate: expiry,
      status: 'active',
    );
  }

  Reminder copyWith({
    String? id,
    String? firestoreId,
    String? memberId,
    String? createdBy,
    String? title,
    String? description,
    DateTime? reminderDateTime,
    String? priority,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    String? kind,
    int? stepNumber,
    String? stepDescription,
    String? memberName,
    String? surname,
    String? saId,
    DateTime? expiryDate,
    String? status,
    DateTime? completedDate,
    String? completedBy,
    bool clearCompleted = false,
  }) {
    return Reminder(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      memberId: memberId ?? this.memberId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
      kind: kind ?? this.kind,
      stepNumber: stepNumber ?? this.stepNumber,
      stepDescription: stepDescription ?? this.stepDescription,
      memberName: memberName ?? this.memberName,
      surname: surname ?? this.surname,
      saId: saId ?? this.saId,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      completedDate:
          clearCompleted ? null : (completedDate ?? this.completedDate),
      completedBy: clearCompleted ? null : (completedBy ?? this.completedBy),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'memberId': memberId,
        'createdBy': createdBy,
        'title': title,
        'description': description,
        'reminderDateTime': reminderDateTime.toIso8601String(),
        'priority': priority,
        'isCompleted': isCompleted ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pendingSync': pendingSync ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'kind': kind,
        'stepNumber': stepNumber,
        'stepDescription': stepDescription,
        'memberName': memberName,
        'surname': surname,
        'saId': saId,
        'expiryDate': expiryDate?.toIso8601String(),
        'status': status,
        'completedDate': completedDate?.toIso8601String(),
        'completedBy': completedBy,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'firestoreId': firestoreId ?? id,
        'memberId': memberId,
        'createdBy': createdBy,
        'title': title,
        'description': description,
        'reminderDateTime': reminderDateTime.toIso8601String(),
        'priority': priority,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
        'kind': kind,
        'stepNumber': stepNumber,
        'stepDescription': stepDescription,
        'memberName': memberName,
        'surname': surname,
        'saId': saId,
        'expiryDate': expiryDate?.toIso8601String(),
        'status': status,
        'completedDate': completedDate?.toIso8601String(),
        'completedBy': completedBy,
      };

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    final expiry = _asDate(map['expiryDate']);
    final reminderDt = _asDate(map['reminderDateTime']) ??
        expiry ??
        DateTime.now().toUtc();
    return Reminder(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      memberId: map['memberId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      reminderDateTime: reminderDt,
      priority: map['priority'] as String? ?? 'Medium',
      isCompleted: _asBool(map['isCompleted']),
      createdAt: _asDate(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _asDate(map['updatedAt']) ?? DateTime.now().toUtc(),
      pendingSync: _asBool(map['pendingSync']),
      deleted: _asBool(map['deleted']),
      kind: map['kind'] as String? ?? 'manual',
      stepNumber: map['stepNumber'] is int
          ? map['stepNumber'] as int
          : int.tryParse('${map['stepNumber'] ?? ''}'),
      stepDescription: map['stepDescription'] as String?,
      memberName: map['memberName'] as String?,
      surname: map['surname'] as String?,
      saId: map['saId'] as String?,
      expiryDate: expiry,
      status: map['status'] as String? ??
          (_asBool(map['isCompleted']) ? 'completed' : 'active'),
      completedDate: _asDate(map['completedDate']),
      completedBy: map['completedBy'] as String?,
    );
  }

  factory Reminder.fromFirestore(Map<String, dynamic> map) {
    return Reminder.fromMap({
      ...map,
      'pendingSync': 0,
      'isCompleted': map['isCompleted'] == true || map['isCompleted'] == 1
          ? 1
          : 0,
      'deleted': map['deleted'] == true || map['deleted'] == 1 ? 1 : 0,
    });
  }
}

class ReminderStats {
  const ReminderStats({
    required this.total,
    required this.step1,
    required this.step2,
    required this.step3,
    required this.step4,
  });

  final int total;
  final int step1;
  final int step2;
  final int step3;
  final int step4;
}
