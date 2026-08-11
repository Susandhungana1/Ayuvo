/// The native build's [LocalStore]: real files under the app support directory.
///
/// Picked by the conditional import in `local_store.dart` on every platform
/// except web.
library;

import 'local_store.dart';

LocalStore createDefaultLocalStore() => FileLocalStore();
