/// Role-based permission checking for Housepital Patient App.
///
/// Roles:
/// - PRIMARY_CONTACT: Full access — can book, pay, edit patient, manage family.
/// - FAMILY_MEMBER: View + limited actions — can view, book, rate, raise concern.
///   CANNOT pay, edit patient, or manage family.
/// - PATIENT_SELF: View-only access.

/// All known roles.
class UserRole {
  static const String primaryContact = 'PRIMARY_CONTACT';
  static const String familyMember = 'FAMILY_MEMBER';
  static const String patientSelf = 'PATIENT_SELF';
}

/// All known actions.
class UserAction {
  static const String book = 'book';
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
    'pay',
    'edit_patient',
    'manage_family',
    'view',
    'rate',
    'raise_concern',
  },
  'FAMILY_MEMBER': {
    'view',
    'book',
    'rate',
    'raise_concern',
  },
  'PATIENT_SELF': {
    'view',
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
