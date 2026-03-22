/// Booking status state machine.
///
/// Valid transitions:
///   pending   -> confirmed, cancelled
///   confirmed -> in_progress, cancelled
///   in_progress -> completed
///   completed -> (terminal — no transitions)
///   cancelled -> (terminal — no transitions)

class BookingStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
    pending,
    confirmed,
    inProgress,
    completed,
    cancelled,
  ];
}

/// Valid transitions: from-status -> set of allowed to-statuses.
const Map<String, Set<String>> _validTransitions = {
  'pending': {'confirmed', 'cancelled'},
  'confirmed': {'in_progress', 'cancelled'},
  'in_progress': {'completed'},
  'completed': {},   // terminal
  'cancelled': {},   // terminal
};

/// Check if transitioning from [fromStatus] to [toStatus] is valid.
///
/// Returns `true` if the transition is allowed, `false` otherwise.
/// Unknown statuses return `false`.
bool canTransition(String fromStatus, String toStatus) {
  final allowed = _validTransitions[fromStatus];
  if (allowed == null) return false;
  return allowed.contains(toStatus);
}

/// Attempt to transition from [fromStatus] to [toStatus].
///
/// Returns [toStatus] if the transition is valid.
/// Throws [StateError] if the transition is invalid.
String transition(String fromStatus, String toStatus) {
  if (!canTransition(fromStatus, toStatus)) {
    throw StateError(
      'Invalid booking transition: $fromStatus -> $toStatus',
    );
  }
  return toStatus;
}

/// Get all valid next statuses from a given [status].
///
/// Returns an empty set for terminal or unknown statuses.
Set<String> validNextStatuses(String status) {
  return _validTransitions[status] ?? {};
}
