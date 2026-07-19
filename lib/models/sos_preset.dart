import 'package:uuid/uuid.dart';

class SosPreset {
  final String id;
  final String title;
  final String message;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const SosPreset({
    required this.id,
    required this.title,
    required this.message,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  factory SosPreset.create({
    required String title,
    required String message,
  }) {
    return SosPreset(
      id: const Uuid().v4(),
      title: title.trim(),
      message: message.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  SosPreset copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return SosPreset(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'updatedAt': updatedAt.toIso8601String(),
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'updatedAt': updatedAt.toIso8601String(),
      'deleted': deleted,
    };
  }

  factory SosPreset.fromMap(Map<String, dynamic> map) {
    return SosPreset(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  factory SosPreset.fromFirestore(Map<String, dynamic> map) {
    return SosPreset(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
    );
  }
}
