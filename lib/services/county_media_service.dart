import 'package:flutter/foundation.dart';

import '../models/county_article.dart';
import '../models/county_video.dart';
import 'county_media_persist_stub.dart'
    if (dart.library.io) 'county_media_persist_io.dart' as persist;
import 'database_service.dart';

/// County articles (Info tab) and videos — SQLite + local file persistence.
class CountyMediaService {
  CountyMediaService(this._db);

  final DatabaseService _db;

  Future<List<CountyArticle>> getPublishedArticles() =>
      _db.getPublishedArticles();

  Future<List<CountyArticle>> getAllArticles() => _db.getAllArticles();

  Future<void> upsertArticle(CountyArticle article) =>
      _db.upsertArticle(article);

  Future<void> softDeleteArticle(String id) => _db.softDeleteArticle(id);

  Future<List<CountyVideo>> getActiveVideos() => _db.getActiveVideos();

  Future<List<CountyVideo>> getAllVideos() => _db.getAllVideos();

  Future<void> upsertVideo(CountyVideo video) => _db.upsertVideo(video);

  Future<void> softDeleteVideo(String id) => _db.softDeleteVideo(id);

  /// Copy a picked file into app documents under [subfolder]/[fileName].
  /// On web, returns [sourcePath] unchanged (no local filesystem).
  Future<String> persistPickedFile({
    required String sourcePath,
    required String subfolder,
    required String fileName,
  }) async {
    if (kIsWeb) return sourcePath;
    return persist.copyPickedFileToAppDocs(
      sourcePath: sourcePath,
      subfolder: subfolder,
      fileName: fileName,
    );
  }
}
