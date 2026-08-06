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

  // Patient shell.
  static const home = '/home';
  static const medicines = '/medicines';
  static const vitals = '/vitals';
  static const reports = '/reports';
  static const more = '/more';

  // Doctor shell.
  static const doctorAppointments = '/doctor/appointments';
  static const doctorAvailability = '/doctor/availability';
  static const doctorMore = '/doctor/more';

  static const doctorPrefix = '/doctor';
}
