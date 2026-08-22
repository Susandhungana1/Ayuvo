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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Background message handler — must be a top-level function.
  FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
  runApp(const ProviderScope(child: MediStoreApp()));
}
