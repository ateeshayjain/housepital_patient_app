# Housepital Patient App — 11-Checklist Audit Synthesis

**Date:** 2026-08-03 · **Commit:** `0a62955` (branch `fix/five-tab-nav`)
**Source:** eleven independent read-only audits against the owner's app-agnostic checklists.
Individual reports live beside this file in `docs/audits/`.

## Verdict

**The app fails all eleven checklists.** That sounds worse than it is, and the shape matters:
the app is *built* but not *operable*. Every checklist that measures "does the screen work"
scores respectably; every checklist that measures "what happens when this meets a real
patient, a real rupee, or a real outage" fails.

| Checklist | ✅ | ⚠️ | ❌ | N/A | Verdict |
|---|---|---|---|---|---|
| Accessibility | 4 | 7 | 15 | – | FAIL |
| Apple Design Framework | 33 | 39 | 10 | 15 | FAIL |
| Content & Localization | 3 | 16 | 11 | 2 | FAIL |
| Documentation | 3 | 16 | 16 | 0 | FAIL |
| Performance & Reliability | 2 | 18 | 14 | 1 | FAIL |
| Post-Launch Operations | 1 | 11 | 14 | 2 | FAIL |
| Release & App Store | 3 | 13 | 26 | 1 | FAIL |
| Security & Privacy | 8 | 21 | 21 | 1 | FAIL |
| Sync & Multi-Device | 1 | 5 | 19 | 6 | FAIL |
| Testing | 31 | 27 | 29 | 10 | FAIL |
| Upgrade Path | 0 | 10 | 12 | 2 | FAIL |

## What the eleven audits independently agreed on

These are the findings that more than one agent reached from a different direction. Cross-
confirmation is the strongest signal in this document.

### 1. The backend does not exist, and the app hides that from the patient
`api.housepital.in` is **NXDOMAIN** (verified by DNS lookup, not assumed). Every provider
catches the failure and serves `DemoData` — the demo patient "Rajesh Kumar", 72, post-stroke,
with five named prescriptions. There is no banner anywhere in `lib/`: the one signal the code
computes (`app_provider.dart:232` `_lastUpdatedText = 'Demo data'`) is rendered by no screen.

Four audits reached this independently (post-launch, upgrade, release, sync). It is the single
most dangerous property of the current build: **a family member checking whether insulin was
given reads a stranger's chart, with full visual confidence and no indication.**

### 2. Money can be taken without being verified
`payment_service.dart:185` returns `skippedDemo` whenever `orderId`/`signature` are absent, and
`:163-166` calls the **same success callback as `verified`**. I read this path myself to confirm
it. `createOrder` has zero callers, so a live Razorpay key produces exactly that state: order
confirmed, cart cleared, payment never verified. Separately, `payment_screen.dart:266-283`
sets `_paymentSuccess = true` unconditionally on web, gated on `kIsWeb` rather than
`PaymentService.isDemoPayments`.

### 3. One patient's medical data renders under another patient's name
`app_provider.dart:157` switches patient and resets nothing; the other four providers are never
told a switch happened. `auth_provider.dart:223` `logout()` clears SharedPreferences but resets
no in-memory provider, so on a shared phone the previous patient's data survives a sign-out.
Both are PHI leaks in an app whose whole premise is that several family members share access.

### 4. Writes that report success and go nowhere
Nine paths, including a medication dose log (`medication_provider.dart:109-126`, in-memory only,
dies on app kill — while the UI flips to "Taken" with haptic confirmation), daily feedback
("We've shared your feedback with the team" → a local int), document save, and family
add/remove. In a care app, a dose log that silently evaporates is a clinical record failure.

### 5. Nothing that goes wrong in production is observable
`logger.dart:63` is an unwired TODO, so ~45 `Log.warn`/`Log.error` sites reach no remote sink.
Crashlytics captures fatals only, and has no iOS dSYM upload phase, so what does arrive is
unsymbolicated. There is no analytics of any kind: the team could not answer "did anyone
complete a booking yesterday?" And there is no kill switch, feature flag, or force-upgrade —
so if a dosage-display bug ships, the only options are hotfix-and-wait or phone every patient.

## Blockers, ranked by (harm × likelihood) ÷ effort

I verified items 1–6 in the working tree myself rather than relying on the reports.

| # | Blocker | Evidence | Fix size |
|---|---|---|---|
| 1 | **iOS hard-crashes on any camera/photo tap** — `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are absent while six screens call `ImagePicker` | 0 matches in `ios/Runner/Info.plist`; 6 files use image_picker | 2 lines |
| 2 | **App icon is the stock Flutter logo** (rendered and eyeballed — it is the blue F), launch screen is a 1×1 transparent PNG | `AppIcon.appiconset/` | asset drop |
| 3 | **Unverified payments accepted as success** | `payment_service.dart:163-166,185` | ~10 lines |
| 4 | **`/services` route returns a blank `Scaffold()` with no back button**, reachable from the assistant's "services dikhao" | `main.dart:555-557` | 1 line |
| 5 | **PHI leak on patient switch and on logout** | `app_provider.dart:157`, `auth_provider.dart:217-223` | ~1 day |
| 6 | **Firebase config tracked in git** — `android/app/google-services.json` and `lib/config/firebase_options.dart` are both tracked, contradicting CLAUDE.md's claim that plists are gitignored (the .gitignore rule was added *after* they were committed, so it is inert) | `git ls-files` | rotate + untrack |
| 7 | **No Firebase Storage rules at all** — chat and concern-evidence photos upload to Storage; the default posture exposes them across patients | no `storage` block in `firebase.json` | rules file |
| 8 | **No account deletion path** — automatic App Store rejection (5.1.1(v)) and a DPDP §12 gap | Settings has Logout only | ~1 day |
| 9 | **Demo clinical data seeds on every fresh install** and is shown as the user's own | `app_provider.dart:182` | gate it |
| 10 | **No schema version, no migration hook, no force-upgrade gate** — 13 SharedPreferences namespaces of bare JSON. Free to fix now; expensive-to-impossible once v1 is on real phones | grep finds no `schema_version`/`migrat` | ~120 lines |

## The contrast question you asked about

**White `#FFFFFF` on Housepital orange `#F39314` = 2.33 : 1.** I computed this myself:
orange relative luminance 0.39973. It fails 4.5:1 by 1.93×, and fails the 3:1 large-text floor
too — there is no text size at which it passes. Unselected nav labels are worse: white at 70%
alpha composites to `#FBDFB8` = **1.82 : 1** (`main_shell.dart:79`).

