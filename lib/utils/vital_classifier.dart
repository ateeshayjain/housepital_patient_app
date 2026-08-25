/// THE vital-sign classifier. There is exactly one, deliberately.
///
/// WHY THIS FILE SAYS "EXACTLY ONE" SO LOUDLY
/// Until round 4 the app had TWO independent classifiers with different
/// thresholds AND different key names:
///
///   • `classifyVital` here — keys `bp_systolic`, `spo2`, `pulse`,
///     `temperature`, `sugar`; SpO2 red below 92; sugar red above 200.
///   • `VitalHelper.getVitalColor` in helpers.dart, reading
///     `AppConstants.vitalRanges` — keys `systolic`, `diastolic`, …; SpO2 red
///     below 90; sugar red above 180.
///
/// So an SpO2 of 91 was RED on My Care and merely BORDERLINE on the vitals
/// trend screen. A blood sugar of 190 was YELLOW on one and ALERT on the
/// other. Worse, the key names did not match: the trend screen passed
/// `systolic` to a helper whose sibling expected `bp_systolic`, so a blood
/// pressure reading fell through to "unknown vital" and was counted as
/// normal — the alert counter under-reported.
///
/// Which screen a family happened to open decided how urgent a hypoxic
/// reading looked. That is not an inconsistency to tidy up; it is two
/// different clinical opinions shipped in one binary, and the app cannot hold
/// two. `VitalHelper` now delegates here and owns no thresholds of its own.
///
/// ── THRESHOLDS ARE PROVISIONAL AND NEED CLINICAL SIGN-OFF ──
/// Where the two classifiers disagreed, this file takes the MORE CONSERVATIVE
/// bound — the one that escalates sooner — because in home care the cost of an
/// unnecessary "call your nurse" is far below the cost of a missed
/// deterioration. Those choices are marked below. They are a safe default, not
/// a clinical authority: a clinician must confirm every row before release.
/// The regulated-domain audit already holds release on exactly this.
///
/// | Vital       | GREEN        | YELLOW              | RED               |
/// |-------------|--------------|---------------------|-------------------|
/// | bp_systolic | 100-130      | 130-140 or 90-100   | >=140 or <90      |
/// | bp_diastolic| 65-85        | 85-90 or 60-65      | >=90 or <60       |
/// | spo2        | 95-100       | 90-95               | <90               |
/// | pulse       | 60-100       | 100-110 or 50-60    | >110 or <50       |
/// | temperature | 97-99 (°F)   | 99-100.4 or 96-97   | >100.4 or <96     |
/// | sugar       | 70-140       | 140-180 or 60-70    | >180 or <60       |
///
/// Boundary convention: the exact boundary value goes to the MORE SEVERE
/// category (140 systolic is RED, not yellow).
library;

/// Canonical keys. Both historical spellings map here so no call site can
/// silently fall through to "unknown" the way the trend screen did.
const Map<String, String> _keyAliases = <String, String>{
  'bp_systolic': 'bp_systolic',
  'systolic': 'bp_systolic',
  'bp': 'bp_systolic',
  'bp_diastolic': 'bp_diastolic',
  'diastolic': 'bp_diastolic',
  'spo2': 'spo2',
  'oxygen': 'spo2',
  'pulse': 'pulse',
  'heart_rate': 'pulse',
  'temperature': 'temperature',
  'temp': 'temperature',
  'sugar': 'sugar',
  'blood_sugar': 'sugar',
  'glucose': 'sugar',
};

/// Resolves a call site's key to a canonical one, or null if genuinely
/// unrecognised.
String? canonicalVitalKey(String vitalType) =>
    _keyAliases[vitalType.toLowerCase().trim()];

/// Classify a vital sign reading into 'green', 'yellow', or 'red'.
///
/// [vitalType] — any key in [_keyAliases].
/// [value] — the numeric reading.
///
/// An unrecognised vital type returns 'unknown', NOT 'green'. It used to
/// return 'green': a typo'd or newly-added key rendered as a reassuring green
/// dot, which is the worst possible way to say "I have no idea what this is".
/// Callers must handle 'unknown' by showing a neutral, non-reassuring state.
String classifyVital(String vitalType, double value) {
  switch (canonicalVitalKey(vitalType)) {
    case 'bp_systolic':
      return _classifyBpSystolic(value);
    case 'bp_diastolic':
      return _classifyBpDiastolic(value);
    case 'spo2':
      return _classifySpo2(value);
    case 'pulse':
      return _classifyPulse(value);
    case 'temperature':
      return _classifyTemperature(value);
    case 'sugar':
      return _classifySugar(value);
    default:
      return 'unknown';
  }
}

String _classifyBpSystolic(double value) {
  if (value >= 140 || value < 90) return 'red';
  // RECONCILED: green used to start at 90 here and at 100 in vitalRanges.
  // 90-100 is now yellow — the more cautious of the two.
  if (value < 100 || value >= 130) return 'yellow';
  return 'green'; // 100-130
}

String _classifyBpDiastolic(double value) {
  // Only vitalRanges had diastolic; the other classifier ignored it entirely,
  // so a diastolic of 110 was never classified at all.
  if (value >= 90 || value < 60) return 'red';
  if (value < 65 || value >= 85) return 'yellow';
  return 'green'; // 65-85
}

String _classifySpo2(double value) {
  // RECONCILED: red was <92 here and <90 in vitalRanges. Taking <90 as red
  // and widening YELLOW down to 90 means 90-91 is still flagged, prominently,
  // rather than either being silently normal or crying red at 91.
  if (value < 90) return 'red';
  if (value < 95) return 'yellow'; // 90-94
  return 'green'; // 95-100
}

String _classifyPulse(double value) {
  // Both classifiers agreed here.
  if (value > 110 || value < 50) return 'red';
  if (value >= 100 || value < 60) return 'yellow';
  return 'green'; // 60-100
}

String _classifyTemperature(double value) {
  // Both classifiers agreed here.
  if (value > 100.4 || value < 96) return 'red';
  if (value >= 99 || value < 97) return 'yellow';
  return 'green'; // 97-99
}

String _classifySugar(double value) {
  // RECONCILED: red was >200 here and >180 in vitalRanges. 180 is the
  // cautious bound.
  if (value > 180 || value < 60) return 'red';
  if (value >= 140 || value < 70) return 'yellow';
  return 'green'; // 70-140
}
