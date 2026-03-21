import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';

enum AuthState { initial, loading, otpSent, authenticated, onboarding, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final ApiService _apiService;

  AuthState _state = AuthState.initial;
  String? _errorMessage;
  FamilyMember? _currentUser;
  String? _phone;

  AuthProvider(this._firebaseService, this._apiService) {
    _checkAuthState();
  }

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  FamilyMember? get currentUser => _currentUser;
  String? get phone => _phone;
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
      } else {
        _state = AuthState.onboarding;
      }
    }
    notifyListeners();
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
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Setup failed. Please try again.';
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _firebaseService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUser = null;
    _state = AuthState.initial;
    notifyListeners();
  }
}
