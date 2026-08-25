# Performance & Reliability Checklist (App-Agnostic) — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Method:** static only — `du`, `python3` measurement, `rg`/`grep`, code reading.
`flutter analyze` clean, design gate passing, 1,797 tests passing per the caller; no
`flutter test` / `build` / `clean` run by me (central suite owns those).

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **Unverified real payment accepted as success** (`payment_service.dart`) | ✅ **GENUINELY FIXED** — verified line by line | `payment_service.dart:163-183` — `skippedDemo` now branches on `isDemoPayments`; the real-key arm logs `Log.error` and calls `_onFailureCallback`. `_verifyPaymentOnBackend:196-202` unchanged but its output is no longer trusted. |
| **Web always reports payment success** (`payment_screen.dart`) | ✅ **GENUINELY FIXED** | `payment_screen.dart:318-332` — `_processWebPayment` gates on `!PaymentService.isDemoPayments` and fails closed with an honest message. Gate is `isDemoPayments`, not `kIsWeb`. |
| `createOrder` never called before real checkout | ✅ **FIXED on the PaymentScreen path only** | `payment_screen.dart:226-253` — calls `createOrder`, and `orderId == null` fails closed before `openCheckout`. **But see B-1: the second payment entry point was not fixed.** |
| **40.8 MB of dead product images** | ❌ **UNCHANGED** — re-measured, still there | 238 unreferenced files, **40.3 MiB**, of 439 files / 77.4 MiB. `pubspec.yaml:85` still declares the whole directory. |
| **No `cacheWidth` anywhere — full-res decode on catalog hot path** | ❌ **UNCHANGED** | `grep -rn "cacheWidth\|cacheHeight\|ResizeImage\|memCacheWidth\|imageCache" lib/` → **0 matches**. |
| **`logger.dart:63` unwired TODO — no remote sink for warn/error** | ❌ **UNCHANGED** | `lib/utils/logger.dart:63-65` — TODO verbatim; `_log` still ends at `debugPrint`. |
| **`ApiService` not a singleton, no timeout/cancellation, 17 leaked clients** | ❌ **UNCHANGED, now 18 sites** | `api_service.dart:41` `_client = client ?? http.Client()`; no `factory`/`static instance`/`close()`. `grep -c "ApiService()" lib/` → **18** (was 17). |
| 862 KB catalog decoded on UI isolate at 7 sites | ❌ **UNCHANGED** | Same 7 `rootBundle.loadString('assets/equipment_catalog.json')` sites; `grep "compute(\|Isolate\." lib/` → **0**. |
| `requestRefill` cannot return false | ❌ **UNCHANGED** | `medication_provider.dart:165-180` — `return true` still outside the `try`. |
| `CacheService` never evicts | ❌ **UNCHANGED** | `cache_service.dart:31` — expired entries `return null`, never removed. |
| Corrupt persisted orders silently wipe | ❌ **UNCHANGED** | `orders_provider.dart:196-206` — demo seed still inside the `try`, above the throw point. |
| Undisposed `TextEditingController` | ❌ **UNCHANGED** | `document_repository_screen.dart:47`; still no `dispose()` in the file. |
| 2 s hard-coded splash delay | ❌ **UNCHANGED** | `splash_screen.dart:15`. |
| Reduced-motion gap on the one ungated controller | ❌ **UNCHANGED** | `equipment_detail_screen.dart:1690`, `:1708-1712`. |
| No high-contrast / reduce-transparency handling | ❌ **UNCHANGED** | `glass.dart:156` `BackdropFilter` unconditional; 0 matches for `highContrast`. |
| Overflow suite never exercises 1.4× textScaler | ❌ **UNCHANGED** | `grep -rn textScaler test/` → **0**. |
| Four unused deps (`dio`, `go_router`, `flutter_svg`, `cupertino_icons`) | ❌ **UNCHANGED** | 0 `package:<name>/` imports in `lib/` for all four. |
| Silent demo fallback invisible to the user | ⚠️ **PARTIALLY FIXED** | New `DemoMode` + banner (`demo_mode.dart`, `main_shell.dart:64`) — real progress, but 3 fallback paths don't set the flag and 1 provider clears it for everyone. See §7. |

**New in round 2 (none of these existed at `803124d`):**

| New code | Verdict |
|---|---|
| `store_migrator.dart` awaited in `main()` | ⚠️ cheap, but can throw and abort startup — §1 |
| `_DemoDataBanner` in `main_shell.dart` | ✅ rebuild scope is correctly narrow — §2 |
| `session_scope.dart` | ⚠️ bounded, but amplified by the IndexedStack — §6 |
| `main.dart:395` root `watch<AppProvider>()` | ⚠️ MaterialApp rebuilt on every dashboard tick — §2 |
| `delete_account_screen.dart` | ✅ controller disposed, `mounted` guarded — no perf/reliability defect found |

