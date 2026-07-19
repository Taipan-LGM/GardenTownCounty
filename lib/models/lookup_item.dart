import 'package:uuid/uuid.dart';

enum LookupType { suburb, townCity, postalCode }

extension LookupTypeX on LookupType {
  String get storageKey {
    switch (this) {
      case LookupType.suburb:
        return 'suburb';
      case LookupType.townCity:
        return 'townCity';
      case LookupType.postalCode:
        return 'postalCode';
    }
  }

  String get label {
    switch (this) {
      case LookupType.suburb:
        return 'Suburb';
      case LookupType.townCity:
        return 'Town / City';
      case LookupType.postalCode:
        return 'Postal Code';
    }
  }

  static LookupType fromStorage(String value) {
    switch (value) {
      case 'townCity':
        return LookupType.townCity;
      case 'postalCode':
        return LookupType.postalCode;
      default:
        return LookupType.suburb;
    }
  }
}

class LookupItem {
  final String id;
  final LookupType type;
  final String value;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const LookupItem({
    required this.id,
    required this.type,
    required this.value,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  factory LookupItem.create({
    required LookupType type,
    required String value,
  }) {
    return LookupItem(
      id: const Uuid().v4(),
      type: type,
      value: value.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  LookupItem copyWith({
    String? id,
    LookupType? type,
    String? value,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return LookupItem(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.storageKey,
      'value': value,
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type.storageKey,
      'value': value,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
    };
  }

  factory LookupItem.fromMap(Map<String, dynamic> map) {
    return LookupItem(
      id: map['id'] as String,
      type: LookupTypeX.fromStorage(map['type'] as String? ?? 'suburb'),
      value: map['value'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  factory LookupItem.fromFirestore(Map<String, dynamic> map) {
    return LookupItem(
      id: map['id'] as String,
      type: LookupTypeX.fromStorage(map['type'] as String? ?? 'suburb'),
      value: map['value'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
    );
  }
}
