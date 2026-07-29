/**
 * Garden Town County — Cloud Functions
 *
 * Deploy: firebase deploy --only functions,firestore:rules
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

async function notifyDuplicate(field, value, memberId) {
  await admin.firestore().collection('notifications').add({
    type: 'duplicate_detected',
    field,
    value,
    memberId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    message: `Duplicate ${field} detected: ${value}`,
  });
}

/**
 * Callable: set custom claims for role-based Firestore rules.
 *
 * Request: { uid: string, admin?: boolean, secretary?: boolean }
 * Caller must already have admin claim (or be the first bootstrap via console).
 */
exports.setUserClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Sign in required.',
    );
  }
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set custom claims.',
    );
  }

  const uid = (data && data.uid) ? String(data.uid).trim() : '';
  if (!uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'uid is required.',
    );
  }

  const claims = {
    admin: data.admin === true,
    secretary: data.secretary === true,
  };

  await admin.auth().setCustomUserClaims(uid, claims);
  return { ok: true, uid, claims };
});

/**
 * Callable used once by a project owner to bootstrap the first admin claim.
 * Protect with a one-time setup secret in functions config:
 *   firebase functions:config:set bootstrap.secret="YOUR_SECRET"
 */
exports.bootstrapAdminClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Sign in required.',
    );
  }

  const expected = functions.config().bootstrap?.secret;
  if (!expected || data?.secret !== expected) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Invalid bootstrap secret.',
    );
  }

  const uid = context.auth.uid;
  await admin.auth().setCustomUserClaims(uid, {
    admin: true,
    secretary: false,
  });
  return { ok: true, uid };
});

/**
 * Process claim_requests written by the Flutter ClaimsService.
 * Sets Auth custom claims used by firestore.rules (admin / secretary).
 */
exports.processClaimRequest = functions.firestore
  .document('claim_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const uid = (data.uid || '').toString().trim();
    if (!uid) {
      await snap.ref.set({ status: 'error', error: 'missing uid' }, { merge: true });
      return null;
    }
    try {
      await admin.auth().setCustomUserClaims(uid, {
        admin: data.admin === true,
        secretary: data.secretary === true,
      });
      await snap.ref.set(
        {
          status: 'applied',
          appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (err) {
      console.error('processClaimRequest failed', err);
      await snap.ref.set(
        {
          status: 'error',
          error: String(err && err.message ? err.message : err),
        },
        { merge: true },
      );
    }
    return null;
  });

exports.validateMemberBeforeSave = functions.firestore
  .document('members/{memberId}')
  .onWrite(async (change, context) => {
    const newData = change.after.exists ? change.after.data() : null;
    const oldData = change.before.exists ? change.before.data() : null;
    const memberId = context.params.memberId;

    if (!newData) return null;

    const saId = (newData.saId || '').toString().trim();
    const globalRecordNo = (newData.globalRecordNo || '').toString().trim();

    if (!/^[0-9]{13}$/.test(saId)) {
      console.error(`Invalid SA ID format for ${memberId}: ${saId}`);
    }
    if (!/^[0-9]{1,14}$/.test(globalRecordNo)) {
      console.error(
        `Invalid Global Record for ${memberId}: ${globalRecordNo}`,
      );
    }

    if (!oldData || oldData.saId !== saId) {
      const existing = await admin
        .firestore()
        .collection('members')
        .where('saId', '==', saId)
        .get();

      const clash = existing.docs.find((d) => d.id !== memberId);
      if (clash) {
        console.error(`Duplicate SA ID detected: ${saId}`);
        await notifyDuplicate('saId', saId, memberId);
        await change.after.ref.set(
          {
            duplicateFlag: true,
            duplicateField: 'saId',
            duplicateValue: saId,
          },
          { merge: true },
        );
      } else {
        await admin
          .firestore()
          .collection('members_unique_sa_id')
          .doc(saId)
          .set({ memberId, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        if (oldData?.saId && oldData.saId !== saId) {
          const oldLock = await admin
            .firestore()
            .collection('members_unique_sa_id')
            .doc(oldData.saId)
            .get();
          if (oldLock.exists && oldLock.data()?.memberId === memberId) {
            await oldLock.ref.delete();
          }
        }
      }
    }

    if (!oldData || oldData.globalRecordNo !== globalRecordNo) {
      const existing = await admin
        .firestore()
        .collection('members')
        .where('globalRecordNo', '==', globalRecordNo)
        .get();

      const clash = existing.docs.find((d) => d.id !== memberId);
      if (clash) {
        console.error(`Duplicate Global Record detected: ${globalRecordNo}`);
        await notifyDuplicate('globalRecordNo', globalRecordNo, memberId);
        await change.after.ref.set(
          {
            duplicateFlag: true,
            duplicateField: 'globalRecordNo',
            duplicateValue: globalRecordNo,
          },
          { merge: true },
        );
      } else {
        await admin
          .firestore()
          .collection('members_unique_global_record')
          .doc(globalRecordNo)
          .set({ memberId, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        if (
          oldData?.globalRecordNo &&
          oldData.globalRecordNo !== globalRecordNo
        ) {
          const oldLock = await admin
            .firestore()
            .collection('members_unique_global_record')
            .doc(oldData.globalRecordNo)
            .get();
          if (oldLock.exists && oldLock.data()?.memberId === memberId) {
            await oldLock.ref.delete();
          }
        }
      }
    }

    return null;
  });