**Nothing regressed** in the measurable sense: no round-1 grade got worse. One round-1
finding is *larger* than reported (`ApiService()` sites 17 → 18, from the new
`billing_screen.dart:304` construction).

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED |
|---|---|---|---|---|---|
| 1. Startup / first response | 1 | 1 | 1 | 0 | 0 |
| 2. Rendering & interaction | 0 | 2 | 2 | 0 | 0 |
| 3. Memory | 0 | 0 | 3 | 0 | 1 |
| 4. Battery, network & resource | 0 | 3 | 1 | 0 | 0 |
| 5. Data & query performance | 0 | 2 | 1 | 1 | 0 |
| 6. Concurrency & responsiveness | 0 | 2 | 2 | 0 | 0 |
| 7. Reliability & resilience | 1 | 3 | 2 | 0 | 0 |
| 8. Size & asset hygiene | 0 | 1 | 2 | 0 | 0 |
| 9. Accessibility-driven perf | 0 | 2 | 1 | 0 | 0 |
| 10. Measurement & evidence | 0 | 1 | 0 | 0 | 3 |
| **TOTAL (39 items)** | **2** | **17** | **15** | **1** | **4** |

Round 1 was ✅2 / ⚠️18 / ❌14 / N/A1 / BLOCKED4. The one-item shift from ⚠️ to ❌ is §3
"no leaks" — the new `billing_screen.dart:304` `PaymentService()` construction adds an
18th unclosed client and a leak window, tipping an already-weak partial into a fail.

---

## Measured facts (round 2, re-measured — not carried over)

```
assets/                       81 MB
assets/images/products/       77.4 MiB across 439 files
  referenced (unique):        201 files = 37.1 MiB
  UNREFERENCED:               238 files = 40.3 MiB   <-- dead weight, unchanged
  referenced-but-missing:       0 files
lib/  →  cacheWidth|cacheHeight|ResizeImage|memCacheWidth|imageCache : 0 matches
lib/  →  compute( | Isolate.                                        : 0 matches
lib/  →  ApiService()                                               : 18 sites
test/ →  textScaler                                                 : 0 matches
```

*Method note:* round 1 reported "40.8 MB"; my round-1 extraction regex truncated at `)`,
which mis-scored the 41 catalog filenames containing parentheses (e.g.
`0033_BIPAP_Mask_(L).png`). Corrected regex (`assets/images/products/([^"']+)`) gives
**238 files / 40.3 MiB unreferenced and 0 referenced-but-missing** — same file count as
round 1, so the finding is confirmed, not revised. No files were added or deleted.

---

## Findings

### 1. Startup / first response

- ❌ **Time-to-interactive still floored at 2 s** — `splash_screen.dart:15`,
  `Future.delayed(const Duration(seconds: 2), …)` then `pushReplacementNamed('/home')`.
  Unchanged from round 1. **Fix:** race the delay against real readiness.

- ⚠️ **Heavy work blocking startup — one item added, and it can abort the launch.**
  `main.dart:174` now `await StoreMigrator.run()` before `runApp` (`:191`).
  **Measured cost is small:** `_migrations` is empty (`store_migrator.dart:57-58`),
  `currentVersion` is 1, so the whole run is one `SharedPreferences.getInstance()`, one
  `getInt`, and at most one `setInt` (`:64-72`). On a fresh install that is a plist load
  the app performs anyway — the migrator does not add I/O so much as **serialise** it
  ahead of `runApp` instead of letting providers do it lazily. Call it single-digit ms
  on a warm store, dominated by the first `getInstance()` platform-channel round trip.
  **The real defect is the failure mode.** The doc comment at `:61-62` says *"Never
  throws: a migration failure must not stop the app from starting"*, but the code does
  not honour that: `SharedPreferences.getInstance()` (`:64`), `prefs.setInt` (`:71`) and
  `prefs.setInt` (`:117`) are **outside any try/catch**. Only the migration *step* is
  guarded (`:106-114`). If the platform channel fails — corrupt plist, low storage, the
  documented iOS `getInstance` failure modes — `run()` throws, `runApp` at `:191` is
  never reached, `runZonedGuarded` (`:100`) swallows it to Crashlytics, and the user gets
  a **permanently black screen with no error UI**, because `ErrorWidget.builder` only
  helps once a widget tree exists. **Fix:** wrap the body of `run()` in try/catch and
  return on failure — the tolerant readers already handle an unmigrated store.
  Also still blocking, unchanged from round 1: `Firebase.initializeApp` (`:103`), four
  awaited Crashlytics/Performance setters (`:122-132`), `MedicationReminderService().init()`
  (`:178`), and the five-screen eager `IndexedStack` (`main_shell.dart:37-43`, `:66-69`).

- ✅ **First view shows content fast** — `splash_screen.dart:22-56` paints with zero async
  dependencies; `equipment_tab.dart:204-235` has a real shimmer skeleton.

### 2. Rendering & interaction

