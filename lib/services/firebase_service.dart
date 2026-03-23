import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

class FirebaseService {
  FirebaseAuth? _auth;
  FirebaseMessaging? _messaging;
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

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
    } catch (e) {
      debugPrint('FirebaseService: currentUser failed: $e');
      return null;
    }
  }

  bool get isLoggedIn {
    try {
      return currentUser != null;
    } catch (e) {
      debugPrint('FirebaseService: isLoggedIn failed: $e');
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
    } catch (e) {
      debugPrint('FirebaseService: signOut failed: $e');
    }
  }

  // ==================== FCM ====================

  Future<String?> getFcmToken() async {
    try {
      return await messaging.getToken();
    } catch (e) {
      debugPrint('FirebaseService: getFcmToken failed: $e');
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
    } catch (e) {
      debugPrint('FirebaseService: requestNotificationPermission failed: $e');
    }
  }

  void onTokenRefresh(Function(String token) callback) {
    try {
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen(callback);
    } catch (e) {
      debugPrint('FirebaseService: onTokenRefresh failed: $e');
    }
  }

  void setupForegroundHandler(
      Function(RemoteMessage message) onMessage) {
    try {
      FirebaseMessaging.onMessage.listen(onMessage);
    } catch (e) {
      debugPrint('FirebaseService: setupForegroundHandler failed: $e');
    }
  }

  void setupBackgroundHandler() {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('FirebaseService: setupBackgroundHandler failed: $e');
    }
  }

  static Future<void> _firebaseBackgroundHandler(
      RemoteMessage message) async {}

  void setupMessageOpenedApp(
      Function(RemoteMessage message) onMessageOpenedApp) {
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedApp);
    } catch (e) {
      debugPrint('FirebaseService: setupMessageOpenedApp failed: $e');
    }
  }

  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await messaging.getInitialMessage();
    } catch (e) {
      debugPrint('FirebaseService: getInitialMessage failed: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('FirebaseService: subscribeToTopic failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('FirebaseService: unsubscribeFromTopic failed: $e');
    }
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
  ///
  /// [navigatorKey] – a GlobalKey<NavigatorState> so we can push routes from
  /// notification taps without a local BuildContext.
  Future<void> setupFCM({
    ApiService? apiService,
    Function(RemoteMessage message)? onForegroundMessage,
    Function(RemoteMessage message)? onMessageOpenedApp,
    GlobalKey<NavigatorState>? navigatorKey,
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

      // Handle cold-start (getInitialMessage)
      if (navigatorKey != null) {
        final initialMessage = await getInitialMessage();
        if (initialMessage != null) {
          _routeFromMessage(initialMessage, navigatorKey);
        }
      }

      debugPrint('FCM setup completed successfully');
    } catch (e) {
      debugPrint('FCM setup skipped: $e');
    }
  }

  /// Convenience: extract data payload from a RemoteMessage and route.
  void _routeFromMessage(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    final data = message.data;
    if (data.isEmpty) return;
    // Defer until the navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      // Use NotificationRouter (imported at call-site in main.dart)
      _pendingNotificationData = data;
    });
  }

  /// Pending notification data from cold-start that main.dart can pick up.
  Map<String, dynamic>? _pendingNotificationData;
  Map<String, dynamic>? consumePendingNotification() {
    final data = _pendingNotificationData;
    _pendingNotificationData = null;
    return data;
  }

  /// Cancel stream subscriptions to prevent memory leaks.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}
