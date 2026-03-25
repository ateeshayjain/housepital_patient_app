# Troubleshooting Guide

Common issues and their solutions for Housepital Patient App development.

**Last updated:** 2026-03-24

---

## Flutter Build Failures

### Problem: `flutter pub get` fails with dependency conflicts

**Cause:** Version constraints in `pubspec.yaml` conflict with each other or with Flutter SDK version.

**Solution:**
```bash
# Clean and re-fetch
flutter clean
flutter pub cache repair
flutter pub get

# If still failing, check your Flutter SDK version
flutter --version
# Required: Dart SDK ^3.11.0 (Flutter 3.x)

# Upgrade Flutter if needed
flutter upgrade
```

---

### Problem: Build fails with "Dart SDK version mismatch"

**Cause:** Local Dart SDK version does not satisfy the `^3.11.0` constraint in `pubspec.yaml`.

**Solution:**
```bash
flutter upgrade
flutter pub get
```

---

### Problem: Android build fails with Gradle errors

**Cause:** Gradle version mismatch, missing Android SDK, or JDK version issues.

**Solution:**
```bash
# Ensure Android SDK is installed
flutter doctor -v

# Clean Android build
cd android && ./gradlew clean && cd ..
flutter clean
flutter pub get
flutter build apk

# If JDK issues, ensure Java 17 is installed
java -version
# If not: brew install openjdk@17
```

---

### Problem: iOS build fails with CocoaPods errors

**Cause:** Pod dependencies out of sync or missing.

**Solution:**
```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter build ios
```

---

### Problem: Web build fails or page is blank

**Cause:** Often a JavaScript compilation issue or missing assets.

**Solution:**
```bash
flutter clean
flutter pub get
flutter build web --release

# If page is blank, check browser console for errors
# Common: Firebase config missing or service worker issues
```

---

## Firebase Auth Issues

### Problem: Phone OTP not received / Firebase Auth returns error

**Cause:** Firebase Auth phone provider not configured, or quota exceeded, or test phone numbers not set up.

**Solution:**
1. In Firebase Console > Authentication > Sign-in Providers, ensure Phone is enabled
2. For development, add test phone numbers:
   - Firebase Console > Authentication > Phone > Phone numbers for testing
   - Add: `+919999900001` with code `123456` (or your test numbers)
3. Check Firebase Auth quotas (free tier: 10k verifications/month)
4. On Android: Ensure SHA-1 and SHA-256 fingerprints are registered in Firebase Console

```bash
# Get debug SHA-1 for Android
cd android && ./gradlew signingReport
```

---

### Problem: Firebase Auth token expired / 401 Unauthorized from backend

**Cause:** Firebase ID tokens expire after 1 hour. The app needs to refresh them.

**Solution:**
The `AuthProvider` should call `user.getIdToken(true)` to force-refresh the token before API calls. Check that `ApiService.setAuthToken()` is called with the refreshed token.

---

## Cloud Functions Deployment Errors

### Problem: `firebase deploy --only functions` fails with build errors

**Cause:** TypeScript compilation errors in the functions source.

**Solution:**
```bash
cd ~/housepital-backend/functions

# Check for TypeScript errors
npm run build

# Fix any errors shown in the output, then redeploy
cd ..
firebase deploy --only functions
```

---

### Problem: Cloud Functions deploy succeeds but returns 500 errors

**Cause:** Usually a missing environment variable (DB connection, Razorpay keys).

**Solution:**
```bash
# Check function logs
firebase functions:log --only api

# Verify environment variables are set
firebase functions:config:get

# Common missing vars: DB_HOST, DB_PASSWORD, RAZORPAY_KEY_SECRET
```

---

### Problem: Cloud Functions cold start timeout

**Cause:** Cloud SQL connection takes too long during cold start. Default timeout is 60 seconds.

**Solution:**
1. Increase function timeout in `firebase.json` or function definition
2. Use connection pooling (already configured in `cloudSql.ts` with `pool.min: 0, max: 10`)
3. Set minimum instances to 1 to avoid cold starts (costs more):
   ```
   firebase functions:config:set min_instances=1
   ```

---

## MySQL Connection Issues

### Problem: "Connection refused" when connecting to Cloud SQL

**Cause:** Cloud SQL Auth Proxy not running, or wrong host/port.

**Solution:**
```bash
# Start Cloud SQL Auth Proxy
cloud-sql-proxy housepital-patient:asia-south1:housepital-db --port=3306

# Verify connection
mysql -h 127.0.0.1 -P 3306 -u housepital -p housepital -e "SELECT 1"
```

---

### Problem: "Access denied for user" when connecting to MySQL

**Cause:** Wrong username, password, or the user does not have grants on the database.

