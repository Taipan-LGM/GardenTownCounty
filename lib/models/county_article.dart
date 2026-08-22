import 'package:uuid/uuid.dart';

/// County article for the Info tab (optional PDF attachment).
///
/// // NEW ADDITION - Delete this file to revert Info articles feature.
class CountyArticle {
  final String id;
  final String? firestoreId;
  final String title;
  final String content;
  final String? author;
  final String? pdfLocalPath;
  final String? pdfUrl;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublished;
  final String? category;
  final int viewCount;
  final String createdBy;
  final String syncStatus;
  final bool isDeleted;
  final String countyId;

  const CountyArticle({
    required this.id,
    this.firestoreId,
    required this.title,
    required this.content,
    this.author,
    this.pdfLocalPath,
    this.pdfUrl,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
    this.isPublished = true,
    this.category,
    this.viewCount = 0,
    required this.createdBy,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    this.countyId = '',
  });

  factory CountyArticle.create({
    required String title,
    required String content,
    required String createdBy,
    String? author,
    String? pdfLocalPath,
    String? category,
    bool isPublished = true,
    String countyId = '',
  }) {
    return CountyArticle(
      id: const Uuid().v4(),
      title: title.trim(),
      content: content.trim(),
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      pdfLocalPath: pdfLocalPath,
      createdAt: DateTime.now().toUtc(),
      isPublished: isPublished,
      category: category,
      createdBy: createdBy,
      countyId: countyId,
    );
  }

  CountyArticle copyWith({
    String? id,
    String? firestoreId,
    String? title,
    String? content,
    String? author,
    String? pdfLocalPath,
    String? pdfUrl,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublished,
    String? category,
    int? viewCount,
    String? createdBy,
    String? syncStatus,
    bool? isDeleted,
    String? countyId,
    bool clearAuthor = false,
    bool clearPdf = false,
    bool clearCategory = false,
  }) {
    return CountyArticle(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      content: content ?? this.content,
      author: clearAuthor ? null : (author ?? this.author),
      pdfLocalPath: clearPdf ? null : (pdfLocalPath ?? this.pdfLocalPath),
      pdfUrl: clearPdf ? null : (pdfUrl ?? this.pdfUrl),
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublished: isPublished ?? this.isPublished,
      category: clearCategory ? null : (category ?? this.category),
      viewCount: viewCount ?? this.viewCount,
      createdBy: createdBy ?? this.createdBy,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      countyId: countyId ?? this.countyId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firestoreId': firestoreId,
        'title': title,
        'content': content,
        'author': author,
        'pdfLocalPath': pdfLocalPath,
        'pdfUrl': pdfUrl,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isPublished': isPublished ? 1 : 0,
        'category': category,
        'viewCount': viewCount,
        'createdBy': createdBy,
        'syncStatus': syncStatus,
        'isDeleted': isDeleted ? 1 : 0,
        'countyId': countyId,
      };

  factory CountyArticle.fromMap(Map<String, dynamic> map) {
    return CountyArticle(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      author: map['author'] as String?,
      pdfLocalPath: map['pdfLocalPath'] as String?,
      pdfUrl: map['pdfUrl'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
      isPublished: (map['isPublished'] as int? ?? 1) == 1,
      category: map['category'] as String?,
      viewCount: map['viewCount'] as int? ?? 0,
      createdBy: map['createdBy'] as String? ?? 'system',
      syncStatus: map['syncStatus'] as String? ?? 'pending',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      countyId: map['countyId'] as String? ?? '',
    );
  }
}
