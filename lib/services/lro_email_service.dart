import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Best-effort email delivery for the personalized LRO Public Notice.
///
/// SMTP configuration is stored split across two stores:
///   * SharedPreferences holds the non-secret fields (host, port, username,
///     from address, from name, TLS flag).
///   * [FlutterSecureStorage] holds the SMTP password in the OS keychain /
///     encrypted container (never plaintext on disk).
///
/// If no SMTP server is configured, [sendPublicNotice] does NOT throw — it
/// returns a [LroEmailResult] with [LroEmailResult.skipped] so the rest of the
/// LRO workflow continues (per design: in-app + Facebook still succeed).
class LroEmailService {
  static const String _prefix = 'lro_email_';
  static const String _securePasswordKey = 'lro_email_smtp_password';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    // Web: uses localStorage; native: OS keychain/keystore.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  /// Saves the SMTP configuration. The password is stored in the OS secure
  /// store; all other fields in SharedPreferences.
  static Future<void> saveSmtpConfig({
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromAddress,
    required String fromName,
    bool ssl = true,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('${_prefix}host', host.trim());
    await prefs.setInt('${_prefix}port', port);
    await prefs.setString('${_prefix}username', username.trim());
    await prefs.setString('${_prefix}from', fromAddress.trim());
    await prefs.setString('${_prefix}fromName', fromName.trim());
    await prefs.setBool('${_prefix}ssl', ssl);
    // Password lives only in the secure store.
    await _secure.write(key: _securePasswordKey, value: password);
  }

  static Future<void> clearSmtpConfig() async {
    final prefs = await _prefs;
    for (final k in [
      '${_prefix}host',
      '${_prefix}port',
      '${_prefix}username',
      '${_prefix}from',
      '${_prefix}fromName',
      '${_prefix}ssl',
    ]) {
      await prefs.remove(k);
    }
    await _secure.delete(key: _securePasswordKey);
  }

  /// Loads the stored SMTP configuration (password read from the secure store).
  static Future<LroSmtpConfig?> loadSmtpConfig() async {
    final prefs = await _prefs;
    final host = prefs.getString('${_prefix}host');
    final port = prefs.getInt('${_prefix}port');
    final username = prefs.getString('${_prefix}username');
    final from = prefs.getString('${_prefix}from');
    if (host == null ||
        host.isEmpty ||
        port == null ||
        username == null ||
        username.isEmpty ||
        from == null ||
        from.isEmpty) {
      return null;
    }
    final password = await _secure.read(key: _securePasswordKey) ?? '';
    final fromName = prefs.getString('${_prefix}fromName') ?? '';
    final ssl = prefs.getBool('${_prefix}ssl') ?? true;
    return LroSmtpConfig(
      host: host,
      port: port,
      username: username,
      password: password,
      fromAddress: from,
      fromName: fromName,
      ssl: ssl,
    );
  }

  /// Returns true when a complete SMTP server has been configured.
  static Future<bool> isConfigured() async =>
      (await loadSmtpConfig()) != null;

  /// Sends a test email to [recipient] using the stored (or supplied) config.
  /// Used by the SMTP Settings screen to validate before saving.
  /// Returns a result describing success/failure with a human-readable reason.
  static Future<LroEmailResult> testConnection({
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromAddress,
    required String fromName,
    required bool ssl,
    required String recipient,
  }) async {
    if (recipient.trim().isEmpty) {
      return const LroEmailResult(
        sent: false,
        skipped: false,
        reason: 'Enter a test recipient email address.',
      );
    }
    final smtpServer = ssl
        ? SmtpServer(host,
            port: port, username: username, password: password)
        : SmtpServer(host,
            port: port,
            username: username,
            password: password,
            ignoreBadCertificate: true);

    final message = Message()
      ..from = Address(fromAddress, fromName.isNotEmpty ? fromName : null)
      ..recipients.add(recipient.trim())
      ..subject = 'Garden Town County — LRO SMTP Test'
      ..text = 'This is a test email from the Garden Town County '
          'Land Recording Office. If you received this, SMTP is working.';

    try {
      final report = await send(message, smtpServer);
      return LroEmailResult(sent: true, skipped: false, reason: report.toString());
    } catch (e) {
      return LroEmailResult(
        sent: false,
        skipped: false,
        reason: _describeSmtpError(e),
      );
    }
  }

  /// Sends the personalized Public Notice to the member's email address.
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

    final config = await loadSmtpConfig();
    if (config == null) {
      return const LroEmailResult(
        sent: false,
        skipped: true,
        reason: 'No SMTP server configured — email delivery skipped.',
      );
    }

    final smtpServer = config.ssl
        ? SmtpServer(config.host,
            port: config.port,
            username: config.username,
            password: config.password)
        : SmtpServer(config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            ignoreBadCertificate: true);

    final dateStr =
        '${paymentDate.day.toString().padLeft(2, '0')}/${paymentDate.month.toString().padLeft(2, '0')}/${paymentDate.year}';

    final message = Message()
      ..from = Address(config.fromAddress,
          config.fromName.isNotEmpty ? config.fromName : null)
      ..recipients.add(memberEmail.trim())
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
        reason: _describeSmtpError(e),
      );
    }
  }

  /// Translates common mailer exceptions into friendly messages.
  static String _describeSmtpError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('authentication') || msg.contains('535') || msg.contains('login')) {
      return 'Authentication failed — check the SMTP username and password.';
    }
    if (msg.contains('connection') || msg.contains('refused') || msg.contains('timed out') || msg.contains('host')) {
      return 'Connection refused — check the SMTP host and port.';
    }
    if (msg.contains('certificate') || msg.contains('tls') || msg.contains('ssl')) {
      return 'TLS/SSL error — verify the Enable TLS/SSL toggle matches your provider.';
    }
    return 'SMTP send failed: $e';
  }
}

/// Stored SMTP configuration.
class LroSmtpConfig {
  const LroSmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromAddress,
    required this.fromName,
    required this.ssl,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String fromAddress;
  final String fromName;
  final bool ssl;
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
