# Performance & Reliability Checklist (App-Agnostic) — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Method:** static only — `python3` asset measurement, `git grep` across refs, Flutter SDK source
reading (`/opt/homebrew/share/flutter`) to settle element-lifecycle claims, code reading.
No `flutter test` / `build` / `clean` run by me. Central results cited per the brief:
`flutter analyze` clean, design gate passes, 1,813 tests pass.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **B-1 · second unguarded payment path** (`billing_screen` "Pay Now" → `openCheckout`, no `createOrder`) | ❌ blocker | ✅ **GENUINELY FIXED — and fixed structurally** | `billing_screen.dart:315-322` now `Navigator.pushNamed(context, '/payment', …)`. `billing_screen.dart` no longer imports `payment_service.dart` at all. `grep -rn "payment_service.dart" lib/` → **one importer**: `payment_screen.dart:11`. `grep -rn "openCheckout" lib/` → **one call site**: `payment_screen.dart:263`. See §"Adversarial review" A-1. |
| **`StoreMigrator.run()` can throw before `runApp`** | ❌ blocker (new in R2) | ✅ **FIXED for `StoreMigrator`** — ⚠️ the *window* is still open | `store_migrator.dart:56-67` — whole body delegated to `_run()` inside `try/catch`. Catch calls `Log.error`, which reaches `debugPrint` only (`logger.dart:52-66`) and cannot throw. But `main.dart:103` `Firebase.initializeApp` and `main.dart:178` `MedicationReminderService().init()` are still unguarded awaits in the same pre-`runApp` window. A-2. |
| **40.3 MiB / 238 dead product images** | ❌ | ❌ **UNCHANGED — independently re-measured, byte-identical** | 439 files / 77.4 MiB total; 201 referenced = 37.1 MiB; **238 unreferenced = 40.3 MiB**; referenced-but-missing = 0. `pubspec.yaml:85` still declares the directory. |
| **No `cacheWidth` anywhere** | ❌ | ❌ **UNCHANGED** | `grep -rn "cacheWidth\|cacheHeight\|ResizeImage\|memCacheWidth\|imageCache" lib/` → **0**. `common_widgets.dart:124-140` `ProductImage` unchanged. |
| **`logger.dart:63` unwired TODO** | ❌ | ❌ **UNCHANGED, verbatim** | `logger.dart:63-65`; `_log` still ends at `debugPrint` (`:59-62`). |
| **`ApiService` no singleton / no timeout / 18 sites** | ❌ | ❌ **UNCHANGED — the set is byte-identical** | `diff` of `git grep -n "ApiService()" 820060b -- lib` vs `HEAD` → **one line differs, and only by line number** (`main.dart:182`→`:183`). Still 18 sites, no `factory`, no `close()`. |
| **862 KB catalog on UI isolate at 7 sites** | ❌ | ❌ **UNCHANGED** | 7 `rootBundle.loadString('assets/equipment_catalog.json')` sites (`assistant_local_actions:39`, `universal_search_screen:149`, `package_detail_screen:35`, `medications_screen:354`, `equipment_detail_screen:138`, `equipment_tab:72`, `doctor_advice_card:55`). File is **864,311 bytes**. `grep "compute(\|Isolate\." lib/` → **0**. |
| **`requestRefill` cannot return false** | ❌ | ❌ **UNCHANGED** | `medication_provider.dart:165-180` — `_refillRequestedIds.add` + `return true` still outside the `try`. |
| **`CacheService` never evicts** | ❌ | ❌ **UNCHANGED, and the unbounded surface grew** | `cache_service.dart:30` `_isExpired` → `return null`, no `remove`. New neighbour: `daily_rating_YYYY-MM-DD` keys (`my_care_screen.dart:593`, `:614`) — **one key per rated day, forever**, pruned only by `SessionScope`. See A-4. |
| **Corrupt persisted orders silently wipe** | ❌ | ❌ **UNCHANGED** | `orders_provider.dart:197-200` — demo seed still inside the `try`, above the throw point. |
| **Undisposed `TextEditingController`** | ❌ | ❌ **UNCHANGED** | `document_repository_screen.dart:47`; `grep -n dispose` on the file → **0 hits**. |
| **2 s hard-coded splash delay** | ❌ | ❌ **UNCHANGED** | `splash_screen.dart:14-19`. |
| **Reduced-motion gap on the one ungated controller** | ❌ | ❌ **UNCHANGED** | `equipment_detail_screen.dart:1689-1696` (250 ms, no gate), `_toggle` `:1704-1713`. 7 `AnimationController(` in `lib/`, 11 files reference `disableAnimations`. |
| **No high-contrast / reduce-transparency handling** | ❌ | ❌ **UNCHANGED, and materially WORSE** | `grep "highContrast\|boldText\|accessibleNavigation\|disableAnimations"` in `glass.dart` + `theme.dart` → **0**. Blur surfaces per frame **doubled**: see the headline finding below. |
| **Overflow suite never exercises 1.4× textScaler** | ❌ | ❌ **UNCHANGED** | `grep -rn textScaler test/` → **0**. |
| **Four unused deps** | ❌ | ❌ **UNCHANGED** | `dio`, `go_router`, `flutter_svg`, `cupertino_icons` → 0 `package:<name>/` imports in `lib/`. |
| **Silent demo fallback invisible / one provider clears for all** | ⚠️ | ⚠️ **IMPROVED in shape, INVERTED in failure mode** | `demo_mode.dart:36-66` is now a `Set` — a source may only clear itself. But `markServingLiveData` has **exactly one call site** (`app_provider.dart:273`, dashboard). The other **10 sources can never be lowered**. A-3. |
| **`DemoMode.reset()` global, called by one provider** | High (new in R2) | ✅ **FIXED** | `demo_mode.dart:57-62` — `reset()` is now `@visibleForTesting` and has **zero production call sites** (`grep "DemoMode.reset" lib/` → 0). |
| **Three demo fallbacks never set the flag** | High | ✅ **FIXED** | `blog_provider.dart:40`/`:70` (`sourceArticles`), `app_provider.dart:142` (`sourcePatientIdentity`), `handover_report_service.dart:105` (`sourceHandover`) all now mark. |
| **`main.dart:395` root `watch<AppProvider>()` for `locale` alone** | ⚠️ | ⚠️ **UNCHANGED** | Now `main.dart:397` `context.watch<AppProvider>()`, read only at `:407` for `locale`. Still a `select` away. |
| **`SessionScope` bounded, amplified by IndexedStack** | ⚠️ (credit) | ❌ **REGRESSED** — the notification count is fine; the new `await` is not | `session_scope.dart:65-68` now awaits two async stores. The rebuild analysis from R2 still holds, but the awaits opened a re-entrancy hole and an O(days) storage loop. A-4, A-5. |
| **`_DemoDataBanner` rebuild scope correctly narrow** | ✅ (credit) | ⚠️ **Scope is still narrow; the widget MOVED and the move has costs** | Banner left `main_shell.dart` for `MaterialApp.builder` (`main.dart:434`, `demo_data_banner.dart:28-55`). Per-frame rebuild scope is still correct. But the flip now re-parents the whole app subtree once, and adds a 4th backdrop filter permanently. A-3, headline finding. |
| **`delete_account_screen.dart`** | ✅ | ✅ **UNCHANGED** | No perf/reliability defect found. |
| **`BillingProvider` has zero listeners** | Medium | ❌ **UNCHANGED** | Still provided (`main.dart`), still watched by nothing; `clearPatientScopedData` notifies nobody. |
| **`my_care_provider` `_lastFetchedAt` set while seeding demo** | ⚠️ | ⚠️ **UNCHANGED** | `my_care_provider.dart:47-53` — `_lastFetchedAt = DateTime.now()` inside the demo-seed branch; `isStale` (`:36-38`) reports false for 60 s off a demo seed. |
| **Unguarded `setState` after `await`** | ⚠️ | ⚠️ **UNCHANGED** | `daily_report_screen.dart:31-36`, `notifications_screen.dart:32-35`. |
| **Large hardcoded sample data in a production screen** | ❌ | ❌ **UNCHANGED** | `daily_report_screen.dart:40-87` — ~47 lines of fabricated clinical report, still inside the `catch`. |
| **`PaymentService` leaked when checkout abandoned** | Medium | ✅ **FIXED** | The leaking construction (`billing_screen.dart:304`) is gone. The surviving one is State-owned and disposed: `payment_screen.dart:216` created in `_initPaymentService`, `:165` `_paymentService?.dispose()` in `dispose()`. |

