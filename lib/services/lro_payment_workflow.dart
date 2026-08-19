import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/lro_status_correction.dart' as sc;
import '../models/member.dart';
import '../services/county_settings_service.dart';
import '../services/database_service.dart';
import '../services/lro_settings_service.dart';
import '../services/recording_number_service.dart';
import '../services/activity_service.dart';
import '../services/lro_email_service.dart';

/// Handles the automated LRO (Land Recording Office) workflow that runs after a
/// Step 4_LRO payment is recorded.
///
/// Sequence (per the Garden Town County LRO design plan):
///  1. Generate the unique 16-digit Recording Number.
///  2. Personalize the Public Notice Template with the County Name (auto-filled
///     from County Settings), the Member name (surname + "(C)"), the 16-digit
///     Recording Number, the Date of Registration, and the Admin-defined list of
///     Status Corrections (each prefixed with a green check), then overlay the
///     County Seal at the bottom of the notice.
///  3. Publish the personalized picture to three locations:
///       a. the in-app LRO Publications section,
///       b. the County Facebook page (best-effort),
///       c. the Member's email address (best-effort, skipped if no email/SMTP).
///  4. Update the Member's Application Form (Recording Number + saved notice).
class LroPaymentWorkflow {
  LroPaymentWorkflow(
    this._db,
    this._activity,
    this._lroService,
    this._countySvc,
  );

  final DatabaseService _db;
  final ActivityService _activity;
  final LroSettingsService _lroService;
  final CountySettingsService _countySvc;

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
    final settings = await _lroService.load();

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
    if (!settings.hasPublicNoticeTemplate) {
      throw const LroWorkflowException(
        'LRO not configured: Public Notice Template has not been uploaded.',
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

    // ── Step 2: Personalize the Public Notice Template ───────────────────
    final templateBytes = await this._lroService.loadPublicNoticeTemplateBytes();
    if (templateBytes == null || templateBytes.isEmpty) {
      throw const LroWorkflowException(
        'Public Notice Template image could not be loaded. Upload it in LRO Settings.',
      );
    }

    final countyProfile = await _countySvc.load();
    final countyName = countyProfile.countyName.trim().isNotEmpty
        ? countyProfile.countyName.trim()
        : 'Garden Town County';

    final personalizedBytes = await _personalizeImage(
      templateBytes,
      countyName: countyName,
      memberName: member.fullName,
      recordingNumber: recordingNumber,
      paymentDate: paymentDate,
      statusCorrections: settings.statusCorrections,
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

  /// Overlays the dynamic Public Notice content onto the uploaded Template image
  /// and returns the personalized notice as JPEG bytes.
  ///
  /// Per the design plan, the notice shows:
  ///  - the County Name (auto-filled from County Settings),
  ///  - the Member name with a "(C)" suffix,
  ///  - the 16-digit Recording Number,
  ///  - the Date of Registration,
  ///  - the Admin-defined Status Corrections (each prefixed with a green check,
  ///    with NO date attached), and
  ///  - the County Seal overlaid at the bottom of the notice (the only element
  ///    at the bottom).
  Future<Uint8List> _personalizeImage(
    Uint8List templateBytes, {
    required String countyName,
    required String memberName,
    required String recordingNumber,
    required DateTime paymentDate,
    required List<sc.LroStatusCorrection> statusCorrections,
  }) async {
    final nameWithC = '$memberName (C)';
    final dateStr = DateFormat('dd/MM/yyyy').format(paymentDate);
    final checked = statusCorrections.where((c) => c.isChecked).toList();

    final image = img.decodeImage(templateBytes);
    if (image == null) {
      throw const LroWorkflowException(
        'Public Notice Template image could not be decoded. Upload a valid JPG/PNG.',
      );
    }

    final font = img.arial24;
    final textColor = img.ColorRgb8(20, 20, 20);
    final shadow = img.ColorRgb8(255, 255, 255);
    final checkColor = img.ColorRgb8(33, 150, 83); // green

    // Reserve the bottom ~24% of the image for the County Seal (the only
    // element allowed at the bottom per the design plan).
    final sealReserve = (image.height * 0.24).round();
    final textBottomLimit = image.height - sealReserve;

    var y = (image.height * 0.07).round();

    void drawLine(String text) {
      if (y > textBottomLimit - 30) return; // never collide with the seal
      // White shadow offset, then dark text on top for legibility.
      img.drawString(image, '  $text', x: 24, y: y, font: font, color: shadow);
      img.drawString(image, '  $text', x: 22, y: y - 2, font: font, color: textColor);
      y += 34;
    }

    void drawCheck(int cx, int cy, int size) {
      final t = (size / 7).round().clamp(2, 5);
      // Two segments forming a check (✓) in green.
      img.drawLine(
        image,
        x1: cx - size ~/ 2,
        y1: cy,
        x2: cx - size ~/ 6,
        y2: cy + size ~/ 3,
        color: checkColor,
        thickness: t,
      );
      img.drawLine(
        image,
        x1: cx - size ~/ 6,
        y1: cy + size ~/ 3,
        x2: cx + size ~/ 2,
        y2: cy - size ~/ 3,
        color: checkColor,
        thickness: t,
      );
    }

    // ── Header: County Name (auto-filled) ────────────────────────────────
    drawLine(countyName);
    drawLine('Land Recording Office');
    y += 12;

    // ── Member details ───────────────────────────────────────────────────
    drawLine('This is to confirm that:');
    y += 8;
    drawLine('Member: $nameWithC');
    drawLine('Recording Number: $recordingNumber');
    drawLine('Date of Registration: $dateStr');
    y += 14;

    // ── Status Corrections (descriptions only, no dates) ─────────────────
    drawLine('Is Status Corrected - 528:');
    if (checked.isEmpty) {
      y += 6;
      drawLine('  (none)');
    } else {
      for (final c in checked) {
        final desc = c.description.trim();
        if (desc.isEmpty) continue;
        // Draw the green check to the left of the description.
        drawCheck(40, y + 16, 22);
        drawLine('  $desc');
      }
    }

    // ── Overlay the County Seal at the bottom-center ─────────────────────
    final sealBytes = await this._lroService.loadCountySealBytes();
    if (sealBytes != null && sealBytes.isNotEmpty) {
      final seal = img.decodeImage(sealBytes);
      if (seal != null) {
        // Scale the seal to ~20% of the image width, preserving aspect ratio.
        final maxW = (image.width * 0.20).round().clamp(40, 400);
        final scale = maxW / seal.width;
        final sealW = maxW;
        final sealH = (seal.height * scale).round();
        final resized = img.copyResize(seal, width: sealW, height: sealH);
        final dstX = ((image.width - sealW) ~/ 2).clamp(0, image.width - 1);
        final dstY = (image.height - sealH - (image.height * 0.03).round())
            .clamp(0, image.height - 1);
        img.compositeImage(
          image,
          resized,
          dstX: dstX,
          dstY: dstY,
          blend: img.BlendMode.alpha,
        );
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  /// Publishes the personalized image to the County's Facebook page.
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
