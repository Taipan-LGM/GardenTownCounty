import 'package:uuid/uuid.dart';

/// County video for the Videos tab.
///
/// // NEW ADDITION - Delete this file to revert Videos feature.
class CountyVideo {
  final String id;
  final String? firestoreId;
  final String title;
  final String description;
  final String videoLocalPath;
  final String? videoUrl;
  final String? thumbnailLocalPath;
  final String? thumbnailUrl;
  final String? duration;
  final DateTime uploadedAt;
  final String? category;
  final int viewCount;
  final bool isActive;
  final String uploadedBy;
  final String syncStatus;
  final bool isDeleted;

  const CountyVideo({
    required this.id,
    this.firestoreId,
    required this.title,
    this.description = '',
    required this.videoLocalPath,
    this.videoUrl,
    this.thumbnailLocalPath,
    this.thumbnailUrl,
    this.duration,
    required this.uploadedAt,
    this.category,
    this.viewCount = 0,
    this.isActive = true,
    required this.uploadedBy,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  factory CountyVideo.create({
    required String title,
    required String uploadedBy,
    String videoLocalPath = '',
    String? videoUrl,
    String description = '',
    String? thumbnailLocalPath,
    String? thumbnailUrl,
    String? duration,
    String? category,
    bool isActive = true,
  }) {
    return CountyVideo(
      id: const Uuid().v4(),
      title: title.trim(),
      description: description.trim(),
      videoLocalPath: videoLocalPath,
      videoUrl: videoUrl,
      thumbnailLocalPath: thumbnailLocalPath,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      uploadedAt: DateTime.now().toUtc(),
      category: category,
      isActive: isActive,
      uploadedBy: uploadedBy,
    );
  }

  CountyVideo copyWith({
    String? id,
    String? firestoreId,
    String? title,
    String? description,
    String? videoLocalPath,
    String? videoUrl,
    String? thumbnailLocalPath,
    String? thumbnailUrl,
    String? duration,
    DateTime? uploadedAt,
    String? category,
    int? viewCount,
    bool? isActive,
    String? uploadedBy,
    String? syncStatus,
    bool? isDeleted,
    bool clearThumbnail = false,
    bool clearDuration = false,
    bool clearCategory = false,
  }) {
    return CountyVideo(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoLocalPath: videoLocalPath ?? this.videoLocalPath,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailLocalPath: clearThumbnail
          ? null
          : (thumbnailLocalPath ?? this.thumbnailLocalPath),
      thumbnailUrl: clearThumbnail ? null : (thumbnailUrl ?? this.thumbnailUrl),
      duration: clearDuration ? null : (duration ?? this.duration),
      uploadedAt: uploadedAt ?? this.uploadedAt,
      category: clearCategory ? null : (category ?? this.category),
      viewCount: viewCount ?? this.viewCount,
      isActive: isActive ?? this.isActive,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'title': title,
    'description': description,
    'videoLocalPath': videoLocalPath,
    'videoUrl': videoUrl,
    'thumbnailLocalPath': thumbnailLocalPath,
    'thumbnailUrl': thumbnailUrl,
    'duration': duration,
    'uploadedAt': uploadedAt.toIso8601String(),
    'category': category,
    'viewCount': viewCount,
    'isActive': isActive ? 1 : 0,
    'uploadedBy': uploadedBy,
    'syncStatus': syncStatus,
    'isDeleted': isDeleted ? 1 : 0,
  };

  factory CountyVideo.fromMap(Map<String, dynamic> map) {
    return CountyVideo(
      id: map['id'] as String,
      firestoreId: map['firestoreId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      videoLocalPath: map['videoLocalPath'] as String? ?? '',
      videoUrl: map['videoUrl'] as String?,
      thumbnailLocalPath: map['thumbnailLocalPath'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      duration: map['duration'] as String?,
      uploadedAt:
          DateTime.tryParse(map['uploadedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      category: map['category'] as String?,
      viewCount: map['viewCount'] as int? ?? 0,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      uploadedBy: map['uploadedBy'] as String? ?? 'system',
      syncStatus: map['syncStatus'] as String? ?? 'pending',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }
}
