import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/lro_status_correction.dart' as sc;
import '../models/member.dart';
import '../models/lro_settings.dart';
import '../services/lro_notice_renderer.dart';
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
    this._countySvc, {
    this.countyId = '',
  });

  final DatabaseService _db;
  final ActivityService _activity;
  final LroSettingsService _lroService;
  final CountySettingsService _countySvc;

  /// Active county id — scopes LRO settings, seal, template and county profile
  /// so a non-default county publishes its own notice correctly.
  final String countyId;

  /// Prepares a Member's LRO record when Step 4_LRO payment is completed.
  ///
  /// Performs the configuration checks, generates the unique 16-digit
  /// Recording Number, and personalizes the Public Notice image. It stores the
  /// Recording Number, the notice image, and marks Step 4_LRO complete on the
  /// Member — but it does NOT publish. Publishing is a separate, explicit step
  /// triggered from the "LRO Publication" button (see [publish]).
  ///
  /// Returns the updated Member (with the new Recording Number + notice image).
  /// Throws [LroWorkflowException] if LRO is not configured.
  Future<Member> prepare({
    required Member member,
    required DateTime paymentDate,
    required String actorId,
  }) async {
    final settings = await _lroService.load(countyId: countyId);
    if (!settings.hasCountyUniqueNo) {
      throw const LroWorkflowException(
        'LRO not configured: County Unique Number (3 digits) is missing.',
      );
    }
    if (!settings.hasPublicNoticeTemplate) {
      throw const LroWorkflowException(
        'LRO not configured: a Public Notice Template has not been created or uploaded '
        'in LRO Settings.',
      );
    }

    final existingNumbers = await _db.getAllLroRecordingNumbers();
    final recordingNumber = RecordingNumberService.generate(
      countyUniqueNo: settings.countyUniqueNo,
      paymentDate: paymentDate,
      order: settings.numberOrder,
      existingNumbers: existingNumbers,
    );

    final countyProfile = await _countySvc.load(countyId: countyId);
    final countyName = countyProfile.countyName.trim().isNotEmpty
        ? countyProfile.countyName.trim()
        : 'Garden Town County';

    final noticeBytes = await _renderNoticeBytes(
      member: member,
      recordingNumber: recordingNumber,
      paymentDate: paymentDate,
      settings: settings,
      countyName: countyName,
    );

    final updated = member.copyWith(
      lroRecordNo: recordingNumber,
      step4LROComplete: true,
      step4CompletionDate: paymentDate,
      step4ApprovedBy: actorId,
      lastModifiedBy: actorId,
      updatedAt: paymentDate.toUtc(),
      pendingSync: true,
      lroNoticeImageBase64: _toDataUri(noticeBytes),
    );
    await _db.upsertMember(updated);
    return updated;
  }

  /// Publishes the previously-prepared Personal Public Notice for a Member.
  ///
  /// This is the explicit "LRO Publication" action. It:
  ///   a. saves the notice to the in-app LRO Publications section,
  ///   b. posts to the County Facebook page (best-effort),
  ///   c. emails the Member (best-effort),
  ///   d. writes the notice image to the Member's Application Form, and
  ///   e. stamps the publication date + actor, and marks the payment complete.
  ///
  /// Publishing is fail-graceful: a single destination failure does not roll
  /// back the others. Returns the updated Member.
  Future<Member> publish({
    required Member member,
    required String actorId,
  }) async {
    if (member.lroRecordNo == null || member.lroRecordNo!.isEmpty) {
      throw const LroWorkflowException(
        'Cannot publish: no Recording Number. Complete Step 4_LRO payment first.',
      );
    }

    final settings = await _lroService.load(countyId: countyId);
    final countyProfile = await _countySvc.load(countyId: countyId);
    final countyName = countyProfile.countyName.trim().isNotEmpty
        ? countyProfile.countyName.trim()
        : 'Garden Town County';

    final noticeBytes = await _renderNoticeBytes(
      member: member,
      recordingNumber: member.lroRecordNo!,
      paymentDate: member.step4CompletionDate ?? DateTime.now(),
      settings: settings,
      countyName: countyName,
    );

    // a. in-app LRO Publications
    await _db.createLroPublication(
      memberId: member.id,
      memberName: member.fullName,
      recordingNumber: member.lroRecordNo!,
      imageBytes: noticeBytes,
      publishedAt: DateTime.now(),
      actorId: actorId,
    );

    // b. Facebook (best-effort)
    String? facebookPostId;
    try {
      facebookPostId = await _publishToFacebook(
        settings.facebookPageUrl,
        noticeBytes,
        member.fullName,
        member.lroRecordNo!,
      );
    } catch (e) {
      await _activity.record(
        userName: 'System',
        action: 'LRO Facebook publish failed for ${member.fullName}: $e',
        captureGps: false,
      );
    }

    // c. Email (best-effort)
    try {
      final emailResult = await LroEmailService.sendPublicNotice(
        memberEmail: member.emailAddress,
        memberName: member.fullName,
        recordingNumber: member.lroRecordNo!,
        paymentDate: member.step4CompletionDate ?? DateTime.now(),
        imageBytes: noticeBytes,
      );
      await _activity.record(
        userName: 'System',
        action: emailResult.sent
            ? 'LRO Public Notice emailed to ${member.emailAddress}.'
            : 'LRO email skipped for ${member.fullName}: ${emailResult.reason}',
        captureGps: false,
      );
    } catch (e) {
      await _activity.record(
        userName: 'System',
        action: 'LRO email error for ${member.fullName}: $e',
        captureGps: false,
      );
    }

    // d. Member Application Form record
    await _db.saveLroNoticeImage(
      memberId: member.id,
      recordingNumber: member.lroRecordNo!,
      imageBytes: noticeBytes,
      publishedAt: DateTime.now(),
    );

    // e. Stamp + audit
    final publishedAt = DateTime.now();
    final updated = member.copyWith(
      lroPublicationDate: publishedAt,
      lroPublishedBy: actorId,
      lastModifiedBy: actorId,
      updatedAt: publishedAt.toUtc(),
      pendingSync: true,
      lroNoticeImageBase64: _toDataUri(noticeBytes),
    );
    await _db.upsertMember(updated);

    await _activity.record(
      userName: actorId,
      action:
          'LRO Public Notice published for ${member.fullName}: ${member.lroRecordNo} '
          '(Facebook ${facebookPostId ?? 'skipped'}, Publications, Member Form)',
      captureGps: false,
    );

    return updated;
  }

  /// Renders the personalized Public Notice image for [member].
  ///
  /// Uses the parametric template renderer when an Admin-designed template
  /// exists, otherwise falls back to the legacy image-overlay path.
  Future<Uint8List> _renderNoticeBytes({
    required Member member,
    required String recordingNumber,
    required DateTime paymentDate,
    required LroSettings settings,
    required String countyName,
  }) async {
    if (settings.noticeTemplate != null) {
      final sealBytes = await _lroService.loadCountySealBytes(countyId: countyId);
      return LroNoticeRenderer.render(
        style: settings.noticeTemplate!,
        countyName: countyName,
        memberName: member.fullName,
        recordingNumber: recordingNumber,
        paymentDate: paymentDate,
        statusCorrections: settings.statusCorrections,
        sealBytes:
            (sealBytes != null && sealBytes.isNotEmpty) ? sealBytes : null,
      );
    } else {
      final templateBytes = await _lroService.loadPublicNoticeTemplateBytes(
        countyId: countyId,
      );
      if (templateBytes == null || templateBytes.isEmpty) {
        throw const LroWorkflowException(
          'Public Notice Template image could not be loaded. Upload it in LRO Settings.',
        );
      }
      return await _personalizeImage(
        templateBytes,
        countyName: countyName,
        memberName: member.fullName,
        recordingNumber: recordingNumber,
        paymentDate: paymentDate,
        statusCorrections: settings.statusCorrections,
      );
    }
  }

  /// Public wrapper around the legacy template-image overlay, used by the
  /// review dialog when no parametric template exists.
  Future<Uint8List> renderLegacyOverlay(
    Uint8List templateBytes, {
    required String countyName,
    required String memberName,
    required String recordingNumber,
    required DateTime paymentDate,
    required List<sc.LroStatusCorrection> statusCorrections,
  }) =>
      _personalizeImage(
        templateBytes,
        countyName: countyName,
        memberName: memberName,
        recordingNumber: recordingNumber,
        paymentDate: paymentDate,
        statusCorrections: statusCorrections,
      );

  /// Backwards-compatible convenience: prepare then publish in one call.
  Future<Member> run({
    required Member member,
    required DateTime paymentDate,
    required String actorId,
  }) async {
    final prepared = await prepare(
      member: member,
      paymentDate: paymentDate,
      actorId: actorId,
    );
    return await publish(member: prepared, actorId: actorId);
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
    final sealBytes = await this._lroService.loadCountySealBytes(
      countyId: countyId,
    );
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
