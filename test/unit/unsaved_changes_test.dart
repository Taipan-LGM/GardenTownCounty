import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/widgets/member_nav/unsaved_changes_dialog.dart';

void main() {
  test('UnsavedChangesAction has save/discard/stay', () {
    expect(UnsavedChangesAction.values, contains(UnsavedChangesAction.save));
    expect(UnsavedChangesAction.values, contains(UnsavedChangesAction.discard));
    expect(UnsavedChangesAction.values, contains(UnsavedChangesAction.stay));
  });
}