**Nothing else regressed by measurement.** Three round-2 items got genuinely better
(B-1, `DemoMode.reset`, the `PaymentService` leak) and one got genuinely worse
(`SessionScope`, below).

---

## Round-2 repairs: adversarial review

These are the fixes-of-fixes. I read each one against the failure it claims to close.

### A-1 · The payment fix is real, and it is the right *kind* of fix — ✅

Round 2's headline was that `billing_screen`'s "Pay Now" was a second `openCheckout` caller
with no `createOrder`. The repair did not just add a guard to that button; it **deleted the
button's ability to reach the payment machinery at all**:

- `grep -rn "openCheckout" lib/` → **1 call site**: `payment_screen.dart:263`.
- `grep -rn "razorpay_flutter" lib/` → **1 import**: `payment_service.dart:2`.
- `grep -rn "payment_service.dart" lib/` → **1 importer**: `payment_screen.dart:11`.

So `PaymentService` is unreachable from anywhere except `PaymentScreen`. That is a structural
invariant, not a code-review convention, and it is what makes "exactly one path" checkable by
grep rather than by memory. **I hunted for a third path and there is none:** the only other
route into checkout is `'/payment'`, pushed from `cart_screen.dart:564`,
`invoice_detail_screen.dart:136`, and `billing_screen.dart:317`, all of which land on the same
guarded `PaymentScreen`. The route handler validates its arguments and rejects malformed ones
(`main.dart:521-533`, `_argErrorRoute()`).

**Does the single path always carry a backend `order_id` with a real key?** Yes, and the guard
is on the correct axis:

```
payment_screen.dart:234-259
  if (!PaymentService.isDemoPayments) {
     patientId == null            → orderId stays null
     createOrder(...)             → may return null on API failure
     if (orderId == null) { fail closed, "Nothing has been charged", return; }
  }
  _paymentService!.openCheckout(orderId: orderId, ...)
```

The gate is `PaymentService.isDemoPayments` (`payment_service.dart:52`), which is
`_placeholderKeys.contains(AppConstants.razorpayKey)` — a *positive* whitelist of two
placeholders. Any other key, including an empty/misconfigured one, takes the **real** arm and
therefore requires an `order_id`. That fails safe in the right direction: a build with no key
cannot silently reach the unverifiable branch. The `patientId == null` case also fails closed
(`:236-237`) — I checked specifically, because that is the kind of null that usually leaks
through.

**Two residual notes, neither a blocker:**
1. `openCheckout`'s own signature still accepts `String? orderId` and still builds
   `'order_id': ?orderId` (`payment_service.dart:135`), which drops the key when null. The
   service does not enforce the invariant its only caller now honours. If a second caller ever
   appears, nothing in `PaymentService` stops it. A two-line assert
   (`assert(isDemoPayments || orderId != null)`) or a required non-null parameter on the
   real-key arm would make the invariant local instead of remote.
2. There is **no test that locks the invariant**. `test/services/payment_service_test.dart`
   exercises `openCheckout` extensively but nothing asserts "only one production call site" or
   "billing does not import payment_service". This fix is exactly the class of thing that gets
   re-broken by the next person who adds a Pay button.

The `_pendingVerification` state is also real, not cosmetic: `payment_screen.dart:53`,
set at `:291` from `message.contains('under verification')`, and branched on at `:473`, `:478`,
`:491`, `:499`, `:611` so the charged-but-unverified case renders as a warning with a contact
path rather than red "Failed" + Retry. The string-matching coupling between
`payment_service.dart:181`/`:187` and `payment_screen.dart:290` is brittle — a reworded message
silently reverts the screen to "Payment Failed" — but the behaviour today is correct.

### A-2 · `StoreMigrator` is throw-safe. The black-screen window is not closed. — ⚠️

The claim checks out for `StoreMigrator` itself. `run()` (`store_migrator.dart:56-67`) is now a
thin wrapper: **everything** — including `SharedPreferences.getInstance()` (`:70`), every
`prefs.setInt` (`:76`, `:123`, `:128`, `:134`), `prefs.getKeys()` (`:140`) and `quarantine`
(`:151-169`) — lives inside `_run()`, which is called inside the `try`. I traced each of round
2's three named escape points (`:64`, `:71`, `:117` in the old numbering) and all three are now
enclosed.

**The logger call inside the catch cannot escape either** — I checked this specifically because
it is the classic way a "whole body wrapped" fix still throws. `Log.error` →
`Log._log` (`logger.dart:52-66`) does a `kReleaseMode` check, string interpolation, and
`debugPrint`. No I/O, no platform channel, no Crashlytics call (that is still the unwired TODO
at `:63`). It cannot throw for any input reachable here. ✅

**But the finding round 2 actually raised was "an exception in the pre-`runApp` window is a
permanent black screen," and that window still contains two unguarded awaits:**

