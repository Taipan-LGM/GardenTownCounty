import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/activity_log.dart';
import '../models/lookup_item.dart';
import '../models/member.dart';
import '../models/member_file.dart';
import '../models/sos_preset.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';

/// Bidirectional offline-first sync: SQLite ↔ Firestore (+ Storage for files).
class SyncEngine {
  SyncEngine(this._db);

  final DatabaseService _db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _lookupsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _filesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activitiesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _presetsSub;
  Timer? _pushTimer;
  bool _pushing = false;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  bool get isCloudEnabled => FirebaseBootstrap.ready;

  Future<void> start() async {
    if (!isCloudEnabled) return;

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
    _pushTimer?.cancel();
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
  }

  Future<void> _onMembersSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final remote = Member.fromFirestore({...data, 'id': change.doc.id});
      final local = await _db.getMemberById(remote.id);
      if (local == null ||
          remote.updatedAt.isAfter(local.updatedAt) ||
          (remote.deleted && !local.deleted)) {
        await _db.upsertMember(remote.copyWith(pendingSync: false));
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

  Future<void> pushPending() async {
    if (!isCloudEnabled || _pushing) return;
    _pushing = true;
    try {
      await _pushMembers();
      await _pushLookups();
      await _pushFiles();
      await _pushActivities();
      await _pushPresets();
    } catch (error, stack) {
      _logError(error, stack);
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushMembers() async {
    final pending = await _db.getPendingMembers();
    for (final member in pending) {
      await _fs
          .collection(AppConstants.membersCollection)
          .doc(member.id)
          .set(member.toFirestore(), SetOptions(merge: true));
      await _db.markMemberSynced(member.id);
    }
  }

  Future<void> _pushLookups() async {
    final pending = await _db.getPendingLookups();
    for (final item in pending) {
      await _fs
          .collection(AppConstants.lookupsCollection)
          .doc(item.id)
          .set(item.toFirestore(), SetOptions(merge: true));
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

  Future<void> _pushActivities() async {
    final pending = await _db.getPendingActivities();
    for (final activity in pending) {
      await _fs
          .collection(AppConstants.activitiesCollection)
          .doc(activity.id)
          .set(activity.toFirestore(), SetOptions(merge: true));
      await _db.markActivitySynced(activity.id);
    }
  }

  Future<void> _pushPresets() async {
    final pending = await _db.getPendingSosPresets();
    for (final preset in pending) {
      await _fs
          .collection(AppConstants.sosPresetsCollection)
          .doc(preset.id)
          .set(preset.toFirestore(), SetOptions(merge: true));
      await _db.markSosPresetSynced(preset.id);
    }
  }

  void _logError(Object error, [StackTrace? stack]) {
    debugPrint('SyncEngine error: $error\n$stack');
  }
}
