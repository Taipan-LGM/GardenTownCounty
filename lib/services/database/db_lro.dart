part of '../database_service.dart';

import 'dart:io' show File, Directory;
import 'package:path/path.dart' as p;

import '../models/lro_publication.dart';
import '../models/lro_case.dart';
import '../models/lro_notice.dart';
import '../models/lro_document.dart';
import '../models/lro_history.dart';
import '../models/member.dart';

/// LRO case, notice, document, history persistence + publications + image storage.
mixin _DbLro on _DatabaseServiceBase {
  // ── LRO cases ──────────────────────────────────────────────────────────

  Future<void> upsertLroCase(LroCase lroCase) async {
    if (_memoryMode) {
      _lroCases[lroCase.id] = lroCase;
      return;
    }
    await db.insert(
      'lro_cases',
      lroCase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroCase>> getLroCases({String? caseType}) async {
    if (_memoryMode) {
      final list = _lroCases.values
          .where((c) => !c.deleted && (caseType == null || c.caseType == caseType))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final where = StringBuffer('deleted = 0');
    final args = <Object?>[];
    if (caseType != null) {
      where.write(' AND caseType = ?');
      args.add(caseType);
    }
    final rows = await db.query(
      'lro_cases',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(LroCase.fromMap).toList();
  }

  Future<LroCase?> getLroCaseById(String id) async {
    if (_memoryMode) {
      final c = _lroCases[id];
      if (c == null || c.deleted) return null;
      return c;
    }
    final rows = await db.query(
      'lro_cases',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LroCase.fromMap(rows.first);
  }

  Future<void> softDeleteLroCase(String id) async {
    if (_memoryMode) {
      final c = _lroCases[id];
      if (c != null) {
        _lroCases[id] = c.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'lro_cases',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroCase>> getPendingLroCases() async {
    if (_memoryMode) {
      return _lroCases.values.where((c) => c.pendingSync).toList();
    }
    final rows = await db.query('lro_cases', where: 'pendingSync = 1');
    return rows.map(LroCase.fromMap).toList();
  }

  Future<void> markLroCaseSynced(String id) async {
    if (_memoryMode) {
      final c = _lroCases[id];
      if (c != null) _lroCases[id] = c.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_cases',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── LRO notices ────────────────────────────────────────────────────────

  Future<void> upsertLroNotice(LroNotice notice) async {
    if (_memoryMode) {
      _lroNotices[notice.id] = notice;
      return;
    }
    await db.insert(
      'lro_notices',
      notice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroNotice>> getLroNotices({String? status}) async {
    if (_memoryMode) {
      final list = _lroNotices.values
          .where((n) => !n.deleted && (status == null || n.status == status))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final where = StringBuffer('deleted = 0');
    final args = <Object?>[];
    if (status != null) {
      where.write(' AND status = ?');
      args.add(status);
    }
    final rows = await db.query(
      'lro_notices',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(LroNotice.fromMap).toList();
  }

  Future<List<LroNotice>> getPublishedNoticesForFeed() async {
    if (_memoryMode) {
      final list = _lroNotices.values
          .where((n) => !n.deleted && n.status == 'published')
          .toList()
        ..sort((a, b) {
          final aKey = a.publicationDate ?? a.updatedAt;
          final bKey = b.publicationDate ?? b.updatedAt;
          return bKey.compareTo(aKey);
        });
      return list;
    }
    final rows = await db.query(
      'lro_notices',
      where: "deleted = 0 AND status = 'published'",
      orderBy: 'COALESCE(publicationDate, updatedAt) DESC',
    );
    return rows.map(LroNotice.fromMap).toList();
  }

  Future<LroNotice?> getLroNoticeById(String id) async {
    if (_memoryMode) {
      final n = _lroNotices[id];
      if (n == null || n.deleted) return null;
      return n;
    }
    final rows = await db.query(
      'lro_notices',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LroNotice.fromMap(rows.first);
  }

  Future<void> softDeleteLroNotice(String id) async {
    if (_memoryMode) {
      final n = _lroNotices[id];
      if (n != null) {
        _lroNotices[id] = n.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'lro_notices',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroNotice>> getPendingLroNotices() async {
    if (_memoryMode) {
      return _lroNotices.values.where((n) => n.pendingSync).toList();
    }
    final rows = await db.query('lro_notices', where: 'pendingSync = 1');
    return rows.map(LroNotice.fromMap).toList();
  }

  Future<void> markLroNoticeSynced(String id) async {
    if (_memoryMode) {
      final n = _lroNotices[id];
      if (n != null) _lroNotices[id] = n.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_notices',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── LRO publications (for the in-app Publications section) ──────────────

  final Map<String, LroPublication> _lroPublications = {};

  Future<void> upsertLroPublication(LroPublication pub) async {
    if (_memoryMode) {
      _lroPublications[pub.id] = pub;
      return;
    }
    await db.insert(
      'lro_publications',
      pub.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroPublication>> getLroPublications({
    int limit = 100,
  }) async {
    if (_memoryMode) {
      final all = _lroPublications.values
          .where((p) => !p.deleted)
          .toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (all.length > limit) all.removeRange(limit, all.length);
      return all;
    }
    final rows = await db.query(
      'lro_publications',
      where: 'deleted = 0',
      orderBy: 'publishedAt DESC',
      limit: limit,
    );
    return rows.map(LroPublication.fromMap).toList();
  }

  Future<LroPublication?> getLroPublicationById(String id) async {
    if (_memoryMode) {
      final p = _lroPublications[id];
      if (p == null || p.deleted) return null;
      return p;
    }
    final rows = await db.query(
      'lro_publications',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LroPublication.fromMap(rows.first);
  }

  Future<void> softDeleteLroPublication(String id) async {
    if (_memoryMode) {
      final p = _lroPublications[id];
      if (p != null) {
        _lroPublications[id] = p.copyWith(
          deleted: true,
          pendingSync: true,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return;
    }
    await db.update(
      'lro_publications',
      {
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markLroPublicationSynced(String id) async {
    if (_memoryMode) {
      final p = _lroPublications[id];
      if (p != null) _lroPublications[id] = p.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_publications',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroPublication>> getPendingLroPublications() async {
    if (_memoryMode) {
      return _lroPublications.values.where((p) => p.pendingSync).toList();
    }
    final rows = await db.query(
      'lro_publications',
      where: 'pendingSync = 1 AND deleted = 0',
    );
    return rows.map(LroPublication.fromMap).toList();
  }

  // ── LRO documents ──────────────────────────────────────────────────────

  Future<void> upsertLroDocument(LroDocument document) async {
    if (_memoryMode) {
      _lroDocuments[document.id] = document;
      return;
    }
    await db.insert(
      'lro_documents',
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroDocument>> getLroDocumentsForParent(
    String parentType,
    String parentId,
  ) async {
    if (_memoryMode) {
      final list = _lroDocuments.values
          .where((d) =>
              !d.deleted && d.parentType == parentType && d.parentId == parentId)
          .toList()
        ..sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
      return list;
    }
    final rows = await db.query(
      'lro_documents',
      where: 'parentType = ? AND parentId = ? AND deleted = 0',
      whereArgs: [parentType, parentId],
      orderBy: 'fileName COLLATE NOCASE ASC',
    );
    return rows.map(LroDocument.fromMap).toList();
  }

  Future<void> softDeleteLroDocument(String id) async {
    if (_memoryMode) {
      final d = _lroDocuments[id];
      if (d != null) {
        _lroDocuments[id] = d.copyWith(deleted: true, pendingSync: true);
      }
      return;
    }
    await db.update(
      'lro_documents',
      {
        'deleted': 1,
        'pendingSync': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LroDocument>> getPendingLroDocuments() async {
    if (_memoryMode) {
      return _lroDocuments.values
          .where((d) => d.pendingSync && !d.deleted)
          .toList();
    }
    final rows = await db.query(
      'lro_documents',
      where: 'pendingSync = 1 AND deleted = 0',
    );
    return rows.map(LroDocument.fromMap).toList();
  }

  Future<void> markLroDocumentSynced(String id, {String? storageUrl}) async {
    if (_memoryMode) {
      final d = _lroDocuments[id];
      if (d != null) {
        _lroDocuments[id] = d.copyWith(
          pendingSync: false,
          storageUrl: storageUrl,
        );
      }
      return;
    }
    final values = <String, Object?>{'pendingSync': 0};
    if (storageUrl != null) {
      values['storageUrl'] = storageUrl;
    }
    await db.update(
      'lro_documents',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── LRO history ────────────────────────────────────────────────────────

  Future<void> insertLroHistory(LroHistory history) async {
    if (_memoryMode) {
      _lroHistory[history.id] = history;
      return;
    }
    await db.insert(
      'lro_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LroHistory>> getLroHistoryForEntity(
    String entityType,
    String entityId,
  ) async {
    if (_memoryMode) {
      final list = _lroHistory.values
          .where((h) => h.entityType == entityType && h.entityId == entityId)
          .toList()
        ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
      return list;
    }
    final rows = await db.query(
      'lro_history',
      where: 'entityType = ? AND entityId = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'changedAt DESC',
    );
    return rows.map(LroHistory.fromMap).toList();
  }

  Future<List<LroHistory>> getPendingLroHistory() async {
    if (_memoryMode) {
      return _lroHistory.values.where((h) => h.pendingSync).toList();
    }
    final rows = await db.query('lro_history', where: 'pendingSync = 1');
    return rows.map(LroHistory.fromMap).toList();
  }

  Future<void> markLroHistorySynced(String id) async {
    if (_memoryMode) {
      final h = _lroHistory[id];
      if (h != null) _lroHistory[id] = h.copyWith(pendingSync: false);
      return;
    }
    await db.update(
      'lro_history',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Recording Number uniqueness ─────────────────────────────────────────

  /// Returns every distinct Recording Number stored against members.
  Future<Set<String>> getAllLroRecordingNumbers() async {
    if (_memoryMode) {
      return _members.values
          .where((m) => m.lroRecordNo != null && m.lroRecordNo!.isNotEmpty)
          .map((m) => m.lroRecordNo!.trim())
          .toSet();
    }
    final rows = await db.query(
      'members',
      columns: ['lroRecordNo'],
      where: 'lroRecordNo IS NOT NULL AND lroRecordNo != \'\' AND deleted = 0',
    );
    return rows
        .map((r) => (r['lroRecordNo'] as String).trim())
        .toSet();
  }

  // ── Personalized notice image storage ───────────────────────────────────

  /// Persists the personalized Public Notice image bytes for a member.
  /// On disk: `<dbDir>/lro_notices/<memberId>.png`.
  Future<void> saveLroNoticeImage({
    required String memberId,
    required String recordingNumber,
    required Uint8List imageBytes,
    required DateTime publishedAt,
  }) async {
    if (_memoryMode) return;
    final dbDir = (await getApplicationDocumentsDirectory()).path;
    final dir = p.join(dbDir, 'lro_notices');
    await Directory(dir).create(recursive: true);
    final file = File(p.join(dir, '${memberId}.png'));
    await file.writeAsBytes(imageBytes);
  }

  /// Creates a publication row in the LRO Publications table.
  Future<String> createLroPublication({
    required String memberId,
    required String memberName,
    required String recordingNumber,
    required Uint8List imageBytes,
    required DateTime publishedAt,
    String? facebookPostId,
    String? actorId,
  }) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${memberId.substring(0, 8)}';
    final pub = LroPublication(
      id: id,
      memberId: memberId,
      memberName: memberName,
      recordingNumber: recordingNumber,
      publishedAt: publishedAt,
      facebookPostId: facebookPostId,
      pendingSync: true,
      deleted: false,
    );
    await upsertLroPublication(pub);
    return id;
  }
}