- `main.dart:103` — `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
- `main.dart:178` — `await MedicationReminderService().init()` (guarded only by `!kIsWeb`)

Both are before `runApp` (`main.dart:191`). `runZonedGuarded` (`:100`) catches them into
Crashlytics, `ErrorWidget.builder` (`:139`) cannot help because no widget tree exists yet, and
the user gets the same permanent black screen for the same reason. The repair fixed the
instance, not the class. **The general fix is one line:** move `runApp` above these
initialisations, or wrap the whole init block and call `runApp` unconditionally in a `finally`.

I am re-grading §7's "global error boundary" from ✅ to ⚠️ on this basis. To be explicit: **the
underlying facts did not change this round** — this is a re-grade, not a regression. Round 2
recorded it as a caveat under a ✅; having now seen a concrete crash land in that window and be
fixed one call at a time, a caveat undersells it.

### A-3 · The `Set` fixed over-clearing by making under-clearing permanent — ⚠️, and it is why the second blur is always on

`demo_mode.dart:11-20` states the design intent precisely, and diagnoses the two prior failures
correctly: "`AppProvider` lowered it the moment the DASHBOARD recovered… Conversely
`MyCareProvider` raised it and never lowered it, so a healthy backend showed a permanent false
alarm."

The repair fixed the first half. It did not fix the second.

```
grep -rn "markServingLiveData" lib/  →  app_provider.dart:273   (sourceDashboard)   [1 site]
grep -rn "markServingDemoData"  lib/ →  11 sites across 6 providers + 1 service
```

Eleven source constants are declared (`demo_mode.dart:24-34`). **Exactly one of them can ever
be cleared.** In particular `sourcePatientIdentity` is raised at `app_provider.dart:142` when
`_patients.isEmpty`, and when the API subsequently returns real patients at `:151-159` the
provider replaces `_patients` and `_currentPatient` — and never calls `markServingLiveData`. So
against a working backend the notice states "Sample data — not your live record" over a screen
showing the patient's real name, for the rest of the process lifetime. That is the exact
permanent-false-alarm failure the file's own doc comment says it exists to prevent.

This is not only an honesty bug. It is the reason the second `BackdropFilter` in the headline
finding is unconditional: `DemoMode.isServingDemoData` is a **one-way latch**, so
`DemoDataBannerHost` renders its `Stack` + glass pill for every user, on every route, for the
whole session, backend or no backend.

**One more thing I checked, and it is good news:** because the latch is one-way, there is no
flip-flop. `_sync()` (`:64-66`) writes a `ValueNotifier<bool>`, which only notifies on an actual
value change, and `markServingDemoData` only calls `_sync()` when `Set.add` returns true
(`:47`). So the app-subtree re-parent described below happens **at most once per launch**, not
once per provider refresh. Had `markServingLiveData` been wired for all eleven sources without
also addressing the widget-swap, a flaky network would have re-parented the entire app on every
5-minute `sync_service` tick (`sync_service.dart:96`).

### A-4 · `SessionScope`'s new `await` chain is O(days-since-install) and runs sequentially — ❌

`session_scope.dart:65-68` now awaits two async stores. Cost, traced call by call:

| Step | Calls | Notes |
|---|---|---|
| `RemindersProvider.clearPatientScopedData()` (`reminders_provider.dart:194-204`) | 1 × `getInstance` + 1 × `remove` | awaited |
| `CacheService.clear()` (`cache_service.dart:38-44`) | 1 × `getInstance`, 1 × `getKeys()`, **N × `await prefs.remove(key)` in a sequential `for`** | N = `housepital_cache_*` entries |
| `SharedPreferences.getInstance()` (`session_scope.dart:86`) | 1 | cached after first call |
| loose keys (`:87-89`) | 1 × `remove` | |
| `prefs.getKeys().toList()` + `daily_rating_*` sweep (`:91-95`) | 1 × full key scan + **M × `await prefs.remove(key)` sequentially** | |

**M is unbounded and grows at one key per day.** `my_care_screen.dart:593` builds
`daily_rating_$y-$m-$d` and `:614` writes it with `prefs.setInt`. Nothing else in `lib/`
references the prefix except this sweep — so on a phone in daily use for a year, M ≈ 365; two
years, M ≈ 730. Every one of them is a separate `await` on a platform-channel round trip, run
strictly one after another. Even at a conservative 0.05–0.2 ms per round trip that is **tens of
milliseconds of pure event-loop churn**, entirely avoidable: `SharedPreferences` exposes no
batch remove, but `await Future.wait(keys.map(prefs.remove))` collapses M sequential round trips
into M concurrent ones, and `CacheService.clear()`'s loop has the same shape and the same fix.

**Does it block the UI?** Not in the "jank on the raster thread" sense — these are awaits, so
the event loop keeps turning and frames keep being produced. The problem is the opposite and
worse: **nothing tells the user anything is happening, and the UI stays fully interactive
during the gap.**

```dart
// home_screen.dart:1767-1777
onTap: () async {
  final nav = Navigator.of(context);
  await SessionScope.clearPatientData(context);   // ← unbounded gap, no guard
  app.switchPatient(patient);
  nav.pop();
},
```

The bottom sheet stays open, the old patient still shows the ✓, every row is still tappable,
and there is no spinner, no `_busy` flag, and no `AbsorbPointer`. §3 of the checklist calls this
"long operations are cancellable and cancelled on navigation/teardown"; §6 calls it "shared
mutable state protected (no races in read-modify-write)." It fails both.

### A-5 · The same `await` creates a reachable double-tap defect that pops the wrong route — ❌ **new in round 3**

Because the handler above is unguarded, tapping two rows (or one row twice) inside the gap runs
the sequence twice:

1. Tap B → `clearPatientData` in flight.
2. Tap C → a **second** `clearPatientData` starts, interleaved with the first. Both mutate the
   same six providers and the same prefs store; the wipes are not idempotent with respect to
   each other's ordering, and `app.switchPatient` will be called twice with different patients.
3. Run 1 finishes → `switchPatient(B)` → `nav.pop()` closes the sheet.
4. Run 2 finishes → `switchPatient(C)` → `nav.pop()` **on a `NavigatorState` captured before the
   sheet existed**, with the sheet already gone. It pops whatever is now topmost — `MainShell`,
   which `splash_screen.dart:16-18` installed via `pushReplacementNamed`, i.e. the first route.

The final patient is C, but the user is left on a popped root. The wider the storage gap, the
easier it is to hit — and A-4 says the gap grows with the age of the install.

**The identical pattern is in the logout dialog** — `settings_screen.dart:455-463`: an
`ElevatedButton.onPressed` that is `async`, awaits `SessionScope.clearSession` *and*
`auth.logout()`, then `nav.pop()`, with no in-flight guard and no disabled state. Double-tapping
Logout runs the whole wipe twice and pops twice.

Both were synchronous handlers before the round-2 repair. **This is a genuine case of a round-2
repair introducing a new defect**, and it is the one I would fix first after the blockers: a
`bool _switching` guard plus a disabled/spinner state is a few lines in each of the two call
sites.

---

## Headline finding: blur surfaces per frame have DOUBLED, and the second pair is permanent

This is the new per-frame cost the brief asked me to assess. I measured what I could and
reasoned the rest explicitly.

### What is actually on screen

`grep -rn "BackdropFilter\|ImageFilter.blur" lib/` returns two *definitions* —
`glass.dart:156-157` (`GlassSurface`, used by `GlassAppBar` and directly) and
`assistant_fab.dart:34-35`. The number that matters is **instances composited per frame**, and
that is not two:

| Surface | File:line | σ | Present when |
|---|---|---|---|
| `GlassAppBar` → `GlassSurface` | `glass.dart:70`, `:156` | 24 | 46 screen files use `GlassAppBar`; all five root tabs do |
| `AssistantFab` | `assistant_fab.dart:34` | 24 | every root tab (`main_shell.dart:64`) |
| **Nav pill** → `GlassSurface` | `main_shell.dart:109-115` | **36** | every root tab, permanently |
| **Demo pill** → `GlassSurface` | `demo_data_banner.dart:96` | 24 (default) | **every route**, and permanently — see A-3 |

**At `820060b` there were two.** `git grep "BackdropFilter\|sigma:" 820060b -- lib` returns only
`assistant_fab.dart:34` and `glass.dart:156`; the round-2 nav bar was
`Material(color: context.hc.orange)` with no blur, and the round-2 demo banner was an opaque
strip. So `d439928`/`6d4abcb`/`9a80fe2` plus the banner move took the count from **2 → 4** on
every root tab, and from **1 → 2** on every pushed screen.

### The area, measured

On a 390×844 pt device at DPR 3 (iPhone 13/14 class — a fair "mid-range target" for this app's
Delhi NCR audience, which skews older/Android but the geometry is comparable):

| Surface | Footprint | pt² |
|---|---|---|
| `GlassAppBar` | 390 × (47 status + 56 toolbar) | 40,170 |
| Nav pill | (390 − 32) × (56 + 8 padding) | 22,912 |
| Demo pill | ≈ 259 × 29 (12 px w600 label + icon + padding) | ≈ 7,500 |
| `AssistantFab` | ClipOval Ø56 | 2,463 |
| **Total blurred** | | **≈ 73,045 pt² = 657,405 device px²** |
| Screen | 390 × 844 | 329,160 pt² |

**≈ 22 % of the screen sits under a backdrop blur on a root tab in the app's default state**,
split across four separate regions. At `820060b` the equivalent figure was ≈ 13 % across two
regions.

### Why the *count* matters more than the σ bump

The σ 24→36 change is the smaller half of this. Skia and Impeller both implement large-σ
Gaussians as downsample → small-kernel blur → upsample, so cost is markedly sublinear in σ; 36
over 24 is a modest increase on the pill's 22,912 pt².

The expensive part is per-`BackdropFilter` and **independent of σ**: a backdrop filter has to
read back what is already painted beneath it. In Flutter's layer tree,
`BackdropFilterLayer` registers a readback region, which (a) expands the partial-repaint damage
rect so any damage intersecting the region forces the filter to re-rasterize, and (b) on a
tile-based mobile GPU forces the current render pass to be flushed and resolved to a texture
before the filter can sample it. **Four filters = four such flushes per frame, in four different
places in the paint order** (top chrome, mid-screen pill, FAB, bottom pill). Doubling the number
of render-pass breaks is a structurally worse change than making one existing blur stronger.

Two concrete consequences I can point at in this codebase:

- `universal_search_screen.dart:277` — `onChanged: (v) => setState(() => _query = v.trim())`
  rebuilds the whole `Scaffold` on **every keystroke**, and its `TextField` lives *inside* the
  `GlassAppBar` (`:270-292`). Every keystroke therefore dirties the app-bar readback region and
  re-rasterizes its blur, on top of the un-debounced full-corpus rescan at `:261`/`:159`. That
  screen was already the worst interaction path in the app; it now has one more blur above it
  (the demo pill sits at `padding.top + kToolbarHeight + 4`, directly below the search field).
- The nav pill adds, beyond the blur: a `BoxShadow` with `blurRadius: 24` on a 358×64 rounded
  rect (`main_shell.dart:102-106`), a `ClipRRect` (`glass.dart:154`), and **two** stacked
  `DecoratedBox` fills (`glass.dart:158`, `main_shell.dart:116-124`). Five paint ops for one
  bar. The `ClipRRect` is correctly *outside* the `BackdropFilter`, which bounds the blur to the
  pill — that part is right and should stay.

**Reduce Transparency is still not honoured anywhere** (`grep "highContrast\|boldText\|
accessibleNavigation"` across `glass.dart` + `theme.dart` → 0). A user who turns it on to make
the app cheaper and more legible gets four unconditional blurs instead of two. The one-line fix
is a `MediaQuery.of(context).highContrast ||
MediaQuery.of(context).accessibleNavigation` check inside `GlassSurface.build` that returns an
opaque `DecoratedBox` instead of the `BackdropFilter` — it would fix all four sites at once,
because all four go through `GlassSurface` or are trivially convertible.

