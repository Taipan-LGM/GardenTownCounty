import '../models/lro_case.dart';
import '../models/lro_document.dart';
import '../models/lro_history.dart';
import '../models/lro_notice.dart';
import 'database_service.dart';
import 'sync_engine.dart';

/// Aggregate counts for the LRO dashboard.
class LroStats {
  final int total528;
  final int total928;
  final Map<String, int> byStatus528;
  final Map<String, int> byStatus928;
  final Map<String, int> noticeCounts;

  const LroStats({
    required this.total528,
    required this.total928,
    required this.byStatus528,
    required this.byStatus928,
    required this.noticeCounts,
  });

  int statusCount(LroCaseType type, LroCaseStatus status) {
    final map = type == LroCaseType.status528 ? byStatus528 : byStatus928;
    return map[status.code] ?? 0;
  }
}

/// Offline-first CRUD + workflow rules for LRO cases, notices, documents
/// and their audit history.
class LroRepository {
  LroRepository(this._db, this._sync);

  final DatabaseService _db;
  final SyncEngine _sync;

  // ── Cases ────────────────────────────────────────────────────────────

  Future<List<LroCase>> listCases({LroCaseType? type}) =>
      _db.getLroCases(caseType: type?.code);

  Future<LroCase?> getCase(String id) => _db.getLroCaseById(id);

  /// Stamps `updatedAt`/`pendingSync`, applies workflow rules (auto
  /// `publishedDate`, required `rejectionReason`), records a history entry
  /// on create or status change, then pushes to cloud.
  Future<LroCase> saveCase(LroCase lroCase) async {
    if (lroCase.statusEnum == LroCaseStatus.rejected &&
        lroCase.rejectionReason.trim().isEmpty) {
      throw ArgumentError(
        'A rejection reason is required when rejecting a case.',
      );
    }

    final existing = await _db.getLroCaseById(lroCase.id);
    final isCreate = existing == null;

    var next = lroCase.copyWith(
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );

    if (next.statusEnum == LroCaseStatus.published &&
        next.publishedDate == null) {
      next = next.copyWith(publishedDate: DateTime.now().toUtc());
    }

    await _db.upsertLroCase(next);

    if (isCreate) {
      await _db.insertLroHistory(LroHistory.create(
        entityType: 'case',
        entityId: next.id,
        action: 'created',
        changedBy: next.updatedBy,
        toStatus: next.status,
      ));
    } else if (existing.status != next.status) {
      await _db.insertLroHistory(LroHistory.create(
        entityType: 'case',
        entityId: next.id,
        action: 'status_changed',
        changedBy: next.updatedBy,
        fromStatus: existing.status,
        toStatus: next.status,
        detail: next.statusEnum == LroCaseStatus.rejected
            ? next.rejectionReason
            : '',
      ));
    }

    await _sync.pushPending();
    return next;
  }

  Future<void> deleteCase(String id) async {
    await _db.softDeleteLroCase(id);
    await _sync.pushPending();
  }

  // ── Notices ──────────────────────────────────────────────────────────

  Future<List<LroNotice>> listNotices({String? status}) =>
      _db.getLroNotices(status: status);

  Future<List<LroNotice>> getPublishedFeed() =>
      _db.getPublishedNoticesForFeed();

  Future<LroNotice> saveNotice(LroNotice notice) async {
    final existing = await _db.getLroNoticeById(notice.id);
    final isCreate = existing == null;

    final next = notice.copyWith(
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );

    await _db.upsertLroNotice(next);

    if (isCreate) {
      await _db.insertLroHistory(LroHistory.create(
        entityType: 'notice',
        entityId: next.id,
        action: 'created',
        changedBy: next.updatedBy,
        toStatus: next.status,
      ));
    } else if (existing.status != next.status) {
      await _db.insertLroHistory(LroHistory.create(
        entityType: 'notice',
        entityId: next.id,
        action: 'status_changed',
        changedBy: next.updatedBy,
        fromStatus: existing.status,
        toStatus: next.status,
      ));
    }

    await _sync.pushPending();
    return next;
  }

  Future<void> deleteNotice(String id) async {
    await _db.softDeleteLroNotice(id);
    await _sync.pushPending();
  }

  // ── Documents ────────────────────────────────────────────────────────

  Future<List<LroDocument>> listDocuments(
    String parentType,
    String parentId,
  ) =>
      _db.getLroDocumentsForParent(parentType, parentId);

  /// Persist document metadata. Callers own file-pick / upload plumbing
  /// (see [FileStorageService.pickAndUploadLroDocument]).
  Future<LroDocument> addDocument(LroDocument document) async {
    await _db.upsertLroDocument(document);
    await _sync.pushPending();
    return document;
  }

  Future<void> deleteDocument(String id) async {
    await _db.softDeleteLroDocument(id);
    await _sync.pushPending();
  }

  // ── History ──────────────────────────────────────────────────────────

  Future<List<LroHistory>> listHistory(String entityType, String entityId) =>
      _db.getLroHistoryForEntity(entityType, entityId);

  // ── Stats ────────────────────────────────────────────────────────────

  Future<LroStats> stats() async {
    final cases528 = await _db.getLroCases(caseType: LroCaseType.status528.code);
    final cases928 =
        await _db.getLroCases(caseType: LroCaseType.emancipation928.code);
    final notices = await _db.getLroNotices();

    final byStatus528 = <String, int>{};
    for (final c in cases528) {
      byStatus528[c.status] = (byStatus528[c.status] ?? 0) + 1;
    }
    final byStatus928 = <String, int>{};
    for (final c in cases928) {
      byStatus928[c.status] = (byStatus928[c.status] ?? 0) + 1;
    }
    final noticeCounts = <String, int>{};
    for (final n in notices) {
      noticeCounts[n.status] = (noticeCounts[n.status] ?? 0) + 1;
    }

    return LroStats(
      total528: cases528.length,
      total928: cases928.length,
      byStatus528: byStatus528,
      byStatus928: byStatus928,
      noticeCounts: noticeCounts,
    );
  }
}
