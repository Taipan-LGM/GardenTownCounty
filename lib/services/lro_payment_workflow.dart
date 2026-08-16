import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/lro_settings.dart';
import '../models/member.dart';
import '../services/database_service.dart';
import '../services/lro_settings_service.dart';
import '../services/recording_number_service.dart';
import '../services/activity_service.dart';
import '../services/lro_email_service.dart';
import '../providers/providers.dart';

/// Handles the automated LRO (Land Recording Office) workflow that runs after a
/// Step 4_LRO payment is recorded.
///
/// Sequence (per the Garden Town County LRO design plan):
///  1. Generate the unique 16-digit Recording Number.
///  2. Personalize the Blueprint picture with the Member name (surname + (C)),
///     the 16-digit Recording Number, and the four Publication Dates.
///  3. Publish the personalized picture to three locations:
///       a. the in-app LRO Publications section,
///       b. the County Facebook page (best-effort),
///       c. the Member's email address (best-effort, skipped if no email/SMTP).
///  4. Update the Member's Application Form (Recording Number + saved notice).
class LroPaymentWorkflow {
  LroPaymentWorkflow(this._db, this._activity);

  final DatabaseService _db;
  final ActivityService _activity;

  /// Runs the full LRO automation for a Member who just completed a Step 4_LRO
  /// payment.
  ///
  /// [member] — the Member who paid.
  /// [paymentDate] — the date the payment was recorded.
  /// [actorId] — the user who triggered the payment (for audit logging).
  ///
  /// Returns the updated Member (with the new Recording Number) on success.
  /// Throws [LroWorkflowException] with a descriptive message if anything fails.
  Future<Member> run({
    required Member member,
    required DateTime paymentDate,
    required String actorId,
  }) async {
    // ── Step 0: Load LRO settings ────────────────────────────────────────
    final lroService = LroSettingsService();
    final settings = await lroService.load();

    if (!settings.hasCountyUniqueNo) {
      throw const LroWorkflowException(
        'LRO not configured: County Unique Number (3 digits) is missing.',
      );
    }
    if (!settings.isValidFacebookUrl) {
      throw const LroWorkflowException(
        'LRO not configured: Facebook Page URL is missing or invalid.',
      );
    }
    if (!settings.hasBlueprint) {
      throw const LroWorkflowException(
        'LRO not configured: Blueprint Public Notice template has not been uploaded.',
      );
    }

    // ── Step 1: Generate the unique 16-digit Recording Number ────────────
    final existingNumbers = await _db.getAllLroRecordingNumbers();
    final recordingNumber = RecordingNumberService.generate(
      countyUniqueNo: settings.countyUniqueNo,
      paymentDate: paymentDate,
      order: settings.numberOrder,
      existingNumbers: existingNumbers,
    );

    // ── Step 2: Personalize the Blueprint picture ────────────────────────
    final blueprintBytes = await lroService.loadBlueprintBytes();
    if (blueprintBytes == null || blueprintBytes.isEmpty) {
      throw const LroWorkflowException(
        'Blueprint image could not be loaded. Upload it in LRO Settings.',
      );
    }

    final personalizedBytes = await _personalizeImage(
      blueprintBytes,
      member.fullName,
      recordingNumber,
      paymentDate,
    );

    // ── Step 3a: Save to in-app LRO Publications ─────────────────────────
    await _db.createLroPublication(
      memberId: member.id,
      memberName: member.fullName,
      recordingNumber: recordingNumber,
      imageBytes: personalizedBytes,
      publishedAt: paymentDate,
      actorId: actorId,
    );

    // ── Step 3b: Publish to Facebook (best-effort) ───────────────────────
    String? facebookPostId;
    try {
      facebookPostId = await _publishToFacebook(
        settings.facebookPageUrl,
        personalizedBytes,
        member.fullName,
        recordingNumber,
      );
    } catch (e) {
      await _activity.record(
        userName: 'System',
        action:
            'LRO Facebook publish failed for ${member.fullName}: $e',
        captureGps: false,
      );
    }

    // ── Step 3c: Email the Public Notice to the Member (best-effort) ──────
    LroEmailResult emailResult;
    try {
      emailResult = await LroEmailService.sendPublicNotice(
        memberEmail: member.emailAddress,
        memberName: member.fullName,
        recordingNumber: recordingNumber,
        paymentDate: paymentDate,
        imageBytes: personalizedBytes,
      );
      await _activity.record(
        userName: 'System',
        action: emailResult.sent
            ? 'LRO Public Notice emailed to ${member.emailAddress}.'
            : 'LRO email skipped for ${member.fullName}: ${emailResult.reason}',
        captureGps: false,
      );
    } catch (e) {
      emailResult = LroEmailResult(
        sent: false,
        skipped: false,
        reason: 'Email error: $e',
      );
    }

    // ── Step 3d: Save the personalized image to the Member's record ───────
    await _db.saveLroNoticeImage(
      memberId: member.id,
      recordingNumber: recordingNumber,
      imageBytes: personalizedBytes,
      publishedAt: paymentDate,
    );

    // ── Step 4: Update the Member's Application Form ──────────────────────
    final updated = member.copyWith(
      lroRecordNo: recordingNumber,
      step4LROComplete: true,
      step4CompletionDate: paymentDate,
      step4ApprovedBy: actorId,
      lastModifiedBy: actorId,
      updatedAt: paymentDate.toUtc(),
      pendingSync: true,
      lroNoticeImageBase64: _toDataUri(personalizedBytes),
    );
    await _db.upsertMember(updated);

    // ── Audit log ────────────────────────────────────────────────────────
    await _activity.record(
      userName: actorId,
      action:
          'LRO Recording Number generated for ${member.fullName}: $recordingNumber '
          '(Facebook ${facebookPostId ?? "skipped"}, Email ${emailResult.sent ? "sent" : "skipped"})',
      captureGps: false,
    );

    return updated;
  }

