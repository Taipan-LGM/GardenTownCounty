import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/models/county_article.dart';
import 'package:garden_town_county/models/county_video.dart';
import 'package:garden_town_county/services/county_media_service.dart';
import 'package:garden_town_county/services/database_service.dart';

void main() {
  late DatabaseService db;
  late CountyMediaService media;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
    media = CountyMediaService(db);
  });

  tearDown(() async {
    await db.clearAllForTests();
  });

  test('article publish and soft-delete', () async {
    final article = CountyArticle.create(
      title: 'Welcome',
      content: 'Hello county',
      createdBy: 'admin',
      isPublished: true,
    );
    await media.upsertArticle(article);
    expect((await media.getPublishedArticles()).length, 1);
    expect((await media.getAllArticles()).length, 1);

    await media.softDeleteArticle(article.id);
    expect(await media.getPublishedArticles(), isEmpty);
    expect(await media.getAllArticles(), isEmpty);
  });

  test('video active list', () async {
    final video = CountyVideo.create(
      title: 'Intro',
      videoUrl: 'https://storage.example/intro.mp4',
      uploadedBy: 'admin',
      isActive: true,
    );
    await media.upsertVideo(video);
    final active = await media.getActiveVideos();
    expect(active, hasLength(1));
    expect(active.single.videoLocalPath, isEmpty);
    expect(active.single.videoUrl, 'https://storage.example/intro.mp4');

    await media.upsertVideo(video.copyWith(isActive: false));
    expect(await media.getActiveVideos(), isEmpty);
    expect((await media.getAllVideos()).length, 1);
  });
}
