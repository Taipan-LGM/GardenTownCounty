import 'dart:typed_data';

/// Publication record stored in the LRO Publications section of the app.
class LroPublication {
  final String id;
  final String memberId;
  final String memberName;
  final String recordingNumber;
  final DateTime publishedAt;
  final String? facebookPostId;
  final bool pendingSync;
  final bool deleted;

  const LroPublication({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.recordingNumber,
    required this.publishedAt,
    this.facebookPostId,
    this.pendingSync = true,
    this.deleted = false,
  });

  LroPublication copyWith({
    String? id,
    String? memberId,
    String? memberName,
    String? recordingNumber,
    DateTime? publishedAt,
    String? facebookPostId,
    bool? pendingSync,
    bool? deleted,
  }) {
    return LroPublication(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      recordingNumber: recordingNumber ?? this.recordingNumber,
      publishedAt: publishedAt ?? this.publishedAt,
      facebookPostId: facebookPostId ?? this.facebookPostId,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'recordingNumber': recordingNumber,
        'publishedAt': publishedAt.toIso8601String(),
        'facebookPostId': facebookPostId,
        'pendingSync': pendingSync ? 1 : 0,
        'deleted': deleted ? 1 : 0,
      };

  factory LroPublication.fromMap(Map<String, dynamic> map) {
    return LroPublication(
      id: map['id'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String? ?? '',
      recordingNumber: map['recordingNumber'] as String? ?? '',
      publishedAt: DateTime.parse(map['publishedAt'] as String),
      facebookPostId: map['facebookPostId'] as String?,
      pendingSync: (_parseInt(map['pendingSync']) ?? 0) == 1,
      deleted: (_parseInt(map['deleted']) ?? 0) == 1,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
