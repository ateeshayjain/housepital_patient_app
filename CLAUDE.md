# CLAUDE.md — Housepital Patient App

Flutter/Dart home-healthcare app (Delhi NCR). "Hospital-like expertise. Home-like care."
Runs in demo mode when `api.housepital.in` is unreachable — `DemoData` fallbacks load and
the failed fetch is logged; that log line is expected, not a bug.

## Commands

```bash
flutter analyze                                   # must be clean (CI: --no-fatal-warnings --no-fatal-infos)
flutter test --dart-define=RAZORPAY_KEY=rzp_test_ci_dummy_key   # full suite; the dart-define un-skips 8 payment groups
bash scripts/check_design_consistency.sh          # design gate — must pass before any commit
flutter test test/screens/overflow_smoke_test.dart # 37 screens × 320/375/414 overflow guard
flutter test test/widgets/dark_mode_test.dart      # dark-mode token guard
flutter test test/utils/i18n_sync_test.dart        # EN/HI key-sync guard
```

Run the design gate + analyze + the relevant test files after every change. Never end a
task "waiting for the test suite" — run targeted files, report results.

## Inviolable business rules

- **Manpower prices ARE shown and directly bookable** — caretaker, nurse, physio.
  Prices come from the official Delhi NCR rate card (Caretaker ₹800–1,500/day,
  Nurse ₹1,600–3,000/day, plus monthly packages ₹18,000–₹90,000/mo), stored as
  per-day `basePriceMin` in `catalog_seeds.dart`. Booking goes through the normal
  cart/payment path; the booking wizard multiplies the unit rate (per-day × days
  for ongoing manpower, × sessions for IV/physio — `_priceMultiplier` in
  `service_booking_screen.dart`). Housepital calls back after purchase to confirm
  requirements and assign staff. **Lineage:** prices were hidden Mar–Jun 2026
  (audit M-1, based on a stale memory); the owner reversed this on 2026-06-11
  (re-confirmed explicitly) — round 6 / commit `e41224c`.
- **Quote-pending applies ONLY to items that genuinely lack a price** — `isQuote`
  is `price == null || price == 0` (`service_booking_screen.dart`), **never**
  `category == 'manpower'`. For those price-less items: never render ₹0; quote
  invoices export PRO FORMA without amounts (`OrdersProvider.isQuotePending`);
  billing sums exclude quotes. Equipment price-on-request uses the Reserve flow.
- **Dai Maa is a separate business** — one cross-promo banner on Home linking to the
  external app, nothing else. Japa/Nanny are not Housepital offerings.
- **SOS is never blocked** — no permission gate, no confirmation friction on the SOS path.
- **Equipment** shows MRP strikethrough + discounted price (Blinkit-style); every
  catalog item now carries a price (zero price-on-request remain). 100 high-traffic
  items have bundled product photos in `assets/images/products/`, rendered by the
  shared `ProductImage` widget (asset→Image.asset, url→CachedNetworkImage, else
  fallback icon) in both the grid card and the detail sheet. ~31 generic/unbranded
  items still show the placeholder icon (known gap).
- Secrets: `ANTHROPIC_API_KEY` lives server-side (Firebase secret) only — verified absent from
  every ref in git history; Razorpay key via `--dart-define`. **The iOS plist is gitignored and
  was never committed, but `android/app/google-services.json` and `lib/config/firebase_options.dart`
  ARE tracked** (the `.gitignore` entries were added after those files were committed, so they
  are inert). Firebase client keys are not secrets in the way an API key is — they identify the
  project and are embedded in every shipped binary — so the real control is Firebase Security
  Rules plus API-key restrictions in the console, not untracking the files. Do not repeat the
  old claim that "Firebase plists are gitignored" as though it covered all platforms.
- **Storage rules:** `storage.rules` (default-deny + per-patient chat/concern photo paths) must be
  deployed with `firebase deploy --only storage`; editing the file alone changes nothing live.

## Design system contract