**BLOCKED-OWNER for the actual number.** Everything above is geometry and engine behaviour, not
a measurement. What settles it: DevTools timeline / Xcode Instruments GPU trace on a real
mid-range device, scrolling Home with the demo pill up, comparing `9a80fe2` against `820060b`.
That is a 20-minute A/B and it is the single most useful measurement anyone could take on this
app right now.

### Does the overlay `Stack` force a repaint of the whole app subtree?

**Per frame: no.** I traced this carefully because it is the obvious worry.

- `DemoDataBannerHost` (`demo_data_banner.dart:34-54`) returns `child` when not serving, and
  `Stack(children: [child, Positioned(...)])` when serving. The `Stack` is `StackFit.loose`, but
  `RenderStack` sizes to `constraints.biggest` and the Navigator's `_RenderTheatre` takes
  `constraints.biggest` too, so the app still fills the screen. **The doc claim "displaces
  nothing" is correct** — I could not construct a case where the overlay changes another
  screen's layout.
- When `MaterialApp` rebuilds for an unrelated reason (e.g. `main.dart:397`'s
  `context.watch<AppProvider>()`, or a keyboard-driven `MediaQuery` change), `WidgetsApp`
  passes the *same* `routing` widget instance into `builder`. `Element.updateChild` has an
  identical-widget fast path (`framework.dart:4014` — `if (hasSameSuperclass && child.widget ==
  newWidget)`) that skips the subtree entirely. So the overlay does **not** amplify the existing
  root-rebuild finding. Good.
- The pill itself is static — no controller, no animation — so it does not dirty anything after
  first paint.

**On the flip (`false → true`): yes, once, and it is not free.** The widget at that slot changes
runtimeType from `FocusScope` to `Stack`, so the old element subtree is deactivated and a new
one inflated one level deeper. The app survives this only because
`WidgetsApp` gives its `Navigator` a `GlobalKey` (`app.dart:1696` `key: _navigator`, assigned
from `widget.navigatorKey` at `:1513` — and this app *does* pass one, `main.dart:402`
`navigatorKey: HousepitalApp.navigatorKey`), so global-key reparenting reclaims the deactivated
element in the same build phase and `NavigatorState` plus every route survives. The costs that
do land:

1. `StatefulElement.activate()` calls `markNeedsBuild()` unconditionally (`framework.dart:6018`)
   — the `Navigator` rebuilds.
2. The render subtree is detached and re-attached, forcing a **full relayout and repaint of the
   entire app** on that frame.
3. The unkeyed `FocusScope` wrapper is destroyed and recreated, so focus attachments below it
   re-parent. If the flip lands while a text field is focused, focus behaviour is not
   guaranteed.

Because `markServingDemoData` fires from provider loads immediately after the first frame
(`app_provider.dart:142` runs on `loadPatients`, which the Home screen mounts), **this
full-app relayout lands squarely inside the cold-launch window** — the most jank-sensitive
moment in the app's life, and the one already carrying the 2 s splash floor, the five-screen
eager `IndexedStack`, and the un-`cacheWidth`'d catalog decode.

It happens **once**, for the reason in A-3 (the latch is one-way), so this is a startup-cost
finding rather than a steady-state one. **The fix is one line and removes it entirely:** keep the
`Stack` in the tree unconditionally and swap only the *pill* for a `SizedBox.shrink()`:

```dart
return Stack(children: [
  child,
  if (serving) Positioned(top: …, child: const Center(child: _DemoDataPill())),
]);
```

The slot then always holds a `Stack`, the app subtree is never re-parented, and the overlay's
"displaces nothing" property is unaffected.

### Overlay-occlusion vs the displacement it replaced (the brief's explicit question)

