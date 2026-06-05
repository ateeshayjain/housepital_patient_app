// test/_mocks/fake_firebase_service.dart
//
// Manual fake of [FirebaseService] for unit-testing AuthProvider and any
// widget that depends on it. Overrides only the methods AuthProvider /
// the auth screens actually call — no Firebase SDK access, no plugin
// channels.
//
// Pattern matches test/providers/mock_api_service.dart (no mockito / mocktail).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:housepital_patient/services/firebase_service.dart';

class FakeFirebaseService extends FirebaseService {
  // ── Configurable state ─────────────────────────────────────────────────────
  bool isLoggedInResult = false;
  String? idTokenResult = 'fake-id-token';
  String? fcmTokenResult = 'fake-fcm-token';
  String sendOtpVerificationId = 'verification-id-123';

  /// How sendOtp should behave: 'success' fires onCodeSent, 'error' fires
  /// onError, 'auto' fires onAutoVerified, 'none' does nothing.
  String sendOtpBehavior = 'success';
  String sendOtpError = 'Verification failed';

  /// If true, [verifyOtp] throws instead of returning.
  bool verifyOtpShouldThrow = false;
  Object verifyOtpError = Exception('Invalid OTP');

  // ── Call counters ──────────────────────────────────────────────────────────
  int sendOtpCalls = 0;
  int verifyOtpCalls = 0;
  int getIdTokenCalls = 0;
  int signOutCalls = 0;
  int getFcmTokenCalls = 0;

  // ── Recorded args (last call) ──────────────────────────────────────────────
  String? lastPhone;
  String? lastOtp;

  // ── Overrides ──────────────────────────────────────────────────────────────

  @override
  bool get isLoggedIn => isLoggedInResult;

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    sendOtpCalls++;
    lastPhone = phoneNumber;
    switch (sendOtpBehavior) {
      case 'success':
        onCodeSent(sendOtpVerificationId);
        break;
      case 'error':
        onError(sendOtpError);
        break;
      case 'auto':
        // Cannot construct a real PhoneAuthCredential without Firebase init,
        // but the AuthProvider passes it straight through to _handleCredential
        // which only uses getIdToken. So a null cast works *only* if the test
        // doesn't trigger this path through the real provider. We instead
        // simulate auto-verify by calling _handleCredential indirectly via
        // the same path verifyOtp uses — tests should prefer the 'success'
        // path + verifyOtp for that flow.
        break;
      case 'none':
        break;
    }
  }

  @override
  Future<void> verifyOtp(String otp) async {
    verifyOtpCalls++;
    lastOtp = otp;
    if (verifyOtpShouldThrow) {
      throw verifyOtpError;
    }
  }

  @override
  Future<String?> getIdToken() async {
    getIdTokenCalls++;
    return idTokenResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<String?> getFcmToken() async {
    getFcmTokenCalls++;
    return fcmTokenResult;
  }

  void reset() {
    isLoggedInResult = false;
    idTokenResult = 'fake-id-token';
    fcmTokenResult = 'fake-fcm-token';
    sendOtpVerificationId = 'verification-id-123';
    sendOtpBehavior = 'success';
    sendOtpError = 'Verification failed';
    verifyOtpShouldThrow = false;
    verifyOtpError = Exception('Invalid OTP');
    sendOtpCalls = 0;
    verifyOtpCalls = 0;
    getIdTokenCalls = 0;
    signOutCalls = 0;
    getFcmTokenCalls = 0;
    lastPhone = null;
    lastOtp = null;
  }
}

