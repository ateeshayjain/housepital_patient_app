# Apple Design Framework — Complete Standard (v1.0, Feb 2026) — Audit **round 2** vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Auditor:** Apple-Design-Framework agent · **Method:** read-only.

`rg`/`grep` sweeps + direct reads of `lib/main.dart`, `lib/screens/main_shell.dart`,
`lib/config/theme.dart`, `lib/config/app_colors.dart`, `lib/data/demo_mode.dart`,
`lib/screens/settings/delete_account_screen.dart`, every root-tab screen, and the
`ios/Runner/Assets.xcassets` icon + launch sets (inspected with `sips` and read as images).
Ran `bash scripts/check_design_consistency.sh` — **PASS**. Did **not** run
`flutter test/build/clean` per brief; central results cited where relevant.
All contrast ratios recomputed this round with a WCAG 2.x relative-luminance calculator
validated against reference pairs (`#767676`/white = 4.54, black/white = 21.0, `#0000FF`/white = 8.59).

---

## Changed since round 1

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **N-1 Blocker** — `/services` → bare `const Scaffold()`, blank screen, no way back | ✅ **FIXED, and the fix is sound** | `lib/main.dart:568-569` now returns `const _RootTabRedirect(tabIndex: 2)`; `:802-834` pops to the first route then `MainShell.switchToTab(2)`. Verified it cannot strand — see §Verification A |
| **N-2 Blocker** — `orangeText`/`orangeDark`/`warning` documented as AA-passing, measure 3.99 / 3.62 / 3.79 | ❌ **UNCHANGED** — was not in the blocker fix list and `theme.dart` was not touched in `803124d..820060b` | `git diff --stat 803124d 820060b` lists no `lib/config/theme.dart`; comments still read "4.6:1" (`theme.dart:62`), "4.5:1" (`:64`), "4.6:1" (`:87`). Re-measured: **3.99 / 3.62 / 3.79** |
| **N-3 High** — GlassAppBar unpaired with `extendBodyBehindAppBar` | ⚠️ **UNCHANGED (ratio identical)** | now **8 of 46** files comply (was 7 of 45). The one new compliant file is `delete_account_screen.dart:126`. The non-compliant count is still **38** |
| **N-4 High** — four root-tab header idioms | ❌ **WORSENED → five** | the demo banner (`main_shell.dart:64`) inserts a sixth chrome layer above all five tabs; My Care's trailing group grew to 4 icons (`my_care_screen.dart:86-95`). See §Round-2 specifics C |
| **N-5 High** — SOS: one entry point, scrolls off-screen, `SOSButton` dead | ❌ **UNCHANGED** | `grep -rn "'/sos'" lib` → still exactly 2 hits (`main.dart:447`, `home_screen.dart:493`); `SOSButton(` instantiations = **0** outside its own declaration; `home_screen.dart` diff this round added only a `SessionScope` import |
| **N-6 High** — nav unselected labels 1.82:1 | ❌ **UNCHANGED** | `main_shell.dart:91` still `context.hc.onOrange.withValues(alpha: 0.7)` |
| **N-7 High** — errors rendered as empty states | ❌ **UNCHANGED** | `transaction_log_screen.dart:60` and `notifications_screen.dart:47` still `showEmptyOnError: true` |
| **N-8 High** — destructive actions with no confirmation | ❌ **UNCHANGED** | `patient_profile_screen.dart:145-150` still `setState` + `removeAt` on an **emergency contact**; `care_calendar_screen.dart:1308-1313` still deletes a reminder straight through; `cart_screen.dart:982` still `cart.removeSaved(index)` |
| **N-9 High** — booking wizard: raw `AppBar`, overloaded back, no `PopScope` | ❌ **UNCHANGED** | `grep -rn PopScope lib` → **one** hit, `booking_confirmation_screen.dart:187` |
| **N-10..N-14 Med/Low** — gate scope, sheet geometry, SnackBar split, dead `PopScope`, stale docs | ❌ **ALL UNCHANGED** | none of `scripts/check_design_consistency.sh`, `paginated_list.dart`, `document_attach_widgets.dart`, `glass.dart` appear in the round diff |
| Previously-fixed items (radius 14, `Colors.grey.shade*`, raw hex, rainbow, 11px floor, text-scale clamp, 44pt floors) | ✅ **STILL HOLDING** | gate re-run this round: `✓ Design-consistency check passed`. fontSize histogram grew only on-canon (12: 191→192, 13: 200→202, 14: 184→186, 16: 138→141) — the new screen introduced **no** new off-canon size |
| Test/doc staleness on tab count | ✅ **CLEAN** | `test/screens/main_shell_test.dart:228-242` asserts five tabs and `barLabel('Calendar') findsNothing`; no `.dart`/`.md` outside `docs/audits/` asserts six tabs |

**Net movement: 1 blocker closed, 3 new failures opened.** Round 1: 33 ✅ / 39 ⚠️ / 10 ❌.
Round 2: **29 ✅ / 42 ⚠️ / 11 ❌.** The regression is concentrated in the new shell chrome.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1.1 Calm Command pillars (4) | 1 | 3 | 0 | 0 |
| 1.2 Ten First Principles (10) | 1 | 5 | 4 | 0 |
| 2.1 Typography system (5) | 0 | 2 | 3 | 0 |
| 2.2 Color system (8) | 4 | 3 | 1 | 0 |
| 2.3 Spacing & layout (9) | 4 | 4 | 1 | 0 |
| 3.1 Touch targets (3) | 2 | 1 | 0 | 0 |
| 3.2 Animation (6) | 4 | 2 | 0 | 0 |
| 3.3 Feedback patterns (3) | 1 | 2 | 0 | 0 |
| 4.1 Buttons (4) | 1 | 3 | 0 | 0 |
| 4.2 Cards (4) | 2 | 2 | 0 | 0 |
| 4.3 Forms (4) | 1 | 3 | 0 | 0 |
| 5.1 Quick tests (3) | 0 | 3 | 0 | 0 |
| 5.2 Accessibility checklist (6+1) | 2 | 2 | 1 | 1 |
| 5.3 Design review sign-off (9) | 3 | 5 | 1 | 0 |
| 6.1–6.3 Figma / PPT / Notion (14) | 0 | 0 | 0 | 14 |
| 6.4 Code implementation (5) | 3 | 2 | 0 | 0 |
| **TOTAL (82 scored + 15 N/A)** | **29** | **42** | **11** | **15** |

---

# Round-2 specifics (the four questions in the brief)

## A. Verification — does `_RootTabRedirect` actually restore a usable state? ✅ **YES**

`lib/main.dart:802-834`:

```dart
class _RootTabRedirectState extends State<_RootTabRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      MainShell.switchToTab(widget.tabIndex);
    });
  }
  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
}
```

I traced every way the user can arrive and every way it can fail:

| Concern | Verdict | Evidence |
|---|---|---|
| Is the first route actually the shell? | ✅ | `main.dart:418` `home: const SplashScreen()`; `splash_screen.dart:17` `pushReplacementNamed('/home')`; `main.dart:437-438` `/home` → `MainShell(key: MainShell.shellKey)`. After the splash **replaces** itself, `isFirst` **is** the shell |
| Does `switchToTab` actually reach a live state? | ✅ | the shell is built **with** `MainShell.shellKey` at both `main.dart:438` and `:769`, and `MainShellState` survives (it is the first route, never disposed) |
| What if `shellKey.currentState` were null? | ✅ **fails safe** | `MainShell.switchToTab` (`main_shell.dart:21-23`) is a null-aware no-op, and `popUntil` has already returned the user to the shell — worst case they land on Home instead of Services. No stranding path exists |
| Live entry point still works? | ✅ | `assistant_service.dart:189` maps `services`/`dikhao`/`kholo` → `'/services'`; `assistant_screen.dart` pushes it. Stack `MainShell → AssistantScreen → redirect`; `popUntil(isFirst)` clears both, leaving Services selected |
| Bounds-checked? | ✅ | `switchTab` guards `index >= 0 && index < _screens.length` (`main_shell.dart:46`) |

**One inaccuracy in the fix's own comment.** `main.dart:806-807` says the redirect "never paints a frame."
It does — `build()` returns a real `Scaffold`, and `addPostFrameCallback` fires *after* frame 1, by which
point `MaterialPageRoute`'s ~350ms iOS slide has begun. The user sees a brief blank page slide in and
immediately slide back out. Functionally safe, visually a stutter. — **Fix:** use
`PageRouteBuilder(opaque: false, transitionDuration: Duration.zero)` for this one route so the redirect
is genuinely invisible, and correct the comment.

**Grade: ✅ blocker closed.** ⚠️ Low: transition stutter + a comment that overstates.

## B. The sample-data banner as chrome — ❌ **it fights all three: large titles, glass bars, and safe areas**

`main_shell.dart:58-72` puts `_DemoDataBanner` **above** the `IndexedStack`, inside a `Column`,
on a `Scaffold` that has **no `appBar:`**.

### B-1. ❌ It double-counts the top safe-area inset on every screen in the app

The mechanism is deterministic:

1. `main_shell.dart:54` — the shell `Scaffold` declares **no `appBar:`**, so Scaffold does **not**
   `removePadding(removeTop: true)` from its `body`.
2. `main_shell.dart:143` — the banner's `SafeArea(bottom: false)` inserts `MediaQuery.padding.top`
   (≈47pt on an iPhone 14/15/16) above its own text. `SafeArea` calls `MediaQuery.removePadding`
   **for its own child only** — never for its siblings in the `Column`.
3. `main_shell.dart:65-70` — the `Expanded(IndexedStack(...))` therefore still reads
   `MediaQuery.of(context).padding.top == 47`, while it is now laid out starting at
   y ≈ 47 + 8 + ~17 + 8 ≈ **80pt**.
4. Each tab is its own `Scaffold` + `GlassAppBar`; `AppBar` adds `MediaQuery.padding.top` above its
   56pt toolbar → the bar becomes **103pt** tall and begins at y≈80.

Net: a **~47pt empty band inside every screen**, below the banner and above the app-bar title.
Two tabs then add it a **third** time in their scroll padding:
`billing_screen.dart:173` `MediaQuery.of(context).padding.top + kToolbarHeight + 16` and
`my_care_screen.dart:141` `… + 8`. `delete_account_screen.dart:123` does the same.

— **Impact:** this is the app's **default** state — `api.housepital.in` does not resolve, so
`markServingDemoData()` fires on first load (`app_provider.dart:260`) and the banner is up for the
entire session. Every screen in the app currently renders with roughly one-and-a-half phantom notches
of dead space. Directly fails §2.3 "Always respect system safe areas".
— **Fix:** wrap the stack in `MediaQuery.removePadding(context: context, removeTop: true, child: …)`
when the banner is visible — or, better, stop treating this as body content at all (see B-3).

### B-2. ❌ It breaks the glass app-bar material and the large-title pattern

- **Glass.** `GlassSurface` (`glass.dart:145-156`) is a `BackdropFilter` that is only meaningful when
  content passes under it. On the 8 screens that *do* pair `extendBodyBehindAppBar`
  (`assistant_screen`, `delete_account_screen`, `care_calendar_screen`, `service_detail_screen`,
  `my_care_screen`, `care_team_screen`, `service_catalog_screen`, `billing_screen`) the whole glass
  assembly now floats **below** an opaque cream band instead of merging with the status bar.
  The defining iOS chrome behaviour — nav bar and status bar reading as one surface — is gone app-wide
  while the banner is up.
- **Large titles.** My Care and Billing implement the iOS collapsing large title
  (`my_care_screen.dart:99-105`, `billing_screen.dart:153-160`). The collapse itself still works (it is
  scroll-driven), but the resting large title now starts ~127pt down the screen instead of ~103pt,
  and the first thing the user reads on every tab is a warning, not the screen's own title. §1.2 P3
  ("most important information largest and highest") inverts: the highest element on all five tabs is
  12pt caption text.
- **Home.** Home has no `AppBar` at all (`home_screen.dart:103`); the banner is now the **only** top
  chrome on tab 0, which is a fifth distinct header treatment (see C).

### B-3. Content and accessibility of the banner itself

| Item | Verdict | Evidence |
|---|---|---|
| Contrast | ✅ | light: `#212121` on `#FFF3E0` = **14.68:1**; dark: `hc.black`→`HousepitalColorsDark.textPrimary #F2F2F2` on `#3A2D14` = **11.98:1** (`app_colors.dart:107,114`). Both AAA |
| Non-dismissible, persistent | ✅ correct call | the condition persists; the dartdoc's reasoning (`main_shell.dart:126-131`) is sound |
| Icon + text, not colour alone | ✅ | `Icons.info_outline` (`:149`) |
| **Localized** | ❌ | hardcoded English at `main_shell.dart:153-154`; `grep "Showing sample" assets/i18n/*.json` → **no match**. Violates the CLAUDE.md contract ("every new user-facing string gets a key in BOTH en.json and hi.json"); the `i18n_sync_test.dart` guard cannot catch a string that never became a key |
| **Offers recovery** | ❌ | §1.2 P7 requires errors to explain *and* offer a fix. It explains; there is no Retry, no "learn more", no tap target at all |
| **Announced to VoiceOver** | ❌ | no `Semantics(liveRegion: true)`. A banner that appears asynchronously mid-session is silent to a screen-reader user |
| Regression-tested | ❌ | `test/screens/main_shell_test.dart` has no banner test (`grep -in banner` → 0 hits). The layout consequence in B-1 would have been caught by a golden or a `tester.getTopLeft` assertion |

