# Housepital Patient App

**Status:** Active development — pre-launch
**Stage:** Post-feature build (Jun 2026) — Home Layout B, Care Guides, AI Assistant (action-taking) + Cloud Function shipped; all audit batches + tri-audit fixes complete; **six field-feedback rounds (3–6) shipped**: fixed solid-orange nav bar, Calendar root tab, chrome contract, calm/dark/one-accent design pass, working offline assistant, 1-tap dose logging, manpower prices shown + direct booking, equipment catalog dedup/pricing + bundled product images
**Owner:** Ateeshay Jain ([Ateeshay.jain@gmail.com](mailto:Ateeshay.jain@gmail.com))
**Last reviewed:** 2026-06-15

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

**Doc TODOs:**
- ARCHITECTURE.md is duplicated at root and `docs/` — keep one.
- CHANGELOG.md / FEATURE_TRACKER / SCREEN_MAP / TEST_MAP refreshed 2026-06-15 for field rounds 3–6.
- TEST_MAP and README test counts reconciled (call-site + runtime expansion method documented in TEST_MAP).

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
- **Business rule (durable):** manpower service prices (caretaker, nurse, physio) **ARE shown and directly bookable** from the official Delhi NCR rate card (Caretaker ₹800–1,500/day, Nurse ₹1,600–3,000/day, plus monthly packages ₹18,000–₹90,000/mo; per-day `basePriceMin` in `catalog_seeds.dart`). Booking runs the normal cart/payment path with a per-day × days (or × sessions) multiplier; Housepital calls back after purchase to confirm requirements and assign staff. *Lineage:* prices were hidden Mar–Jun 2026 (audit M-1, based on a stale memory); the owner **reversed this on 2026-06-11, re-confirmed explicitly** (round 6 / `e41224c`). Quote-pending now applies **only** to items that genuinely lack a price — `isQuote` is `price == null || price == 0`, never `category == 'manpower'`; those export PRO FORMA invoices without amounts and are excluded from billing sums.
- **Separate business (durable):** Dai Maa (mother & baby) is a **different company and app** — not a Housepital offering. In-app presence is ONE cross-promo banner on Home linking out; Japa/Nanny are not sold in this app. `daimaa_theme.dart` exists only for the banner's branding.

Full conventions: [CONTRIBUTING.md](./CONTRIBUTING.md).
