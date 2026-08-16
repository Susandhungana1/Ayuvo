/// Every location in the app, in one list.
///
/// Screens navigate with these constants, never with a literal path, so a
/// renamed route breaks at compile time instead of at runtime.
library;

abstract final class Routes {
  /// Shown only while the stored session is being read.
  static const splash = '/splash';

  static const signIn = '/sign-in';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  /// Signed out, in the order they appear in the flow.
  static const signedOut = [signIn, register, forgotPassword, resetPassword];

  /// Public share readers, mirroring `front/app/share/*`. A recipient follows
  /// a link or scans a QR code *without* an account — the token is the
  /// credential — so these are reachable by anyone, signed in or not, and are
  /// never gated behind the session redirect.
  static const shareQrCode = '/share/qr-code/:token';
  static const shareSingle = '/share/:token';

  /// Every route under the public share readers. Checked as a prefix against
  /// the resolved location (see `app_router.dart`), and safe as one because no
  /// authenticated route lives under `/share/` — the owner's sharing screen is
  /// [shareUnderMore], which starts with `/more/`.
  static const sharePrefix = '/share/';

  // Patient shell.
  static const home = '/home';
  static const medicines = '/medicines';
  static const vitals = '/vitals';
  static const reports = '/reports';
  static const more = '/more';

  /// Children of [more], so the bottom bar stays put and Back returns to the
  /// tab rather than to whatever screen was there before it.
  static const documents = '/more/documents';
  static const appointments = '/more/appointments';
  static const share = '/more/share';
  static const emergency = '/more/emergency';
  static const timeline = '/more/timeline';
  static const search = '/more/search';
  static const assistant = '/more/assistant';
  static const nearby = '/more/nearby';
  static const caretakers = '/more/caretakers';
  static const settings = '/more/settings';
  static const privacy = '/more/privacy';
  static const terms = '/more/terms';
  static const about = '/more/about';
  static const contact = '/more/contact';
  static const faq = '/more/faq';

  // Doctor shell.
  static const doctorAppointments = '/doctor/appointments';
  static const doctorAvailability = '/doctor/availability';
  static const doctorMore = '/doctor/more';

  /// Children of [doctorMore], for the same reason as the patient ones. A
  /// doctor gets Settings — language and appearance are not patient features —
  /// but not the caretaker screens, which are about a medicine list they
  /// do not have.
  static const doctorProfile = '/doctor/more/profile';
  static const doctorSettings = '/doctor/more/settings';

  static const doctorPrefix = '/doctor';
}