This is reported as measured fact, not as a recommendation to reverse your decision. The
smallest change that **keeps white ink everywhere** is a darker orange *fill* token used only
behind text, at the same hue: `#AA670E` = 4.51:1, or `#D58112` = 3.01:1 for icons and large
text. Four edit sites. Orange as an accent on true black is already fine at 8.99:1.

**Separately — and this one is not an owner decision, it is a wrong number:** three tokens in
`theme.dart:62,64,87` carry comments claiming 4.5–4.6:1 and actually measure **3.99 / 3.62 /
3.79:1**. `orangeText` is the default `TextButton` foreground app-wide. The design gate bans raw
orange *because of* that incorrect figure. `#9A5C00` gives 5.38:1 on white.

## Cheapest high-value work (a day or two, disproportionate return)

1. Two Info.plist keys — stops a crash.
2. Real app icon + launch screen.
3. `/services` blank screen — one line.
4. The three placeholder phone numbers (`+919999999999`, `+918888888888`) that currently sit on
   help and emergency paths, and the `emergencyPhone == supportPhone` collision.
5. **85 one-line localization swaps** where a good Hindi translation already exists in both JSONs
   and the screen hardcodes English anyway. (Hindi is genuinely well translated — 315/321 real
   Devanagari, font fallback correct. It is simply never called: 13.8% coverage.)
6. Delete 40.8 MB of unreferenced product images (238 of 439 files are not in the catalog JSON).
7. Fix the four `https://housepital.in/...` links that fail TLS — `www.` works, apex doesn't.
8. Delete `VitalHelper` — two contradictory vital classifiers currently run on the same screen
   (SpO₂ 91 reads "borderline" via one and "red" via the other).

## Where the app is genuinely strong

Worth stating plainly, because eleven FAIL verdicts distort the picture:

- The global error boundary is textbook — `runZonedGuarded` + `FlutterError.onError` +
  `ErrorWidget.builder` + route-level recovery, correctly `kIsWeb`/`kDebugMode` gated.
- Data minimization is excellent: no Aadhaar, no bank details, no government ID collected.
  Tokens are never persisted. `firestore.rules` is default-deny. Data residency is `asia-south1`.
- `ANTHROPIC_API_KEY` is clean — verified by `git log -p --all` across every ref; it has never
  existed in client code. It lives only at `functions/index.js:21` as a Firebase secret.
- Every chart and gauge has a text equivalent; Reduce Motion is honoured at 11 sites; no
  infinite pulses anywhere.
- The 28 patient-education articles are genuinely good: plain language, India context, red-flag
  lists, consistent clinical disclaimer.
- Two excellent CI guards — the 320/375/414 overflow smoke test and the EN/HI key-sync test.
- 1,372 tests with real strength in pure logic (pricing, permissions, validators, vitals).
- The design gate has eradicated hex literals and banned patterns from `lib/screens`.

## Uncomfortable finding about the test suite

The suite is green, large, and partly self-referential. **120 tests execute zero production
code** — seven files replicate FAQ data, coupon maths, IV price tables and catalog invariants
inside the test file and assert the copy. They have not drifted yet, and nothing would ever
detect it if they did. Twenty-four tests marked `Critical? YES` guard
`booking_state_machine.dart`, which has **zero production callers**. And `_priceMultiplier` —
the arithmetic that turns ₹1,500/day into a ₹45,000 booking, the live owner pricing rule — has
**no test at all**. Meanwhile 17 payment tests skip silently on a bare `flutter test`.

Green does not currently mean safe on the paths that carry money and doses.

## Documentation drift (third repeat of the same failure)

Four commits landed on 2026-06-15 and not one touched a `.md`. The dead "never show manpower
prices" rule survives in **six live docs and seven code/test sites**, including an active test
named `'sheet shows no prices for manpower'`. Eleven doc lines still assert six tabs. `SCREEN_MAP`
documents a `BookingHistoryScreen` widget that does not exist. `ARCHITECTURE.md` misses
`RemindersProvider`.

CLAUDE.md and BUSINESS_RULES.md are correct and agree with each other; everything else drifted
away from them.

## Owner-blocked items

Nothing below can be closed from the code side:

- Real Razorpay key (and a decision on whether payments go live before backend verification exists).
- The backend itself — `api.housepital.in` does not resolve.
- Privacy policy URL, support URL, App Store screenshots, description, age rating, privacy
  nutrition labels.
- Firebase console: Storage rules deployment, alerting, budget.
- Confirmation of the real support and emergency phone numbers.
- Master Excel with authoritative prices (88 rental prices, diagnostics, and 4 flagged
  placeholder sale prices are still estimates).
- Assistant enablement: `firebase functions:secrets:set ANTHROPIC_API_KEY`,
  `firebase deploy --only functions`, then rebuild with `--dart-define=ASSISTANT_API_URL=…`.
