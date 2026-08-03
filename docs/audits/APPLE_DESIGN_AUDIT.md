# Apple Design Framework — Complete Standard (v1.0, Feb 2026) — Audit vs commit `803124d`

**Date:** 2026-08-03 · **Auditor:** Apple-Design-Framework agent
**Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app` (working tree at HEAD `803124d`)
**Method:** read-only. `rg`/`grep` sweeps + direct reads of `lib/config/theme.dart`, `lib/config/app_colors.dart`,
`lib/widgets/*`, `lib/screens/main_shell.dart`, `lib/main.dart` route table, and every root-tab screen.
Ran `bash scripts/check_design_consistency.sh` (PASS). Did **not** run `flutter test/build/clean` per brief.
All contrast ratios below were computed with a WCAG 2.x relative-luminance calculator validated against
reference pairs (`#767676`/white = 4.54, black/white = 21.0, `#0000FF`/white = 8.59 — exact matches).

**Working-tree note honoured:** this audit reflects the **FIVE**-tab shell
(Home/My Care/Services/Billing/More) with the care calendar moved to the My Care app bar.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1.1 Calm Command pillars (4) | 2 | 2 | 0 | 0 |
| 1.2 Ten First Principles (10) | 3 | 5 | 2 | 0 |
| 2.1 Typography system (5) | 0 | 2 | 3 | 0 |
| 2.2 Color system (8) | 4 | 3 | 1 | 0 |
| 2.3 Spacing & layout (9) | 5 | 4 | 0 | 0 |
| 3.1 Touch targets (3) | 2 | 1 | 0 | 0 |
| 3.2 Animation (6) | 4 | 2 | 0 | 0 |
| 3.3 Feedback patterns (3) | 1 | 2 | 0 | 0 |
| 4.1 Buttons (4) | 1 | 3 | 0 | 0 |
| 4.2 Cards (4) | 2 | 2 | 0 | 0 |
| 4.3 Forms (4) | 1 | 3 | 0 | 0 |
| 5.1 Quick tests (3) | 0 | 2 | 1 | 0 |
| 5.2 Accessibility checklist (6) | 2 | 2 | 1 | 1 |
| 5.3 Design review sign-off (9) | 3 | 4 | 2 | 0 |
| 6.1–6.3 Figma / PPT / Notion (14) | 0 | 0 | 0 | 14 |
| 6.4 Code implementation (5) | 3 | 2 | 0 | 0 |
| **TOTAL (97 scored + 14 N/A)** | **33** | **39** | **10** | **15** |

---

## Standing vs the earlier audit batch

### (a) Previously fixed — still holding ✅

Verified by re-running the enforcement gate and re-greping the banned patterns:

```
$ bash scripts/check_design_consistency.sh
✓ Design-consistency check passed — no banned patterns in lib/screens.
```

| Item | Evidence |
|---|---|
| `BorderRadius.circular(14)` eliminated | gate check #1 clean; `circular(14)` count in `lib/screens` = 0 |
| `Colors.grey.shade*` eliminated from screens | gate check #2 clean |
| Raw `Colors.red/blue/green/teal/purple` eliminated from screens | gate check #3 clean |
| Hardcoded `Color(0xFF…)` eliminated from screens (9-entry allowlist only) | gate check #4 clean |
| Raw brand orange as text colour eliminated | gate check #5 clean, allowlist is literally `__none__` |
| `CircleAvatar` wrapping an `Icon` eliminated | gate check #6 clean; `AppIconTile` is the primitive (`lib/widgets/common_widgets.dart:197`) |
| Per-service rainbow retired from screens | gate check #7 clean, 4 documented categorical allowlist files |
| Shared kit exists and is used | `HousepitalCard` 49 sites, `SectionHeader`/`StatusBadge`/`AppIconTile`/`DetailRow`/`VitalCard` all in `lib/widgets/common_widgets.dart` |
| 11px text floor | fontSize histogram: `11` ×95, and exactly **one** sub-11 value (`9.5` ×1) at `lib/screens/calendar/care_calendar_screen.dart:817` — the documented year-view exception |
| Text-scale clamp (WCAG 1.4.4) | `lib/main.dart:417` — `textScaler.clamp(0.85, 1.4)` |
| 44pt hit areas on previously-flagged hot spots | `lib/screens/cart/cart_screen.dart:862`, `:979`; `lib/widgets/common_widgets.dart:691`; `lib/screens/home/home_screen.dart:410`, `:497`; `lib/widgets/empty_state.dart:96` |
| Colour-blind-safe vital status | `VitalCard` renders icon + word ("Normal"/"Borderline"/"Alert"), not a colour dot — `lib/widgets/common_widgets.dart:363-378` |
| Bottom-nav geometry after the 6→5 change | `test/screens/main_shell_test.dart:189-234` asserts fixed full-width orange bar, 5 items, no Calendar tab |
| No dangling 6-tab indices | every `MainShell.switchToTab(n)` call site uses n ∈ {0,1,2,3} — `lib/screens/home/home_screen.dart` ×12, `lib/screens/my_care/my_care_screen.dart:364`, `lib/widgets/glass.dart:67` |

### (b) NEW or regressed violations ❌⚠️

Ranked; full evidence in the Findings section below.

| # | Finding | Grade | Where |
|---|---|---|---|
| N-1 | `/services` route resolves to a bare `const Scaffold()` — blank screen, **no app bar, no back button**, reachable live from the Sahayak assistant | ❌ Blocker | `lib/main.dart:555-557`, `lib/services/assistant_service.dart:189` |
| N-2 | Three colour tokens documented as WCAG-AA-passing measure **below 4.5:1** — the premise the design gate is built on | ❌ Blocker | `lib/config/theme.dart:62,64,87` |
| N-3 | GlassAppBar chrome contract broken on **38 of 45** screens: no paired `extendBodyBehindAppBar` | ❌ High | see table in §1.2 P2 |
| N-4 | **Four different root-tab header idioms** across five tabs (regression surface of the 6→5 tab change) | ❌ High | Home / My Care / Services / Billing / More |
| N-5 | SOS has exactly **one** entry point app-wide and it **scrolls off-screen**; `SOSButton` is dead code | ⚠️ High | `lib/screens/home/home_screen.dart:483-530`, `lib/widgets/common_widgets.dart:586` |
| N-6 | Bottom-nav **unselected** tab labels measure **1.82:1** (not covered by the white-on-orange owner override) | ❌ High | `lib/screens/main_shell.dart:79` |
| N-7 | Errors silently rendered as empty states on Billing → Transaction Log and Notifications | ⚠️ High | `lib/screens/billing/transaction_log_screen.dart:60`, `lib/screens/notifications/notifications_screen.dart:47` |
| N-8 | Two destructive actions ship with **no confirmation**, inconsistent with their own siblings | ⚠️ High | `lib/screens/calendar/care_calendar_screen.dart:1312`, `lib/screens/settings/patient_profile_screen.dart:145` |
| N-9 | `service_booking_screen` hand-rolls a Material `AppBar`, overloads back for wizard steps, and has **no `PopScope`** — the iOS edge-swipe silently exits the whole wizard | ⚠️ High | `lib/screens/services/service_booking_screen.dart:325-336` |
| N-10 | `lib/widgets/` is **outside** the design gate's scan scope — two shared widgets are light-mode-only | ⚠️ Med | `scripts/check_design_consistency.sh:18`, `lib/widgets/paginated_list.dart`, `lib/widgets/document_attach_widgets.dart` |
| N-11 | Sheet geometry drift: three top-corner radii (16/20/28) + 6 sheets with no drag handle | ⚠️ Med | 25 `showModalBottomSheet` sites |
| N-12 | Two competing transient-feedback idioms: 61 Material `SnackBar`s vs 7 `showTopToast`s (the *fix* pattern from this very commit) | ⚠️ Med | 35 files |
| N-13 | `PopScope(canPop: false)` with no `onPopInvoked` → dead back-gesture on booking confirmation | ⚠️ Med | `lib/screens/services/booking_confirmation_screen.dart:187-188` |
| N-14 | Stale documentation contradicting shipped code (4 sites) | ⚠️ Low | `lib/widgets/glass.dart:22`, `test/screens/main_shell_test.dart:3-9`, `lib/config/theme.dart:159,231,325,416`, `lib/screens/services/service_catalog_screen.dart:128` |

---

# Findings

## 1. Philosophy & First Principles

### 1.1 The Calm Command Manifesto — Core Design Pillars

- ⚠️ **Clarity over decoration — every element must earn its place** — the calm pass genuinely landed
  (service rainbow retired, one accent enforced by gate check #7, true-black tonal dark). But the
  chrome still carries up to **four** trailing icons plus a leading home button on a 375pt bar
  (`lib/widgets/glass.dart:74-84`: custom → home → search → cart), and Home adds a fifth (SOS pill,
  `lib/screens/home/home_screen.dart:483`). — **Impact:** the "decrowding" field round removed a
  second cart but the bar is still the densest surface in the app. — **Fix:** move `home` into the
  bottom-nav-only role on pushed screens (back already returns), leaving `[custom, search, cart]`.
- ✅ **Consistency breeds confidence — same action, same result** *for the enforced layer* —
  `GlassAppBar`'s trailing order is contract-tested: `test/widgets/glass_app_bar_test.dart:73-80`
  asserts custom → home → search → **cart rightmost** by measured `dx`.
- ⚠️ **Whitespace is not empty** — spacing is on a coherent 4pt sub-grid but with real off-grid noise:
  `SizedBox(height: 6)` ×32, `height: 10` ×29, `height: 14` ×48 (plus `width:` 6 ×17, 10 ×31).
  See §2.3.
- ✅ **Hierarchy guides the eye** — verified structurally on the root tabs: each has a single dominant
  CTA cluster and `SectionHeader` (16/w600) separates bands
  (`lib/widgets/common_widgets.dart:388-442`).

### 1.2 The Ten First Principles

#### Principle 1 — Immediate Recognition (3-second test)

❌ **FAIL.** `lib/main.dart:555-557`:

```dart
case '/services':
  return MaterialPageRoute(
      builder: (_) => const Scaffold());
```

A named route resolves to an **empty Scaffold** — no app bar, no title, no content, no back button.
It is *not* dead code: `lib/services/assistant_service.dart:185-193` routes the Hinglish utterances
`services` / `service` / `dikhao` / `kholo` to `'/services'`, and `assistant_screen.dart:55-58`
pushes it. A user who says "services dikhao" to Sahayak lands on a blank page whose only exit is the
iOS edge-swipe (there is no rendered back affordance at all).
This is `BUG-16` in `docs/KNOWN_ISSUES.md`, open since 2026-03-21, and still open at `803124d`.
— **Impact:** blocker. Fails the 3-second test absolutely (nothing to recognise) and traps the user.
— **Fix:** `case '/services': return MaterialPageRoute(builder: (_) => MainShell(key: MainShell.shellKey));`
then `MainShell.switchToTab(2)` — or delete the case so it falls through to the existing
`default:` branch, which already returns `MainShell`.

⚠️ Everywhere else the principle holds: every other screen opens with either a large in-body display
title or a `GlassAppBar` title, and the root tabs each have one obvious primary job.

#### Principle 2 — Predictable Behavior (same gesture = same result; back always goes back)

❌ **FAIL — three independent breaks.**

**(a) Chrome contract honoured on 7 of 45 screens.** `CLAUDE.md` states glass screens *pair* with
`extendBodyBehindAppBar` + scroll padding. Measured:

```
GlassAppBar files:               45
extendBodyBehindAppBar: true:     7
```

The 7 that comply: `assistant_screen.dart:80`, `care_calendar_screen.dart:189`,
`my_care_screen.dart:83`, `service_detail_screen.dart:48`, `care_team_screen.dart:77`,
`billing_screen.dart:145` — plus `service_catalog_screen.dart:127` which *deliberately* opts out
with a comment. The other **38** (full list obtainable via
`for f in $(grep -rl GlassAppBar lib/screens); do grep -q extendBodyBehindAppBar $f || echo $f; done`)
include `cart_screen.dart`, `payment_screen.dart`, `settings_screen.dart`,
`universal_search_screen.dart`, `document_repository_screen.dart`, `my_orders_screen.dart`,
`vitals_screen.dart`, `notifications_screen.dart`, `order_tracking_screen.dart`.
On those 38 the `BackdropFilter` in `GlassSurface` (`lib/widgets/glass.dart:156`) has nothing behind
it to blur, so the bar degrades to a flat 55%-opacity fill. — **Impact:** two visibly different app-bar
materials across the app; content "glides under glass" on 7 screens and hard-stops on 38.
— **Fix:** either set `extendBodyBehindAppBar: true` + the documented
`MediaQuery.padding.top + kToolbarHeight` scroll padding on the remaining 38, or make `GlassSurface`
fall back to an opaque `surface` fill when the bar is not extended, so the two states look identical.

**(b) Wizard back is overloaded with no gesture parity.**
`lib/screens/services/service_booking_screen.dart:325-336`:

```dart
appBar: AppBar(                       // ← raw Material AppBar, not GlassAppBar
  title: Text(s.name),
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),   // ← Material arrow, not the adaptive BackButton
    onPressed: () {
      if (_step > 0) { setState(() => _step--); } else { Navigator.pop(context); }
```

There is **no `PopScope`** on this screen (`grep -rn 'PopScope' lib` returns only
`booking_confirmation_screen.dart:187`). So on iOS the edge-swipe pops the entire booking wizard from
step 3, while the visible arrow one pixel away steps back to step 2. Same gesture intent, two
different results. — **Impact:** users lose a half-completed priced booking. — **Fix:** wrap in
`PopScope(canPop: _step == 0, onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(() => _step--); })`
and drop the hardcoded `Icons.arrow_back` so Flutter's adaptive `BackButtonIcon` renders the iOS chevron.

**(c) Dead back gesture on the confirmation screen.**
`lib/screens/services/booking_confirmation_screen.dart:187-188` is `PopScope(canPop: false, child: …)`
with **no `onPopInvokedWithResult`**. Swiping back does literally nothing and says nothing. The screen
does provide three explicit exits (`:404` Track order, `:420` popUntil first, `:432` a TextButton), so
the intent is sound — the silence is not. — **Fix:** add an `onPopInvokedWithResult` that runs the same
`Navigator.popUntil(context, (r) => r.isFirst)` as line 422.

✅ Destructive-confirmation *helper* exists and is used at 7 call sites
(`confirmDestructiveAction`, `lib/widgets/common_widgets.dart:501`) — but see Principle 7 for the gaps.

#### Principle 3 — Information Hierarchy

❌ **FAIL on root-tab consistency.** The five tabs use **four different header idioms**:

| Tab | Idiom | Evidence |
|---|---|---|
| Home (0) | **No `AppBar` at all** — hand-rolled in-body header row (logo + bell + search + cart + SOS) that scrolls away | `home_screen.dart:103` (`Scaffold` with no `appBar:`), `:375-530` |
| My Care (1) | `GlassAppBar` + in-body large title, bar title **fades in on scroll** (iOS large-title collapse) | `my_care_screen.dart:99-105`, `:44-48` |
| Services (2) | `GlassAppBar` with a **static, non-collapsing** 28/w800 title inside `bottom:` + a 7-tab `TabBar` | `service_catalog_screen.dart:123-170` |
| Billing (3) | `GlassAppBar` + in-body large title, bar title fades in on scroll | `billing_screen.dart:153-160` |
| More (4) | `GlassAppBar` with a **plain 20pt title**, no large title at all | `settings_screen.dart:87-91` |

— **Impact:** "most important information largest and highest" resolves differently on every tab; the
display-title size a user sees on tab 1 vanishes on tab 4. This is the surface most exposed by the
6→5 tab change (Services acquired its title-in-`bottom` treatment to make room for the tab strip).
— **Fix:** pick one — the My Care/Billing collapsing large title is the strongest and already has two
implementations to copy. Give Services the same treatment above its `TabBar`, and give More a large title.

⚠️ Progressive disclosure is otherwise good: 25 modal sheets carry tertiary detail rather than pushing routes.

#### Principle 4 — Touch-First Design (≥44pt, thumb zones, visual feedback)

⚠️ **PARTIAL.**
- ✅ 44pt floors are explicitly reserved at 11 sites (`grep -c 'minWidth: 44\|minHeight: 44\|Size(0, 32).*padded'` → 11), including every previously-flagged small control.
- ✅ Every `IconButton` with `padding: EdgeInsets.zero` also declares `constraints: BoxConstraints(minWidth: 44, minHeight: 44)` — verified at `cart_screen.dart:862/979` and `common_widgets.dart:691`.
- ✅ Bottom nav: 5 items across ≥320pt = ≥64pt each; `BottomNavigationBar` fixed-type default height 56pt inside `SafeArea` — `main_shell.dart:67-71`.
- ⚠️ **Thumb-zone failure for the app's most urgent action.** SOS is in the *top* trailing corner of Home (`home_screen.dart:483`) — the hardest reach on a large iPhone — and, because `_buildHeader` is a child of the `SingleChildScrollView` at `home_screen.dart:110-120`, it **scrolls out of view**. The comment at `:481-483` claims it "lives in the persistent header so it's always one tap away"; the code contradicts it.
  Worse, `grep -rn "'/sos'" lib` returns exactly **two** hits: the route case (`main.dart:439`) and that one push (`home_screen.dart:492`). There is no SOS on My Care, Services, Billing, or More, and the ready-made `SOSButton` widget (`lib/widgets/common_widgets.dart:586-648`, complete with `heavyImpact` haptic and a Semantics label) is **never instantiated anywhere**.
  — **Impact:** `CLAUDE.md`'s "SOS is never blocked" is satisfied in the sense that nothing gates it, but it is effectively hidden from 4 of 5 tabs and from any scrolled Home. — **Fix:** pin the Home header (move `_buildHeader` out of the scroll view, or use a `SliverPersistentHeader`), and surface SOS from the shell so it survives a tab switch.

#### Principle 5 — Meaningful Motion

✅ **PASS.**
- Durations: `100`(4), `120`(1), `150`(4), `200`(4), `220`(2), `250`(2), `300`(2), `400`(1), `450`(3), `500`(1). Micro-interactions and standard transitions land in spec; the three `450` and one `500` are celebrations (`booking_confirmation_screen.dart:95,104`, `payment_screen.dart:135`, `staff_otp_verification_screen.dart:66`) — at or under the 500ms "complex animation" ceiling and under `CLAUDE.md`'s ≤500ms celebration rule.
- Two outliers are **not** animations: `Duration(milliseconds: 800)` at `payment_screen.dart:171` and `payment_service.dart:118` are `Future.delayed` simulated-network waits; `1200` at `order_tracking_screen.dart:109` is the tracking-progress sweep.
- ✅ No infinite pulses: `grep -rn '\.repeat(' lib` returns a single **comment** at `order_tracking_screen.dart:103` recording that the unbounded pulse was removed.

#### Principle 6 — Accessible by Default

❌ **FAIL** — see §5.2 for the full contrast table. Headline: three tokens the codebase *documents* as
AA-passing measure below 4.5:1, and the bottom nav's unselected labels measure 1.82:1.

#### Principle 7 — Error Prevention

⚠️ **PARTIAL — two real gaps.**

**(a) Errors disguised as empty states.** `lib/widgets/paginated_list.dart:140-165` — when
`showEmptyOnError: true`, an initial-load **failure** renders the caller's `emptyWidget` instead of
the error/retry block. Two screens opt in:
- `lib/screens/billing/transaction_log_screen.dart:60` → a failed transaction fetch reads as *"you have no transactions"* on a **billing** screen.
- `lib/screens/notifications/notifications_screen.dart:47` → a failed notification fetch reads as *"you're all caught up"*.

— **Impact:** the user cannot distinguish "nothing here" from "we couldn't load it", and is given no
retry. Directly contradicts "when errors occur, explain clearly and offer recovery". — **Fix:** drop
`showEmptyOnError` on both; the widget's own error branch (`:167-185`) already offers Retry.

**(b) Two destructive actions with no confirmation, each inconsistent with a sibling that *does* confirm.**

| Action | Confirms? | Evidence |
|---|---|---|
| Remove item from cart | ✅ yes | `cart_screen.dart:865-872` |
| Remove item from **saved-for-later** | ❌ **no** | `cart_screen.dart:982` — `onPressed: () => cart.removeSaved(index)` |
| Remove medication (profile) | ✅ yes | `patient_profile_screen.dart:225-233` |
| Remove **emergency contact** (profile) | ❌ **no** | `patient_profile_screen.dart:145-150` — `setState` + `removeAt`, straight through |
| Delete **care reminder** | ❌ **no** | `care_calendar_screen.dart:1308-1313` — `IconButton(Icons.close)` → `RemindersProvider.delete(r.id)` |

— **Impact:** the emergency-contact case is the serious one — a single mis-tap on `Icons.remove_circle_outline`
(`patient_profile_screen.dart:694`) silently deletes a safety contact from a home-healthcare app, with no
undo. The inconsistency also breaks Principle 2: the same red minus glyph two rows apart behaves differently.
— **Fix:** route all three through the existing `confirmDestructiveAction` helper (already imported in
both files).

✅ Real-time validation is present where it matters: `AutovalidateMode.onUserInteraction` on 8 forms
(login, onboarding, add-patient, patient-profile, address, family-members, raise-concern, vitals).
⚠️ 45 `TextFormField`s vs 32 `validator:` declarations → ~13 fields ship without validation.

#### Principle 8 — Performance Perception

⚠️ **PARTIAL.** Skeleton screens exist on exactly **2** screens
(`article_list_screen.dart:101-102`, `notification_preferences_screen.dart:190,229` — both `Shimmer`).
Every other loading state is a bare spinner: `CircularProgressIndicator` ×24, `LoadingWidget` on 10
screens (`lib/widgets/common_widgets.dart:444`). ✅ Optimistic/offline behaviour is strong —
`cache_service.dart`, `sync_service.dart`, provider-level offline fallbacks, and the assistant's local
executor which "really executes add-to-cart / booking offline"
(`assistant_executor.dart:319`). — **Fix:** the Shimmer dependency is already in `pubspec`; extend the
skeleton pattern to My Care, Billing, and the Services tabs, which are the three longest first-paints.

#### Principle 9 — Platform Authenticity (iOS: SF Symbols, safe areas, standard nav)

❌ **FAIL against the literal spec — the app reads as Material on iOS.** Objective inventory:

| Material idiom | Count | Note |
|---|---|---|
| `SnackBar` (bottom, Material) | **61** call sites across 35 files | vs 7 `showTopToast` — see N-12 |
| `DropdownButton` | **40** (21 in `assessment_request_screen.dart` alone) | iOS uses picker wheels / action sheets |
| `SwitchListTile` / `Switch` | 14 | M3 switch, not `CupertinoSwitch` |
| `showDatePicker` / `showTimePicker` | 3 (`care_calendar_screen.dart:935,962`, `assessment_request_screen.dart:1367`) | Material calendar/clock dialogs on iOS |
| `FloatingActionButton` | 5 screens + the global `AssistantFab` | pure Material affordance |
| `TabBar` with 3pt underline indicator | 3 (`service_catalog_screen.dart:96` — 7 scrollable tabs, `vitals_screen.dart:136`, `my_orders_screen.dart:159`) | iOS uses a segmented control |
| `ExpansionTile` | 5 | |
| `Badge` (M3) on cart | 1 | `glass.dart:113` |
| `Icons.*` (Material icon set) | app-wide | `grep -rn 'Cupertino' lib` → **1 hit**, and it is only `GlobalCupertinoLocalizations.delegate` (`main.dart:406`) |

**Mitigating:** Flutter's default `pageTransitionsTheme` is not overridden in either theme
(`lib/config/theme.dart` — no `pageTransitionsTheme` key), so iOS gets the Cupertino slide + edge-swipe
for free. `BackButton()` (`otp_screen.dart:98`) and `AppBar`'s automatic leading are platform-adaptive
and render the iOS chevron — the **one** hardcoded Material arrow is
`service_booking_screen.dart:327` (`Icons.arrow_back`).
✅ Safe areas are respected: 18 screens use `SafeArea`, `main_shell.dart:69` wraps the nav in
`SafeArea(top: false)`, and the `extendBody: true` inset is regression-tested
(`test/screens/main_shell_test.dart:224`).

— **Impact:** none of this is a bug; it is a deliberate cross-platform Flutter posture. But measured
against *this* checklist ("iOS: Use SF Symbols… Android: Material Design components"), the app ships
Android components on an iOS-first product. — **Fix (scoped):** the cheapest high-yield swaps are
(1) replace the 3 Material date/time pickers with Cupertino equivalents, (2) finish the
`showTopToast` migration so the 61 bottom SnackBars stop reading as Android, (3) replace the 40
`DropdownButton`s in the assessment form with an action-sheet picker.

#### Principle 10 — Graceful Degradation

✅ **PASS.** Demo mode is a first-class path: `DemoData` fallbacks across providers, `cache_service.dart`
+ `sync_service.dart`, offline coupon handling (`cart_screen.dart:48`), and an offline assistant that
genuinely executes bookings (`assistant_executor.dart:123-140`). `app_provider.dart:174` explicitly
caches the dashboard. The only degradation hole is N-1 (`/services` → blank screen), reported under
Principle 1.

---

## 2. Visual Standards

### 2.1 Typography System

The checklist specifies an SF-based scale: **Large Title 34/Bold · Title 1 28/Bold · Headline 17/Semibold ·
Body 17/Regular · Caption 12/Regular.**

Measured `fontSize` histogram, `lib/screens` + `lib/widgets` (from `scripts/check_design_consistency.sh`,
which prints this informationally and never fails the build):

```
  1  9.5      95  11     191  12     200  13     184  14      2  14.5
 61  15      138  16      34  18      17  20       6  22       8  24
 12  28        2  32       6  36
```

- ❌ **Large Title 34pt** — not present. The app's display size is **28** (×12), plus `32` (×2) and `36` (×6) as ad-hoc numerics. `CLAUDE.md` names 28/w800 as the display canon — so 34 is deliberately not used, but 32 and 36 are unaccounted-for outliers (`billing_screen.dart:280`, `emi_screen.dart:56`; `payment_screen.dart:427,577`, `vitals_screen.dart:297`, `equipment_detail_screen.dart:1174`).
- ✅/⚠️ **Title 1 28/Bold** — present and dominant as the display title (28 ×12, w800 rather than w700). Grade ⚠️: weight is heavier than spec.
- ❌ **Headline 17/Semibold** — **17pt does not exist anywhere** in the codebase. The section-header role is 16/w600 (`SectionHeader`, `common_widgets.dart:415-417`).
- ❌ **Body 17/Regular** — the app's body sizes are **13** (×200) and **14** (×184). At iOS default Dynamic Type, body copy is 3–4pt below the platform standard.
- ⚠️ **Caption 12/Regular** — 12 is used ×191 ✅, but **11 is used ×95** — below the checklist's caption floor (though at the `CLAUDE.md` 11px minimum).

**Drift the project's own docs already flag:** `CLAUDE.md` calls 13/17/18/19/20/21/10 "smells to review".
Present count of those smells: **13 ×200, 18 ×34, 20 ×17** = 251 occurrences. `18` alone appears in 34
places across 24 files (`home_screen.dart` ×5, `service_booking_screen.dart` ×5,
`staff_otp_verification_screen.dart` ×5, `billing_screen.dart` ×3, `article_detail_screen.dart` ×3, …).
Two `14.5` values (`article_detail_screen.dart:149`, `active_service_card.dart:51`) are pure one-offs.

— **Impact:** the scale is *converging* (11/12/13/14/15/16/28 covers 892 of 977 literals = 91%) but the
remaining 85 literals span 9 distinct off-canon sizes. — **Fix:** the histogram is already printed by the
gate; promote it from echo-only to a **ratchet** — record today's counts as a baseline and fail the build
if any off-canon size *increases*. That freezes the drift without a big-bang refactor.

- ✅ **Font family** — bundled `Archivo` + `NotoSansDevanagari` fallback applied to every style
  (`theme.dart:146-148,156,337`); `google_fonts` is absent from `pubspec.yaml`.

### 2.2 Color System

#### Semantic colours (checklist hexes vs shipped)

| Role | Checklist | Shipped (light) | Measured on white | Verdict |
|---|---|---|---|---|
| Primary Action | `#007AFF` | `#F39314` (brand orange) | — | ✅ *justified brand override; one-accent budget enforced by gate check #7* |
| Success | `#34C759` | `#2E7D32` | **5.13:1** | ✅ (Apple's own `#34C759` is 2.2:1 on white — the app's darker green is objectively better) |
| Warning | `#FF9500` | `#E65100` | **3.79:1** | ⚠️ documented as "4.6:1" at `theme.dart:87` — **wrong by 0.8**; used as a text colour at 73 sites in `lib/screens` |
| Error | `#FF3B30` | `#D32F2F` | **4.98:1** | ✅ (doc says 4.7 — conservative, fine) |
| Neutral | `#8E8E93` | `#6B6B6B` | **5.33:1** | ✅ (doc says 5.3 — accurate) |

❌ **The AA premise of the design system is off.** `scripts/check_design_consistency.sh:74-78` bans raw
orange as text *because* `orangeText` "keeps AA (4.6:1)". Measured:

| Token | Documented claim | **Measured** | Delta |
|---|---|---|---|
| `orangeText #B86E00` on white | `theme.dart:62` "4.6:1 on white" | **3.99:1** | −0.6, **fails AA** |
| `orangeText #B86E00` on app bg `#F8F9FA` | — | **3.78:1** | **fails AA** |
| `orangeText #B86E00` on `orangeLight #FFF3E0` | — | **3.63:1** | **fails AA** |
| `orangeDark #CC6E00` on white | `theme.dart:64` "4.5:1 on white" | **3.62:1** | −0.9, **fails AA** |
| `warning #E65100` on white | `theme.dart:87` "4.6:1" | **3.79:1** | −0.8, **fails AA** |

`orangeText` is not a corner case — it is the **default `TextButton` foreground app-wide**
(`theme.dart:255-259`), the **chip label colour** (`theme.dart:312`), the `SectionHeader` "See All"
action (`common_widgets.dart:433`), and the empty-state CTA label (`empty_state.dart:92`).
— **Impact:** every secondary/link action in the app sits at ~3.8–4.0:1 while the codebase, the gate
script, and the previous audit all assert it passes AA. All three passed 3:1 large-text, so this is a
normal-text failure, not a catastrophic one. — **Fix:** darken to **`#9A5C00`** (measures **5.38:1** on white,
**5.10:1** on `#F8F9FA`, **4.90:1** on `#FFF3E0` — AA on all three surfaces the token actually lands on)
and re-derive `orangeDark`/`warning` the same way; then correct the four doc comments and the gate
script's rationale.

#### Owner override — measured, as instructed

- `onOrange = #FFFFFF` on brand orange `#F39314` = **2.33:1** (`theme.dart:70`, `theme.dart:32`).
  Fails AA 4.5:1 for normal text **and** 3:1 for large text. Recorded per the brief as an explicit
  owner decision (white bold on orange fills, both modes) — **not reported as a defect.** The mitigation
  documented at `theme.dart:65-69` (keep text bold w600+ and ≥14px) is honoured in the nav bar
  (`main.dart` label styles) but is **not** enforced anywhere.
- ❌ **Not covered by that override:** the bottom nav's **unselected** items use
  `context.hc.onOrange.withValues(alpha: 0.7)` (`lib/screens/main_shell.dart:79`). White@70% over
  `#F39314` resolves to `#FBDFB8`, which measures **1.82:1** against the orange bar. At
  `BottomNavigationBar`'s default `unselectedFontSize: 12`, four of the five tab labels are at
  1.82:1 — below even the 3:1 large-text floor, and roughly **22% worse than** the already-overridden
  full-white 2.33:1. — **Impact:** the primary navigation is the least legible text in the app.
  — **Fix:** raise the unselected alpha to ~0.85 (≈2.05:1) or, better, distinguish selected/unselected
  by **weight + filled-vs-outlined icon** (both already present via `activeIcon`) and keep all labels
  at full white 2.33:1 — matching the owner's rule exactly.

#### Dark mode

- ✅ **Backgrounds `#000000` (pure black) or `#1C1C1E` (elevated)** — exact match:
  `theme.dart:16-18` (`surface #000000`, `surfaceElevated #1C1C1E`, `surfaceHigh #2C2C2E`).
- ✅ **Reduce pure white to off-white** — `textPrimary = #F2F2F2` (`theme.dart:23`), essentially the
  checklist's `#F2F2F7`. Measures 7.85:1 for `textSecondary #B0B0B0` on the `#1C1C1E` card ✅.
- ⚠️ **Semantic colours adapt automatically** — the `context.hc.*` resolver
  (`lib/config/app_colors.dart:17-21`) is the right mechanism and is enforced inside `lib/screens`.
  But the gate's `SCAN_DIR` is **`lib/screens` only** (`scripts/check_design_consistency.sh:18`), so
  `lib/widgets` is unguarded — and two shared widgets are light-mode-only:
  - `lib/widgets/paginated_list.dart` — 8 static `HousepitalColors.*` references
    (`:117,129,145,157,172,189,222,236`). In dark mode the "No items found" (15pt) and "No more items"
    (13pt) strings render `#6B6B6B` on the true-black page = **3.94:1**, or **3.19:1** on a `#1C1C1E`
    card. Both fail AA. This widget backs **Report History, Attendance History, Notifications, and the
    Billing Transaction Log**.
  - `lib/widgets/document_attach_widgets.dart` — 15 static references including `infoLight #E3F2FD`
    and `orangeLight #FFF3E0` used as **fills** (`:80,144,162,180,198,255`). In dark mode these render
    as bright pastel cards on a true-black page — a light-mode island inside the tonal dark system.
  - Also `HousepitalColorsDark.textDisabled #7A7A7A` is documented as "4.2:1 on card / 5.4:1 on bg"
    (`theme.dart:25`); measured **3.96:1 / 4.89:1**.
  — **Fix:** widen the gate to `SCAN_DIR="lib/screens lib/widgets"` (the fontSize histogram already
  scans both — the scopes are inconsistent today) and migrate those 23 references to `context.hc.*`.
- ✅ Dark-mode token flipping is regression-tested (`test/widgets/dark_mode_test.dart`,
  `test/screens/dark_mode_sweep_test.dart`) and a user-facing Appearance picker exists
  (`settings_screen.dart:231-237` → `ThemeProvider`).

### 2.3 Spacing & Layout

**8pt grid** (Micro 4 · Small 8 · Medium 16 · Large 24 · XLarge 32):

```
EdgeInsets.all(N):   4×7   8×16  12×38  14×2  16×107  20×16  24×16  32×3  48×1
SizedBox(height:N):  2×49  3×2   4×93   6×32   8×162  10×29  12×110 14×48
                    16×115 20×42 24×69  28×3  32×11  40×5   48×3
SizedBox(width:N):   4×42  6×17   8×149 10×31 12×74  14×5   16×29
```

- ✅ **Micro 4pt** — 4 is the second-most-used value.
- ✅ **Small 8pt** — 8 is the single most-used value (311 combined).
- ✅ **Medium 16pt** — 16 is the dominant padding (107 `EdgeInsets.all(16)`).
- ✅ **Large 24pt** — present and consistent (69 + 16).
- ⚠️ **XLarge 32pt** — used only 14 times; screen-level padding is 16, not 32 (a reasonable phone-width
  choice, but a spec divergence).
- ⚠️ **Off-grid strays**: `6` (49), `10` (60), `14` (55), plus singletons `3`, `5`, `18`, `26`, `30`, `34`, `42`, `50`, `88`, `100`. ~170 occurrences are on a 2pt sub-grid rather than the 8pt (or even 4pt) grid. — **Fix:** define `Spacing.xs/sm/md/lg/xl` constants (see §6.4 — this is the one design-token category with **no** named constants) and mechanically map 6→8, 10→8 or 12, 14→12 or 16.
- ⚠️ **Corner-radius spread** — 17 distinct values in `lib/screens` + `lib/widgets`:
  `12`(137) `8`(79) `10`(53) `16`(35) `20`(24) `4`(14) `6`(6) `3`(3) `24`(2) `2`(2) `11`(2) `9`(1) `5`(1) `28`(1) `22`(1) `2.5`(1) `18`(1). The banned `14` is gone ✅, but `9`, `11`, `2.5`, `18`, `22` are unexplained one-offs.
- ✅ **Safe areas respected** — `SafeArea` in 18 screens; `main_shell.dart:69` `SafeArea(top: false)` around the nav; `extendBody`/`extendBodyBehindAppBar` insets flow through `MediaQuery.padding` and are regression-tested; the six Services tabs each pad with `MediaQuery.padding.bottom`.
- ✅ **Minimum 16pt horizontal margins** — `EdgeInsets.all(16)` ×107 and `EdgeInsets.symmetric(horizontal: 16)` ×76 are the app's default gutters.
- ✅ **Tab bars ≥49pt** — `BottomNavigationBar` fixed type renders 56pt + safe-area inset.
- ✅ **Navigation bars ≥44pt** — `GlassAppBar.preferredSize` = `kToolbarHeight` (56) + optional bottom (`glass.dart:52-53`).

---

## 3. Interaction Patterns

### 3.1 Touch Targets

- ✅ **Minimum 44×44pt** — explicitly reserved at 11 sites; no `IconButton` was found with
  `padding: EdgeInsets.zero` and no compensating `constraints`. `StarRatingInput`
  (`common_widgets.dart:688-691`) keeps a 44pt box around a 24pt glyph.
- ⚠️ **8pt minimum spacing between targets** — not systematically enforced. `GlassAppBar` packs up to
  4 `IconButton`s (each 48pt wide, `IconButton`'s own default) with zero inter-button padding
  (`glass.dart:74-84`); the visual gap comes from icon-inside-button whitespace only. On Home the
  header adds a 5th control (`home_screen.dart:445-530`). Not a hard failure (48pt boxes are adjacent,
  not overlapping) but no explicit gap is declared anywhere.
- ✅ **Primary actions in the thumb zone** — bottom nav, `AssistantFab` (bottom-right,
  `main_shell.dart:61`), and sticky bottom CTAs in cart/checkout/payment. **Exception:** SOS
  (see Principle 4) is top-right and scrolls away.

### 3.2 Animation Guidelines

- ✅ **Micro-interactions 100–150ms** — `HousepitalCard` press-scale is **120ms**
  (`common_widgets.dart:187`); `100` ×4 and `150` ×4 elsewhere.
- ✅ **Standard transitions 200–300ms** — `200` ×4, `220` ×2, `250` ×2, `300` ×2. Route transitions
  use Flutter's platform default (no `pageTransitionsTheme` override) = iOS Cupertino ~350ms.
- ✅ **Complex 300–500ms** — the four celebration/reveal controllers are 450/450/450/500ms.
- ⚠️ **Enter: ease-out** — only partially explicit. `HousepitalCard` uses `Curves.easeOut`
  (`common_widgets.dart:188`) ✅, but most `AnimatedOpacity`/`AnimatedContainer` calls omit `curve:`
  and take the Flutter default `Curves.linear`, e.g. `my_care_screen.dart:99-104` and
  `billing_screen.dart:155-159` (the large-title cross-fades).
- ⚠️ **Exit: ease-in / Move: ease-in-out** — no explicit `Curves.easeIn` or `Curves.easeInOut` found
  outside the animation controllers. — **Fix:** add `curve: Curves.easeOut` to the ~12 implicit
  animations; it is a one-line change per site.
- ✅ **Respect reduced motion** — `MediaQuery.disableAnimations` gates animations at **17 sites across
  11 files** (`my_care_screen.dart`, `billing_screen.dart`, `payment_screen.dart`,
  `booking_confirmation_screen.dart`, `order_tracking_screen.dart`, `care_calendar_screen.dart`,
  `medications_screen.dart`, `medication_schedule_screen.dart`, `staff_otp_verification_screen.dart`,
  `equipment_tab.dart`, `care_pulse_ring.dart`). Every file that owns an `AnimationController` is on
  that list except `equipment_detail_screen.dart` (`:1690`, a 250ms sheet controller — under the
  perceptual threshold, low risk).

### 3.3 Feedback Patterns

- ✅ **Visual** — press-scale 0.97 + `InkWell` ripple on `HousepitalCard`; `AnimatedScale`
  (`common_widgets.dart:185-189`).
- ⚠️ **Haptic — thin and semantically inverted vs spec.** Only **8** call sites app-wide:
  `heavyImpact` ×3 (SOS in `home_screen.dart:491` and `common_widgets.dart:605`; payment in
  `payment_screen.dart`), `mediumImpact` ×2 (payment, booking confirmation), `lightImpact` ×3
  (calendar, medications, medication schedule). The checklist reserves **heavy for errors**; the app
  uses heavy for the SOS *action*. Defensible for an emergency control, but it means errors carry no
  haptic at all. Most confirmations, add-to-cart events, and toggles are silent.
  — **Fix:** add `HapticFeedback.selectionClick()` to tab switches and toggles, `mediumImpact` to
  add-to-cart, and `heavyImpact` to error toasts (`showTopToast(isError: true)` is the single choke point).
- ⚠️ **Transient feedback is split between two competing systems.** `showTopToast`
  (`common_widgets.dart:19-93`) was introduced *in this very commit* precisely because bottom
  SnackBars "covered the primary CTA and couldn't be dismissed (field report: 'I can't select slot' /
  'how do I cross it')". Adoption:

  ```
  showTopToast call sites:  7
  showSnackBar call sites: 61   (35 files)
  ```

  Worst offenders: `document_repository_screen.dart` (7), `raise_concern_screen.dart` (5),
  `service_booking_screen.dart` (5) — the last being exactly the booking wizard the field report was
  about. — **Impact:** the same class of message appears at the top on 7 paths and at the bottom,
  over the CTA, on 61. — **Fix:** finish the migration; the toast API is a drop-in
  (`message`, `actionLabel`, `onAction`, `isError`).

---

## 4. Component Library

### 4.1 Buttons

| Type | Spec | Shipped | Verdict |
|---|---|---|---|
| Primary | Filled system blue, **50pt height, 16pt radius** | `ElevatedButtonTheme`: brand orange fill, `vertical: 14` padding + 16pt/w600 label → **≈47pt**, radius **12** (`theme.dart:228-242`) | ⚠️ 3pt short, radius 4pt tight; brand fill is a sanctioned override |
| Secondary | Outlined, gray border, 50pt, **1pt** border | `OutlinedButtonTheme`: orange border (default 1pt), `vertical: 14` → ≈47pt, radius 12 (`theme.dart:243-252`) | ⚠️ orange rather than gray border; same height/radius deltas |
| Destructive | Filled system red, **requires confirmation** | `confirmDestructiveAction` builds `ElevatedButton` with `backgroundColor: context.hc.error, foregroundColor: Colors.white` (`common_widgets.dart:518-524`) — white on `#D32F2F` = **4.98:1** ✅ | ⚠️ the *style* is right; 3 destructive paths bypass it entirely (Principle 7b) |
| Text | No background, blue text, **44pt min touch target** | `TextButtonTheme` → `orangeText` (`theme.dart:255-259`), measured **3.99:1** — see §2.2; Material `TextButton` default min size 64×40 with `padded` tap target → 48pt hit ✅ | ✅ touch target / ❌ contrast |

### 4.2 Cards

- ⚠️ **Corner radius 12 (standard) / 16 (large)** — the theme uses **16 for all cards**
  (`RoundedSuperellipseBorder(16)`, `theme.dart:272-274` light, `:451-453` dark). Deliberate
  ("continuous corners" — a genuinely more Apple-correct choice than a circular arc), but every card
  is a "large card" by the checklist's rule.
- ⚠️ **Shadow 0, 2, 8 blur, 10% black** — light theme ships `elevation: 3` with
  `shadowColor: Colors.black.withValues(alpha: 0.35)` (`theme.dart:267-268`) — **3.5× the specified
  opacity**. Dark theme uses `elevation: 0` and relies on tone (`:447`), which is correct for OLED.
  Ad-hoc `BoxShadow`s elsewhere use `blurRadius` 8/10/12/16/24.
- ✅ **16pt internal padding** — `HousepitalCard` defaults to `EdgeInsets.all(16)`
  (`common_widgets.dart:166`).
- ⚠️ **Tap state: scale to 0.98** — `HousepitalCard` scales to **0.97** @120ms
  (`common_widgets.dart:186-188`) — right idiom, marginally stronger than spec. But it covers only
  **49** of the app's card instances: raw `Card(` appears **127** times in `lib/screens`
  (`report_history_screen.dart:38`, `attendance_history_screen.dart:39`, `active_service_card.dart:35`,
  `service_detail_screen.dart:238,578`, `billing_summary_section.dart:43`,
  `staff_otp_verification_screen.dart:150`, `equipment_deployed_section.dart:30`, …). Those inherit
  the correct *geometry* from `CardThemeData`, so they look right — but tappable ones get only an
  `InkWell` ripple, with **no press-scale**. ~72% of cards therefore have a different tap feel from
  the other 28%. — **Fix:** convert the tappable raw `Card(child: ListTile(onTap:))` instances to
  `HousepitalCard(onTap:)`.

### 4.3 Forms

- ⚠️ **Input height ≥50pt** — `InputDecorationTheme.contentPadding: symmetric(vertical: 14)`
  (`theme.dart:292`, dark `:474`) + a 16pt label ≈ **48pt**. 2pt short.
- ✅ **Label above field, 8pt spacing** — the 8 audited forms use `Text` label + `SizedBox(height: 8)`
  + field (e.g. `add_patient_screen.dart`, `address_selection_screen.dart`).
- ⚠️ **Error state: red border, error text below** — `errorBorder` and `focusedErrorBorder` are
  **not declared** in either theme (`theme.dart:277-293`, `:456-476`); the app relies on Material's
  fallback rather than its own `error` token. Error *text* below the field is provided by
  `validator:` on 32 of 45 `TextFormField`s; `errorText:` is used explicitly only once.
- ⚠️ **Focus state: blue border, 2pt** — 2pt width is correct (`theme.dart:290`, `:472`); colour is
  brand orange, not blue (sanctioned one-accent override). Focused orange border on white is 2.33:1 —
  a non-text UI-component contrast that falls under WCAG 1.4.11's 3:1 rule. — **Fix:** use
  `orangeText`/a darkened orange for the focus ring specifically.

---

## 5. QA & Validation Checklist

### 5.1 Quick Tests (Pre-Flight)

- ❌ **3-Second Test** — fails on `/services` (blank `Scaffold`, N-1). It also fails a weaker version on
  the **More** tab, which is a `ListView` of undifferentiated `ListTile`s with no large title and no
  visual grouping other than two `Divider`s (`settings_screen.dart:92-270`) — cover the app-bar title
  and there is nothing that says "account & settings".
- ⚠️ **Squint Test** — hierarchy is legible on Home / My Care / Billing (large title → section headers
  → cards). Weakest surface is Services: seven scrollable tabs (`service_catalog_screen.dart:133-140`)
  under a static title give no sense of "what do I do next".
- ⚠️ **Grayscale Test** — mostly passes: `StatusBadge` supports an icon (`common_widgets.dart:247-249`),
  `VitalCard` ships icon **and** word (`:363-378`), the SOS pill has an icon + the literal text "SOS".
  Weak spot: attendance status relies on `AttendanceHelper.getStatusColor` for the leading icon tint
  (`attendance_history_screen.dart:41-44`) — the accompanying `StatusBadge` does carry the status
  **text**, so it degrades acceptably. — **Fix:** pass `icon:` to those `StatusBadge`s for parity with
  `VitalCard`.

### 5.2 Accessibility Checklist

| Requirement | Standard | Measured | Pass? |
|---|---|---|---|
| Text contrast ratio | ≥4.5:1 | **Mixed.** Pass: `black #212121`/white 16.1 · `grey #3D3D3D`/`#F8F9FA` 10.30 · `greyLight`/white 5.33 · `success` 5.13 · `error` 4.98 · `info` 5.75 · dark `textSecondary`/card 7.85 · dark `success`/card 7.20 · dark `error`/card 4.88 · dark orange/black 8.99. **Fail:** `orangeText` 3.99 · `orangeDark` 3.62 · `warning` 3.79 · nav unselected label **1.82** · `paginated_list` grey on dark 3.19–3.94 · SOS subtitle `white70` on `#D32F2F` **3.10** (`common_widgets.dart:635`) · white on dark SOS `#EF5350` 3.49 · **owner-override** white on orange 2.33 | ❌ |
| Large text contrast | ≥3:1 | 28pt display titles use `hc.black` (16.1:1) ✅. SOS screen's 28/w700 white on `#D32F2F` = 4.98 ✅. But nav labels (1.82) and white-on-orange (2.33) fail even this floor | ⚠️ |
| Touch targets | ≥44pt | 11 explicit reservations; no unguarded zero-padding `IconButton` found | ✅ |
| VoiceOver labels | All interactive | **72** `Semantics(` wrappers across **24 of 98** files in `lib/screens` + `lib/widgets`, plus 27 `tooltip:` and 17 `semanticLabel:`. Excellent where present (`home_screen.dart:401-404,446,454,463,484`, `common_widgets.dart:318,593,685`, `assistant_fab.dart:17-21`) — but ~75% of files carry none, relying on Flutter's inferred labels from `Text`/`Icon` children. Icon-only controls without `tooltip:` announce nothing useful | ⚠️ |
| Color-blind safe | Non-color cues | `VitalCard` icon+word ✅; `StatusBadge` text always present, icon optional ✅; bottom nav pairs filled/outlined `activeIcon` with colour ✅ | ✅ |
| Reduced motion support | Respects setting | `MediaQuery.disableAnimations` at 17 sites / 11 files, covering every screen with an `AnimationController` except one 250ms sheet | ✅ |
| VoiceOver **tested** on device | — | Cannot verify from source | **BLOCKED-OWNER** |

### 5.3 Design Review Sign-Off

| ☐ | Item | Verdict |
|---|---|---|
| 1 | All screens pass 3-second test | ❌ — `/services` renders nothing (`main.dart:555`) |
| 2 | Typography follows scale exactly | ❌ — 85 literals across 9 off-canon sizes; no 17pt Headline/Body; 18pt ×34 and 20pt ×17 are named smells in `CLAUDE.md` |
| 3 | Colors use semantic system only | ⚠️ — semantic **naming** is excellent and gate-enforced in `lib/screens`, but `lib/widgets` is unscanned and 23 static light-palette references live there |
| 4 | Dark mode tested | ✅ — `test/widgets/dark_mode_test.dart` + `test/screens/dark_mode_sweep_test.dart`; true-black tonal system matches the checklist's dark spec exactly |
| 5 | Accessibility checklist complete | ⚠️ — 4 of 6 verifiable rows pass; contrast fails, Semantics coverage is partial |
| 6 | Animation durations within spec | ✅ — every UI animation is 100–500ms; the 3 longer values are network simulations / progress sweeps |
| 7 | **Error states designed** | ⚠️ — `ErrorRetryWidget` exists but is used on only **6** screens (`my_care_screen.dart:339`, `medications_screen.dart:92`, `medication_schedule_screen.dart:68`, `service_detail_screen.dart:55`, `staff_profile_screen.dart:171`, `daily_report_screen.dart:105`). `PaginatedListView` hand-rolls its own (`paginated_list.dart:167-185`), and 2 screens suppress it entirely via `showEmptyOnError` |
| 8 | **Loading states designed** | ✅ — `LoadingWidget` on 10 screens, `CircularProgressIndicator` ×24, Shimmer skeletons on 2. Every screen that loads has *a* loading state; only the *quality* (spinner vs skeleton) varies — see Principle 8 |
| 9 | **Empty states designed** | ⚠️ — `HousepitalEmptyState` (`lib/widgets/empty_state.dart`) is a genuinely well-specified primitive (icon tile + 15/w600 title + 13pt body + optional 44pt-tap CTA) but is used in only **5** files: `care_calendar_screen.dart`, `medications_screen.dart`, `my_orders_screen.dart`, `billing_screen.dart`, `services/widgets/empty_state.dart`. Elsewhere: `PaginatedListView` falls back to a bare `Center(Text('No items found'))` (`paginated_list.dart:124-132`), and `report_history_screen.dart:49` / `attendance_history_screen.dart:57` pass `Center(child: Text(l.t('no_data')))` — a single grey string, no icon, no explanation, no CTA. `care_team_screen.dart` (402 lines) has **no** loading, error, or empty branch at all |

**Sheet / modal usage (called out in the brief).** 25 `showModalBottomSheet` sites. Geometry is
inconsistent in two dimensions:
- **Top corner radius: three values** — `28` (`home_screen.dart:1742`), `20` (9 sites:
  `staff_profile_screen.dart:759`, `family_members_screen.dart:91`, `my_orders_screen.dart:462`,
  `staff_role_card.dart:173`, `equipment_item_card.dart:284`, `universal_search_screen.dart:520`,
  `transaction_log_screen.dart:207`, `payment_screen.dart:836`, `payment_methods_screen.dart:339`),
  `16` (4 sites: `vitals_screen.dart:88`, `my_care_screen.dart:637`,
  `document_attach_widgets.dart:127,228`). The remainder declare no `shape:` and inherit the M3
  default (28) in light — while the **dark** `bottomSheetTheme` (`theme.dart:510-513`) sets a colour
  but no shape, so light and dark sheets can differ.
- **Drag handle: 19 of 25.** Missing on `my_care_screen.dart:633`, `my_orders_screen.dart:458`,
  `lab_tests_tab.dart:123`, `vitals_screen.dart:84`, `document_attach_widgets.dart:124,224` — including
  `my_orders_screen.dart:458`, which returns a `bool` (a confirmation sheet) and so most needs an
  obvious dismiss affordance.
- ✅ 15 of 25 set `isScrollControlled: true`; the 10 that don't are short fixed-height pickers, which
  is correct.
— **Fix:** add `showDragHandle: true` to the 6, and put a single `RoundedRectangleBorder(vertical top 20)`
into **both** `bottomSheetTheme`s so no call site needs `shape:` at all.

---

## 6. Tool-Specific Guidelines

- **6.1 Figma** (5 items) — **N/A.** No `.fig` files, no Figma tokens export, no design-file references in the repo.
- **6.2 PowerPoint/Keynote** (4 items) — **N/A.** Not a presentation deliverable.
- **6.3 Notion/Documentation** (5 items) — **N/A** as a *tool* rule. (For the record, the repo's own markdown does follow H1-once/H2-sections: `CLAUDE.md`, `docs/*.md`.)

### 6.4 Code Implementation

- ⚠️ **Use design tokens, not hardcoded values** — colour tokens: ✅ and gate-enforced in `lib/screens`;
  ⚠️ unenforced in `lib/widgets` (23 static references). Radii/spacing: ❌ **no named constants exist** —
  `lib/config/constants.dart` (88 lines) holds API/business constants only; every radius and gap is a
  raw literal (17 distinct radii, ~10 off-grid spacings).
- ✅ **Semantic color names (primary, error) not hex values** — `HousepitalColors.success/warning/error/info`,
  `context.hc.*`. Raw hex in `lib/screens` is banned and the gate proves it (9-entry allowlist, each with
  a written justification).
- ❌→⚠️ **Spacing constants (`spacing.sm`, `spacing.md`)** — do not exist. This is the single highest-leverage
  missing token category and is the root cause of the §2.3 off-grid tail. — **Fix:** add
  `class Spacing { static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0; }` to
  `lib/config/constants.dart` and a gate rule banning new numeric literals in `SizedBox`/`EdgeInsets`.
- ✅ **Typography scale via shared styles** — `ThemeData.textTheme` defines headline/title/body/label
  (`theme.dart:169-216`, `:350-398`), `SectionHeader` centralises the 16/w600 role. ⚠️ but 977 inline
  `fontSize:` literals bypass it — the shared styles exist, they are just not the primary channel.
- ✅ **Component library with documented props** — `lib/widgets/common_widgets.dart`,
  `empty_state.dart`, `glass.dart`, `paginated_list.dart` all carry substantive dartdoc explaining the
  contract, the field report that motivated it, and the anti-pattern being replaced. This is genuinely
  above average and is the reason the enforced layer holds up so well.

---

## Blockers (must fix before release)

1. **`/services` resolves to a blank `const Scaffold()`** — `lib/main.dart:555-557`. No app bar, no back
   button, no content. Live-reachable: `assistant_service.dart:189` routes "services dikhao" here and
   `assistant_screen.dart:57` pushes it. Fails the 3-second test, traps the user, and is `BUG-16` open
   since 2026-03-21. **Fix:** return `MainShell` + `switchToTab(2)`, or delete the case (the `default:`
   branch at `main.dart:750` already returns `MainShell`).
2. **`orangeText` / `orangeDark` / `warning` fail WCAG AA while documented as passing** —
   `lib/config/theme.dart:62,64,87`. Measured 3.99 / 3.62 / 3.79 vs claimed 4.6 / 4.5 / 4.6.
   `orangeText` is the default `TextButton` foreground app-wide, the chip label, the `SectionHeader`
   action, and the empty-state CTA. `scripts/check_design_consistency.sh:74-78` enforces its use on the
   strength of the wrong number. **Fix:** `orangeText → #9A5C00` (5.38:1 on white, 5.10:1 on `#F8F9FA`,
   4.90:1 on `#FFF3E0`); re-derive `orangeDark`/`warning`; correct the four comments and the gate rationale.

## High

3. **Bottom-nav unselected labels at 1.82:1** — `lib/screens/main_shell.dart:79`. White@70% over
   `#F39314` = `#FBDFB8`. 12pt text on the app's primary navigation, worse than the already-overridden
   full-white 2.33:1, and **not** covered by the owner's white-on-orange decision. **Fix:** full-white
   labels for all five, differentiating selected state by weight + `activeIcon` (already wired).
4. **GlassAppBar chrome contract broken on 38 of 45 screens** — no paired `extendBodyBehindAppBar`, so
   the backdrop blur has nothing to blur and the bar degrades to a flat translucent fill. Two visibly
   different app-bar materials app-wide.
5. **Four root-tab header idioms across five tabs** — Home (no app bar, scrolling hand-rolled header) ·
   My Care & Billing (collapsing large title) · Services (static large title in `bottom:`) ·
   More (plain 20pt title). Most-exposed regression surface of the 6→5 tab change.
6. **SOS: one entry point, and it scrolls away** — `home_screen.dart:483-530` inside the
   `SingleChildScrollView` at `:110`; the `SOSButton` widget (`common_widgets.dart:586`) is never used;
   no SOS on 4 of 5 tabs. The code comment claims persistence the code does not deliver.
7. **Errors rendered as empty states on Billing → Transaction Log and Notifications** —
   `showEmptyOnError: true` at `transaction_log_screen.dart:60` and `notifications_screen.dart:47`
   (`paginated_list.dart:140-165`). No retry offered; "load failed" is indistinguishable from "no data"
   on a billing surface.
8. **Two unconfirmed destructive actions** — delete care reminder (`care_calendar_screen.dart:1312`)
   and remove **emergency contact** (`patient_profile_screen.dart:145`). Both have sibling actions two
   rows away that *do* confirm via `confirmDestructiveAction`.
9. **Booking wizard back is unpredictable** — `service_booking_screen.dart:325-336`: raw Material
   `AppBar`, hardcoded `Icons.arrow_back`, back overloaded to step backwards, **no `PopScope`** — so the
   iOS edge-swipe destroys a half-completed priced booking while the adjacent arrow steps back one page.

## Medium / Low

10. **`lib/widgets` is outside the design gate** (`scripts/check_design_consistency.sh:18` scans
    `lib/screens` only, while its own fontSize histogram scans both). Consequence:
    `paginated_list.dart` (8 static refs — grey text at 3.19–3.94:1 in dark mode, on Report History /
    Attendance History / Notifications / Transaction Log) and `document_attach_widgets.dart`
    (15 refs — `#E3F2FD`/`#FFF3E0` pastel fills as light-mode islands on true black).
11. **Sheet geometry drift** — three top radii (16 / 20 / 28 + theme default), 6 of 25 sheets with no
    drag handle, and no `shape` in either `bottomSheetTheme`.
12. **Transient feedback split 61 SnackBar / 7 showTopToast** across 35 files — the top-toast pattern
    landed in this commit specifically to stop bottom snackbars covering CTAs; 5 of the 61 are in
    `service_booking_screen.dart`, the exact screen the field report named.
13. **`PopScope(canPop: false)` with no callback** — `booking_confirmation_screen.dart:187-188`; the
    back gesture is silently inert.
14. **Empty-state fragmentation** — `HousepitalEmptyState` used in 5 files; `PaginatedListView` falls
    back to bare `Center(Text('No items found'))` (`paginated_list.dart:124-132`);
    `report_history_screen.dart:49` and `attendance_history_screen.dart:57` show a single grey word;
    `care_team_screen.dart` (402 lines) has no loading/error/empty branch at all.
15. **No spacing constants** — `lib/config/constants.dart` holds no design tokens; ~170 off-8pt-grid
    literals (6 ×49, 10 ×60, 14 ×55) and 17 distinct corner radii follow from that.
16. **Card press-feedback split** — 49 `HousepitalCard` (0.97 @120ms `easeOut`) vs 127 raw `Card(`
    (ripple only). Geometry matches; tap *feel* does not.
17. **Card shadow 3.5× spec opacity** — `theme.dart:267-268` `elevation: 3` + `black@0.35` vs the
    checklist's 10%.
18. **Button/input heights 2–3pt under spec** — 47pt buttons (`theme.dart:233`) and 48pt inputs
    (`theme.dart:292`) vs 50pt; button radius 12 vs 16.
19. **Implicit animations default to `Curves.linear`** — ~12 `AnimatedOpacity`/`AnimatedContainer` sites
    omit `curve:` (e.g. `my_care_screen.dart:99-104`, `billing_screen.dart:155-159`); spec wants
    ease-out on enter.
20. **Haptics: 8 sites total**, and `heavyImpact` is used for the SOS *action* rather than for errors.
21. **Semantics coverage: 24 of 98 files** in `lib/screens` + `lib/widgets`.
22. **Stale documentation contradicting shipped code (Low, but corrosive):**
    - `lib/widgets/glass.dart:22` documents trailing order `[custom…, cart, search, home]`; the code
      (`:74-84`) and the guard test (`test/widgets/glass_app_bar_test.dart:73-80`) both implement
      `[custom…, home, search, cart]`.
    - `test/screens/main_shell_test.dart:3-9` describes a "floating-pill / DETACHED capsule, radius 32"
      nav bar; the assertions (`:189-234`) correctly test the fixed full-width orange bar. Header only.
    - `lib/config/theme.dart:159`, `:231`, `:325`, `:416` all say "dark ink on orange" / "white on
      orange fails AA" while the value shipped is `onOrange = #FFFFFF`. `lib/config/app_colors.dart:63-64`
      says "both modes use the same dark ink" — also false.
    - `lib/config/theme.dart:10` says surface is `#1A1A1A`; `:16` sets `#000000`. The dark-orange ratio
      comment at `:28` ("6.32:1 vs surface #1A1A1A") is therefore stale — the real value on `#000000`
      is 8.99:1.
    - `lib/screens/services/service_catalog_screen.dart:128` says "6 tab bodies"; there are **7**
      (`:133-140`).

## BLOCKED-OWNER

| Item | What I'd need |
|---|---|
| VoiceOver actually tested on device | A device/simulator VoiceOver pass. Source can prove `Semantics` nodes exist (72 of them) but not that the spoken order, grouping, and focus traversal are sensible. |
| "3-Second Test" / "Squint Test" with real users | The checklist defines these as *human* tests (§5.1). My grades are structural proxies. |
| Rendered contrast at runtime | All ratios above are computed from declared token hexes. The `GlassSurface` bar (`glass.dart:145-152`) composites 55%-opacity fill over live scrolling content, so **text on the app bar has a variable, content-dependent contrast** that only a runtime capture can measure. Recommend a screenshot pass over the 7 `extendBodyBehindAppBar` screens. |
| Whether the 4-icon app bar is acceptable to the owner | §1.1 flags density; `CLAUDE.md` records the owner explicitly *asked* for home + search + cart on every screen. Reported as a measured fact, not a defect. |
| Dynamic Type / large-text layout at 1.4× | `overflow_smoke_test.dart` covers 320/375/414 widths but with the Ahem font at scale 1. The 1.4× clamp (`main.dart:417`) is untested at the layout level. |

---

*Read-only audit. No files under `lib/`, `test/`, or `scripts/` were modified.*
