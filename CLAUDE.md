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

- **Manpower prices are NEVER shown** — caretaker, nursing, attendant (legacy japa/nanny).
  No ₹/GST anywhere in catalog, wizard, cart, orders. Booking is quote-pending:
  `orders_provider.dart` sets `quoteStatus: 'pending'`; copy is
  "Price confirmed on call before payment"; never render ₹0; quote invoices are
  PRO FORMA without amounts; billing sums exclude quotes. Customers reject without
  talking if they see a manpower price. (Any doc claiming prices are shown is stale.)
- **Dai Maa is a separate business** — one cross-promo banner on Home linking to the
  external app, nothing else. Japa/Nanny are not Housepital offerings.
- **SOS is never blocked** — no permission gate, no confirmation friction on the SOS path.
- **Equipment** shows MRP strikethrough + discounted price (Blinkit-style);
  price-on-request items use the Reserve flow (no fabricated price).
- Secrets: `ANTHROPIC_API_KEY` lives server-side (Firebase secret) only; Razorpay key via
  `--dart-define`; Firebase plists are gitignored.

## Design system contract

- **Colors:** every brightness-sensitive color goes through `context.hc.*`
  (`lib/config/app_colors.dart`, `HcPalette` light/dark). Raw `Colors.*`, hex literals,
  and `Colors.grey.shade*` are banned by `scripts/check_design_consistency.sh`
  (allowlist inside the script). One accent: orange `#F39314`; orange text on light
  surfaces uses `orangeText`. Green = good status, red = SOS/error only, blue = info.
- **Chrome:** every screen uses `GlassAppBar` (`lib/widgets/glass.dart`). Nav contract:
  back on the left; trailing order `[custom…, search → '/search', home → pop-to-root +
  MainShell.switchToTab(0)]`; `showSearch` defaults on; `showHome` off on root tabs.
  Glass screens pair with `extendBodyBehindAppBar` + scroll padding
  `MediaQuery.padding.top + kToolbarHeight` (resolve MediaQuery from a context BELOW the
  Scaffold). Padding-less nested scrollables absorb ambient insets — give them
  `padding: EdgeInsets.zero`.
- **Cards:** `HousepitalCard` (squircle `RoundedSuperellipseBorder(16)`, press-scale
  0.97 @ 120ms). Do not hand-roll `Container(radius: 12, border: …)` cards, and do not
  wrap cards in bare `GestureDetector` — use `HousepitalCard(onTap:)`.
- **Type:** bundled `Archivo` (+ `NotoSansDevanagari`) — google_fonts was removed; never
  re-add it. 11px minimum text size.
- **Touch targets:** ≥44pt. Visual element may be smaller; reserve the hit area
  (ConstrainedBox / padded InkWell).
- **Motion:** gate animations on `MediaQuery.disableAnimations`; celebrations ≤500ms;
  no infinite pulses; nothing animated on SOS/payment/vitals paths.
- **i18n:** every new user-facing string gets a key in BOTH `assets/i18n/en.json` and
  `hi.json` (guard test enforces sync).

## Architecture notes

- Provider for state. `OrdersProvider` seeds `DemoData.orders` **in-memory only** when
  persistence is empty — demo orders are never written to storage (a test asserts this).
- Role/permission layer gates actions per user role (patient-self, primary contact,
  family, caretaker). Sensitive exports (doctor handover PDF) are role-gated.
- PDFs are generated on-device: `invoice_pdf_service.dart`, `handover_report_service.dart`
  (`pdf` + `printing`). Inject `DateTime` for determinism in tests.
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
