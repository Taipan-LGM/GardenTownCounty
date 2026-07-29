import '../navigation/app_section.dart';
import '../services/app_preferences_service.dart';

/// EN/AF string table — keep drawer IDs and section titles in sync here.
class AppStrings {
  AppStrings(this.lang);

  final AppLanguage lang;

  bool get isAf => lang == AppLanguage.afrikaans;

  String get appName => 'Garden Town County';

  String get home => isAf ? 'Tuis' : 'Home';
  String get search => isAf ? 'Soek' : 'Search';
  String get settings => isAf ? 'Instellings' : 'Settings';
  String get videos => isAf ? "Video's" : 'Videos';
  String get info => isAf ? 'Inligting' : 'Info';
  String get menu => isAf ? 'Kieslys' : 'Menu';

  String get memberInfo =>
      isAf ? 'Aansoekvorm' : 'Application Form';
  String get memberInfoForm =>
      isAf ? 'Lid-aansoekvorm' : 'Member Application Form';
  String get sos => 'SOS';
  String get global528 => 'Step 1_Global 528';
  String get global528Step2 => 'Step 2_Global 528';
  String get global928 => 'Step 3_Global 928';
  String get lro => 'Step 4_LRO';
  String get credentialCard => 'Step 5_Credential Card';
  String get backupRestore =>
      isAf ? 'Rugsteun & Herstel' : 'Backup & Restore';
  String get addUser => isAf ? 'Voeg Gebruiker By' : 'Add User';
  String get userManagement => isAf ? 'RS Regte' : 'RS Rights';
  String get userManagementForm =>
      isAf ? 'Opnamesekretaris-regte' : 'Recording Secretary Rights';
  String get reminders => isAf ? 'Herinnerings' : 'Reminders';
  String get activities => isAf ? 'Aktiwiteite' : 'Activities';
  String get signOut => isAf ? 'Teken uit' : 'Sign Out';
  String get cancellations => isAf ? 'Kansellasies' : 'Cancellations';
  String get duplicateManagement =>
      isAf ? 'Duplikaatbestuurder' : 'Duplicate Manager';
  String get demoData => isAf ? 'Demo-data' : 'Demo Data';
  String get demoDataSubtitle => isAf
      ? 'Skep 10 demo-lede'
      : 'Generate 10 demo members';
  String get countyVideos => isAf ? "County-video's" : 'County Videos';
  String get countyInfoShort => isAf ? 'County-inligting' : 'County Info';

  String get theme => isAf ? 'Tema' : 'Theme';
  String get light => isAf ? 'Lig' : 'Light';
  String get dark => isAf ? 'Donker' : 'Dark';
  String get language => isAf ? 'Taal' : 'Language';
  String get english => 'English';
  String get afrikaans => 'Afrikaans';
  String get languageApplied => isAf
      ? 'Taal gestel na Afrikaans'
      : 'Language set to English';

  String get countyInfo =>
      isAf ? 'County-inligting' : 'County Information';
  String get countyName => isAf ? 'County-naam' : 'County name';
  String get countyAddress =>
      isAf ? 'County-adres' : 'County Address';
  String get countyRegNo =>
      isAf ? 'County reg. nr.' : 'County reg. no.';
  String get countyContactNo =>
      isAf ? 'County kontaknr.' : 'County Contact no.';
  String get uploadLogo =>
      isAf ? 'Laai eerste logo op' : 'Upload first (background) logo';
  String get uploadSecondaryLogo =>
      isAf ? 'Laai tweede logo op' : 'Upload second (corner) logo';
  String get save => isAf ? 'Stoor' : 'Save';
  String get cancel => isAf ? 'Kanselleer' : 'Cancel';
  String get edit => isAf ? 'Wysig' : 'Edit';
  String get delete => isAf ? 'Skrap' : 'Delete';
  String get close => isAf ? 'Maak toe' : 'Close';
  String get continueLabel => isAf ? 'Gaan voort' : 'Continue';
  String get guest => isAf ? 'Gas' : 'Guest';
  String get notSet => isAf ? 'Nie gestel nie' : 'Not set';
  String get requiredField => isAf ? 'Verpligtend' : 'Required';

  // Login
  String get signIn => isAf ? 'Teken in' : 'Sign In';
  String get signInToContinue =>
      isAf ? 'Teken in om voort te gaan' : 'Sign in to continue';
  String get usernameOrEmail =>
      isAf ? 'Gebruikersnaam / E-pos' : 'Username / Email';
  String get password => isAf ? 'Wagwoord' : 'Password';
  String get mustAcceptAgreement => isAf
      ? 'Jy moet die vertroulikheidsooreenkoms aanvaar.'
      : 'You must accept the confidentiality agreement.';