- **Demo-data notice:** `DemoDataBannerHost` (installed from `MaterialApp.builder`) shows
  a compact glass **pill OVERLAY** while any `DemoMode` source serves sample data. It is a
  Stack overlay, never a layout participant — two earlier shapes (inside `MainShell`; a
  full-width strip in a Column) each regressed, the strip by stealing the status bar and
  pushing every glass app bar down. Adding or removing it must not change any screen's
  layout.
- **Colors:** every brightness-sensitive color goes through `context.hc.*`
  (`lib/config/app_colors.dart`, `HcPalette` light/dark). Raw `Colors.*`, hex literals,
  and `Colors.grey.shade*` are banned by `scripts/check_design_consistency.sh`
  (allowlist inside the script). One accent: orange `#F39314` (one-accent color
  budget — don't introduce a second brand hue); orange text on light surfaces uses
  `orangeText`. **`onOrange` is WHITE app-wide** (owner decision — `#FFFFFF` in both
  light and dark `theme.dart`); text/icons on any orange fill are white. Green =
  good status, red = SOS/error only, blue = info. Dark mode is **true-black tonal**.
- **Chrome:** every screen uses `GlassAppBar` (`lib/widgets/glass.dart`). Nav contract:
  back on the left (or HOME leftmost on non-Home root tabs); trailing order
  `[custom…, home, search → '/search', cart → '/cart']` with the **CART always
  rightmost** and a live item-count badge. `showSearch`/`showCart`/`showHome` all
  default on; the purchase funnel (cart/checkout/payment) opts out of the cart icon
  (it would loop into itself); Billing shows no cart; the Home tab omits its own
  home button (SOS is the home-screen far-right emergency exception).
  Glass screens pair with `extendBodyBehindAppBar` + scroll padding
  `MediaQuery.padding.top + kToolbarHeight` (resolve MediaQuery from a context BELOW the
  Scaffold). Padding-less nested scrollables absorb ambient insets — give them
  `padding: EdgeInsets.zero`.
- **Cards:** `HousepitalCard` (squircle `RoundedSuperellipseBorder(16)`, press-scale
  0.97 @ 120ms). Do not hand-roll `Container(radius: 12, border: …)` cards, and do not
  wrap cards in bare `GestureDetector` — use `HousepitalCard(onTap:)`.
- **Bottom nav:** `MainShell` renders a **FLOATING LIQUID-GLASS PILL** — 16px side
  insets, floating above the home indicator, `GlassSurface` radius 32, transparent
  `BottomNavigationBar` inside it. Owner iterated floating-glass → pill → fixed orange
  bar (round 5) → **back to the pill (round 8)**, matching the reference app they use
  daily. Round 5's objection ("the pill covered content") is answered structurally: the
  pill lives in the Scaffold's `bottomNavigationBar` slot, so the body's bottom
  MediaQuery inset still covers its full footprint and `extendBody: true` lets content
  glide underneath. Selected item uses `orangeStrong` (5.38:1), not `orangeText`
  (3.99:1) — a 12px label needs the AA floor, and the white-on-orange owner rule governs
  orange FILLS, not glass. **FIVE root tabs:** Home (0), My Care (1), Services (2),
  Billing (3), More (4). The **care calendar is not a tab** — the owner moved it to the
  My Care app bar (`'/care-calendar'`, custom action left of search) to get back to five
  icons. Indices 1/2/3 are referenced externally via `MainShell.switchToTab` — do not
  reorder them.
- **Paired foregrounds:** `onOrange` is white (owner decision, 2.33:1 — measured, accepted).
  `onError` FLIPS with appearance (white on light error = 4.98:1; dark ink on the lighter
  dark-mode error = 4.62:1) — white on dark-mode error is 3.49:1 and fails. `orangeStrong`
  (#9A5C00, 5.38:1) is for SMALL orange text where `orangeText` (3.99:1 measured, despite
  its comment) would fail.
- **Type:** bundled `Archivo` (+ `NotoSansDevanagari`) — google_fonts was removed; never
  re-add it. 11px minimum text size. Large iOS-style display titles. The typography scale
  is converging on a canon (28/w800 display • 16/w600 section header • etc.); the design
  gate prints an informational fontSize histogram (echo-only, never fails the build).
- **Touch targets:** ≥44pt. Visual element may be smaller; reserve the hit area
  (ConstrainedBox / padded InkWell).
- **Motion:** gate animations on `MediaQuery.disableAnimations`; celebrations ≤500ms;
  no infinite pulses; nothing animated on SOS/payment/vitals paths.
- **i18n:** every new user-facing string gets a key in BOTH `assets/i18n/en.json` and
  `hi.json` (guard test enforces sync). **Never branch control flow on a user-facing
  string** — translating it silently changes behaviour. The payment retry decision used to
  be `message.contains('under verification')`; it is now a typed `PaymentFailure`.

## Storage & session contracts

- **Orders/assessments are keyed PER PATIENT** (`housepital_orders_<patientId>`). A
  patient switch is a READ of a different key, so `OrdersProvider.clearPatientScopedData()`
  is memory-only and must never persist — the previous global-key version wrote `[]` over
  the outgoing patient's real history and destroyed it.
- **Every patient-switch path fans out through `SessionScope`**, via
  `AppProvider.onPatientChanged`, wired once by `SessionScope.install()` in
  `MainShell.initState`. There are two paths: the switch sheet and `loadPatients()`, which
  runs on every Home mount. A third must use the hook, not clear by hand.
- **`SessionScope` enumerates STORES, not symptoms** — provider fields, prefs keys, cache
  entries, and OS-scheduled notifications (`cancelAllReminders`, since they outlive the
  app). New patient-scoped state gets added there and asserted in
  `test/providers/patient_scope_isolation_test.dart` in the SAME edit.
- **`StoreMigrator` is at v2** with one shipped step. Bump `currentVersion`, add to
  `_buildShippedMigrations()`, use FROZEN literals (never a key constant or model class),
  `quarantine()` rather than overwrite, and never stamp success on a failed step.
- **`DemoMode` is a set of sources**; a source may clear only itself. Declare a `source*`
  constant and wire its call in the same edit — an unused constant is invisible to the
  analyzer and makes the list read complete when it isn't.

## Architecture notes

- Provider for state. `OrdersProvider` seeds `DemoData.orders` **in-memory only** when
  persistence is empty — demo orders are never written to storage (a test asserts this).
- Role/permission layer gates actions per user role (patient-self, primary contact,
  family, caretaker). Sensitive exports (doctor handover PDF) are role-gated.
- PDFs are generated on-device: `invoice_pdf_service.dart`, `handover_report_service.dart`
  (`pdf` + `printing`). Inject `DateTime` for determinism in tests.
- **Payments:** `payment_service.dart` runs in **demo mode** when the Razorpay key is a
  placeholder (`rzp_test_XXXXXXXXXX` / `rzp_test_dummy`) — `openCheckout` simulates the
  checkout locally so the full purchase flow stays demoable. A real key via
  `--dart-define=RAZORPAY_KEY=…` enables real checkout (the CI key `rzp_test_ci_dummy_key`
  is deliberately NOT a placeholder — it un-skips the real-checkout tests).
- **Sahayak assistant:** demo builds use a local Hinglish intent matcher/executor
  (`assistant_service.dart` + `assistant_local_actions.dart`) that really executes
  add-to-cart / booking offline; the Cloud Function (Claude) is used when
  `ASSISTANT_API_URL` is set.
- Tests render with the Ahem font (worst-case wide glyphs). Overflow fixes must be
  device-correct (Flexible/ellipsis, FittedBox(scaleDown), mainAxisExtent grids) — never
  hacks that only satisfy Ahem.
- Widget-test pitfall: two pumps of the SAME `const` widget are canonicalized — the
  second pump does not rebuild. One pump per test when asserting theme changes.

## Git / process

- Feature branches only (`fix/<topic>`, `feat/<topic>`) — never push directly to `main`.
- Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- Before any phone release after switching builders (Xcode ⇄ CLI): `flutter clean`
  (DerivedData collisions cause 0xe8008014 invalid-signature installs). One builder rule:
  don't mix Xcode and CLI builds of the same artifact.
- iOS simulator runs debug-only attached; a standalone phone install needs a release
  build on the physical device.
