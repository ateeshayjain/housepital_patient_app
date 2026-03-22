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

  static FirebaseOptions get ios {
    throw UnsupportedError(
      'iOS Firebase not configured. Register the iOS app at '
      'https://console.firebase.google.com/project/housepital-patient/settings/general '
      'and update this file with the real config.',
    );
  }
}
