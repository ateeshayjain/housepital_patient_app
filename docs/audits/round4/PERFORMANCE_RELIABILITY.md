# Performance & Reliability — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 · **Auditor:** Performance & Reliability (app-agnostic checklist, control family PERF)
**Scope:** source review of `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app` at
`9127713`, branch `fix/five-tab-nav`. See Limitations.
**Prior rounds:** R1 `803124d` · R2 `820060b` · R3 `9a80fe2` (`docs/audits/round3/PERFORMANCE_RELIABILITY_AUDIT.md`, read, not modified).
**Method:** `git grep` / `git show` across refs, `python3` asset measurement (script inlined
below so it is re-runnable), Flutter SDK source reading for layout/element-lifecycle claims,
line-by-line reading of every file cited. Per the brief I did **not** run `flutter test`,
`flutter build`, `flutter clean` or `pod install`. Central results cited as given:
`flutter analyze` clean · design gate passes · 1,819 tests pass across 101 test files.

Suite v2.0 has **56 controls** (§1–§14). Round 3 graded the 39 controls of the older §1–§10
sheet. The 17 controls in §11–§14 are graded here for the first time; they are not regressions,
they are newly-in-scope requirements.

---

## Applicability

MASTER-3.xx trigger: this is a shipping consumer mobile application with a rendering surface, a
local persistence layer, scheduled OS notifications, periodic background sync, on-device PDF
generation, and a declared HTTP backend (`AppConstants.apiBaseUrl = 'https://api.housepital.in/v1'`,
`lib/config/constants.dart:3`). Every family in this checklist applies to the client artifact.

§5.01 (query indexes) is the only control I mark N/A, with rationale below. §11–§14 are
written for services as much as clients; where a control's server half is unreachable from this
repo I grade the client half on evidence and mark the server half BLOCKED-OWNER rather than
narrowing the control's scope to make it passable.

**Backend note (must not be mis-stated):** a backend exists — `../housepital-backend`
(Firebase Functions + MySQL `housepital`) and `../housepital-api` (Laravel + MySQL
`housepital_db`). The app is pointed at neither; `api.housepital.in` does not resolve. That is
why the app ships as a demo-data build, and it is the direct cause of the §14.03 finding
(no synthetic probe can pass against a host that does not exist).

**Owner decisions, measured but never graded Fail** (per the brief): the floating glass pill
nav, white-on-orange, manpower pricing. The pill's per-frame cost is measured in §2 because
measuring cost is this checklist's job; the design decision is recorded as the owner's.

---

## Prior-round status

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **Blur surfaces per root-tab frame 2 → 4, ≈22 % of screen** | **Still open — and round 3's count is WRONG on the most-used tab.** Corrected below | `grep -rn "BackdropFilter\|ImageFilter.blur" lib/` → 2 definitions (`glass.dart:156`, `assistant_fab.dart:34`), unchanged. But `grep -c GlassAppBar lib/screens/home/home_screen.dart` → **0**, and `grep -n "Scaffold(\|appBar" lib/screens/home/home_screen.dart` → `Scaffold(` at `:104` with **no `appBar:`**. Home composites **3**, not 4. The other four root tabs composite 4. See §2.01. |
| **Double-tap race at both `SessionScope` call sites (A-5)** | **Still open, WIDER, and now joined by a second unconditional defect** | `home_screen.dart:1767-1777` and `settings_screen.dart:452-463` are byte-unchanged unguarded `async` handlers. `clearPatientData` gained `MedicationReminderService().cancelAllReminders()` (`session_scope.dart:100`) and `_adopt` added `OrdersProvider.setPatient` (`:76`). **New:** every single switch now runs the full wipe **twice** — see F-1. |
| **`SessionScope` wipe is O(days-since-install), sequential** | **Still open, and the constant doubled** | `session_scope.dart:129-133` sweep unchanged; `cache_service.dart:41-43` sequential `for` unchanged. F-1 makes both run twice per switch. |
| **40.3 MiB / 238 unreferenced product images** | **Still open. Figure was an UNDERCOUNT — correct number is 241 files / 40.5 MiB** | `pubspec.yaml:84-86` declares **three** directories: `assets/images/`, `assets/images/products/`, `assets/images/branding/`. Round 3 measured only `products/`. Reconciliation with the parallel module's 241/448 @ 40.5 MiB is exact — see §8.01. |
| **`Firebase.initializeApp` + `MedicationReminderService().init()` unguarded before `runApp`** | **Still open, verbatim** | `main.dart:104` `await Firebase.initializeApp(...)`; `main.dart:179` `await MedicationReminderService().init()`; `runApp` at `main.dart:192`. Also `:130-134`, four awaited Crashlytics/Performance setters. |
| **No `cacheWidth` anywhere** | **Still open** | `grep -rn "cacheWidth\|cacheHeight\|ResizeImage\|memCacheWidth\|imageCache" lib/` → **0 matches**. `common_widgets.dart:129` `Image.asset(url, …)`, `:134` `CachedNetworkImage(…)`, neither sized. |
| **`logger.dart:63` unwired TODO** | **Still open, verbatim** | `logger.dart:63` `// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`. `_log` (`:54-67`) still terminates at `debugPrint`. |
| **10 of 11 `DemoMode` sources can never be lowered (A-3)** | **Still open. Now 10 of 12, and I can prove the pill is permanent by construction** | `grep -rn "markServingLiveData" lib/` → 2 production sites: `app_provider.dart:292` (`sourceDashboard`), `vitals_screen.dart:129` (`sourceVitals`). 12 sources declared (`demo_mode.dart:24-35`). `sourceOrders` is raised at `orders_provider.dart:237` on first read and has **no** clearing site. See F-4. |
| **`SessionScope` imported by zero tests** | **Still open** | `grep -rn "session_scope.dart" test/` → **0**. `patient_scope_isolation_test.dart` names SessionScope in a comment (`:12`) and asserts provider contracts directly; it never exercises `install`, `_adopt`, or `clearPatientData`. |
| **`ApiService` not a singleton, 18 unclosed clients** | **Still open** | `grep -rn "ApiService()" lib/` → **18**. `api_service.dart:41` `_client = client ?? http.Client()`; no `factory`, no `close()`. |
| **864 KB catalog on the UI isolate at 7 sites** | **Still open, byte-identical set** | 7 `rootBundle.loadString('assets/equipment_catalog.json')` sites (`assistant_local_actions.dart:39`, `universal_search_screen.dart:149`, `package_detail_screen.dart:35`, `medications_screen.dart:354`, `doctor_advice_card.dart:55`, `equipment_tab.dart:72`, `equipment_detail_screen.dart:138`). `git grep -c` at `9a80fe2` returns the same file set. File is **864,311 bytes**. `grep -rn "compute(\|Isolate\." lib/` → **0**. |
| **`requestRefill` cannot return false** | **Still open** | `medication_provider.dart:164-181` — `_refillRequestedIds.add` + `return true` still outside the `try`. |
| **`CacheService` never evicts; `daily_rating_*` unbounded** | **Still open** | `cache_service.dart:30` `if (_isExpired(timestamp)) return null;` with no `remove`. `my_care_screen.dart:593` builds the key, `:614` writes it. |
| **2 s hard-coded splash delay** | **Still open** | `splash_screen.dart:14-18`. |
| **Reduced-motion gap on one controller** | **Still open** | `equipment_detail_screen.dart:1689-1695` (250 ms, no gate), `_toggle` `:1704-1712`. |
| **No high-contrast / reduce-transparency handling** | **Still open** | `grep -rn "highContrast\|boldText\|accessibleNavigation" lib/` → **0**. `glass.dart:154-157` applies `ClipRRect` + `BackdropFilter` unconditionally. |
| **Overflow suite never exercises 1.4× textScaler** | **Still open** | `grep -rn textScaler test/` → **0**. |
| **Four unused deps** | **Still open** | `dio`, `go_router`, `flutter_svg`, `cupertino_icons` → 0 `package:<name>/` imports in `lib/`. |
| **Undisposed `TextEditingController`** | **Still open, and there are now two** | `document_repository_screen.dart:47` (`_searchController`) and `:648` (dialog-local `nameController`); no `dispose` in the file. |
| **Unguarded `setState` after `await`** | **Still open** | `daily_report_screen.dart:31-36`, `notifications_screen.dart:34`. |
| **Global toast `OverlayEntry`/`Timer` never torn down on route pop** | **Still open** | `common_widgets.dart:16-17` module-level `_activeToast` / `_toastTimer`. |
| **Large hardcoded sample data in a production screen** | **Still open** | `daily_report_screen.dart:40-87`. |
| **`StoreMigrator.run()` throw-safe** | **Pass — holds** | `store_migrator.dart:109-120`: whole body in `_run()` inside `try`; catch calls `Log.error` which cannot throw (`logger.dart:54-67` — no I/O beyond `debugPrint`). Re-verified line by line. |
| **Single `openCheckout` call site / payment path** | **Pass — holds** | `grep -rn "openCheckout" lib/` → 1 site; `grep -rn "payment_service.dart" lib/` → 1 importer. Structural invariant intact at `9127713`. Still **not** locked by a test. |
| **`DemoMode.reset()` has no production call sites** | **Pass — holds** | `grep -rn "DemoMode.reset" lib/` → 0. |
| **`PaymentService` leak on abandoned checkout** | **Pass — holds** | `billing_screen.dart` does not import `payment_service.dart`; surviving instance disposed at `payment_screen.dart:165`. |

