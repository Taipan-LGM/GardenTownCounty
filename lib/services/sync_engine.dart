import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/activity_log.dart';
import '../models/app_user.dart';
import '../models/lookup_item.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import '../models/sos_preset.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';

enum SyncUiStatus { synced, syncing, offline, error }

class SyncState {
  final SyncUiStatus status;
  final DateTime? lastSyncedAt;
  final String? message;

  const SyncState({
    required this.status,
    this.lastSyncedAt,
    this.message,
  });

  SyncState copyWith({
    SyncUiStatus? status,
    DateTime? lastSyncedAt,
    String? message,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message,
    );
  }
}

/// Bidirectional offline-first sync: SQLite ↔ Firestore (+ Storage for files).
class SyncEngine {
  SyncEngine(this._db);

  final DatabaseService _db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _lookupsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _filesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activitiesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _presetsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  Timer? _pushTimer;
  bool _pushing = false;

  final _statusController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState(status: SyncUiStatus.offline);

  Stream<SyncState> get statusStream => _statusController.stream;
  SyncState get state => _state;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  bool get isCloudEnabled => FirebaseBootstrap.ready;

  void _emit(SyncState next) {
    _state = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  Future<void> start() async {
    if (!isCloudEnabled) {
      _emit(const SyncState(
        status: SyncUiStatus.offline,
        message: 'Cloud not configured — local only',
      ));
      return;
    }

    _emit(_state.copyWith(status: SyncUiStatus.syncing, message: 'Starting…'));
    await pushPending();
    _listenCloud();
    _pushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => pushPending(),
    );
  }

