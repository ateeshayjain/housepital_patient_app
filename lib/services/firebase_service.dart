import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
}
