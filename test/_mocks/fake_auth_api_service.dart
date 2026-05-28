// test/_mocks/fake_auth_api_service.dart
//
// Lightweight fake of [ApiService] that overrides only the methods used by
// AuthProvider. Sister of test/providers/mock_api_service.dart but scoped
// to auth-flow tests so we don't pull medication/care fixtures in.

import 'package:housepital_patient/services/api_service.dart';

class FakeAuthApiService extends ApiService {
  // ── State ──────────────────────────────────────────────────────────────────
  String? lastAuthToken;
  bool completeOnboardingShouldThrow = false;
  bool updateFcmTokenShouldThrow = false;

  // ── Counters ───────────────────────────────────────────────────────────────
  int setAuthTokenCalls = 0;
  int completeOnboardingCalls = 0;
  int updateFcmTokenCalls = 0;

  // ── Recorded args ──────────────────────────────────────────────────────────
  String? lastName;
  String? lastRelationship;
  String? lastPreferredLanguage;
  String? lastFcmToken;

  @override
  void setAuthToken(String token) {
    setAuthTokenCalls++;
    lastAuthToken = token;
  }

  @override
  Future<Map<String, dynamic>> completeOnboarding({
    required String name,
    required String relationship,
    required String preferredLanguage,
  }) async {
    completeOnboardingCalls++;
    lastName = name;
    lastRelationship = relationship;
    lastPreferredLanguage = preferredLanguage;
    if (completeOnboardingShouldThrow) {
      throw ApiException(statusCode: 500, message: 'onboarding failed');
    }
    return {};
  }

  @override
  Future<void> updateFcmToken(String token) async {
    updateFcmTokenCalls++;
    lastFcmToken = token;
    if (updateFcmTokenShouldThrow) {
      throw ApiException(statusCode: 500, message: 'fcm failed');
    }
  }
}
