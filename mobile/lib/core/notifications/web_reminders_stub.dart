/// Native fallback for the web reminders factory.
///
/// Selected by the conditional import in `reminders.dart` everywhere except
/// the web build, so `package:web` (browser-only code) never reaches a native
/// compiler. The web path is `web_reminders.dart`; the returned no-op is never
/// reachable here because `remindersProvider` only calls this on `kIsWeb`.
library;

import '../network/api_client.dart';
import 'reminders.dart';

Reminders createWebReminders(ApiClient client) => NoReminders();
