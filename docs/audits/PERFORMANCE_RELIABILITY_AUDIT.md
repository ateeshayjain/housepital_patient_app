# Performance & Reliability Checklist (App-Agnostic) — Audit vs commit 803124d

**Date:** 2026-08-03 · **Auditor:** Performance & Reliability agent
**Method:** static only — `du`, `sips`, `rg`, `python3` measurement + code reading.
`flutter analyze` reported clean by the caller; no `flutter test` / `build` / `clean` run (central suite owns those).

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED |
|---|---|---|---|---|---|
| 1. Startup / first response | 1 | 1 | 1 | 0 | 0 |
| 2. Rendering & interaction | 0 | 2 | 2 | 0 | 0 |
| 3. Memory | 0 | 1 | 2 | 0 | 1 |
| 4. Battery, network & resource | 0 | 3 | 1 | 0 | 0 |
| 5. Data & query performance | 0 | 2 | 1 | 1 | 0 |
| 6. Concurrency & responsiveness | 0 | 2 | 2 | 0 | 0 |
| 7. Reliability & resilience | 1 | 3 | 2 | 0 | 0 |
| 8. Size & asset hygiene | 0 | 1 | 2 | 0 | 0 |
| 9. Accessibility-driven perf | 0 | 2 | 1 | 0 | 0 |
| 10. Measurement & evidence | 0 | 1 | 0 | 0 | 3 |
| **TOTAL (39 items)** | **2** | **18** | **14** | **1** | **4** |

---

## Measured facts (the numbers this audit rests on)

```
assets/                       81 MB total
assets/images/                79 MB
assets/images/products/       78 MB across 439 files (avg 182.6 KB)
  >500 KB: 30 files   >200 KB: 55   >100 KB: 84   >50 KB: 138   <=50 KB: 132
assets/equipment_catalog.json 862,279 bytes / 351 entries
assets/lab_tests_catalog.json 153 entries
lib/                          2.2 MB, 54,295 LOC across 149 .dart files
```

**Product-image reference analysis** (`assets/images/products/*` vs every `assets/images/products/…`
string in `lib/` + `assets/*.json`):

```
referenced (unique):   201 files = 37.5 MB
UNREFERENCED:          238 files = 40.8 MB   <-- dead weight in the binary
referenced-but-missing:  0 files             (no broken paths — good)
```

`equipment_catalog.json` carries 320 `image_url` asset paths resolving to 201 unique files
(variants share art) and 31 null/absent entries — the "~31 placeholder items" known gap in
`CLAUDE.md` is confirmed accurate.

**Largest images vs their display size.** Grid cards are `(width − 30) / 2` ≈ **180 pt** wide
(`lib/screens/services/tabs/equipment_tab.dart:394-397`), image area ≈ 164 pt → **~492 px at 3×**.

| File | On-disk | Pixels | Decoded RGBA |
|---|---|---|---|
| `0009_Aircurve_10_Vauto_Apac_Tri_4g.png` | 5.5 MB | 2000×2000 | **16.0 MB** |
| `0094_ECG_Electrodes.png` | 3.6 MB | 3000×2010 | **24.1 MB** |
| `0479_ResMed_AirFit_F20_Full_Face_Mask.png` | 1.9 MB | 2048×2048 | **16.8 MB** |
| `0360_Inj_Ondomed.jpg` | 1.7 MB | 1800×2890 | **20.8 MB** |

A 492 px target needs ~0.97 MB decoded. The worst asset is decoded at **~17× the required
pixel budget**.

---

## Findings

### 1. Startup / first response

- ❌ **Time-to-interactive is floored at 2 s by construction** — evidence:
  `lib/screens/splash_screen.dart:15` — `Future.delayed(const Duration(seconds: 2), …)` then
  `pushReplacementNamed('/home')`. The splash does no work; it is a hard-coded wait.
  **Impact:** cold launch can never meet the <2 s target no matter how fast init becomes;
  every user pays 2 s on every launch. **Fix:** race the delay against real readiness —
  `await Future.wait([initFuture, Future.delayed(Duration(milliseconds: 400))])` — so the
  splash covers actual work rather than replacing it.

