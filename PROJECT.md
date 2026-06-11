# Housepital Patient App

**Status:** Active development — pre-launch
**Stage:** Post-feature build (Jun 2026) — Home Layout B, Care Guides, AI Assistant (action-taking) + Cloud Function shipped; all audit batches + tri-audit fixes complete
**Owner:** Ateeshay Jain ([Ateeshay.jain@gmail.com](mailto:Ateeshay.jain@gmail.com))
**Last reviewed:** 2026-06-08

> Created in audit batch 3 per the project Documentation Audit Report template — this is the "meta layer" doc that maps you to everything else. Skim it once; bookmark the Quick Links.

---

## Quick Links

| Resource | URL |
|---|---|
| GitHub repo | <https://github.com/ateeshayjain/housepital_patient_app> |
| Open PRs | <https://github.com/ateeshayjain/housepital_patient_app/pulls> |
| CI runs | <https://github.com/ateeshayjain/housepital_patient_app/actions> |
| Firebase console | <https://console.firebase.google.com/project/housepital-patient> |
| Razorpay dashboard | <https://dashboard.razorpay.com> |
| Backend API (dev) | <https://api.housepital.in/v1> |
| Brand Guidelines | _TODO: add link to Drive/Notion_ |
| Master pricing Excel | _TODO: add link to Drive (single source of truth for service prices)_ |

---

## Tech Stack

Flutter 3.41+ / Dart, Provider state management, Firebase Auth (phone OTP) + FCM, REST API on Firebase Cloud Functions (Express + TS), Cloud SQL MySQL + Firestore (chat), Razorpay payments, fl_chart for vitals, Archivo + Noto Sans Devanagari fonts, brand orange `#F39314`.

Full table: see [README.md § Tech Stack](./README.md#-tech-stack).

---

## Setup (5-minute version)

```bash
git clone git@github.com:ateeshayjain/housepital_patient_app.git
cd housepital_patient_app
flutter pub get

# Drop these in place from your secure share:
#   android/app/google-services.json      (Firebase config, restricted)
#   ios/Runner/GoogleService-Info.plist   (Firebase config, restricted)

# Run with the Razorpay test key:
flutter run --dart-define=RAZORPAY_KEY=rzp_test_XXXXXXXXXX

# For production builds, swap to the live key (see KNOWN_ISSUES BUG-01):
flutter build apk --release --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXXXXX
```

Full guide: [docs/ENVIRONMENT_SETUP.md](./docs/ENVIRONMENT_SETUP.md)
Troubleshooting: [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)

---

## Secrets

| Secret | Where it lives | How to rotate |
|---|---|---|
| Razorpay **test** key | `.env.example` placeholder | not applicable |
| Razorpay **live** key | passed via `--dart-define=RAZORPAY_KEY=…` at build time | Razorpay dashboard → new key → update CI build secret |
| Firebase config (API key, app ID) | `google-services.json` / `GoogleService-Info.plist` — gitignored as of 2026-05-28 | Firebase Console → re-download → distribute via secure channel |
| Razorpay **server secret**, FCM admin SDK, MySQL creds | **Backend repo** (separate), not here | (see backend repo) |
| **ANTHROPIC_API_KEY** (AI assistant) | Firebase **secret** on the `assistant` Cloud Function (`firebase functions:secrets:set ANTHROPIC_API_KEY`) — never in the app binary | Anthropic console → new key → re-set secret → `firebase deploy --only functions`. See `functions/README.md` |
| `ASSISTANT_API_URL` (assistant endpoint) | build flag `--dart-define=ASSISTANT_API_URL=…` (the deployed function URL); optional — omit for offline stub | n/a (URL, not a secret) |
| Where credentials are vaulted | _TODO: confirm + link (1Password? Doppler?)_ | |

**Production build checklist:** Razorpay key must be live (see KNOWN_ISSUES BUG-01). Verify Firebase API key restrictions are enabled in the console (HTTP referrer for web, package + SHA1 for Android).

---

## Documentation Map

Skim once. Bookmark when you'll need it.

| For | Read |
|---|---|
| Onboarding a new developer | [README.md](./README.md) → [docs/ENVIRONMENT_SETUP.md](./docs/ENVIRONMENT_SETUP.md) |
| Understanding the system | [ARCHITECTURE.md](./ARCHITECTURE.md) (or [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — currently duplicated, see TODO below) |
| Integrating with backend | [docs/API_REFERENCE.md](./docs/API_REFERENCE.md), [docs/DATABASE_SCHEMA.md](./docs/DATABASE_SCHEMA.md) |
| Shipping to prod | [docs/DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md) |
| Debugging | [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md), [docs/KNOWN_ISSUES.md](./docs/KNOWN_ISSUES.md) |
| Product / pricing rules | [docs/BUSINESS_RULES.md](./docs/BUSINESS_RULES.md) |
| Test coverage map | [docs/TEST_MAP.md](./docs/TEST_MAP.md) (caveat: currently inconsistent with README's count) |
| Contributing | [CONTRIBUTING.md](./CONTRIBUTING.md) |

**Doc TODOs (audit batch 3 follow-up):**
- ARCHITECTURE.md is duplicated at root and `docs/` — keep one.
- CHANGELOG.md last updated 2026-03-25 (stale by 2 months — needs batches 1, 2, 3 catch-up).
- TEST_MAP.md claims 1090 tests, README claims 220 — reconcile.

---

## Roadmap (short)

1. **In flight**: audit batches 1 → 3 (PRs #10, #11, #12). When merged, app passes 7-dimension audit + Apple Design Framework + Testing & Code Quality Checklist.
2. **Next**: wire real REST API (replace AppProvider mock data) — see [README § Remaining Steps](./README.md).
3. **Pre-launch**:
   - Firebase Crashlytics + Performance Monitoring (audit F flagged this — currently no production observability).
   - `firestore.rules` audit + redeploy (audit F flagged the source-file rule expired 2026-04-21).
   - Razorpay webhook idempotency in backend repo (KNOWN_ISSUES BUG-02).
   - FCM token registration + notification handlers wired to live backend.
   - Coverage gate in CI (audit F flagged this).
4. **Launch**: App Store + Play Store builds; restricted Firebase API keys in console verified.

---

## Conventions

- **Branches:** `fix/<topic>` or `feat/<topic>` — never push directly to `main`.
- **PRs:** all must pass CI (`flutter analyze --no-fatal-warnings --no-fatal-infos` + `flutter test` + `flutter build web --release`).
- **Commits:** Conventional — `fix:`, `feat:`, `docs:`, `chore:`, `test:` prefix.
- **Business rule (durable, INVIOLABLE):** manpower service prices (caretaker, nursing, attendant — and legacy japa/nanny) are **NEVER shown anywhere in the app**. Customers reject without talking when they see a price. Booking is fully in-app but quote-pending: no ₹/GST anywhere in the wizard, copy "Price confirmed on call before payment" (`catalog_seeds.dart` strips prices; `orders_provider.dart` sets `quoteStatus: 'pending'`); never render ₹0; quote invoices export PRO FORMA without amounts. *(An earlier note here claiming prices were re-shown on 2026-03-24 was a documentation error — code has hidden them since the M-1 fix.)* Do not re-introduce price display without explicit owner sign-off.
- **Separate business (durable):** Dai Maa (mother & baby) is a **different company and app** — not a Housepital offering. In-app presence is ONE cross-promo banner on Home linking out; Japa/Nanny are not sold in this app. `daimaa_theme.dart` exists only for the banner's branding.

Full conventions: [CONTRIBUTING.md](./CONTRIBUTING.md).
