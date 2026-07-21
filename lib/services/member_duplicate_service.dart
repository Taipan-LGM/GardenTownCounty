import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/exceptions/duplicate_exception.dart';
import '../models/member.dart';
import 'database_service.dart';
import 'firebase_bootstrap.dart';
import 'sa_id_validator.dart';

/// Result of a uniqueness probe for one field.
class DuplicateCheckResult {
  const DuplicateCheckResult({
    required this.isDuplicate,
    this.existingMember,
    this.errorMessage,
  });

  final bool isDuplicate;
  final Member? existingMember;
  final String? errorMessage;

  static const ok = DuplicateCheckResult(isDuplicate: false);
}

/// Local + cloud duplicate checks for SA ID / Global Record No.
class MemberDuplicateService {
  MemberDuplicateService(this._db, {FirebaseFirestore? firestore})
      : _firestore = firestore;

  final DatabaseService _db;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _fs {
    if (_firestore != null) return _firestore;
    if (!FirebaseBootstrap.ready) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<DuplicateCheckResult> checkSaId(
    String saId, {
    String? excludeMemberId,
  }) async {
    final formatError = SaIdValidator.validate(saId);
    if (formatError != null) {
      return DuplicateCheckResult(
        isDuplicate: false,
        errorMessage: formatError,
      );
    }
    final key = saId.trim();

    final local = await _db.findMemberBySaId(
      key,
      excludeMemberId: excludeMemberId,
    );
    if (local != null) {
      return DuplicateCheckResult(
        isDuplicate: true,
        existingMember: local,
        errorMessage:
            '❌ This SA ID is already registered to another member',
      );
    }

    final cloud = await _checkFirestoreField(
      field: 'saId',
      value: key,
      excludeMemberId: excludeMemberId,
    );
    if (cloud != null) {
      return DuplicateCheckResult(
        isDuplicate: true,
        existingMember: cloud,
        errorMessage:
            '❌ This SA ID is already registered to another member',
      );
    }
    return DuplicateCheckResult.ok;
  }

  Future<DuplicateCheckResult> checkGlobalRecord(
    String globalRecordNo, {
    String? excludeMemberId,
  }) async {
    final formatError = GlobalRecordValidator.validate(globalRecordNo);
    if (formatError != null) {
      return DuplicateCheckResult(
        isDuplicate: false,
        errorMessage: formatError,
      );
    }
    final key = globalRecordNo.trim();

    final local = await _db.findMemberByGlobalRecordNo(
      key,
      excludeMemberId: excludeMemberId,
    );
    if (local != null) {
      return DuplicateCheckResult(
        isDuplicate: true,
        existingMember: local,
        errorMessage:
            '❌ This Global Record No. is already registered to another member',
      );
    }

    final cloud = await _checkFirestoreField(
      field: 'globalRecordNo',
      value: key,
      excludeMemberId: excludeMemberId,
    );
    if (cloud != null) {
      return DuplicateCheckResult(
        isDuplicate: true,
        existingMember: cloud,
        errorMessage:
            '❌ This Global Record No. is already registered to another member',
      );
    }
    return DuplicateCheckResult.ok;
  }

  /// Throws [DuplicateException] if either unique field collides.
  Future<void> assertUnique(Member member) async {
    final sa = await checkSaId(member.saId, excludeMemberId: member.id);
    if (sa.errorMessage != null && !sa.isDuplicate) {
      throw DuplicateException(
        sa.errorMessage!,
        field: 'SA ID',
        value: member.saId,
      );
    }
    if (sa.isDuplicate) {
      throw DuplicateException(
        sa.errorMessage ?? 'SA ID already exists',
        field: 'SA ID',
        value: member.saId,
        existingMemberId: sa.existingMember?.id,
      );
    }

    final gr = await checkGlobalRecord(
      member.globalRecordNo,
      excludeMemberId: member.id,
    );
    if (gr.errorMessage != null && !gr.isDuplicate) {
      throw DuplicateException(
        gr.errorMessage!,
        field: 'Global Record No.',
        value: member.globalRecordNo,
      );
    }
    if (gr.isDuplicate) {
      throw DuplicateException(
        gr.errorMessage ?? 'Global Record No. already exists',
        field: 'Global Record No.',
        value: member.globalRecordNo,
        existingMemberId: gr.existingMember?.id,
      );
    }
  }

  Future<Member?> _checkFirestoreField({
    required String field,
    required String value,
    String? excludeMemberId,
  }) async {
    final fs = _fs;
    if (fs == null) return null;
    try {
      final snap = await fs
          .collection(AppConstants.membersCollection)
          .where(field, isEqualTo: value)
          .limit(5)
          .get();
      for (final doc in snap.docs) {
        if (excludeMemberId != null && doc.id == excludeMemberId) continue;
        final data = doc.data();
        if (data['deleted'] == true) continue;
        try {
          return Member.fromFirestore({...data, 'id': doc.id});
        } catch (e) {
          debugPrint('Duplicate cloud parse failed: $e');
          return Member.create(
            saId: data['saId']?.toString() ?? value,
            globalRecordNo: data['globalRecordNo']?.toString() ?? '',
            memberName: data['memberName']?.toString() ?? 'Unknown',
            surname: data['surname']?.toString() ?? '',
          ).copyWith(id: doc.id);
        }
      }
    } catch (e) {
      debugPrint('Error checking Firestore $field duplicate: $e');
    }
    return null;
  }
}
