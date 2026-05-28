// audit batch 4 (Agent I): centralized form validators — single source of
// truth so all forms accept the same input shape. Previously each screen
// rolled its own regex/length checks (`length != 10`, `contains('@')`, etc.),
// which let invalid data through inconsistently. Each method returns the
// Flutter `FormFieldValidator<String>` contract: `null` if valid, or an
// actionable error message string.

/// Centralized form validators — single source of truth so all forms accept
/// the same input shape.
///
/// Each method matches Flutter's `FormFieldValidator<String>` signature:
/// returns `null` when the value is valid, or a user-facing error string
/// when it isn't. Pass `required: false` for optional fields — an empty
/// value will then be treated as valid.
///
/// Used by login, family members, add patient, address selection, raise
/// concern, and patient profile forms (audit batch 4 wiring).
class Validators {
  // Block instantiation — this is a static utility.
  Validators._();

  /// Indian mobile: 10 digits, leading digit 6-9 per TRAI numbering plan.
  ///
  /// Rejects landlines, 0-prefixed dialouts, and obviously-malformed inputs
  /// (mixed letters, wrong length). Returns null if valid.
  static String? indianMobile(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Mobile number is required' : null;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Enter a valid 10-digit Indian mobile (starts with 6-9)';
    }
    return null;
  }

  /// Pragmatic email regex — not RFC-perfect, but rejects obvious typos
  /// (`foo`, `foo@`, `foo@bar`). Local-part allows the common safe set.
  static String? email(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Email is required' : null;
    }
    final r = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!r.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  /// Indian pincode: exactly 6 digits, first digit 1-9 (0-prefix invalid).
  static String? pincode(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Pincode is required' : null;
    }
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(value)) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }

  /// Patient/family name: 2..max chars, only letters, spaces, dots, hyphens,
  /// or apostrophes (covers compound Indian names, initials, hyphenated
  /// surnames, names like "D'Souza"). Default max 60.
  static String? name(String? value, {bool required = true, int max = 60}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Name is required' : null;
    }
    final v = value.trim();
    if (v.length < 2) return 'Name is too short';
    if (v.length > max) return 'Name is too long (max $max)';
    if (!RegExp(r"^[A-Za-z .\-']+$").hasMatch(v)) {
      return 'Use letters, spaces, dots, hyphens, or apostrophes only';
    }
    return null;
  }

  /// Age: integer 0..150. Anything non-numeric or out-of-range is rejected.
  static String? age(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Age is required' : null;
    }
    final n = int.tryParse(value);
    if (n == null) return 'Must be a number';
    if (n < 0 || n > 150) return 'Invalid age';
    return null;
  }

  /// Description / long-form text: required + maxLength cap.
  ///
  /// Audit F finding: `raise_concern` accepted unbounded body (~10MB DoS
  /// risk via the API). Default cap 1000 chars; pair with `maxLength:` on
  /// the TextFormField to surface a character counter.
  static String? description(
    String? value, {
    bool required = true,
    int max = 1000,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Please describe the issue' : null;
    }
    if (value.length > max) {
      return 'Too long (max $max characters)';
    }
    return null;
  }
}
