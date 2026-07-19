import 'package:uuid/uuid.dart';

class MemberFile {
  final String id;
  final String memberId;
  final String fileName;
  final String description;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String? storageUrl;
  final String? localPath;
  final String contentType;
  final int sizeBytes;
  final bool pendingSync;
  final bool deleted;

  const MemberFile({
    required this.id,
    required this.memberId,
    required this.fileName,
    required this.description,
    required this.uploadedBy,
    required this.uploadedAt,
    this.storageUrl,
    this.localPath,
    this.contentType = 'application/octet-stream',
    this.sizeBytes = 0,
    this.pendingSync = true,
    this.deleted = false,
  });

  factory MemberFile.create({
    required String memberId,
    required String fileName,
    required String description,
    required String uploadedBy,
    String? localPath,
    String contentType = 'application/octet-stream',
    int sizeBytes = 0,
  }) {
    return MemberFile(
      id: const Uuid().v4(),
      memberId: memberId,
      fileName: fileName,
      description: description,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now().toUtc(),
      localPath: localPath,
      contentType: contentType,
      sizeBytes: sizeBytes,
    );
  }

  MemberFile copyWith({
    String? id,
    String? memberId,
    String? fileName,
    String? description,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? storageUrl,
    String? localPath,
    String? contentType,
    int? sizeBytes,
    bool? pendingSync,
    bool? deleted,
  }) {
    return MemberFile(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      fileName: fileName ?? this.fileName,
      description: description ?? this.description,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      storageUrl: storageUrl ?? this.storageUrl,
      localPath: localPath ?? this.localPath,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'fileName': fileName,
      'description': description,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'storageUrl': storageUrl,
      'localPath': localPath,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'memberId': memberId,
      'fileName': fileName,
      'description': description,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'storageUrl': storageUrl,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'deleted': deleted,
    };
  }

  factory MemberFile.fromMap(Map<String, dynamic> map) {
    return MemberFile(
      id: map['id'] as String,
      memberId: map['memberId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedAt: DateTime.tryParse(map['uploadedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      storageUrl: map['storageUrl'] as String?,
      localPath: map['localPath'] as String?,
      contentType: map['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  factory MemberFile.fromFirestore(Map<String, dynamic> map) {
    return MemberFile(
      id: map['id'] as String,
      memberId: map['memberId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedAt: DateTime.tryParse(map['uploadedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      storageUrl: map['storageUrl'] as String?,
      contentType: map['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      pendingSync: false,
      deleted: map['deleted'] as bool? ?? false,
    );
  }
}
