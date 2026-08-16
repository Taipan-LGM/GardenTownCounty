import 'dart:typed_data';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Best-effort email delivery for the personalized LRO Public Notice.
///
/// SMTP credentials are optional. They are read from SharedPreferences
/// (configured once by an Admin in a County Settings / Email section). If no
/// SMTP server is configured, [sendPublicNotice] does NOT throw — it returns
/// false and records a clear "skipped" result so the rest of the LRO workflow
/// continues unaffected (per the design: publishing to Facebook + in-app still
/// succeeds even when email is unavailable).
class LroEmailService {
  static const String _prefix = 'lro_email_';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Saves optional SMTP configuration. Leave [password] empty to clear it.
  static Future<void> saveSmtpConfig({
    required String host,
    required int port,
    required String username,
    String? password,
    required String fromAddress,
    bool ssl = true,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('${_prefix}host', host);
    await prefs.setInt('${_prefix}port', port);
    await prefs.setString('${_prefix}username', username);
    await prefs.setString('${_prefix}from', fromAddress);
    if (password != null && password.isNotEmpty) {
      await prefs.setString('${_prefix}password', password);
    }
    await prefs.setBool('${_prefix}ssl', ssl);
  }

  static Future<void> clearSmtpConfig() async {
    final prefs = await _prefs;
    for (final k in [
      '${_prefix}host',
      '${_prefix}port',
      '${_prefix}username',
      '${_prefix}password',
      '${_prefix}from',
      '${_prefix}ssl',
    ]) {
      await prefs.remove(k);
    }
  }

  /// Returns true when an SMTP server has been configured.
  static Future<bool> isConfigured() async {
    final prefs = await _prefs;
    final host = prefs.getString('${_prefix}host');
    final user = prefs.getString('${_prefix}username');
    final pass = prefs.getString('${_prefix}password');
    final from = prefs.getString('${_prefix}from');
    return host != null &&
        host.isNotEmpty &&
        user != null &&
        user.isNotEmpty &&
        pass != null &&
        pass.isNotEmpty &&
        from != null &&
        from.isNotEmpty;
  }

  /// Sends the personalized Public Notice to the member's email address.
  ///
  /// Returns a result describing what happened. Never throws for missing
  /// configuration — instead it returns a [LroEmailResult] with
  /// [LroEmailResult.skipped] so the caller can log and continue.
  static Future<LroEmailResult> sendPublicNotice({
    required String memberEmail,
    required String memberName,
    required String recordingNumber,
    required DateTime paymentDate,
    required Uint8List imageBytes,
  }) async {
    if (memberEmail.trim().isEmpty) {
      return const LroEmailResult(
        sent: false,
        skipped: true,
        reason: 'Member has no email address on file.',
      );
    }

    final configured = await isConfigured();
    if (!configured) {
      return const LroEmailResult(
        sent: false,
        skipped: true,
        reason: 'No SMTP server configured — email delivery skipped.',
      );
    }

    final prefs = await _prefs;
    final host = prefs.getString('${_prefix}host')!;
    final port = prefs.getInt('${_prefix}port') ?? 465;
    final username = prefs.getString('${_prefix}username')!;
    final password = prefs.getString('${_prefix}password')!;
    final from = prefs.getString('${_prefix}from')!;
    final ssl = prefs.getBool('${_prefix}ssl') ?? true;

    final smtpServer = ssl
        ? SmtpServer(host, port: port, username: username, password: password)
        : SmtpServer(host,
            port: port, username: username, password: password, ignoreBadCertificate: true);

    final dateStr =
        '${paymentDate.day.toString().padLeft(2, '0')}/${paymentDate.month.toString().padLeft(2, '0')}/${paymentDate.year}';

    final message = Message()
      ..from = Address(from, 'Garden Town County — Land Recording Office')
      ..recipients.add(memberEmail)
      ..subject = 'Your Land Recording Office Public Notice — $recordingNumber'
      ..text = 'Dear $memberName,\n\n'
          'Please find attached your personalized Land Recording Office '
          'Public Notice.\n\n'
          'Recording Number: $recordingNumber\n'
          'Publication Date: $dateStr\n\n'
          'Kind regards,\n'
          'Garden Town County — Land Recording Office'
      ..attachments.add(
        StreamAttachment(
          Stream.value(imageBytes),
          'image/jpeg',
          fileName: 'LRO_Public_Notice_$recordingNumber.jpg',
        ),
      );

    try {
      final sendReport = await send(message, smtpServer);
      return LroEmailResult(
        sent: true,
        skipped: false,
        reason: sendReport.toString(),
      );
    } catch (e) {
      return LroEmailResult(
        sent: false,
        skipped: false,
        reason: 'SMTP send failed: $e',
      );
    }
  }
}

/// Outcome of an email delivery attempt.
class LroEmailResult {
  const LroEmailResult({
    required this.sent,
    required this.skipped,
    required this.reason,
  });

  final bool sent;
  final bool skipped;
  final String reason;
}
