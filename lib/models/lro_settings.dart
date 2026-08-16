import 'package:flutter/foundation.dart';

/// How the 16-digit LRO Recording Number is assembled.
enum LroNumberOrder {
  countyDateUnique('County No. + Payment Date + Unique No.'),
  uniqueDateCounty('Unique No. + Payment Date + County No.'),
  dateCountyUnique('Payment Date + County No. + Unique No.');

  const LroNumberOrder(this.label);
  final String label;
}

/// Admin-configured Land Recovery Office settings.
class LroSettings {
  final String countyUniqueNo; // exactly 3 digits, e.g. "024"
  final String facebookPageUrl; // Facebook page URL for auto-publishing
  final LroNumberOrder numberOrder; // which concatenation order is active
  final String? blueprintPath; // local path or web marker for blank template image
  final String? blueprintBase64; // web base64 fallback for the template
  final String? samplePath; // local path or web marker for sample image
  final String? sampleBase64; // web base64 fallback for the sample

  const LroSettings({
    this.countyUniqueNo = '',
    this.facebookPageUrl = '',
    this.numberOrder = LroNumberOrder.countyDateUnique,
    this.blueprintPath,
    this.blueprintBase64,
    this.samplePath,
    this.sampleBase64,
  });

  bool get hasBlueprint =>
      (blueprintPath != null && blueprintPath!.isNotEmpty) ||
      (blueprintBase64 != null && blueprintBase64!.isNotEmpty);

  bool get hasSample =>
      (samplePath != null && samplePath!.isNotEmpty) ||
      (sampleBase64 != null && sampleBase64!.isNotEmpty);

  bool get hasCountyUniqueNo => countyUniqueNo.trim().length == 3;

  bool get isValidFacebookUrl =>
      facebookPageUrl.trim().isNotEmpty &&
      checkFacebookUrl(facebookPageUrl.trim());

  bool get isComplete =>
      hasCountyUniqueNo &&
      isValidFacebookUrl &&
      hasBlueprint;

  LroSettings copyWith({
    String? countyUniqueNo,
    String? facebookPageUrl,
    LroNumberOrder? numberOrder,
    String? blueprintPath,
    String? blueprintBase64,
    String? samplePath,
    String? sampleBase64,
    bool clearBlueprintPath = false,
    bool clearBlueprintBase64 = false,
    bool clearSamplePath = false,
    bool clearSampleBase64 = false,
  }) {
    return LroSettings(
      countyUniqueNo: countyUniqueNo ?? this.countyUniqueNo,
      facebookPageUrl: facebookPageUrl ?? this.facebookPageUrl,
      numberOrder: numberOrder ?? this.numberOrder,
      blueprintPath:
          clearBlueprintPath ? null : (blueprintPath ?? this.blueprintPath),
      blueprintBase64: clearBlueprintBase64
          ? null
          : (blueprintBase64 ?? this.blueprintBase64),
      samplePath: clearSamplePath ? null : (samplePath ?? this.samplePath),
      sampleBase64:
          clearSampleBase64 ? null : (sampleBase64 ?? this.sampleBase64),
    );
  }

  Map<String, String> toPrefs() => {
        'countyUniqueNo': countyUniqueNo,
        'facebookPageUrl': facebookPageUrl,
        'numberOrder': numberOrder.name,
        'blueprintPath': blueprintPath ?? '',
        'blueprintBase64': blueprintBase64 ?? '',
        'samplePath': samplePath ?? '',
        'sampleBase64': sampleBase64 ?? '',
      };

  factory LroSettings.fromPrefs(Map<String, String> map) {
    final orderName = map['numberOrder'] ?? LroNumberOrder.countyDateUnique.name;
    return LroSettings(
      countyUniqueNo: map['countyUniqueNo'] ?? '',
      facebookPageUrl: map['facebookPageUrl'] ?? '',
      numberOrder: LroNumberOrder.values.firstWhere(
        (o) => o.name == orderName,
        orElse: () => LroNumberOrder.countyDateUnique,
      ),
      blueprintPath: (map['blueprintPath'] ?? '').isEmpty ? null : map['blueprintPath'],
      blueprintBase64:
          (map['blueprintBase64'] ?? '').isEmpty ? null : map['blueprintBase64'],
      samplePath: (map['samplePath'] ?? '').isEmpty ? null : map['samplePath'],
      sampleBase64:
          (map['sampleBase64'] ?? '').isEmpty ? null : map['sampleBase64'],
    );
  }

  /// Validates a Facebook URL string.
  /// Accepts facebook.com/PageName, www.facebook.com/PageName,
  /// m.facebook.com/PageName, fb.com/PageName.
  static bool checkFacebookUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (!lower.contains('facebook.com') && !lower.contains('fb.com')) {
      return false;
    }
    // Must start with a scheme or www.
    if (!lower.startsWith('http://') &&
        !lower.startsWith('https://') &&
        !lower.startsWith('www.')) {
      return false;
    }
    // Reject personal profile URLs that contain /profile.php or /posts/
    if (lower.contains('/profile.php') || lower.contains('/posts/')) {
      return false;
    }
    return true;
  }

  @override
  String toString() =>
      'LroSettings(countyUniqueNo=$countyUniqueNo, order=${numberOrder.name}, '
      'hasBlueprint=${hasBlueprint}, hasFacebook=${facebookPageUrl.isNotEmpty})';
}