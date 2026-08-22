/// MediStore — your personal digital health record.
///
///   flutter run                                    # local dev backend
///   flutter run --dart-define=API_BASE_URL=...     # any other backend
///
/// The design-system gallery has its own entry point:
/// `flutter run -t lib/dev/design_gallery.dart`.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is only configured for Android (google-services.json).
  // On web, Firebase.initializeApp() needs firebase_options.dart which we
  // don't have — and reminders use local notifications on web anyway.
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
  }

  runApp(const ProviderScope(child: MediStoreApp()));
}