**Which pattern does the latest work fit?** Round 1→2 found surfaces; round 2→3 found half-wires.
`13e3656` is a third pattern and it deserves its own name: **correct new machinery bolted on
beside the old machinery, with nothing removed.** `AppProvider.onPatientChanged` +
`SessionScope.install` is the right design and it works. But the manual
`await SessionScope.clearPatientData(context)` at `home_screen.dart:1774`, which the hook was
built to replace, was left in place. The result is not a half-wire — it is a **double-wire**,
and it makes the very failure mode the round-3 report flagged strictly more likely.

---

## Round-4 findings

### F-1 · Every patient switch now runs the full wipe TWICE — one of them detached and unobserved — ❌ NEW

Trace, call by call, from the only production `switchPatient` call site:

```
home_screen.dart:1767-1777
  onTap: () async {
    final nav = Navigator.of(context);
    await SessionScope.clearPatientData(context);   // ── WIPE #1 (awaited)
    app.switchPatient(patient);                     // ── synchronous
    nav.pop();                                      // ── runs while WIPE #2 is in flight
  }

app_provider.dart:187-197
  void switchPatient(Patient patient) {
    clearPatientScopedData(notify: false);
    _currentPatient = patient;
    notifyListeners();
    _announcePatient(patient.id);                   // ── :195
    loadDashboard();                                // ── :196, unawaited
  }

app_provider.dart:65-68  _announcePatient → onPatientChanged(id)

session_scope.dart:64-70
  app.onPatientChanged = (patientId) {
    if (!context.mounted) return;
    unawaited(_adopt(context, patientId));          // ── fire-and-forget
  };

session_scope.dart:73-77
  static Future<void> _adopt(BuildContext context, String? patientId) async {
    await clearPatientData(context);                // ── WIPE #2
    if (!context.mounted) return;
    await context.read<OrdersProvider>().setPatient(patientId);
  }
```

`clearPatientData` (`session_scope.dart:81-107`) therefore executes **twice per switch**. Each
execution costs:

| Step | Cost per execution |
|---|---|
| 6 synchronous provider clears, each `notifyListeners()` (`:82-89`) | 6 rebuild broadcasts |
| `RemindersProvider.clearPatientScopedData()` (`:93`) | 1 `getInstance` + 1 `remove` |
| `MedicationReminderService().cancelAllReminders()` (`:100`) | 1 **platform-channel** round trip (`medication_reminder_service.dart:248-251` → `_plugin.cancelAll()`) |
| `CacheService.clear()` (`:122` → `cache_service.dart:38-44`) | 1 `getKeys()` + **N sequential awaited `remove`** |
| loose keys (`:125-127`) | 1 `remove` |
| `daily_rating_*` sweep (`:129-133`) | 1 full key scan + **M sequential awaited `remove`**, M = days rated since install |

Doubled: **two `cancelAll()` platform round trips, two full key scans, 2·(N+M+1) sequential
awaited `prefs.remove` calls, and twelve provider notification broadcasts** for one tap.

Three consequences, in ascending severity:

1. **Wipe #2 is not awaited by anyone.** `nav.pop()` at `:1776` executes immediately after
   `switchPatient` returns, so the sheet closes and the user is returned to a fully interactive
   Home while an unbounded storage wipe is still running. There is no completion signal, no
   error surface, and `Log.warn` inside `_clearPatientScopedStorage`'s catch (`:134-137`) reaches
   `debugPrint` only (`logger.dart:63`). **A failed wipe is silent and invisible.**
2. **Wipe #2 races `loadDashboard()`.** `switchPatient:196` starts `loadDashboard()` immediately
   after `_announcePatient`. `loadDashboard` ends with
   `await cache.cache('dashboard_$patientId', billing)` (`app_provider.dart:293`) — a **write** to
   the same `housepital_cache_*` namespace that wipe #2's `CacheService.clear()` (`:40`) is
   iterating. Nothing orders them. With a live backend the write lands after the wipe in the
   common case and the cache survives; on a fast/cached response it lands inside the sweep and
   the new patient's dashboard cache is deleted. Neither ordering is guaranteed by anything in
   the code.
3. **The round-3 double-tap race (A-5) is not merely still open — its window is wider.** The gap
   between the tap and `nav.pop()` is now the duration of wipe #1, which gained a platform-channel
   `cancelAll()`. The sheet stays open, every row keeps its `ListTile` hit region, there is no
   `_switching` guard, no `AbsorbPointer`, no spinner. Two taps run two complete
   `onTap` bodies, i.e. **four** interleaved wipes and two `switchPatient` calls, and the second
   `nav.pop()` fires on a `NavigatorState` captured before the sheet existed, popping whatever is
   then topmost.

**The correct fix is a deletion, not an addition:** remove `await SessionScope.clearPatientData(context)`
from `home_screen.dart:1774` — the hook installed at `main_shell.dart:39-40` already does it — and
add a `bool _switching` guard plus a disabled row state. That reduces the work by half and closes
the race in the same edit.

### F-2 · `_adopt` is re-entrant with no guard; a late adopt lands the WRONG patient's order history — ❌ NEW

The brief's explicit question. `_adopt` has no in-flight flag, no sequence token, and no
cancellation. Two adopts can overlap by two independent routes:

- **Route A — `loadPatients()` on every Home mount.** `app_provider.dart:148-184`. The API call is
  `await _apiService.getPatients().timeout(const Duration(seconds: 5))` (`:162-163`). If the
  identity differs it calls `_announcePatient(incoming.id)` at `:178`. `HomeScreen` triggers
  `loadPatients` on mount, so this fires on every return to the Home tab, with a window of up to
  5 s in which the user can also open the switch sheet.
- **Route B — the switch sheet itself**, per F-1(3).

The interleaving that matters, and its outcome:

```
adopt(A):  clearPatientData ──────────────────────────────────► setPatient(A)
adopt(B):        clearPatientData ──────► setPatient(B)
```

`OrdersProvider.setPatient` (`orders_provider.dart:53-60`) early-returns only when
`patientId == _patientId`. `clearPatientData` → `OrdersProvider.clearPatientScopedData()`
(`:258-263`) sets `_patientId = null`, so the guard never fires between two different adopts.
When adopt(A) lands **after** adopt(B)'s `setPatient(B)`:

- `_patientId` becomes `A`, `_orders` is reloaded from `housepital_orders_A`;
- `AppProvider._currentPatient` is whichever `_announcePatient` ran last — `B`;
- Billing, My Orders, and the assistant's order sink then render **patient A's order history
  under patient B's name**.

That is precisely the cross-patient bleed the whole `SessionScope` + per-patient-key design
exists to prevent, arriving through the wiring rather than through the storage.

A second, quieter outcome of the same race: if adopt(B)'s `clearPatientScopedData()` lands after
adopt(A)'s `setPatient(A)`, `_patientId` is left `null` and `_ordersKey` evaluates to
`'housepital_orders__none'` (`orders_provider.dart:32-33`). Any subsequent `addOrder` →
`_persistAndNotify` (`:201-211`) writes a real order to that orphan key, where no patient will
ever read it.

**Latent, not currently reachable, but worth recording:** `install` (`:61-71`) captures
`MainShell`'s `BuildContext` in a closure that is assigned once and never cleared, and guards
re-installation with `if (app.onPatientChanged != null) return`. If `MainShellState` is ever
disposed and a new one mounted while `AppProvider` survives (it is a root provider in
`main.dart`), the stale closure short-circuits on `!context.mounted` and the new `install` refuses
to overwrite it — the fan-out dies permanently and silently. Today the only mount path is
`splash_screen.dart:17` `pushReplacementNamed('/home')`, once, so this is not reachable in the
shipped build. It becomes reachable the moment the commented-out auth gate is restored.

### F-3 · The v1→v2 migration is cheap and correctly idempotent; its startup cost is not where the startup problem is — ⚠️

Assessed as the brief asked. The step (`store_migrator.dart:65-73`) does, on first launch after
upgrade and only if the legacy keys are present: `containsKey` ×2, `quarantine` ×2
(`prefs.get` + one typed setter, `:204-222`), `remove` ×2. Around it, `_run` (`:122-154`) costs one
`SharedPreferences.getInstance()`, one `getInt`, one `getKeys()` scan via `_hasAnyStoredData`
(`:192-197`), and one to two `setInt`. **Upper bound ≈ 10 platform round trips, once in the
lifetime of the install.** That is not a startup problem.

I traced the kill-points for failure modes and the design holds:

- Killed between `quarantine` and `remove`: version unstamped → next launch re-enters at v1 →
  `quarantine` rewrites the identical value → `remove` → stamp. **Idempotent.**
- Killed after `remove`, before `setInt`: next launch sees `stamped == null` and
  `_hasAnyStoredData` true → `_migrateFrom(prefs, 1)` → both keys absent → `continue` → stamp v2.
  **Idempotent.**
