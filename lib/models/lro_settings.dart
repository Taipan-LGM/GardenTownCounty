import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:flutter/foundation.dart';
import 'lro_settings_options.dart';
import 'lro_status_correction.dart' as sc;
import 'lro_notice_template.dart';
export 'lro_settings_options.dart';

/// Admin-configured Land Recording Office settings.
class LroSettings {
  final String countyUniqueNo; // exactly 3 digits, e.g. "024"
  final String facebookPageUrl; // Facebook page URL for auto-publishing
  final LroNumberOrder numberOrder;
  final String? publicNoticeTemplatePath; // local path or web marker for the template image
  final String? publicNoticeTemplateBase64; // web base64 fallback for the template
  final String? countySealPath; // local path or web marker for the seal image
  final String? countySealBase64; // web base64 fallback for the seal
  final List<sc.LroStatusCorrection> statusCorrections; // dynamic 528 descriptions
  final LroNoticeTemplateStyle? noticeTemplate; // parametric Public Notice style

  const LroSettings({
    this.countyUniqueNo = '',
    this.facebookPageUrl = '',
    this.numberOrder = LroNumberOrder.countyDateUnique,
    this.publicNoticeTemplatePath,
    this.publicNoticeTemplateBase64,
    this.countySealPath,
    this.countySealBase64,
    this.statusCorrections = const [],
    this.noticeTemplate,
  });

  bool get hasPublicNoticeTemplate =>
      ((publicNoticeTemplatePath != null &&
                  publicNoticeTemplatePath!.isNotEmpty) ||
              (publicNoticeTemplateBase64 != null &&
                  publicNoticeTemplateBase64!.isNotEmpty)) ||
      noticeTemplate != null;

  bool get hasCountySeal =>
      (countySealPath != null && countySealPath!.isNotEmpty) ||
      (countySealBase64 != null && countySealBase64!.isNotEmpty);

  bool get hasCountyUniqueNo => countyUniqueNo.trim().length == 3;

  bool get isValidFacebookUrl =>
      facebookPageUrl.trim().isNotEmpty && checkFacebookUrl(facebookPageUrl.trim());

  bool get isComplete =>
      hasCountyUniqueNo && isValidFacebookUrl && hasPublicNoticeTemplate;

  /// Whether the status corrections list is still the first-run defaults.
  bool get isFirstRunStatusCorrections =>
      statusCorrections.length == sc.kDefaultStatusCorrections.length &&
      statusCorrections
          .every((c) => c.description == sc.kDefaultStatusCorrections[
              sc.kDefaultStatusCorrections.indexOf(c.description)] &&
              c.isChecked);

  LroSettings copyWith({
    String? countyUniqueNo,
    String? facebookPageUrl,
    LroNumberOrder? numberOrder,
    String? publicNoticeTemplatePath,
    String? publicNoticeTemplateBase64,
    String? countySealPath,
    String? countySealBase64,
    List<sc.LroStatusCorrection>? statusCorrections,
    LroNoticeTemplateStyle? noticeTemplate,
    bool clearPublicNoticeTemplatePath = false,
    bool clearPublicNoticeTemplateBase64 = false,
    bool clearCountySealPath = false,
    bool clearCountySealBase64 = false,
  }) {
    return LroSettings(
      countyUniqueNo: countyUniqueNo ?? this.countyUniqueNo,
      facebookPageUrl: facebookPageUrl ?? this.facebookPageUrl,
      numberOrder: numberOrder ?? this.numberOrder,
      publicNoticeTemplatePath: clearPublicNoticeTemplatePath
          ? null
          : (publicNoticeTemplatePath ?? this.publicNoticeTemplatePath),
      publicNoticeTemplateBase64: clearPublicNoticeTemplateBase64
          ? null
          : (publicNoticeTemplateBase64 ?? this.publicNoticeTemplateBase64),
      countySealPath: clearCountySealPath
          ? null
          : (countySealPath ?? this.countySealPath),
      countySealBase64: clearCountySealBase64
          ? null
          : (countySealBase64 ?? this.countySealBase64),
      statusCorrections: statusCorrections ?? this.statusCorrections,
      noticeTemplate: noticeTemplate ?? this.noticeTemplate,
    );
  }

