# Deployment Guide

Step-by-step guide to deploy the full Housepital Patient App stack.

**Last updated:** 2026-05-28 (audit batch 4 — added Firebase Console hardening checklist)

---

## Overview

```
Deployment Architecture:
  Flutter App  -->  Firebase Cloud Functions (Express.js)  -->  Cloud SQL MySQL
                    |                                           |
                    +-> Cloud Firestore (real-time)             |
                    +-> Firebase Auth (phone OTP)               |
                    +-> Razorpay API (payments)                 |
                    +-> FCM (push notifications)                |

Region: asia-south1 (Mumbai)
Firebase Project: housepital-patient
```

---

## 1. Firebase Project Setup

The Firebase project `housepital-patient` is already created. Here is what was configured:

### 1.1 Firebase Console Setup (already done)

1. Created Firebase project: `housepital-patient`
2. Enabled Firebase Authentication with Phone provider
3. Created Cloud Firestore database in `asia-south1`
4. Enabled Cloud Functions (Blaze plan required)
5. Registered Flutter apps (Android + iOS + Web)
6. Downloaded `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
7. Generated `firebase_options.dart` via `flutterfire configure`

### 1.2 Firestore Security Rules

Deploy the security rules:

```bash
cd /Users/ateeshayjain/housepital-backend
firebase deploy --only firestore:rules
```

Rules file: `firestore.rules` (5 collection rules + default deny)

### 1.3 Firestore Indexes

Deploy indexes:

```bash
cd /Users/ateeshayjain/housepital-backend
firebase deploy --only firestore:indexes
```

---

## 2. Cloud SQL MySQL Setup

### 2.1 Create Cloud SQL Instance

```bash
# Create MySQL 8.0 instance in asia-south1
gcloud sql instances create housepital-db \
  --database-version=MYSQL_8_0 \
  --tier=db-f1-micro \
  --region=asia-south1 \
  --storage-size=10GB \
  --storage-auto-increase

# Set root password
gcloud sql users set-password root \
  --host="%" \
  --instance=housepital-db \
  --password="YOUR_SECURE_PASSWORD"

# Create application user
gcloud sql users create housepital \
  --host="%" \
  --instance=housepital-db \
  --password="YOUR_APP_PASSWORD"

# Create database
gcloud sql databases create housepital \
  --instance=housepital-db
```

### 2.2 Connect and Run Migrations

```bash
# Option A: Cloud SQL Auth Proxy (recommended for local)
cloud-sql-proxy housepital-patient:asia-south1:housepital-db --port=3306

# In another terminal, connect and run schema:
mysql -h 127.0.0.1 -u housepital -p housepital < sql/001_initial_schema.sql
```

### 2.3 Seed Data

```bash
mysql -h 127.0.0.1 -u housepital -p housepital < sql/002_seed_services.sql
mysql -h 127.0.0.1 -u housepital -p housepital < sql/003_seed_equipment.sql
mysql -h 127.0.0.1 -u housepital -p housepital < sql/004_seed_coupons.sql
```

### 2.4 Enable Private IP for Cloud Functions

For production, use private IP so Cloud Functions connect directly:

```bash
# Enable private services access
gcloud sql instances patch housepital-db \
  --network=default \
  --no-assign-ip
```

Or use the Unix socket path in `cloudSql.ts`:
```
socketPath: /cloudsql/housepital-patient:asia-south1:housepital-db
```

---

## 3. Cloud Functions Deployment

### 3.1 Set Environment Variables

```bash
cd /Users/ateeshayjain/housepital-backend

# Database connection
firebase functions:config:set \
  db.host="CLOUD_SQL_PRIVATE_IP_OR_SOCKET_PATH" \
  db.user="housepital" \
  db.password="YOUR_APP_PASSWORD" \
  db.name="housepital"

# Razorpay
firebase functions:config:set \
  razorpay.key_id="rzp_live_XXXXXXXXXX" \
  razorpay.key_secret="YOUR_RAZORPAY_SECRET" \
  razorpay.webhook_secret="YOUR_WEBHOOK_SECRET"