The brief asks whether the overlay's known occlusion of Settings content is better or worse
than the layout displacement it replaced. **On the axis this checklist owns, the overlay is
clearly better and the occlusion is the cheaper of the two failures.** The strip version
(`820060b`, `main_shell.dart:132-170`) changed the `Column`'s layout on flip, which shortened
the `Expanded(IndexedStack)`'s constraints and **relaid out all five tabs** — a layout-dependency
that also meant every screen's inset maths had to know whether the banner was up. The overlay
has no layout dependency at all; its only structural cost is the one-shot re-parent above, which
is itself removable with the one-line change. Occluding a strip of Settings content is a design
defect with a design fix (an inset on that one screen, or moving the pill to the bottom edge);
displacement was an architectural coupling. Do not go back.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A | BLOCKED |
|---|---|---|---|---|---|
| 1. Startup / first response | 1 | 1 | 1 | 0 | 0 |
| 2. Rendering & interaction | 0 | 1 | 3 | 0 | 0 |
| 3. Memory | 0 | 0 | 3 | 0 | 1 |
| 4. Battery, network & resource | 0 | 3 | 1 | 0 | 0 |
| 5. Data & query performance | 0 | 2 | 1 | 1 | 0 |
| 6. Concurrency & responsiveness | 0 | 1 | 3 | 0 | 0 |
| 7. Reliability & resilience | 0 | 4 | 2 | 0 | 0 |
| 8. Size & asset hygiene | 0 | 1 | 2 | 0 | 0 |
| 9. Accessibility-driven perf | 0 | 2 | 1 | 0 | 0 |
| 10. Measurement & evidence | 0 | 1 | 0 | 0 | 3 |
| **TOTAL (39 items)** | **1** | **16** | **17** | **1** | **4** |

Round 2: ✅2 / ⚠️17 / ❌15 / N/A1 / BLOCKED4. Round 1: ✅2 / ⚠️18 / ❌14 / N/A1 / BLOCKED4.

Three grades moved, all downward, and **none of them because a round-2 fix failed**:

- **§2 "smooth scroll/animation" ⚠️ → ❌.** Blur surfaces per root-tab frame went 2 → 4; the
  static risk is no longer a partial. Measurement is still BLOCKED-OWNER; the grade reflects
  known cost added with no measurement taken.
- **§6 "shared mutable state protected" ⚠️ → ❌.** A-5: two unguarded async handlers with a
  reachable double-tap race, both introduced by the round-2 `await`.
- **§7 "global error boundary" ✅ → ⚠️.** A-2, and I want to be plain that **the facts here did
  not change this round** — this is a re-grade of a round-2 caveat, not a regression.

The trend is worth stating without spin: three rounds, and the ❌ count has gone 14 → 15 → 17
while the ✅ count has gone 2 → 2 → 1. Payments got genuinely and structurally fixed across
rounds 1–3, and that mattered. Every other blocker on this checklist is exactly where round 1
left it, and each round's chrome work has added a little cost on top.

---

## Findings

### 1. Startup / first response

- ❌ **Time-to-interactive still floored at 2 s** — `splash_screen.dart:14-19`,
  `Future.delayed(const Duration(seconds: 2))` then `pushReplacementNamed('/home')`. Unchanged
  through three rounds. **Fix:** race the delay against real readiness.
- ⚠️ **Heavy work blocking startup** — `StoreMigrator` is now genuinely cheap *and* safe
  (A-2), which is real progress. Still serialised ahead of `runApp` (`main.dart:191`):
  `Firebase.initializeApp` (`:103`), four awaited Crashlytics/Performance setters (`:122-134`),
  `MedicationReminderService().init()` (`:178`), `StoreMigrator.run()` (`:174`), and then the
  five-screen eager `IndexedStack` (`main_shell.dart:37-43`, `:63`). **New:** the demo-pill flip
  adds a one-shot full-app relayout inside this same window (headline finding).
- ✅ **First view shows content fast** — `splash_screen.dart` paints with zero async
  dependencies; `equipment_tab.dart:204-235` has a real shimmer skeleton.

### 2. Rendering & interaction

- ❌ **Smooth scroll/animation (60fps)** — downgraded. Four `BackdropFilter` instances per root
  tab frame, ≈22 % of the screen blurred, one at σ 36; full-resolution image decode unchanged;
  `ImageCache` still untuned. Measurement BLOCKED-OWNER. See headline finding.
- ⚠️ **Lazy loading / virtualization** — unchanged. Correct: `equipment_tab.dart:212`/`:400`,
  `lab_tests_tab.dart`, `packages_tab.dart`, `widgets/paginated_list.dart` (4 history screens).
  Still eager over unbounded data: `universal_search_screen.dart:300`, `diagnostics_tab.dart:39`,
  `consultations_tab.dart:41`, `manpower_tab.dart:48`.
- ❌ **Images sized/compressed to display size** — unchanged.
  `common_widgets.dart:124-140` (`ProductImage`): `Image.asset` with no `cacheWidth`,
  `CachedNetworkImage` with no `memCacheWidth`. Repo-wide grep → **0**. Grid cards ≈180 pt
  (`equipment_tab.dart:394-397`) → ~492 px at 3× → ~0.97 MB needed. Largest *live* asset
  `0009_Aircurve_10_Vauto_Apac_Tri_4g.png` is 5.46 MiB / 2000×2000 → **16.0 MB decoded**, ~17×
  the pixel budget. **Still the single largest runtime memory lever.**
- ❌ **No expensive work in render/row builders** — unchanged, and now sitting under an extra
  blur. `universal_search_screen.dart:277` un-debounced `setState` per keystroke;
  `:261` `final results = _results;` invokes the getter at `:159` that rescans the corpus inside
  `build`.

### 3. Memory

- ❌ **No leaks / retain cycles** — still ❌, but genuinely improved.
  - **Fixed:** the `PaymentService` + `http.Client` leak per Pay Now tap is gone
    (`billing_screen.dart` no longer imports it); the surviving instance is disposed at
    `payment_screen.dart:165`.
  - **Unchanged:** 18 `ApiService()` sites (byte-identical set to `820060b`),
    `api_service.dart:41` `_client = client ?? http.Client()`, no `factory`, no `close()`.
  - **Unchanged:** `document_repository_screen.dart:47` `TextEditingController`, no `dispose()`
    anywhere in the file.
  - **Unchanged:** module-level `OverlayEntry? _activeToast` / `Timer? _toastTimer`
    (`common_widgets.dart:16-17`), cancelled only on tap/fire/replacement, never on route
    teardown.
  - Still correct and still worth credit: every periodic `Timer` cancelled
    (`otp_screen.dart:77`, `home_screen.dart:88`, `auth_provider.dart:234`,
    `sync_service.dart:111`) and all four `StreamSubscription`s cancelled.
- ❌ **Large media streamed or bounded** — unchanged; nothing bounds decoded image memory.
- ❌ **Caches have a size bound and evict** — unchanged and the surface grew.
  `cache_service.dart:30` still returns `null` on expiry without removing. **New neighbour:**
  `daily_rating_YYYY-MM-DD` (`my_care_screen.dart:593`, written at `:614`) grows at one
  `SharedPreferences` key per rated day with no cap and no TTL, pruned only by a patient switch.
  On iOS the whole store is memory-resident.
- **BLOCKED-OWNER** — "memory returns to baseline after heavy flows." Instruments Allocations:
  launch → scroll the full equipment catalog → back out.

### 4. Battery, network & resource use