- ⚠️ **Work blocking startup** — evidence: `lib/main.dart:101` awaits `Firebase.initializeApp`;
  `:120-131` awaits four Crashlytics/Performance setters; `:170` awaits
  `MedicationReminderService().init()` — all **before** `runApp` at `:183`. Additionally
  `lib/screens/main_shell.dart:36-42` puts all five root screens in an `IndexedStack`
  (`:57-60`), which **builds and lays out every child**, so at first frame the app runs
  `initState` + `build` for HomeScreen (1,904 LOC), MyCareScreen (750), ServiceCatalogScreen
  (247), BillingScreen (687) and SettingsScreen (454) — ~4,000 LOC of widget tree for four
  tabs the user has not opened. Three of them kick off async loads immediately:
  `home_screen.dart:58` `app.loadPatients()`, `my_care_screen.dart:41`
  `Future.microtask(() => _loadData())`, `settings_screen.dart:29` `_loadProfilePhoto()`.
  **Fix:** keep `IndexedStack` but wrap non-Home children in a lazily-instantiated
  placeholder that materialises on first visit.

- ✅ **First view shows content fast** — evidence: `lib/screens/splash_screen.dart:22-56`
  paints a branded screen with zero async dependencies; the equipment catalog has a real
  shimmer skeleton at `lib/screens/services/tabs/equipment_tab.dart:204-235`.

### 2. Rendering & interaction

- ⚠️ **Smooth scroll/animation (60fps)** — BLOCKED on a device for the actual measurement,
  but the static risk is concrete: see the image-decode finding below. Flutter's `ImageCache`
  is left at its default 100 MB / 1000 entries (no `imageCache` tuning exists anywhere in
  `lib/`). With 6–8 grid tiles visible at up to 16–24 MB decoded each, the cache thrashes
  during a normal catalog scroll.

- ⚠️ **Lazy loading / virtualization for long lists** — mixed. Correctly virtualized:
  `equipment_tab.dart:212` and `:400` (`GridView.builder` with `mainAxisExtent`),
  `lab_tests_tab.dart`, `packages_tab.dart`, and `lib/widgets/paginated_list.dart` used by
  four history screens (`report_history_screen.dart:30`, `transaction_log_screen.dart:57`,
  `attendance_history_screen.dart:31`, `notifications_screen.dart:44`). **Not** virtualized
  over unbounded data:
  - `lib/screens/search/universal_search_screen.dart:300-307` — `ListView(children: grouped.entries.expand(…).toList())`
    builds **every** search result eagerly across a ~550-item corpus (351 equipment + 153 lab
    tests + 46 service seeds).
  - `lib/screens/services/tabs/diagnostics_tab.dart:39` and `:56` — `...filtered.map(…)` eager.
  - `lib/screens/services/tabs/consultations_tab.dart:41`, `lib/screens/services/tabs/manpower_tab.dart:48` — same pattern.

  **Fix:** convert these four to `ListView.builder` with a header index, as `equipment_tab` already does.

- ❌ **Images sized/compressed to display size** — evidence: `lib/widgets/common_widgets.dart:129-131`
  `Image.asset(url, fit: fit, …)` with **no `cacheWidth`/`cacheHeight`**, and `:135-140`
  `CachedNetworkImage` with **no `memCacheWidth`/`memCacheHeight`**. Repo-wide grep for
  `cacheWidth|cacheHeight|ResizeImage|memCacheWidth` returns **zero matches**.
  **Impact:** a 180 pt card decodes a 2000×2000 PNG at full resolution — 16 MB of RAM for
  ~1 MB of need. This is the single largest runtime memory lever in the app.
  **Fix:** in `ProductImage.build`, add
  `cacheWidth: (MediaQuery.devicePixelRatioOf(context) * 180).round()` to the `Image.asset`
  branch and the matching `memCacheWidth` to `CachedNetworkImage`.

- ❌ **No expensive work in render/row builders** — evidence:
  `lib/screens/search/universal_search_screen.dart:277` —
  `onChanged: (v) => setState(() => _query = v.trim())` with **no debounce**; `:261`
  `final results = _results;` calls a **getter that rescans the whole corpus inside `build`**
  (`:159-…`). Every keystroke therefore = full corpus scan + eager rebuild of all matching
  tiles + full-resolution image decodes.
  **Fix:** debounce input ~250 ms, memoise `_results` against `_query`, and switch the
  result list to `ListView.builder`.

