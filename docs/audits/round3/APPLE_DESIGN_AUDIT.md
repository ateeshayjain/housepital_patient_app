# Apple Design Framework — Complete Standard (v1.0, Feb 2026) — Audit **round 3** vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Auditor:** Apple-Design-Framework agent · **Method:** read-only.

Direct reads of `lib/screens/main_shell.dart`, `lib/widgets/demo_data_banner.dart`, `lib/widgets/glass.dart`,
`lib/main.dart`, `lib/config/theme.dart`, `lib/config/app_colors.dart`, `lib/data/demo_mode.dart`,
`lib/screens/settings/delete_account_screen.dart`, `lib/screens/billing/payment_screen.dart`,
every root-tab screen, `test/screens/main_shell_test.dart`, `scripts/check_design_consistency.sh`,
and the Flutter SDK's `packages/flutter/lib/src/widgets/app.dart` (to settle the `MaterialApp.builder`
re-parenting question in §A-4).

Ran `bash scripts/check_design_consistency.sh` — **PASS** (`✓ Design-consistency check passed`).
Did **not** run `flutter test/build/clean` per brief. All contrast ratios recomputed with a WCAG 2.x
relative-luminance calculator validated this round against reference pairs
(`#767676`/white = **4.54**, black/white = **21.00**) and against alpha-composited fills.

---

## Round-2 findings: status now

