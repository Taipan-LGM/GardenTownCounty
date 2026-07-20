import 'package:uuid/uuid.dart';

enum LroNoticeStatus {
  draft('draft', 'Draft'),
  published('published', 'Published'),
  archived('archived', 'Archived');

  const LroNoticeStatus(this.code, this.label);
  final String code;
  final String label;

  static LroNoticeStatus fromCode(String? code) {
    return LroNoticeStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => LroNoticeStatus.draft,
    );
  }
}

class LroNotice {
  final String id;
  final String? firestoreId;
  final String title;
  final String content;
  final DateTime? publicationDate;
  final DateTime? expiryDate;
  final String status;
  final String? memberId;
  final String? relatedCaseId;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const LroNotice({
    required this.id,
    this.firestoreId,
    required this.title,
    this.content = '',
    this.publicationDate,
    this.expiryDate,
    this.status = 'draft',
    this.memberId,
    this.relatedCaseId,
    this.createdBy = '',
    this.updatedBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  LroNoticeStatus get statusEnum => LroNoticeStatus.fromCode(status);

  factory LroNotice.create({
    required String title,
    required String createdBy,
    String content = '',
    DateTime? publicationDate,
    DateTime? expiryDate,
    String? memberId,
    String? relatedCaseId,
  }) {
    final now = DateTime.now().toUtc();
    return LroNotice(
      id: const Uuid().v4(),
      title: title,
      content: content,
      publicationDate: publicationDate,
      expiryDate: expiryDate,
      status: LroNoticeStatus.draft.code,
      memberId: memberId,
      relatedCaseId: relatedCaseId,
      createdBy: createdBy,
      updatedBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
  }

  LroNotice copyWith({
    String? id,
    String? firestoreId,
    String? title,
    String? content,
    DateTime? publicationDate,
    DateTime? expiryDate,
    String? status,
    String? memberId,
    String? relatedCaseId,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
    bool clearPublicationDate = false,
    bool clearExpiryDate = false,
    bool clearMemberId = false,
    bool clearRelatedCaseId = false,
  }) {
    return LroNotice(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      content: content ?? this.content,
      publicationDate: clearPublicationDate
          ? null
          : (publicationDate ?? this.publicationDate),
      expiryDate:
          clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      status: status ?? this.status,
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      relatedCaseId:
          clearRelatedCaseId ? null : (relatedCaseId ?? this.relatedCaseId),
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'title': title,
        'content': content,
        'publicationDate': publicationDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'status': status,
        'memberId': memberId,
        'relatedCaseId': relatedCaseId,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pendingSync': pendingSync ? 1 : 0,
        'deleted': deleted ? 1 : 0,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'firestoreId': firestoreId ?? id,
        'title': title,
        'content': content,
        'publicationDate': publicationDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'status': status,
        'memberId': memberId,
        'relatedCaseId': relatedCaseId,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory LroNotice.fromMap(Map<String, dynamic> map) {
    return LroNotice(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      publicationDate: _parseDt(map['publicationDate']),
      expiryDate: _parseDt(map['expiryDate']),
      status: map['status'] as String? ?? 'draft',
      memberId: map['memberId'] as String?,
      relatedCaseId: map['relatedCaseId'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      updatedBy: map['updatedBy'] as String? ?? '',
      createdAt: _parseDt(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDt(map['updatedAt']) ?? DateTime.now().toUtc(),
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1 ||
          map['pendingSync'] == true,
      deleted: (map['deleted'] as int? ?? 0) == 1 || map['deleted'] == true,
    );
  }

  factory LroNotice.fromFirestore(Map<String, dynamic> map) {
    return LroNotice.fromMap({
      ...map,
      'pendingSync': 0,
      'deleted': map['deleted'] == true || map['deleted'] == 1 ? 1 : 0,
    });
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }
}
