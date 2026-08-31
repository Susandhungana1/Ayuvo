/// Queue of pending medicine intakes from notification taps.
///
/// Both local reminders and FCM pushes write here when the user taps a
/// notification.  The medicines screen reads and clears the queue on mount
/// so the intake is recorded even on a cold start.
library;

class PendingIntake {
  PendingIntake({required this.medId, required this.time});
  final String medId;
  final String time;
}

/// Module-level queue — lightweight, no DI needed.
final List<PendingIntake> _queue = [];

/// Add a pending intake from a notification tap.
void addPendingIntake(String medId, String time) {
  _queue.add(PendingIntake(medId: medId, time: time));
}

/// Consume all pending intakes (called by the medicines screen on mount).
List<PendingIntake> consumePendingIntakes() {
  final list = List<PendingIntake>.from(_queue);
  _queue.clear();
  return list;
}
