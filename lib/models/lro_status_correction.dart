import 'dart:convert';

/// One Status Correction description row shown on the Public Notice.
///
/// Each row is purely a description (no date — the payment date is supplied
/// globally by {PAYMENT_DATE} in the template). The check mark indicates the
/// Admin considers this correction "done"; the system auto-prefixes every
/// published row with a "✅ ".
class LroStatusCorrection {
  const LroStatusCorrection({
    required this.description,
    this.isChecked = true,
  });

  /// Human-readable status correction label (e.g. "Voter Deregistration").
  final String description;

  /// Whether this row is "checked" (completed). The ✅ is shown whenever
  /// the row is non-empty, regardless of this flag, but the flag drives the
  /// Admin toggle UI and the default 4 pre-population.
  final bool isChecked;

  LroStatusCorrection copyWith({
    String? description,
    bool? isChecked,
  }) {
    return LroStatusCorrection(
      description: description ?? this.description,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'isChecked': isChecked,
      };

  factory LroStatusCorrection.fromJson(Map<String, dynamic> json) {
    return LroStatusCorrection(
      description: (json['description'] as String?) ?? '',
      isChecked: json['isChecked'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LroStatusCorrection &&
      other.description == description &&
      other.isChecked == isChecked;

  @override
  int get hashCode => Object.hash(description, isChecked);
}

/// The 4 default Status Correction descriptions shown on first LRO setup.
const kDefaultStatusCorrections = [
  'Voter Deregistration',
  'BIO Pages',
  '2 x Witness Testimonies',
  'Universal Declaration',
];
