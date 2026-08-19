import 'dart:convert' show jsonDecode, jsonEncode;

/// Parametric Public Notice template style.
///
/// Stored as a set of style parameters (NOT a generated image). At publication
/// time the [LroNoticeRenderer] re-renders the notice from these parameters
/// plus the Member's data, replacing the old image-overlay approach.
class LroNoticeTemplateStyle {
  final String fontFamily; // display name: Arial, Times New Roman, etc.
  final double fontSize; // 8..72 pt
  final String fontColor; // "#RRGGBB"
  final bool bold;
  final bool italic;
  final bool underline;
  final LroNoticeAlignment alignment; // global default
  final String backgroundColor; // "#RRGGBB"
  final LroNoticeBorderStyle borderStyle;
  final String borderColor; // "#RRGGBB"
  final int borderWidth; // 1..10
  final String padding; // "small" | "medium" | "large"
  final double lineSpacing; // 1.0..2.0
  final bool showPlaceholders; // show {PLACEHOLDER} labels in preview
  final String placeholderColor; // "#RRGGBB"
  final LroNoticeSealPosition sealPosition;

  const LroNoticeTemplateStyle({
    this.fontFamily = 'Arial',
    this.fontSize = 24,
    this.fontColor = '#14202E',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = LroNoticeAlignment.center,
    this.backgroundColor = '#FFFFFF',
    this.borderStyle = LroNoticeBorderStyle.solid,
    this.borderColor = '#14202E',
    this.borderWidth = 2,
    this.padding = 'medium',
    this.lineSpacing = 1.2,
    this.showPlaceholders = true,
    this.placeholderColor = '#6B7280',
    this.sealPosition = LroNoticeSealPosition.bottom,
  });

  LroNoticeTemplateStyle copyWith({
    String? fontFamily,
    double? fontSize,
    String? fontColor,
    bool? bold,
    bool? italic,
    bool? underline,
    LroNoticeAlignment? alignment,
    String? backgroundColor,
    LroNoticeBorderStyle? borderStyle,
    String? borderColor,
    int? borderWidth,
    String? padding,
    double? lineSpacing,
    bool? showPlaceholders,
    String? placeholderColor,
    LroNoticeSealPosition? sealPosition,
  }) =>
      LroNoticeTemplateStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        fontColor: fontColor ?? this.fontColor,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        alignment: alignment ?? this.alignment,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        borderStyle: borderStyle ?? this.borderStyle,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
        padding: padding ?? this.padding,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        showPlaceholders: showPlaceholders ?? this.showPlaceholders,
        placeholderColor: placeholderColor ?? this.placeholderColor,
        sealPosition: sealPosition ?? this.sealPosition,
      );

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'fontColor': fontColor,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'alignment': alignment.name,
        'backgroundColor': backgroundColor,
        'borderStyle': borderStyle.name,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'padding': padding,
        'lineSpacing': lineSpacing,
        'showPlaceholders': showPlaceholders,
        'placeholderColor': placeholderColor,
        'sealPosition': sealPosition.name,
      };

  factory LroNoticeTemplateStyle.fromJson(Map<String, dynamic> json) {
    T _enum<T extends Enum>(List<T> values, String? name, T fallback) => name == null
        ? fallback
        : values.firstWhere((e) => e.name == name, orElse: () => fallback);
    return LroNoticeTemplateStyle(
      fontFamily: json['fontFamily'] as String? ?? 'Arial',
      fontSize: (json['fontSize'] as num? ?? 24).toDouble(),
      fontColor: json['fontColor'] as String? ?? '#14202E',
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      alignment: _enum(
          LroNoticeAlignment.values, json['alignment'] as String?, LroNoticeAlignment.center),
      backgroundColor: json['backgroundColor'] as String? ?? '#FFFFFF',
      borderStyle: _enum(LroNoticeBorderStyle.values, json['borderStyle'] as String?,
          LroNoticeBorderStyle.solid),
      borderColor: json['borderColor'] as String? ?? '#14202E',
      borderWidth: json['borderWidth'] as int? ?? 2,
      padding: json['padding'] as String? ?? 'medium',
      lineSpacing: (json['lineSpacing'] as num? ?? 1.2).toDouble(),
      showPlaceholders: json['showPlaceholders'] as bool? ?? true,
      placeholderColor: json['placeholderColor'] as String? ?? '#6B7280',
      sealPosition: _enum(LroNoticeSealPosition.values, json['sealPosition'] as String?,
          LroNoticeSealPosition.bottom),
    );
  }

  /// The default template matches the Part 3 design-plan layout.
  static const LroNoticeTemplateStyle defaults = LroNoticeTemplateStyle();

  @override
  String toString() => 'LroNoticeTemplateStyle(font=$fontFamily, size=$fontSize, '
      'align=${alignment.name}, bg=$backgroundColor, seal=${sealPosition.name})';
}

enum LroNoticeAlignment { left, center, right }

enum LroNoticeBorderStyle { none, solid, dashed, dotted }

enum LroNoticeSealPosition { top, bottom, left, right }

/// Encodes a nullable [LroNoticeTemplateStyle] to a JSON string (or '').
String? encodeNoticeTemplate(LroNoticeTemplateStyle? style) =>
    style == null ? null : jsonEncode(style.toJson());

/// Decodes a JSON string back into a [LroNoticeTemplateStyle] (or null).
LroNoticeTemplateStyle? decodeNoticeTemplate(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) {
      return LroNoticeTemplateStyle.fromJson(decoded);
    }
    return null;
  } catch (_) {
    return null;
  }
}