- ⚠️ **No busy-wait loops / runaway timers** — unchanged. `sync_service.dart:96` `Timer.periodic`
  at a fixed interval, no backoff, no escalation; both call sites swallow the outcome
  (`:92-94`, `:97-99`).
- ⚠️ **Background work registered correctly** — unchanged. FCM deferred to
  `addPostFrameCallback`; cold-start notifications drained. Nothing bounds a detached request.
- ⚠️ **Batched/coalesced; retried with backoff** — backoff is real and good
  (`api_service.dart:55-85`: 2 retries at `_retryDelay * attempt` for `SocketException`,
  `TimeoutException`, 5xx, plus a one-shot 401 recovery). Coalescing still absent: the
  **864,311-byte** `equipment_catalog.json` is loaded and decoded independently at **seven**
  sites with no shared memo.
- ❌ **Requests cancelled when no longer needed** — unchanged. No `CancelToken`, no
  `_client.close`, no request-level timeout in `ApiService`; timeouts exist only at caller sites.
  The `on TimeoutException` branch at `api_service.dart:77` is still effectively dead.

### 5. Data & query performance

- **N/A — hot queries / indexes.** No local DB (no sqflite/drift/Isar in `pubspec.yaml`);
  persistence is `SharedPreferences` only; Firestore index config is server-side.
- ⚠️ **N+1 avoided** — no network N+1; the 7-site catalog re-parse is the client-side equivalent.
- ⚠️ **Large result sets paginated; query timeouts set** — `PaginatedListView` used correctly at
  `pageSize: 20` in four history screens; timeouts cover a minority of call sites.
- ❌ **Connection pooling / reads off the UI thread** — unchanged, plus one new instance.
  (a) 18 independent `http.Client()`s, none closed. (b) `grep "compute(\|Isolate\." lib/` → **0**
  while 864 KB `jsonDecode` runs on the main isolate at 7 sites and PDF generation
  (`invoice_pdf_service.dart:96`, `handover_report_service.dart:97`) is synchronous on the UI
  isolate. (c) **New:** `SessionScope`'s O(days) sequential `prefs.remove` chain (A-4).

### 6. Concurrency & responsiveness

- ❌ **No blocking calls on the main/UI thread** — unchanged (see §5).
- ❌ **Long operations cancellable and cancelled on navigation/teardown** — unchanged; no
  cancellation primitive exists anywhere. The new `SessionScope` await is a fresh example: it
  cannot be cancelled and nothing prevents a second one starting.
- ❌ **Shared mutable state protected** — downgraded from ⚠️. The toast globals
  (`common_widgets.dart:16-17`) are unchanged; `DemoMode` moving from a global bool to a Set is
  an improvement in this row's terms. **But A-5 is a live read-modify-write race on six
  providers plus the prefs store**, reachable by a double tap, at `home_screen.dart:1767-1777`
  and `settings_screen.dart:455-463`.
- ⚠️ **State captured at invocation, not execution** — unchanged. Coverage is good overall; the
  two confirmed gaps remain: `daily_report_screen.dart:31-36` (`setState` after `await` with no
  `mounted` check) and `notifications_screen.dart:32-35`. Note the round-2 repairs did this
  correctly (`payment_screen.dart:245` `if (!mounted) return;`, `session_scope.dart:75`
  `if (!context.mounted) return;`).

### 7. Reliability & resilience

- ❌ **Crash/error-free target defined and monitored** — unchanged, verbatim.
  `logger.dart:63-65` still reads
  `// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError`, and `_log`
  still ends at `debugPrint`. Crashlytics receives **fatals only**. Every `Log.warn`/`Log.error`
  — including `payment_service.dart:181` "Refusing to confirm",
  `store_migrator.dart:64` "StoreMigrator aborted", and `session_scope.dart:97` "Failed to clear
  patient-scoped storage" — reaches **no remote sink in release**. Round 2 called this "the
  finding that makes every other finding undetectable in the field." It is now also the finding
  that makes the round-2 *repairs* unobservable: three of the new safety nets log and continue,
  and nobody will ever know they fired. No error-rate or crash-free-sessions target exists.
- ⚠️ **No uncaught exceptions on user paths; global error boundary exists** — re-graded from ✅
  (A-2). The boundary itself is still done well: `runZonedGuarded` (`main.dart:100`),
  `FlutterError.onError` → `recordFlutterFatalError` (`:116-117`),
  `PlatformDispatcher.instance.onError` (`:118-121`), friendly `ErrorWidget.builder`
  (`:139-168`), route-level try/catch (`:520`), correctly gated on `!kIsWeb` / `!kDebugMode`.
  The pre-`runApp` window still holds two unguarded awaits (`:103`, `:178`).
- ⚠️ **Degrades gracefully when a dependency is down** — the demo-honesty work is materially
  better than round 2: notice is now over **every route** rather than five tabs
  (`main.dart:434`), sources are per-provider, the three unmarked fallbacks are marked, and the
  handover PDF marks itself (`handover_report_service.dart:105`). Held at ⚠️ for A-3: ten of
  eleven sources are a one-way latch, so a healthy backend shows a permanent false alarm — the
  precise failure `demo_mode.dart:16-17` says the redesign eliminated.
  Also unchanged: `my_care_provider.dart:88-99` still substitutes `DemoData.icuServiceDetail`
  for **any** deployment id on a non-`ApiException` failure.
- ⚠️ **Recovers cleanly from interruption** — unchanged. `my_care_provider.dart:47-53` still sets
  `_lastFetchedAt = DateTime.now()` while seeding demo data, so `isStale` (`:36-38`) reports
  false for 60 s off a demo seed and the foreground-resume refresh is skipped.
- ❌ **Data integrity holds under interrupted writes** — the payment blocker is closed (A-1),
  which is the big one. The rest of the cluster is untouched:
  - **No write queue exists.** `sync_service.dart` is still read-only;
    `grep "outbox\|pending_writes\|writeQueue\|enqueue"` → 0. `OrdersProvider.addOrder` persists
    locally and makes no API call, yet all four call sites show an unqualified confirmation.
  - **`requestRefill` cannot return false** — `medication_provider.dart:165-180`.
    Patient-safety-adjacent: the UI says the pharmacy was notified when it was not.
  - **Failed delete pops as success** — `add_edit_medication_screen.dart:268-272`.
  - **Corrupt persisted orders silently wipe** — `orders_provider.dart:197-206`.
  - **New:** the interleaved double-wipe in A-5 is itself an interrupted-write hazard — two
    concurrent `clearPatientScopedData` runs against the same prefs store with no ordering
    guarantee.
- ⚠️ **Retries with backoff + circuit breakers** — backoff correct in `api_service.dart:55-85`;
  **no circuit breaker anywhere**; `sync_service.dart:96` has no backoff at all.

### 8. Size & asset hygiene

- ❌ **No unused assets, deps, or dead code shipped** — unchanged, independently re-measured.