```

Note: Firebase Functions v2 uses `defineSecret()` or `.env` files. If using v1 style, use `functions.config()`. The current codebase reads from `process.env.*`.

### 3.2 Install Dependencies and Build

```bash
cd /Users/ateeshayjain/housepital-backend/functions
npm install
npm run build
```

### 3.3 Deploy

```bash
cd /Users/ateeshayjain/housepital-backend

# Deploy functions only
firebase deploy --only functions

# Deploy everything (functions + firestore rules + indexes)
firebase deploy
```

### 3.4 Verify Deployment

```bash
# Health check
curl https://asia-south1-housepital-patient.cloudfunctions.net/api/health

# Expected response:
# {"status":"ok","version":"1.0.0","timestamp":"2026-03-22T..."}
```

---

## 4. Flutter App Build

### 4.1 Web Build

```bash
cd /Users/ateeshayjain/housepital_patient_app

# Build for web
flutter build web --release

# Output: build/web/
# Deploy to Firebase Hosting or any static host
```

### 4.2 Android Build

```bash
cd /Users/ateeshayjain/housepital_patient_app

# Build APK (for testing)
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 4.1.1 Android Permissions for Medication Reminders

The `flutter_local_notifications` package requires the following Android permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Medication reminder notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<!-- Exact alarm scheduling for medication reminders -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<!-- Receive boot completed to reschedule notifications -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

For Android 13+ (API 33+), the app requests `POST_NOTIFICATIONS` permission at runtime when the user first adds a medication.

### 4.1.2 New Dependencies to Install

These dependencies were added since the last deployment guide update:

```yaml
# pubspec.yaml additions
flutter_local_notifications: ^18.0.0   # Medication reminders
timezone: ^0.9.4                       # Timezone-aware notification scheduling
```

Run `flutter pub get` after pulling latest code.

Before building for release:
1. Update `android/app/build.gradle` with your signing config
2. Create a keystore: `keytool -genkey -v -keystore housepital.jks -keyalg RSA -keysize 2048 -validity 10000 -alias housepital`
3. Create `android/key.properties` with keystore path/password
4. Update `pubspec.yaml` version number

### 4.3 iOS Build

```bash
cd /Users/ateeshayjain/housepital_patient_app

# Build IPA (for App Store)
flutter build ipa --release

# Output: build/ios/ipa/housepital_patient.ipa
```

Before building for release:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Set your Team and Bundle Identifier
3. Configure signing certificates and provisioning profiles
4. Add `GoogleService-Info.plist` to the Runner target

---

## 5. Environment Variables Reference

### Backend (Cloud Functions)

| Variable              | Description                              | Required | Default       |
|-----------------------|------------------------------------------|----------|---------------|
| DB_HOST               | Cloud SQL MySQL host or socket path      | YES      | 127.0.0.1     |
| DB_PORT               | MySQL port                               | NO       | 3306          |
| DB_USER               | MySQL username                           | YES      | housepital    |
| DB_PASSWORD            | MySQL password                          | YES      | (none)        |
| DB_NAME               | MySQL database name                      | YES      | housepital    |
| CLOUD_SQL_CONNECTION_NAME | Cloud SQL instance connection name    | For prod | (none)        |
| RAZORPAY_KEY_ID       | Razorpay API key                         | YES      | (test key)    |
| RAZORPAY_KEY_SECRET   | Razorpay secret key                      | YES      | (none)        |
| RAZORPAY_WEBHOOK_SECRET | Razorpay webhook signature secret      | YES      | (none)        |

### Flutter App

| Variable              | Description                              | Location           |
|-----------------------|------------------------------------------|--------------------|
| API Base URL          | Backend Cloud Function URL               | lib/config/constants.dart |
| Razorpay Key ID       | Razorpay publishable key                 | lib/config/constants.dart |
| Firebase Config       | Firebase project settings                | lib/config/firebase_options.dart |

