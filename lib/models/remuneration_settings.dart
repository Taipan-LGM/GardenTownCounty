import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Configurable RS step amounts + extra services.
///
/// // NEW ADDITION - Delete this file to revert RS remuneration settings model.
class RemunerationSettings {
  static const String defaultStep1Name = 'Step 1_Global 528';
  static const String defaultStep2Name = 'Step 2_Global 528';
  static const String defaultStep3Name = 'Step 3_Global 928';
  static const String defaultStep4Name = 'Step 4_LRO';
  static const String defaultStep5Name = 'Step 5_Credential Card';

  final String id;
  final String? firestoreId;
  final String step1Name;
  final String step2Name;
  final String step3Name;
  final String step4Name;
  final String step5Name;
  final double step1Amount;
  final double step2Amount;
  final double step3Amount;
  final double step4Amount;
  final double step5Amount;
  final List<RemunerationStep> steps;
  final String bankAccountName;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountCode;
  final List<ExtraService> extraServices;
  final DateTime lastUpdated;
  final String syncStatus;

  const RemunerationSettings({
    required this.id,
    this.firestoreId,
    this.step1Name = defaultStep1Name,
    this.step2Name = defaultStep2Name,
    this.step3Name = defaultStep3Name,
    this.step4Name = defaultStep4Name,
    this.step5Name = defaultStep5Name,
    this.step1Amount = 100,
    this.step2Amount = 200,
    this.step3Amount = 300,
    this.step4Amount = 250,
    this.step5Amount = 250,
    this.steps = const [],
    this.bankAccountName = 'Garden Town County',
    this.bankName = 'Capitec Bank',
    this.bankAccountNumber = '',
    this.bankAccountCode = '',
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
    String? step1Name,
    String? step2Name,
    String? step3Name,
    String? step4Name,
    String? step5Name,
    double? step1Amount,
    double? step2Amount,
    double? step3Amount,
    double? step4Amount,
    double? step5Amount,
    List<RemunerationStep>? steps,
    String? bankAccountName,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountCode,
    List<ExtraService>? extraServices,
    DateTime? lastUpdated,
    String? syncStatus,
  }) {
    return RemunerationSettings(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      step1Name: step1Name ?? this.step1Name,
      step2Name: step2Name ?? this.step2Name,
      step3Name: step3Name ?? this.step3Name,
      step4Name: step4Name ?? this.step4Name,
      step5Name: step5Name ?? this.step5Name,
      step1Amount: step1Amount ?? this.step1Amount,
      step2Amount: step2Amount ?? this.step2Amount,
      step3Amount: step3Amount ?? this.step3Amount,
      step4Amount: step4Amount ?? this.step4Amount,
      step5Amount: step5Amount ?? this.step5Amount,
      steps: steps ?? this.steps,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountCode: bankAccountCode ?? this.bankAccountCode,
      extraServices: extraServices ?? this.extraServices,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'step1Name': step1Name,
    'step2Name': step2Name,
    'step3Name': step3Name,
    'step4Name': step4Name,
    'step5Name': step5Name,
    'step1Amount': step1Amount,
    'step2Amount': step2Amount,
    'step3Amount': step3Amount,
    'step4Amount': step4Amount,
    'step5Amount': step5Amount,
    'stepsJson': RemunerationStep.encodeList(allSteps),
    'bankAccountName': bankAccountName,
    'bankName': bankName,
    'bankAccountNumber': bankAccountNumber,
    'bankAccountCode': bankAccountCode,
    'extraServicesJson': ExtraService.encodeList(extraServices),
    'lastUpdated': lastUpdated.toIso8601String(),
    'syncStatus': syncStatus,
  };

  factory RemunerationSettings.fromMap(Map<String, dynamic> map) {
    return RemunerationSettings(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      step1Name: map['step1Name'] as String? ?? defaultStep1Name,
      step2Name: map['step2Name'] as String? ?? defaultStep2Name,
      step3Name: map['step3Name'] as String? ?? defaultStep3Name,
      step4Name: map['step4Name'] as String? ?? defaultStep4Name,
      step5Name: map['step5Name'] as String? ?? defaultStep5Name,
      step1Amount: (map['step1Amount'] as num?)?.toDouble() ?? 100,
      step2Amount: (map['step2Amount'] as num?)?.toDouble() ?? 200,
      step3Amount: (map['step3Amount'] as num?)?.toDouble() ?? 300,
      step4Amount: (map['step4Amount'] as num?)?.toDouble() ?? 250,
      step5Amount: (map['step5Amount'] as num?)?.toDouble() ?? 250,
      steps: RemunerationStep.decodeList(map['stepsJson'] as String? ?? '[]'),
      bankAccountName:
          map['bankAccountName'] as String? ?? 'Garden Town County',
      bankName: map['bankName'] as String? ?? 'Capitec Bank',
      bankAccountNumber: map['bankAccountNumber'] as String? ?? '',
      bankAccountCode: map['bankAccountCode'] as String? ?? '',
      extraServices: ExtraService.decodeList(
        map['extraServicesJson'] as String? ?? '[]',
      ),
      lastUpdated:
          DateTime.tryParse(map['lastUpdated'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      syncStatus: map['syncStatus'] as String? ?? 'pending',
    );
  }

  List<RemunerationStep> get allSteps => steps.isNotEmpty
      ? List.unmodifiable(steps)
      : [
          RemunerationStep(number: 1, name: step1Name, amount: step1Amount),
          RemunerationStep(number: 2, name: step2Name, amount: step2Amount),
          RemunerationStep(number: 3, name: step3Name, amount: step3Amount),
          RemunerationStep(number: 4, name: step4Name, amount: step4Amount),
          RemunerationStep(number: 5, name: step5Name, amount: step5Amount),
        ];

  List<RemunerationStep> get configuredSteps =>
      allSteps.where((step) => step.active).toList(growable: false);

  RemunerationStep? step(int stepNumber) {
    for (final step in allSteps) {
      if (step.number == stepNumber) return step;
    }
    return null;
  }

  String stepName(int stepNumber) =>
      step(stepNumber)?.name ?? 'Step $stepNumber';

  double stepAmount(int stepNumber) => step(stepNumber)?.amount ?? 0.0;

  double get configuredTotalAmount =>
      configuredSteps.fold<double>(0, (total, step) => total + step.amount);

  int get nextStepNumber =>
      allSteps.fold<int>(
        0,
        (highest, step) => step.number > highest ? step.number : highest,
      ) +
      1;
}

class RemunerationStep {
  const RemunerationStep({
    required this.number,
    required this.name,
    required this.amount,
    this.active = true,
  });

  final int number;
  final String name;
  final double amount;
  final bool active;

  RemunerationStep copyWith({String? name, double? amount, bool? active}) {
    return RemunerationStep(
      number: number,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'amount': amount,
    'active': active,
  };

  factory RemunerationStep.fromJson(Map<String, dynamic> json) {
    return RemunerationStep(
      number: (json['number'] as num).toInt(),
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      active: json['active'] as bool? ?? true,
    );
  }

  static String encodeList(List<RemunerationStep> steps) =>
      jsonEncode(steps.map((step) => step.toJson()).toList());

  static List<RemunerationStep> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => RemunerationStep.fromJson(item as Map<String, dynamic>),
          )
          .where((step) => step.number > 0 && step.name.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));
    } catch (_) {
      return const [];
    }
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
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
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
