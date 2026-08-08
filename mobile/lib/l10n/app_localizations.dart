import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n? of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n);
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne'),
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get navMedicines;

  /// No description provided for @navVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get navVitals;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get navAppointments;

  /// No description provided for @navAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get navAvailability;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get navDocuments;

  /// No description provided for @navSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get navSharing;

  /// No description provided for @navEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency ID'**
  String get navEmergency;

  /// No description provided for @navTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get navTimeline;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navAssistant.
  ///
  /// In en, this message translates to:
  /// **'Health assistant'**
  String get navAssistant;

  /// No description provided for @navNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby care'**
  String get navNearby;

  /// No description provided for @navCaretakers.
  ///
  /// In en, this message translates to:
  /// **'Caretakers'**
  String get navCaretakers;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navDoctorProfile.
  ///
  /// In en, this message translates to:
  /// **'Doctor profile'**
  String get navDoctorProfile;

  /// No description provided for @moreAppointmentsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Book a doctor, or keep a reminder of one you booked yourself'**
  String get moreAppointmentsBlurb;

  /// No description provided for @moreDocumentsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Visits, and the files each one produced'**
  String get moreDocumentsBlurb;

  /// No description provided for @moreSharingBlurb.
  ///
  /// In en, this message translates to:
  /// **'Links that let a doctor read your record without an account'**
  String get moreSharingBlurb;

  /// No description provided for @moreEmergencyBlurb.
  ///
  /// In en, this message translates to:
  /// **'Blood type, allergies and who to call, behind a QR'**
  String get moreEmergencyBlurb;

  /// No description provided for @moreTimelineBlurb.
  ///
  /// In en, this message translates to:
  /// **'Everything you have recorded, newest first'**
  String get moreTimelineBlurb;

  /// No description provided for @moreSearchBlurb.
  ///
  /// In en, this message translates to:
  /// **'Find a report, a medicine or a visit by name'**
  String get moreSearchBlurb;

  /// No description provided for @moreAssistantBlurb.
  ///
  /// In en, this message translates to:
  /// **'Ask a general health question. Not a diagnosis'**
  String get moreAssistantBlurb;

  /// No description provided for @moreNearbyBlurb.
  ///
  /// In en, this message translates to:
  /// **'Hospitals, clinics and pharmacies within 4 km'**
  String get moreNearbyBlurb;

  /// No description provided for @moreCaretakersBlurb.
  ///
  /// In en, this message translates to:
  /// **'Let someone you trust manage your medicines'**
  String get moreCaretakersBlurb;

  /// No description provided for @moreSettingsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Language, appearance and dose reminders'**
  String get moreSettingsBlurb;

  /// No description provided for @moreDoctorProfileBlurb.
  ///
  /// In en, this message translates to:
  /// **'Your NMC registration and verification status'**
  String get moreDoctorProfileBlurb;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your records stay on the server. You will need your password to get back in.'**
  String get signOutBody;

  /// No description provided for @signOutStay.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get signOutStay;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageBlurb.
  ///
  /// In en, this message translates to:
  /// **'Navigation and this screen change straight away. Most other text is still English only.'**
  String get settingsLanguageBlurb;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageNepali.
  ///
  /// In en, this message translates to:
  /// **'नेपाली'**
  String get languageNepali;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match my phone'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Dose reminders'**
  String get settingsReminders;

  /// No description provided for @settingsRemindersBlurb.
  ///
  /// In en, this message translates to:
  /// **'A notification at each dose time, scheduled on this phone. Nothing about a medicine is sent anywhere.'**
  String get settingsRemindersBlurb;

  /// No description provided for @settingsRemindersOn.
  ///
  /// In en, this message translates to:
  /// **'Remind me to take my medicines'**
  String get settingsRemindersOn;

  /// No description provided for @settingsRemindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off for MediStore. Turn them on in your phone\'s settings, then come back.'**
  String get settingsRemindersDenied;

  /// No description provided for @settingsRemindersScheduled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing scheduled yet} =1{1 reminder scheduled} other{{count} reminders scheduled}}'**
  String settingsRemindersScheduled(int count);

  /// No description provided for @settingsRemindersHorizon.
  ///
  /// In en, this message translates to:
  /// **'Covers the next 7 days. The app refreshes them whenever you open it.'**
  String get settingsRemindersHorizon;

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTitle;

  /// No description provided for @timelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything on your record, newest first'**
  String get timelineSubtitle;

  /// No description provided for @timelineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get timelineEmptyTitle;

  /// No description provided for @timelineEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Upload a report, add a medicine or take a reading, and it shows up here in order.'**
  String get timelineEmptyBody;

  /// No description provided for @timelineEventCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String timelineEventCount(int count);

  /// No description provided for @timelineLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Show older'**
  String get timelineLoadMore;

  /// No description provided for @timelineAllLoaded.
  ///
  /// In en, this message translates to:
  /// **'That is the whole record.'**
  String get timelineAllLoaded;

  /// No description provided for @timelineTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get timelineTypeReport;

  /// No description provided for @timelineTypeMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get timelineTypeMedicine;

  /// No description provided for @timelineTypeAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get timelineTypeAppointment;

  /// No description provided for @timelineTypeVital.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get timelineTypeVital;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Reports, medicines, documents'**
  String get searchHint;

  /// No description provided for @searchPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Search your record'**
  String get searchPromptTitle;

  /// No description provided for @searchPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Matches a report\'s summary and its scanned text, a medicine\'s name and notes, and a visit\'s hospital, doctor or department.'**
  String get searchPromptBody;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'No report, medicine or document contains “{query}”.'**
  String searchNoResultsBody(String query);

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String searchResultCount(int count);

  /// No description provided for @searchTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get searchTypeReport;

  /// No description provided for @searchTypeMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get searchTypeMedicine;

  /// No description provided for @searchTypeDocument.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get searchTypeDocument;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Health assistant'**
  String get assistantTitle;

  /// No description provided for @assistantGreeting.
  ///
  /// In en, this message translates to:
  /// **'Ask me about symptoms, medicines, nutrition or fitness. I answer in general terms only.'**
  String get assistantGreeting;

  /// No description provided for @assistantDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'An AI, not a doctor. Nothing here is a diagnosis, and it cannot see your records.'**
  String get assistantDisclaimer;

  /// No description provided for @assistantHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about health'**
  String get assistantHint;

  /// No description provided for @assistantListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get assistantListening;

  /// No description provided for @assistantSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistantSend;

  /// No description provided for @assistantVoice.
  ///
  /// In en, this message translates to:
  /// **'Speak your question'**
  String get assistantVoice;

  /// No description provided for @assistantThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get assistantThinking;

  /// No description provided for @assistantClear.
  ///
  /// In en, this message translates to:
  /// **'Clear this conversation'**
  String get assistantClear;

  /// No description provided for @assistantCleared.
  ///
  /// In en, this message translates to:
  /// **'Conversation cleared'**
  String get assistantCleared;

  /// No description provided for @assistantOffTitle.
  ///
  /// In en, this message translates to:
  /// **'The assistant is not switched on'**
  String get assistantOffTitle;

  /// No description provided for @assistantOffBody.
  ///
  /// In en, this message translates to:
  /// **'This server has no GROQ_API_KEY set, so there is nothing to answer with.'**
  String get assistantOffBody;

  /// No description provided for @assistantTrimmed.
  ///
  /// In en, this message translates to:
  /// **'Older messages are dropped from what gets sent, so a long conversation keeps working.'**
  String get assistantTrimmed;

  /// No description provided for @nearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby care'**
  String get nearbyTitle;

  /// No description provided for @nearbyLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding you…'**
  String get nearbyLocating;

  /// No description provided for @nearbyShowingYours.
  ///
  /// In en, this message translates to:
  /// **'Care within 4 km of you.'**
  String get nearbyShowingYours;

  /// No description provided for @nearbyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is off, so this is Kathmandu. Allow location to see what is near you.'**
  String get nearbyDenied;

  /// No description provided for @nearbyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This phone would not give a location, so this is Kathmandu.'**
  String get nearbyUnavailable;

  /// No description provided for @nearbyNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing found within 4 km.'**
  String get nearbyNone;

  /// No description provided for @nearbyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the map data service. It is a public service and is sometimes busy.'**
  String get nearbyFailed;

  /// No description provided for @nearbyDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get nearbyDirections;

  /// No description provided for @nearbyUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get nearbyUseMyLocation;

  /// No description provided for @nearbyKindHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get nearbyKindHospital;

  /// No description provided for @nearbyKindClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get nearbyKindClinic;

  /// No description provided for @nearbyKindPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get nearbyKindPharmacy;

  /// No description provided for @nearbyDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String nearbyDistanceKm(String km);

  /// No description provided for @nearbyAttribution.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get nearbyAttribution;

  /// No description provided for @nearbyYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get nearbyYouAreHere;

  /// No description provided for @caretakersTitle.
  ///
  /// In en, this message translates to:
  /// **'Caretakers'**
  String get caretakersTitle;

  /// No description provided for @caretakersBlurb.
  ///
  /// In en, this message translates to:
  /// **'A caretaker can see and manage your medicines, and gets your dose reminders. They cannot see your vitals, reports, documents or anything else.'**
  String get caretakersBlurb;

  /// No description provided for @caretakersAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a caretaker'**
  String get caretakersAddTitle;

  /// No description provided for @caretakersAddBlurb.
  ///
  /// In en, this message translates to:
  /// **'Generate a code and read it out to the person with you. It works once, and only for the next 15 minutes.'**
  String get caretakersAddBlurb;

  /// No description provided for @caretakersGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate a code'**
  String get caretakersGenerate;

  /// No description provided for @caretakersGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get caretakersGenerating;

  /// No description provided for @caretakersCodeWarning.
  ///
  /// In en, this message translates to:
  /// **'This code cannot be shown again once hidden or expired. Generating a new one cancels it.'**
  String get caretakersCodeWarning;

  /// No description provided for @caretakersExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String caretakersExpiresIn(String time);

  /// No description provided for @caretakersExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get caretakersExpired;

  /// No description provided for @caretakersHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get caretakersHide;

  /// No description provided for @caretakersYours.
  ///
  /// In en, this message translates to:
  /// **'Your caretakers'**
  String get caretakersYours;

  /// No description provided for @caretakersNone.
  ///
  /// In en, this message translates to:
  /// **'Nobody is helping manage your medicines yet.'**
  String get caretakersNone;

  /// No description provided for @caretakersAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String caretakersAdded(String date);

  /// No description provided for @caretakersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String caretakersRemoveTitle(String name);

  /// No description provided for @caretakersRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They lose access to your medicines immediately and stop getting your reminders.'**
  String get caretakersRemoveBody;

  /// No description provided for @caretakersActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent caretaker activity'**
  String get caretakersActivity;

  /// No description provided for @caretakersActivityNone.
  ///
  /// In en, this message translates to:
  /// **'No changes by a caretaker yet.'**
  String get caretakersActivityNone;

  /// No description provided for @caretakersRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get caretakersRestore;

  /// No description provided for @caretakersOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Caretakers is switched off'**
  String get caretakersOffTitle;

  /// No description provided for @caretakersOffBody.
  ///
  /// In en, this message translates to:
  /// **'This server has the caretaker feature disabled. It needs CARETAKER_ENABLED=true on the API.'**
  String get caretakersOffBody;

  /// No description provided for @careMineTitle.
  ///
  /// In en, this message translates to:
  /// **'People I care for'**
  String get careMineTitle;

  /// No description provided for @careMineAdd.
  ///
  /// In en, this message translates to:
  /// **'Add someone'**
  String get careMineAdd;

  /// No description provided for @careMinePrompt.
  ///
  /// In en, this message translates to:
  /// **'Caring for someone? Enter their code'**
  String get careMinePrompt;

  /// No description provided for @careRedeemTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a care code'**
  String get careRedeemTitle;

  /// No description provided for @careRedeemBlurb.
  ///
  /// In en, this message translates to:
  /// **'The person you are helping generates this on their own phone, under Caretakers. It lasts 15 minutes.'**
  String get careRedeemBlurb;

  /// No description provided for @careRedeemLabel.
  ///
  /// In en, this message translates to:
  /// **'Their care code'**
  String get careRedeemLabel;

  /// No description provided for @careRedeemSubmit.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get careRedeemSubmit;

  /// No description provided for @careMedicineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No medicines} =1{1 medicine} other{{count} medicines}}'**
  String careMedicineCount(int count);

  /// No description provided for @careNextDose.
  ///
  /// In en, this message translates to:
  /// **'Next: {label}'**
  String careNextDose(String label);

  /// No description provided for @careNoDoses.
  ///
  /// In en, this message translates to:
  /// **'No upcoming doses'**
  String get careNoDoses;

  /// No description provided for @careDoseAt.
  ///
  /// In en, this message translates to:
  /// **'{name} at {time}'**
  String careDoseAt(String name, String time);

  /// No description provided for @careDoseTomorrow.
  ///
  /// In en, this message translates to:
  /// **'{time} tomorrow'**
  String careDoseTomorrow(String time);

  /// No description provided for @careTheirTime.
  ///
  /// In en, this message translates to:
  /// **'(their time)'**
  String get careTheirTime;

  /// No description provided for @careManage.
  ///
  /// In en, this message translates to:
  /// **'Manage medicines'**
  String get careManage;

  /// No description provided for @careMuted.
  ///
  /// In en, this message translates to:
  /// **'Reminders muted'**
  String get careMuted;

  /// No description provided for @careMute.
  ///
  /// In en, this message translates to:
  /// **'Mute reminders'**
  String get careMute;

  /// No description provided for @careUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute reminders'**
  String get careUnmute;

  /// No description provided for @careScopeBanner.
  ///
  /// In en, this message translates to:
  /// **'You are managing medicines for {name}.'**
  String careScopeBanner(String name);

  /// No description provided for @careScopeOnly.
  ///
  /// In en, this message translates to:
  /// **'Medicines only — nothing else on their record is shown here, or fetched.'**
  String get careScopeOnly;

  /// No description provided for @careGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get careGoneTitle;

  /// No description provided for @careGoneBody.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this person\'s medicines.'**
  String get careGoneBody;

  /// No description provided for @careRevoked.
  ///
  /// In en, this message translates to:
  /// **'{name} removed your caretaker access.'**
  String careRevoked(String name);

  /// No description provided for @careBackToMine.
  ///
  /// In en, this message translates to:
  /// **'Back to my own record'**
  String get careBackToMine;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'ne':
      return AppL10nNe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