**Important:** Before production, move Razorpay key to `--dart-define` or runtime config:
```bash
flutter build apk --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXXXXX
```

---

## 6. DNS / Domain Setup

### API Domain

Current API base URL in `constants.dart`: `https://api.housepital.in/v1`

To set up custom domain:
1. In Firebase Console > Hosting > Custom Domain, add `api.housepital.in`
2. Add the required DNS records (A record or CNAME) at your registrar
3. Firebase will provision SSL automatically
4. Update `firebase.json` to rewrite `/v1/*` to the Cloud Function

Alternative: Use Cloud Functions custom domain directly via Google Cloud Console.

### App Distribution

- **Android:** Google Play Console > upload AAB > internal/closed/open testing tracks
- **iOS:** App Store Connect > upload IPA via Xcode or Transporter > TestFlight/App Store
- **Web:** Deploy `build/web/` to Firebase Hosting: `firebase deploy --only hosting`

---

## 7. Razorpay Webhook Setup

1. Log into Razorpay Dashboard > Settings > Webhooks
2. Add webhook URL: `https://asia-south1-housepital-patient.cloudfunctions.net/api/payments/webhook`
3. Select events: `payment.captured`, `payment.failed`, `refund.processed`
4. Set webhook secret and store it as `RAZORPAY_WEBHOOK_SECRET` in Cloud Functions env
5. The backend verifies the `x-razorpay-signature` header using HMAC SHA256

---

## 7a. Firebase Console hardening checklist (pre-launch)

The Flutter app embeds Firebase API keys in `lib/config/firebase_options.dart`
and `android/app/google-services.json`. These keys are **safe by design only
if the corresponding console-side restrictions are configured.** Without
restrictions, anyone who decompiles the app can use the keys to abuse your
Firebase quota or hit your Cloud Functions from arbitrary origins.

Run through this list before flipping the app to production:

### 1. Restrict each Firebase / Google Cloud API key

Open https://console.cloud.google.com/apis/credentials?project=housepital-patient
and for each key listed below, set restrictions:

| Key value (truncated)               | Platform | Restriction type | Restriction details |
|-------------------------------------|----------|------------------|---------------------|
| `AIzaSyCmH3bfQCN4q6rjjJROf6LQzBG-8i_nTJg` | (web)    | HTTP referrer    | `*.housepital.in/*`, `housepital.in/*`, `localhost/*` (dev only) |
| `AIzaSyBKK2NxRuvZsIGrBdpugnePy9zA7g13TLc` | (Android)| Android app      | Package `in.housepital.patient` + release signing SHA1 (`keytool -list -v -keystore housepital.jks`) |
| (iOS key in GoogleService-Info.plist) | (iOS)    | iOS app          | Bundle ID `in.housepital.patient` |

For each key, also restrict the API surface:

- Firebase Cloud Messaging API
- Firebase Installations API
- Cloud Firestore API
- Identity Toolkit API (Auth)
- Firebase Realtime Database (only if used)

Do NOT leave keys with "No restrictions" or "All APIs".

### 2. Enable Firebase App Check

App Check verifies that requests to Firestore / Cloud Functions / Storage come
from your real apps, not from a script. Without App Check, a determined
attacker who decompiles the app can call backend services directly using the
embedded API keys, bypassing your firestore.rules.

```bash
# Enable in console:
# https://console.firebase.google.com/project/housepital-patient/appcheck

# Providers per platform:
#   Android — Play Integrity (debug: SafetyNet)
#   iOS     — App Attest (debug: DeviceCheck)
#   Web     — reCAPTCHA Enterprise

# In the Flutter app, add firebase_app_check and call:
#   await FirebaseAppCheck.instance.activate(
#     androidProvider: AndroidProvider.playIntegrity,
#     appleProvider: AppleProvider.appAttest,
#     webProvider: ReCaptchaEnterpriseProvider('SITE_KEY'),
#   );
# (See Agent J's wiring task — infra agent only documents the requirement.)
```