- ⚠️ **Smooth scroll/animation (60fps)** — BLOCKED for the measurement; static risk
  unchanged and concrete (full-res decode below, `ImageCache` still untuned).
  **New in round 2, and worth naming:** `main.dart:395` does
  `final appProvider = context.watch<AppProvider>();` in `HousepitalApp.build` **solely to
  read `appProvider.locale` at `:405`**. Every `AppProvider.notifyListeners()` therefore
  rebuilds the `MaterialApp` element and its `Theme`/`Localizations`/`MediaQuery`/`Navigator`
  scaffolding. That is **≥6 root rebuilds on a cold start** — `loadPatients` notifies twice
  (`app_provider.dart:139`, `:149`), `loadDashboard` three times (`:212`, `:218`, `:249`),
  `switchPatient` once (`:165`) — plus one per dashboard refresh thereafter.
  Element reuse keeps the mounted route contents from rebuilding, so this is **not** a
  whole-tree repaint; it is avoidable root churn during the most jank-sensitive window.
  **Fix:** `context.select<AppProvider, Locale>((p) => p.locale)` — one line, eliminates it.

- ⚠️ **Lazy loading / virtualization** — unchanged from round 1. Correctly virtualized:
  `equipment_tab.dart:212`/`:400`, `lab_tests_tab.dart`, `packages_tab.dart`,
  `widgets/paginated_list.dart` (4 history screens). Still eager over unbounded data:
  `universal_search_screen.dart:300` (`ListView(children: …)` over a ~550-item corpus),
  `diagnostics_tab.dart:39`/`:56`, `consultations_tab.dart:41`, `manpower_tab.dart:48`.

- ❌ **Images sized/compressed to display size** — unchanged. `common_widgets.dart:129-140`,
  `Image.asset` with no `cacheWidth`, `CachedNetworkImage` with no `memCacheWidth`;
  repo-wide grep returns **zero**. Grid cards are ~180 pt (`equipment_tab.dart:394-397`)
  → ~492 px at 3× → ~0.97 MB needed. Largest live asset
  `0009_Aircurve_10_Vauto_Apac_Tri_4g.png` is 5.46 MB / 2000×2000 → **16.0 MB decoded**,
  ~17× the pixel budget. **This remains the single largest runtime memory lever.**

- ❌ **No expensive work in render/row builders** — unchanged.
  `universal_search_screen.dart:277` `onChanged: (v) => setState(() => _query = v.trim())`
  with no debounce; `:261` `final results = _results;` invokes the getter at `:159` that
  rescans the whole corpus **inside `build`**.

- ✅ *(credit, not a checklist row)* **The new sample-data banner does NOT cause a
  per-frame or per-tab rebuild storm** — I checked this specifically. The
  `ValueListenableBuilder` is scoped **inside** `_DemoDataBanner`
  (`main_shell.dart:137-139`), which is itself a `const` widget at `:64`. A flag flip
  therefore rebuilds the banner subtree only; `IndexedStack` at `:66` and the five tab
  screens are untouched, and `_screens` (`:37-43`) is a `final` field built once. This is
  the correct implementation and it should stay this way.
  Two secondary costs are real but small: (a) the flip false→true changes the `Column`'s
  layout, so the `Expanded(IndexedStack)` gets shorter constraints and **all five tabs
  relayout once** — and because `markServingDemoData` fires from provider loads
  immediately after first frame, that relayout lands in the launch window; (b) the banner's
  `SafeArea(bottom: false)` at `:143` consumes top padding for *itself* only — the sibling
  `IndexedStack` still sees the full `MediaQuery.padding.top`, so every glass tab adds a
  second status-bar inset *below* the banner. Cosmetic, but visible.

### 3. Memory

- ❌ **No leaks / retain cycles** — downgraded from ⚠️; all three round-1 defects survive
  and one grew.
  - **18 unclosed HTTP clients** (was 17). `ApiService` still has no `factory`, no
    `static instance`, no `close()`/`dispose()`; `_client = client ?? http.Client()` at
    `api_service.dart:41`. New 18th site: `billing_screen.dart:304`
    `final paymentService = PaymentService();` inside an `onPressed`, which constructs an
    `ApiService()` via `payment_service.dart:58` — **a fresh client per tap of Pay Now.**
    That `PaymentService` is disposed only on the success/failure callbacks
    (`billing_screen.dart:309`, `:320`); if the user backgrounds the app or navigates away
    with the Razorpay sheet open, neither fires and the service, its Razorpay channel and
    its client leak with closures over `context`.
  - `document_repository_screen.dart:47` — `TextEditingController` still State-owned and
    **never disposed**; the file still contains no `dispose()`.
  - `common_widgets.dart:16-17` — module-level `OverlayEntry? _activeToast` / `Timer?
    _toastTimer` still cancelled only on tap, timer fire, or replacement — never on route
    teardown.

  Still correct and still worth credit: every periodic `Timer` is cancelled
  (`otp_screen.dart:77`, `home_screen.dart:88`, `auth_provider.dart:234`,
  `sync_service.dart:111`), and all four `StreamSubscription`s are cancelled
  (`firebase_service.dart:16`, `chat_screen.dart:40`,
  `staff_otp_verification_screen.dart:44`, `order_tracking_screen.dart:37`).

