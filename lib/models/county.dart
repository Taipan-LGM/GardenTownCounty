import 'package:flutter/foundation.dart';

/// A County is the platform tier in CountyConnect. Every operational record
/// (members, payments, LRO, settings) belongs to exactly one County.
///
/// The original "Garden Town County" data is migrated into the first seeded
/// County row so existing users and data are preserved (no account recreation).
class County {
  final String id;
  final String countyName;
  final String countyAddress;
  final String countyContactNo;
  final String countyEmail;
  final String countyRegistrationNo;
  final String facebookUrl;
  final String uniqueNumber; // 3-digit code, unique across ALL counties

  /// Absolute path to uploaded primary logo (desktop/mobile), or null.
  final String? logoPath;

  /// Absolute path to optional secondary / corner logo, or null.
  final String? secondaryLogoPath;

  /// Absolute path to the official county seal (Public Notices), or null.
  final String? sealPath;

  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const County({
    required this.id,
    required this.countyName,
    this.countyAddress = '',
    this.countyContactNo = '',
    this.countyEmail = '',
    this.countyRegistrationNo = '',
    this.facebookUrl = '',
    this.uniqueNumber = '',
    this.logoPath,
    this.secondaryLogoPath,
    this.sealPath,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  County copyWith({
    String? id,
    String? countyName,
    String? countyAddress,
    String? countyContactNo,
    String? countyEmail,
    String? countyRegistrationNo,
    String? facebookUrl,
    String? uniqueNumber,
    String? logoPath,
    String? secondaryLogoPath,
    String? sealPath,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool clearLogoPath = false,
    bool clearSecondaryLogoPath = false,
    bool clearSealPath = false,
  }) {
    return County(
      id: id ?? this.id,
      countyName: countyName ?? this.countyName,
      countyAddress: countyAddress ?? this.countyAddress,
      countyContactNo: countyContactNo ?? this.countyContactNo,
      countyEmail: countyEmail ?? this.countyEmail,
      countyRegistrationNo:
          countyRegistrationNo ?? this.countyRegistrationNo,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      uniqueNumber: uniqueNumber ?? this.uniqueNumber,
      logoPath: clearLogoPath ? null : (logoPath ?? this.logoPath),
      secondaryLogoPath:
          clearSecondaryLogoPath ? null : (secondaryLogoPath ?? this.secondaryLogoPath),
      sealPath: clearSealPath ? null : (sealPath ?? this.sealPath),
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'countyName': countyName,
        'countyAddress': countyAddress,
        'countyContactNo': countyContactNo,
        'countyEmail': countyEmail,
        'countyRegistrationNo': countyRegistrationNo,
        'facebookUrl': facebookUrl,
        'uniqueNumber': uniqueNumber,
        'logoPath': logoPath,
        'secondaryLogoPath': secondaryLogoPath,
        'sealPath': sealPath,
        'isDefault': isDefault ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted ? 1 : 0,
      };

  factory County.fromMap(Map<String, dynamic> map) {
    return County(
      id: map['id'] as String,
      countyName: map['countyName'] as String? ?? '',
      countyAddress: map['countyAddress'] as String? ?? '',
      countyContactNo: map['countyContactNo'] as String? ?? '',
      countyEmail: map['countyEmail'] as String? ?? '',
      countyRegistrationNo: map['countyRegistrationNo'] as String? ?? '',
      facebookUrl: map['facebookUrl'] as String? ?? '',
      uniqueNumber: map['uniqueNumber'] as String? ?? '',
      logoPath: map['logoPath'] as String?,
      secondaryLogoPath: map['secondaryLogoPath'] as String?,
      sealPath: map['sealPath'] as String?,
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }
}
