import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for Housepital Patient App.
/// Project: housepital-patient (536139461614)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmH3bfQCN4q6rjjJROf6LQzBG-8i_nTJg',
    appId: '1:536139461614:web:743273ef351e82a52754ff',
    messagingSenderId: '536139461614',
    projectId: 'housepital-patient',
    authDomain: 'housepital-patient.firebaseapp.com',
    storageBucket: 'housepital-patient.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBKK2NxRuvZsIGrBdpugnePy9zA7g13TLc',
    appId: '1:536139461614:android:26f4013abc21cd1c2754ff',
    messagingSenderId: '536139461614',
    projectId: 'housepital-patient',
    storageBucket: 'housepital-patient.firebasestorage.app',
  );

  // iOS app registered in Firebase Console 2026-06-02 (bundle id
  // com.housepital.housepitalPatient). Values mirror
  // ios/Runner/GoogleService-Info.plist — keep the two in sync if the app
  // is re-registered or the API key is rotated.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCMPK4nMVjcgRm5pJx5uNpjyuYO19cII_g',
    appId: '1:536139461614:ios:c149e94748af207d2754ff',
    messagingSenderId: '536139461614',
    projectId: 'housepital-patient',
    storageBucket: 'housepital-patient.firebasestorage.app',
    iosBundleId: 'com.housepital.housepitalPatient',
  );
}