### 3. Memory

- ⚠️ **No leaks / retain cycles** — mostly good, three real defects:
  - ❌ `lib/screens/documents/document_repository_screen.dart:47` — `final _searchController = TextEditingController();`
    is **State-owned and never disposed**; the file contains **no `dispose()` at all**
    (grep for `dispose` in that file returns nothing). Confirmed leak.
  - ⚠️ `lib/widgets/common_widgets.dart:16-17` — `OverlayEntry? _activeToast;` and
    `Timer? _toastTimer;` are **module-level mutable globals**. `_dismissTopToast`
    (`:95-100`) only runs on tap, on timer fire, or when the next toast replaces it —
    **nothing cancels it on route teardown**. Navigating away within the 3 s window leaves a
    live `Timer` holding an `OverlayEntry` for a route that is gone.
    **Fix:** key the toast to the route (`ModalRoute.of(context)`) and cancel in a route-aware
    observer, or at minimum null-check the overlay's `mounted` state before `remove()`.
  - ❌ **17 unclosed HTTP clients** — `ApiService` is **not a singleton** (no `factory` /
    `static instance` in `lib/services/api_service.dart`), `_client` is created per instance at
    `:41`, and there is **no `dispose()`/`close()` in the file**. `ApiService()` is constructed
    ad hoc at 17 call sites: `daily_report_screen.dart:33`, `universal_search_screen.dart:145`,
    `transaction_log_screen.dart:62`, `cart_screen.dart:64`, `payment_methods_screen.dart:25`,
    `staff_profile_screen.dart:39`, `notifications_screen.dart:33/49/149`,
    `staff_replacement_screen.dart:187`, `doctor_advice_card.dart:52`, `return_screen.dart:325`,
    `equipment_detail_screen.dart:170/1351`, `service_booking_screen.dart:88`,
    `equipment_tab.dart:67`, `payment_service.dart:58`.

  Correctly handled elsewhere, and worth crediting: every periodic `Timer` is cancelled
  (`otp_screen.dart:77`, `home_screen.dart:88`, `auth_provider.dart:234`,
  `sync_service.dart:111`, `video_consultation_screen.dart`), and all four
  `StreamSubscription`s are cancelled (`firebase_service.dart:16`, `chat_screen.dart:40`,
  `staff_otp_verification_screen.dart:44`, `order_tracking_screen.dart:37`).

- ❌ **Large media streamed or bounded** — evidence: as §2 above, plus `ImageCache` never
  tuned. Nothing bounds decoded image memory anywhere in the app.

- ❌ **Caches have a size bound and evict** — evidence: `lib/services/cache_service.dart` has a
  30-minute TTL (`:7`, `_isExpired` `:52-55`) but **no size bound and no eviction**. Expired
  entries `return null` at `:31` yet are **never removed from disk** — only the blanket
  `clear()` (`:37-43`) or an explicit `remove(key)` deletes anything. Backed by
  `SharedPreferences`, which iOS loads wholly into memory as a plist, so the store grows
  monotonically for the life of the install.
  **Fix:** delete the key inside the `_isExpired` branch, and add an LRU/entry-count cap in `cache()`.

- **BLOCKED-OWNER** — "Memory returns to baseline after heavy flows." Needs an Instruments
  Allocations run on a device: launch → scroll the full equipment catalog → back out, and
  confirm the image cache releases. I can predict pressure but cannot measure recovery statically.

### 4. Battery, network & resource use

- ⚠️ **No busy-wait loops / runaway timers** — no busy-waits; all timers are cancelled. But
  `lib/services/sync_service.dart:96` is `Timer.periodic(interval, …)` at a **fixed 5-minute
  interval with no backoff and no escalation** — against an unreachable host it retries
  forever at the same rate. Both call sites swallow the outcome (`:92-94`, `:97-99`).

