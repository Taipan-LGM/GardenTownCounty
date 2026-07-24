import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Configurable RS step amounts + extra services.
///
/// // NEW ADDITION - Delete this file to revert RS remuneration settings model.
class RemunerationSettings {
  final String id;
  final String? firestoreId;
  final double step2Amount;
  final double step3Amount;
  final double step4Amount;
  final List<ExtraService> extraServices;
  final DateTime lastUpdated;
  final String syncStatus;

  const RemunerationSettings({
    required this.id,
    this.firestoreId,
    this.step2Amount = 200,
    this.step3Amount = 300,
    this.step4Amount = 250,
    this.extraServices = const [],
    required this.lastUpdated,
    this.syncStatus = 'pending',
  });

  factory RemunerationSettings.defaults() {
    return RemunerationSettings(
      id: const Uuid().v4(),
      lastUpdated: DateTime.now().toUtc(),
    );
  }

  RemunerationSettings copyWith({
    String? id,
    String? firestoreId,
    double? step2Amount,
    double? step3Amount,
    double? step4Amount,
    List<ExtraService>? extraServices,
    DateTime? lastUpdated,
    String? syncStatus,
  }) {
    return RemunerationSettings(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      step2Amount: step2Amount ?? this.step2Amount,
      step3Amount: step3Amount ?? this.step3Amount,
      step4Amount: step4Amount ?? this.step4Amount,
      extraServices: extraServices ?? this.extraServices,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'step2Amount': step2Amount,
        'step3Amount': step3Amount,
        'step4Amount': step4Amount,
        'extraServicesJson': ExtraService.encodeList(extraServices),
        'lastUpdated': lastUpdated.toIso8601String(),
        'syncStatus': syncStatus,
      };

  factory RemunerationSettings.fromMap(Map<String, dynamic> map) {
    return RemunerationSettings(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      step2Amount: (map['step2Amount'] as num?)?.toDouble() ?? 200,
      step3Amount: (map['step3Amount'] as num?)?.toDouble() ?? 300,
      step4Amount: (map['step4Amount'] as num?)?.toDouble() ?? 250,
      extraServices: ExtraService.decodeList(
        map['extraServicesJson'] as String? ?? '[]',
      ),
      lastUpdated: DateTime.tryParse(map['lastUpdated'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      syncStatus: map['syncStatus'] as String? ?? 'pending',
    );
  }
}

/// Extra billable service line for RS remuneration settings.
///
/// // NEW ADDITION - Delete with remuneration_settings.dart to revert.
class ExtraService {
  final String id;
  final String description;
  final double amount;
  final bool isActive;
  final DateTime createdAt;

  const ExtraService({
    required this.id,
    required this.description,
    required this.amount,
    this.isActive = true,
    required this.createdAt,
  });

  ExtraService copyWith({
    String? id,
    String? description,
    double? amount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ExtraService(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExtraService.fromJson(Map<String, dynamic> json) {
    return ExtraService(
      id: json['id'] as String? ?? const Uuid().v4(),
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  static String encodeList(List<ExtraService> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<ExtraService> decodeList(String raw) {
    if (raw.trim().isEmpty || raw.trim() == '[]') return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ExtraService.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
