import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class FirebaseService {
  FirebaseAuth? _auth;
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  String? _verificationId;

  FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  FirebaseMessaging get messaging {
    _messaging ??= FirebaseMessaging.instance;
    return _messaging!;
  }

  User? get currentUser {
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn {
    try {
      return currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Stream<User?> get authStateChanges => auth.authStateChanges();

  // ==================== PHONE AUTH ====================

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    await auth.verifyPhoneNumber(
      phoneNumber: '+91$phoneNumber',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        onAutoVerified(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<UserCredential> verifyOtp(String otp) async {
    if (_verificationId == null) {
      throw Exception('No verification ID. Send OTP first.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    return await auth.signInWithCredential(credential);
  }

  Future<String?> getIdToken() async {
    return await currentUser?.getIdToken();
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (_) {}
  }

  // ==================== FCM ====================

  Future<String?> getFcmToken() async {
    try {
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (_) {}
  }

  void onTokenRefresh(Function(String token) callback) {
    try {
      messaging.onTokenRefresh.listen(callback);
    } catch (_) {}
  }

  void setupForegroundHandler(
      Function(RemoteMessage message) onMessage) {
    try {
      FirebaseMessaging.onMessage.listen(onMessage);
    } catch (_) {}
  }

  void setupBackgroundHandler() {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (_) {}
  }

  static Future<void> _firebaseBackgroundHandler(
      RemoteMessage message) async {}

  void setupMessageOpenedApp(
      Function(RemoteMessage message) onMessageOpenedApp) {
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedApp);
    } catch (_) {}
  }

  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await messaging.getInitialMessage();
    } catch (_) {
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await messaging.subscribeToTopic(topic);
    } catch (_) {}
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await messaging.unsubscribeFromTopic(topic);
    } catch (_) {}
  }

  // ==================== FIRESTORE REAL-TIME LISTENERS ====================

  /// Listens to today's attendance for a patient.
  /// Returns an empty stream if Firestore isn't initialized.
  Stream<Map<String, dynamic>> listenToAttendance(String patientId) {
    try {
      return FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('attendance')
          .doc(_todayDateString())
          .snapshots()
          .map((snapshot) => snapshot.data() ?? {});
    } catch (e) {
      debugPrint('Firestore attendance listener skipped: $e');
      return const Stream.empty();
    }
  }

  /// Listens to latest vitals for a patient.
  /// Returns an empty stream if Firestore isn't initialized.
  Stream<Map<String, dynamic>> listenToVitals(String patientId) {
    try {
      return FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('vitals')
          .orderBy('recorded_at', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) return {};
        return snapshot.docs.first.data();
      });
    } catch (e) {
      debugPrint('Firestore vitals listener skipped: $e');
      return const Stream.empty();
    }
  }

  /// Listens to notifications for a user.
  /// Returns an empty stream if Firestore isn't initialized.
  Stream<List<Map<String, dynamic>>> listenToNotifications(String userId) {
    try {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('created_at', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
    } catch (e) {
      debugPrint('Firestore notifications listener skipped: $e');
      return const Stream.empty();
    }
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ==================== FCM SETUP ====================

  /// Full FCM setup — request permission, get token, register handlers.
  /// Wrapped in try-catch so the app doesn't crash without Firebase.
  Future<void> setupFCM({
    ApiService? apiService,
    Function(RemoteMessage message)? onForegroundMessage,
    Function(RemoteMessage message)? onMessageOpenedApp,
  }) async {
    try {
      // Request permission
      await requestNotificationPermission();

      // Get token and store via API
      final token = await getFcmToken();
      if (token != null && apiService != null) {
        try {
          await apiService.updateFcmToken(token);
        } catch (e) {
          debugPrint('FCM token registration failed: $e');
        }
      }

      // Listen for token refresh
      if (apiService != null) {
        onTokenRefresh((newToken) async {
          try {
            await apiService.updateFcmToken(newToken);
          } catch (e) {
            debugPrint('FCM token refresh registration failed: $e');
          }
        });
      }

      // Setup foreground message handler
      if (onForegroundMessage != null) {
        setupForegroundHandler(onForegroundMessage);
      }

      // Setup background handler
      setupBackgroundHandler();

      // Setup notification tap handler (onMessageOpenedApp)
      if (onMessageOpenedApp != null) {
        setupMessageOpenedApp(onMessageOpenedApp);
      }

      debugPrint('FCM setup completed successfully');
    } catch (e) {
      debugPrint('FCM setup skipped: $e');
    }
  }
}
