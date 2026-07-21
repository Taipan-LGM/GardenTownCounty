/**
 * Garden Town County — pre-save duplicate validation for members.
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
        // Soft-flag document; client must resolve. Hard rollback is unsafe in onWrite.
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
