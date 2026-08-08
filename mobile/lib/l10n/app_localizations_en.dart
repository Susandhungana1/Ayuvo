// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navMedicines => 'Medicines';

  @override
  String get navVitals => 'Vitals';

  @override
  String get navReports => 'Reports';

  @override
  String get navMore => 'More';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navAvailability => 'Availability';

  @override
  String get navAccount => 'Account';

  @override
  String get navDocuments => 'Documents';

  @override
  String get navSharing => 'Sharing';

  @override
  String get navEmergency => 'Emergency ID';

  @override
  String get navTimeline => 'Timeline';

  @override
  String get navSearch => 'Search';

  @override
  String get navAssistant => 'Health assistant';

  @override
  String get navNearby => 'Nearby care';

  @override
  String get navCaretakers => 'Caretakers';

  @override
  String get navSettings => 'Settings';

  @override
  String get navDoctorProfile => 'Doctor profile';

  @override
  String get moreAppointmentsBlurb =>
      'Book a doctor, or keep a reminder of one you booked yourself';

  @override
  String get moreDocumentsBlurb => 'Visits, and the files each one produced';

  @override
  String get moreSharingBlurb =>
      'Links that let a doctor read your record without an account';

  @override
  String get moreEmergencyBlurb =>
      'Blood type, allergies and who to call, behind a QR';

  @override
  String get moreTimelineBlurb => 'Everything you have recorded, newest first';

  @override
  String get moreSearchBlurb => 'Find a report, a medicine or a visit by name';

  @override
  String get moreAssistantBlurb =>
      'Ask a general health question. Not a diagnosis';

  @override
  String get moreNearbyBlurb => 'Hospitals, clinics and pharmacies within 4 km';

  @override
  String get moreCaretakersBlurb =>
      'Let someone you trust manage your medicines';

  @override
  String get moreSettingsBlurb => 'Language, appearance and dose reminders';

  @override
  String get moreDoctorProfileBlurb =>
      'Your NMC registration and verification status';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'Your records stay on the server. You will need your password to get back in.';

  @override
  String get signOutStay => 'Stay signed in';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get remove => 'Remove';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageBlurb =>
      'Navigation and this screen change straight away. Most other text is still English only.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageNepali => 'नेपाली';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'Match my phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsReminders => 'Dose reminders';

  @override
  String get settingsRemindersBlurb =>
      'A notification at each dose time, scheduled on this phone. Nothing about a medicine is sent anywhere.';

  @override
  String get settingsRemindersOn => 'Remind me to take my medicines';

  @override
  String get settingsRemindersDenied =>
      'Notifications are switched off for MediStore. Turn them on in your phone\'s settings, then come back.';

  @override
  String settingsRemindersScheduled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders scheduled',
      one: '1 reminder scheduled',
      zero: 'Nothing scheduled yet',
    );
    return '$_temp0';
  }

  @override
  String get settingsRemindersHorizon =>
      'Covers the next 7 days. The app refreshes them whenever you open it.';

  @override
  String get timelineTitle => 'Timeline';

  @override
  String get timelineSubtitle => 'Everything on your record, newest first';

  @override
  String get timelineEmptyTitle => 'Nothing recorded yet';

  @override
  String get timelineEmptyBody =>
      'Upload a report, add a medicine or take a reading, and it shows up here in order.';

  @override
  String timelineEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get timelineLoadMore => 'Show older';

  @override
  String get timelineAllLoaded => 'That is the whole record.';

  @override
  String get timelineTypeReport => 'Report';

  @override
  String get timelineTypeMedicine => 'Medicine';

  @override
  String get timelineTypeAppointment => 'Appointment';

  @override
  String get timelineTypeVital => 'Reading';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Reports, medicines, documents';

  @override
  String get searchPromptTitle => 'Search your record';

  @override
  String get searchPromptBody =>
      'Matches a report\'s summary and its scanned text, a medicine\'s name and notes, and a visit\'s hospital, doctor or department.';

  @override
  String get searchNoResultsTitle => 'Nothing matched';

  @override
  String searchNoResultsBody(String query) {
    return 'No report, medicine or document contains “$query”.';
  }

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get searchTypeReport => 'Report';

  @override
  String get searchTypeMedicine => 'Medicine';

  @override
  String get searchTypeDocument => 'Visit';

  @override
  String get assistantTitle => 'Health assistant';

  @override
  String get assistantGreeting =>
      'Ask me about symptoms, medicines, nutrition or fitness. I answer in general terms only.';

  @override
  String get assistantDisclaimer =>
      'An AI, not a doctor. Nothing here is a diagnosis, and it cannot see your records.';

  @override
  String get assistantHint => 'Ask about health';

  @override
  String get assistantListening => 'Listening…';

  @override
  String get assistantSend => 'Send';

  @override
  String get assistantVoice => 'Speak your question';

  @override
  String get assistantThinking => 'Thinking…';

  @override
  String get assistantClear => 'Clear this conversation';

  @override
  String get assistantCleared => 'Conversation cleared';

  @override
  String get assistantOffTitle => 'The assistant is not switched on';

  @override
  String get assistantOffBody =>
      'This server has no GROQ_API_KEY set, so there is nothing to answer with.';

  @override
  String get assistantTrimmed =>
      'Older messages are dropped from what gets sent, so a long conversation keeps working.';

  @override
  String get nearbyTitle => 'Nearby care';

  @override
  String get nearbyLocating => 'Finding you…';

  @override
  String get nearbyShowingYours => 'Care within 4 km of you.';

  @override
  String get nearbyDenied =>
      'Location is off, so this is Kathmandu. Allow location to see what is near you.';

  @override
  String get nearbyUnavailable =>
      'This phone would not give a location, so this is Kathmandu.';

  @override
  String get nearbyNone => 'Nothing found within 4 km.';

  @override
  String get nearbyFailed =>
      'Could not reach the map data service. It is a public service and is sometimes busy.';

  @override
  String get nearbyDirections => 'Directions';

  @override
  String get nearbyUseMyLocation => 'Use my location';

  @override
  String get nearbyKindHospital => 'Hospital';

  @override
  String get nearbyKindClinic => 'Clinic';

  @override
  String get nearbyKindPharmacy => 'Pharmacy';

  @override
  String nearbyDistanceKm(String km) {
    return '$km km away';
  }

  @override
  String get nearbyAttribution => '© OpenStreetMap contributors';

  @override
  String get nearbyYouAreHere => 'You are here';

  @override
  String get caretakersTitle => 'Caretakers';

  @override
  String get caretakersBlurb =>
      'A caretaker can see and manage your medicines, and gets your dose reminders. They cannot see your vitals, reports, documents or anything else.';

  @override
  String get caretakersAddTitle => 'Add a caretaker';

  @override
  String get caretakersAddBlurb =>
      'Generate a code and read it out to the person with you. It works once, and only for the next 15 minutes.';

  @override
  String get caretakersGenerate => 'Generate a code';

  @override
  String get caretakersGenerating => 'Generating…';

  @override
  String get caretakersCodeWarning =>
      'This code cannot be shown again once hidden or expired. Generating a new one cancels it.';

  @override
  String caretakersExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get caretakersExpired => 'Expired';

  @override
  String get caretakersHide => 'Hide';

  @override
  String get caretakersYours => 'Your caretakers';

  @override
  String get caretakersNone => 'Nobody is helping manage your medicines yet.';

  @override
  String caretakersAdded(String date) {
    return 'Added $date';
  }

  @override
  String caretakersRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get caretakersRemoveBody =>
      'They lose access to your medicines immediately and stop getting your reminders.';

  @override
  String get caretakersActivity => 'Recent caretaker activity';

  @override
  String get caretakersActivityNone => 'No changes by a caretaker yet.';

  @override
  String get caretakersRestore => 'Restore';

  @override
  String get caretakersOffTitle => 'Caretakers is switched off';

  @override
  String get caretakersOffBody =>
      'This server has the caretaker feature disabled. It needs CARETAKER_ENABLED=true on the API.';

  @override
  String get careMineTitle => 'People I care for';

  @override
  String get careMineAdd => 'Add someone';

  @override
  String get careMinePrompt => 'Caring for someone? Enter their code';

  @override
  String get careRedeemTitle => 'Enter a care code';

  @override
  String get careRedeemBlurb =>
      'The person you are helping generates this on their own phone, under Caretakers. It lasts 15 minutes.';

  @override
  String get careRedeemLabel => 'Their care code';

  @override
  String get careRedeemSubmit => 'Add';

  @override
  String careMedicineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicines',
      one: '1 medicine',
      zero: 'No medicines',
    );
    return '$_temp0';
  }

  @override
  String careNextDose(String label) {
    return 'Next: $label';
  }

  @override
  String get careNoDoses => 'No upcoming doses';

  @override
  String careDoseAt(String name, String time) {
    return '$name at $time';
  }

  @override
  String careDoseTomorrow(String time) {
    return '$time tomorrow';
  }

  @override
  String get careTheirTime => '(their time)';

  @override
  String get careManage => 'Manage medicines';

  @override
  String get careMuted => 'Reminders muted';

  @override
  String get careMute => 'Mute reminders';

  @override
  String get careUnmute => 'Unmute reminders';

  @override
  String careScopeBanner(String name) {
    return 'You are managing medicines for $name.';
  }

  @override
  String get careScopeOnly =>
      'Medicines only — nothing else on their record is shown here, or fetched.';

  @override
  String get careGoneTitle => 'No longer available';

  @override
  String get careGoneBody =>
      'You do not have access to this person\'s medicines.';

  @override
  String careRevoked(String name) {
    return '$name removed your caretaker access.';
  }

  @override
  String get careBackToMine => 'Back to my own record';
}
