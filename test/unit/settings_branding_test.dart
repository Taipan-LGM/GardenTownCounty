import 'package:flutter_test/flutter_test.dart';
import 'package:garden_town_county/l10n/app_strings.dart';
import 'package:garden_town_county/models/county_profile.dart';
import 'package:garden_town_county/navigation/app_section.dart';
import 'package:garden_town_county/services/app_preferences_service.dart';

void main() {
  test('CountyProfile prefs round-trip', () {
    const profile = CountyProfile(
      countyName: 'Garden Town County',
      countyAddress: '1 Main Rd',
      countyRegNo: 'REG-1',
      countyContactNo: '0123456789',
    );
    final restored = CountyProfile.fromPrefs(profile.toPrefs());
    expect(restored.countyName, 'Garden Town County');
    expect(restored.countyAddress, '1 Main Rd');
    expect(restored.countyRegNo, 'REG-1');
    expect(restored.countyContactNo, '0123456789');
  });

  test('AppStrings switches language labels', () {
    final en = AppStrings(AppLanguage.english);
    final af = AppStrings(AppLanguage.afrikaans);
    expect(en.settings, 'Settings');
    expect(af.settings, 'Instellings');
    expect(af.memberInfo, 'Aansoekvorm');
    expect(af.drawerLabel('home'), 'Tuis');
    expect(af.drawerLabel('application_form'), 'Aansoekvorm');
    expect(af.sectionTitle(AppSection.settings), 'Instellings');
    expect(af.videos, "Video's");
    expect(af.menu, 'Kieslys');
    expect(en.menu, 'Menu');
  });
}
