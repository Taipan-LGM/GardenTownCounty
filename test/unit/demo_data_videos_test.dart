import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/services/database_service.dart';
import 'package:garden_town_county/services/demo_data_service.dart';

void main() {
  late DatabaseService db;
  late DemoDataService demoData;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initForTests();
    demoData = DemoDataService(db);
  });

  tearDown(() async {
    await db.clearAllForTests();
  });

  test('uploaded videos are stable bundled demo data', () async {
    await demoData.generateDemoData();
    await demoData.generateDemoData();

    final videos = await db.getAllVideos();
    expect(
      videos.map((video) => video.id).toSet(),
      {'vid_global_family_group', 'vid_south_africa_corporation'},
    );
    final globalFamily =
        videos.where((video) => video.id == 'vid_global_family_group').single;
    final southAfrica = videos
        .where((video) => video.id == 'vid_south_africa_corporation')
        .single;

    expect(globalFamily.title, 'Global family Group');
    expect(globalFamily.duration, '14:89');
    expect(
      globalFamily.videoUrl,
      'assets/assets/videos/global_family_group.mp4',
    );
    expect(southAfrica.title, 'South Africa is a Corporation');
    expect(southAfrica.duration, '6:22');
    expect(
      southAfrica.videoUrl,
      'assets/assets/videos/south_africa_corporation.mp4',
    );
  });
}