- ⚠️ **Background work registered correctly and finishes promptly** — FCM setup is correctly
  deferred to `addPostFrameCallback` (`lib/main.dart:321-324`) and cold-start notifications are
  drained at `:376-382`. However nothing bounds how long a detached request runs (see cancellation below).

- ⚠️ **Requests batched/coalesced; retried with backoff** — backoff **is** implemented and is
  genuinely good: `lib/services/api_service.dart:55-85`, 2 retries at `_retryDelay * attempt`
  (1 s then 2 s) for `SocketException`, `TimeoutException` and 5xx, with a deliberately separate
  one-shot 401 recovery (`:92-100`) so a permanent 401 does not fan out. **Not** coalesced:
  the 862 KB `equipment_catalog.json` is loaded and decoded independently at **seven** sites
  with **no shared cache** (grep for a static/memoised catalog returns nothing):
  `universal_search_screen.dart:149`, `package_detail_screen.dart:35`,
  `assistant_local_actions.dart:39`, `doctor_advice_card.dart:55`,
  `equipment_detail_screen.dart:138`, `equipment_tab.dart:72`, `medications_screen.dart:353`.
  Opening Equipment → tapping an item re-parses the entire 862 KB file a second time.
  **Fix:** one `static Future<List<EquipmentItem>>? _catalog` memo in a shared loader.
  (`doctor_advice_card.dart:38-60` already does exactly this per-instance — that pattern is
  the right one, just needs to be static and shared.)

- ❌ **Requests cancelled when no longer needed** — evidence: grep for
  `CancelToken|abort|_client.close` across `lib/services/` returns **nothing**. Timeouts exist
  only at the **caller** level (9 sites: `app_provider.dart:144/199`,
  `medication_provider.dart:198`, `my_care_provider.dart:61`, `blog_provider.dart:33/64`,
  `assistant_executor.dart:336/363/392`) — `ApiService` itself sets **no request timeout at all**.
  **Impact:** a caller's `.timeout(5s)` abandons the *future* but the underlying socket and the
  `_withRetry` loop keep running detached, so a hung connection burns radio and memory well past
  the 5 s budget. It also means the `on TimeoutException` branch at `api_service.dart:77` is
  effectively dead code — that exception is thrown by the caller's wrapper, outside `_withRetry`.
  Worse, **20 of 25 API call sites have no timeout at all**.
  **Fix:** apply `.timeout(const Duration(seconds: 10))` inside `_withRetry` per attempt, and
  give `ApiService` a `close()` that disposes `_client`.

### 5. Data & query performance

- **N/A — hot queries / indexes.** There is no local database (no sqflite/drift/Isar in
  `pubspec.yaml`); persistence is `SharedPreferences` only. Firestore is used for three live
  listeners (`chat_screen.dart:54`, `staff_otp_verification_screen.dart:97`,
  `order_tracking_screen.dart:154`); index configuration is server-side and out of scope here.

- ⚠️ **N+1 patterns avoided** — no classic N+1 over the network, but the catalog re-parse
  above is the client-side equivalent: the same 862 KB / 351-object payload is materialised
  repeatedly instead of once.

- ⚠️ **Large result sets paginated; query timeouts set** — `PaginatedListView`
  (`lib/widgets/paginated_list.dart`) exists and is used correctly in four history screens
  with `pageSize: 20`. But timeouts cover only 5 of 25 provider call sites (see §4).

- ❌ **Connection pooling / reads off the UI thread** — two failures. (a) Pooling is defeated:
  17 independent `http.Client()` instances, each with its own connection pool, none closed
  (§3). (b) Nothing runs off the UI isolate — grep for `compute(` / `Isolate.` across `lib/`
  returns **zero matches**, while `jsonDecode` of the 862 KB catalog runs on the main isolate at
  seven sites, and PDF generation (`invoice_pdf_service.dart:96`,
  `handover_report_service.dart:97`) is likewise synchronous on the UI isolate.
  **Fix:** move catalog decode and PDF building into `compute()`.

### 6. Concurrency & responsiveness

- ❌ **No blocking calls on the main/UI thread** — as above: 862 KB `jsonDecode` + 351
  `fromJson` allocations ×7 sites, plus PDF generation, all on the UI isolate with no
  `compute()` anywhere.

