import 'dart:async';
import 'dart:io' show File;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../utils/logger.dart';
import 'i_api_service.dart';

class FirebaseService {
  FirebaseAuth? _auth;
  FirebaseMessaging? _messaging;
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
      Log.warn('currentUser failed', error: e, tag: 'FirebaseService');
      return null;
    }
  }

  bool get isLoggedIn {
    try {
      return currentUser != null;
    } catch (e) {
      Log.warn('isLoggedIn failed', error: e, tag: 'FirebaseService');
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

  // Returns Future<void> (was Future<UserCredential>) — the only caller,
  // [AuthProvider.verifyOtp], discards the credential and calls
  // [getIdToken] separately. Narrowing the return type lets unit tests
  // substitute a fake without needing to construct a real [UserCredential]
  // (which has a private constructor that requires real Firebase init).
  Future<void> verifyOtp(String otp) async {
    if (_verificationId == null) {
      throw Exception('No verification ID. Send OTP first.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    await auth.signInWithCredential(credential);
  }

  Future<String?> getIdToken() async {
    return await currentUser?.getIdToken();
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      Log.warn('signOut failed', error: e, tag: 'FirebaseService');
    }
  }

  // ==================== STORAGE ====================

  // audit M-9: upload local files to Firebase Storage and return public download URL.
  // Previously chat/raise-concern wrote local device paths into Firestore, which
  // coordinators couldn't open.
  /// Uploads a local file to Firebase Storage and returns the public download URL.
  /// Returns null on failure (caller should handle the null gracefully).
  ///
  /// On web (`kIsWeb`) this is a no-op returning null — file uploads from a web
  /// blob need a different code path (use `putData` with bytes). The current
  /// call sites (chat photo, concern evidence) are mobile-only flows.
  Future<String?> uploadFile({
    required String localPath,
    required String storagePath, // e.g. "chat/{patientId}/{ts}_{filename}"
    String? contentType,
  }) async {
    if (kIsWeb) {
      Log.debug('uploadFile skipped on web (use putData for web blobs)',
          tag: 'FirebaseService');
      return null;
    }
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        Log.warn('uploadFile: local file does not exist: $localPath',
            tag: 'FirebaseService');
        return null;
      }
      final ref = FirebaseStorage.instance.ref(storagePath);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;
      await ref.putFile(file, metadata);
      return await ref.getDownloadURL();
    } catch (e, st) {
      Log.error('uploadFile failed', error: e, stack: st, tag: 'FirebaseService');
      return null;
    }
  }

  // ==================== FCM ====================

  Future<String?> getFcmToken() async {
    try {
      return await messaging.getToken();
    } catch (e) {
      Log.warn('getFcmToken failed', error: e, tag: 'FirebaseService');
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
      Log.warn('requestNotificationPermission failed',
          error: e, tag: 'FirebaseService');
    }
  }

  void onTokenRefresh(Function(String token) callback) {
    try {
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen(callback);
    } catch (e) {
      Log.warn('onTokenRefresh failed', error: e, tag: 'FirebaseService');
    }
  }

  void setupForegroundHandler(
      Function(RemoteMessage message) onMessage) {
    try {
      FirebaseMessaging.onMessage.listen(onMessage);
    } catch (e) {
      Log.warn('setupForegroundHandler failed', error: e, tag: 'FirebaseService');
    }
  }

  void setupBackgroundHandler() {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      Log.warn('setupBackgroundHandler failed', error: e, tag: 'FirebaseService');
    }
  }

  static Future<void> _firebaseBackgroundHandler(
      RemoteMessage message) async {}

  void setupMessageOpenedApp(
      Function(RemoteMessage message) onMessageOpenedApp) {
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(onMessageOpenedApp);
    } catch (e) {
      Log.warn('setupMessageOpenedApp failed', error: e, tag: 'FirebaseService');
    }
  }

  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await messaging.getInitialMessage();
    } catch (e) {
      Log.warn('getInitialMessage failed', error: e, tag: 'FirebaseService');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await messaging.subscribeToTopic(topic);
    } catch (e) {
      Log.warn('subscribeToTopic failed', error: e, tag: 'FirebaseService');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      Log.warn('unsubscribeFromTopic failed', error: e, tag: 'FirebaseService');
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
      Log.warn('Firestore attendance listener skipped',
          error: e, tag: 'FirebaseService');
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
      Log.warn('Firestore vitals listener skipped',
          error: e, tag: 'FirebaseService');
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
      Log.warn('Firestore notifications listener skipped',
          error: e, tag: 'FirebaseService');
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
  /// [navigatorKey] – a `GlobalKey<NavigatorState>` so we can push routes from
  /// notification taps without a local BuildContext.
  Future<void> setupFCM({
    // audit batch 4 (Agent J): accept the interface (DIP) — callers pass
    // AuthProvider.apiService which now returns IApiService.
    IApiService? apiService,
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
          Log.warn('FCM token registration failed',
              error: e, tag: 'FirebaseService');
        }
      }

      // Listen for token refresh
      if (apiService != null) {
        onTokenRefresh((newToken) async {
          try {
            await apiService.updateFcmToken(newToken);
          } catch (e) {
            Log.warn('FCM token refresh registration failed',
              error: e, tag: 'FirebaseService');
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

      Log.info('FCM setup completed successfully', tag: 'FirebaseService');
    } catch (e) {
      Log.warn('FCM setup skipped', error: e, tag: 'FirebaseService');
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
