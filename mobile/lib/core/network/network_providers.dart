import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_client.dart';

/// The one HTTP client, alive for the life of the app.
///
/// It has no dependencies on purpose: the session controller reaches *down* to
/// hand it a token and to hear about a 401, and nothing reaches back up. That
/// is what keeps the two out of a provider cycle.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: Env.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});
