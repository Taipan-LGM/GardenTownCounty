import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Client helpers for Firebase custom claims used by Firestore security rules.
///
/// Production deployments should use the Cloud Functions `setUserClaims` /
/// `bootstrapAdminClaims` callables. This service documents the expected
/// contract and provides a local-dev fallback that writes a claims request
/// document for admins to process.
class ClaimsService {
  static const requestsCollection = 'claim_requests';

  /// Request custom claims for [uid]. Prefer calling the deployed callable
  /// from an Admin tooling screen once Cloud Functions are wired.
  Future<void> requestUserClaims({
    required String uid,
    bool admin = false,
    bool secretary = false,
  }) async {
    if (!FirebaseBootstrap.ready) {
      debugPrint('ClaimsService: Firebase not ready — skipped.');
      return;
    }
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) {
      throw Exception('Sign in required to request claims.');
    }
    await FirebaseFirestore.instance.collection(requestsCollection).add({
      'uid': uid,
      'admin': admin,
      'secretary': secretary,
      'requestedBy': actor.uid,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// After deploying functions, force-refresh the ID token so new claims apply.
  Future<void> refreshIdToken() async {
    if (!FirebaseBootstrap.ready) return;
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }
}
