import 'package:flutter/foundation.dart';

/// Admin-managed Garden Town County branding / identity.
class CountyProfile {
  final String countyName;
  final String countyAddress;
  final String countyRegNo;
  final String countyContactNo;
  /// Absolute path to uploaded primary logo (desktop/mobile), or null.
  final String? logoPath;
  /// Absolute path to optional secondary logo, or null (defaults to primary).
  final String? secondaryLogoPath;

  const CountyProfile({
    this.countyName = 'Garden Town County',
    this.countyAddress = '',
    this.countyRegNo = '',
    this.countyContactNo = '',
    this.logoPath,
    this.secondaryLogoPath,
  });

  CountyProfile copyWith({
    String? countyName,
    String? countyAddress,
    String? countyRegNo,
    String? countyContactNo,
    String? logoPath,
    String? secondaryLogoPath,
    bool clearLogoPath = false,
    bool clearSecondaryLogoPath = false,
  }) {
    return CountyProfile(
      countyName: countyName ?? this.countyName,
      countyAddress: countyAddress ?? this.countyAddress,
      countyRegNo: countyRegNo ?? this.countyRegNo,
      countyContactNo: countyContactNo ?? this.countyContactNo,
      logoPath: clearLogoPath ? null : (logoPath ?? this.logoPath),
      secondaryLogoPath: clearSecondaryLogoPath
          ? null
          : (secondaryLogoPath ?? this.secondaryLogoPath),
    );
  }

  Map<String, String?> toPrefs() => {
        'countyName': countyName,
        'countyAddress': countyAddress,
        'countyRegNo': countyRegNo,
        'countyContactNo': countyContactNo,
        'logoPath': logoPath,
        'secondaryLogoPath': secondaryLogoPath,
      };

  factory CountyProfile.fromPrefs(Map<String, String?> map) {
    return CountyProfile(
      countyName: map['countyName']?.trim().isNotEmpty == true
          ? map['countyName']!.trim()
          : 'Garden Town County',
      countyAddress: map['countyAddress'] ?? '',
      countyRegNo: map['countyRegNo'] ?? '',
      countyContactNo: map['countyContactNo'] ?? '',
      logoPath: map['logoPath'],
      secondaryLogoPath: map['secondaryLogoPath'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountyProfile &&
          countyName == other.countyName &&
          countyAddress == other.countyAddress &&
          countyRegNo == other.countyRegNo &&
          countyContactNo == other.countyContactNo &&
          logoPath == other.logoPath &&
          secondaryLogoPath == other.secondaryLogoPath;

  @override
  int get hashCode => Object.hash(
        countyName,
        countyAddress,
        countyRegNo,
        countyContactNo,
        logoPath,
        secondaryLogoPath,
      );

  @override
  String toString() =>
      'CountyProfile($countyName, web=${kIsWeb}, logo=$logoPath)';
}
