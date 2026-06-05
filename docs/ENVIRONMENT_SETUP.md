# Environment Setup

How to set up a development environment for the Housepital Patient App from scratch.

**Last updated:** 2026-03-22

---

## Prerequisites

### Required Software

| Tool              | Version      | Install Command / URL                                    |
|-------------------|-------------|----------------------------------------------------------|
| Flutter SDK       | 3.x (Dart ^3.11.0) | https://docs.flutter.dev/get-started/install        |
| Node.js           | 20.x LTS    | `brew install node@20` or https://nodejs.org             |
| npm               | 10.x+       | Bundled with Node.js                                     |
| Firebase CLI      | 13.x+       | `npm install -g firebase-tools`                          |
| gcloud CLI        | latest       | https://cloud.google.com/sdk/docs/install                |
| MySQL Client      | 8.0+        | `brew install mysql-client` (macOS)                      |
| Cloud SQL Proxy   | v2           | `brew install cloud-sql-proxy` or download from Google   |
| Git               | 2.x+        | `brew install git`                                       |
| VS Code / Android Studio | latest | IDE with Flutter/Dart plugins                       |

### Verify Installation

```bash
flutter --version    # Should show Flutter 3.x, Dart 3.11+
node --version       # Should show v20.x
npm --version        # Should show 10.x
firebase --version   # Should show 13.x+
gcloud --version     # Should show latest
mysql --version      # Should show 8.x
git --version        # Should show 2.x
```

### Flutter Doctor

```bash
flutter doctor -v
```

Ensure all checkmarks pass for your target platforms (Android, iOS, Web).

---

## 1. Clone Repositories

```bash
# Patient App (Flutter frontend)
git clone <patient-app-repo-url> ~/housepital_patient_app

# Backend (Firebase Cloud Functions)
git clone <backend-repo-url> ~/housepital-backend
```

**Important:** Always use feature branches for development. Never push directly to main.

---

## 2. Install Dependencies

### Flutter App

```bash
cd ~/housepital_patient_app
flutter pub get
```

### Backend

```bash
cd ~/housepital-backend/functions
npm install
```

---

## 3. Firebase Setup

### 3.1 Login to Firebase

```bash
firebase login
```

### 3.2 Select Project

```bash
cd ~/housepital-backend
firebase use housepital-patient
```

### 3.3 Generate Firebase Config (if needed)

If `lib/config/firebase_options.dart` is missing or needs regeneration:

```bash
cd ~/housepital_patient_app

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (select housepital-patient project)
flutterfire configure --project=housepital-patient
```

This generates/updates `firebase_options.dart` and platform-specific config files.

---

## 4. Firebase Emulator Setup (Local Development)

The Firebase Emulator Suite lets you run Firebase services locally without hitting production.

### 4.1 Install Emulators

```bash
firebase init emulators
# Select: Authentication, Functions, Firestore, Hosting
# Accept default ports or customize
```

### 4.2 Start Emulators

```bash
cd ~/housepital-backend

# Build TypeScript first
cd functions && npm run build && cd ..

# Start all emulators
firebase emulators:start

# Or start with a specific set
firebase emulators:start --only functions,firestore,auth
```

Default emulator ports:
| Service      | Port  | UI URL                        |
|-------------|-------|-------------------------------|
| Auth        | 9099  | http://localhost:4000/auth    |
| Functions   | 5001  | http://localhost:4000/functions|
| Firestore   | 8080  | http://localhost:4000/firestore|
| Hosting     | 5000  | http://localhost:5000          |
| Emulator UI | 4000  | http://localhost:4000          |

### 4.3 Point Flutter App to Emulators

For local development, update the API base URL in `lib/config/constants.dart`:

```dart
// Local development (emulator)
static const String apiBaseUrl = 'http://localhost:5001/housepital-patient/asia-south1/api';

// Production
// static const String apiBaseUrl = 'https://api.housepital.in/v1';
```

For Firebase Auth emulator, add to your Flutter app initialization (before `runApp`):

```dart
if (kDebugMode) {
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

---

## 5. Local MySQL Setup (Alternative to Cloud SQL)

If you want a fully local database instead of connecting to Cloud SQL:

### 5.1 Install MySQL Locally

```bash
# macOS
brew install mysql
brew services start mysql

# Set root password
mysql_secure_installation
```

### 5.2 Create Database and User

```bash
mysql -u root -p

CREATE DATABASE housepital;
CREATE USER 'housepital'@'localhost' IDENTIFIED BY 'localdev123';
GRANT ALL PRIVILEGES ON housepital.* TO 'housepital'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 5.3 Run Schema and Seeds

```bash
cd ~/housepital-backend

mysql -u housepital -p housepital < sql/001_initial_schema.sql
mysql -u housepital -p housepital < sql/002_seed_services.sql
mysql -u housepital -p housepital < sql/003_seed_equipment.sql
mysql -u housepital -p housepital < sql/004_seed_coupons.sql
```