### B-4. The flag it renders can lie in both directions

- **False-negative.** `DemoMode.reset()` is called at exactly one place — `app_provider.dart:247`,
  when the **dashboard** fetch succeeds. It resets a single global flag that five other providers set.
  If the dashboard endpoint recovers while `MedicationProvider` (`:191`, `:236`),
  `MyCareProvider` (`:50`, `:98`), `BillingProvider` (`:43`) or `OrdersProvider` (`:199`) are still
  serving `DemoData`, the banner **disappears while sample medication schedules and sample vitals stay
  on screen** — the precise failure the banner exists to prevent.
- **Unmarked fallback.** `blog_provider.dart:38` and `:68` serve `DemoData.articles` with **no**
  `markServingDemoData()` call. Lower clinical stakes than vitals, but it is a genuine gap in the
  "every provider that serves a demo fallback calls markServingDemoData" contract asserted in
  `demo_mode.dart:11-13`.
— **Fix:** make it a counter/`Set<String>` of provider ids rather than a bool, so the banner drops only
when every registered source is live; add the `blog_provider` call.

### B-5. What it should be instead

Apple's idiom for "the data you are seeing is not live" is a **chrome-level** notice that participates in
the nav bar (a subtitle / status line under the title, or a bar-tinted state), not a body-level band that
translates the entire app down. — **Fix:** move it into `GlassAppBar` as an optional status strip inside
`bottom:` (which already exists and already sizes correctly — `glass.dart:52-53`), or render it as an
overlay in the `Stack` **below** the safe-area inset. Either removes B-1 and B-2 entirely.

**Grade: ❌.** As chrome, this is a net regression despite the underlying safety idea being right.

## C. Did five tabs improve or worsen the header-idiom inconsistency? — **Worsened.**

Round 1 already measured the five-tab tree, so the tab count itself changed nothing. What changed in
round 2 made it worse in two ways.

| Tab | Header idiom (round 2) | Evidence |
|---|---|---|
| Home (0) | **No `AppBar`.** Hand-rolled in-body header (logo + bell + search + cart + SOS) that scrolls away — now sitting under the banner, which is its only fixed chrome | `home_screen.dart:103`, `:375-530` |
| My Care (1) | `GlassAppBar` + collapsing in-body large title; trailing group now **four** icons (calendar → home → search → cart) | `my_care_screen.dart:84-105`, new action at `:86-95` |
| Services (2) | `GlassAppBar` with a **static, non-collapsing** 28/w800 title inside `bottom:` + a 7-tab `TabBar` | `service_catalog_screen.dart:129-170` |
| Billing (3) | `GlassAppBar` + collapsing in-body large title | `billing_screen.dart:146-160` |
| More (4) | `GlassAppBar` with a **plain 20pt title**, no large title | `settings_screen.dart:88-91` |
| **All five** | **plus** a persistent non-dismissible band above everything | `main_shell.dart:64` |

Two regressions:
1. **My Care's app bar grew to four trailing icons** with the calendar action, against Home's five
   hand-rolled controls, Services' two, Billing's two, More's three. The 6→5 tab consolidation moved
   density from the nav bar into the app bar rather than removing it.
2. **The banner is now the top-most element on all five**, which means the *only* consistent header
   element in the app is a warning message. On Home it is the only fixed header at all.

Still **four title treatments across five tabs**, unchanged from round 1 — but the surface above them
is new and the icon counts diverged further.
— **Fix (unchanged from round 1):** adopt the My Care/Billing collapsing large title on Services and
More; it already has two working implementations to copy. Then move the banner into the bar.

## D. The new app icon — ❌ **not submission-quality. Do not ship it.**