- ❌ **Long operations cancellable and cancelled on navigation/teardown** — no cancellation
  primitive exists in the codebase (§4).

- ⚠️ **Shared mutable state protected** — the toast globals
  (`lib/widgets/common_widgets.dart:16-17`) are app-wide mutable state mutated from any screen
  with no ownership discipline. Dart's single isolate prevents a true data race, but the
  read-modify-write in `showTopToast` → `_dismissTopToast` → `overlay.insert` is
  interleavable across routes.

- ⚠️ **State captured at invocation, not execution** — 114 `mounted` guards across 123
  `await`s in `lib/screens` is good coverage, plus 18 `context.mounted` guards. Two confirmed
  gaps: `lib/screens/reports/daily_report_screen.dart:34` (`setState` straight after
  `await ApiService().getReportDetail(…)`, launched from `initState:28`, no guard — also `:88`
  in the catch) and `lib/screens/notifications/notifications_screen.dart:34`
  (`setState` after `await ApiService().markAllNotificationsRead()` in a button handler, no guard).

### 7. Reliability & resilience

- ❌ **Crash/error-free target defined and monitored** — evidence:
  `lib/utils/logger.dart:63` — `// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`.
  `_log` (`:52-66`) only calls `debugPrint`. Crashlytics therefore receives **fatal crashes
  only**; every `Log.warn`/`Log.error` — the entire "we logged the fallback" story, ~45 call
  sites — reaches no remote sink in release. No error-rate or crash-free-sessions target is
  defined anywhere in the repo. **Fix:** it is a genuine one-line change at the documented
  chokepoint — `FirebaseCrashlytics.instance.recordError(error, stack, fatal: false)` guarded
  on `!kIsWeb && !kDebugMode`.

- ✅ **No uncaught exceptions on user paths; global error boundary exists** — this is done
  well: `runZonedGuarded` wraps all of `main()` (`lib/main.dart:98`, handler `:274-284`),
  `FlutterError.onError` → `recordFlutterFatalError` (`:114-115`),
  `PlatformDispatcher.instance.onError` (`:116-119`), a friendly non-red `ErrorWidget.builder`
  (`:137-166`), and a route-level try/catch with a user-visible recovery page (`:754-780`).
  All correctly gated on `!kIsWeb` / `!kDebugMode`.

- ⚠️ **Degrades gracefully when a dependency is down** — it degrades, but **silently**. There
  is no offline/demo indicator anywhere in `lib/screens` or `lib/widgets`. The one flag that
  exists is dead: `AppProvider._lastUpdatedText` is written at `app_provider.dart:212`/`:232`
  and exposed at `:60`, but **no screen, widget or test reads it**. Three provider error gates
  are unreachable by construction because the demo path nulls the error it would have shown —
  `my_care_provider.dart:96` (`_detailError = null`), `billing_provider.dart:46`,
  `blog_provider.dart:39`. Per the brief this fallback behaviour is *by design*; the objective
  fact to report is that **the user cannot distinguish demo data from live data**, which is a
  resilience gap rather than a demo-mode complaint.
  One case is worse than masking: `my_care_provider.dart:87-97` substitutes
  `DemoData.icuServiceDetail` for **any** deployment id on a non-`ApiException` failure, with
  **no log line at all** — tapping a physio or caretaker card renders the ICU roster.

- ⚠️ **Recovers cleanly from interruption** — foreground-resume refresh exists
  (`my_care_screen.dart:59-62`) but is defeated by `my_care_provider.dart:50`, which sets
  `_lastFetchedAt = DateTime.now()` **while seeding demo data**, so `isStale` (`:35-37`)
  reports false for 60 s off a demo seed and the refresh is skipped.

