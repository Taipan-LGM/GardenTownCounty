import '../services/app_preferences_service.dart';

/// Minimal EN/AF string table for Settings + drawer.
class AppStrings {
  AppStrings(this.lang);

  final AppLanguage lang;

  bool get isAf => lang == AppLanguage.afrikaans;

  String get appName =>
      isAf ? 'Garden Town County' : 'Garden Town County';

  String get home => isAf ? 'Tuis' : 'Home';
  String get search => isAf ? 'Soek' : 'Search';
  String get settings => isAf ? 'Instellings' : 'Settings';
  String get memberInfo => isAf ? '1_Lid Info' : '1_Member Info';
  String get sos => 'SOS';
  String get global528 => '2_Global 528';
  String get global928 => '3_Global 928';
  String get lro => '4_LRO';
  String get backupRestore =>
      isAf ? 'Rugsteun & Herstel' : 'Backup & Restore';
  String get addUser => isAf ? 'Voeg Gebruiker By' : 'Add User';
  String get userManagement =>
      isAf ? 'Gebruikerbestuur' : 'User Management';
  String get reminders => isAf ? 'Herinnerings' : 'Reminders';
  String get activities => isAf ? 'Aktiwiteite' : 'Activities';
  String get signOut => isAf ? 'Teken uit' : 'Sign out';

  String get theme => isAf ? 'Tema' : 'Theme';
  String get light => isAf ? 'Lig' : 'Light';
  String get dark => isAf ? 'Donker' : 'Dark';
  String get language => isAf ? 'Taal' : 'Language';
  String get english => 'English';
  String get afrikaans => 'Afrikaans';

  String get countyInfo =>
      isAf ? 'County Inligting' : 'County Information';
  String get countyName => isAf ? 'County naam' : 'County name';
  String get countyAddress =>
      isAf ? 'County adres' : 'County Address';
  String get countyRegNo =>
      isAf ? 'County reg. nr.' : 'County reg. no.';
  String get countyContactNo =>
      isAf ? 'County kontaknr.' : 'County Contact no.';
  String get uploadLogo =>
      isAf ? 'Laai eerste logo op' : 'Upload first (background) logo';
  String get uploadSecondaryLogo =>
      isAf ? 'Laai tweede logo op' : 'Upload second (corner) logo';
  String get save => isAf ? 'Stoor' : 'Save';
  String get continueLabel => isAf ? 'Gaan voort' : 'Continue';

  String get backupCenter =>
      isAf ? 'Rugsteun & Herstel Sentrum' : 'Backup & Restore Center';
  String get localBackup =>
      isAf ? 'Plaaslike rugsteun' : 'Local Backup';
  String get externalBackup =>
      isAf ? 'Eksterne / Netwerk-skyf' : 'External / Network Drive';
  String get restore => isAf ? 'Herstel' : 'Restore';
  String get createBackup =>
      isAf ? 'Skep rugsteun nou' : 'Create Backup Now';
  String get restoreFromBackup =>
      isAf ? 'Herstel vanaf rugsteun' : 'Restore from Backup';
  String get enableLocalBackup =>
      isAf ? 'Aktiveer plaaslike rugsteun op hierdie PC' : 'Enable Local Backup on this PC';
}
