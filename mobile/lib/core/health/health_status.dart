import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_status.freezed.dart';
part 'health_status.g.dart';

/// `GET /health` — the server's own summary of itself.
///
/// Worth calling at startup for one reason above the others: `caretaker` is the
/// only way to know whether `/api/care/*` exists on this deployment. When it is
/// false those routes answer 404, so the caretaker UI must be hidden rather
/// than left to fail.
@freezed
abstract class HealthStatus with _$HealthStatus {
  const factory HealthStatus({
    required String status,
    required bool database,

    /// Which mail transport is live: `brevo`, `smtp`, or `none`. Names the
    /// transport, never the credential.
    required String email,

    /// Whether the caretaker feature is switched on.
    required bool caretaker,
  }) = _HealthStatus;

  const HealthStatus._();

  factory HealthStatus.fromJson(Map<String, dynamic> json) =>
      _$HealthStatusFromJson(json);

  bool get isHealthy => status == 'ok' && database;

  /// Password reset needs mail. When this is false, "we sent you a code" is a
  /// promise the server cannot keep.
  bool get canSendEmail => email != 'none';
}