**Solution:**
```bash
# Connect as root and check grants
mysql -h HOST -u root -p
SHOW GRANTS FOR 'housepital'@'%';

# If missing, grant access
GRANT ALL PRIVILEGES ON housepital.* TO 'housepital'@'%';
FLUSH PRIVILEGES;
```

---

### Problem: "ER_CON_COUNT_ERROR: Too many connections"

**Cause:** Cloud Functions scaling creates too many DB connections. Each function instance opens a new connection pool.

**Solution:**
The connection pool in `cloudSql.ts` is configured with `max: 10` and `idleTimeoutMillis: 30000`. If still hitting limits:
1. Increase Cloud SQL max connections: `gcloud sql instances patch housepital-db --max-connections=200`
2. Reduce pool max to 5 in `cloudSql.ts`
3. Consider using Cloud SQL Connector for Node.js for better connection management

---

## Bottom Sheet Navigation Issues

### Problem: Bottom sheet navigation shows grey screen

**Cause:** Using a pop-then-push pattern from within a bottom sheet causes a grey screen because the bottom sheet's navigation context is destroyed during the pop.

**Solution:**
Do NOT pop the bottom sheet and then push a new route. Instead, use the **return-result-to-parent** pattern:

1. In the bottom sheet, call `Navigator.pop(context, result)` to return a result
2. In the parent screen, use the returned result to navigate:
```dart
final result = await showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  builder: (ctx) => MyBottomSheet(),
);
if (result != null) {
  Navigator.pushNamed(context, '/target-route', arguments: result);
}
```

This ensures the parent's navigation context (not the destroyed bottom sheet context) handles the push.

---

## Razorpay Issues

### Problem: Razorpay crashes on web platform

**Cause:** The `razorpay_flutter` plugin does not support web. Calling Razorpay methods on web causes an unrecoverable crash.

**Solution:**
Guard all Razorpay calls with `kIsWeb`:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (kIsWeb) {
  // Show web-specific payment flow or "not supported on web" message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Payments are not supported on web. Please use the mobile app.')),
  );
  return;
}
// Proceed with Razorpay checkout
```

---

### Problem: Razorpay checkout does not open / crashes on Android

**Cause:** Razorpay Flutter plugin requires additional Android configuration.

**Solution:**
1. Ensure `minSdkVersion` is at least 19 in `android/app/build.gradle`
2. Add internet permission in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
3. For release builds, add ProGuard rules for Razorpay

---

### Problem: Razorpay payment succeeds but backend verification fails

**Cause:** Razorpay secret key mismatch between test and live modes, or the order was created in test mode but verified in live mode.

**Solution:**
1. Ensure the same mode (test/live) is used for both key_id (Flutter) and key_secret (backend)
2. Check that the Razorpay key in `constants.dart` matches the key_secret on the backend
3. Verify the signature calculation in the webhook handler

---

### Problem: Razorpay test mode -- how to test payments

**Solution:**
Test credentials for Razorpay:
```
Test Key ID: rzp_test_XXXXXXXXXX (from constants.dart)
Test Cards:
  Success: 4111 1111 1111 1111 (any future expiry, any CVV)
  Failure: Use any card with amount ending in 34 (e.g., 10034 paise)
Test UPI:
  Success: success@razorpay
  Failure: failure@razorpay
Test Netbanking: All banks work in test mode
```

---

## Service Worker Caching Issues (Web)

### Problem: Web app shows old version after deploy / changes not reflected

**Cause:** Service worker caches the old version. This is the most common web deployment issue.

**Solution:**
```bash
# Hard refresh in browser
# Chrome: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (macOS)

# Clear service worker cache
# Chrome DevTools > Application > Service Workers > Unregister
# Chrome DevTools > Application > Cache Storage > Delete all

# Nuclear option: Clear all browsing data for the domain

# Prevent in future: Update the service worker version in web/index.html
# or disable service worker for development:
flutter build web --pwa-strategy=none
```

---

### Problem: Service worker caching old build -- changes not visible

**Cause:** `flutter_service_worker.js` aggressively caches all assets. Even after deploying a new build, users may see the old version indefinitely.

**Solution:**
1. Delete `flutter_service_worker.js` from the deployed build folder
2. Use a **different port** for local dev to avoid port-specific cache:
   ```bash
   flutter run -d chrome --web-port=9999
   ```
3. For production, build without service worker:
   ```bash
   flutter build web --pwa-strategy=none
   ```
4. If already deployed with service worker, users must manually clear cache or you can add a version check script to `web/index.html` that forces reload when version changes.

---

### Problem: Web app stuck on loading spinner after deploy

**Cause:** Service worker serving stale `main.dart.js` while `flutter_service_worker.js` has been updated.

**Solution:**
1. Add cache-busting to your web deploy:
   ```bash
   flutter build web --release
   # The build adds a hash to main.dart.js automatically
   ```
2. In `web/index.html`, ensure the service worker registration uses `updateViaCache: 'none'`
3. If deploying to Firebase Hosting, add cache headers:
   ```json
   // firebase.json
   {
     "hosting": {
       "headers": [{
         "source": "**/*.js",
         "headers": [{"key": "Cache-Control", "value": "no-cache"}]
       }]
     }
   }
   ```

---

## Port Conflicts

### Problem: Firebase Emulator fails to start -- port already in use

**Cause:** Another process is using the emulator port (4000, 5000, 5001, 8080, 9099).

**Solution:**
```bash
# Find what is using the port
lsof -i :5001