| # | Round-2 finding | R2 grade | Now | Evidence |
|---|---|---|---|---|
| B1 | Sample-data banner double-counts the top safe-area inset on every screen | ❌ Blocker | ⚠️ **Displacement fixed; occlusion introduced** | Banner left `MainShell` entirely (`main_shell.dart:58-62` comment; `body:` is now a bare `IndexedStack` at `:63`). It is now `DemoDataBannerHost` installed from `MaterialApp.builder` (`main.dart:434`) as a `Stack` overlay (`demo_data_banner.dart:39-51`). **No screen's layout is displaced — verified.** But it is hard-positioned at `padding.top + kToolbarHeight + 4` (`demo_data_banner.dart:45`) and lands *on* the screen title of 4 of 5 tabs and on the TabBar of `/vitals` and `/my-orders`. See §A |
| B2 | `orangeText`/`orangeDark`/`warning` fail AA while documented as passing | ❌ Blocker | ❌ **UNCHANGED — and now self-contradictory** | `theme.dart:70` still `// 4.6:1 on white` (measured **3.99**); `:72` still `// 4.5:1` (**3.62**); `:95` still `// 4.6:1` (**3.79**). A new `orangeStrong` was added at `:103` whose own doc says *"where `orangeText` measures only 3.99:1"* — the file now asserts both numbers 33 lines apart. Gate still enforces `orangeText` on the wrong figure: `check_design_consistency.sh:57-58` *"Text must use orangeText (4.6:1)"*. See §C |
| B3 | App icon not submission-quality; launch screen hardcoded white | ❌ Blocker | ❌ **UNCHANGED** | `git log --oneline -3 -- ios/Runner/Assets.xcassets` → last touch is `820060b` (round 2's own commit). `grep -c appearances .../AppIcon.appiconset/Contents.json` → **0**. `LaunchScreen.storyboard:22` still `red="1" green="1" blue="1" alpha="1"` |
| H4 | Nav unselected labels 1.82:1 | ❌ High | ✅ **FIXED** | `main_shell.dart:144` `unselectedItemColor: context.hc.grey`. Composited on the pill's real fill `#FFFCF8`: **10.62:1** light; dark fill `#1F1A16` with `textSecondary #B0B0B0`: **7.95:1**. Selected `orangeStrong #9A5C00` on `#FFFCF8` = **5.26:1** (`:143`) |
| H5 | GlassAppBar unpaired with `extendBodyBehindAppBar` on 38 of 46 | ❌ High | ❌ **UNCHANGED, exactly** | `comm -12` of the two file lists: **8** of **46** comply; **38** do not. Identical to round 2 |
| H6 | Four header idioms across five tabs + a sixth chrome layer | ❌ High | ❌ **UNCHANGED (different failure mode)** | Still 4 title treatments (`home_screen.dart:103` no AppBar · `my_care_screen.dart:82-107` collapsing large title · `service_catalog_screen.dart:129-169` static 28/w800 in `bottom:` · `settings_screen.dart:88-92` plain 20pt). My Care still carries 4 trailing icons. The sixth layer no longer *displaces* — it now *overlaps*. See §B |
| H7 | SOS: one entry point, scrolls away, `SOSButton` dead | ❌ High | ❌ **UNCHANGED** | `grep -rn "'/sos'" lib \| wc -l` → **2**; `grep -rn SOSButton lib` → only its own declaration/ctor at `common_widgets.dart:586,589`. `home_screen.dart:485-530` still inside the `SingleChildScrollView` at `:112` |
| H8 | Errors rendered as empty states | ❌ High | ❌ **UNCHANGED** | `notifications_screen.dart:47` and `transaction_log_screen.dart:60` still `showEmptyOnError: true` |
| H9 | Two unconfirmed destructive actions | ❌ High | ❌ **UNCHANGED** | `patient_profile_screen.dart:148` still bare `_emergencyContacts.removeAt(index)` (and `:164` for conditions), two blocks from `:230`'s correct `confirmDestructiveAction`. `care_calendar_screen.dart:1311-1313` still `RemindersProvider().delete(r.id)` straight through. `cart_screen.dart:982` unchanged |
| H10 | Booking wizard: raw `AppBar`, overloaded back, no `PopScope` | ❌ High | ❌ **UNCHANGED** | `service_booking_screen.dart:325-336` still a raw `AppBar` + hardcoded `Icons.arrow_back` + step-decrement. `grep -rn PopScope lib` → still exactly **1** hit (`booking_confirmation_screen.dart:187`) |
| H11 | Logout and account deletion leave the user inside the authenticated app | ❌ High | ❌ **UNCHANGED** | `delete_account_screen.dart:161-162` still `popUntil((route) => route.isFirst)`; `settings_screen.dart:461` still `nav.pop()`; `main.dart:417-418` auth-gated `home:` still commented out |
| H12 | The demo-mode flag can lie in both directions | ❌ High | ✅ **FIXED, and fixed properly** | `demo_mode.dart:21-67` — `Set<String>` of 11 named sources, `markServingLiveData` can only clear its own key (`:52-54`), `reset()` is `@visibleForTesting` (`:57`). `blog_provider.dart` now marks (`sourceArticles` at `:30`) |
| M13 | New strings not localized (banner + ~22 in delete-account) | ❌ Med | ✅ **FIXED for both** | `demo_banner_message` / `demo_banner_short` present in **both** `assets/i18n/en.json:323,354` and `hi.json:323,354`. `delete_account_screen.dart` is now `l.t(...)` throughout, including the typed confirmation word (`_confirmWord(l)`) |
| M14 | Banner has no `liveRegion` and no regression test | ❌ Med | ⚠️ **Semantics added; test still absent** | `demo_data_banner.dart:90-94` `Semantics(liveRegion: true, label: …)` + a one-shot assertive `SemanticsService.sendAnnouncement` at `:74-84`. But `grep -rn "DemoDataBannerHost\|demo_data_banner" test/` → **0 hits**. CLAUDE.md now states as contract *"Adding or removing it must not change any screen's layout"* — nothing tests it |
| M15 | A third destructive-confirmation idiom (bespoke `AlertDialog`) | ⚠️ Med | ⚠️ **UNCHANGED — and consolidating would now be wrong** | `delete_account_screen.dart:174-197` still hand-rolls. Consolidating into `confirmDestructiveAction` as round 2 advised would *introduce* a contrast bug — see §D-3 |
| M16 | `lib/widgets` outside the design gate | ❌ Med | ❌ **UNCHANGED, and it now costs something concrete** | `check_design_consistency.sh:17` `SCAN_DIR="lib/screens"`. This is why `common_widgets.dart:522`'s `foregroundColor: Colors.white` on a red fill is invisible to the gate (§D-3) |
| M17 | Sheet geometry drift | ⚠️ | ⚠️ **UNCHANGED** | 25 `showModalBottomSheet` sites |
| M18 | 61 SnackBar / 7 `showTopToast` | ⚠️ | ⚠️ **Marginally moved** | now **59** / **8** |
| M19 | `PopScope(canPop:false)` with no callback | ⚠️ | ⚠️ **UNCHANGED** | `booking_confirmation_screen.dart:187` |
| M20 | Empty-state fragmentation | ⚠️ | ⚠️ **UNCHANGED** | — |
| M21 | No spacing or radius constants | ⚠️ | ⚠️ **Slightly worse** | distinct `circular(n)` values in `lib/screens`+`lib/widgets`: **19** (was 17) — the new chrome added `32` and `999` as literals |
| M22 | Card press-feedback split | ⚠️ | ⚠️ **UNCHANGED** | — |
| M23 | Shadow/height/curve/haptic tail | ⚠️ | ⚠️ **UNCHANGED** | — |
| M24 | `_RootTabRedirect` paints a visible frame | ⚠️ | ⚠️ **UNCHANGED** | `main.dart` redirect untouched in `820060b..9a80fe2` |
| M25 | Stale docs contradicting shipped code | ⚠️ | ⚠️ **UNCHANGED, all of them** | `glass.dart:22` still documents trailing order `[custom…, cart, search, home]` while `:74-84` builds custom → home → search → **cart**. `theme.dart:244` *"Dark text on orange — 6.3:1"* and `:429` *"passes 6.32:1"* while `onOrange` is `#FFFFFF` at `:78`/`:32`. `app_colors.dart:68` *"both modes use the same dark ink (6.3:1 on orange)"* — flatly false |
| A | `_RootTabRedirect` restores a usable state | ✅ | ✅ **HOLDS** | untouched |
| — | Typography canon | ❌ | ❌ **UNCHANGED** | histogram from the gate this round: `11:95 12:192 13:201 14:186 16:141 … 28:12 32:2 36:6`. **No 17pt. No 34pt.** |

**Net movement:** 3 genuine ❌→✅ closures (nav contrast, demo-mode truthfulness, localization), 1 ❌→⚠️
(safe-area displacement), 1 ❌→⚠️ (banner semantics). **All three round-2 blockers are still open** — one
is re-shaped rather than closed, two were never touched. Two new failures opened (§A-2, §D-3).

---

## Round-2 repairs: adversarial review

### A. The banner overlay — the displacement is gone; the notice now sits **on** the content

#### A-1. ✅ The layout claim is true. Verified, not assumed.

`main_shell.dart:63` is now `body: IndexedStack(...)` with no `Column`, no sibling `SafeArea`, and
`main.dart:434` installs `DemoDataBannerHost` above the Navigator. `demo_data_banner.dart:39-51` returns
`Stack(children: [child, Positioned(...)])` — the `Positioned` child is a *positioned* child, so it does
not participate in the `Stack`'s sizing, and `child` is the only non-positioned child. The `Stack`
therefore sizes to `child`, and `child` (the Overlay's `_RenderTheatre`) takes `constraints.biggest`
under the loosened constraints a `StackFit.loose` stack hands it. **No screen loses a pixel of height, and
the round-2 triple-count on Billing / My Care / Delete-Account is gone.** Blocker B1's *stated* mechanism
is closed. Credit where due: this is a real structural fix, not a surface.

#### A-2. ❌ **NEW — the pill is positioned by chrome that four screen classes do not have, and it lands on the title.**

`demo_data_banner.dart:44-49`:

```dart
Positioned(
  top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
  left: 12, right: 12,
  child: const Center(child: _DemoDataPill()),
),
```

`kToolbarHeight` is a **constant**, resolved once, against a context that knows nothing about the route
below it. On an iPhone 14/15/16 (`padding.top` ≈ 47) the pill occupies **y ≈ 107 → 137** (its own height is
7 + 7 padding + a 12pt line ≈ 30). Where each screen's content actually starts:

| Screen | Content starts at | Pill occupies | Result |
|---|---|---|---|
| **Services** (`service_catalog_screen.dart:134-141`, `largeTitleHeight = 44` at `:123`) | the 28/w800 "Book Services" title is inside the app bar's `bottom:`, y ≈ **103–147** | 107–137 | the pill sits **on top of the screen's own large title**, and horizontally (centred, ≈ 245pt wide on a 393pt screen → x 74–319) it overlaps the tail of a left-aligned 28pt title |
| **My Care** (`my_care_screen.dart:140-142`, `padding.top + kToolbarHeight + 8`) | y = **111** | 107–137 | covers ~26 of the 34pt large-title line |
| **Billing** (`billing_screen.dart:169-173`, `+16`) | y = **119** | 107–137 | covers ~18 of 34pt |
| **More / Settings** (`settings_screen.dart:92`, bare `ListView`, no top padding) | y = **103** | 107–137 | clips the top of the 72pt profile avatar |
| **Home** (`home_screen.dart:103` no `AppBar`; header `Padding(16,6,16,4)` at `:381`) | header row y ≈ **53–125** | 107–137 | covers the **patient-switcher chip** (`:401-420`) — on a multi-patient account this hides *which patient is selected* |
| **`/vitals`** (`vitals_screen.dart:134-145`, `GlassAppBar(bottom: TabBar)`) | TabBar y ≈ **103–149** | 107–137 | **covers the TabBar labels** |
| **`/my-orders`** (`my_orders_screen.dart:157-169`, same shape) | TabBar y ≈ 103–149 | 107–137 | covers the TabBar labels |

`/vitals` is the screen the notice's own dartdoc names as the one where mistaking sample data
*"actually does harm"* (`demo_data_banner.dart:15-17`). The notice now obscures that screen's primary
control. That is not a Settings-only trade — it is systematic, and it targets exactly the element Apple's
large-title pattern makes the anchor of a screen.

**And it is pointer-transparent.** The pill's render chain is `ClipRRect → BackdropFilter → DecoratedBox →
Padding → Row` (`glass.dart:154-168`, `demo_data_banner.dart:96-131`). None of those absorb hit tests —
`RenderProxyBox.hitTestSelf` is `false` and `_RenderCustomClip` only *rejects* hits outside the clip. So
taps pass straight through. On `/vitals` the user can tap a tab they cannot see. Occlusion without
interception is the worst combination: it hides state and still accepts input against it.

#### A-3. Which is correct per Apple — displacement or occlusion? **Displacement. This repair inverted the rule.**

The platform's own split is clean:

- **Transient status → floats and occludes, then leaves.** The volume/ringer HUD, the AirPods
  connection card, "Copied" toasts. They are allowed to cover content precisely *because* they go away.
- **Persistent status → participates in chrome and displaces.** `UINavigationItem.prompt` is the exact
  iOS precedent: a single line of qualifying text above the nav bar, laid out **by the system**, which
  grows the bar and pushes content down for as long as the condition holds. Mail's account-status line,
  Safari's "Not Secure" field state, Music's offline strip — all in-chrome, all displacing.
- The one genuinely persistent iOS overlay — the status-bar pill for an active call, screen recording, or
  location use — is (a) *inside* the status bar so it occludes nothing, (b) system-laid-out, and (c)
  **tappable**, taking you to the thing it reports.

The Housepital condition is persistent (`api.housepital.in` does not resolve, so it is up for the whole
session), non-dismissible by design, and clinical. Every attribute says "chrome", and the repair chose the
transient mechanism.

**The sharper point: round 2 never objected to displacement.** It objected to displacement counted
*twice* — `MediaQuery.padding.top` applied by the banner's `SafeArea` and again by every `AppBar`. That is
an arithmetic bug with a one-line fix (`MediaQuery.removePadding(removeTop: true)` around the sibling).
The repair discarded the pattern instead of fixing the arithmetic, and imported a new class of defect to do
it. That is the round-2 report's own definition of a surface: the stated symptom disappears, the underlying
question ("where does a persistent status notice live?") is answered worse.

#### A-4. ⚠️ The flip re-parents the entire app.

`demo_data_banner.dart:38-39`: `if (!serving) return child;` … `return Stack(children: [child, …]);`
The returned widget's `runtimeType` changes (`FocusScope` ⇄ `Stack`), so `Widget.canUpdate` is false and
the whole subtree is deactivated and re-inflated when the flag flips. Route state survives only because
`WidgetsApp` gives its `Navigator` a `GlobalKey` — verified in the SDK at
`/opt/homebrew/share/flutter/packages/flutter/lib/src/widgets/app.dart:1513`
(`_navigator = widget.navigatorKey ?? GlobalObjectKey<NavigatorState>(this)`) and `:1690-1696`
(`FocusScope(… child: Navigator(key: _navigator …))`). So nothing is lost — but every `State` in the app
receives `deactivate`/`activate`, and the **unkeyed `FocusScope` above the Navigator is recreated, dropping
keyboard focus**. If a patient is mid-typing when the backend drops, the keyboard dismisses.
— **Fix (free):** keep the shape constant — `Stack(children: [child, if (serving) Positioned(…)])`.

#### A-5. What it should be instead — concretely

1. **Put it in `GlassAppBar.bottom:`.** The slot already exists and already sizes correctly
   (`glass.dart:52-53` `preferredSize` sums `bottom.preferredSize.height`), so **no screen does inset
   maths** — which is the exact property the repair says it was chasing. Add an app-level wrapper so the
   strip is declared once rather than 46 times. Home (`home_screen.dart:103`, no `AppBar`) needs either a
   `GlassAppBar` or an inline first row — that gap is a symptom of H6, not a reason to reject the pattern.
2. **Make it interactive.** §1.2 P7 requires an error to explain *and* offer recovery. The pill does
   neither — it is inert, and pointer-transparent besides. Tap → a sheet explaining what sample data is,
   which sources are stale (`DemoMode.activeSources` already exposes exactly this, `demo_mode.dart:43`),
   and a **Retry**.
3. If an overlay must be kept as an interim, at minimum: derive `top` from the actual route's app-bar
   height rather than `kToolbarHeight`, and wrap it in `IgnorePointer`+`SafeArea` so its behaviour is at
   least declared rather than accidental.

**Grade: ⚠️.** Half a blocker closed. The layout regression is genuinely gone; a content-occlusion
regression replaced it, on the wrong side of Apple's transient/persistent line.

---

### B. The nav pill — judged against the platform idiom and against round 5

#### B-1. ✅ Round 5's objection is answered structurally, and the answer is **tested**.

Round 5 said "the detached pill covered content." `main_shell.dart:77-84` puts the `Padding` **inside** the
`bottomNavigationBar` slot, so Scaffold reports the slot's full height (pill + margins) as the body's bottom
`MediaQuery` inset, and `extendBody: true` (`:57`) lets content glide under it.
`main_shell.dart:125-129`'s inner `MediaQuery.removePadding(removeBottom: true)` correctly prevents
`BottomNavigationBar` adding the home-indicator inset a second time.

This is verified by real assertions, not by a comment:
`test/screens/main_shell_test.dart:220-235` asserts
`MediaQuery.of(homeContext).padding.bottom >= barRect.height`, and `:238-247` asserts `>= 56.0`.
`:189-218` asserts the pill floats clear of all three edges and is a `GlassSurface` with a transparent bar;
`:280-289` asserts the `AssistantFab` does not collide; `:291-296` asserts no overflow at 320×568.
**This is the best-tested piece of chrome in the app**, and it is the model the demo pill should have
followed. Full credit.

#### B-2. ✅ It is now the platform-native *shape*.

A floating, side-inset, capsule tab bar is the iOS 26 Liquid Glass tab-bar form. Reversing round 5's fixed
edge-to-edge orange bar moves *toward* the platform, not away. Radius 32 against a 64pt content height
(`BottomNavigationBar` 56 + `:131`'s 4+4 padding) is exactly half — a true stadium, not an
almost-stadium. Correct.

Contrast, recomputed on the **composited** fill rather than the token (the commit message's own method, and
it checks out exactly):

| | composited fill | selected | unselected |
|---|---|---|---|
| Light (frost 0.78 over white, then `orangeLight` @0.22) | `#FFFCF8` | `#9A5C00` = **5.26:1** | `#3D3D3D` = **10.62:1** |
| Dark (`#1C1C1E` @0.78 over `#000000`, then `orangeMuted #3D2A12` @0.22) | `#1F1A16` | `#F39314` = **7.39:1** | `#B0B0B0` = **7.95:1** |
| Worst case — pill over a scrolling brand-orange fill | `#FDEAD0` | `#9A5C00` = **4.57:1** | — |

All pass AA at 12px, including the worst case. The commit's stated figures (`#FFFCF8`, 5.26; `#1F1A16`,
7.39) reproduce to the digit. **This is the one place in the codebase where a contrast claim is honest and
conservative** — which makes §C's untouched wrong numbers harder to excuse, not easier.

#### B-3. ⚠️ It reads as intentional — but as a *custom component*, not as iOS chrome. Three tells.

- **The frost is not glass.** `sigma: 36, opacity: 0.78` (`main_shell.dart:114-115`) is a 78%-opaque fill.
  At that opacity the backdrop blur is doing almost no visible work: content gliding under the pill is
  barely perceptible, which is the entire point of the material. Apple's Liquid Glass gets legibility from
  *adaptive tinting and a specular edge*, not from opacity — it stays markedly more transparent than this.
  The result reads as a milky card with rounded ends. The comment at `:112-115` calls it "frosted material
  rather than a transparent pane", which is an accurate description of what was built and an accurate
  description of *not being glass*.
- **The warm drop shadow is the strongest tell.** `context.hc.orange @0.18, blur 24, offset (0,8)`
  (`:102-106`). Apple's floating chrome uses a neutral, very low-alpha ambient shadow or none at all. A
  **coloured** shadow — an orange halo under a cream capsule on a white page — is a Material/Dribbble
  idiom, not a platform one. This single property is what makes it read as "a widget parked on the page"
  rather than as system chrome. With the border gone, the comment at `:98-101` correctly identifies it as
  the *only* thing separating the pill from a white page — which is precisely why it is doing too much.
- **"NO border" is not what the code does.** `GlassSurface` still draws
  `Border.all(color: edge, width: 0.5)` whenever `borderRadius != null` (`glass.dart:162-163`) — white
  @0.6 in light, white @0.08 in dark. `9a80fe2` removed the *orange* border (`git show 9a80fe2`), not the
  border. So the pill carries a white hairline on a near-white page: exactly the "white on white is a bit
  off" condition the owner complained about, still present, now undocumented. Apple's Liquid Glass *does*
  have an edge — the correct answer is an **adaptive** specular edge (light against dark content, dark
  against light), not none and not orange.
- Minor: the pill does not respond to scroll. iOS 26's floating tab bar collapses to icons on scroll-down.
  Not a defect against this checklist, but the idiom is incomplete.
- Minor: `math.max(padding.bottom, 8.0)` (`:83`) floats the pill **34pt** above the screen edge on
  home-indicator devices. With the pill's own 64pt that is ~98pt of bottom chrome. Apple's floating tab bar
  sits nearer the safe-area line. A `math.max(padding.bottom - 8, 8)` would read tighter.

**Verdict: intentional, and defensibly on-idiom in shape and in contrast — but the material and the
coloured shadow make it read as a custom component rather than system chrome.** Two changes would close
the gap almost entirely: drop `opacity` to ~0.6 and replace the orange shadow with a neutral
`black @0.06–0.08` ambient plus a proper adaptive edge.

---

### C. `theme.dart` — the wrong numbers were not fixed; a second token was parked beside them ❌

Confirmed by direct read, all still present at `9a80fe2`:

| Line | Comment says | **Measured** | |
|---|---|---|---|
| `theme.dart:70` `orangeText = #B86E00` | `// 4.6:1 on white — use for text` | **3.99:1** | fails AA |
| `theme.dart:72` `orangeDark = #CC6E00` | `// 4.5:1 on white` | **3.62:1** | fails AA |
| `theme.dart:95` `warning = #E65100` | `// 4.6:1` | **3.79:1** | fails AA |
| `theme.dart:267` | `// darkened orangeText (4.6:1, AA) instead` | — | wrong |
| `theme.dart:324` | `// orangeText keeps AA` | — | wrong |
| `check_design_consistency.sh:57-58` | `Text must use orangeText (4.6:1)` | — | **the gate enforces a rule on a false premise** |

`orangeStrong` (`theme.dart:103`) is correct — `#9A5C00` measures **5.38:1** on white exactly as documented,
and its own doc-comment states *"where `orangeText` measures only 3.99:1."* So `theme.dart` now contains,
33 lines apart, the claim that `orangeText` is 4.6:1 and the claim that it is 3.99:1. A designer reading
this file cannot tell which token to use or which number to believe.

**And the new token is used at exactly one site.** `grep -rn orangeStrong lib` → `main_shell.dart:143` only.
`orangeText` remains the app-wide default `TextButton` foreground (`theme.dart:270`) and the chip label
(`:325`). So the repair fixed the *nav pill's* label and left the default text-button colour app-wide at
3.99:1 while the gate keeps mandating it. This is a spot-fix presented as a token fix.

— **Fix (unchanged from rounds 1 and 2):** promote `orangeStrong` to be `orangeText`, or retire `orangeText`
to a large-text-only role and re-point `theme.dart:270`/`:325`; re-derive `orangeDark`/`warning`; correct
the five comments and the gate's stated rationale.

**Grade: ❌ blocker unchanged, with a new internal contradiction.**

---

### D. New surfaces — the delete-account screen and the payment pending state

#### D-1. Delete-account chrome — ✅ the best-behaved chrome in the app

- ✅ `extendBodyBehindAppBar: true` + `padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 32)`
  (`delete_account_screen.dart:206, 213`), with `topPad = padding.top + kToolbarHeight` (`:200`). Resolved
  from the widget's own context rather than below the Scaffold, but the value is identical to the app-bar
  height here, so it is correct. One of only **8 of 46**.
- ✅ Opts out of the cart (`:210`) — correct application of the funnel rule to a destructive screen.
- ✅ **Fully localized now** (round-2 M13 closed) — including the typed confirmation word via
  `_confirmWord(l)` (`:281-283`), which is the detail most implementations get wrong.
- ✅ `labelText` rather than `hintText` on the confirmation field (`:279-283`) with a comment explaining
  that a hint alone leaves the field with no accessible name. That is a real VoiceOver fix, correctly
  reasoned.
- ✅ Confirmation depth (checkbox `:259` + typed word `:275` + `AlertDialog` `:174`) still exceeds the
  checklist and matches Apple's own Apple-ID deletion flow.
- ✅ **Paired `onError` foreground** (`:187`, `:294`, `:302`) — white on light `#D32F2F` = 4.98:1, `#212121`
  on dark `#EF5350` = **4.62:1**. Correct in both appearances.

**Still open, unchanged from round 2:**
- ❌ **`:161-162` `popUntil((route) => route.isFirst)`** → the first route is `/home` → `MainShell`
  (`main.dart:442`). "Everything on this phone has been erased" → **OK** → the Home tab of a fully
  navigable app. `main.dart:417-418` still has the auth-gated `home:` commented out. Highest-stakes moment
  in the product, §1.2 P2 broken. `settings_screen.dart:461`'s `nav.pop()` is the same shape.
- ⚠️ **No haptic on the destructive commit** — `grep -c HapticFeedback delete_account_screen.dart` → **0**.
  §3.3 reserves heavy impact for exactly this.
- ⚠️ No `PopScope`; button `height: 48` (`:291`) vs the spec's 50; the `canSubmit ? error : grey` ternary at
  `:293` is still dead (`styleFrom.backgroundColor` maps to the enabled state only and
  `disabledBackgroundColor` is unset); the local `border: const OutlineInputBorder()` at `:277` still
  contradicts the app's `InputDecorationTheme`.
- ⚠️ Plain 20pt bar title, no large title — the app's minority idiom (H6).

#### D-2. Payment pending-verification — ✅ the right pattern, ❌ colour-coded as its opposite, ❌ one translation from a double debit

The **instinct is correct and worth protecting**: a charged-but-unverified payment must not read as
"Payment Failed" with a Retry button. `payment_screen.dart:611-635` deliberately offers no retry —
*"paying again would debit twice for the same bill"* — and routes to a human via `/help-faq`. That is
textbook §1.2 P7 (explain *and* offer recovery) and better than most production apps.

Three defects, one of them serious:

- ❌ **The state is colour-coded as an error.** `payment_screen.dart:461-466` — the 120pt icon well is
  `isSuccess ? successLight : errorLight`. The **pending** branch therefore renders a warning-coloured
  `Icons.schedule` (`:473-480`) on a **red-tinted** circle. At squint distance and in grayscale
  (§5.1) the screen reads as a failure, which is the precise misreading the state exists to prevent.
  Colour is not merely absent as a differentiator here — it is an *actively wrong* one (§1.2 P6).
  — **Fix:** `_pendingVerification ? context.hc.warningLight : context.hc.errorLight`.
- ✅ Honest contrast comment at `:497-499`: the 24pt/w700 title uses `context.hc.warning` (3.79:1) and the
  comment correctly notes that 24pt bold is *large text*, so the 3:1 floor applies. Correct per WCAG and
  conservatively stated. Noted because it is the exception in this codebase.
- ❌ **The whole branch is gated on an English substring.** `payment_screen.dart:286`
  `final unverified = message.contains('under verification');` against
  `payment_service.dart:180,186` `"Payment under verification — we'll confirm in 24 hours"`. That string is
  **user-facing** (it is rendered as `_failureMessage`), so the CLAUDE.md i18n contract requires it become a
  key in `en.json`/`hi.json`. The moment it does — or the moment the wording is edited — the match silently
  fails and a charged patient sees red **"Payment Failed" + "Retry Payment"**. A double-debit path one
  translation away, with no test guarding it. — **Fix:** return a typed result
  (`PaymentOutcome.pendingVerification`) from `payment_service`, never a string match.
- ❌ **New hardcoded English on the payment screen** — `'Go Back'` (`:631`, `:649`), `'Retry Payment'`
  (`:640`), `'Got it'` (`:972`), and the SnackBar at `:130`. Same contract breach the banner and
  delete-account just closed, on the highest-consequence screen in the app.
- ⚠️ `HapticFeedback.heavyImpact()` fires for pending too (`:295`) — §3.3 reserves heavy for errors.
  Pending is not an error; the haptic tells the patient it is.
- ⚠️ Button heights 52 (`:616`) and 48 (`:628`) on the same screen, neither the spec's 50.

#### D-3. ❌ **NEW High — the round-2 `onError` repair reached 3 of 14 destructive sites, and missed the shared helper**

Round 2's repair added a paired `onError` token because white on the dark-mode error red measures
**3.49:1**. Verified: `#FFFFFF` on `HousepitalColorsDark.error #EF5350` (`theme.dart:46`) = **3.49:1**;
the paired `#212121` = **4.62:1**.

`grep -rn "hc.onError" lib` → **3 hits, all inside `delete_account_screen.dart`** (`:187`, `:294`, `:302`).

Meanwhile `grep -rn "backgroundColor: context.hc.error" lib` → **14 sites**, and the most important of them
is the shared destructive dialog itself:

```dart
// lib/widgets/common_widgets.dart:520-523
style: ElevatedButton.styleFrom(
  backgroundColor: context.hc.error,
  foregroundColor: Colors.white,          // ← 3.49:1 in dark mode
),
```

`confirmDestructiveAction` has **14 call sites**. Every "Delete?" dialog in the app except the bespoke one
in delete-account renders its confirm button at 3.49:1 in dark mode. `settings_screen.dart:463-465`
(Logout) is worse still — `backgroundColor: context.hc.error` with **no `foregroundColor` at all**, so it
inherits `elevatedButtonTheme`'s `onOrange` = white (`theme.dart:428-430`): same 3.49:1.

This inverts round 2's own M15 recommendation: consolidating `delete_account_screen`'s bespoke dialog into
`confirmDestructiveAction` would have *replaced a correct 4.62:1 with a wrong 3.49:1*. **Fix the helper
first, then consolidate.** And note why the gate cannot see this: `Colors.white` is a raw colour in
`lib/widgets`, and `check_design_consistency.sh:17` scans `lib/screens` only (M16).

This is the round-3 instance of the round-2 pattern: a token is introduced, a comment asserts the rule, one
screen adopts it, and the shared component that governs the other 13 sites is left alone.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1.1 Calm Command pillars (4) | 1 | 3 | 0 | 0 |
| 1.2 Ten First Principles (10) | 2 | 4 | 4 | 0 |
| 2.1 Typography system (5) | 0 | 2 | 3 | 0 |
| 2.2 Color system (8) | 5 | 2 | 1 | 0 |
| 2.3 Spacing & layout (9) | 4 | 5 | 0 | 0 |
| 3.1 Touch targets (3) | 2 | 1 | 0 | 0 |
| 3.2 Animation (6) | 4 | 2 | 0 | 0 |
| 3.3 Feedback patterns (3) | 1 | 2 | 0 | 0 |
| 4.1 Buttons (4) | 1 | 3 | 0 | 0 |
| 4.2 Cards (4) | 2 | 2 | 0 | 0 |
| 4.3 Forms (4) | 1 | 3 | 0 | 0 |
| 5.1 Quick tests (3) | 0 | 2 | 1 | 0 |
| 5.2 Accessibility checklist (6+1) | 2 | 3 | 1 | 1 |
| 5.3 Design review sign-off (9) | 2 | 5 | 2 | 0 |
| 6.1–6.3 Figma / PPT / Notion (14) | 0 | 0 | 0 | 14 |
| 6.4 Code implementation (5) | 2 | 3 | 0 | 0 |
| **TOTAL (83 scored + 15 N/A)** | **29** | **42** | **12** | **15** |

*Reconciliation with round 2 (29 ✅ / 42 ⚠️ / 11 ❌ over 82): my §5.2 counts six scored rows against round
2's five (round 2's §5.3 detail table also totals 2/6/1 while its scorecard row reads 3/5/1 — an internal
inconsistency in that report). Movements this round: §1.2 P10 ⚠️→✅ and §2.2 nav labels ⚠️→✅ and §2.3 safe
areas ❌→⚠️ (up), against §5.1 3-second ⚠️→❌, §5.3 item 1 ⚠️→❌, and §6.4 design-tokens ✅→⚠️ (down).*