After enabling, run for at least 7 days in "Monitor" mode to confirm no
legitimate clients are being blocked, THEN switch to "Enforce".

### 3. Deploy the hardened firestore.rules

The repo's `firestore.rules` file is the source of truth. After every change:

```bash
# From this repo (or from housepital-backend if firebase.json lives there):
firebase deploy --only firestore:rules --project housepital-patient

# Verify the deployed rules match the file:
firebase firestore:rules get --project housepital-patient
```

**Audit trail:** every deploy is logged at
https://console.firebase.google.com/project/housepital-patient/firestore/rules
(history tab). Check the timestamp matches the git commit SHA.

The current rules use default-deny + per-collection authorisation. See the
extensive comment block at the top of `firestore.rules` for the audit trail
and the list of collections covered.

### 4. Verify deploys are logged in audit

Cloud Audit Logs should capture every `firebase deploy` against Firestore,
Cloud Functions, and Hosting. Confirm at:

https://console.cloud.google.com/logs/query?project=housepital-patient

Filter: `resource.type="firestore.googleapis.com/Database"` and
`protoPayload.methodName=~"UpdateRuleset"`. If logs are missing, enable
Data Access audit logs for the Firebase project.

### 5. Configure Crashlytics + Performance dashboard alerts

`firebase_crashlytics: 4.3.10` and `firebase_performance: 0.10.1+10` are added
to `pubspec.yaml` (initialization is wired in `lib/main.dart` by Agent J in
this same batch). Once builds are flowing crashes:

1. https://console.firebase.google.com/project/housepital-patient/crashlytics
2. Velocity alerts: trigger when a fatal issue affects > 0.1% of users in 1h
3. New issue alerts: email + Slack webhook (wire via Firebase → Integrations)
4. Performance: alert on app start > 5s p95, HTTP > 3s p95

Verify Crashlytics dSYM upload is working on iOS (Run Script phase in Xcode).
Without dSYMs, all iOS crash reports are obfuscated and useless.

### 6. Razorpay key rotation post-launch

If a production Razorpay key is ever committed by mistake (CI lint should
catch this), rotate immediately at https://dashboard.razorpay.com and
re-deploy with `--dart-define=RAZORPAY_KEY=rzp_live_...`.

---

## 8. Post-Deployment Checklist

- [ ] Health check endpoint returns 200
- [ ] Firebase Auth phone OTP works (test with a real phone number)
- [ ] Cloud SQL connection succeeds (check Cloud Functions logs)
- [ ] **Firestore security rules deployed AND verified in console** (Section 7a step 3)
- [ ] **Firebase API key restrictions configured for all platforms** (Section 7a step 1)
- [ ] **App Check enabled in Monitor mode (7 days), then Enforce** (Section 7a step 2)
- [ ] **Crashlytics + Performance dashboard alerts configured** (Section 7a step 5)
- [ ] Razorpay test payment completes successfully
- [ ] Push notification received on a test device
- [ ] All seed data loaded (services, equipment, coupons)
- [ ] API base URL in Flutter app points to production Cloud Function
- [ ] Razorpay key in Flutter app is production key (not test)
- [ ] Version number bumped in pubspec.yaml

---

## 9. Rollback Procedure

### Cloud Functions Rollback

```bash
# List previous deployments
firebase functions:log

# Rollback to previous version (redeploy from git)
git checkout <previous-commit>
cd functions && npm install && npm run build
cd .. && firebase deploy --only functions
```

### Database Rollback

- MySQL does not have built-in migration rollback in this setup
- Keep backup before any migration: `mysqldump -h HOST -u USER -p housepital > backup_YYYYMMDD.sql`
- Apply rollback SQL manually if needed
- **Always test migrations on staging first**

### Flutter App Rollback

- Android: Use Google Play Console staged rollout, halt rollout, or rollback to previous version
- iOS: App Store Connect does not support rollback -- submit a new version with the fix
- Web: Redeploy previous build to Firebase Hosting

---

**Update rule:** Update this guide whenever deployment steps, environment variables, or infrastructure changes.