- ❌ **Large media streamed or bounded** — unchanged. No `cacheWidth`, no `ImageCache`
  tuning anywhere. Nothing bounds decoded image memory.

- ❌ **Caches have a size bound and evict** — unchanged. `cache_service.dart:30-31`,
  `_isExpired` → `return null` **without** `prefs.remove`; only the blanket `clear()`
  (`:37-43`) or explicit `remove(key)` (`:45-48`) deletes anything. Backed by
  `SharedPreferences`, which iOS loads wholly into memory, so the store grows monotonically
  for the life of the install. **Fix is two lines:** `await remove(key)` inside the
  `_isExpired` branch, plus an entry-count cap in `cache()`.

- **BLOCKED-OWNER** — "Memory returns to baseline after heavy flows." Needs an Instruments
  Allocations run: launch → scroll the full equipment catalog → back out.

### 4. Battery, network & resource use

- ⚠️ **No busy-wait loops / runaway timers** — unchanged. `sync_service.dart:96`
  `Timer.periodic` at a fixed 5-minute interval, no backoff, no escalation; both call sites
  swallow the outcome (`:92-94`, `:97-99`).

- ⚠️ **Background work registered correctly** — unchanged. FCM deferred to
  `addPostFrameCallback` (`main.dart:321-324`); cold-start notifications drained
  (`:384-390`). Nothing bounds how long a detached request runs.

- ⚠️ **Batched/coalesced; retried with backoff** — backoff is real and good
  (`api_service.dart:55-85`: 2 retries at `_retryDelay * attempt` for `SocketException`,
  `TimeoutException`, 5xx, with a separate one-shot 401 recovery). Coalescing is still
  absent: the **862 KB** `equipment_catalog.json` is loaded and decoded independently at
  **seven** sites with no shared memo — `universal_search_screen.dart:149`,
  `package_detail_screen.dart:35`, `assistant_local_actions.dart:39`,
  `doctor_advice_card.dart:55`, `equipment_detail_screen.dart:138`, `equipment_tab.dart:72`,
  `medications_screen.dart:354`. Equipment → tap an item still re-parses the whole file.

- ❌ **Requests cancelled when no longer needed** — unchanged.
  `grep "CancelToken\|abort\|_client.close" lib/services/` → nothing. `ApiService` sets
  **no request timeout**; timeouts exist only at 9 caller sites. The `on TimeoutException`
  branch at `api_service.dart:77` is still effectively dead code — that exception is thrown
  by the caller's wrapper, outside `_withRetry`.

### 5. Data & query performance

- **N/A — hot queries / indexes.** No local DB (no sqflite/drift/Isar in `pubspec.yaml`);
  persistence is `SharedPreferences` only. Firestore index config is server-side.

- ⚠️ **N+1 avoided** — no network N+1; the 7-site catalog re-parse is the client-side
  equivalent.

- ⚠️ **Large result sets paginated; query timeouts set** — `PaginatedListView` used
  correctly in four history screens at `pageSize: 20`; timeouts still cover a minority of
  call sites.

- ❌ **Connection pooling / reads off the UI thread** — unchanged and now worse by one.
  (a) 18 independent `http.Client()`s, each with its own pool, none closed. (b)
  `grep "compute(\|Isolate\." lib/` → **0 matches**, while 862 KB `jsonDecode` runs on the
  main isolate at 7 sites and PDF generation (`invoice_pdf_service.dart:96`,
  `handover_report_service.dart:97`) is synchronous on the UI isolate.

### 6. Concurrency & responsiveness

- ❌ **No blocking calls on the main/UI thread** — unchanged (see §5).

- ❌ **Long operations cancellable and cancelled on navigation/teardown** — unchanged; no
  cancellation primitive exists.

- ⚠️ **Shared mutable state protected** — the toast globals
  (`common_widgets.dart:16-17`) are unchanged. **New shared global in round 2:**
  `DemoMode.isServingDemoData` (`demo_mode.dart:16-17`) is a process-wide `ValueNotifier`
  written by five providers and **reset by one** — see §7 for why that ownership split is
  a correctness bug, not just a style one.

- ⚠️ **State captured at invocation, not execution** — unchanged. 114 `mounted` guards
  across 123 `await`s plus 18 `context.mounted` guards is good coverage; the two confirmed
  gaps remain: `daily_report_screen.dart:34` and `:88`, `notifications_screen.dart:34`.