Section-level deltas worth naming:
- **§2.3 Spacing & layout — the only section with zero ❌ now.** The safe-area double-count is genuinely
  gone; what remains (19 distinct radii, ~170 off-grid literals, XLarge under-used) is all ⚠️.
- **§5.1 Quick tests — 3-second test moves ⚠️→❌.** On four of five tabs the first thing a user's eye lands
  on is a warning pill sitting on top of the screen's own title. Cover the title and you cannot tell what
  the screen does — because the title is covered by default.
- **§1.2 P6 Accessible by default — still ❌**, driven entirely by §C's untouched tokens plus the new
  3.49:1 destructive-button gap (§D-3). Nav labels and the demo pill are now both clean.

---

# Findings

## Blockers (must fix before release)

1. **`orangeText` / `orangeDark` / `warning` fail WCAG AA while documented as passing, and the gate enforces
   the false figure** — `theme.dart:70, 72, 95` (measured **3.99 / 3.62 / 3.79** vs claimed 4.6 / 4.5 / 4.6),
   restated wrongly at `theme.dart:267, 324` and at `check_design_consistency.sh:57-58`. Carried unfixed
   through **three rounds**. The new `orangeStrong` (`:103`) is correct but used at one site
   (`main_shell.dart:143`), so `theme.dart` now contradicts itself and the app-wide default `TextButton`
   foreground (`:270`) is still 3.99:1. **Fix:** re-point `orangeText` to `#9A5C00` (or retire it to a
   large-text role), re-derive the other two, correct five comments and the gate's rationale.