```
assets/images/products/     439 files   77.4 MiB
  referenced (unique)       201 files   37.1 MiB
  UNREFERENCED              238 files   40.3 MiB   ← unchanged since round 1
  referenced-but-missing      0 files
```

  Method: `re.compile(r'assets/images/products/([^"\']+)')` over every `.dart`/`.json`/`.yaml` in
  the repo (excluding `.git`, `build`, `.dart_tool`, `ios/Pods`, `docs/audits`). The one raw
  "missing" hit is the unquoted directory declaration in `pubspec.yaml:85` itself, not a real
  reference. This reproduces round 2's figure exactly, from a clean re-run rather than a
  carry-over.

  Bundled because `pubspec.yaml:85` declares the **directory** — Flutter ships every file in a
  declared directory regardless of reference, which is also why asset tree-shaking cannot help.
  Two of the five largest files on disk are dead: `0094_ECG_Electrodes.png` (3.55 MiB) and
  `0360_Inj_Ondomed.jpg` (1.71 MiB); three 1.48 MiB F-20 mask renders are dead as well.

  **This is still the largest single win available and it is still a pure delete** — ~40 MiB off
  the install, roughly a quarter to a third of total app size, no code change, no behavioural
  risk (`referenced-but-missing` is **0**, so nothing breaks). It has now survived three audit
  rounds unchanged while three rounds of chrome work happened around it. **Fix:** delete the 238
  files, then either enumerate assets in `pubspec.yaml` or add a CI check that prunes
  `assets/images/products/` against `equipment_catalog.json`.

  Also unchanged: four unused dependencies at 0 imports in `lib/` — `dio`, `go_router`,
  `flutter_svg`, `cupertino_icons`.
- ⚠️ **Code-splitting / tree-shaking** — Dart AOT tree-shakes unreached code; bundling
  `Archivo`/`NotoSansDevanagari` locally instead of `google_fonts` is the right call. Assets are
  never tree-shaken — directory-level declaration defeats it.
- ❌ **No debug-only resources or large sample data in the release artifact** — unchanged.
  `DemoData` is reachable from providers, screens and `handover_report_service.dart:101-108`, so
  it is not tree-shakeable: `demo_data.dart` (749 LOC), `demo_articles.dart` (236),
  `care_packages.dart` (266), `demo_mode.dart`. `daily_report_screen.dart:40-87` is still a
  ~47-line hardcoded clinical report (fabricated vitals, tasks and medications attributed to a
  named nurse) compiled into the release binary and rendered on API failure.

### 9. Accessibility-driven performance

- ⚠️ **Reduced-motion honoured** — unchanged. 11 files reference `disableAnimations`; the "no
  infinite pulses" rule holds; the round-2 repairs did this right
  (`payment_screen.dart:302-310`). Same single gap: `equipment_detail_screen.dart:1689-1696`
  constructs an `AnimationController` with a hardcoded 250 ms and `_toggle` (`:1704-1713`) calls
  `forward()`/`reverse()` with **no `disableAnimations` check** — still the only ungated
  controller of seven.
- ⚠️ **Largest text / zoom doesn't break layout** — the clamp is correct and deliberate
  (`main.dart:421-432`, 0.85–1.4, honouring WCAG 1.4.4); overflow guarded across 320/375/414 by
  `test/screens/overflow_smoke_test.dart`. Gap unchanged: `grep -rn textScaler test/` → **0**, so
  the suite runs at default scale only and the 1.4× ceiling the app advertises is never tested.
  **Newly relevant:** the demo pill's label is `maxLines: 1` with `TextOverflow.ellipsis`
  (`demo_data_banner.dart:118-119`) at 12 px — at 1.4× the warning text is the first thing to
  get truncated, and it is a clinical-safety string.
- ❌ **Reduced-transparency / high-contrast respected** — unchanged in code and **doubled in
  cost**. Zero matches for `highContrast`/`boldText`/`accessibleNavigation`;
  `glass.dart:156` applies its `BackdropFilter` unconditionally. Users with Reduce Transparency
  on now pay four blurs per root-tab frame instead of two. See the headline finding for the
  one-line fix that covers all four sites.

### 10. Measurement & evidence

- **BLOCKED-OWNER — profiler pass on a real target.** Now materially more valuable than in round
  2 because there is a specific A/B to run: `820060b` vs `9a80fe2`, Home tab, demo pill up.
  Xcode Instruments Time Profiler + GPU on a physical mid-range phone.
- **BLOCKED-OWNER — startup/interaction/memory measured.** No perf artefact exists anywhere in
  `docs/`. Firebase Performance **is** initialised (`main.dart:124-125`), so cold-start and HTTP
  traces should already be flowing — needs console access to read.
- ⚠️ **Crash/error/latency reports monitored** — Crashlytics and Performance correctly
  initialised and correctly gated (`main.dart:112-134`), which is real credit. `logger.dart:63`
  means non-fatals never arrive, so what is monitored is fatals only.
- **BLOCKED-OWNER — tested on a low-end target.** Matters more each round: image decode, catalog
  parse, and now four backdrop filters are exactly the class of problem invisible on a modern
  dev machine.

---

## Blockers (must fix before release)

1. **40.3 MiB of unreferenced product images ship in the binary** — 238 files, bundled via the
   directory declaration at `pubspec.yaml:85`. Pure delete, zero risk, largest single win
   available, unchanged across three rounds. *Now the #1 blocker because B-1 is closed.*
2. **Full-resolution image decode on the catalog hot path** — `common_widgets.dart:124-140`. Up
   to 16 MB decoded per tile against a ~1 MB need; no `cacheWidth`, no `ImageCache` tuning.
   Unchanged across three rounds.
3. **All non-fatal errors invisible in production** — `logger.dart:63`. Every fallback and every
   new round-2 safety net logs and continues into a void, which makes blockers 4 and 5 and the
   whole demo-honesty layer undetectable in the field. One line at a documented chokepoint.
4. **Four `BackdropFilter` surfaces composited per root-tab frame, permanently, with no
   Reduce-Transparency escape** — `glass.dart:156` (×2: app bar + demo pill),
   `main_shell.dart:114` (σ 36), `assistant_fab.dart:34`. Doubled since `820060b`; ≈22 % of the
   screen. Permanence is caused by the one-way `DemoMode` latch (A-3). **New in round 3.**
5. **Unguarded async patient-switch and logout handlers** — `home_screen.dart:1767-1777`,
   `settings_screen.dart:455-463`. A double tap inside the storage-wipe gap runs two interleaved
   wipes and pops a route it should not. The gap grows with install age (A-4). **New in round 3,
   introduced by the round-2 repair.**

## High

- **Ten of eleven `DemoMode` sources can never be lowered** — `app_provider.dart:273` is the only
  `markServingLiveData` call site. A healthy backend shows a permanent "Sample data" warning, and
  the second blur is permanent as a result. (A-3)
- **`SessionScope`'s wipe is O(days-since-install) and strictly sequential** —
  `session_scope.dart:91-95`, `cache_service.dart:41-43`. `Future.wait` over the removals is the
  fix; capping `daily_rating_*` growth is the better one. (A-4)
- **The pre-`runApp` black-screen window is still open** — `main.dart:103`, `:178`. (A-2)
- **The demo-pill flip re-parents the entire app subtree once, inside the launch window** —
  `demo_data_banner.dart:38-51`; one-line fix (keep the `Stack`, swap only the pill).
- **No request-level timeout or cancellation in `ApiService`** — `api_service.dart:55-85`,
  `:102-136`.
- **`ApiService` is not a singleton — 18 unclosed `http.Client`s** (`api_service.dart:41`, no
  `close()`). Defeats pooling; ad-hoc instances also never receive the auth token, so against a
  real backend those call sites would 401 and fall back to demo data permanently.
- **864 KB catalog decoded on the UI isolate at 7 sites with no shared cache** — no `compute()`
  anywhere in `lib/`.
