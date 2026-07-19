import 'package:uuid/uuid.dart';

class ActivityLog {
  final String id;
  final String userName;
  final String action;
  final DateTime occurredAt;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final bool pendingSync;

  const ActivityLog({
    required this.id,
    required this.userName,
    required this.action,
    required this.occurredAt,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.pendingSync = true,
  });

  factory ActivityLog.create({
    required String userName,
    required String action,
    double? latitude,
    double? longitude,
    String? locationLabel,
  }) {
    return ActivityLog(
      id: const Uuid().v4(),
      userName: userName,
      action: action,
      occurredAt: DateTime.now().toUtc(),
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userName': userName,
      'action': action,
      'occurredAt': occurredAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationLabel': locationLabel,
      'pendingSync': pendingSync ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userName': userName,
      'action': action,
      'occurredAt': occurredAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationLabel': locationLabel,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as String,
      userName: map['userName'] as String? ?? '',
      action: map['action'] as String? ?? '',
      occurredAt: DateTime.tryParse(map['occurredAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationLabel: map['locationLabel'] as String?,
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
    );
  }

  factory ActivityLog.fromFirestore(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as String,
      userName: map['userName'] as String? ?? '',
      action: map['action'] as String? ?? '',
      occurredAt: DateTime.tryParse(map['occurredAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationLabel: map['locationLabel'] as String?,
      pendingSync: false,
    );
  }
}