- ✅ *(credit, not a checklist row)* **`SessionScope` does not cause a rebuild storm —
  I counted it.** `session_scope.dart:28-36` fires five `notifyListeners()` in sequence
  (MyCare, Medication, Billing, Orders, Cart), and `home_screen.dart:1771-1772` follows
  them with `app.switchPatient`, which notifies again (`app_provider.dart:165`) and calls
  `loadDashboard` (two more synchronous notifications at `:212`/`:218`) — **8 synchronous
  notifications from one tap.** They do **not** produce 8 frames: `notifyListeners` only
  calls `markNeedsBuild`, and Flutter coalesces every dirtied element into the *next*
  frame, so each listening element rebuilds exactly once. The bounded cost is the union of
  listeners:

  | Provider | Listening sites | Mounted during a patient switch |
  |---|---|---|
  | `AppProvider` | 13 | `main.dart:395` (root), `home_screen:97`, `my_care_screen:79`, `billing_screen:134`, `settings_screen:83`, `medications_screen:48` |
  | `MedicationProvider` | 8 | `home_screen:1659`, `my_care_screen:122` |
  | `CartProvider` | 6 | `home_screen:463` + `glass.dart:106` × every mounted `GlassAppBar` |
  | `MyCareProvider` | 3 | `my_care_screen:78` |
  | `OrdersProvider` | 4 | `billing_screen:133` |
  | `BillingProvider` | **0** | — |

  So: **one frame, ~15–20 elements rebuilt.** That is acceptable. Two notes worth acting on:
  (a) `BillingProvider.clearPatientScopedData` (`billing_provider.dart:68-74`) calls
  `notifyListeners()` to **zero listeners** — the provider is wired into the tree
  (`main.dart:202-204`) but nothing watches it, confirming round 1's note that
  `BillingScreen` still reads off `AppProvider`. Clearing it is dead work today, and the
  PHI guarantee it is supposed to provide is not actually observable by any UI.
  (b) The count is **amplified by the eager `IndexedStack`** (`main_shell.dart:66-69`):
  because all five tabs stay mounted, listeners in four tabs the user is not looking at
  rebuild on every patient switch. Fixing the lazy-tab finding in §1 shrinks this too.

### 7. Reliability & resilience

- ❌ **Crash/error-free target defined and monitored** — unchanged, verbatim.
  `logger.dart:63-65` still reads
  `// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`, and
  `_log` (`:52-67`) still ends at `debugPrint`. Crashlytics receives **fatals only**; every
  `Log.warn`/`Log.error` — ~45 sites, including the new
  `payment_service.dart:174` "Refusing to confirm" and the new
  `store_migrator.dart:109` migration-failure line — reaches **no remote sink in release**.
  No error-rate or crash-free-sessions target exists in the repo.
  This is the finding that makes every other finding undetectable in the field, and it is
  still a one-line change at a documented chokepoint.

- ✅ **No uncaught exceptions on user paths; global error boundary exists** — still done
  well. `runZonedGuarded` wraps `main()` (`main.dart:100`), `FlutterError.onError` →
  `recordFlutterFatalError` (`:116-117`), `PlatformDispatcher.instance.onError` (`:118-121`),
  friendly `ErrorWidget.builder` (`:139-168`), route-level try/catch (`:434`). Correctly
  gated on `!kIsWeb` / `!kDebugMode`. **Caveat:** none of it covers the pre-`runApp` window,
  which is exactly where the new `StoreMigrator.run()` throw lands (§1).

- ⚠️ **Degrades gracefully when a dependency is down** — **materially improved, and
  incomplete.** The `DemoMode` flag + persistent banner (`demo_mode.dart`,
  `main_shell.dart:64`, `:132-170`) is the right shape: non-dismissible, states the
  consequence in plain language, and correctly scoped for rebuilds (§2). Six fallback
  paths now set it: `app_provider.dart:260`, `my_care_provider.dart:50`/`:98`,
  `medication_provider.dart:191`/`:236`, `billing_provider.dart:43`,
  `orders_provider.dart:199`. **Four gaps remain:**
  1. **One provider's success clears everyone's warning.** `app_provider.dart:247` calls
     `DemoMode.reset()` when the *dashboard* fetch succeeds. The notifier is global, so a
     successful dashboard takes the banner down while `MedicationProvider`,
     `OrdersProvider`, `MyCareProvider` and `BillingProvider` are still serving
     `DemoData`. Partial connectivity is the common real-world case, and it produces the
     exact failure the banner exists to prevent: sample medications shown with no warning.
     **Fix:** make it a per-source set (`Set<String> _demoSources`) and show the banner
     while any source is demo.
  2. **`blog_provider.dart:38` and `:68`** fall back to `DemoData.articles` with **no**
     `markServingDemoData()` call.
  3. **`app_provider.dart:136-140`** seeds `DemoData.patient` as the current patient
     without marking — the sample *identity* itself is unannounced.
  4. **`handover_report_service.dart:101-108`** builds the doctor-handover PDF entirely
     from `DemoData` (patient, medical history, medications, vitals, report, services,
     staff on duty, appointments) with no demo marking anywhere. This is the role-gated
     clinical export; it leaves the phone as a document with no indication it is sample
     data. Worth escalating beyond this checklist.

  Also unchanged: `my_care_provider.dart:88-99` still substitutes `DemoData.icuServiceDetail`
  for **any** deployment id on a non-`ApiException` failure — it now marks demo mode
  (`:98`), which is an improvement, but the user still sees the ICU roster after tapping a
  physio card.