2. **The app icon is not submission-quality and the launch screen is hardcoded white** — untouched since
   `820060b`. `Contents.json` has **0** `appearances` entries, so iOS 18+ dark/tinted home screens
   auto-derive a washed grey tile from a white-background icon; the 1024 master is a soft upscale with ~25%
   self-imposed margin. `LaunchScreen.storyboard:22` is literal white, so every cold start on a dark-mode
   device flashes white before the true-black app (`theme.dart:16`). **Fix:** re-export full-bleed from
   vector at 1024², on brand orange, with dark + tinted variants; make the launch background a light/dark
   colour set.

3. **The sample-data notice occludes the screen title on four of five tabs and the TabBar on `/vitals`** —
   `demo_data_banner.dart:44-49` hard-positions at `padding.top + kToolbarHeight + 4`, a constant that
   matches no screen's actual content origin (§A-2 table). It is pointer-transparent, so users can tap
   controls they cannot see. This is the app's **default** state. Persistent status belongs in chrome, not
   in a transient-style overlay (§A-3). **Fix:** move it into `GlassAppBar.bottom:` — the slot already
   sizes itself via `preferredSize` (`glass.dart:52-53`), so no screen needs inset maths, which is exactly
   the property the overlay was built to obtain.

## High

4. **The `onError` pairing reached 3 of 14 destructive sites and missed the shared helper** —
   `common_widgets.dart:522` hardcodes `foregroundColor: Colors.white` on `context.hc.error`
   (**3.49:1** in dark mode) across **14** `confirmDestructiveAction` call sites, and
   `settings_screen.dart:463-465` sets no foreground at all. Only `delete_account_screen.dart` uses the
   token. Invisible to the gate because `SCAN_DIR="lib/screens"` (`check_design_consistency.sh:17`).
   **NEW this round.**

