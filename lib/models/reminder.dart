import 'package:uuid/uuid.dart';

class Reminder {
  final String id;
  final String? firestoreId;
  final String memberId;
  final String createdBy;
  final String title;
  final String description;
  final DateTime reminderDateTime;
  final String priority; // High | Medium | Low
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

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
  });

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
      };

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      memberId: map['memberId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      reminderDateTime:
          DateTime.tryParse(map['reminderDateTime'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      priority: map['priority'] as String? ?? 'Medium',
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1 ||
          map['isCompleted'] == true,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1 ||
          map['pendingSync'] == true,
      deleted:
          (map['deleted'] as int? ?? 0) == 1 || map['deleted'] == true,
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
