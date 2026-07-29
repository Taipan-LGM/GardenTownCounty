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
  String get surname => isAf ? 'Van' : 'Surname';
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

  // Search
  String get globalSearch => isAf ? 'Globale soektog' : 'Global Search';
  String get searchHint =>
      isAf ? 'Soek alle lidvelde…' : 'Search all member fields…';
  String get noMembersMatched =>
      isAf ? 'Geen lede pas nie.' : 'No members matched.';

  // SOS
  String get sosMessaging => isAf ? 'SOS-boodskappe' : 'SOS Messaging';
  String get sosMessage => isAf ? 'SOS-boodskap' : 'SOS Message';
  String get standardisedSosTitle =>
      isAf ? 'Gestandaardiseerde SOS-titel' : 'Standardised SOS title';
  String get savePreset => isAf ? 'Stoor voorafstel' : 'Save Preset';
  String get presets => isAf ? 'Voorafstellings' : 'Presets';
  String get recipients => isAf ? 'Ontvangers' : 'Recipients';
  String get singleMember => isAf ? 'Enkele lid' : 'Single Member';
  String get selectedIndividuals =>
      isAf ? 'Gekose individue' : 'Selected Individuals';
  String get allMembers => isAf ? 'Alle lede' : 'All Members';
  String get member => isAf ? 'Lid' : 'Member';
  String get sendSos => isAf ? 'Stuur SOS' : 'Send SOS';
  String get sending => isAf ? 'Stuur tans…' : 'Sending…';
  String get presetNeedsTitleAndMessage => isAf
      ? 'Voorafstel benodig ’n titel en boodskap.'
      : 'Preset needs a title and message.';
  String get email => isAf ? 'E-pos' : 'Email';

  // Reminders
  String get remindersTitle => isAf ? 'Herinnerings' : 'Reminders';
  String get viewMember => isAf ? 'Bekyk lid' : 'View Member';
  String get markAsCompleted =>
      isAf ? 'Merk as voltooi' : 'Mark as Completed';
  String get dismissReminder =>
      isAf ? 'Verwerp herinnering' : 'Dismiss Reminder';
  String get dismissReminderConfirm =>
      isAf ? 'Verwerp herinnering?' : 'Dismiss Reminder?';
  String get dismiss => isAf ? 'Verwerp' : 'Dismiss';
  String get reminderDismissed =>
      isAf ? 'Herinnering verwerp' : 'Reminder dismissed';
  String get reminderCompleted => isAf
      ? 'Herinnering as voltooi gemerk'
      : 'Reminder marked as completed';
  String get refresh => isAf ? 'Verfris' : 'Refresh';
  String get total => isAf ? 'Totaal' : 'Total';
  String get step => isAf ? 'Stap' : 'Step';
  String get autoAssignAll =>
      isAf ? 'Outo-ken almal toe' : 'Auto-Assign All';
  String get assigning => isAf ? 'Ken tans toe...' : 'Assigning...';
  String get allRemindersHaveRs => isAf
      ? 'Alle herinnerings het ’n Opnamesekretaris'
      : 'All reminders have a Recording Secretary';
  String membersWithoutRs(int count) => isAf
      ? '$count lede sonder Opnamesekretaris'
      : '$count members without Recording Secretary';
  String get expired => isAf ? 'Verstryk' : 'Expired';
  String get expiringSoon => isAf ? 'Verstryk binnekort' : 'Expiring soon';
  String get noReminders =>
      isAf ? 'Geen aktiewe herinnerings nie.' : 'No active reminders.';

  // Activities
  String get activitiesTitle => isAf ? 'Aktiwiteite' : 'Activities';
  String get activitiesSubtitle => isAf
      ? 'Aanteken en lid-aksies met GPS, datum, tyd en gebruikersnaam. '
          'Tik GPS om die kaart te sien — druk, stoor of deel via WhatsApp.'
      : 'Login and member actions with GPS, date, time, and user name. '
          'Tap GPS to view map — print, save, or share via WhatsApp.';
  String get noGpsYet =>
      isAf ? 'Nog geen GPS-ligging aangeteken nie.' : 'No GPS location recorded yet.';
  String get noActivitiesYet =>
      isAf ? 'Nog geen aktiwiteite aangeteken nie.' : 'No activities recorded yet.';
  String get dateTime => isAf ? 'Datum / Tyd' : 'Date / Time';
  String get user => isAf ? 'Gebruiker' : 'User';
  String get action => isAf ? 'Aksie' : 'Action';
  String get gpsLocation => isAf ? 'GPS-ligging' : 'GPS Location';
  String get map => isAf ? 'Kaart' : 'Map';
  String get openGpsMap => isAf ? 'Maak GPS-kaart oop' : 'Open GPS map';

  // Info / Videos
  String get countyInformation =>
      isAf ? 'County-inligting' : 'County Information';
  String get addArticle => isAf ? 'Voeg artikel by' : 'Add Article';
  String get noArticles =>
      isAf ? 'Geen artikels beskikbaar nie.' : 'No articles available.';
  String get addVideo => isAf ? 'Voeg video by' : 'Add Video';
  String get noVideos =>
      isAf ? 'Geen video’s beskikbaar nie.' : 'No videos available.';

  // Member form extras
  String get viewMembers => isAf ? 'Bekyk lede:' : 'View Members:';
  String get focusSearch =>
      isAf ? 'Fokus soektog (Ctrl+F)' : 'Focus Search (Ctrl+F)';
  String get globalRecordNo =>
      isAf ? 'Globale rekordnr.' : 'Global Record No.';
  String get contactNo1 =>
      isAf ? 'Kontaknr. 1 * (maks. 12)' : 'Contact No 1 * (max 12)';
  String get contactNo2 =>
      isAf ? 'Kontaknr. 2 (maks. 12)' : 'Contact No 2 (max 12)';
  String get emailAddress =>
      isAf ? 'E-posadres *' : 'Email Address *';
  String get enterValidEmail =>
      isAf ? 'Voer ’n geldige e-pos in' : 'Enter a valid email';
  String get recordVisibility =>
      isAf ? 'Rekord-sigbaarheid' : 'Record visibility';
  String get enterLroRecordNo =>
      isAf ? 'Voer LRO-rekordnr. in' : 'Enter LRO Record No.';
  String get activateRs =>
      isAf ? 'Aktiveer Opnamesekretaris?' : 'Activate Recording Secretary?';
  String get deactivateRs => isAf
      ? 'Deaktiveer Opnamesekretaris?'
      : 'Deactivate Recording Secretary?';
  String get activateRsBtn => isAf ? 'Aktiveer OS' : 'Activate RS';
  String get deactivateRsBtn => isAf ? 'Deaktiveer OS' : 'Deactivate RS';

  // Backup snackbars / dialogs (common)
  String get warning => isAf ? 'WAARSKUWING' : 'WARNING';
  String get dangerZone => isAf ? 'GEVAARSONE' : 'DANGER ZONE';
  String get backupAuthorized =>
      isAf ? 'Rugsteun gemagtig.' : 'Backup authorized.';
  String get backupAuthRequired => isAf
      ? 'Rugsteun-magtiging vereis.'
      : 'Backup authorization required.';
  String get backupComplete =>
      isAf ? 'Rugsteun voltooi' : 'Backup complete';
  String get restoreComplete =>
      isAf ? 'Herstel voltooi' : 'Restore Complete';
  String get allDataDeleted =>
      isAf ? 'Alle data geskrap' : 'All Data Deleted';
  String get errorLabel => isAf ? 'Fout' : 'Error';

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
