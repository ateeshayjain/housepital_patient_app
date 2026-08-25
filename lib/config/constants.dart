class AppConstants {
  // API base URL. Overridable at build time:
  //   --dart-define=API_BASE_URL=https://staging.housepital.in/v1
  //
  // This was a plain `const` with the production host baked in, while the
  // correct idiom sat eight lines below for `assistantApiUrl` — someone knew
  // the pattern, applied it to the newer constant, and never came back for
  // this one. The consequence was not cosmetic: a debug build and a store
  // build hit the SAME server, so there was no way to point a build at
  // staging, no way to exercise the app against a backend without touching
  // production data, and no way for QA to run anywhere but prod.
  //
  // The default is unchanged, so an un-defined build behaves exactly as
  // before.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.housepital.in/v1',
  );

  /// True when this build points somewhere other than production. Used to
  /// surface the target in-app so a tester can never mistake a staging build
  /// for a production one — or, worse, the reverse.
  static bool get isNonProductionApi =>
      apiBaseUrl != 'https://api.housepital.in/v1';

  // AI Assistant (Sahayak) endpoint — the Firebase Cloud Function URL.
  // Set at build time:  --dart-define=ASSISTANT_API_URL=https://...
  // When empty (default), the assistant runs on the offline Hinglish keyword
  // stub so the feature still works without the backend. When set, the app
  // calls the real Claude-powered endpoint.
  static const String assistantApiUrl =
      String.fromEnvironment('ASSISTANT_API_URL', defaultValue: '');

  // Firebase
  static const String fcmTopic = 'housepital_patient';

  // Housepital Contact
  static const String emergencyPhone = '9990911911';
  static const String emergencyNumber112 = '112';
  static const String supportPhone = '9990911911';
  static const String website = 'www.housepital.in';

  // Razorpay — pass real key via --dart-define=RAZORPAY_KEY=rzp_live_xxx
  static const razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_XXXXXXXXXX', // Test key fallback for dev
  );

  // Pagination
  static const int pageSize = 20;

  // Vitals Normal Ranges
  // REMOVED: `vitalRanges`. It was the app's SECOND set of vital thresholds,
  // read only by VitalHelper, and it disagreed with vital_classifier.dart on
  // SpO2 (red <90 vs <92), sugar (red >180 vs >200) and systolic — under
  // different key names, so a reading could match one map and neither the
  // other. Thresholds now live in exactly one place:
  // lib/utils/vital_classifier.dart. Do not reintroduce a second source.

  // Attendance Grace Period (minutes)
  static const int attendanceGracePeriod = 30;
  static const int attendanceAbsentThreshold = 60;

  // Concern SLA (hours)
  static const Map<String, int> concernSla = {
    'emergency': 2,
    'high': 12,
    'medium': 24,
    'low': 72,
  };

  // Service Categories
  static const List<String> instantServices = [
    'nursing_visit',
    'physio_visit',
    'sleep_therapy',
    'lab_test',
  ];

  static const List<String> assessmentServices = [
    'caretaker',
    'nursing_deployment',
    'icu_setup',
    'japa',
    'nanny',
  ];

  // Relationships
  static const List<String> relationships = [
    'spouse',
    'son',
    'daughter',
    'son_in_law',
    'daughter_in_law',
    'sibling',
    'other',
  ];

  // Cities
  static const List<String> cities = [
    'faridabad',
    'delhi',
    'noida',
    'ghaziabad',
    'gurgaon',
  ];
}
