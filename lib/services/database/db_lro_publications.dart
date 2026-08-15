part of '../database_service.dart';

/// LRO Publications table — stores in-app publication records for the
/// LRO Publications section.
mixin _DbLroPublications on _DatabaseServiceBase {
  Future<void> _createLroPublicationsTable(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS lro_publications (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        memberName TEXT NOT NULL DEFAULT '',
        recordingNumber TEXT NOT NULL DEFAULT '',
        publishedAt TEXT NOT NULL,
        facebookPostId TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_pub_member ON lro_publications(memberId)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_lro_pub_date ON lro_publications(publishedAt)',
    );
  }

  Future<void> _dropLroPublicationsTable(Database database) async {
    await database.execute('DROP TABLE IF EXISTS lro_publications');
  }
}