Inspected `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (all 16 PNGs + `Contents.json`), read the
1024 master and a 4× magnification of the 40×40 as images.

| Apple icon requirement | Verdict | Evidence |
|---|---|---|
| **Crisp at every size** | ❌ | the 1024 master is a visibly soft, resampled raster — every edge of the ring and the nurse's cap carries a 3–6px blur halo. This is upscaling from a small source, exactly as the brief describes. Apple's App Review 2.3.8 treats blurry/pixelated icons as a quality rejection |
| **Artwork fills the canvas** | ❌ | the mark occupies roughly the middle 50% of the 1024 square with ~25% white margin on each side. iOS applies its own rounded-rect mask and expects a **full-bleed** square; self-imposed padding makes the icon read visibly smaller and weaker than every neighbour on the home screen |
| **Legible at 40×40 / 29×29** | ❌ | at 40×40 the white cross inside the cap collapses to 2–3 mud-coloured pixels and the cap reads as an unidentified orange blob. The self-imposed padding compounds it: the effective mark is ~20pt inside a 40pt tile |
| **No alpha channel** | ✅ | `sips -g hasAlpha` → `no` on 1024, 180 and 40. Correct — alpha is an automatic upload rejection |
| Correct sizes present | ✅ | all 15 required iPhone/iPad sizes, dimensions verified (1024², 180², 40²) |
| **Avoid pure-white backgrounds** | ⚠️ | the background is `#FFFFFF`. Icons get no border on iOS, so a white icon dissolves into light wallpapers. Brand orange or a subtle orange gradient would separate it and is on-brand |
| **iOS 18+ dark & tinted variants** | ❌ | `Contents.json` contains **zero** `appearances` entries (`grep -c 'appearances\|luminosity\|tinted'` → 0). On iOS 18+ dark/tinted home screens the system auto-derives a variant from a white-background icon, which produces a washed grey tile |
| Recognisable / distinct | ⚠️ | the mark itself (ring + nurse's cap + face) is a good, ownable idea and is genuinely readable at ≥120pt. The execution, not the concept, is the problem |

**Plain answer: no.** It is a better placeholder than the stock Flutter logo, but it is a blurry,
over-padded, white-background upscale with no dark/tinted variants. It will look conspicuously
amateur next to any other app on the home screen and is a plausible 2.3.8 rejection.
— **Fix:** re-export the mark from **vector** at 1024×1024, full-bleed, on brand orange (or a
1-stop orange gradient) with the cap/face in white; drop the cross detail or thicken it to ≥6% of the
canvas so it survives 29pt; add `appearances` entries with a dark and a tinted (monochrome-safe)
variant. `assets/images/housepital_logo.png` (1200×312, alpha) is a wordmark lockup, not a suitable
icon source — the icon needs the standalone glyph at vector fidelity.

**Related, same asset pass — ❌ the launch screen is light-mode-only.**
`ios/Runner/Base.lproj/LaunchScreen.storyboard:22` hardcodes
`<color key="backgroundColor" red="1" green="1" blue="1" alpha="1"/>` — literal white, not
`systemBackground`. `LaunchImage@3x.png` is 282×360 with alpha, `contentMode="center"`. So on a
dark-mode device the app launches to a **full white screen** and then cuts to the app's true-black
surface (`theme.dart:16` `#000000`). That is the single most jarring transition in the product and it
happens on every cold start. — **Fix:** set the storyboard background to the `systemBackground` named
colour (or add a `LaunchBackground` color set with light/dark values) and supply a dark `LaunchImage`
appearance.

## E. `delete_account_screen.dart` vs the destructive-action pattern — ⚠️ **strong content, three real defects**

`lib/screens/settings/delete_account_screen.dart` (247 lines), reached from
`settings_screen.dart:273-279` (tile correctly tinted `context.hc.error`).

**What it gets right — genuinely above the app's own bar:**

- ✅ **Confirmation depth exceeds spec.** Checkbox (`:185-194`) **and** typed `DELETE` (`:199-208`)
  **and** a final `AlertDialog` (`:91-119`). §1.2 P2 asks for "explicit confirmation"; this is three gates.
- ✅ **Destructive button styling is correct** — `backgroundColor: context.hc.error` + white
  foreground (`:213-217`) = **4.98:1**, matching §4.1's Destructive row and the
  `confirmDestructiveAction` house style.
- ✅ **Honours the glass contract** — `extendBodyBehindAppBar: true` (`:126`) + `topPad` (`:123`).
  It is one of only 8 screens in the app that do, and it correctly opts out of the cart (`:131`).
- ✅ **The copy is honest** — "What gets deleted" / "What we must keep" (`:142-177`), and the dartdoc
  at `:17-27` explicitly refuses to claim server-side erasure it cannot perform. This is the right call.
- ✅ On-canon type only (16/14/13), `HousepitalCard`, `context.hc.*` throughout. Gate passes.

**Defects:**

- ❌ **After deleting the account the user is returned to the working app.** `:82-83` the success
  dialog's only action is `Navigator.of(context).popUntil((route) => route.isFirst)` — and `isFirst`
  is `/home` → `MainShell` (`main.dart:438`, reached via `splash_screen.dart:17`'s
  `pushReplacementNamed`). There is **no auth gate**: `main.dart:417` shows the auth-aware
  `home: Consumer<AuthProvider>(…)` **commented out**. So "Delete my account" → "Everything on this
  phone has been erased" → **Done** → the user is standing on the Home tab of a fully navigable app.
  `settings_screen.dart:452-460` (Logout) has the same shape, so the two are at least consistent —
  consistently wrong. — **Impact:** breaks §1.2 P2 (predictable behaviour) at the highest-stakes
  moment in the app, and undermines the App Store 5.1.1(v) claim the screen was built to satisfy.
  — **Fix:** `Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false)` from both, and
  re-enable the auth-gated `home:`.
- ⚠️ **A third competing destructive-confirmation idiom.** The app already has
  `confirmDestructiveAction` (`common_widgets.dart:501`, 8 call sites) — this screen hand-rolls its own
  `AlertDialog` (`:92-118`) instead. Combined with the three paths that confirm *nothing* (round-1 N-8,
  still open), the app now has **three** behaviours for "user is about to destroy something":
  helper dialog · bespoke dialog · silence. §1.1 "same action, same result, everywhere".
  — **Fix:** the helper takes `title`/`message`/`confirmLabel`; this screen's dialog fits it exactly.
- ⚠️ **Not localized.** ~22 user-facing strings, all hardcoded English (`:72-78`, `:95-98`, `:136-197`,
  `:226`), including the phone number `9990-911-911` twice (`:78`, `:181`). Same contract breach as
  the banner, on the one screen a Hindi-first user most needs to understand before acting.
- ⚠️ **No haptic on the destructive commit** (`:110-113`). §3.3 reserves heavy impact for exactly this;
  the app already uses `HapticFeedback.heavyImpact` for SOS.
- ⚠️ **Button 48pt** (`:211`) vs the checklist's 50pt — consistent with the rest of the app (§4.1), not
  a new defect, but the one place a new screen could have set the corrected precedent.
- ⚠️ **No `PopScope`.** Half-completed state (box ticked, `DELETE` typed) is silently discarded by the
  iOS edge-swipe. Low stakes here — losing progress on a deletion form is the safe direction — but it
  is the same gap as N-9.
- Low: `:214-215` `backgroundColor: _canSubmit ? context.hc.error : context.hc.grey` — the `grey` arm
  never renders. `ElevatedButton.styleFrom` maps `backgroundColor` to the **enabled** state only;
  with `onPressed: null` Material falls back to its own disabled colour because
  `disabledBackgroundColor` is unset. Dead ternary; the visual outcome happens to be correct.
- Low: `:203-206` sets a bare `border: OutlineInputBorder()` locally, contradicting the app's
  `InputDecorationTheme` (radius 12, `theme.dart:280-283`). Theme `enabledBorder`/`focusedBorder` still
  win in practice, so the override is inert — but it is the only field in the app that declares one.

---

# Findings

## 1. Philosophy & First Principles

### 1.1 Calm Command pillars

- ⚠️ **Clarity over decoration** — the calm pass holds (rainbow retired, one accent gate-enforced,
  true-black tonal dark). But chrome density **increased**: `glass.dart:74-84` still packs up to four
  trailing icons, My Care now uses all four (`my_care_screen.dart:86-95`), Home adds a fifth control,
  and the banner adds a full-width band above all of it.
- ✅ **Consistency breeds confidence** *(for the enforced layer)* — `GlassAppBar` trailing order is
  contract-tested (`test/widgets/glass_app_bar_test.dart:73-80`, custom → home → search → cart by
  measured `dx`). Note the dartdoc at `glass.dart:22` still documents the **wrong** order
  (`cart, search, home`) — round-1 N-14, unfixed.
- ⚠️ **Whitespace is not empty** — unchanged off-grid tail (§2.3).
- ⚠️ **Hierarchy guides the eye** — *downgraded from ✅*. The banner makes 12pt caption text the
  topmost element on all five tabs (§B-2).

### 1.2 The Ten First Principles

**P1 Immediate Recognition — ⚠️ (was ❌).** `/services` is fixed and verified (§A). The residual
failure is the **More** tab: a `ListView` of undifferentiated `ListTile`s with no large title and two
`Divider`s for structure (`settings_screen.dart:88-280`) — cover the 20pt title and nothing says
"account & settings".

**P2 Predictable Behavior — ❌.** Four independent breaks, three unchanged plus one new:
- (a) chrome contract honoured on **8 of 46** screens; 38 `GlassAppBar` screens have no
  `extendBodyBehindAppBar`, so `BackdropFilter` (`glass.dart:156`) has nothing to blur and the bar
  degrades to a flat 55% fill. Two visibly different bar materials app-wide.
- (b) `service_booking_screen.dart:325-336` — raw Material `AppBar`, hardcoded `Icons.arrow_back`,
  back overloaded to step the wizard, **no `PopScope`**. iOS edge-swipe destroys a half-completed
  priced booking; the arrow one pixel away steps back one page.
- (c) `booking_confirmation_screen.dart:187-188` — `PopScope(canPop: false)` with no
  `onPopInvokedWithResult`: the back gesture does nothing and says nothing.
- (d) **NEW** — logout (`settings_screen.dart:452-460`) and account deletion
  (`delete_account_screen.dart:82-83`) both leave the user inside the authenticated shell (§E).

**P3 Information Hierarchy — ❌.** Four title idioms across five tabs, plus the banner above all of
them (§C). ⚠️ Progressive disclosure remains good: 25 modal sheets carry tertiary detail.

**P4 Touch-First Design — ⚠️.** 44pt floors reserved at 11 sites; every zero-padding `IconButton`
carries compensating `constraints`; nav items ≥64pt wide. **Unchanged failure:** SOS sits in the *top*
trailing corner of Home (`home_screen.dart:483`) inside the `SingleChildScrollView` at `:110`, so it
scrolls out of view; the comment at `:481-483` claims persistence the code does not deliver;
`SOSButton` (`common_widgets.dart:586-648`, with `heavyImpact` + `Semantics`) is still instantiated
**zero** times; there is no SOS on 4 of 5 tabs.

**P5 Meaningful Motion — ✅.** Durations 100–500ms for all UI animation; the three >500ms values are
`Future.delayed` network simulations and a tracking sweep. No infinite pulses (`grep '\.repeat('` →
one comment recording the removal).

**P6 Accessible by Default — ❌.** See §5.2. Headline unchanged: three tokens documented as AA-passing
measure 3.99 / 3.62 / 3.79, and nav unselected labels measure 1.82:1.

**P7 Error Prevention — ⚠️.**
- (a) **Errors disguised as empty states, unchanged.** `paginated_list.dart:140-165` renders the
  caller's `emptyWidget` on an initial-load *failure* when `showEmptyOnError: true`. Both opt-ins
  survive: `transaction_log_screen.dart:60` (a failed fetch reads "you have no transactions" on a
  **billing** screen) and `notifications_screen.dart:47` ("you're all caught up"). No retry offered;
  the widget's own error branch at `:167-185` already has one.
- (b) **Unconfirmed destructive actions, unchanged.** Emergency contact
  (`patient_profile_screen.dart:145-150`) and care reminder (`care_calendar_screen.dart:1308-1313`)
  delete straight through, each two rows from a sibling that *does* confirm; saved-for-later
  (`cart_screen.dart:982`) likewise. The emergency-contact case remains the serious one — a single
  mis-tap silently deletes a safety contact from a home-healthcare app, no undo.
- (c) **NEW positive** — `delete_account_screen.dart` is the best-confirmed destructive path in the app
  (§E), which makes the three silent ones stand out more, not less.
- ✅ `AutovalidateMode.onUserInteraction` on 8 forms. ⚠️ 45 `TextFormField`s vs 32 `validator:`.

**P8 Performance Perception — ⚠️.** Skeletons on 2 screens; everything else is a bare spinner
(`CircularProgressIndicator` ×24, `LoadingWidget` on 10). Offline/optimistic behaviour is strong.

**P9 Platform Authenticity — ❌ against the literal spec.** Unchanged inventory: 61 Material
`SnackBar` sites vs 7 `showTopToast`; 40 `DropdownButton`; 14 `Switch`/`SwitchListTile`; 3
`showDatePicker`/`showTimePicker`; 5 `FloatingActionButton` + the global `AssistantFab`; 3 underline
`TabBar`s; Material icon set app-wide (`grep Cupertino lib` → 1 hit, a localization delegate).
Mitigating: no `pageTransitionsTheme` override, so iOS gets Cupertino slide + edge-swipe free, and
safe areas are otherwise respected. **New this round:** §B-1 means the safe-area claim no longer holds
in the app's default state.

**P10 Graceful Degradation — ⚠️ (was ✅).** `/services`, the only degradation hole in round 1, is
fixed. But the *new* degradation-signalling layer has two holes: `DemoMode.reset()` is keyed to one
provider and can take the banner down while five others still serve sample data (§B-4), and
`blog_provider.dart:38,68` never marks. A safety mechanism that can silently lie is worse than none.

---

## 2. Visual Standards

### 2.1 Typography — unchanged

Histogram re-run this round (`scripts/check_design_consistency.sh`, `lib/screens` + `lib/widgets`):

```
  1 9.5   95 11  192 12  202 13  186 14   2 14.5
 61 15   141 16   34 18   17 20    6 22   8 24
 12 28     2 32    6 36
```

- ❌ **Large Title 34/Bold** — absent. Display size is 28 (×12); 32 (×2) and 36 (×6) are unaccounted-for.
- ⚠️ **Title 1 28/Bold** — present and dominant, but at w800.
- ❌ **Headline 17/Semibold** — **17pt does not exist anywhere.** The role is 16/w600 (`SectionHeader`).
- ❌ **Body 17/Regular** — the app's body sizes are 13 (×202) and 14 (×186), 3–4pt under platform standard.
- ⚠️ **Caption 12/Regular** — 12 ×192 ✅, but 11 ×95 sits below the checklist floor.

The new screen added **only on-canon** sizes (13/14/16) — the ratchet fix recommended in round 1 would
now cost nothing to adopt. ✅ Bundled `Archivo` + `NotoSansDevanagari`; no `google_fonts`.

### 2.2 Color System

| Role | Checklist | Shipped (light) | Measured on white | Verdict |
|---|---|---|---|---|
| Primary Action | `#007AFF` | `#F39314` | — | ✅ sanctioned brand override, one-accent budget gate-enforced |
| Success | `#34C759` | `#2E7D32` | **5.13:1** | ✅ (Apple's own value is 2.2:1 on white — this is objectively better) |
| Warning | `#FF9500` | `#E65100` | **3.79:1** | ❌ documented "4.6:1" at `theme.dart:87` |
| Error | `#FF3B30` | `#D32F2F` | **4.98:1** | ✅ |
| Neutral | `#8E8E93` | `#6B6B6B` | **5.33:1** | ✅ |

❌ **The AA premise of the design system is still wrong.** `scripts/check_design_consistency.sh:74-78`
bans raw orange as text *because* `orangeText` "keeps AA (4.6:1)". Re-measured this round:

| Token | Documented | **Measured** | Delta |
|---|---|---|---|
| `orangeText #B86E00` on white — `theme.dart:62` | 4.6:1 | **3.99:1** | −0.6, fails AA |
| `orangeText` on app bg `#F8F9FA` | — | **3.78:1** | fails AA |
| `orangeText` on `orangeLight #FFF3E0` | — | **3.63:1** | fails AA |
| `orangeDark #CC6E00` on white — `theme.dart:64` | 4.5:1 | **3.62:1** | −0.9, fails AA |
| `warning #E65100` on white — `theme.dart:87` | 4.6:1 | **3.79:1** | −0.8, fails AA |

`orangeText` is the default `TextButton` foreground app-wide (`theme.dart:255-259`), the chip label
(`:312`), `SectionHeader`'s "See All" (`common_widgets.dart:433`) and the empty-state CTA
(`empty_state.dart:92`). All three clear the 3:1 large-text floor, so this is a normal-text failure,
not a catastrophic one — but the codebase, the gate script and the round-1 fix list all assert it passes.
— **Fix:** `orangeText → #9A5C00` (**5.38:1** on white, **5.10:1** on `#F8F9FA`, **4.90:1** on
`#FFF3E0` — AA on all three surfaces it actually lands on); re-derive `orangeDark`/`warning`; correct
the four comments and the gate's stated rationale.

**Owner override, measured as instructed (not graded a defect):**
`onOrange = #FFFFFF` on `#F39314` = **2.33:1** (`theme.dart:70`, `:32`). The documented mitigation
(bold w600+, ≥14px — `theme.dart:65-69`) is honoured in the nav bar but enforced nowhere.

❌ **Not covered by that override:** `main_shell.dart:91` — unselected nav items are
`onOrange.withValues(alpha: 0.7)`. White@70% over `#F39314` resolves to `#FBDFB8` = **1.82:1**,
at `BottomNavigationBar`'s default 12pt unselected label. Four of five tab labels sit below even the
3:1 large-text floor and ~22% worse than the already-overridden 2.33:1. The app's primary navigation
is its least legible text. — **Fix:** keep all five labels at full white (matching the owner's rule
exactly) and differentiate state by weight + the already-wired `activeIcon`.

**Dark mode:** ✅ `#000000` page / `#1C1C1E` elevated / `#2C2C2E` high — an exact match to the
checklist's dark spec. ✅ off-white `#F2F2F2` text. ⚠️ `lib/widgets` is still outside the gate's
`SCAN_DIR` (`check_design_consistency.sh:18` = `lib/screens` only, while its own histogram scans both),
so `paginated_list.dart` (8 static light-palette refs → grey text at 3.19–3.94:1 in dark, backing
Report History / Attendance History / Notifications / Transaction Log) and
`document_attach_widgets.dart` (15 refs, `#E3F2FD`/`#FFF3E0` pastel **fills** as light-mode islands on
true black) remain unguarded. Also `HousepitalColorsDark.textDisabled #7A7A7A` is documented "4.2:1 on
card"; measured **3.96:1**.

### 2.3 Spacing & Layout

- ✅ Micro 4 · Small 8 · Medium 16 · Large 24 all present and dominant (8 is the single most-used value).
- ⚠️ XLarge 32 used only 14×; screen padding is 16 (a reasonable phone-width choice, a spec divergence).
- ⚠️ Off-grid strays: `6` ×49, `10` ×60, `14` ×55, plus singletons 3/5/18/26/30/34/42/50/88/100.
- ⚠️ 17 distinct corner radii; the banned `14` stays gone ✅, but 9/11/2.5/18/22 are unexplained.
- ✅ Minimum 16pt horizontal margins; ✅ tab bar ≥49pt (56 + inset); ✅ nav bar ≥44pt (`kToolbarHeight`).
- ❌ **Safe areas — regressed.** `main_shell.dart:58-72` double-counts `MediaQuery.padding.top` on
  every screen (§B-1), and triple-counts it on Billing (`:173`), My Care (`:141`) and Delete Account
  (`:123`). Round 1 graded this ✅.

---

## 3. Interaction Patterns

### 3.1 Touch Targets — unchanged
✅ 44pt floors at 11 sites; no unguarded zero-padding `IconButton`.
⚠️ 8pt inter-target spacing is not declared anywhere — `glass.dart:74-84` packs up to four 48pt
`IconButton`s with zero inter-button padding; My Care now uses all four.
✅ Primary actions in the thumb zone (nav, `AssistantFab`, sticky bottom CTAs) — **except SOS**.

### 3.2 Animation — unchanged
✅ micro 100–150ms (`HousepitalCard` 120ms), ✅ standard 200–300ms, ✅ complex 450–500ms,
✅ reduced motion honoured at 17 sites / 11 files.
⚠️ ~12 `AnimatedOpacity`/`AnimatedContainer` sites omit `curve:` and take `Curves.linear`
(`my_care_screen.dart:99-104`, `billing_screen.dart:155-159` — the large-title cross-fades);
no explicit `easeIn`/`easeInOut` outside controllers.

### 3.3 Feedback — unchanged
✅ visual press-scale 0.97 + ripple.
⚠️ **8 haptic sites app-wide**, and `heavyImpact` is used for the SOS *action* rather than for errors
as the spec reserves; the new deletion commit has none.
⚠️ **61 `showSnackBar` vs 7 `showTopToast`** across 35 files — the toast pattern landed specifically
because bottom snackbars covered the primary CTA ("I can't select slot"), and 5 of the 61 are still in
`service_booking_screen.dart`, the exact screen the field report named.

---

## 4. Component Library — unchanged from round 1

- **4.1 Buttons** — ⚠️ primary ≈47pt / radius 12 vs spec 50pt / 16 (`theme.dart:228-242`);
  ⚠️ secondary uses an orange border rather than gray; ⚠️ destructive *style* is correct
  (white on `#D32F2F` = 4.98:1) but three paths bypass confirmation entirely and a fourth
  (delete-account) hand-rolls its own; ✅/❌ text buttons have a 48pt hit target but a 3.99:1 label.
- **4.2 Cards** — ⚠️ radius 16 for all cards (deliberate continuous-corner choice, but every card is a
  "large card"); ⚠️ light shadow is `elevation: 3` + `black@0.35` (`theme.dart:267-268`) = **3.5×** the
  spec'd 10%; ✅ 16pt internal padding; ⚠️ press-scale covers 49 `HousepitalCard` vs 127 raw `Card(` —
  ~72% of cards have a different tap feel.
- **4.3 Forms** — ⚠️ inputs ≈48pt vs 50; ✅ label above field + 8pt; ⚠️ `errorBorder`/`focusedErrorBorder`
  undeclared in both themes; ⚠️ focus ring is 2pt ✅ but brand orange on white = 2.33:1, under
  WCAG 1.4.11's 3:1 for UI components.

---

## 5. QA & Validation

### 5.1 Quick Tests
- ⚠️ **3-Second Test (was ❌)** — `/services` no longer renders nothing. Residual: the **More** tab has
  no large title and no grouping beyond two dividers; and on every tab the first thing read is now the
  banner, not the screen's purpose.
- ⚠️ **Squint Test** — legible on Home / My Care / Billing. Weakest is Services: seven scrollable tabs
  under a static title (`service_catalog_screen.dart:133-140`).
- ⚠️ **Grayscale Test** — mostly passes (`StatusBadge` carries text, `VitalCard` carries icon + word,
  SOS pill carries the literal word, banner carries an icon). Weak spot: attendance status leans on
  `AttendanceHelper.getStatusColor` for the leading tint.

### 5.2 Accessibility Checklist

| Requirement | Standard | Measured (round 2) | Pass? |
|---|---|---|---|
| Text contrast | ≥4.5:1 | **Pass:** black/white 16.1 · grey/`#F8F9FA` 10.30 · greyLight/white 5.33 · success 5.13 · error 4.98 · info 5.75 · dark textSecondary/card 7.85 · dark error/card 4.88 · **banner light 14.68 · banner dark 11.98**. **Fail:** `orangeText` **3.99** · `orangeDark` **3.62** · `warning` **3.79** · nav unselected **1.82** · `paginated_list` grey on dark 3.19–3.94 · SOS subtitle white70 on `#D32F2F` 3.10 · dark `textDisabled`/card 3.96 · *owner-override* white-on-orange 2.33 | ❌ |
| Large text | ≥3:1 | 28pt titles at 16.1:1 ✅; nav labels (1.82) and white-on-orange (2.33) fail even this | ⚠️ |
| Touch targets | ≥44pt | 11 explicit reservations; none unguarded | ✅ |
| VoiceOver labels | All interactive | 72 `Semantics(` across 24 of 98 files, + 27 `tooltip:` + 17 `semanticLabel:`. **The new banner has none and is not a `liveRegion`** — it appears asynchronously and is silent | ⚠️ |
| Color-blind safe | Non-colour cues | `VitalCard` icon+word ✅, `StatusBadge` text ✅, nav filled/outlined `activeIcon` ✅, banner icon ✅ | ✅ |
| Reduced motion | Respects setting | 17 sites / 11 files | ✅ |
| VoiceOver tested on device | — | not verifiable from source | **BLOCKED-OWNER** |

### 5.3 Design Review Sign-Off

| ☐ | Item | Round-2 verdict |
|---|---|---|
| 1 | All screens pass 3-second test | ⚠️ *(was ❌)* — `/services` fixed; More tab still undifferentiated; banner pre-empts every title |
| 2 | Typography follows scale exactly | ❌ — no 17pt Headline/Body, no 34pt Large Title, 85 literals across 9 off-canon sizes |
| 3 | Colors use semantic system only | ⚠️ — excellent and gate-enforced in `lib/screens`; `lib/widgets` unscanned, 23 static refs |
| 4 | Dark mode tested | ⚠️ *(was ✅)* — token tests still pass, but the **launch screen is hardcoded white** (`LaunchScreen.storyboard:22`) and the icon set has no dark/tinted appearance |
| 5 | Accessibility checklist complete | ⚠️ — 4 of 6 verifiable rows pass |
| 6 | Animation durations within spec | ✅ |
| 7 | Error states designed | ⚠️ — `ErrorRetryWidget` on 6 screens; `PaginatedListView` hand-rolls its own; 2 screens suppress it entirely |
| 8 | Loading states designed | ✅ — every loading path has *a* state; only quality varies |
| 9 | Empty states designed | ⚠️ — `HousepitalEmptyState` used in 5 files; `paginated_list.dart:124-132` falls back to bare `Center(Text('No items found'))`; `care_team_screen.dart` (402 lines) has no loading/error/empty branch at all |

**Sheet geometry — unchanged.** 25 `showModalBottomSheet` sites; three top radii (16 / 20 / 28 + the M3
default); 6 with no drag handle including `my_orders_screen.dart:458`, which returns a `bool`; neither
`bottomSheetTheme` declares a `shape`.

---

## 6. Tool-Specific Guidelines

- **6.1 Figma / 6.2 PowerPoint / 6.3 Notion (14 items)** — **N/A.** No design files in the repo.
- **6.4 Code Implementation** — ⚠️ colour tokens excellent and gate-enforced in `lib/screens`,
  unenforced in `lib/widgets`; ❌→⚠️ **no spacing or radius constants exist** (`lib/config/constants.dart`
  is API/business only) — the root cause of the §2.3 tail; ✅ semantic colour names; ✅ typography scale
  exists via `textTheme` though 977 inline `fontSize:` literals bypass it; ✅ component library with
  genuinely substantive dartdoc (`common_widgets.dart`, `empty_state.dart`, `glass.dart`,
  `paginated_list.dart`, and now `demo_mode.dart` + `delete_account_screen.dart`, both of which explain
  *why* rather than *what*).

---

# Blockers (must fix before release)

1. **The sample-data banner double-counts the top safe-area inset on every screen.**
   `main_shell.dart:58-72` — no `appBar:` on the shell `Scaffold`, so `body` keeps
   `MediaQuery.padding.top`; the banner's own `SafeArea` removes padding only for its own child, and
   the `Expanded(IndexedStack)` sibling still sees the full inset while already positioned ~80pt down.
   Billing (`:173`), My Care (`:141`) and Delete Account (`:123`) add it a third time. This is the app's
   **default** state — the backend does not resolve, so the banner is up for the whole session.
   **Fix:** `MediaQuery.removePadding(removeTop: true)` around the stack, or move the notice into
   `GlassAppBar`'s existing `bottom:` slot.
2. **`orangeText` / `orangeDark` / `warning` fail WCAG AA while documented as passing** —
   `theme.dart:62, 64, 87`. Measured **3.99 / 3.62 / 3.79** vs claimed 4.6 / 4.5 / 4.6. Carried over
   unfixed from round 1; the file was not touched. `orangeText` is the default `TextButton` foreground
   app-wide, and `check_design_consistency.sh:74-78` enforces its use on the strength of the wrong
   number. **Fix:** `orangeText → #9A5C00`; re-derive the other two; correct four comments + the gate.
3. **The app icon is not submission-quality** — blurry upscaled raster, ~25% self-imposed white margin
   so it reads small on the home screen, the cap's cross illegible at 40×40, pure-white background, and
   **zero** iOS 18+ dark/tinted `appearances` in `Contents.json`. Plus the launch screen is hardcoded
   white (`LaunchScreen.storyboard:22`), so every cold start on a dark-mode device flashes full white
   before the true-black app. **Fix:** re-export full-bleed from vector at 1024², on brand orange, with
   dark + tinted variants; make the launch background a light/dark colour set.

# High

4. **Nav unselected labels at 1.82:1** — `main_shell.dart:91`. Not covered by the white-on-orange
   owner override; below even the 3:1 large-text floor, on the app's primary navigation.
5. **GlassAppBar chrome contract broken on 38 of 46 screens** — no paired `extendBodyBehindAppBar`;
   two visibly different bar materials app-wide. Unchanged ratio since round 1.
6. **Header idiom inconsistency worsened** — still four title treatments across five tabs, now with a
   sixth chrome layer above all of them and My Care's trailing group grown to four icons.
7. **SOS: one entry point, and it scrolls away** — `home_screen.dart:483-530` inside the scroll view at
   `:110`; `SOSButton` (`common_widgets.dart:586`) instantiated zero times; no SOS on 4 of 5 tabs.
8. **Errors rendered as empty states** — `transaction_log_screen.dart:60`,
   `notifications_screen.dart:47`, via `paginated_list.dart:140-165`. No retry; "load failed" is
   indistinguishable from "no data" on a billing surface.
9. **Two unconfirmed destructive actions** — emergency contact (`patient_profile_screen.dart:145`) and
   care reminder (`care_calendar_screen.dart:1312`), each two rows from a sibling that confirms.
10. **Booking wizard back is unpredictable** — `service_booking_screen.dart:325-336`: raw `AppBar`,
    hardcoded `Icons.arrow_back`, overloaded back, **no `PopScope`**.
11. **NEW — logout and account deletion leave the user inside the authenticated app** —
    `delete_account_screen.dart:82-83` and `settings_screen.dart:452-460` both end on the Home tab of a
    fully working shell, because `main.dart:417`'s auth-gated `home:` is commented out.
12. **NEW — the demo-mode flag can lie** — `DemoMode.reset()` fires from one provider
    (`app_provider.dart:247`) but is set by six, so the banner can drop while sample vitals and
    medication schedules are still on screen; `blog_provider.dart:38,68` serves `DemoData` without
    marking at all.

# Medium / Low

13. **New user-facing strings are not localized** — the banner (`main_shell.dart:153-154`) and ~22
    strings in `delete_account_screen.dart`. Breaks the CLAUDE.md i18n contract; `i18n_sync_test.dart`
    cannot catch a string that never became a key.
14. **The banner has no `Semantics(liveRegion: true)` and no regression test** — it appears
    asynchronously and is silent to VoiceOver; `main_shell_test.dart` has zero banner assertions.
15. **A third destructive-confirmation idiom** — `delete_account_screen.dart:92-118` hand-rolls an
    `AlertDialog` instead of `confirmDestructiveAction` (8 existing call sites). Three behaviours now
    exist for "about to destroy something": helper · bespoke · silence.
16. **`lib/widgets` is outside the design gate** (`check_design_consistency.sh:18`) —
    `paginated_list.dart` (8 static refs, 3.19–3.94:1 in dark) and `document_attach_widgets.dart`
    (15 refs, pastel fills on true black).
17. **Sheet geometry drift** — three top radii, 6 of 25 without a drag handle, no `shape` in either
    `bottomSheetTheme`.
18. **Transient feedback split 61 SnackBar / 7 showTopToast** across 35 files.
19. **`PopScope(canPop: false)` with no callback** — `booking_confirmation_screen.dart:187-188`.
20. **Empty-state fragmentation** — `HousepitalEmptyState` in 5 files; bare `Center(Text(…))` elsewhere;
    `care_team_screen.dart` has no loading/error/empty branch.
21. **No spacing or radius constants** — ~170 off-8pt-grid literals and 17 distinct radii follow.
22. **Card press-feedback split** — 49 `HousepitalCard` vs 127 raw `Card(`.
23. **Card shadow 3.5× spec opacity** (`theme.dart:267-268`); **button/input heights 2–3pt under spec**;
    **~12 implicit animations default to `Curves.linear`**; **8 haptic sites total**;
    **Semantics on 24 of 98 files**.
24. **`_RootTabRedirect` paints a visible frame** despite its comment claiming otherwise
    (`main.dart:806-807`) — a blank page slides in and back out. Use a zero-duration transparent route.
25. **Stale documentation contradicting shipped code** — all unfixed: `glass.dart:22` documents the
    wrong trailing order; `theme.dart:159,231,325,416` and `app_colors.dart:63-64` still say "dark ink
    on orange"; `theme.dart:9-10` says surface is `#1A1A1A` while `:16` sets `#000000` (making the
    `:28` ratio comment stale — the real value on black is 8.99:1);
    `service_catalog_screen.dart:128` says "6 tab bodies" where there are 7;
    `main_shell_test.dart:3-9`'s header describes a floating-pill nav the assertions correctly reject.

# BLOCKED-OWNER

| Item | What I would need |
|---|---|
| Exact pixel cost of the banner inset bug (Blocker 1) | A simulator screenshot of any tab with `DemoMode.isServingDemoData == true`, or a widget test asserting `tester.getTopLeft(find.text('My Care'))`. The *mechanism* is certain from the code; the precise gap depends on device inset |
| Whether the icon passes App Review | An actual TestFlight upload. Source proves it is a soft upscale with no dark/tinted variants; only Apple decides 2.3.8 |
| VoiceOver actually tested on device | A device/simulator VoiceOver pass. Source proves 72 `Semantics` nodes exist, not that traversal order is sensible |
| "3-Second" / "Squint" tests with real users | The checklist defines these as *human* tests (§5.1); my grades are structural proxies |
| Rendered contrast at runtime | All ratios are computed from declared token hexes. `GlassSurface` composites 55% opacity over live scrolling content, so app-bar text has content-dependent contrast only a runtime capture can measure |
| Dynamic Type at 1.4× | `overflow_smoke_test.dart` covers 320/375/414 at scale 1 with Ahem. The `main.dart:417` clamp is untested at layout level — and the banner now consumes vertical space that grows with text scale |

---

*Read-only audit. No files under `lib/`, `test/`, `scripts/`, or `ios/` were modified.*
