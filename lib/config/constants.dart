class AppConstants {
  // API Configuration - Update with your backend URL
  static const String apiBaseUrl = 'https://api.housepital.in/v1';

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
  static const Map<String, Map<String, double>> vitalRanges = {
    'systolic': {'low': 90, 'normalLow': 100, 'normalHigh': 130, 'high': 140},
    'diastolic': {'low': 60, 'normalLow': 65, 'normalHigh': 85, 'high': 90},
    'pulse': {'low': 50, 'normalLow': 60, 'normalHigh': 100, 'high': 110},
    'spo2': {'low': 90, 'normalLow': 95, 'normalHigh': 100, 'high': 100},
    'temperature': {'low': 96.0, 'normalLow': 97.0, 'normalHigh': 99.0, 'high': 100.4},
    'sugar': {'low': 60, 'normalLow': 70, 'normalHigh': 140, 'high': 180},
  };

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