- ⚠️ **Recovers cleanly from interruption** — unchanged. `my_care_provider.dart:52` still
  sets `_lastFetchedAt = DateTime.now()` **while seeding demo data**, so `isStale`
  (`:36-38`) reports false for 60 s off a demo seed and the foreground-resume refresh at
  `my_care_screen.dart:59-62` is skipped.

- ❌ **Data integrity holds under interrupted writes** — the two payment blockers are
  genuinely fixed (see "Changed since round 1"), but the cluster is not closed:
  - **B-1 · A second payment entry point still opens real checkout with no order.**
    `billing_screen.dart:303-336` — "Pay Now" on the outstanding-balance card constructs
    `PaymentService()` and calls `openCheckout(amount: totalDue * 100, …)` **without ever
    calling `createOrder`**. This path was not touched by the round-1 fix. With a real key:
    `isDemoPayments` is false so `payment_service.dart:113` does not simulate;
    `openCheckout` builds options at `:124-140` where `'order_id': ?orderId` **omits the
    key entirely** because `orderId` is null; real Razorpay checkout opens and can capture
    real money; the success response carries no signature; `_verifyPaymentOnBackend:196`
    returns `skippedDemo`; `_handleSuccess:171` now correctly refuses — and calls
    `_onFailureCallback` with *"Payment under verification — we'll confirm in 24 hours."*
    **Net effect: the patient is charged and told the payment failed, with no order record
    and no recoverable reference.** The round-1 fix converted "unverified payment silently
    accepted" into "real payment taken and disowned" on this path. It is a smaller loss
    than round 1 but it is still a money-losing bug, and it is now the headline.
    **Fix:** apply the same guard `payment_screen.dart:226-253` uses — call `createOrder`
    and fail closed on null — or route this button through `PaymentScreen`.
  - **No write queue exists.** `sync_service.dart` is still read-only (`:47-64` fetches six
    endpoints, sends nothing); `grep "outbox\|pending_writes\|writeQueue\|enqueue"` → 0.
    `OrdersProvider.addOrder` persists locally and makes no API call, yet all four call
    sites show an unqualified confirmation.
  - **`requestRefill` cannot return false** — `medication_provider.dart:165-180`. The catch
    logs, then `_refillRequestedIds.add(med.id)` and `return true` execute **outside** the
    try. Patient-safety-adjacent: the UI says the pharmacy was notified when it was not.
  - **Failed delete pops as success** — `add_edit_medication_screen.dart:268-272` awaits
    `deleteMedication` and pops `true` without checking the returned bool.
  - **Corrupt persisted orders silently wipe** — `orders_provider.dart:196-206`. The demo
    seed sits inside the `try` above the throw point, so a `jsonDecode` failure caught at
    `:203` leaves `_orders` empty and real user orders vanish.

- ⚠️ **Retries with backoff + circuit breakers** — backoff correct in `ApiService:55-85`;
  **no circuit breaker anywhere**; `sync_service.dart:96` has no backoff at all.

### 8. Size & asset hygiene

- ❌ **No unused assets, deps, or dead code shipped** — unchanged, re-measured.
  - **238 unreferenced product images = 40.3 MiB** (54 % of `assets/images/products/` by
    size), bundled because `pubspec.yaml:85` declares the whole
    `assets/images/products/` **directory** — Flutter ships every file in a declared
    directory regardless of reference. Two of the five largest files on disk are dead:
    `0094_ECG_Electrodes.png` (3.55 MB) and `0360_Inj_Ondomed.jpg` (1.71 MB).
  - **Four unused dependencies**, all still at 0 imports in `lib/`: `dio`, `go_router`,
    `flutter_svg`, `cupertino_icons`.

  **This is the largest single win available and it is a pure delete** — ~40 MiB off the
  install, roughly a quarter to a third of total app size, with no code change and no
  behavioural risk (`referenced-but-missing` is **0**, so nothing breaks). **Fix:** delete
  the 238 files, then either enumerate assets in `pubspec.yaml` or add a CI check that
  prunes `assets/images/products/` against `equipment_catalog.json`.

- ⚠️ **Code-splitting / tree-shaking** — Dart AOT tree-shakes unreached code, and bundling
  `Archivo`/`NotoSansDevanagari` locally instead of `google_fonts` (`pubspec.yaml:94-98`)
  is the right call. **Assets are never tree-shaken** — directory-level declaration defeats
  it, which is precisely why the 40.3 MiB above ships.