- ❌ **Data integrity holds under interrupted writes** — the most serious cluster in this audit.
  - **Unverified real payment accepted as success.** `lib/services/payment_service.dart:178-186`
    returns `skippedDemo` whenever `paymentId`, `orderId` **or** `signature` is null, and
    `:163-166` treats `skippedDemo` **identically to `verified`** — it fires the success
    callback. Reachable with a real key: `createOrder` fails → warn-logged → **returns null**
    (`:87-88`) → `openCheckout` omits `order_id` → Razorpay returns success with no signature →
    `skippedDemo` → order marked confirmed and cart cleared (`cart_screen.dart:571-583`). The
    condition is "signature missing", **not** "demo mode". A backend blip during order creation
    becomes an accepted, unverified, real-money payment. The `failed` branch (`:168-172`)
    already has the correct honest behaviour.
  - **Web payments always succeed.** `lib/screens/billing/payment_screen.dart:213-214` routes
    all web payments to `_processWebPayment` (`:266-283`), which sleeps 2 s and sets
    `_paymentSuccess = true` unconditionally. Gated on `kIsWeb` only — **not** on
    `PaymentService.isDemoPayments`.
  - **No write queue exists.** `lib/services/sync_service.dart` is read-only (`:47-64` fetches
    six endpoints, sends nothing); grep for `outbox|pending_writes|writeQueue|enqueue` returns
    zero matches. `OrdersProvider.addOrder` (`orders_provider.dart:59-75`) persists locally and
    makes no API call, yet all four call sites show an unqualified confirmation.
  - **`requestRefill` cannot return false.** `lib/providers/medication_provider.dart:172-178` —
    the catch logs, then execution falls through to `_refillRequestedIds.add(med.id)` and
    `return true`, which sits **outside** the try. A medication refill reports "Requested" while
    nothing was sent, and `_refillRequestedIds` is session-only.
  - **Failed delete pops as success.** `lib/screens/my_care/add_edit_medication_screen.dart:271-273`
    awaits `deleteMedication` and pops `true` without checking the returned bool.
  - **Corrupt persisted orders silently wipe.** `orders_provider.dart:175-206` — a `jsonDecode`
    failure is caught at `:201`, warn-logged, and leaves `_orders` empty; the demo seed at
    `:196-198` sits inside the try above the throw point, so real user orders vanish.

- ⚠️ **Retries with backoff + circuit breakers** — backoff is present and correct in
  `ApiService` (`:55-85`). **No circuit breaker exists anywhere**, and `sync_service.dart:96`
  has no backoff at all. Nothing escalates after N consecutive failures.

### 8. Size & asset hygiene

- ❌ **No unused assets, deps, or dead code shipped** — evidence:
  - **238 unreferenced product images = 40.8 MB** (52 % of `assets/images/products/`), bundled
    because `pubspec.yaml:31` declares the whole `assets/images/products/` **directory** —
    Flutter ships every file in a declared directory regardless of reference.
  - **Four unused dependencies** (zero `package:<name>/` imports in `lib/`): `dio` (superseded
    by `http`), `go_router` (the app uses `onGenerateRoute` in `main.dart:425`), `flutter_svg`,
    `cupertino_icons`.

  **Impact:** removing the 238 dead images cuts ~40.8 MB from the install — roughly a quarter
  to a third of total app size (assets are ~81 MB of an estimated 130–150 MB iOS install;
  PNG/JPG do not compress further inside the IPA zip). **Fix:** delete the 238 unreferenced
  files, then narrow `pubspec.yaml` to enumerate files or keep the directory but prune it in CI
  against `equipment_catalog.json`.

- ⚠️ **Code-splitting / tree-shaking applied where the platform supports it** — Dart AOT
  tree-shakes unreached code, and bundling `Archivo`/`NotoSansDevanagari` locally instead of
  `google_fonts` (`pubspec.yaml:37-45`) is the right call and correctly documented. But
  **assets are never tree-shaken** — directory-level declaration defeats it entirely, which is
  precisely why the 40.8 MB above ships.

- ❌ **No debug-only resources or large sample data in the release artifact** — `DemoData` is
  referenced from **10 files** in `lib/screens` + `lib/providers`, so it is reachable and
  **not** tree-shakeable; `lib/data/demo_data.dart` (749 LOC), `demo_articles.dart` (236),
  `care_packages.dart` (266) all ship. Plus inline mock data in production screens:
  `lib/screens/reports/daily_report_screen.dart:41-87` is a ~47-line hardcoded clinical report
  (fabricated vitals, tasks and medications attributed to a named nurse) compiled into the
  release binary and rendered on API failure.

### 9. Accessibility-driven performance

