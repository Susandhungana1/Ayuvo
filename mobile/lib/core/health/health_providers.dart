import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/network_providers.dart';
import 'health_status.dart';

/// `GET /health`. Public, so it also works as a reachability check before
/// anyone has signed in.
final healthProvider = FutureProvider<HealthStatus>((ref) async {
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
        '/health',
        options: unauthenticated,
      );
  return HealthStatus.fromJson(json);
});

/// Whether to show any caretaker UI at all.
///
/// Defaults to false while the check is in flight or if it fails: offering a
/// feature that answers 404 is worse than not offering it.
final caretakerEnabledProvider = Provider<bool>(
  (ref) => ref.watch(healthProvider).valueOrNull?.caretaker ?? false,
);
