import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/core/constants/app_constants.dart';
import 'package:garden_town_county/models/member.dart';

void main() {
  test('app constants expose logo asset and demo credentials', () {
    expect(AppConstants.logoAsset, contains('county_logo'));
    expect(AppConstants.demoUsername, isNotEmpty);
    expect(AppConstants.saIdMaxLength, 13);
    expect(AppConstants.globalRecordNoMaxLength, 14);
    expect(AppConstants.contactNoMaxLength, 12);
  });

  test('member firestore payload omits local pendingSync flag', () {
    final member = Member.create(
      saId: '9001015009087',
      globalRecordNo: 'GTC-0000000001',
      memberName: 'A',
      surname: 'B',
    );
    final payload = member.toFirestore();
    expect(payload.containsKey('pendingSync'), isFalse);
    expect(payload['saId'], '9001015009087');
  });
}
