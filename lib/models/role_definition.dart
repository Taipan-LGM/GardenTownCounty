import 'package:uuid/uuid.dart';

/// Rights / Role definition managed from Add User (Add / Edit / Delete).
class RoleDefinition {
  final String id;
  final String name;
  final bool isSystem;
  final bool grantsAdmin;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const RoleDefinition({
    required this.id,
    required this.name,
    this.isSystem = false,
    this.grantsAdmin = false,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  factory RoleDefinition.create({
    required String name,
    bool grantsAdmin = false,
    bool isSystem = false,
  }) {
    return RoleDefinition(
      id: const Uuid().v4(),
      name: name.trim(),
      grantsAdmin: grantsAdmin,
      isSystem: isSystem,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  RoleDefinition copyWith({
    String? id,
    String? name,
    bool? isSystem,
    bool? grantsAdmin,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return RoleDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      isSystem: isSystem ?? this.isSystem,
      grantsAdmin: grantsAdmin ?? this.grantsAdmin,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  bool get isAdminRole =>
      grantsAdmin || name.trim().toLowerCase() == 'admin';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isSystem': isSystem ? 1 : 0,
      'grantsAdmin': grantsAdmin ? 1 : 0,
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'isSystem': isSystem,
      'grantsAdmin': grantsAdmin,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
    };
  }

  factory RoleDefinition.fromMap(Map<String, dynamic> map) {
    return RoleDefinition(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      isSystem: (map['isSystem'] as int? ?? 0) == 1,
      grantsAdmin: (map['grantsAdmin'] as int? ?? 0) == 1,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  factory RoleDefinition.fromFirestore(Map<String, dynamic> map) {
    return RoleDefinition(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      isSystem: map['isSystem'] as bool? ?? false,
      grantsAdmin: map['grantsAdmin'] as bool? ?? false,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
    );
  }
}