### 5.4 Set Environment Variables for Backend

Create a `.env` file in `~/housepital-backend/functions/`:

```bash
# .env (DO NOT COMMIT — add to .gitignore)
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=housepital
DB_PASSWORD=localdev123
DB_NAME=housepital

RAZORPAY_KEY_ID=rzp_test_XXXXXXXXXX
RAZORPAY_KEY_SECRET=YOUR_TEST_SECRET
RAZORPAY_WEBHOOK_SECRET=YOUR_WEBHOOK_SECRET
```

Or for Cloud SQL via proxy:

```bash
# Start Cloud SQL Auth Proxy in a separate terminal
cloud-sql-proxy housepital-patient:asia-south1:housepital-db --port=3306

# Then set DB_HOST=127.0.0.1 in .env
```

---

## 6. Run the App Locally

### 6.1 Start Backend

```bash
# Terminal 1: Start Firebase emulators (or just functions)
cd ~/housepital-backend
cd functions && npm run build && cd ..
firebase emulators:start --only functions
```

### 6.2 Start Flutter App

```bash
# Terminal 2: Run Flutter app
cd ~/housepital_patient_app

# Web (recommended for rapid development)
flutter run -d chrome

# Android emulator
flutter run -d emulator-5554

# iOS simulator
flutter run -d "iPhone 16"

# List available devices
flutter devices
```

### 6.3 Hot Reload

- Press `r` in the terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

## 7. Run Tests

### Flutter Tests

```bash
cd ~/housepital_patient_app

# Run all tests
flutter test

# Run specific test file
flutter test test/utils/pricing_test.dart

# Run only business logic tests
flutter test test/utils/ test/models/booking_state_machine_test.dart test/providers/cart_provider_test.dart

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Backend Tests

```bash
cd ~/housepital-backend/functions

# Run backend tests
npm test
```

---

## 8. Project Structure Quick Reference

```
~/housepital_patient_app/          # Flutter frontend
  lib/                             # Application code
  test/                            # Unit and widget tests
  assets/                          # Images, JSON data, i18n
  docs/                            # All documentation
  pubspec.yaml                     # Flutter dependencies

~/housepital-backend/              # Backend
  functions/                       # Cloud Functions source
    src/                           # TypeScript source
      config/                      # Firebase, CloudSQL, Razorpay config
      middleware/                   # Auth, error handling
      routes/                      # API route handlers (16 files)
    package.json                   # Node.js dependencies
    tsconfig.json                  # TypeScript config
  sql/                             # MySQL migration and seed files
  firebase.json                    # Firebase project config
  firestore.rules                  # Firestore security rules
  firestore.indexes.json           # Firestore indexes
  .firebaserc                      # Firebase project alias
```

---

## 9. Common Development Workflows

### Adding a New Screen

1. Create screen file in appropriate `lib/screens/<section>/` directory
2. Add route to `onGenerateRoute` in `lib/main.dart`
3. Update `docs/SCREEN_MAP.md` with the new screen
4. Write a basic widget test in `test/screens/`

### Adding a New API Endpoint

1. Create or update route file in `functions/src/routes/`
2. Register route in `functions/src/index.ts`
3. Add corresponding method in `lib/services/api_service.dart`
4. Update `docs/API_REFERENCE.md`
5. Build and redeploy: `cd functions && npm run build && cd .. && firebase deploy --only functions`

### Running a Database Migration

1. Create new SQL file: `sql/005_description.sql`
2. Test on local MySQL first
3. Apply to staging, then production
4. **Update `docs/DATABASE_SCHEMA.md` immediately** (mandatory)

---

## 10. Useful Commands Cheat Sheet

```bash
# Flutter
flutter pub get                    # Install dependencies
flutter pub upgrade                # Upgrade dependencies
flutter clean                      # Clean build artifacts
flutter analyze                    # Static analysis
flutter test                       # Run all tests
flutter run -d chrome              # Run on web
flutter build apk --release        # Build Android APK
flutter build appbundle --release   # Build Android App Bundle
flutter build ipa --release         # Build iOS IPA
flutter build web --release         # Build web

# Firebase
firebase login                     # Login
firebase use housepital-patient    # Select project
firebase deploy                    # Deploy all
firebase deploy --only functions   # Deploy functions only
firebase deploy --only firestore:rules  # Deploy Firestore rules
firebase emulators:start           # Start emulators
firebase functions:log             # View function logs

# Backend
cd functions && npm run build      # Build TypeScript
cd functions && npm test           # Run tests
cd functions && npm run lint       # Lint TypeScript

# MySQL
mysql -h HOST -u USER -p DB_NAME  # Connect to MySQL
mysqldump -h HOST -u USER -p DB > backup.sql  # Backup
```

---

**Update rule:** Update this guide when prerequisites change, new tools are required, or setup steps change.