5. **The payment pending-verification state is one translation away from a double debit** —
   `payment_screen.dart:286` branches on `message.contains('under verification')` against a hardcoded
   English string at `payment_service.dart:180,186`. Localize or reword it and a charged patient gets
   "Payment Failed" + "Retry Payment". No test guards it. **NEW this round.**

6. **The pending state is colour-coded as a failure** — `payment_screen.dart:461-466` puts a warning icon on
   an `errorLight` (red) well. Fails the squint and grayscale tests on a money screen. **NEW this round.**

7. **GlassAppBar chrome contract broken on 38 of 46 screens** — no paired `extendBodyBehindAppBar`; two
   visibly different bar materials app-wide. Ratio **identical** for three rounds.

8. **Header idiom inconsistency, unchanged** — four title treatments across five tabs
   (`home_screen.dart:103` · `my_care_screen.dart:82-107` · `service_catalog_screen.dart:129-169` ·
   `settings_screen.dart:88-92`), My Care still at four trailing icons, plus a sixth chrome layer that now
   overlaps rather than displaces.

9. **SOS: one entry point, and it scrolls away** — `home_screen.dart:485-530` inside the scroll view at
   `:112`; `SOSButton` instantiated **zero** times; no SOS on 4 of 5 tabs. Unchanged, and it now competes
   for the top band with the demo pill.

