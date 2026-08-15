import '../models/member.dart';
import '../models/member_navigation_state.dart';
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
  String get liveView => isAf ? 'Regstreekse Oorsig' : 'Live View';
  String get lroPublications => 'LRO Publications';
  String get videos => isAf ? "Video's" : 'Videos';
  String get info => isAf ? 'Inligting' : 'Info';
  String get menu => isAf ? 'Kieslys' : 'Menu';

  String get memberInfo => isAf ? 'Aansoekvorm' : 'Application Form';
  String get memberInfoForm =>
      isAf ? 'Lid-aansoekvorm' : 'Member Application Form';
  String get sos => 'SOS';
  String get global528 => isAf ? 'Betalings' : 'Payments';
  String get global528Step2 => 'Step 2_Global 528';
  String get global928 => 'Step 3_Global 928';
  String get lro => 'Step 4_LRO';
  String get credentialCard => 'Step 5_Credential Card';
  String get backupRestore => isAf ? 'Rugsteun & Herstel' : 'Backup & Restore';
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
  String get demoDataSubtitle =>
      isAf ? 'Skep 10 demo-lede' : 'Generate 10 demo members';
  String get countyVideos => isAf ? "County-video's" : 'County Videos';
  String get countyInfoShort => isAf ? 'County-inligting' : 'County Info';

  String get theme => isAf ? 'Tema' : 'Theme';
  String get light => isAf ? 'Lig' : 'Light';
  String get dark => isAf ? 'Donker' : 'Dark';
  String get language => isAf ? 'Taal' : 'Language';
  String get english => 'English';
  String get afrikaans => 'Afrikaans';
  String get languageApplied =>
      isAf ? 'Taal gestel na Afrikaans' : 'Language set to English';

  String get countyInfo => isAf ? 'County-inligting' : 'County Information';
  String get countyName => isAf ? 'County-naam' : 'County name';
  String get countyAddress => isAf ? 'County-adres' : 'County Address';
  String get countyRegNo => isAf ? 'County reg. nr.' : 'County reg. no.';
  String get countyContactNo =>
      isAf ? 'County kontaknr.' : 'County Contact no.';
  String get lroSettings => isAf ? 'LRO-instellings' : 'LRO Settings';
  String get lroSettingsSubtitle => isAf
      ? 'Land Recovery Office-configurasie'
      : 'Land Recovery Office configuration';
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
  String get rsRemuneration => isAf ? 'RS-vergoeding' : 'RS Remuneration';
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
  String get countySettings => isAf ? 'County-instellings' : 'County Settings';
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
  String get lroSettings => isAf ? 'LRO-instellings' : 'LRO Settings';
  String get lroSettingsSubtitle => isAf
      ? 'Land Recovery Office-configurasie'
      : 'Land Recovery Office configuration';
  String get countyFacebookPageUrl => isAf
      ? 'County Facebook-blaaier URL'
      : 'County Facebook Page URL';
  String get countyNameAuto => isAf
      ? 'County-naam (outo-geskryf)'
      : 'County Name (auto-filled)';
  String get countyUniqueNumber => isAf
      ? 'County unieke nommer (3 syfers)'
      : 'County Unique Number (3 digits)';
  String get selectDisplayOrder => isAf
      ? 'Kies die display-volgorde vir die 16-syfering Rekordnommer'
      : 'Select the display order for the 16-digit Recording Number';
  String get blueprintPublicNotice => isAf
      ? 'Blaaie Public Notice ( Sjabloon)'
      : 'Blueprint Public Notice (Template)';
  String get blueprintDescription => isAf
      ? 'Leë sjabloon — geen Lid-naam of Rekordnommer nie.'
      : 'Blank template — no Member Name or Recording Number.';
  String get samplePublicNotice => isAf
      ? 'Voorbeeld Public Notice (met Lid-data)'
      : 'Sample Public Notice (With Member Data)';
  String get sampleDescription => isAf
      ? 'Voorbeeld wat die finale gepubliseerde kennisgewing vertoon.'
      : 'Example showing how the final published notice will look.';
  String get uploadBlueprint = isAf ? 'Laai blaaie op' : 'Upload Blueprint';
  String get uploadSample = isAf ? 'Laai voorbeeld op' : 'Upload Sample';
  String get clearImages = isAf ? 'Verwyder beelde' : 'Clear Images';
  String get imagePreview = isAf ? 'Voorbeeld' : 'Preview';
  String get LroSettingsSaved => isAf
      ? 'LRO-instellings gestoor'
      : 'LRO settings saved';
  String get lroIncomplete => isAf
      ? 'LRO is onvolledig. Laai die Blaaie sjabloon op en stel die Facebook URL voor
          lede kan Stap 4_LRO-betalings voltooi.'
      : 'LRO is incomplete. Upload the Blueprint template and set the Facebook URL
          before Members can complete Step 4_LRO payments.';
  String get lroReady => isAf
      ? 'LRO is gereed. Blaaie opgelaai, Facebook-keuring gestel, County-nommer
          geconfigureer.'
      : 'LRO is ready. Blueprint uploaded, Facebook link set, County number configured.';
  String get adminAccessRequired =>
      isAf ? 'Admin-toegang vereis.' : 'Admin access required.';
  String get viewBackups => isAf ? 'Bekyk rugsteun' : 'View Backups';
  String get deleteAll => isAf ? 'SKRAP ALLES' : 'DELETE ALL';
  String get createBackupShort => isAf ? 'Skep rugsteun' : 'Create Backup';
  String get restoreBackupShort => isAf ? 'Herstel rugsteun' : 'Restore Backup';

  String get backupCenter =>
      isAf ? 'Rugsteun & Herstel Sentrum' : 'Backup & Restore Center';
  String get localBackup => isAf ? 'Plaaslike rugsteun' : 'Local Backup';
  String get externalBackup =>
      isAf ? 'Eksterne / Netwerk-skyf' : 'External / Network Drive';
  String get restore => isAf ? 'Herstel' : 'Restore';
  String get createBackup => isAf ? 'Skep rugsteun nou' : 'Create Backup Now';
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
  String get markAsCompleted => isAf ? 'Merk as voltooi' : 'Mark as Completed';
  String get dismissReminder =>
      isAf ? 'Verwerp herinnering' : 'Dismiss Reminder';
  String get dismissReminderConfirm =>
      isAf ? 'Verwerp herinnering?' : 'Dismiss Reminder?';
  String get dismiss => isAf ? 'Verwerp' : 'Dismiss';
  String get reminderDismissed =>
      isAf ? 'Herinnering verwerp' : 'Reminder dismissed';
  String get reminderCompleted =>
      isAf ? 'Herinnering as voltooi gemerk' : 'Reminder marked as completed';
  String get refresh => isAf ? 'Verfris' : 'Refresh';
  String get total => isAf ? 'Totaal' : 'Total';
  String get step => isAf ? 'Stap' : 'Step';
  String get autoAssignAll => isAf ? 'Outo-ken almal toe' : 'Auto-Assign All';
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
  String get noGpsYet => isAf
      ? 'Nog geen GPS-ligging aangeteken nie.'
      : 'No GPS location recorded yet.';
  String get noActivitiesYet => isAf
      ? 'Nog geen aktiwiteite aangeteken nie.'
      : 'No activities recorded yet.';
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
  String get globalRecordNo => isAf ? 'Globale rekordnr.' : 'Global Record No.';
  String get contactNo1 =>
      isAf ? 'Kontaknr. 1 * (maks. 12)' : 'Contact No 1 * (max 12)';
  String get contactNo2 =>
      isAf ? 'Kontaknr. 2 (maks. 12)' : 'Contact No 2 (max 12)';
  String get emailAddress => isAf ? 'E-posadres *' : 'Email Address *';
  String get enterValidEmail =>
      isAf ? 'Voer ’n geldige e-pos in' : 'Enter a valid email';
  String get recordVisibility =>
      isAf ? 'Rekord-sigbaarheid' : 'Record visibility';
  String get enterLroRecordNo =>
      isAf ? 'Voer LRO-rekordnr. in' : 'Enter LRO Record No.';
  String get activateRs =>
      isAf ? 'Aktiveer Opnamesekretaris?' : 'Activate Recording Secretary?';
  String get deactivateRs =>
      isAf ? 'Deaktiveer Opnamesekretaris?' : 'Deactivate Recording Secretary?';
  String get activateRsBtn => isAf ? 'Aktiveer OS' : 'Activate RS';
  String get deactivateRsBtn => isAf ? 'Deaktiveer OS' : 'Deactivate RS';

  // Backup snackbars / dialogs (common)
  String get warning => isAf ? 'WAARSKUWING' : 'WARNING';
  String get dangerZone => isAf ? 'GEVAARSONE' : 'DANGER ZONE';
  String get backupAuthorized =>
      isAf ? 'Rugsteun gemagtig.' : 'Backup authorized.';
  String get backupAuthRequired =>
      isAf ? 'Rugsteun-magtiging vereis.' : 'Backup authorization required.';
  String get backupComplete => isAf ? 'Rugsteun voltooi' : 'Backup complete';
  String get restoreComplete => isAf ? 'Herstel voltooi' : 'Restore Complete';
  String get allDataDeleted => isAf ? 'Alle data geskrap' : 'All Data Deleted';
  String get errorLabel => isAf ? 'Fout' : 'Error';

  // Member list / filters / nav
  String get memberList => isAf ? 'LEDELYS' : 'MEMBER LIST';
  String get filterTitle => isAf ? 'FILTERE' : 'FILTERS';
  String get searchByNameSurnameSaId => isAf
      ? 'Soek volgens naam, van of SA-ID...'
      : 'Search by Name, Surname, or SA ID...';
  String get noMembersMatchFilter => isAf
      ? 'Geen lede pas by hierdie filter nie.'
      : 'No members match this filter.';
  String get newLabel => isAf ? 'Nuut' : 'New';
  String get newMember => isAf ? 'Nuwe lid' : 'New Member';
  String get upload => isAf ? 'Laai op' : 'Upload';
  String get previous => isAf ? 'Vorige' : 'Previous';
  String get next => isAf ? 'Volgende' : 'Next';
  String previousNamed(String name) =>
      isAf ? 'Vorige: $name' : 'Previous: $name';
  String nextNamed(String name) => isAf ? 'Volgende: $name' : 'Next: $name';
  String ofTotal(Object current, int total) =>
      isAf ? '$current van $total' : '$current of $total';
  String get statusActive => isAf ? 'Aktief' : 'Active';
  String get statusLocked => isAf ? 'Gesluit' : 'Locked';
  String get statusCancelled => isAf ? 'Gekanselleer' : 'Cancelled';
  String get statusPending => isAf ? 'Hangende' : 'Pending';
  String get favorites => isAf ? 'Gunstelinge' : 'Favorites';
  String get ascending => isAf ? 'Stygend' : 'Ascending';
  String get descending => isAf ? 'Dalend' : 'Descending';
  String get sortName => isAf ? 'Naam' : 'Name';
  String get sortSurname => isAf ? 'Van' : 'Surname';
  String get sortSaId => 'SA ID';
  String get sortUpdated => isAf ? 'Opgedateer' : 'Updated';
  String get backToList => isAf ? 'Terug na lys (Esc)' : 'Back to List (Esc)';
  String get viewProfile => isAf ? 'Bekyk profiel' : 'View Profile';
  String get editMember => isAf ? 'Wysig lid' : 'Edit Member';
  String get completeMember => isAf ? 'Voltooi lid' : 'Complete Member';
  String get grantTempAccess =>
      isAf ? 'Gee tydelike toegang' : 'Grant Temp Access';
  String get addFavorite => isAf ? 'Voeg gunsteling by' : 'Add Favorite';
  String get removeFavorite => isAf ? 'Verwyder gunsteling' : 'Remove Favorite';
  String get copySaId => isAf ? 'Kopieer SA-ID' : 'Copy SA ID';
  String get saIdCopied => isAf ? 'SA-ID gekopieer' : 'SA ID copied';
  String get sendEmail => isAf ? 'Stuur e-pos' : 'Send Email';
  String get callContact => isAf ? 'Bel kontak' : 'Call Contact';
  String get deleteMember => isAf ? 'Skrap lid' : 'Delete Member';
  String showingRange(int start, int end, int total) =>
      isAf ? 'Wys $start–$end van $total' : 'Showing $start–$end of $total';

  // Unsaved / discard
  String get unsavedChangesTitle =>
      isAf ? 'Ongestoorde veranderinge' : 'Unsaved Changes';
  String get unsavedChangesBody => isAf
      ? 'Jy het ongestoorde veranderinge vir hierdie lid.'
      : 'You have unsaved changes to this member.';
  String get whatWouldYouLike =>
      isAf ? 'Wat wil jy doen?' : 'What would you like to do?';
  String get unsavedChangesHint => isAf
      ? 'Jou veranderinge sal verlore gaan as jy weggaan sonder om te stoor.'
      : 'Your changes will be lost if you navigate away without saving.';
  String get discardChanges =>
      isAf ? 'Verwerp veranderinge' : 'Discard Changes';
  String get stayHere => isAf ? 'Bly hier' : 'Stay Here';
  String get saveChanges => isAf ? 'Stoor veranderinge' : 'Save Changes';
  String get discardChangesConfirm =>
      isAf ? 'Verwerp veranderinge?' : 'Discard Changes?';
  String get discardChangesBody => isAf
      ? 'Jy het ongestoorde veranderinge. Is jy seker jy wil dit verwerp?'
      : 'You have unsaved changes. Are you sure you want to discard them?';
  String get keepEditing => isAf ? 'Hou aan wysig' : 'Keep Editing';

  // Legal
  String get confidentialityTitle =>
      isAf ? 'Vertroulikheidsooreenkoms' : 'Confidentiality Agreement';
  String get confidentialityBody => isAf
      ? 'Deur hierdie stelsel te gebruik, stem jy in tot die volgende:\n\n'
            '1. Alle lidinligting is vertroulik.\n'
            '2. Skermkiekies van geslote lidinligting is streng verbode.\n'
            '3. Alle pogings om lidinligting vas te vang of te deel sal aangeteken word.\n'
            '4. Ongemagtigde deling van lidinligting sal dissiplinêre optrede tot gevolg hê.\n\n'
            'Aanvaar jy hierdie voorwaardes?'
      : 'By accessing this system, you agree to the following:\n\n'
            '1. All member information is confidential.\n'
            '2. Screenshots of locked member information are strictly prohibited.\n'
            '3. All attempts to capture or share member information will be logged.\n'
            '4. Unauthorized sharing of member information will result in '
            'disciplinary action.\n\n'
            'Do you accept these terms?';
  String get reject => isAf ? 'Weier' : 'Reject';
  String get iAccept => isAf ? 'Ek aanvaar' : 'I Accept';

  // Sync
  String get synced => isAf ? 'Gesinkroniseer' : 'Synced';
  String get syncing => isAf ? 'Sinkroniseer' : 'Syncing';
  String get offline => isAf ? 'Aflyn' : 'Offline';
  String get syncError => isAf ? 'Sinkroniseringsfout' : 'Sync error';
  String get never => isAf ? 'Nooit' : 'Never';
  String lastSyncedAt(String when) =>
      isAf ? 'Laas gesinkroniseer: $when' : 'Last synced: $when';

  // Onboarding checklist
  String get onboardingProgress =>
      isAf ? 'INDUKSIE-VORDERING' : 'ONBOARDING PROGRESS';
  String get onboardingMustComplete => isAf
      ? 'Lid moet 4 stappe voltooi om volledig te wees:'
      : 'Member must complete 4 steps to become fully fledged:';
  String get step1MemberInfo =>
      isAf ? 'Stap 1: Lidinligting' : 'Step 1: Member Info';
  String get step2Global528 => 'Step 2: Global 528';
  String get step3Global928 => 'Step 3: Global 928';
  String get step4Lro => 'Step 4: LRO';
  String get completeMemberBtn => isAf ? 'Voltooi lid' : 'Complete Member';

  // Cancel membership dialog
  String get keepMembership => isAf ? 'Hou lidmaatskap' : 'Keep Membership';
  String get cancellationReasonHint => isAf
      ? 'Rede vir kansellasie (opsioneel)'
      : 'Reason for cancellation (optional)';

  // Photo / edit mode
  String get memberPhoto => isAf ? 'Lidfoto' : 'Member Photo';
  String get uploadPhoto => isAf ? 'Laai foto op' : 'Upload Photo';
  String get changePhoto => isAf ? 'Verander foto' : 'Change Photo';
  String get remove => isAf ? 'Verwyder' : 'Remove';
  String get editMode => isAf ? 'WYSIG-MODUS' : 'EDIT MODE';
  String get viewMode => isAf ? 'KYK-MODUS' : 'VIEW MODE';
  String get address => isAf ? 'Adres *' : 'Address *';
  String get comment => isAf ? 'Opmerking' : 'Comment';

  // Lock / temp access (common)
  String get memberLocked =>
      isAf ? 'Hierdie lid is gesluit' : 'This member is locked';
  String get enterTempAccessCode =>
      isAf ? 'Voer tydelike toegangskode in' : 'Enter Temporary Access Code';
  String get grantTemporaryAccess =>
      isAf ? 'Gee tydelike toegang' : 'Grant Temporary Access';
  String get selectRecordingSecretary =>
      isAf ? 'Kies Opnamesekretaris' : 'Select Recording Secretary';
  String get reasonForAccess =>
      isAf ? 'Rede vir toegang *' : 'Reason for Access *';
  String get lockedMembers => isAf ? 'Geslote lede' : 'Locked Members';
  String get unlockMember => isAf ? 'Ontsluit lid' : 'Unlock Member';
  String get noLockedMembers =>
      isAf ? 'Nog geen geslote lede nie.' : 'No locked members yet.';

  // Files / duplicates
  String get noFilesUploaded =>
      isAf ? 'Nog geen lêers opgelaai nie.' : 'No files uploaded yet.';
  String get briefFileDescription =>
      isAf ? 'Kort lêerbeskrywing' : 'Brief File Description';
  String get duplicateDetected =>
      isAf ? 'Duplikaat gevind' : 'Duplicate Detected';
  String get viewExistingMember =>
      isAf ? 'Bekyk bestaande lid' : 'View Existing Member';
  String get noDuplicatesFound =>
      isAf ? 'Geen duplikate gevind nie' : 'No Duplicates Found';
  String get moduleComingSoon =>
      isAf ? 'Module kom binnekort.' : 'Module coming soon.';
  String get starting => isAf ? 'Begin…' : 'Starting…';
  String get adminOnly => isAf ? 'Slegs Admin' : 'Admin Only';
  String get savePermissions => isAf ? 'Stoor regte' : 'Save Permissions';
  String get recordingSecretaryRights =>
      isAf ? 'OPNAMESEKRETARIS-REGTE' : 'RECORDING SECRETARY RIGHTS';
  String get searchRecordingSecretaries =>
      isAf ? 'Soek Opnamesekretarisse…' : 'Search Recording Secretaries…';
  String get reinstateMember => isAf ? 'Herstel lid?' : 'Reinstate Member?';
  String get yesReinstate => isAf ? 'Ja, herstel' : 'Yes, Reinstate';
  String get searchCancelledMembers =>
      isAf ? 'Soek gekanselleerde lede…' : 'Search Cancelled Members…';

  String quickFilterLabel(MemberQuickFilter f) {
    switch (f) {
      case MemberQuickFilter.all:
        return filterAll;
      case MemberQuickFilter.active:
        return statusActive;
      case MemberQuickFilter.pending:
        return statusPending;
      case MemberQuickFilter.locked:
        return statusLocked;
      case MemberQuickFilter.newMembers:
        return filterNew;
      case MemberQuickFilter.favorites:
        return favorites;
    }
  }

  String sortLabel(MemberSortBy sort) {
    switch (sort) {
      case MemberSortBy.name:
        return sortName;
      case MemberSortBy.surname:
        return sortSurname;
      case MemberSortBy.saId:
        return sortSaId;
      case MemberSortBy.date:
        return sortUpdated;
    }
  }

  String memberStatusLabel(Member m) {
    if (m.isCancelled) return statusCancelled;
    if (m.isLocked) return statusLocked;
    if (m.registrationStatus == 'pending' ||
        m.registrationStatus == 'in_progress') {
      return statusPending;
    }
    return statusActive;
  }

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
      case 'lro_settings':
        return lroSettings;
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
      case AppSection.liveView:
        return liveView;
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
      case AppSection.lroPublications:
        return lroPublications;
      case AppSection.countyVideos:
        return countyVideos;
    }
  }
}
