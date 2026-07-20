import 'package:uuid/uuid.dart';

class LroDocument {
  final String id;
  final String? firestoreId;
  final String parentType; // case | notice
  final String parentId;
  final String docType;
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

  const LroDocument({
    required this.id,
    this.firestoreId,
    required this.parentType,
    required this.parentId,
    this.docType = 'other',
    required this.fileName,
    this.description = '',
    required this.uploadedBy,
    required this.uploadedAt,
    this.storageUrl,
    this.localPath,
    this.contentType = 'application/octet-stream',
    this.sizeBytes = 0,
    this.pendingSync = true,
    this.deleted = false,
  });

  factory LroDocument.create({
    required String parentType,
    required String parentId,
    required String fileName,
    required String uploadedBy,
    String docType = 'other',
    String description = '',
    String? storageUrl,
    String? localPath,
    String contentType = 'application/octet-stream',
    int sizeBytes = 0,
  }) {
    return LroDocument(
      id: const Uuid().v4(),
      parentType: parentType,
      parentId: parentId,
      docType: docType,
      fileName: fileName,
      description: description,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now().toUtc(),
      storageUrl: storageUrl,
      localPath: localPath,
      contentType: contentType,
      sizeBytes: sizeBytes,
    );
  }

  LroDocument copyWith({
    String? id,
    String? firestoreId,
    String? parentType,
    String? parentId,
    String? docType,
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
    bool clearStorageUrl = false,
    bool clearLocalPath = false,
  }) {
    return LroDocument(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      parentType: parentType ?? this.parentType,
      parentId: parentId ?? this.parentId,
      docType: docType ?? this.docType,
      fileName: fileName ?? this.fileName,
      description: description ?? this.description,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      storageUrl: clearStorageUrl ? null : (storageUrl ?? this.storageUrl),
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'parentType': parentType,
        'parentId': parentId,
        'docType': docType,
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

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'firestoreId': firestoreId ?? id,
        'parentType': parentType,
        'parentId': parentId,
        'docType': docType,
        'fileName': fileName,
        'description': description,
        'uploadedBy': uploadedBy,
        'uploadedAt': uploadedAt.toIso8601String(),
        'storageUrl': storageUrl,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'deleted': deleted,
      };

  factory LroDocument.fromMap(Map<String, dynamic> map) {
    return LroDocument(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      parentType: map['parentType'] as String? ?? 'case',
      parentId: map['parentId'] as String? ?? '',
      docType: map['docType'] as String? ?? 'other',
      fileName: map['fileName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedAt: DateTime.tryParse(map['uploadedAt'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      storageUrl: map['storageUrl'] as String?,
      localPath: map['localPath'] as String?,
      contentType: map['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      pendingSync: (map['pendingSync'] as int? ?? 0) == 1 ||
          map['pendingSync'] == true,
      deleted: (map['deleted'] as int? ?? 0) == 1 || map['deleted'] == true,
    );
  }

  factory LroDocument.fromFirestore(Map<String, dynamic> map) {
    return LroDocument.fromMap({
      ...map,
      'pendingSync': 0,
      'deleted': map['deleted'] == true || map['deleted'] == 1 ? 1 : 0,
    });
  }
}
