import '../core/exceptions/duplicate_exception.dart';
import '../models/lookup_item.dart';
import '../models/member.dart';
import 'database_service.dart';
import 'member_duplicate_service.dart';
import 'sync_engine.dart';

class MemberRepository {
  MemberRepository(this._db, this._sync, this._duplicates);

  final DatabaseService _db;
  final SyncEngine _sync;
  final MemberDuplicateService _duplicates;

  Future<List<Member>> getAll() => _db.getAllMembers();

  Future<Member?> getById(String id) => _db.getMemberById(id);

  Future<List<Member>> search(String query) => _db.searchMembers(query);

  Future<Member> save(Member member) async {
    await _duplicates.assertUnique(member);
    final stamped = member.copyWith(
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    try {
      await _db.upsertMember(stamped);
    } on DuplicateException {
      rethrow;
    }
    await _sync.pushPending();
    return stamped;
  }

  Future<void> delete(String id) async {
    await _db.softDeleteMember(id);
    await _sync.pushPending();
  }

  Future<List<LookupItem>> getLookups(LookupType type) =>
      _db.getLookups(type);

  Future<LookupItem> saveLookup(LookupItem item) async {
    final stamped = item.copyWith(
      updatedAt: DateTime.now().toUtc(),
      pendingSync: true,
    );
    await _db.upsertLookup(stamped);
    await _sync.pushPending();
    return stamped;
  }

  Future<void> deleteLookup(String id) async {
    await _db.softDeleteLookup(id);
    await _sync.pushPending();
  }
}
