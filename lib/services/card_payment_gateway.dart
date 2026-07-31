import 'dart:convert';

import 'package:http/http.dart' as http;

class CardPaymentResult {
  const CardPaymentResult({
    required this.transactionId,
    required this.receiptNumber,
    required this.gateway,
  });

  final String transactionId;
  final String receiptNumber;
  final String gateway;
}

class CardPaymentGateway {
  CardPaymentGateway({http.Client? client}) : _client = client ?? http.Client();

  static const String _apiUrl = String.fromEnvironment(
    'CARD_PAYMENT_API_URL',
  );

  final http.Client _client;

  bool get isConfigured => _apiUrl.trim().isNotEmpty;

  Future<CardPaymentResult> authorize({
    required String memberId,
    required String memberName,
    required int stepNumber,
    required double amount,
    required String requestedBy,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Card payments are not configured. Start the app with '
        '--dart-define=CARD_PAYMENT_API_URL=https://your-secure-api/payments/card.',
      );
    }

    final response = await _client
        .post(
          Uri.parse(_apiUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'memberId': memberId,
            'memberName': memberName,
            'stepNumber': stepNumber,
            'amount': amount,
            'currency': 'ZAR',
            'requestedBy': requestedBy,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Card gateway declined the request (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = payload['status']?.toString().toLowerCase();
    final transactionId = payload['transactionId']?.toString().trim() ?? '';
    if (status != 'approved' || transactionId.isEmpty) {
      throw StateError(payload['message']?.toString() ?? 'Card payment was not approved.');
    }

    return CardPaymentResult(
      transactionId: transactionId,
      receiptNumber: payload['receiptNumber']?.toString().trim().isNotEmpty == true
          ? payload['receiptNumber'].toString().trim()
          : transactionId,
      gateway: payload['gateway']?.toString().trim().isNotEmpty == true
          ? payload['gateway'].toString().trim()
          : 'card',
    );
  }
}