10. **Errors rendered as empty states** — `transaction_log_screen.dart:60`, `notifications_screen.dart:47`.

11. **Two unconfirmed destructive actions** — emergency contact (`patient_profile_screen.dart:148`, and
    conditions at `:164`) and care reminder (`care_calendar_screen.dart:1311-1313`), each a few blocks from
    a sibling that confirms correctly (`patient_profile_screen.dart:230`).

12. **Booking wizard back is unpredictable** — `service_booking_screen.dart:325-336`: raw `AppBar`,
    hardcoded `Icons.arrow_back`, overloaded back, no `PopScope` (still 1 `PopScope` in the whole tree).

13. **Logout and account deletion leave the user inside the authenticated app** —
    `delete_account_screen.dart:161-162`, `settings_screen.dart:461`, `main.dart:417-418`.

## Medium / Low

14. **No test at all for `DemoDataBannerHost`** — `grep -rn "DemoDataBannerHost\|demo_data_banner" test/` →
    0 hits, while CLAUDE.md now states its non-displacement as a design-system **contract**. Every screen
    that the pill overlaps would be caught by one `tester.getRect` assertion. Contrast this with
    `main_shell_test.dart:220-247`, which does exactly that for the nav pill.
15. **The demo flag flip re-parents the whole app** — `demo_data_banner.dart:38-39` changes the returned
    widget type, deactivating and re-adopting the Navigator subtree. Route state survives only via
    `WidgetsApp`'s `GlobalObjectKey`; the unkeyed `FocusScope` above it is recreated, dropping keyboard
    focus mid-typing. Free fix: `Stack(children: [child, if (serving) Positioned(…)])`.
