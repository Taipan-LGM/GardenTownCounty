import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/county_article.dart';
import '../models/county_video.dart';
import 'county_media_persist_stub.dart'
    if (dart.library.io) 'county_media_persist_io.dart'
    as persist;
import 'county_media_web_stub.dart'
    if (dart.library.html) 'county_media_web.dart'
    as web_media;
import 'database_service.dart';
import 'firebase_bootstrap.dart';

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

  Future<String> uploadPickedBytes({
    required Uint8List bytes,
    required String subfolder,
    required String fileName,
    required String contentType,
  }) async {
    if (!FirebaseBootstrap.ready && kIsWeb) {
      return web_media.createObjectUrl(bytes, contentType);
    }
    if (!FirebaseBootstrap.ready) {
      throw StateError('Cloud storage is not available.');
    }
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = FirebaseStorage.instance
        .ref()
        .child(subfolder)
        .child('${DateTime.now().millisecondsSinceEpoch}_$safeName');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