- ⚠️ **Reduced-motion honoured — verify it's wired everywhere** — good coverage in 11 files
  (`care_pulse_ring.dart:84`, `billing_screen.dart:156`, `order_tracking_screen.dart:120`,
  `payment_screen.dart:256`, `booking_confirmation_screen.dart:126`,
  `care_calendar_screen.dart:251/1080/1602/1709`, `staff_otp_verification_screen.dart:105`,
  `my_care_screen.dart:101`, `medication_schedule_screen.dart:322`,
  `medications_screen.dart:329`, `equipment_tab.dart:267`), and the "no infinite pulses" rule
  holds — the only `.repeat(` in `lib/` is a comment recording its removal
  (`order_tracking_screen.dart:103`). **One gap:** `lib/screens/services/equipment_detail_screen.dart:1690`
  constructs an `AnimationController` with a hardcoded 250 ms and calls `_controller.forward()`
  at `:1708` with **no `disableAnimations` check** — the only one of five
  `AnimationController` sites that is ungated.

- ⚠️ **Largest text / zoom doesn't break layout** — the clamp is correct and deliberate:
  `lib/main.dart:417-420` clamps `textScaler` to 0.85–1.4 (honouring WCAG 1.4.4 up to 1.4×).
  Overflow is guarded across three widths (320/375/414) by
  `test/screens/overflow_smoke_test.dart:102-104`. **Gap:** grep for `textScaler` across
  `test/` returns nothing — the overflow suite runs at **default scale only**, so the 1.4×
  ceiling the app advertises is never actually tested.
  **Fix:** add a 1.4× textScaler axis to the existing overflow sweep.

- ❌ **Reduced-transparency / high-contrast preferences respected** — grep for
  `highContrast|boldText|accessibleNavigation` across `lib/config/theme.dart` and
  `lib/widgets/glass.dart` returns **zero matches**. `GlassAppBar` applies its blur
  unconditionally on every screen. **Impact:** users with Reduce Transparency enabled still pay
  the full `BackdropFilter` cost — the most expensive raster op in the app — on every screen.
  **Fix:** in `glass.dart`, skip the `BackdropFilter` and use an opaque fill when
  `MediaQuery.of(context).highContrast` or the platform reduce-transparency flag is set.

### 10. Measurement & evidence

- **BLOCKED-OWNER — profiler pass on a real target.** Needs an Xcode Instruments run on a
  physical mid-range iPhone (Time Profiler + Allocations + Leaks). Specifically: cold-launch
  trace to confirm the 2 s splash floor and the five-tab `IndexedStack` build cost, and an
  Allocations trace scrolling the equipment catalog to confirm the predicted image-cache churn.
- **BLOCKED-OWNER — startup, interaction and memory measured.** No stored measurements exist in
  the repo (`docs/` has no perf artefact). Firebase Performance **is** initialised
  (`lib/main.dart:122-123`) so cold-start and HTTP traces should already be flowing to the
  console — I would need console access to read them.
- ⚠️ **Crash/error/latency reports monitored** — Crashlytics and Performance are correctly
  initialised and correctly gated (`lib/main.dart:110-131`), which is real credit. But the
  `logger.dart:63` gap means non-fatals never arrive, so what is monitored is fatals only.
- **BLOCKED-OWNER — tested on a low-end target.** Needs a run on an older device / throttled
  network. This matters more than usual here: the image-decode and catalog-parse findings are
  exactly the class of problem that is invisible on a modern dev machine.

---

## Blockers (must fix before release)

1. **Unverified real payments are accepted as successful** — `lib/services/payment_service.dart:163-166`
   + `:178-186` + `:87-88`. `skippedDemo` must not call the success callback; treat a missing
   signature as `failed` whenever the key is not a placeholder.
2. **Web builds always report payment success** — `lib/screens/billing/payment_screen.dart:213-214`,
   `:266-283`. Gate `_processWebPayment` on `PaymentService.isDemoPayments`, not `kIsWeb`.
3. **40.8 MB of unreferenced product images ship in the binary** — 238 files in
   `assets/images/products/`, bundled via the directory declaration at `pubspec.yaml:31`.
