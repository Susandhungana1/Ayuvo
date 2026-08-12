/// MediStore — your personal digital health record.
///
///   flutter run                                    # local dev backend
///   flutter run --dart-define=API_BASE_URL=...     # any other backend
///
/// The design-system gallery has its own entry point:
/// `flutter run -t lib/dev/design_gallery.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MediStoreApp()));
}