# Kill the process
kill -9 <PID>

# Or start emulators on different ports
firebase emulators:start --only functions --port 5002
```

---

### Problem: Flutter web dev server port conflict

**Cause:** Another Flutter instance or web server is using port 8080 or the random debug port.

**Solution:**
```bash
# Specify a different port
flutter run -d chrome --web-port=8888

# Kill all Flutter processes
flutter clean
killall dart
```

---

## Cart Issues

### Problem: Cart shows empty after adding items

**Cause:** The old CartProvider used a nested `EquipmentItem` object inside the cart item. When serializing to/from SharedPreferences, the deeply nested `EquipmentItem.fromJson()` would fail silently on missing or changed fields, causing all cart items to be silently dropped on deserialization. This resulted in the cart appearing empty after app restart even though items were added.

**Solution:**
The cart was rewritten (2026-03-25) with a flat `CartItem` model that contains only the fields needed for cart display and calculation (`equipmentId`, `name`, `brand`, `imageUrl`, `unitPrice`, `mrp`, `isRental`, `rentalMonths`, `quantity`). The flat model serializes cleanly to/from JSON without nested object dependencies. `CartItem.fromJson()` uses safe defaults for all fields, so corrupt or partial JSON entries are handled gracefully instead of throwing.

**Key files:**
- `lib/models/models.dart` -- `CartItem` class
- `lib/providers/cart_provider.dart` -- `CartProvider` with `List<CartItem>` and index-based operations

---

## Test Failures

### Problem: 3 pre-existing widget test failures in `my_care_widgets_test.dart`

**Cause:** These are pre-existing failures unrelated to recent changes. Likely caused by widget tree dependency on a provider that is not mocked in the test.

**Solution:** Triage separately. Wrap the widget under test in a `MultiProvider` with mocked providers, or update the widget to handle null provider gracefully.

---

### Problem: Tests pass locally but fail in CI

**Cause:** Different Flutter SDK version, missing assets, or timezone differences.

**Solution:**
```bash
# Pin Flutter version in CI
# Use the same SDK constraint as pubspec.yaml: ^3.11.0

# Ensure assets are available
flutter pub get

# Run with verbose output
flutter test --reporter expanded
```

---

### Problem: Widget tests fail with "No MediaQuery widget ancestor found"

**Cause:** Widget under test needs to be wrapped in `MaterialApp` or `MediaQuery`.

**Solution:**
```dart
testWidgets('my test', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MyWidget(),
      ),
    ),
  );
});
```

---

## Environment-Specific Issues

### Problem: API calls fail on Android emulator

**Cause:** Android emulator uses a different localhost address. `127.0.0.1` on the emulator refers to the emulator itself, not the host machine.

**Solution:**
Use `10.0.2.2` instead of `127.0.0.1` for Android emulator:
```dart
// In constants.dart for local dev with Android emulator
static const String apiBaseUrl = 'http://10.0.2.2:5001/housepital-patient/asia-south1/api';
```

---

### Problem: Firebase emulator data is lost on restart

**Cause:** By default, emulator data is not persisted.

**Solution:**
```bash
# Export data before stopping
firebase emulators:export ./emulator-data

# Start with imported data
firebase emulators:start --import=./emulator-data
```

---

### Problem: `flutter run` is slow / hot reload not working

**Cause:** Large project, too many packages, or debug mode overhead.

**Solution:**
```bash
# Use web for fastest iteration
flutter run -d chrome

# For mobile, ensure you're using debug mode (not profile/release)
flutter run

# Clear build cache if hot reload stops working
flutter clean
flutter pub get
flutter run
```

---

## Quick Diagnostic Commands

```bash
# Flutter health check
flutter doctor -v

# Firebase project status
firebase projects:list
firebase use

# Check backend logs
firebase functions:log --only api

# Check MySQL connectivity
mysql -h HOST -u USER -p -e "SHOW DATABASES"

# Check what's using a port
lsof -i :PORT_NUMBER

# Flutter test with coverage
flutter test --coverage
```

---

**Update rule:** Add new issues and solutions as they are encountered. Remove outdated entries when the root cause is permanently fixed.
