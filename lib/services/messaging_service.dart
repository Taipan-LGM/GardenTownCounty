import 'package:url_launcher/url_launcher.dart';

import '../models/member.dart';

enum MessageChannel { whatsapp, email }

class MessagingService {
  Future<void> send({
    required MessageChannel channel,
    required String message,
    required List<Member> recipients,
  }) async {
    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty.');
    }
    if (recipients.isEmpty) {
      throw Exception('Select at least one recipient.');
    }

    for (final member in recipients) {
      switch (channel) {
        case MessageChannel.whatsapp:
          await _sendWhatsApp(member, message);
        case MessageChannel.email:
          await _sendEmail(member, message);
      }
    }
  }

  Future<void> _sendWhatsApp(Member member, String message) async {
    final phone = _normalizePhone(member.contactNo1.isNotEmpty
        ? member.contactNo1
        : member.contactNo2);
    if (phone == null) {
      throw Exception('No valid phone for ${member.fullName}.');
    }

    final uri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
    final fallback = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Unable to open WhatsApp for ${member.fullName}.');
    }
  }

  Future<void> _sendEmail(Member member, String message) async {
    final email = member.emailAddress.trim();
    if (email.isEmpty) {
      throw Exception('No email for ${member.fullName}.');
    }

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Garden Town County Assembly — SOS',
        'body': message,
      },
    );

    if (!await launchUrl(uri)) {
      throw Exception('Unable to open email client for ${member.fullName}.');
    }
  }

  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+')) {
      return digits.substring(1);
    }
    if (digits.startsWith('0') && digits.length >= 10) {
      // South Africa default country code.
      return '27${digits.substring(1)}';
    }
    return digits;
  }
}