- ❌ **No debug-only resources or large sample data in the release artifact** — unchanged,
  and the round-2 work slightly widened it. `DemoData` is referenced from providers,
  screens **and now `handover_report_service.dart:101-108`**, so it is reachable and not
  tree-shakeable; `demo_data.dart` (749 LOC), `demo_articles.dart` (236),
  `care_packages.dart` (266) all ship, plus the new `demo_mode.dart`. Inline mock data
  survives in a production screen: `daily_report_screen.dart:41-87` is a ~47-line
  hardcoded clinical report (fabricated vitals, tasks and medications attributed to a named
  nurse) compiled into the release binary and rendered on API failure.

### 9. Accessibility-driven performance

- ⚠️ **Reduced-motion honoured** — unchanged. Good coverage in 11 files; the "no infinite
  pulses" rule holds. **Same one gap:** `equipment_detail_screen.dart:1689-1693` constructs
  an `AnimationController` with a hardcoded 250 ms and `_toggle` at `:1704-1712` calls
  `forward()`/`reverse()` with **no `disableAnimations` check** — still the only ungated
  `AnimationController` of five.

- ⚠️ **Largest text / zoom doesn't break layout** — the clamp is correct and deliberate
  (`main.dart:421-432`, 0.85–1.4, honouring WCAG 1.4.4). Overflow guarded across
  320/375/414 by `test/screens/overflow_smoke_test.dart`. **Gap unchanged:**
  `grep -rn textScaler test/` → **0 matches**, so the overflow suite runs at default scale
  only and the 1.4× ceiling the app advertises is never tested.

- ❌ **Reduced-transparency / high-contrast respected** — unchanged.
  `grep "highContrast\|boldText\|accessibleNavigation"` across `glass.dart` and `theme.dart`
  → **0 matches**; `glass.dart:156` applies its `BackdropFilter` unconditionally on every
  screen. Users with Reduce Transparency enabled still pay the full blur cost — the most
  expensive raster op in the app — on every screen, and the new banner adds a sixth
  translucent surface above it.

### 10. Measurement & evidence

- **BLOCKED-OWNER — profiler pass on a real target.** Xcode Instruments on a physical
  mid-range iPhone: Time Profiler on cold launch (confirm the 2 s splash floor, the
  five-tab `IndexedStack` build, and the `StoreMigrator` + `getInstance` cost), Allocations
  while scrolling the equipment catalog (confirm image-cache churn).
- **BLOCKED-OWNER — startup/interaction/memory measured.** No perf artefact exists in
  `docs/`. Firebase Performance **is** initialised (`main.dart:124-125`), so cold-start and
  HTTP traces should already be flowing — needs console access to read.
- ⚠️ **Crash/error/latency reports monitored** — Crashlytics and Performance correctly
  initialised and correctly gated (`main.dart:112-134`), which is real credit. The
  `logger.dart:63` gap means non-fatals never arrive, so what is monitored is fatals only.
- **BLOCKED-OWNER — tested on a low-end target.** Matters more than usual here: the
  image-decode and catalog-parse findings are exactly the class of problem invisible on a
  modern dev machine.

---

## Blockers (must fix before release)

1. **B-1 · `billing_screen.dart:303-336` opens real Razorpay checkout with no backend
   order.** The Pay Now button on the outstanding-balance card never calls `createOrder`,
   so with a real key the patient can be charged and then shown "Payment under
   verification", with no order record. This is the payment path the round-1 fix missed.
2. **40.3 MiB of unreferenced product images ship in the binary** — 238 files, bundled via
   the directory declaration at `pubspec.yaml:85`. Pure delete, zero risk, largest single
   win available. Unchanged from round 1.
3. **Full-resolution image decode on the catalog hot path** — `common_widgets.dart:129-140`.
   Up to 16 MB decoded per tile against a ~1 MB need; no `cacheWidth`, no `ImageCache`
   tuning. Unchanged from round 1.
4. **All non-fatal errors invisible in production** — `logger.dart:63`. Every fallback,
   including the new payment refusal and migration failure, is unobservable in release,
   which makes blockers 1 and 5 undetectable in the field. Unchanged from round 1.
5. **`StoreMigrator.run()` can throw and prevent `runApp` from ever being called** —
   `store_migrator.dart:64`/`:71`/`:117` are outside any try/catch despite the "never
   throws" contract at `:61`, and `main.dart:174` awaits it before `runApp` at `:191`.
   Failure mode is a permanent black screen. **New in round 2.**

## High

- **`DemoMode.reset()` is global but called by one provider** — `app_provider.dart:247`.
  A successful dashboard fetch takes the sample-data banner down while four other providers
  are still serving `DemoData`. **New in round 2**, and it undermines the round-2 fix it
  belongs to.
- **Three demo fallbacks never set the flag** — `blog_provider.dart:38`/`:68`,
  `app_provider.dart:136-140`, `handover_report_service.dart:101-108`. The last is the
  role-gated clinical handover PDF, built entirely from `DemoData` and exported unmarked.
- **No request-level timeout or cancellation in `ApiService`** — `api_service.dart:55-85`,
  `:102-136`. Abandoned futures leave sockets running.