16. **The demo pill is last in VoiceOver traversal.** `Semantics(liveRegion: true)` +  a one-shot assertive
    announcement (`demo_data_banner.dart:74-84`, `:90-94`) is a real improvement over round 2's silence, but
    the pill mounts **once**, above the Navigator — so pushing `/vitals` while it is already up produces no
    announcement, and a swiping user reads all the sample vitals before reaching the warning node.
17. **New hardcoded English on the payment screen** — `payment_screen.dart:130, 631, 640, 649, 972`.
18. **The "no border" claim is false** — `main_shell.dart:87-93` says the border was removed; `GlassSurface`
    still draws `Border.all(white@0.6, 0.5)` whenever `borderRadius != null` (`glass.dart:162-163`). The
    *orange* border went. A white hairline on a white page is the "white on white" problem the change was
    meant to solve.
19. **The pill's coloured drop shadow is the one property that makes it read as non-native** —
    `main_shell.dart:102-106`, `orange @0.18`. Apple's floating chrome uses neutral ambient shadow.
    Paired with `opacity: 0.78` (`:115`), which is high enough that the backdrop blur is nearly invisible.
20. **`lib/widgets` is still outside the design gate** — `check_design_consistency.sh:17`. Now demonstrably
    load-bearing (Finding 4).
21. **Distinct corner radii grew 17 → 19** — the new chrome added `32` and `999` as literals. Still no
    spacing or radius constants anywhere (`lib/config/constants.dart` is API/business only).
22. **No haptic on the account-deletion commit** (`delete_account_screen.dart`, 0 `HapticFeedback`), while
    `payment_screen.dart:295` fires `heavyImpact` for a *pending* state that is not an error.