  String _toDataUri(Uint8List bytes) =>
      Uri.dataFromBytes(bytes, mimeType: 'image/jpeg').toString();

  /// Overlays the Member name (with (C)), the 16-digit Recording Number, and
  /// the four Publication Dates onto the Blueprint image, returning the
  /// personalized Public Notice as JPEG bytes.
  Future<Uint8List> _personalizeImage(
    Uint8List blueprint,
    String memberName,
    String recordingNumber,
    DateTime paymentDate,
  ) async {
    final nameWithC = '$memberName (C)';
    final dateStr = DateFormat('dd/MM/yyyy').format(paymentDate);

    final image = img.decodeImage(blueprint);
    if (image == null) {
      throw const LroWorkflowException(
        'Blueprint image could not be decoded. Upload a valid JPG/PNG.',
      );
    }

    final font = img.arial24;
    final textColor = img.ColorRgb8(20, 20, 20);
    final shadow = img.ColorRgb8(255, 255, 255);

    var y = (image.height * 0.10).round();
    void drawLine(String text) {
      // White shadow offset, then dark text on top for legibility.
      img.drawString(image, '  $text',
          font: font, x: 24, y: y, color: shadow);
      img.drawString(image, '  $text',
          font: font, x: 22, y: y - 2, color: textColor);
      y += 34;
    }

    drawLine(nameWithC);
    drawLine('Recording No: $recordingNumber');
    y += 10;
    drawLine('Publication Date: $dateStr');
    drawLine('Voter deregistration: $dateStr');
    drawLine('BIO Pages: $dateStr');
    drawLine('2 x Witness Testimony: $dateStr');
    drawLine('Universal Declaration: $dateStr');

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  /// Publishes the personalized image to the County's Facebook page.
  ///
  /// This is a best-effort operation. The Facebook Graph API requires a Page
  /// Access Token and Page ID which are not stored in this app, so by default
  /// this returns null (not published) and the in-app publication still
  /// succeeds. Wire a real token here when available.
  Future<String?> _publishToFacebook(
    String facebookPageUrl,
    Uint8List imageBytes,
    String memberName,
    String recordingNumber,
  ) async {
    // Real implementation would POST to:
    //   POST https://graph.facebook.com/{page-id}/photos
    //   with the image and a Page Access Token.
    // That token must be stored securely (not in SharedPreferences).
    // Until configured, publishing is skipped and the workflow continues.
    return null;
  }
}

/// Exception thrown when the LRO workflow cannot complete.
class LroWorkflowException implements Exception {
  const LroWorkflowException(this.message);
  final String message;

  @override
  String toString() => 'LroWorkflowException: $message';
}
