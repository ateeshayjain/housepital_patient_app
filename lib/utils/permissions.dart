/// Role-based permission checking for Housepital Patient App.
///
/// Roles:
/// - PRIMARY_CONTACT: Full access — can book, pay, edit patient, manage family.
/// - FAMILY_MEMBER: View + limited actions — can view, rate, raise concern,
///   and request bookings (which the primary contact must approve and pay).
///   CANNOT directly book, pay, edit patient, or manage family.
/// - PATIENT_SELF: View-only access.
/// - CARETAKER: Hired staff handed temporary read-only view of one patient's
///   care plan. Can view and raise concerns (so they can flag medical issues
///   from the field) but cannot book, pay, rate, edit, or even request a
///   booking — that is the family's call, not the staff's.

/// All known roles.
class UserRole {
  static const String primaryContact = 'PRIMARY_CONTACT';
  static const String familyMember = 'FAMILY_MEMBER';
  static const String patientSelf = 'PATIENT_SELF';
  // audit M-5: hired caretaker — narrow read + concern-raising access.
  static const String caretaker = 'CARETAKER';
}

/// All known actions.
class UserAction {
  static const String book = 'book';
  static const String requestBooking = 'request_booking';
  static const String pay = 'pay';
  static const String editPatient = 'edit_patient';
  static const String manageFamily = 'manage_family';
  static const String view = 'view';
  static const String rate = 'rate';
  static const String raiseConcern = 'raise_concern';
}

/// Permission matrix: role -> set of allowed actions.
const Map<String, Set<String>> _permissions = {
  'PRIMARY_CONTACT': {
    'book',
    'request_booking',
    'pay',
    'edit_patient',
    'manage_family',
    'view',
    'rate',
    'raise_concern',
  },
  'FAMILY_MEMBER': {
    'view',
    'request_booking',
    'rate',
    'raise_concern',
  },
  'PATIENT_SELF': {
    'view',
  },
  // audit M-5: caretaker — narrower than family (no booking, no rating).
  'CARETAKER': {
    'view',
    'raise_concern',
  },
};

/// Check if a user with the given [role] can perform the given [action].
///
/// Returns `true` if the action is allowed, `false` otherwise.
/// Unknown roles or actions return `false`.
bool canUserPerform(String role, String action) {
  final allowedActions = _permissions[role];
  if (allowedActions == null) return false;
  return allowedActions.contains(action);
}

/// Get all allowed actions for a given [role].
///
/// Returns an empty set for unknown roles.
Set<String> getAllowedActions(String role) {
  return _permissions[role] ?? {};
}
