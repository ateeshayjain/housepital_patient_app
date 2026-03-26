/// Vital sign alert classification: green / yellow / red.
///
/// Thresholds (boundary belongs to the MORE SEVERE category):
///
/// | Vital       | GREEN        | YELLOW              | RED               |
/// |-------------|--------------|---------------------|-------------------|
/// | bp_systolic | 90-130       | 130-140 or 80-90    | >140 or <80       |
/// | spo2        | 95-100       | 92-95               | <92               |
/// | pulse       | 60-100       | 100-110 or 50-60    | >110 or <50       |
/// | temperature | 97-99 (°F)   | 99-100.4            | >100.4 or <96     |
/// | sugar       | 70-140       | 140-200 or 60-70    | >200 or <60       |
///
/// Boundary convention: the exact boundary value goes to the MORE SEVERE
/// category (e.g. 140 bp_systolic is RED, not yellow).

/// Classify a vital sign reading into 'green', 'yellow', or 'red'.
///
/// [vitalType] — one of: bp_systolic, spo2, pulse, temperature, sugar.
/// [value] — the numeric reading.
///
/// Returns 'green', 'yellow', or 'red'.
/// Throws [ArgumentError] for unknown vital types.
String classifyVital(String vitalType, double value) {
  switch (vitalType) {
    case 'bp_systolic':
      return _classifyBpSystolic(value);
    case 'spo2':
      return _classifySpo2(value);
    case 'pulse':
      return _classifyPulse(value);
    case 'temperature':
      return _classifyTemperature(value);
    case 'sugar':
      return _classifySugar(value);
    default:
      return 'green'; // Safe fallback for unknown vital types
  }
}

String _classifyBpSystolic(double value) {
  if (value >= 140 || value < 80) return 'red';
  if ((value >= 130 && value < 140) || (value >= 80 && value < 90)) {
    return 'yellow';
  }
  return 'green'; // 90-130 (inclusive both ends for green)
}

String _classifySpo2(double value) {
  if (value < 92) return 'red';
  if (value < 95) return 'yellow'; // 92-94
  return 'green'; // 95-100
}

String _classifyPulse(double value) {
  if (value > 110 || value < 50) return 'red';
  if ((value >= 100 && value <= 110) || (value >= 50 && value < 60)) {
    return 'yellow';
  }
  return 'green'; // 60-100 (inclusive both ends)
}

String _classifyTemperature(double value) {
  if (value > 100.4 || value < 96) return 'red';
  if (value >= 99 && value <= 100.4) return 'yellow';
  if (value < 97) return 'yellow'; // 96-97 borderline low
  return 'green'; // 97-99 (inclusive both ends for green)
}

String _classifySugar(double value) {
  if (value > 200 || value < 60) return 'red';
  if ((value >= 140 && value <= 200) || (value >= 60 && value < 70)) {
    return 'yellow';
  }
  return 'green'; // 70-140 (inclusive both ends)
}