- **`ApiService` is not a singleton — 18 unclosed `http.Client`s** (`api_service.dart:41`,
  no `close()`). Defeats pooling; ad-hoc instances also never receive the auth token, so
  against a real backend those call sites would 401 and fall back to demo data permanently.
- **862 KB catalog decoded on the UI isolate at 7 sites with no shared cache** — no
  `compute()` anywhere in `lib/`.
- **`requestRefill` cannot return false** — `medication_provider.dart:165-180`.
- **`CacheService` never evicts** — `cache_service.dart:31`; unbounded growth.
- **Silent wrong-record substitution** — `my_care_provider.dart:88-99` serves the ICU
  deployment detail for any deployment id.

## Medium / Low

- Root `context.watch<AppProvider>()` for `locale` alone — `main.dart:395`, `:405`.
- Eager `ListView` over unbounded data — `universal_search_screen.dart:300`,
  `diagnostics_tab.dart:39`, `consultations_tab.dart:41`, `manpower_tab.dart:48`.
- No search debounce; `_results` recomputed in `build` — `universal_search_screen.dart:261`, `:277`.
- Undisposed `TextEditingController` — `document_repository_screen.dart:47`.
- `PaymentService` leaked when checkout is abandoned — `billing_screen.dart:304`.
- Global toast timer not cancelled on route teardown — `common_widgets.dart:16-17`.
- Unguarded `setState` after `await` — `daily_report_screen.dart:34`, `:88`;
  `notifications_screen.dart:34`.
- 2 s hard-coded splash delay — `splash_screen.dart:15`.
- Five root tabs built eagerly in `IndexedStack` — `main_shell.dart:37-43`, `:66-69`.
- `BillingProvider` has zero listeners; `clearPatientScopedData` notifies nobody —
  `billing_provider.dart:68-74`, `main.dart:202-204`.
- Banner's `SafeArea` double-insets the tabs below it — `main_shell.dart:143` vs `:66`.
- Four unused dependencies — `dio`, `go_router`, `flutter_svg`, `cupertino_icons`.
- `sync_service` fixed 5-min retry, no backoff or circuit breaker — `sync_service.dart:96`.
- Reduced-motion gap — `equipment_detail_screen.dart:1689-1693`, `:1704-1712`.
- No high-contrast / reduce-transparency handling; `GlassAppBar` blurs unconditionally.
- Overflow suite never exercises the 1.4× textScaler ceiling — 0 `textScaler` in `test/`.
- Large hardcoded sample data in a production screen — `daily_report_screen.dart:41-87`.

## Stale docs asserting six tabs / a Calendar tab

Reported per the brief. The **tests are current** — `test/screens/main_shell_test.dart:228`
asserts *"five tabs, no Calendar tab"*. The docs are not:

| File:line | Stale text |
|---|---|
| `docs/ARCHITECTURE.md:68` | "Fixed solid-orange bottom nav bar (6 tabs: Home/My Care/Services/Calendar/Billing/More)" |
| `docs/SCREEN_MAP.md:6` | "Bottom Tab Bar (MainShell -- 6 tabs …)" |
| `docs/CHANGELOG.md:64` | "are now SIX tabs: … Calendar (3), Billing (4), More (5)" |
| `docs/FEATURE_TRACKER.md:143` | "Care Calendar added as root tab at index 3 … = SIX tabs" |
| `README.md:166` | "services/ # catalog (6 tabs)…" — separate issue: that catalog has 7 tabs |
| `lib/screens/services/service_catalog_screen.dart:127` | comment "the TabBar + 6 tab bodies" — there are 7 |

## BLOCKED-OWNER

| Item | What I need |
|---|---|
| §10 profiler pass (CPU/memory/leaks) | Xcode Instruments on a physical mid-range iPhone — Time Profiler on cold launch, Allocations while scrolling the equipment catalog |
| §10 startup/interaction/memory measured | Firebase Performance console access — traces are already being collected (`main.dart:124-125`) |
| §10 low-end target testing | A run on an older device / throttled network |
| §3 memory returns to baseline | Allocations trace across launch → full catalog scroll → back out |
| §2 60fps confirmation | On-device scroll with the performance overlay / DevTools timeline |
| Live storage-rules posture | `storage.rules` exists but deployment is unverifiable from the repo — `firebase deploy --only storage` status |

---

## Note on owner-decision items

Per the brief I did not grade white-on-orange contrast (round 1 measured 2.33:1 — restated
as fact, not a failure), manpower pricing, or the fixed orange bottom nav. The only
performance consequence of those decisions I found is the unconditional `BackdropFilter`
in `GlassAppBar` (§9), which is a reduce-transparency issue rather than a colour-contrast
one. The expected demo-mode failed-fetch log at startup was **not** counted as a defect;
what I counted is that the demo signal is now shown but is cleared by a single provider's
success and missing from four fallback paths (§7).