4. **Full-resolution image decode on the catalog hot path** — `lib/widgets/common_widgets.dart:129-140`.
   Up to 24 MB decoded per tile against a ~1 MB need; no `cacheWidth`, no `ImageCache` tuning.
5. **All non-fatal errors are invisible in production** — `lib/utils/logger.dart:63`. Every
   fallback in the app is unobservable in release, which makes findings 1–2 undetectable in
   the field.

## High

- **No request-level timeout or cancellation in `ApiService`** — `lib/services/api_service.dart:55-85`,
  `:102-136`; 20 of 25 call sites have no caller timeout either. Abandoned futures leave sockets running.
- **`ApiService` is not a singleton — 17 unclosed `http.Client`s** (`api_service.dart:41`, no
  `dispose`). Defeats connection pooling; ad-hoc instances also never receive the auth token
  (`_authToken` is per-instance, set only via `AuthProvider` on the `main.dart:174` instance),
  so against a real backend all 17 call sites would 401 and fall back to demo data permanently.
- **862 KB catalog decoded on the UI isolate at 7 sites with no shared cache** — see §4;
  no `compute()` anywhere in `lib/`.
- **`requestRefill` cannot return false** — `lib/providers/medication_provider.dart:172-178`.
  Patient-safety-adjacent: the UI says the pharmacy was notified when it was not.
- **`CacheService` never evicts** — `lib/services/cache_service.dart:31`; unbounded
  `SharedPreferences` growth.
- **Silent wrong-record substitution** — `lib/providers/my_care_provider.dart:87-97` serves the
  ICU deployment for any id, with no log.

## Medium / Low

- Eager `ListView` over unbounded data — `universal_search_screen.dart:300`,
  `diagnostics_tab.dart:39`, `consultations_tab.dart:41`, `manpower_tab.dart:48`.
- No search debounce; `_results` recomputed in `build` — `universal_search_screen.dart:261`, `:277`.
- Undisposed `TextEditingController` — `lib/screens/documents/document_repository_screen.dart:47`.
- Global toast timer not cancelled on route teardown — `lib/widgets/common_widgets.dart:16-17`, `:92`.
- Unguarded `setState` after `await` — `daily_report_screen.dart:34`, `:88`;
  `notifications_screen.dart:34`.
- 2 s hard-coded splash delay — `lib/screens/splash_screen.dart:15`.
- Five root tabs built eagerly in `IndexedStack` — `lib/screens/main_shell.dart:36-42`, `:57-60`.
- Four unused dependencies — `dio`, `go_router`, `flutter_svg`, `cupertino_icons`.
- `sync_service` fixed 5-min retry, no backoff or circuit breaker — `lib/services/sync_service.dart:96`.
- Reduced-motion gap — `lib/screens/services/equipment_detail_screen.dart:1690`, `:1708`.
- No high-contrast / reduce-transparency handling; `GlassAppBar` blurs unconditionally.
- Overflow suite never exercises the 1.4× textScaler ceiling it clamps to.
- Large hardcoded sample data in a production screen — `daily_report_screen.dart:41-87`.

## BLOCKED-OWNER

| Item | What I need |
|---|---|
| §10 profiler pass (CPU/memory/leaks) | Xcode Instruments run on a physical mid-range iPhone — Time Profiler on cold launch, Allocations while scrolling the equipment catalog |
| §10 startup/interaction/memory measured | Firebase Performance console access — cold-start and HTTP traces are already being collected (`lib/main.dart:122-123`) |
| §10 low-end target testing | A run on an older device / throttled network |
| §3 memory returns to baseline | Allocations trace across launch → full catalog scroll → back out |
| §2 60fps confirmation | On-device scroll with the performance overlay / DevTools timeline |

---

## Note on owner-decision items

Per the brief I did not grade the white-on-orange contrast, manpower pricing, or the fixed
orange bottom nav as failures. The only performance-relevant consequence of those decisions
I found is the unconditional `BackdropFilter` in `GlassAppBar` (§9), which is a
reduce-transparency issue rather than a colour-contrast one. The expected demo-mode
failed-fetch log at startup was **not** counted as a defect; what I did count is that the
fallback is invisible to the user and unobservable in production telemetry.