- Step throws (disk full during `quarantine`'s `setString`): caught at `:166`, logged, `setInt` the
  **last good** version at `:176`, `return` — retried next launch, not falsely stamped. This is the
  exact silent-data-loss failure the file's own comment says it exists to prevent, and it is
  correctly implemented.
- `run()` cannot throw (`:114-119`), and the catch's `Log.error` cannot throw.

Two residual risks, both real:

1. **`quarantine` doubles the footprint of the blob it preserves before deleting the original.**
   On a device genuinely low on storage — the population most likely to have a long-lived install
   — the `setString` is the operation that fails. It fails *safely* (retry next launch, forever),
   but it fails *invisibly*: the `Log.error` at `:167-169` reaches `debugPrint` only. A device can
   sit in permanent retry with nobody able to know.
2. **No timeout on any pre-`runApp` await, including this one.** `StoreMigrator.run()` cannot
   throw, but it can *hang*: `SharedPreferences.getInstance()` (`:123`) is a platform channel with
   no timeout, sitting inside the black-screen window described in §7.02. The same is true of
   `Firebase.initializeApp` (`main.dart:104`) and `MedicationReminderService().init()` (`:179`).
   Throw-safety and hang-safety are different properties; only the first was fixed.

**Grade rationale:** the migration itself is Pass-quality work. PERF-1.02 still Fails, but on the
strength of `main.dart:104/130-134/179/192` and `splash_screen.dart:14-18`, not on the migration.

### F-4 · The demo pill — and therefore the 3rd/4th backdrop filter — is permanent BY CONSTRUCTION, and I can now show why — ⚠️ (sharpened from R3's A-3)

Round 3 argued the pill was permanent because 10 of 11 sources were a one-way latch. The
mechanism is more concrete than that, and it does not depend on the backend being down:

1. `main.dart:214` provides `OrdersProvider()` with **no** `patientId`.
2. `main_shell.dart:75` `body: IndexedStack(index: _currentIndex, children: _screens)` builds all
   five root tabs eagerly; `billing_screen.dart` reads `OrdersProvider`, so the provider is
   instantiated during the **first frame after splash**.
3. The constructor (`orders_provider.dart:43-45`) calls `_loadFromStorage()` with `_patientId == null`,
   so `_ordersKey` is `'housepital_orders__none'` (`:32`) — a key nothing ever writes.
4. `_orders` is therefore empty, so `:235-238` seeds `DemoData.orders` and calls
   `DemoMode.markServingDemoData(DemoMode.sourceOrders)`.
5. `grep -rn "markServingLiveData" lib/` → `app_provider.dart:292` (`sourceDashboard`) and
   `vitals_screen.dart:129` (`sourceVitals`). **`sourceOrders` has no clearing site anywhere.**

So `DemoMode.isServingDemoData` is `true` from the first post-splash frame, on every device, in
every build, with or without a backend, and can never return to `false`.
`DemoDataBannerHost` (`demo_data_banner.dart:36-56`) therefore renders its `Stack` + `GlassSurface`
pill (`:96`) on every route for the whole process lifetime. Worse for the switch path: step 3–4
repeat on **every** `setPatient` to a patient with no persisted orders, re-raising the flag.

This is simultaneously (a) an honesty defect — the notice cannot ever be lowered, which is the
permanent-false-alarm failure `demo_mode.dart`'s own doc comment says the redesign eliminated;
and (b) the reason one backdrop filter is unconditional for every user (§2.01, §9.03).

One piece of good news, re-verified: because the latch is one-way, the `false → true` element
re-parent that round 3 traced happens **at most once per launch**, not per provider refresh.

---

## Measurements

### Blur surfaces composited per frame — corrected

`grep -rn "BackdropFilter\|ImageFilter.blur" lib/` returns two *definitions*
(`glass.dart:156-157`, `assistant_fab.dart:34-35`). Instances composited per frame:

| Surface | Definition | σ | Present on |
|---|---|---|---|
| `GlassAppBar` → `GlassSurface` | `glass.dart:70`, `:156` | 24 | 47 files use `GlassAppBar`; **4 of 5** root tabs |
| Nav pill → `GlassSurface` | `main_shell.dart:121` | **36** | all 5 root tabs, permanently |
| `AssistantFab` | `assistant_fab.dart:34` | 24 | all 5 root tabs (`main_shell.dart:76`) |
| Demo pill → `GlassSurface` | `demo_data_banner.dart:96` | 24 | **every route, permanently** (F-4) |
| Switch sheet → `GlassSurface` | `home_screen.dart:1741` | 24 | while the patient-switch sheet is open |

**Correction to round 3:** `home_screen.dart` has no app bar — `Scaffold(` at `:104` with no
`appBar:` argument, and `grep -c GlassAppBar` on the file returns 0. The Home tab composites
**3** backdrop filters, not 4. Round 3's "4 on every root tab" over-counted the app's most-used
screen. `IndexedStack` builds all five tabs but paints only the active one, so off-screen
`GlassAppBar`s cost nothing per frame — that part of round 3's reasoning is sound.

Geometry, 390×844 pt (iPhone 13/14 class):

| Surface | Derivation | pt² |
|---|---|---|
| `GlassAppBar` | Scaffold sizes the app-bar slot to `preferredSize.height + padding.top` = 56 + 47 (`glass.dart:52-53`, `kToolbarHeight`); `GlassSurface` is the outermost widget so it fills the slot: 390 × 103 | 40,170 |
| Nav pill | `Padding(16,·,16,·)` is **outside** `GlassSurface` (`main_shell.dart:89-121`), so the blurred box is 358 × `kBottomNavigationBarHeight` 56 | 20,048 |
| Demo pill | 12 px w600 label + 15 px icon + 6 gap + 12 px h-padding ×2, `maxLines: 1`; ≈259 × 30 | ≈7,770 |
| `AssistantFab` | `ClipOval` **outside** `BackdropFilter` (`assistant_fab.dart:33-35`) over a 56×56 box → π·28² | 2,463 |
| Switch sheet | 390 × ≈200 (title 56 + 2–3 rows × 56 + 16) | ≈78,000 |

| State | Surfaces | Blurred pt² | % of 329,160 pt² screen |
|---|---|---|---|
| **Home tab, steady state** | 3 | 30,281 | **9.2 %** |
| **My Care / Services / Billing / More** | 4 | 70,451 | **21.4 %** |
| **Home + patient-switch sheet open** | 4 | 108,281 | **32.9 %** |

At `820060b` the equivalents were 2 surfaces / ≈13 % (nav bar was
`Material(color: context.hc.orange)`, the demo notice an opaque strip —
`git grep "BackdropFilter\|sigma:" 820060b -- lib` returns only the two definitions).

**Why the count matters more than σ.** Skia and Impeller implement large-σ Gaussians as
downsample → small-kernel blur → upsample, so cost is markedly sublinear in σ; 36 over 24 on
20,048 pt² is a modest increase. The expensive part is per-`BackdropFilter` and σ-independent:
`BackdropFilterLayer` registers a readback region, which (a) expands the partial-repaint damage
rect so any intersecting damage forces re-rasterization, and (b) on a tile-based mobile GPU forces
the current render pass to be flushed and resolved to a texture before the filter can sample it.
Three or four filters means three or four such flushes per frame in three or four places in the
paint order. This is engine behaviour and geometry, **not a measurement** — the measurement is
BLOCKED-OWNER (§10.01) and remains the single highest-value 20 minutes anyone could spend on this
app.

The one-line change that covers all five sites at once: a
`MediaQuery.of(context).highContrast || MediaQuery.of(context).accessibleNavigation` check in
`GlassSurface.build` (`glass.dart:140-157`) returning an opaque `DecoratedBox` instead of the
`BackdropFilter`. It changes nothing for any user who has not asked for it.

### Unreferenced assets — re-measured, and the round-3 figure reconciled upward

`pubspec.yaml:84-86` declares three directories. Flutter bundles **every file** in a declared
directory regardless of reference, which is also why asset tree-shaking cannot help.

```
assets/images/            (declared, non-recursive):   3 files
assets/images/products/   (declared):                439 files
assets/images/branding/   (declared):                  6 files
                                            TOTAL:   448 files   78.1 MiB
```

Method (re-runnable): `re.compile(r'assets/images/products/([^"\']+)')` over every
`.dart`/`.json`/`.yaml` in the repo excluding `.git`, `build`, `.dart_tool`, `ios/Pods`,
`docs/audits`; `assets/images/branding/*` checked by filename grep over `lib/` and the catalogs.

| Set | Files | Size |
|---|---|---|
| `products/` total | 439 | 77.4 MiB |
| `products/` referenced | 201 | 37.1 MiB |
| **`products/` UNREFERENCED** | **238** | **40.3 MiB** |
| `products/` referenced-but-missing | **0** | — |
| `branding/` unreferenced (`hero_consultation.jpg`, `hero_equipment.jpg`, `hero_vitals.jpg`) | 3 | 0.24 MiB |
| **TOTAL DEAD, shipped** | **241** | **40.5 MiB** |

**Reconciliation with the parallel module (241 / 448 @ 40.5 MiB): exact.** Their denominator is
every file under `assets/images/` (439 + 6 + 3 = 448); their numerator is my 238 dead products plus
the 3 dead branding heroes; 40.3 MiB + 0.235 MiB = 40.54 MiB. **Round 3's 238 / 40.3 MiB was an
undercount** because it measured only `products/`, and `docs/KNOWN_ISSUES.md:34` currently records
that undercount. The correct figure to fix and to publish is **241 files / 40.5 MiB**.

`referenced-but-missing = 0`, so the delete is behaviourally risk-free. Two of the five largest
files on disk are dead: `0094_ECG_Electrodes.png` (3.55 MiB), `0360_Inj_Ondomed.jpg` (1.71 MiB);
three 1.48 MiB F-20 mask renders are dead as well. **Four rounds, unchanged, still a pure delete,
still the largest single win in the app.**

---

## Control results

Owner column: `OWNER-TBD` where the repo does not name one.

### §1 Startup / first response

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-1.01 TTI fast on mid/low-end (< 2 s cold) | **Fail** | `splash_screen.dart:14-18` — `Future.delayed(const Duration(seconds: 2))` then `pushReplacementNamed('/home')`, unconditional, not raced against readiness. That 2 s begins **after** the pre-`runApp` chain at `main.dart:104,130-134,175,179`. TTI ≥ 2 s + init **by construction**; this is a source-provable budget miss, not an untaken measurement. | First interaction impossible for ≥2 s on every device. Mitigation: race the delay against real readiness (`Future.any`) and cap it. Owner: OWNER-TBD. |
| PERF-1.02 No heavy work blocking startup (migrations, big sync reads, network) | **Fail** | Serialised before `runApp` (`main.dart:192`): `Firebase.initializeApp` (`:104`), four awaited Crashlytics/Performance setters (`:130-134`), `StoreMigrator.run()` (`:175`), `MedicationReminderService().init()` (`:179`). Then the five-tab eager `IndexedStack` (`main_shell.dart:75`), which instantiates every root tab's providers on the first frame (F-4). The control names migrations explicitly; nothing here is deferred or backgrounded. **Note (F-3): the migration is the *cheapest* item on this list (~10 round trips, once).** | Cold-launch cost paid serially with no user-visible progress and no timeout on any await. Mitigation: move `runApp` above the init block; run init in a `finally`/post-frame. Owner: OWNER-TBD. |
| PERF-1.03 First view shows content or skeleton fast; no blank/hung state | **Pass** | `splash_screen.dart:22-30` paints with zero async dependencies. `equipment_tab.dart:204-235` has a real shimmer skeleton. | — |

### §2 Rendering & interaction

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-2.01 Smooth scroll/animation, no jank | **Fail** | 3 backdrop filters on Home / 4 on the other root tabs / 4 at ≈33 % of the screen while the switch sheet is open (measurements above); one at σ 36; **no Reduce-Transparency escape** (`grep highContrast\|accessibleNavigation lib/` → 0); full-resolution image decode unchanged; `ImageCache` untuned. Doubled from 2 surfaces at `820060b`. | Known per-frame cost added across three rounds with **zero** measurement taken. Mitigation: the one-condition `GlassSurface` change; fix the `sourceOrders` latch so the 3rd/4th filter disappears when a backend exists. Owner: OWNER-TBD. Device measurement is BLOCKED-OWNER (§10.01) — the grade reflects known-added cost, not the absence of the trace. |
| PERF-2.02 Lazy loading / virtualization for long lists | **Warning** | Correct: `equipment_tab.dart:212`/`:400`, `lab_tests_tab.dart`, `packages_tab.dart`, `widgets/paginated_list.dart` (4 history screens, `pageSize: 20`). Eager over unbounded data: `universal_search_screen.dart:300`, `diagnostics_tab.dart:39`, `consultations_tab.dart:41`, `manpower_tab.dart:48`. Plus 5 root tabs built eagerly (`main_shell.dart:75`). | Bounded today by demo-sized data; unbounded against a real catalog. Mitigation: `ListView.builder` at the four sites; `LazyIndexedStack` for the shell. Owner: OWNER-TBD. |
| PERF-2.03 Images sized/compressed to display size | **Fail** | `grep -rn "cacheWidth\|cacheHeight\|ResizeImage\|memCacheWidth\|imageCache" lib/` → **0**. `common_widgets.dart:108-140` `ProductImage`: `Image.asset` (`:129`) and `CachedNetworkImage` (`:134`), neither sized. Grid cards ≈180 pt (`equipment_tab.dart:394-397`) → ~492 px @3× → ~0.97 MB needed; largest live asset is 2000×2000 → **16.0 MB decoded**, ~17× the pixel budget. | Largest runtime-memory lever in the app; drives OOM risk on low-RAM Android, which is this app's Delhi NCR audience. Mitigation: `cacheWidth` on both branches + an `imageCache.maximumSizeBytes` cap. Owner: OWNER-TBD. |
| PERF-2.04 No expensive work in render/row builders | **Fail** | `universal_search_screen.dart:277` `onChanged: (v) => setState(() => _query = v.trim())` — un-debounced full-`Scaffold` rebuild per keystroke; `:261` `final results = _results;` invokes the getter at `:159` that rescans the whole corpus **inside `build`**. The `TextField` lives inside the `GlassAppBar` (`:270-292`), so every keystroke also dirties the app-bar readback region. | Worst interaction path in the app, and the one sitting under the most blur. Mitigation: 250 ms debounce + memoise `_results`. Owner: OWNER-TBD. |

### §3 Memory

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-3.01 No leaks / retain cycles | **Fail** | 18 `ApiService()` sites (`grep -rn "ApiService()" lib/`), `api_service.dart:41` `_client = client ?? http.Client()`, no `factory`, no `close()`. `document_repository_screen.dart:47` and `:648` — two undisposed `TextEditingController`s, no `dispose` in the file. Module-level `OverlayEntry? _activeToast` / `Timer? _toastTimer` (`common_widgets.dart:16-17`), never cancelled on route teardown. **Credit, unchanged:** every periodic `Timer` cancelled (`otp_screen.dart:77`, `home_screen.dart:88`, `auth_provider.dart:234`, `sync_service.dart:111`) and all four `StreamSubscription`s cancelled. | 18 unpooled sockets; ad-hoc `ApiService` instances also never receive the auth token, so against a real backend those sites 401 into permanent demo fallback. Mitigation: `factory ApiService()` singleton; dispose the controllers; scope the toast to an `OverlayState`. Owner: OWNER-TBD. |
| PERF-3.02 Large media streamed or bounded | **Fail** | Nothing bounds decoded image memory (see 2.03). `invoice_pdf_service.dart:96` and `handover_report_service.dart:97` build PDFs fully in memory on the UI isolate. | Mitigation: as 2.03; move PDF generation to `compute`. Owner: OWNER-TBD. |
| PERF-3.03 Caches have a size bound and evict | **Fail** | `cache_service.dart:22-36` — `get` returns `null` on expiry (`:30`) and **never removes**; `clear()` (`:38-44`) has no callers except `SessionScope`. `daily_rating_YYYY-MM-DD` (`my_care_screen.dart:593`, written `:614`) grows one `SharedPreferences` key per rated day with no cap and no TTL. `_orders` / `_assessments` grow without bound and are re-encoded whole on every mutation (`orders_provider.dart:201-211`). On iOS the whole prefs store is memory-resident. | Unbounded growth in three stores; drives F-1's O(days) sweep. Mitigation: `remove` on expiry; cap `daily_rating_*` to 90 days; cap the orders blob. Owner: OWNER-TBD. |
| PERF-3.04 Memory returns to baseline after heavy flows | **BLOCKED-OWNER** | Requires Instruments Allocations: launch → scroll the full equipment catalog → back out. Not verifiable from source. | — |

### §4 Battery, network & resource use

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-4.01 No busy-wait loops / runaway timers | **Warning** | `sync_service.dart:96` `Timer.periodic(interval, …)` at a fixed interval with no backoff and no escalation; both call sites swallow the outcome via `.catchError` (`:92-94`, `:97-99`). All timers are cancelled on teardown. | An unreachable backend is polled forever at full rate. Mitigation: exponential backoff + a failure ceiling. Owner: OWNER-TBD. |
| PERF-4.02 Background work registered correctly and finishes promptly | **Warning** | FCM deferred to `addPostFrameCallback`; cold-start notifications drained. **New:** `session_scope.dart:69` `unawaited(_adopt(context, patientId))` is detached async work with **no completion signal, no error surface, and no tracking handle** (F-1(1)), started from a callback that can fire at any time. | A failed or half-completed patient wipe is undetectable. Mitigation: hold the future in a field; surface failure; guard re-entry. Owner: OWNER-TBD. |
| PERF-4.03 Requests batched/coalesced; retried with backoff | **Warning** | Backoff is real and correct: `api_service.dart:53-86` — 2 retries at `_retryDelay * attempt` for `SocketException`, `TimeoutException` and 5xx, plus one-shot 401 recovery. Coalescing absent: the **864,311-byte** `equipment_catalog.json` is loaded and `jsonDecode`d independently at **7** sites with no shared memo. | ~864 KB parsed up to 7× per session on the UI isolate. Mitigation: one `Future<Catalog>` memo. Owner: OWNER-TBD. |
| PERF-4.04 Requests cancelled when no longer needed; payloads paginated/compressed | **Fail** | No `CancelToken`, no `_client.close()`, no request-level timeout in `ApiService` — timeouts exist only at caller sites (`app_provider.dart:163`, `:280`). The `on TimeoutException` branch at `api_service.dart:70` is therefore effectively dead for calls without a caller-side timeout. | In-flight requests survive navigation away; sockets accumulate. Mitigation: a client-level `timeout` + a cancellation primitive. Owner: OWNER-TBD. |

### §5 Data & query performance

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-5.01 Hot queries efficient; indexes on filtered fields | **N/A** | **Rationale:** the client artifact under audit has no query engine to index. No `sqflite`/`drift`/`Isar`/`hive` in `pubspec.yaml`; all persistence is `SharedPreferences` (a flat key→value map) plus in-memory lists. Firestore composite indexes and the MySQL schemas in `../housepital-backend` / `../housepital-api` are server-side artifacts outside this artifact, and the app is connected to neither. This is an applicability rationale, not "not tested". | — |
| PERF-5.02 N+1 patterns avoided | **Warning** | No network N+1 (`loadDashboard` uses `Future.wait` over 5 calls, `app_provider.dart:275-281`). The client-side equivalent is live: the 7-site catalog re-parse (4.03). | Mitigation: shared memo. Owner: OWNER-TBD. |
| PERF-5.03 Large result sets paginated; query timeouts set | **Warning** | `PaginatedListView` used correctly at `pageSize: 20` in four history screens. Timeouts cover a minority of call sites (4.04). | Mitigation: default timeout in `ApiService`. Owner: OWNER-TBD. |
| PERF-5.04 Pooling (server) / reads off the UI thread (client) | **Fail** | (a) 18 independent `http.Client()`s, none closed — no pooling. (b) `grep -rn "compute(\|Isolate\." lib/` → **0**, while 864 KB `jsonDecode` runs on the main isolate at 7 sites and PDF generation is synchronous on the UI isolate. (c) `SessionScope`'s O(N+M) strictly-sequential `prefs.remove` chain (`session_scope.dart:129-133`, `cache_service.dart:41-43`), **now run twice per switch** (F-1). | Mitigation: `Future.wait(keys.map(prefs.remove))` collapses M sequential round trips into M concurrent; `compute()` for the catalog and PDFs; delete the duplicate wipe. Owner: OWNER-TBD. |

### §6 Concurrency & responsiveness

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-6.01 No blocking calls on the main/UI thread | **Fail** | As 5.04(b): 0 isolates, 864 KB JSON ×7 and synchronous PDF generation on the UI isolate. | Mitigation: `compute()`. Owner: OWNER-TBD. |
| PERF-6.02 Long operations cancellable and cancelled on navigation/teardown | **Fail** | No cancellation primitive exists anywhere in `lib/`. `_adopt` (`session_scope.dart:73-77`) cannot be cancelled, is not tracked, and continues after `nav.pop()` (F-1(1)). No `CancelToken` in `ApiService`. | Mitigation: an in-flight token per switch; abandon stale adopts. Owner: OWNER-TBD. |
| PERF-6.03 Shared mutable state protected (no races in read-modify-write) | **Fail** | **F-1** — every switch runs two wipes over the same six providers and the same prefs store, the second detached and racing `loadDashboard`'s cache write (`app_provider.dart:293`). **F-2** — `_adopt` is re-entrant with no guard; a late adopt lands one patient's order history under another's name. **A-5 unchanged** — `home_screen.dart:1767-1777` and `settings_screen.dart:452-463` are still unguarded `async` handlers with no `_busy` flag, no disabled state, no `AbsorbPointer`. Toast globals unchanged (`common_widgets.dart:16-17`). | Cross-patient clinical/order bleed on a shared phone — the exact class this app's whole session design exists to prevent. Mitigation: delete the duplicate call at `home_screen.dart:1774`; add `bool _switching` at both call sites; add a sequence guard to `_adopt`. **Fix first.** Owner: OWNER-TBD. |
| PERF-6.04 State-changing async ops capture state at invocation, not execution | **Warning** | Coverage is good overall and the recent repairs did this correctly (`payment_screen.dart:245`, `session_scope.dart:65`, `:75`). Two confirmed gaps unchanged: `daily_report_screen.dart:31-36` (`setState` after `await`, no `mounted` check) and `notifications_screen.dart:34`. | Mitigation: `if (!mounted) return;`. Owner: OWNER-TBD. |

### §7 Reliability & resilience

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-7.01 Crash/error-free target defined and monitored | **Fail** | `logger.dart:63` still reads `// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`; `_log` (`:54-67`) still terminates at `debugPrint`. Crashlytics receives **fatals only**. Every `Log.warn`/`Log.error` — `session_scope.dart:102`, `:135`, `store_migrator.dart:117`, `:167`, `orders_provider.dart:208`, `:242`, `payment_service.dart:181` — reaches no remote sink in release. No crash-free-sessions or error-rate target exists in `docs/`. | Every safety net in this codebase logs into a void; the F-1/F-2/F-3 failure modes are all undetectable in the field. **One line at a documented chokepoint.** Owner: OWNER-TBD. |
| PERF-7.02 No uncaught exceptions on user paths; global error boundary | **Warning** | Boundary is genuinely good: `runZonedGuarded` (`main.dart:100`), `FlutterError.onError` → `recordFlutterFatalError` (`:116-117`), `PlatformDispatcher.instance.onError` (`:118-121`), friendly `ErrorWidget.builder` (`:139-168`), route-level try/catch (`:437`, `:774-786`), correctly gated on `!kIsWeb` / `!kDebugMode`. The pre-`runApp` window still holds two unguarded awaits — `main.dart:104`, `:179` — where `ErrorWidget.builder` cannot help because no widget tree exists yet. F-3 adds: **none of the pre-`runApp` awaits has a timeout**, so a hang is as fatal as a throw and is not even reported. | Permanent black screen on a Firebase or notification-plugin init failure. Mitigation: `runApp` first, init after, or wrap and `runApp` in a `finally`; add timeouts. Owner: OWNER-TBD. |
| PERF-7.03 Degrades gracefully when a dependency is down | **Warning** | The demo layer is well-shaped: notice over every route (`main.dart:434`), per-source `Set` (`demo_mode.dart:24-35`, 12 sources), the previously-unmarked fallbacks now marked. Held at Warning for **F-4**: `sourceOrders` is raised on the first frame and has no clearing site, so the notice is permanently true regardless of backend health; 10 of 12 sources are one-way. Also unchanged: `my_care_provider.dart:88-99` substitutes `DemoData.icuServiceDetail` for **any** deployment id on a non-`ApiException` failure. | A healthy backend still shows "Sample data — not your live record"; a wrong record can be shown as the right one. Mitigation: wire `markServingLiveData` for all 12 sources; drop the wrong-id substitution. Owner: OWNER-TBD. |
| PERF-7.04 Recovers cleanly from interruption | **Warning** | `my_care_provider.dart:47-53` sets `_lastFetchedAt = DateTime.now()` inside the demo-seed branch, so `isStale` (`:36-38`) reports false for 60 s off a demo seed and the foreground-resume refresh is skipped. Migration kill-point recovery is correct (F-3). | Mitigation: don't stamp freshness on a fallback. Owner: OWNER-TBD. |
| PERF-7.05 Data integrity under interrupted writes (atomic/transactional) | **Fail** | **No write queue exists** — `grep -rn "outbox\|pending_writes\|writeQueue\|enqueue" lib/` → 0; `sync_service` is read-only; `OrdersProvider.addOrder` (`:98-116`) persists locally and makes no API call, yet all four call sites show an unqualified confirmation. `requestRefill` cannot return false (`medication_provider.dart:164-181`) — the UI says the pharmacy was notified when it was not. Failed delete pops as success (`add_edit_medication_screen.dart:268-272`). **New:** `StoreMigrator` introduced `quarantine()` for the *legacy* keys, but the live per-patient read path has **no** such guard — `orders_provider.dart:214-246` catches a `jsonDecode` failure, logs to `debugPrint`, leaves `_orders` empty, and the next `addOrder` → `_persistAndNotify` (`:201-211`) writes the truncated list over the corrupt-but-recoverable blob. `_persistAndNotify` writes two whole blobs sequentially with no atomicity between them. **New:** F-1's duplicated wipe and F-2's re-entrant adopt are themselves interrupted-write hazards over the same store. | Silent loss of a patient's order history; false clinical confirmations. Mitigation: extend `quarantine()` to the v2 read path; make `requestRefill` return the real outcome; add an outbox. Owner: OWNER-TBD. |
| PERF-7.06 Retries with backoff + circuit breakers | **Warning** | Backoff correct at `api_service.dart:53-86`. **No circuit breaker anywhere** in `lib/`. `sync_service.dart:96` has no backoff at all. | Retry storms against a recovering backend. Mitigation: a breaker around `ApiService`. Owner: OWNER-TBD. |

### §8 Size & asset hygiene

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-8.01 No unused assets, deps, or dead code shipped | **Fail** | **241 files / 40.5 MiB** of unreferenced images bundled via three directory declarations at `pubspec.yaml:84-86`; `referenced-but-missing = 0`. Four unused dependencies at 0 `package:<name>/` imports: `dio`, `go_router`, `flutter_svg`, `cupertino_icons`. Unchanged across four rounds. | ~40.5 MiB — roughly a quarter to a third of install size — for zero behaviour. Pure delete, zero risk. Mitigation: delete the 241 files, then enumerate assets in `pubspec.yaml` or add a CI prune check against `equipment_catalog.json`. Also correct `docs/KNOWN_ISSUES.md:34`, which records the old undercount. Owner: OWNER-TBD. |
| PERF-8.02 Code-splitting / thinning / tree-shaking | **Warning** | Dart AOT tree-shakes unreached code; bundling `Archivo` + `NotoSansDevanagari` locally instead of `google_fonts` is the right call (`pubspec.yaml` fonts block). Assets are never tree-shaken — three directory-level declarations defeat it by construction. | Mitigation: enumerate assets individually. Owner: OWNER-TBD. |
| PERF-8.03 No debug-only resources or large sample data in the release artifact | **Fail** | `DemoData` is reachable from providers, screens and `handover_report_service.dart:101-108`, so it is not tree-shakeable: `demo_data.dart` (749 LOC), `demo_articles.dart` (236), `care_packages.dart` (266), `demo_mode.dart`. `daily_report_screen.dart:40-87` is ~47 lines of fabricated clinical report — vitals, tasks and medications attributed to a named nurse — compiled into the release binary and rendered on API failure. | A fabricated clinical report can render as a real one. Mitigation: gate `DemoData` behind a `--dart-define`; delete the hardcoded report. Owner: OWNER-TBD. |

### §9 Accessibility-driven performance

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-9.01 Reduced-motion honoured everywhere | **Warning** | 11 files reference `disableAnimations`; the "no infinite pulses" rule holds; recent repairs did this right (`payment_screen.dart:302-310`). One ungated controller of seven: `equipment_detail_screen.dart:1689-1695` (hardcoded 250 ms) with `_toggle` (`:1704-1712`) calling `forward()`/`reverse()` with no check. | One screen animates for users who asked it not to. Mitigation: gate `_toggle`. Owner: OWNER-TBD. |
| PERF-9.02 Largest text / zoom doesn't break layout or tank performance | **Warning** | The 0.85–1.4 clamp is correct and deliberate (`main.dart:421-432`), honouring WCAG 1.4.4; overflow guarded across 320/375/414 by `test/screens/overflow_smoke_test.dart`. `grep -rn textScaler test/` → **0**, so the suite runs at default scale only and the advertised 1.4× ceiling is never tested. The demo pill's label is `maxLines: 1` + `TextOverflow.ellipsis` at 12 px (`demo_data_banner.dart:118-122`) — at 1.4× a clinical-safety string is the first thing truncated. | The 1.4× ceiling is unverified. Mitigation: parameterise the overflow suite over `textScaler`. Owner: OWNER-TBD. |
| PERF-9.03 Reduced-transparency / high-contrast respected | **Fail** | `grep -rn "highContrast\|boldText\|accessibleNavigation" lib/` → **0 matches, repo-wide**. `glass.dart:154-157` applies `ClipRRect` + `BackdropFilter` unconditionally; so does `assistant_fab.dart:33-35`. A user who enables Reduce Transparency to make the app cheaper and more legible gets 3–4 unconditional blurs instead of the 2 they got at `820060b`. | Accessibility preference ignored; the users most likely to set it are on the weakest hardware. Mitigation: one condition in `GlassSurface.build` fixes all five sites. Owner: OWNER-TBD. |

### §10 Measurement & evidence

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-10.01 Profiler pass on a real target (CPU, memory, leaks) | **BLOCKED-OWNER** | No profiler artefact anywhere in `docs/`. Needs Xcode Instruments Time Profiler + GPU on a physical mid-range phone. Specific A/B available: `820060b` vs `9127713`, Home tab with the demo pill up. **Highest-value single measurement available on this app.** | — |
| PERF-10.02 Startup, interaction, memory measured, not assumed | **BLOCKED-OWNER** | No perf artefact in `docs/`. Firebase Performance **is** initialised (`main.dart:132-134`), so cold-start and HTTP traces should already be flowing — needs console access to read. | — |
| PERF-10.03 Crash/error/latency reports monitored | **Warning** | Crashlytics and Performance correctly initialised and correctly gated on `!kIsWeb`/`!kDebugMode` (`main.dart:112-135`) — real credit. `logger.dart:63` means non-fatals never arrive, so what is monitored is fatals only. `docs/DEPLOYMENT_GUIDE.md:436` documents two alert thresholds (app start > 5 s p95, HTTP > 3 s p95) as a **setup instruction**; whether they are configured is not verifiable from the repo. | Half the signal is missing. Mitigation: wire `logger.dart:63`. Owner: OWNER-TBD. Console verification is BLOCKED-OWNER. |
| PERF-10.04 Tested on a low-end target | **BLOCKED-OWNER** | No evidence of low-end/throttled testing in `docs/`. Matters more each round: image decode, catalog parse and 3–4 backdrop filters are exactly the class of problem invisible on a dev machine. | — |

### §11 Service levels and regression budgets *(new in v2.0)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-11.01 Named SLIs and measurable SLOs for critical journeys | **Fail** | No SLI/SLO document exists. `grep -rln "SLO\|error budget\|crash-free" docs/*.md` → only `DEPLOYMENT_GUIDE.md`, which contains two latency alert thresholds (`:436`) inside a console-setup instruction. No availability, correctness, crash-free or freshness indicators are named for any of the critical journeys (SOS, patient switch, payment, medication reminder). | Nothing defines "good enough", so no release can be judged against it. Mitigation: define SLIs for the four journeys above. Owner: OWNER-TBD. |
| PERF-11.02 Budgets include p50/p95/p99, not averages alone | **Warning** | Two p95 thresholds documented (`DEPLOYMENT_GUIDE.md:436`) — app start > 5 s p95, HTTP > 3 s p95. No p50, no p99, no per-journey budgets, and configuration unverified. Note the app-start threshold (5 s p95) is looser than PERF-1.01's own 2 s budget, which `splash_screen.dart:14` already violates by construction. | Tail latency invisible. Mitigation: extend to p50/p99 per journey and reconcile with the 2 s TTI budget. Owner: OWNER-TBD. |
| PERF-11.03 Hang/ANR/watchdog/memory-pressure/crash targets defined and monitored by release | **Fail** | None defined anywhere in `docs/`. `DEPLOYMENT_GUIDE.md:432` describes a velocity alert (fatal issue affecting > 0.1 % of users in 1 h) — an alert, not a per-release target. Non-fatals never reach Crashlytics (`logger.dart:63`), and no watchdog/hang instrumentation exists. Two of the three pre-`runApp` awaits (`main.dart:104`, `:179`) are un-timed and would present as a watchdog termination, unreported. | Launch hangs and OOM kills are invisible. Mitigation: define per-release targets; wire non-fatals. Owner: OWNER-TBD. |
| PERF-11.04 CI compares startup/interaction/memory/size against approved thresholds | **Fail** | `.github/workflows/ci.yml` runs: `flutter pub get`, `flutter analyze`, `bash scripts/check_design_consistency.sh`, `flutter test --coverage`, a coverage gate, and `flutter build web --release`. **No size budget, no startup benchmark, no memory check, no backend latency check.** This is why 40.5 MiB of dead assets survived four audit rounds — nothing in the pipeline can see them. | Regressions can only be caught by a human re-reading the repo. Mitigation: an artifact-size gate would have caught §8.01 on day one. Owner: OWNER-TBD. |
| PERF-11.05 Error budgets define when delivery pauses for reliability work | **Fail** | No error budget, no reliability-pause policy in `docs/`. The four-round trajectory of this checklist (blockers static while chrome work continued) is what the absence of such a policy looks like in practice. | Mitigation: adopt an error budget once 11.01 exists. Owner: OWNER-TBD. |

### §12 Load, capacity, and backpressure *(new in v2.0)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-12.01 Peak load, growth, quotas, storage growth, third-party limits documented with margin | **Fail** | `grep -rln -i "capacity\|peak load\|soak\|RPO\|RTO\|backpressure" docs/*.md` returns four files, none of which contains a capacity figure (the `ARCHITECTURE.md` hits at `:334` and `:366` are table headers). No Firebase quota analysis, no Razorpay rate-limit note, no on-device storage-growth budget — despite three stores that grow without bound (§3.03). Stated plainly: **unverified and undocumented**, not N/A. | Growth failure modes unowned. Mitigation: document device-storage growth first — it is the one this artifact controls. Owner: OWNER-TBD. |
| PERF-12.02 Load, spike, stress and soak tests over realistic payloads and large accounts | **Fail** | No load/soak harness in the repo; `flutter test` is unit/widget only (101 files). No test seeds an aged account. **Unverified**, stated plainly. | The O(days) wipe (F-1) and the unbounded orders blob are exactly what a soak test would surface. Mitigation: a seeded-aged-store test is cheap and would cover §13.04 too. Owner: OWNER-TBD. |
| PERF-12.03 Bounded concurrency, backpressure, dead-letter handling, recovery from partial completion | **Fail** | `sync_service.dart:96` — fixed-interval `Timer.periodic`, no bounded concurrency (a slow sync overlaps the next tick), no backpressure, no dead-letter path; both call sites discard outcomes via `.catchError` (`:92-94`, `:97-99`). No outbox anywhere (§7.05). F-1's unawaited `_adopt` is unbounded concurrency by construction — nothing limits how many can be in flight. | Overlapping syncs and overlapping wipes, both silent. Mitigation: an in-flight guard on both. Owner: OWNER-TBD. |
| PERF-12.04 Caches define freshness, invalidation, stampede protection, stale correctness | **Fail** | `CacheService` has freshness (`_ttlMinutes = 30`, `cache_service.dart:7`, `:51-54`) — that half is fine. Invalidation is absent: `get` returns `null` on expiry without removing (`:30`), so expired entries accumulate. No stampede protection: the 7 catalog sites each `rootBundle.loadString` + `jsonDecode` independently, which **is** a stampede by construction. Stale-behaviour correctness is not defined anywhere. | Mitigation: `remove` on expiry; one shared catalog future. Owner: OWNER-TBD. |
| PERF-12.05 Rate limiting, retry budgets, timeouts and breakers tested together | **Fail** | Retry exists (`api_service.dart:53-86`) but has no budget ceiling across calls; no client-level timeout (§4.04); no breaker (§7.06); no rate limiting. `test/services/api_service_test.dart` exercises retry in isolation; nothing tests the combination. **Unverified as a system**, stated plainly. | Retry storm against a recovering backend, amplified by `sync_service`'s fixed interval. Mitigation: retry budget + breaker + an integration test. Owner: OWNER-TBD. |

### §13 Device resource pressure *(new in v2.0)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-13.01 Energy and thermal impact measured on representative hardware | **BLOCKED-OWNER** | Needs Xcode Energy Log / Android Battery Historian on a physical device. Not derivable from source. The measurable inputs are known and named (3–4 permanent backdrop filters, fixed-interval sync, un-sized image decode). | — |
| PERF-13.02 Low-storage, disk-full, memory-warning, thermal-throttling, OS-reclamation behaviour tested without corruption | **Fail** | **Unverified — no such test exists.** Source shows the paths are unhardened: every `prefs.set*` return value is discarded (`store_migrator.dart:129`, `:176`, `:181`, `orders_provider.dart:205-206`, `cache_service.dart:19`), so a disk-full write failure is indistinguishable from success. `quarantine()` (`:204-222`) transiently **doubles** the footprint of the blob it is protecting, which is most likely to fail on exactly the low-storage device it is protecting (F-3). No `didHaveMemoryPressure` handler in `lib/`. | Silent local data corruption on a full device. Mitigation: check `prefs.set*` results; handle memory pressure by evicting `imageCache`. Owner: OWNER-TBD. |
| PERF-13.03 Quotas, cleanup rules and safe failure messages for files, caches, logs, temp artifacts | **Fail** | No quota or cleanup rule for: `daily_rating_*` (one key per day, forever — `my_care_screen.dart:614`); `housepital_cache_*` (never evicted — `cache_service.dart:30`); the per-patient orders/assessments blobs (unbounded, rewritten whole — `orders_provider.dart:201-211`); `__quarantine_v1_*` entries (written by `store_migrator.dart:208`, **never read and never deleted by any code path**). Failure messages: all of these fail to `Log.warn` → `debugPrint` (§7.01), i.e. no message at all in release. | Monotonic on-device growth with no ceiling and no user-visible failure. Mitigation: TTL every prefix; a support-triggered quarantine purge. Owner: OWNER-TBD. |
| PERF-13.04 Performance acceptable with realistic aged data, not only fresh accounts | **Fail** | **Unverified — and the source predicts it degrades.** `session_scope.dart:129-133` sweeps `prefs.getKeys()` and issues one **sequential awaited** `prefs.remove` per `daily_rating_*` key; M grows at one key per rated day (≈365/year), and F-1 runs the sweep **twice per switch**. `cache_service.dart:41-43` has the same shape. `orders_provider.dart:201-211` re-encodes the entire order history on every mutation. No test seeds an aged store; every test starts from `SharedPreferences.setMockInitialValues({})`. | A two-year-old install pays ≈1,460 sequential platform round trips per patient switch, with a fully interactive UI and no progress indicator. Mitigation: `Future.wait` over the removals **and** cap the key growth; delete the duplicate wipe. Owner: OWNER-TBD. |

### §14 Recovery and continuity evidence *(new in v2.0)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PERF-14.01 Backup restoration, failover, and recovery from corrupted/unavailable stores exercised, not only documented | **Fail** | A recovery *mechanism* exists and is well-designed — `StoreMigrator.quarantine()` (`:204-222`) plus the fail-and-retry loop (`:156-188`) — and `test/services/store_migrator_test.dart` exercises the loop via `debugSetMigrations`. But: (a) it covers only the two legacy global keys; the **live** per-patient keys have no quarantine (§7.05); (b) nothing reads `__quarantine_v1_*` back — there is no restoration path, documented or coded, so "support can recover a patient's order history" (`store_migrator.dart:63-64`) is an assertion no procedure backs; (c) no drill has been run on a device. **Documented, partially coded, never exercised.** | A quarantined history is preserved but unreachable. Mitigation: write the restoration procedure, or an in-app support export. Owner: OWNER-TBD. |
| PERF-14.02 RPO/RTO defined per critical data/service tier and verified by drills | **Fail** | `grep -rln -i "RPO\|RTO" docs/*.md` → no definitions. Patient-entered clinical data (`AppProvider._vitalsHistory`, `app_provider.dart:41`) is explicitly **in-memory only and never written to storage** — RPO for manually entered vitals is effectively "everything since app launch", undocumented and unaccepted. | Silent loss of patient-entered vitals on any process death. Mitigation: define RPO per store; persist or explicitly accept the vitals gap. Owner: OWNER-TBD. |
| PERF-14.03 Synthetic/scheduled probes verify the critical promise from outside the primary stack | **Fail** | No probe configuration anywhere in the repo. `AppConstants.apiBaseUrl = 'https://api.housepital.in/v1'` (`constants.dart:3`) does not resolve, so no probe could pass today; and because `logger.dart:63` is unwired and every provider falls back to `DemoData`, **the app renders a complete, plausible, entirely fabricated experience while its backend is absent** — the precise condition an external probe exists to catch. | The most important failure this product can have is currently invisible from both inside and outside. Mitigation: an uptime probe on `/v1/health` once a host exists; treat "demo mode in production" as a monitored condition. Owner: OWNER-TBD. |

---

## Scorecard

| Section | Pass | Warning | Fail | N/A | BLOCKED-OWNER |
|---|---|---|---|---|---|
| 1. Startup / first response | 1 | 0 | 2 | 0 | 0 |
| 2. Rendering & interaction | 0 | 1 | 3 | 0 | 0 |
| 3. Memory | 0 | 0 | 3 | 0 | 1 |
| 4. Battery, network & resource | 0 | 3 | 1 | 0 | 0 |
| 5. Data & query performance | 0 | 2 | 1 | 1 | 0 |
| 6. Concurrency & responsiveness | 0 | 1 | 3 | 0 | 0 |
| 7. Reliability & resilience | 0 | 4 | 2 | 0 | 0 |
| 8. Size & asset hygiene | 0 | 1 | 2 | 0 | 0 |
| 9. Accessibility-driven perf | 0 | 2 | 1 | 0 | 0 |
| 10. Measurement & evidence | 0 | 1 | 0 | 0 | 3 |
| 11. Service levels & regression budgets | 0 | 1 | 4 | 0 | 0 |
| 12. Load, capacity & backpressure | 0 | 0 | 5 | 0 | 0 |
| 13. Device resource pressure | 0 | 0 | 3 | 0 | 1 |
| 14. Recovery & continuity | 0 | 0 | 3 | 0 | 0 |
| **TOTAL (56)** | **1** | **16** | **33** | **1** | **5** |

**§1–§10 only, comparable to prior rounds (39 controls):** Pass 1 · Warning 15 · Fail 18 · N/A 1 · BLOCKED 4.
Round 3: 1 / 16 / 17 / 1 / 4. Round 2: 2 / 17 / 15 / 1 / 4. Round 1: 2 / 18 / 14 / 1 / 4.

Two grades moved within §1–§10, in opposite directions:

- **PERF-1.02 Warning → Fail.** Under v2.0 "Warning" requires a recorded mitigation and owner for a
  *residual* risk; this control's requirement ("defer or background it") is simply not met — four
  awaits and an eager five-tab shell sit ahead of the first frame. Round 3 graded it ⚠️ partly on
  credit for the migration work. The migration work is real (F-3) and is credited there; it does
  not satisfy this control.
- **PERF-1.01 stays Fail; PERF-2.01, 6.03, 7.05, 8.01, 9.03 stay Fail** on unchanged or worsened
  evidence.

**§11–§14 are graded for the first time: 1 Warning, 15 Fail, 1 BLOCKED-OWNER.** That is not a
regression — it is what happens when a client-only artifact with no SLOs, no perf CI, no capacity
work and no recovery drills is measured against a suite that requires them.

**Four-round trend, stated without spin:** on the comparable 39-control sheet the Fail count has
gone **14 → 15 → 17 → 18** while Pass has gone **2 → 2 → 1 → 1**. Payments were genuinely and
structurally fixed across rounds 1–3 and that mattered. Every other blocker on this checklist is
where round 1 left it, and each round's session/chrome work has added a little cost on top —
this round's addition being a second full storage wipe on every patient switch.

---

## Release blockers (every Fail)

Ordered by what I would fix first, not by control number.

1. **PERF-6.03 — the patient switch runs two wipes, the second detached, over re-entrant
   unguarded state.** `home_screen.dart:1767-1777`, `session_scope.dart:64-77`,
   `app_provider.dart:187-197`. F-1 and F-2. Cross-patient order/clinical bleed on a shared
   phone, reachable by a double tap or by a Home mount landing inside a switch. **The primary fix
   is a deletion** (`home_screen.dart:1774`) plus a `_switching` guard at both call sites and a
   sequence guard in `_adopt`. Also fixes 6.02, halves 5.04(c) and 13.04.
2. **PERF-8.01 — 241 files / 40.5 MiB of unreferenced images ship.** `pubspec.yaml:84-86`. Pure
   delete, `referenced-but-missing = 0`, largest single win, unchanged for four rounds. Correct
   `docs/KNOWN_ISSUES.md:34` in the same edit.
3. **PERF-7.01 — every non-fatal is invisible in release.** `logger.dart:63`. One line at a
   documented chokepoint. Without it, blockers 1, 5, 7 and 14 are all undetectable in the field,
   as is the migration's permanent-retry state (F-3).
4. **PERF-2.03 / 3.02 — full-resolution image decode on the catalog hot path.**
   `common_widgets.dart:108-140`. Up to 16 MB decoded per tile against a ~1 MB need; 0 `cacheWidth`
   repo-wide. Largest runtime-memory lever.
5. **PERF-2.01 / 9.03 — 3–4 permanent backdrop filters with no Reduce-Transparency escape.**
   `glass.dart:154-157`, `main_shell.dart:121` (σ 36), `assistant_fab.dart:34`,
   `demo_data_banner.dart:96`, `home_screen.dart:1741`. Permanence is caused by the
   `sourceOrders` latch (F-4). One condition in `GlassSurface.build` closes 9.03 outright.
6. **PERF-1.01 / 1.02 — TTI floored at 2 s by construction; four un-timed awaits before `runApp`.**
   `splash_screen.dart:14-18`; `main.dart:104`, `:130-134`, `:175`, `:179`, `:192`.
7. **PERF-7.05 — no write queue; false confirmations; the live per-patient read path has no
   quarantine.** `medication_provider.dart:164-181`, `orders_provider.dart:214-246`,
   `add_edit_medication_screen.dart:268-272`.
8. **PERF-5.04 / 6.01 — 864 KB parsed on the UI isolate at 7 sites; 18 unpooled, unclosed HTTP
   clients; 0 isolates.** `api_service.dart:41`, the 7 `rootBundle` sites.
9. **PERF-3.01 / 3.03 — leaks and unbounded caches.** `document_repository_screen.dart:47`, `:648`;
   `common_widgets.dart:16-17`; `cache_service.dart:30`; `my_care_screen.dart:614`.
10. **PERF-2.04 — un-debounced full-corpus rescan inside `build`, under a blurred app bar.**
    `universal_search_screen.dart:159`, `:261`, `:277`.
11. **PERF-4.04 — no request cancellation or client-level timeout.** `api_service.dart:53-86`.
12. **PERF-8.03 — fabricated clinical report compiled into the release binary.**
    `daily_report_screen.dart:40-87`.
13. **PERF-11.01 / 11.03 / 11.04 / 11.05 — no SLIs/SLOs, no hang/ANR/crash-free targets, no perf
    gate in CI, no error budget.** `.github/workflows/ci.yml`. 11.04 is the cheapest of the four
    and would have caught blocker 2 on day one.
14. **PERF-12.01 – 12.05 — no capacity documentation, no load/soak testing, no backpressure, no
    cache invalidation or stampede protection, no combined retry/timeout/breaker test.**
15. **PERF-13.02 / 13.03 / 13.04 — resource-pressure paths unhardened and untested; four stores
    with no quota or cleanup; performance degrades with install age by construction.**
16. **PERF-14.01 / 14.02 / 14.03 — quarantine has no restoration path, no RPO/RTO, no external
    probe; manually entered vitals are memory-only (`app_provider.dart:41`).**

## Warnings requiring risk acceptance

Each needs an approver, a ticket and a due date; owner is `OWNER-TBD` throughout because the repo
names none. Impact and mitigation are recorded per row in the control tables above.

PERF-2.02 (eager lists + eager five-tab shell) · PERF-4.01 (fixed-interval sync, no backoff) ·
PERF-4.02 (detached `_adopt` with no completion signal) · PERF-4.03 (7-site catalog, no coalescing) ·
PERF-5.02 (client-side N+1) · PERF-5.03 (partial timeout coverage) · PERF-6.04 (two unguarded
`setState`-after-`await`) · PERF-7.02 (pre-`runApp` window, now also un-timed) · PERF-7.03
(10-of-12 one-way demo latch; wrong-record substitution) · PERF-7.04 (freshness stamped on a demo
seed) · PERF-7.06 (no circuit breaker) · PERF-8.02 (directory asset declarations defeat
tree-shaking) · PERF-9.01 (one ungated animation controller) · PERF-9.02 (1.4× ceiling untested;
clinical string ellipsised) · PERF-10.03 (fatals only) · PERF-11.02 (p95 only, and looser than the
TTI budget).

**Owner-decision items, recorded as accepted risk and deliberately NOT graded Fail:** the floating
glass pill nav contributes one of the 3–4 per-frame `BackdropFilter` surfaces at σ 36 over 20,048 pt²
(`main_shell.dart:121`). White-on-orange and manpower pricing have no performance dimension. If the
owner wants the pill *and* wants the cost down, the two levers that do not touch the look are
(a) honour Reduce Transparency in `GlassSurface` — affects only users who asked for it — and (b) fix
the `sourceOrders` latch so the demo pill's filter disappears the moment a backend exists.

## BLOCKED-OWNER — needs access I do not have

| Item | Control | What I need |
|---|---|---|
| Backdrop-filter cost, `820060b` vs `9127713` | 10.01 | GPU/raster trace on a physical mid-range phone, Home tab, demo pill up. **Highest-value single measurement available.** |
| Profiler pass — CPU/memory/leaks | 10.01 | Xcode Instruments: Time Profiler on cold launch (2 s splash floor, four pre-`runApp` awaits, eager five-tab shell, one-shot demo-flip relayout); Allocations while scrolling the equipment catalog |
| Startup/interaction/memory measured | 10.02 | Firebase Performance console — traces should already be collecting (`main.dart:132-134`) |
| Low-end target run | 10.04 | An older Android device / throttled network |
| Memory returns to baseline | 3.04 | Instruments Allocations across launch → full catalog scroll → back out |
| Energy and thermal | 13.01 | Xcode Energy Log / Battery Historian on a physical device |
| `SessionScope` wipe duration | (evidence for 13.04) | A patient switch, timed, on a device carrying ~1 year of `daily_rating_*` keys — now ×2 per F-1 |
| Whether the p95 alerts at `DEPLOYMENT_GUIDE.md:436` are configured | 10.03, 11.02 | Firebase console access |
| Live storage-rules posture | (cross-module) | `firebase deploy --only storage` status — unverifiable from the repo |

## Limitations of this audit

- **MASTER-4.04 is not satisfied and I want that stated plainly.** This is a **source review** of a
  git working tree, not evidence from a release artifact in a production-like environment. Every
  runtime number in this report is either arithmetic over source constants (blur geometry, asset
  bytes, round-trip counts) or engine behaviour reasoned from Flutter/Skia semantics. **Nothing here
  is a profiler reading.** Where a control's answer requires one, I graded BLOCKED-OWNER rather than
  Pass or N/A.
- Per the brief I did not run `flutter test`, `flutter build`, `flutter clean` or `pod install`, so
  I did not build the release artifact, could not measure IPA/AAB size directly, and read test
  **sources** rather than results. The 40.5 MiB figure is the on-disk size of files that
  `pubspec.yaml:84-86` guarantees are bundled; the compressed-in-artifact figure will differ and
  needs a real build.
- I re-verified `ANTHROPIC_API_KEY` absence is out of my module's scope and did not re-litigate it.
- `../housepital-backend` and `../housepital-api` were not audited for §12/§14 server-side posture.
  The app is connected to neither, so their capacity and DR characteristics cannot affect this
  artifact's behaviour today; I graded the client half on evidence and marked the rest BLOCKED-OWNER
  rather than claiming the controls are satisfied or inapplicable. A backend module should own them.
- Concurrency findings F-1 and F-2 are derived by tracing call graphs and Dart's single-threaded
  event-loop semantics. F-1's duplicate execution is unconditional and provable from the source
  alone. F-2's interleaving is a reachable schedule, not an observed one — `SessionScope` is
  imported by **zero** tests (`grep -rn "session_scope.dart" test/` → 0), so no existing test could
  have observed it either. **Two integration tests would settle both**, and their absence is itself
  a finding.