- **`requestRefill` cannot return false** — `medication_provider.dart:165-180`.
- **`CacheService` never evicts; `daily_rating_*` grows one key per day forever** —
  `cache_service.dart:30`, `my_care_screen.dart:593`/`:614`.
- **Silent wrong-record substitution** — `my_care_provider.dart:88-99`.
- **No test locks the single-`openCheckout` invariant** — the round-3 headline fix is
  grep-checkable but not test-enforced. (A-1)

## Medium / Low

- `openCheckout` still accepts a nullable `orderId` and drops the key when null —
  `payment_service.dart:97-137`; the invariant lives in the caller, not the service.
- `_pendingVerification` is derived by string-matching `'under verification'` —
  `payment_screen.dart:290` vs `payment_service.dart:181`/`:187`.
- Root `context.watch<AppProvider>()` for `locale` alone — `main.dart:397`, `:407`.
- Nav pill paints five ops for one bar: shadow blur 24, clip, backdrop blur 36, two fills —
  `main_shell.dart:94-124`.
- Demo-pill warning text is `maxLines: 1` + ellipsis at 12 px — `demo_data_banner.dart:114-127`;
  first casualty at 1.4× textScaler.
- Eager `ListView` over unbounded data — `universal_search_screen.dart:300`,
  `diagnostics_tab.dart:39`, `consultations_tab.dart:41`, `manpower_tab.dart:48`.
- No search debounce; `_results` recomputed in `build`, under a blurred app bar —
  `universal_search_screen.dart:261`, `:277`.
- Undisposed `TextEditingController` — `document_repository_screen.dart:47`.
- Global toast timer not cancelled on route teardown — `common_widgets.dart:16-17`.
- Unguarded `setState` after `await` — `daily_report_screen.dart:31-36`,
  `notifications_screen.dart:32-35`.
- 2 s hard-coded splash delay — `splash_screen.dart:14-19`.
- Five root tabs built eagerly in `IndexedStack` — `main_shell.dart:37-43`, `:63`.
- `BillingProvider` has zero listeners; `clearPatientScopedData` notifies nobody.
- Four unused dependencies — `dio`, `go_router`, `flutter_svg`, `cupertino_icons`.
- `sync_service` fixed-interval retry, no backoff or circuit breaker — `sync_service.dart:96`.
- Reduced-motion gap — `equipment_detail_screen.dart:1689-1696`, `:1704-1713`.
- Overflow suite never exercises the 1.4× textScaler ceiling — 0 `textScaler` in `test/`.
- Large hardcoded sample data in a production screen — `daily_report_screen.dart:40-87`.

## BLOCKED-OWNER

| Item | What I need |
|---|---|
| §2 backdrop-filter cost, `820060b` vs `9a80fe2` | GPU/raster trace on a physical mid-range phone, Home tab, demo pill up. **Highest-value single measurement available.** |
| §10 profiler pass (CPU/memory/leaks) | Xcode Instruments — Time Profiler on cold launch (2 s splash floor, five-tab `IndexedStack`, `getInstance` cost, the one-shot demo-flip relayout); Allocations while scrolling the equipment catalog |
| §10 startup/interaction/memory measured | Firebase Performance console access — traces already collected (`main.dart:124-125`) |
| §10 low-end target testing | A run on an older device / throttled network |
| §3 memory returns to baseline | Allocations across launch → full catalog scroll → back out |
| §4 `SessionScope` wipe duration | A patient switch on a device with ~1 year of `daily_rating_*` keys, timed |
| Live storage-rules posture | `firebase deploy --only storage` status — unverifiable from the repo |

---

## Note on owner-decision items

Per the brief I did not grade the floating glass pill, white-on-orange, or manpower pricing as
failures. **What I did do is measure the pill's cost, because that is this checklist's job:** the
pill contributes one of the four per-frame `BackdropFilter` surfaces, at σ 36 over the app's
σ 24 chrome standard, across ≈22,900 pt². The design decision is the owner's and is recorded as
such; the cost is a fact and is recorded as such. If the owner wants the pill *and* wants the
cost down, the two cheapest levers that do not touch the look are (a) honour
Reduce Transparency in `GlassSurface` — one condition, fixes all four sites, and only affects
users who asked for it; and (b) fix the `DemoMode` latch so the fourth surface disappears the
moment a backend exists. Neither changes the pill for anyone who has not opted out.

---

## Executive summary

1. **Round 3: ✅1 · ⚠️16 · ❌17 · N/A1 · BLOCKED4** of 39. Round 2 was 2/17/15/1/4.
2. **The payment fix is genuine and, unusually, structural.** `payment_service.dart` now has
   exactly one importer and `openCheckout` exactly one call site; `billing_screen` cannot reach
   the payment machinery at all. I hunted for a third path and there is none. The single path
   always carries a backend `order_id` under a real key and fails closed on null.
3. **`StoreMigrator` is genuinely throw-safe** — every `getInstance`, `setInt`, `getKeys` and the
   catch's own `Log.error` are enclosed and none can escape.
4. **But the hole it lived in is still open:** `Firebase.initializeApp` (`main.dart:103`) and
   `MedicationReminderService().init()` (`:178`) are still unguarded awaits before `runApp`, with
   the same permanent-black-screen failure mode. The instance was fixed; the class was not.
5. **Two round-2 repairs are themselves defective.** The `DemoMode` `Set` fixed over-clearing by
   making under-clearing permanent — one `markServingLiveData` call site for eleven sources, so a
   healthy backend shows a permanent false alarm. And `SessionScope`'s new `await` left two
   handlers unguarded (`home_screen.dart:1767`, `settings_screen.dart:455`), where a double tap
   runs two interleaved wipes and pops the wrong route.
6. **REGRESSED — measured:** blur surfaces per root-tab frame went **2 → 4** (`820060b` had none
   on the nav bar and none on the demo strip), covering ≈22 % of the screen, one at σ 36. The
   count matters more than the σ: each `BackdropFilter` is a separate readback and render-pass
   flush. Because the `DemoMode` latch is one-way, the fourth is permanent for every user.
7. **The overlay `Stack` does not repaint the app per frame** — verified against the Flutter SDK,
   including the `updateChild` identical-widget fast path. It does re-parent the whole app
   subtree **once**, on the flip, inside the cold-launch window; the `Navigator`'s `GlobalKey`
   saves the routes, but the render tree is detached and re-attached. One-line fix: keep the
   `Stack` always and swap only the pill.
8. **On the brief's explicit question:** the overlay is better than the displacement it replaced.
   Occlusion is a design defect with a design fix; the strip was an architectural coupling that
   relaid out all five tabs on flip. Do not go back.
9. **Re-verified and restated: 238 unreferenced product images = 40.3 MiB**, `referenced-but-missing`
   = 0, from a clean re-measurement. Three rounds, unchanged, still a pure delete, still the
   largest single win in the app.
10. **FAIL.** Top five remaining: (1) 40.3 MiB dead assets; (2) full-res image decode, no
    `cacheWidth` anywhere; (3) `logger.dart:63` — every non-fatal, including all the new safety
    nets, invisible in release; (4) four permanent backdrop filters with no Reduce-Transparency
    escape; (5) the unguarded async switch/logout handlers. Note that 1–3 are byte-for-byte the
    same findings as round 1.
