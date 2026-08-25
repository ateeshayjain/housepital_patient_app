import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/i_api_service.dart';
import '../utils/logger.dart';

enum AuthState { initial, loading, otpSent, authenticated, onboarding, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  // audit batch 4 (Agent J): depend on IApiService (DIP), not the concrete
  // ApiService — keeps the auth flow trivially fakeable in tests.
  final IApiService _apiService;

  AuthState _state = AuthState.initial;
  String? _errorMessage;
  FamilyMember? _currentUser;
  String? _phone;

  // audit batch 4 (Agent J): proactive token refresh.
  // Firebase ID tokens are valid for 60 minutes. We refresh at 50 min so we
  // have a 10-min buffer before Firebase's 60-min hard expiry — users on flaky
  // networks then get a token-not-yet-expired in their request cache rather
  // than discovering expiry mid-request. The 401-recovery path in ApiService
  // is the safety net for the (rare) case where a request still races expiry.
  static const Duration _tokenRefreshInterval = Duration(minutes: 50);
  Timer? _tokenRefreshTimer;

  AuthProvider(this._firebaseService, this._apiService) {
    _checkAuthState();
  }

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  FamilyMember? get currentUser => _currentUser;
  String? get phone => _phone;

  /// Expose services for FCM setup in main.dart.
  FirebaseService get firebaseService => _firebaseService;
  IApiService get apiService => _apiService;
  bool get isLoggedIn => _state == AuthState.authenticated;
  bool get isPrimaryContact => _currentUser?.isPrimaryContact ?? false;

  Future<void> _checkAuthState() async {
    if (_firebaseService.isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('has_onboarded') ?? false;
      if (hasOnboarded) {
        final token = await _firebaseService.getIdToken();
        if (token != null) {
          _apiService.setAuthToken(token);
        }
        _state = AuthState.authenticated;
        // audit batch 4 (Agent J): kick off periodic token refresh once we
        // know we have an authenticated session restored from cold start.
        _startTokenRefreshTimer();
      } else {
        _state = AuthState.onboarding;
      }
    }
    notifyListeners();
  }

  // ── audit batch 4 (Agent J): Token refresh ─────────────────────────────
  // Firebase ID tokens are valid for 60 minutes; without proactive refresh,
  // users on long-running sessions get 401s and (pre-fix) had to restart the
  // app. Two layers:
  //   1) Periodic refresh every 50 min (this timer).
  //   2) One-shot refresh + single retry on 401 (in [authorizedCall]).
  // If refresh itself fails (refresh token revoked / expired), we logout —
  // the user must re-authenticate via OTP.
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) async {
      await _refreshToken();
    });
  }

  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Forces a Firebase ID token refresh and pushes the new token into the API
  /// client. Returns true on success, false if Firebase rejected the refresh
  /// (in which case the caller will typically logout).
  Future<bool> _refreshToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final fresh = await user.getIdToken(true);
      if (fresh == null) return false;
      _apiService.setAuthToken(fresh);
      return true;
    } catch (e) {
      Log.warn('Token refresh failed', error: e, tag: 'AuthProvider');
      return false;
    }
  }

  /// Public hook for API call sites that hit a 401: refresh the token once,
  /// then let the caller retry the original request. If refresh fails the
  /// user is logged out (refresh token expired/revoked). Returns true if
  /// the caller should retry, false if it should surface the 401.
  /// Fired when an involuntary logout happens (401 / refresh failure).
  ///
  /// [logout] only clears auth state and storage; the provider fan-out and the
  /// cancellation of OS-scheduled medication notifications live in
  /// SessionScope, which needs a BuildContext this class does not have. The
  /// shell wires this. Without it, the logout path MOST likely to fire on a
  /// lost or shared phone was the one that cleared nothing.
  Future<void> Function()? onForcedLogout;

  Future<bool> handleUnauthorized() async {
    final ok = await _refreshToken();
    if (!ok) {
      final hook = onForcedLogout;
      if (hook != null) {
        try {
          await hook();
        } catch (e) {
          Log.warn('Forced-logout fan-out failed', error: e, tag: 'AuthProvider');
        }
      }
      await logout();
      return false;
    }
    return true;
  }

  Future<void> sendOtp(String phoneNumber) async {
    _state = AuthState.loading;
    _errorMessage = null;
    _phone = phoneNumber;
    notifyListeners();

    await _firebaseService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        _state = AuthState.otpSent;
        notifyListeners();
      },
      onError: (error) {
        _state = AuthState.error;
        _errorMessage = error;
        notifyListeners();
      },
      onAutoVerified: (credential) async {
        await _handleCredential();
      },
    );
  }

  Future<void> verifyOtp(String otp) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.verifyOtp(otp);
      await _handleCredential();
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Invalid OTP. Please try again.';
      notifyListeners();
    }
  }

  Future<void> _handleCredential() async {
    try {
      final token = await _firebaseService.getIdToken();
      if (token != null) {
        _apiService.setAuthToken(token);
      }

      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('has_onboarded') ?? false;

      if (hasOnboarded) {
        _state = AuthState.authenticated;
        // audit batch 4 (Agent J): start periodic refresh on fresh login.
        _startTokenRefreshTimer();
      } else {
        _state = AuthState.onboarding;
      }
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Authentication failed. Please try again.';
    }
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String relationship,
    required String preferredLanguage,
  }) async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      await _apiService.completeOnboarding(
        name: name,
        relationship: relationship,
        preferredLanguage: preferredLanguage,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_onboarded', true);
      await prefs.setString('preferred_language', preferredLanguage);

      // Register FCM token
      final fcmToken = await _firebaseService.getFcmToken();
      if (fcmToken != null) {
        await _apiService.updateFcmToken(fcmToken);
      }

      _state = AuthState.authenticated;
      // audit batch 4 (Agent J): start periodic refresh once onboarding
      // completes — this is the other "fresh login" path besides
      // _handleCredential (for users who land directly in onboarding).
      _startTokenRefreshTimer();
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Setup failed. Please try again.';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    // audit batch 4 (Agent J): stop the refresh timer first so a tick
    // in flight can't race the sign-out and set a stale token.
    _stopTokenRefreshTimer();
    await _firebaseService.signOut();
    final prefs = await SharedPreferences.getInstance();
    // prefs.clear() used to take EVERYTHING, including two keys that must
    // outlive a session:
    //   • the storage schema stamp — clearing it makes the next launch look
    //     like a pre-versioning install and re-run migrations against already
    //     migrated data;
    //   • a pending account-deletion request — the only evidence the user
    //     ever asked, and the thing a future backend replays.
    // Neither is patient data. Everything else still goes.
    const preserved = <String>{
      'housepital_schema_version',
      'housepital_pending_deletion',
    };
    // Quarantined blobs are the ONLY copy of data a migration could not
    // attribute — after v1->v2 they hold a pre-upgrade user's entire order
    // history. Wiping them on the first logout destroyed it permanently.
    // They are not patient-readable and carry no session state.
    const preservedPrefixes = <String>['__quarantine_'];
    for (final key in prefs.getKeys().toList()) {
      if (preserved.contains(key)) continue;
      if (preservedPrefixes.any(key.startsWith)) continue;
      await prefs.remove(key);
    }
    _currentUser = null;
    _state = AuthState.initial;
    notifyListeners();
  }

  @override
  void dispose() {
    // audit batch 4 (Agent J): defensive — providers attached to MultiProvider
    // are typically long-lived, but if disposed (e.g. hot restart in dev) we
    // must not leak the Timer.
    _stopTokenRefreshTimer();
    super.dispose();
  }
}