  Future<void> stop() async {
    await _membersSub?.cancel();
    await _lookupsSub?.cancel();
    await _filesSub?.cancel();
    await _activitiesSub?.cancel();
    await _presetsSub?.cancel();
    await _usersSub?.cancel();
    _pushTimer?.cancel();
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  void setOffline() {
    _emit(_state.copyWith(
      status: SyncUiStatus.offline,
      message: 'Offline — changes pending locally',
    ));
  }

  void setOnlineAndSync() {
    if (!isCloudEnabled) return;
    Future.microtask(pushPending);
  }

  void _listenCloud() {
    _membersSub = _fs
        .collection(AppConstants.membersCollection)
        .snapshots()
        .listen(_onMembersSnapshot, onError: _logError);

    _lookupsSub = _fs
        .collection(AppConstants.lookupsCollection)
        .snapshots()
        .listen(_onLookupsSnapshot, onError: _logError);

    _filesSub = _fs
        .collection(AppConstants.memberFilesCollection)
        .snapshots()
        .listen(_onFilesSnapshot, onError: _logError);

    _activitiesSub = _fs
        .collection(AppConstants.activitiesCollection)
        .snapshots()
        .listen(_onActivitiesSnapshot, onError: _logError);

    _presetsSub = _fs
        .collection(AppConstants.sosPresetsCollection)
        .snapshots()
        .listen(_onPresetsSnapshot, onError: _logError);

    _usersSub = _fs
        .collection(AppConstants.appUsersCollection)
        .snapshots()
        .listen(_onUsersSnapshot, onError: _logError);
  }

  Future<void> _onUsersSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = AppUser.fromFirestore({...data, 'id': change.doc.id});
      await _db.upsertAppUser(remote.copyWith(pendingSync: false));
    }
  }

  Future<void> _onMembersSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = Member.fromFirestore({...data, 'id': change.doc.id});
      final local = await _db.getMemberById(remote.id);
      // Last-write-wins on updatedAt.
      if (local == null ||
          remote.updatedAt.isAfter(local.updatedAt) ||
          (remote.deleted && !local.deleted)) {
        await _db.upsertMember(
          remote.copyWith(
            pendingSync: false,
            photoLocalPath: local?.photoLocalPath,
          ),
        );
      }
    }
  }

  Future<void> _onLookupsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = LookupItem.fromFirestore({...data, 'id': change.doc.id});
      await _db.upsertLookup(remote.copyWith(pendingSync: false));
    }
  }

  Future<void> _onFilesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = MemberFile.fromFirestore({...data, 'id': change.doc.id});
      await _db.upsertMemberFile(remote.copyWith(pendingSync: false));
    }
  }

  Future<void> _onActivitiesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = ActivityLog.fromFirestore({...data, 'id': change.doc.id});
      await _db.insertActivity(remote);
    }
  }

  Future<void> _onPresetsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = SosPreset.fromFirestore({...data, 'id': change.doc.id});
      await _db.upsertSosPreset(remote.copyWith(pendingSync: false));
    }
  }

  /// Push pending rows with exponential backoff on network errors.
  Future<void> pushPending() async {
    if (!isCloudEnabled || _pushing) return;
    _pushing = true;
    _emit(_state.copyWith(status: SyncUiStatus.syncing, message: 'Syncing…'));

    var attempt = 0;
    const maxAttempts = 4;
    while (true) {
      try {
        await _pushMembersBatched();
        await _pushLookupsBatched();
        await _pushFiles();
        await _pushActivitiesBatched();
        await _pushPresetsBatched();
        await _pushAppUsersBatched();
        _emit(SyncState(
          status: SyncUiStatus.synced,
          lastSyncedAt: DateTime.now(),
          message: 'Synced with cloud',
        ));
        break;
      } catch (error, stack) {
        _logError(error, stack);
        attempt++;
        if (attempt >= maxAttempts) {
          _emit(_state.copyWith(
            status: SyncUiStatus.error,
            message: 'Sync failed — will retry',
          ));
          break;
        }
        final delay = Duration(seconds: 1 << (attempt - 1)); // 1,2,4,8
        debugPrint('Sync retry in ${delay.inSeconds}s (attempt $attempt)');
        await Future<void>.delayed(delay);
      }
    }

    _pushing = false;
  }

  /// Force-push entire local DB after a manual restore (overwrite cloud).
  Future<void> forcePushAllAfterRestore() async {
    await _db.markAllPendingSync();
    await pushPending();
  }

  Future<void> _commitBatches(
    String collection,
    List<({String id, Map<String, dynamic> data})> docs,
  ) async {
    const chunkSize = 400;
    for (var i = 0; i < docs.length; i += chunkSize) {
      final chunk = docs.skip(i).take(chunkSize);
      final batch = _fs.batch();
      for (final doc in chunk) {
        batch.set(
          _fs.collection(collection).doc(doc.id),
          doc.data,
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  Future<void> _pushMembersBatched() async {
    final pending = await _db.getPendingMembers();
    final docs = <({String id, Map<String, dynamic> data})>[];
    for (final member in pending) {
      var photoUrl = member.photoUrl;
      if ((photoUrl == null || photoUrl.isEmpty) &&
          member.photoLocalPath != null &&
          File(member.photoLocalPath!).existsSync()) {
        final ext = member.photoLocalPath!.split('.').last.toLowerCase();
        final ref = _storage
            .ref()
            .child('member_photos')
            .child(member.id)
            .child('profile.$ext');
        await ref.putFile(File(member.photoLocalPath!));
        photoUrl = await ref.getDownloadURL();
        await _db.upsertMember(
          member.copyWith(photoUrl: photoUrl, pendingSync: true),
        );
      }
      docs.add((id: member.id, data: member.copyWith(photoUrl: photoUrl).toFirestore()));
    }
    await _commitBatches(AppConstants.membersCollection, docs);
    for (final member in pending) {
      await _db.markMemberSynced(member.id);
    }
  }

  Future<void> _pushLookupsBatched() async {
    final pending = await _db.getPendingLookups();
    await _commitBatches(
      AppConstants.lookupsCollection,
      pending.map((i) => (id: i.id, data: i.toFirestore())).toList(),
    );
    for (final item in pending) {
      await _db.markLookupSynced(item.id);
    }
  }

  Future<void> _pushFiles() async {
    final pending = await _db.getPendingMemberFiles();
    for (final file in pending) {
      var storageUrl = file.storageUrl;
      if ((storageUrl == null || storageUrl.isEmpty) &&
          file.localPath != null &&
          File(file.localPath!).existsSync()) {
        final ref = _storage
            .ref()
            .child('member_files')
            .child(file.memberId)
            .child('${file.id}_${file.fileName}');
        await ref.putFile(File(file.localPath!));
        storageUrl = await ref.getDownloadURL();
      }

      final synced = file.copyWith(storageUrl: storageUrl);
      await _fs
          .collection(AppConstants.memberFilesCollection)
          .doc(file.id)
          .set(synced.toFirestore(), SetOptions(merge: true));
      await _db.markMemberFileSynced(file.id, storageUrl: storageUrl);
    }
  }

  Future<void> _pushActivitiesBatched() async {
    final pending = await _db.getPendingActivities();
    await _commitBatches(
      AppConstants.activitiesCollection,
      pending.map((a) => (id: a.id, data: a.toFirestore())).toList(),
    );
    for (final activity in pending) {
      await _db.markActivitySynced(activity.id);
    }
  }

  Future<void> _pushPresetsBatched() async {
    final pending = await _db.getPendingSosPresets();
    await _commitBatches(
      AppConstants.sosPresetsCollection,
      pending.map((p) => (id: p.id, data: p.toFirestore())).toList(),
    );
    for (final preset in pending) {
      await _db.markSosPresetSynced(preset.id);
    }
  }

  Future<void> _pushAppUsersBatched() async {
    final pending = await _db.getPendingAppUsers();
    await _commitBatches(
      AppConstants.appUsersCollection,
      pending.map((u) => (id: u.id, data: u.toFirestore())).toList(),
    );
    for (final user in pending) {
      await _db.markAppUserSynced(user.id);
    }
  }

  void _logError(Object error, [StackTrace? stack]) {
    debugPrint('SyncEngine error: $error\n$stack');
  }
}