  /// Validates the status corrections list for save: every row must have a
  /// non-empty description.
  Map<int, String> validateStatusCorrections() {
    final errors = <int, String>{};
    for (var i = 0; i < statusCorrections.length; i++) {
      if (statusCorrections[i].description.trim().isEmpty) {
        errors[i] = 'Description is required.';
      }
    }
    return errors;
  }

  static Map<String, dynamic> encodeJson(List<sc.LroStatusCorrection> corrections) {
    return {
      'items': corrections.map((c) => c.toJson()).toList(),
    };
  }

  static List<sc.LroStatusCorrection> decodeJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) return const [];
    try {
      return items
          .whereType<Map>()
          .map((m) => sc.LroStatusCorrection.fromJson(
              Map<String, dynamic>.from(m)))
          .where((c) => c.description.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> toPrefs() => {
        'countyUniqueNo': countyUniqueNo,
        'facebookPageUrl': facebookPageUrl,
        'numberOrder': numberOrder.name,
        'publicNoticeTemplatePath': publicNoticeTemplatePath ?? '',
        'publicNoticeTemplateBase64': publicNoticeTemplateBase64 ?? '',
        'countySealPath': countySealPath ?? '',
        'countySealBase64': countySealBase64 ?? '',
        'statusCorrectionsJson': jsonEncode(
            statusCorrections.map((c) => c.toJson()).toList()),
        'noticeTemplateJson': encodeNoticeTemplate(noticeTemplate) ?? '',
      };

  factory LroSettings.fromPrefs(Map<String, String> map) {
    final correctionsJson = map['statusCorrectionsJson'] ??
        jsonEncode(sc.kDefaultStatusCorrections.map((d) => {
              'description': d,
              'isChecked': true,
            }).toList());
    final corrections = <sc.LroStatusCorrection>[];
    try {
      final decoded = jsonDecode(correctionsJson) as List;
      for (final item in decoded) {
        if (item is Map) {
          final c = sc.LroStatusCorrection.fromJson(
              Map<String, dynamic>.from(item));
          if (c.description.trim().isNotEmpty) corrections.add(c);
        }
      }
    } catch (_) {
      // corrupt data — fall back to defaults
    }
    if (corrections.isEmpty) {
      corrections.addAll(sc.kDefaultStatusCorrections.map(
          (d) => sc.LroStatusCorrection(description: d, isChecked: true)));
    }
    return LroSettings(
      countyUniqueNo: map['countyUniqueNo'] ?? '',
      facebookPageUrl: map['facebookPageUrl'] ?? '',
      numberOrder: LroNumberOrder.values.firstWhere(
        (o) => o.name == (map['numberOrder'] ?? ''),
        orElse: () => LroNumberOrder.countyDateUnique,
      ),
      publicNoticeTemplatePath:
          (map['publicNoticeTemplatePath'] ?? '').isEmpty ? null : map['publicNoticeTemplatePath'],
      publicNoticeTemplateBase64: (map['publicNoticeTemplateBase64'] ?? '').isEmpty
          ? null
          : map['publicNoticeTemplateBase64'],
      countySealPath:
          (map['countySealPath'] ?? '').isEmpty ? null : map['countySealPath'],
      countySealBase64: (map['countySealBase64'] ?? '').isEmpty
          ? null
          : map['countySealBase64'],
      noticeTemplate: decodeNoticeTemplate(map['noticeTemplateJson']),
      statusCorrections: corrections,
    );
  }

  /// Validates a Facebook URL string.
  static bool checkFacebookUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (!lower.contains('facebook.com') && !lower.contains('fb.com')) {
      return false;
    }
    if (!lower.startsWith('http://') &&
        !lower.startsWith('https://') &&
        !lower.startsWith('www.')) {
      return false;
    }
    if (lower.contains('/profile.php') || lower.contains('/posts/')) {
      return false;
    }
    return true;
  }

  @override
  String toString() =>
      'LroSettings(countyUniqueNo=$countyUniqueNo, order=${numberOrder.name}, '
      'hasPublicNoticeTemplate=$hasPublicNoticeTemplate, hasFacebook=${facebookPageUrl.isNotEmpty}, '
      'hasSeal=$hasCountySeal, corrections=${statusCorrections.length})';
}
