// test/providers/auth_provider_test.dart
//
// Unit tests for [AuthProvider] (KNOWN_ISSUES BUG-08).
//
// Uses a hand-rolled FakeFirebaseService (no mockito / firebase_auth_mocks,
// no plugin channels) plus FakeAuthApiService — same pattern as
// test/providers/mock_api_service.dart.
//
// What we cover:
//   - Initial state (not logged-in, no current user)
//   - sendOtp success / error / loading flow
//   - verifyOtp success + onboarding-vs-authenticated split
//   - verifyOtp wrong code → error state, no user
//   - completeOnboarding persists prefs + registers FCM token
//   - logout clears state + prefs
//   - Cold-start: SharedPreferences pre-seeded vs empty (auth-state restore)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/providers/auth_provider.dart';

import '../_mocks/fake_firebase_service.dart';
import '../_mocks/fake_auth_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseService firebase;
  late FakeAuthApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebase = FakeFirebaseService();
    api = FakeAuthApiService();
  });

  // ── helper: build a provider and let the async _checkAuthState complete ────
  Future<AuthProvider> buildProvider() async {
    final p = AuthProvider(firebase, api);
    // _checkAuthState is fire-and-forget in the ctor; flush microtasks.
    await Future<void>.delayed(Duration.zero);
    return p;
  }

  // =========================================================================
  group('AuthProvider — initial state', () {
    test('with no firebase session: state is initial and not logged in',
        () async {
      firebase.isLoggedInResult = false;
      final provider = await buildProvider();

      expect(provider.state, AuthState.initial);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.currentUser, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.phone, isNull);
    });

    test('isPrimaryContact is false when currentUser is null', () async {
      final provider = await buildProvider();
      expect(provider.isPrimaryContact, isFalse);
    });

    test('exposes injected services', () async {
      final provider = await buildProvider();
      expect(provider.firebaseService, same(firebase));
      expect(provider.apiService, same(api));
    });
  });

  // =========================================================================
  group('AuthProvider — cold-start session restore', () {
    test(
        'firebase logged-in + has_onboarded=true → state authenticated, '
        'token set on api', () async {
      firebase.isLoggedInResult = true;
      firebase.idTokenResult = 'restored-token';
      SharedPreferences.setMockInitialValues({'has_onboarded': true});

      final provider = await buildProvider();

      expect(provider.state, AuthState.authenticated);
      expect(provider.isLoggedIn, isTrue);
      expect(api.setAuthTokenCalls, 1);
      expect(api.lastAuthToken, 'restored-token');
    });

    test(
        'firebase logged-in + has_onboarded missing → state onboarding, '
        'no token set', () async {
      firebase.isLoggedInResult = true;
      SharedPreferences.setMockInitialValues({});

      final provider = await buildProvider();

      expect(provider.state, AuthState.onboarding);
      expect(provider.isLoggedIn, isFalse);
      expect(api.setAuthTokenCalls, 0);
    });

    test('firebase logged-in but token is null → no setAuthToken', () async {
      firebase.isLoggedInResult = true;
      firebase.idTokenResult = null;
      SharedPreferences.setMockInitialValues({'has_onboarded': true});

      final provider = await buildProvider();

      expect(provider.state, AuthState.authenticated);
      expect(api.setAuthTokenCalls, 0);
    });
  });

  // =========================================================================
  group('AuthProvider — sendOtp', () {
    test('success path: phone stored, state transitions loading → otpSent',
        () async {
      final provider = await buildProvider();

      final states = <AuthState>[];
      provider.addListener(() => states.add(provider.state));

      await provider.sendOtp('9876543210');

      expect(firebase.sendOtpCalls, 1);
      expect(firebase.lastPhone, '9876543210');
      expect(provider.phone, '9876543210');
      expect(provider.state, AuthState.otpSent);
      expect(provider.errorMessage, isNull);
      // We notified at least twice: into loading, then into otpSent.
      expect(states, containsAllInOrder([AuthState.loading, AuthState.otpSent]));
    });

    test('error path: state error, errorMessage populated, phone retained',
        () async {
      firebase.sendOtpBehavior = 'error';
      firebase.sendOtpError = 'Invalid phone number';
      final provider = await buildProvider();

      await provider.sendOtp('9876543210');

      expect(provider.state, AuthState.error);
      expect(provider.errorMessage, 'Invalid phone number');
      expect(provider.phone, '9876543210');
    });

    test('clears stale errorMessage at the start of a fresh send', () async {
      firebase.sendOtpBehavior = 'error';
      firebase.sendOtpError = 'first failure';
      final provider = await buildProvider();
      await provider.sendOtp('9876543210');
      expect(provider.errorMessage, 'first failure');

      // Now a successful retry.
      firebase.sendOtpBehavior = 'success';
      await provider.sendOtp('9876543210');
      expect(provider.errorMessage, isNull);
      expect(provider.state, AuthState.otpSent);
    });
  });

  // =========================================================================
  group('AuthProvider — verifyOtp', () {
    test(
        'success + has_onboarded=true → authenticated, token set, no error',
        () async {
      SharedPreferences.setMockInitialValues({'has_onboarded': true});
      firebase.idTokenResult = 'fresh-token';
      final provider = await buildProvider();

      await provider.verifyOtp('123456');

      expect(firebase.verifyOtpCalls, 1);
      expect(firebase.lastOtp, '123456');
      expect(provider.state, AuthState.authenticated);
      expect(provider.errorMessage, isNull);
      expect(api.lastAuthToken, 'fresh-token');
    });

    test(
        'success + has_onboarded missing → state onboarding (NOT authenticated)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await buildProvider();

      await provider.verifyOtp('123456');

      expect(provider.state, AuthState.onboarding);
      expect(provider.isLoggedIn, isFalse);
    });

    test('wrong code: state error, friendly message, no token set', () async {
      firebase.verifyOtpShouldThrow = true;
      final provider = await buildProvider();

      await provider.verifyOtp('000000');

      expect(provider.state, AuthState.error);
      expect(provider.errorMessage, 'Invalid OTP. Please try again.');
      expect(api.setAuthTokenCalls, 0);
    });

    test('notifies listeners at least twice (loading then resolved)',
        () async {
      SharedPreferences.setMockInitialValues({'has_onboarded': true});
      final provider = await buildProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.verifyOtp('123456');

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });

  // =========================================================================
  group('AuthProvider — completeOnboarding', () {
    test(
        'success: api called, has_onboarded + preferred_language persisted, '
        'state authenticated, FCM token registered', () async {
      final provider = await buildProvider();

      await provider.completeOnboarding(
        name: 'Ateeshay',
        relationship: 'son',
        preferredLanguage: 'hi',
      );

      expect(api.completeOnboardingCalls, 1);
      expect(api.lastName, 'Ateeshay');
      expect(api.lastRelationship, 'son');
      expect(api.lastPreferredLanguage, 'hi');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_onboarded'), isTrue);
      expect(prefs.getString('preferred_language'), 'hi');

      expect(firebase.getFcmTokenCalls, 1);
      expect(api.updateFcmTokenCalls, 1);
      expect(api.lastFcmToken, 'fake-fcm-token');

      expect(provider.state, AuthState.authenticated);
    });

    test('skips FCM registration when token is null', () async {
      firebase.fcmTokenResult = null;
      final provider = await buildProvider();

      await provider.completeOnboarding(
        name: 'A',
        relationship: 'self',
        preferredLanguage: 'en',
      );

      expect(api.updateFcmTokenCalls, 0);
      expect(provider.state, AuthState.authenticated);
    });

    test('api failure: state error, friendly message', () async {
      api.completeOnboardingShouldThrow = true;
      final provider = await buildProvider();

      await provider.completeOnboarding(
        name: 'A',
        relationship: 'self',
        preferredLanguage: 'en',
      );

      expect(provider.state, AuthState.error);
      expect(provider.errorMessage, 'Setup failed. Please try again.');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_onboarded'), isNot(true));
    });
  });

  // =========================================================================
  group('AuthProvider — logout', () {
    test('signs out of firebase, clears prefs, resets state, notifies',
        () async {
      SharedPreferences.setMockInitialValues({
        'has_onboarded': true,
        'preferred_language': 'hi',
        'some_other_pref': 'value',
      });
      firebase.isLoggedInResult = true;
      final provider = await buildProvider();
      // After construction, provider may be in 'authenticated'.

      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.logout();

      expect(firebase.signOutCalls, 1);
      expect(provider.currentUser, isNull);
      expect(provider.state, AuthState.initial);
      expect(provider.isLoggedIn, isFalse);
      expect(notifications, greaterThanOrEqualTo(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  // =========================================================================
  group('AuthProvider — listener contract', () {
    test('removed listener does not fire (sanity for dispose-safety)',
        () async {
      final provider = await buildProvider();
      int hits = 0;
      void cb() => hits++;
      provider.addListener(cb);
      await provider.sendOtp('9876543210');
      final hitsAfterFirst = hits;
      provider.removeListener(cb);
      await provider.sendOtp('9876543210');
      expect(hits, hitsAfterFirst);
    });
  });

}