  // Settings extras
  String get countySettingsLogos =>
      isAf ? 'County-instellings (logos)' : 'County Settings (logos)';
  String get rsRemuneration =>
      isAf ? 'RS-vergoeding' : 'RS Remuneration';
  String get rsRemunerationSubtitle => isAf
      ? 'Stel Opnamesekretaris-betalingsbedrae'
      : 'Configure Recording Secretary payment amounts';
  String get remunerationDashboard =>
      isAf ? 'Vergoedingspaneel' : 'Remuneration Dashboard';
  String get remunerationDashboardSubtitle => isAf
      ? 'Hangende / goedgekeur / betaal oorsig'
      : 'Pending / approved / paid overview';
  String get generateTestData =>
      isAf ? 'Genereer toetsdata' : 'Generate Test Data';
  String get generateTestDataSubtitle => isAf
      ? 'Sekretarisse, lede, herinnerings, vergoeding'
      : 'Secretaries, members, reminders, remuneration';
  String get adminOnlyCountySettings => isAf
      ? 'Teken in as Admin om County-instellings (logos) oop te maak.'
      : 'Sign in as Admin to open County Settings (logos).';
  String get countySettings =>
      isAf ? 'County-instellings' : 'County Settings';
  String get logosAdmin => isAf ? 'Logos (Admin)' : 'Logos (Admin)';
  String get firstLogo => isAf ? 'Eerste logo' : 'First logo';
  String get secondLogo => isAf ? 'Tweede logo' : 'Second logo';
  String get registerNewCounty =>
      isAf ? 'Registreer nuwe county' : 'Register New County';
  String get saving => isAf ? 'Stoor tans...' : 'Saving...';

  // Common dialogs
  String get signOutConfirm => isAf
      ? 'Is jy seker jy wil uitteken?'
      : 'Are you sure you want to sign out?';
  String get unsavedChanges =>
      isAf ? '⚠ Ongestoorde veranderinge' : '⚠️ Unsaved Changes';
  String get saveOrCancelFirst => isAf
      ? 'Stoor of kanselleer eers wysigings'
      : 'Please save or cancel edits first';
  String get uploadFiles => isAf ? 'Laai lêers op' : 'Upload Files';
  String get cancelMembership =>
      isAf ? 'Kanselleer lidmaatskap' : 'Cancel Membership';
  String get filterAll => isAf ? 'Alles' : 'All';
  String get filterNew => isAf ? 'Nuut' : 'New';
  String get filterRs => 'RS';
  String get memberName => isAf ? 'Lidnaam' : 'Member Name';
  String get suburb => isAf ? 'Voorstad' : 'Suburb';
  String get townCity => isAf ? 'Dorp / Stad' : 'Town / City';
  String get postalCode => isAf ? 'Poskode' : 'Postal Code';
  String get lroRecordNo => isAf ? 'LRO-rekordnr.' : 'LRO Record No.';
  String get backupOverdue => isAf
      ? 'Dit is 7 dae sedert jou laaste rugsteun. Maak asseblief \'n rugsteun.'
      : "It's been 7 days since your last backup. Please backup your data.";
  String get adminAccessRequired =>
      isAf ? 'Admin-toegang vereis.' : 'Admin access required.';
  String get viewBackups => isAf ? 'Bekyk rugsteun' : 'View Backups';
  String get deleteAll => isAf ? 'SKRAP ALLES' : 'DELETE ALL';
  String get createBackupShort => isAf ? 'Skep rugsteun' : 'Create Backup';
  String get restoreBackupShort =>
      isAf ? 'Herstel rugsteun' : 'Restore Backup';

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
  String get enableLocalBackup => isAf
      ? 'Aktiveer plaaslike rugsteun op hierdie PC'
      : 'Enable Local Backup on this PC';

  /// Localized drawer row for [AppDrawerCatalog] item ids.
  String drawerLabel(String id) {
    switch (id) {
      case 'home':
        return home;
      case 'search':
        return search;
      case 'application_form':
        return memberInfo;
      case 'step1_global528':
        return global528;
      case 'step2_global528':
        return global528Step2;
      case 'step3_global928':
        return global928;
      case 'step4_lro':
        return lro;
      case 'step5_credential':
        return credentialCard;
      case 'backup_restore':
        return backupRestore;
      case 'user_management':
        return userManagement;
      case 'cancellations':
        return cancellations;
      case 'duplicate_management':
        return duplicateManagement;
      case 'sos':
        return sos;
      case 'reminders':
        return reminders;
      case 'activities':
        return activities;
      case 'demo_data':
        return demoData;
      case 'sign_out':
        return signOut;
      default:
        return id;
    }
  }

  /// App bar / shell title for a section.
  String sectionTitle(AppSection section) {
    switch (section) {
      case AppSection.home:
        return home;
      case AppSection.settings:
        return settings;
      case AppSection.memberInfo:
        return memberInfoForm;
      case AppSection.sos:
        return sos;
      case AppSection.reminders:
        return reminders;
      case AppSection.activities:
        return activities;
      case AppSection.addUser:
        return userManagementForm;
      case AppSection.backupRestore:
        return backupRestore;
      case AppSection.global528:
        return global528;
      case AppSection.global528Step2:
        return global528Step2;
      case AppSection.global928:
        return global928;
      case AppSection.lro:
        return lro;
      case AppSection.credentialCard:
        return credentialCard;
      case AppSection.lockedMembers:
        return cancellations;
      case AppSection.duplicateReport:
        return duplicateManagement;
      case AppSection.countyInfo:
        return countyInfoShort;
      case AppSection.countyVideos:
        return countyVideos;
    }
  }
}