23. **Stale docs contradicting shipped code — all unchanged:** `glass.dart:22` documents the trailing order
    as `[custom…, cart, search, home]` while `:74-84` builds custom → home → search → cart;
    `theme.dart:244, 429` and `app_colors.dart:68` still describe "dark ink on orange" while `onOrange` is
    `#FFFFFF` (`theme.dart:32, 78`); `theme.dart:28` still cites surface `#1A1A1A` while `:16` sets
    `#000000`.
24. **Typography canon unchanged** — histogram `11:95 12:192 13:201 14:186 16:141 … 28:12 32:2 36:6`.
    No 17pt Headline/Body, no 34pt Large Title. The new chrome added no off-canon size (12pt pill label,
    12pt nav labels) — the ratchet recommended in rounds 1 and 2 would still cost nothing.
25. **`_RootTabRedirect` still paints a visible frame** despite its comment (`main.dart`), and
    `booking_confirmation_screen.dart:187` still has `PopScope(canPop: false)` with no callback.

## BLOCKED-OWNER

| Item | What I would need |
|---|---|
| Exact overlap of the demo pill against each screen's first content row | A simulator screenshot of Services / My Care / `/vitals` with `DemoMode.isServingDemoData == true`, or a widget test asserting `tester.getRect(find.byType(_DemoDataPill)).overlaps(tester.getRect(find.text('Book Services')))`. The geometry above is derived from declared constants (`padding.top` 47 on iPhone 14–16, `kToolbarHeight` 56, `largeTitleHeight` 44, `TabBar` ~46) and is certain in mechanism; the pixel figures depend on device inset and rendered text metrics |
| Whether the frosted pill reads as glass or as a card on a real device | A device capture while scrolling colourful content under it. `sigma: 36 / opacity: 0.78` is measurable from source; how much of the backdrop survives 78% fill is a rendering judgement |
| Whether the icon passes App Review 2.3.8 | A TestFlight upload. Source proves 0 `appearances` and a soft upscale; only Apple decides |
| VoiceOver traversal order with the overlay present | A device VoiceOver pass. Source proves the pill is the last child of the top-level `Stack`; it does not prove where the reader lands |
| "3-Second" / "Squint" / "Grayscale" tests with real users | The checklist defines these as *human* tests (§5.1); my grades are structural proxies |
| Dynamic Type at 1.4× with the overlay up | `overflow_smoke_test.dart` covers 320/375/414 at scale 1. The pill's height grows with text scale while its `top` is a constant — at 1.4× it extends further into content, untested |

---

## Executive summary

1. **Round-3 counts: 29 ✅ / 42 ⚠️ / 12 ❌ (83 scored) + 15 N/A** — flat on ✅, one more ❌ than round 2,
   because three real closures were offset by two new failures and one degradation.
2. **Genuinely fixed, no caveats:** the demo-mode flag can no longer lie (`demo_mode.dart` is a per-source
   `Set`, 11 sources, self-clearing only); nav unselected labels went 1.82:1 → 10.62:1 light / 7.95:1 dark;
   the banner and the whole delete-account screen are now localized in EN and HI.
3. **Genuinely fixed with a caveat:** the banner's phantom top inset is gone — verified structurally, not
   assumed — but the pattern that replaced it is on the wrong side of Apple's transient/persistent line.
4. **REGRESSED:** the 3-second test (§5.1) and design-sign-off item 1 both drop ⚠️→❌, because the notice now
   sits on top of the screen title on Services, My Care, Billing and Home, and on the TabBar of `/vitals`
   and `/my-orders` — pointer-transparent, so users can tap what they cannot see.
5. **Is a round-2 repair itself a surface? Two are.** (a) `theme.dart`: a correct `orangeStrong` was parked
   beside the wrong `orangeText` comment instead of replacing it — one call site adopted it, the app-wide
   default is still 3.99:1, and the gate still enforces the false 4.6:1. (b) The `onError` pairing reached
   3 sites, all in one screen, while the shared `confirmDestructiveAction` (14 call sites) still hardcodes
   `Colors.white` at 3.49:1 — invisible to the gate because it lives in the unscanned `lib/widgets`.
6. **Is the banner repair a surface?** Half. It closed the stated symptom honestly and left the underlying
   question worse answered. Round 2 objected to the inset being counted *twice*, not to displacement;
   the fix discarded the pattern rather than fixing the arithmetic.
7. **The nav pill:** the strongest work in this batch. Round 5's "it covers content" is answered
   structurally (Scaffold slot + `extendBody`) **and tested** (`main_shell_test.dart:220-247`); the shape,
   the true-stadium radius, and the composited contrast (5.26:1 / 7.39:1, reproduced to the digit) are all
   correct. It reads as intentional. It does **not** read as system chrome — the orange drop shadow and the
   0.78 fill make it a card with rounded ends rather than glass, and "no border" is inaccurate
   (`GlassSurface` still draws a white hairline).
8. **Top 5 remaining:** (i) `theme.dart`'s three wrong contrast comments + the gate built on them —
   three rounds unfixed; (ii) the icon and launch assets — untouched since round 2; (iii) the demo pill
   occluding titles and the `/vitals` TabBar; (iv) `confirmDestructiveAction` at 3.49:1 in dark across 14
   sites; (v) the payment pending state gated on an English substring, one translation from a double debit.
9. **Discipline note:** the nav pill has six real assertions; the demo overlay has zero, while CLAUDE.md
   promotes its non-displacement to a design-system contract. The same author wrote both in the same batch —
   the difference is testing, and it is exactly where the defects landed.
10. **Verdict: FAIL.** Three blockers stand — two of them (tokens, icon/launch) have now survived three
    consecutive rounds untouched, and the third is a newly-shaped version of a round-2 blocker. The trend is
    genuinely positive on correctness of *reasoning* (the pill's contrast maths, `DemoMode`'s set, the
    delete-account VoiceOver fix are all first-rate) and flat on *coverage* — fixes keep landing on one
    screen instead of on the token, the helper, or the gate.

---

*Read-only audit. No files under `lib/`, `test/`, `scripts/`, or `ios/` were modified. The only file
written is this report.*
