# Accessibility (App-Agnostic) — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-11 · **Auditor:** Accessibility · **Scope:** source review (see Limitations)
**Branch:** `fix/five-tab-nav` · **Round 3:** `9a80fe2` · **Round 2:** `820060b` · **Round 1:** `803124d`

**Method.** Read-only. `rg`/`grep`, a brace-matched constructor parser in Python
(`IconButton` counting), WCAG 2.1 relative-luminance computation over sRGB source-over
compositing in Python, and — for the hit-testing question — direct reading of the Flutter
framework render layer at the exact SDK this app builds against
(`/opt/homebrew/share/flutter`, **Flutter 3.41.2**, framework `90673a4eef`, engine
`d96704abcce17ff`). No `flutter test` / `build` / `clean` / `analyze` was run, per the
brief. Central results cited as given: `flutter analyze` clean, design gate passes, 1,819
tests across 101 files. Only this file was written.

**Note on checklist coverage.** Round 3 graded 28 controls (§§1–6). The v2.0 checklist
revision of 8 August 2026 added §§7–10 (24 further controls). Round 3 (dated 2026-08-05)
predates that revision, so **§§7–10 are graded here for the first time** and have no
prior-round baseline.

---

## Applicability

MASTER-3.xx trigger: *"Every user-facing app or service."* This is a patient-facing
clinical app whose users are disproportionately elderly, post-operative, or caregivers
operating under stress. It renders vitals, medication schedules, doctor's advice, invoices
and a payment funnel. It ships **six platform targets** (`ios`, `android`, `web`, `macos`,
`windows`, `linux`) and CI builds a **web release** (`.github/workflows/ci.yml:101-102`),
which makes keyboard and pointer controls (§7.03/§7.04) live requirements rather than
hypothetical ones. The control family applies in full. No control is N/A for want of
applicability except the two media controls, for which a written rationale is recorded.

---

## Round-4 focus items, answered first

### F1. The overlay pill's hit-testing — the measurement is right and round 3's mechanism was wrong

Round 3 wrote that the pill is *"transparent to touch: `ClipRRect > BackdropFilter >
DecoratedBox > Padding > Row` — every one is a `RenderProxyBox` whose `hitTestSelf` is
`false`, and `Stack` continues to the sibling below."* The widget probe measured the
opposite: overlapping boxes, tap at the intersection, **zero taps reached the control
beneath**. The measurement is correct. Here is why, resolved against the framework source.

**Every widget round 3 named genuinely is non-absorbing.** That part of the reasoning
checks out and I reproduce it:

| Node | Render object | `hitTestSelf` | Source |
|---|---|---|---|
| `ClipRRect` | `RenderClipRRect extends _RenderCustomClip extends RenderProxyBox` | not overridden → `false` | `rendering/proxy_box.dart:1684`, `:1484`; its `hitTest` at `:1628` only *rejects* positions outside the clip |
| `BackdropFilter` | `RenderBackdropFilter extends RenderProxyBox` | not overridden → `false` | `rendering/proxy_box.dart:1201` |
| `DecoratedBox` | `RenderDecoratedBox extends RenderProxyBox` | not overridden → `false` | only two `hitTestSelf` overrides exist in the whole file, at `:195` and `:2468`; neither is this class |
| `Container`'s padding | `RenderPadding` | not overridden → `false` | — |
| `Row` | `RenderFlex` | delegates: `hitTestChildren → defaultHitTestChildren` | `rendering/flex.dart:1395-1396` |

**The error is that the enumeration stopped at `Row`.** The chain does not end there. The
`Row`'s children are `Icon` and `Text` (`demo_data_banner.dart:112`, `:115-127`), and
**both compile to `RenderParagraph`** — `Text` via `RichText`, and `Icon` also via
`RichText` (`widgets/icon.dart:328`, `Widget iconWidget = RichText(`). And:

```dart
// packages/flutter/lib/src/rendering/paragraph.dart:796  (class at :310)
@override
bool hitTestSelf(Offset position) => true;
```

`RenderParagraph` is one of the few `RenderBox` subclasses in the framework that opts into
`hitTestSelf => true`. It does so to support `TextSpan.recognizer` and text selection.
Combined with the base implementation:

```dart
// packages/flutter/lib/src/rendering/box.dart — RenderBox.hitTest
if (_size!.contains(position)) {
  if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
```

…**any** position inside the paragraph's box returns `true` — not merely positions on a
glyph. And `Stack` stops at the first hit:

```dart
// rendering/stack.dart:701-703  → box.dart defaultHitTestChildren
ChildType? child = lastChild;          // the pill is the LAST Stack child
while (child != null) { … if (isHit) { return true; } … }
```

So the `Stack` never tests `child` — the entire application below. The pointer path
contains the pill's paragraphs and nothing else; those paragraphs carry no gesture
recognizer, so the tap enters an empty arena and **dies**. It is not "passed through and
ignored"; it is consumed. Zero taps reach the control beneath, exactly as measured.

**Correct statement of the mechanism:** *the glass stack is pointer-transparent; the
`Icon` and `Text` leaves inside it are not.* Absorption is bounded by the two
`RenderParagraph` boxes. The `Positioned(left: 12, right: 12) > Center` strip either side
of the pill **does** fall through (`RenderPositionedBox` does not override `hitTestSelf`),
and so does the `Container`'s own 12pt horizontal / 7pt vertical padding ring — a tap
landing there hits `RenderPadding`, finds no child, and returns `false`. So the dead zone
is the pill's inner content box, not its full footprint. That is a smaller region than the
visual pill but a larger one than "nothing", and it sits at
`y ∈ [padding.top + kToolbarHeight + 4, +~29pt]` — horizontally centred — on **every route
in the app** (`main.dart:434`).

**Why this matters for the fix, which is the point of the question.**

| Fix | Kills the touch absorption? | Cost | Also fixes occlusion? |
|---|---|---|---|
| `IgnorePointer` around the pill | **Yes, completely** | one line | No |
| Move the pill into chrome / to the bottom | Yes | structural | Yes |

`IgnorePointer` is sufficient and safe: `RenderIgnorePointer.hitTest` is
`return !ignoring && super.hitTest(...)` (`rendering/proxy_box.dart`), which short-circuits
*above* the paragraphs, so `Stack` falls through to the app. Critically, it **does not cost
the screen-reader warning**: `visitChildrenForSemantics` returns early only when the
*deprecated* `ignoringSemantics` is explicitly `true`; with the modern
`IgnorePointer(ignoring: true)` the child semantics — including the pill's
`Semantics(liveRegion: true, label: …)` at `:90-94` — are still visited. The pill has no
`onTap` of its own, so nothing is lost.

Round 3 recommended relocation on **occlusion** grounds and that recommendation still
stands on its own merits (§7.05 below). But the two defects are now separable: occlusion
needs relocation; touch absorption needs one line. Conflating them has cost three rounds.

**Grading.** Round 3 graded §3.1 *"✅ (not implicated)"* on the strength of the wrong
mechanism. That is corrected here: the pill is a **non-interactive overlay that swallows
taps on interactive content beneath it on every route**, which is a §7.05 failure (focus
and interaction obscured by an overlay) and a §3.01 aggravator. It is graded **Fail**.

### F2. The corrected contrast comments — accurate; and the design gate now contradicts them

**The corrections made in `9127713` are verifiably exact.** I recomputed every figure the
commit claims to have fixed:

| Token | Old (false) claim | New claim | My measurement | Verdict |
|---|---|---|---|---|
| `orangeText` `#B86E00` on white | 4.6:1 | **3.99:1** | **3.99:1** | exact |
| `orangeDark` `#CC6E00` on white | 4.5:1 | **3.62:1** | **3.62:1** | exact |
| `warning` `#E65100` on white | 4.6:1 | **3.79:1** | **3.79:1** | exact |
| `onOrange` `#FFFFFF` on `#F39314` | "dark ink, 6.3:1" | **2.33:1**, accepted risk | **2.33:1** | exact |
| `orangeStrong` `#9A5C00` on white | — | 5.38:1 | **5.38:1** | exact |
| `onError` light `#FFFFFF` on `#D32F2F` | — | 4.98:1 | **4.98:1** | exact |
| `onError` dark `#212121` on `#EF5350` | — | 4.62:1 | **4.62:1** | exact |

Seven for seven. This is the first round in which a documentation claim in this repo has
survived independent recomputation without a correction. **Recorded as a genuine Pass** for
the specific work done (`lib/config/theme.dart:69-77`, `:100-103`; `lib/config/app_colors.dart:66-73`).

**But the answer to the question asked is yes — the gate now enforces a token its own
documentation says fails, and the commit that corrected the documentation said so in
writing and then did not touch the gate.**

`lib/config/theme.dart:69-73`, added by `9127713`:

```dart
// MEASURED 3.99:1 on white — the comment here used to claim 4.6:1, and the
// design gate enforces this token BECAUSE of that wrong figure. It clears the
// 3:1 large-text floor but FAILS 4.5:1 for body text. For small text use
// `orangeStrong` (#9A5C00, 5.38:1).
static const Color orangeText = Color(0xFFB86E00);
```

`scripts/check_design_consistency.sh`, **unchanged by that commit** — `git show --stat
9127713` touches `lib/config/app_colors.dart`, `lib/config/theme.dart` and
`lib/screens/assistant/assistant_executor.dart` and **nothing under `scripts/`**:

```
:58  #    and on orangeLight tints (~2:1). Text must use orangeText (4.6:1) — or
:70  report "Raw orange as text color is banned (2.3:1 on white) — use context.hc.orangeText, …"
```

Line 58 still carries **the exact false figure** the commit was written to retire. Line 70
is the message a developer sees when the gate fails their build, and it names
`context.hc.orangeText` as the remedy — it never mentions `orangeStrong`, which is the
token `theme.dart` says to use for small text. The gate's regex
(`\.orange[^A-Za-z]`) accepts `orangeStrong` silently but recommends the failing one.

So the repo now contains a **live internal contradiction**, and it will be resolved in
favour of the wrong side, because the gate is the half that fails builds and the comment is
the half nobody executes. Round 3 listed this as finding #42 ("a future reader will trust
these"); the fix was applied to the two files a reader reads and not to the one file a
machine enforces.

**It is not theoretical — there are failing call sites today.** `orangeText` has **77**
call sites in `lib/screens` + `lib/widgets`. Where the text is under 18pt regular / 14pt
bold, 3.99:1 on white (3.78:1 on the `#F8F9FA` app background) fails 4.5:1:

| Site | Size / weight | Background | Measured | Need |
|---|---|---|---|---|
| `lib/config/theme.dart:329-336` — **app-wide `ChipThemeData`** | 12 / w500 | `orangeLight` `#FFF3E0` | **3.63:1** | 4.5 |
| `lib/screens/settings/patient_profile_screen.dart:329-333` — medical conditions & dietary restrictions | 12 / w600 | `orangeLight` | **3.63:1** | 4.5 |
| `lib/screens/calendar/care_calendar_screen.dart:659-661` (today's weekday) | 11 | page | **3.99:1** | 4.5 |
| `lib/screens/calendar/care_calendar_screen.dart:869-872` | 11 | page | **3.99:1** | 4.5 |
| `lib/screens/checkout/address_selection_screen.dart:338` | 11 / w600 | page | **3.99:1** | 4.5 |
| `lib/screens/my_care/staff_otp_verification_screen.dart:200-201` | 12 | page | **3.99:1** | 4.5 |
| `lib/screens/calendar/care_calendar_screen.dart:1201-1203` | 12 | page | **3.99:1** | 4.5 |

The `ChipThemeData` case is the worst of these and carries its own surviving false comment,
**not corrected this round**:

```dart
// lib/config/theme.dart:334
// Raw orange on orangeLight is ~2:1 — orangeText keeps AA.
color: HousepitalColors.orangeText,
```

`orangeText` on `orangeLight` measures **3.63:1**. It does not keep AA. This is a fourth
false contrast claim, in the same file, five lines from a corrected one — and it governs
every Material `Chip` in the app plus the hand-rolled clone that renders a patient's
**medical conditions**.

**Two further uncorrected false figures**, both outside the two files the commit scoped:

- `lib/screens/main_shell.dart:135-141` — *"Composited **worst case** … #FFFCF8: selected
  #9A5C00 = 5.26:1, unselected grey = **5.21:1**"*. The 5.26:1 reproduces but is the **best**
  case, not the worst (§F3). And unselected `grey` `#3D3D3D` on `#FFFCF8` measures
  **10.62:1**, not 5.21:1 — the figure is simply wrong.
- `lib/config/theme.dart:25` — dark `textDisabled` `#7A7A7A` on card `#1C1C1E` claims
  *"~4.2:1"*; measured **3.96:1**. Round-3 finding #34, **unchanged**. This is the one
  remaining claim that errs in the *dangerous* direction: it asserts a pass where there is
  a fail.

(For completeness, several dark-class ratio comments — `orange` "6.32:1 vs surface",
`error` "4.9:1", `success` "7.6:1", `warning` "8.7:1", `info` "7.6:1" — were computed
against the pre-calm-pass surface `#1A1A1A` and never recomputed after `surface` became
`#000000`. All now understate, so none is a safety risk, but they are stale.)

### F3. Nav pill contrast — the round-3 range reproduces exactly

Independent recomputation of `GlassSurface(white/`#1C1C1E` @0.78)` → `orangeLight @0.22`
over each backdrop, `main_shell.dart:120-141`:

| Backdrop | Composite | Selected | Unselected |
|---|---|---|---|
| LIGHT white `#FFFFFF` | `#FFFCF8` | **5.26:1** | 10.62:1 |
| LIGHT app bg `#F8F9FA` | `#FDFCF7` | 5.24:1 | 10.57:1 |
| LIGHT hero `#FF6B35` | `#FFE3D6` | **4.41:1** | 8.90:1 |
| LIGHT mid-grey photo | `#E9E7E2` | **4.35:1** | 8.79:1 |
| LIGHT dark photo `#000000` | `#D3D1CC` | **3.52:1** | 7.12:1 |
| DARK true black | `#1F1A16` | **7.39:1** | 7.95:1 |
| DARK card `#1C1C1E` | `#231F1B` | 7.01:1 | 7.55:1 |
| DARK white photo `#FFFFFF` | `#4A4642` | **4.00:1** | **4.31:1** |

Round 3's range — **5.26 → 3.52:1 light, 7.39 → 4.00:1 dark** — reproduces to the decimal.
`extendBody: true` (`main_shell.dart:67`), `opacity: 0.78` and `sigma: 36` are all
unchanged, so the finding is unchanged: the control has **no contrast floor**, and the
single figure in its code comment is labelled "worst case" while being the best case.

### F4. Dynamic Type — unchanged, fourth round

`lib/main.dart:426-428`:

```dart
textScaler: mq.textScaler.clamp(
  minScaleFactor: 0.85,
  maxScaleFactor: 1.4,
),
```

Byte-identical to round 3. iOS AX5 ≈ 3.1×, so AX1–AX5 all collapse to 1.4×. The comment at
`:421-422` still cites *"WCAG 1.4.4"*, which requires **200%**; the clamp delivers 140%.

`grep -rln "textScaler\|TextScaler" test/` → **0 files** across 101 test files.
`test/screens/overflow_smoke_test.dart:102-104` still exercises three device sizes at
default scale only. `test/screens/main_shell_test.dart:291-293` still asserts no overflow
at 320×568 at default scale only. Round-1 blocker B3, **fourth round unchanged**.

### F5. Icon-button labelling — 17 of 54, fourth round, line-for-line identical

Independent brace-matched count over `lib/`, excluding the static helper
`IconButton.styleFrom(` (which naïve regex counting mistakes for a constructor — it
inflates the total to 63/20):

```
TOTAL IconButton constructors: 54 · labelled 37 · UNLABELLED 17
```

The 17, unchanged from round 3 and round 2:

`add_patient_screen.dart:273` · `family_members_screen.dart:123` ·
`help_faq_screen.dart:200` · `patient_profile_screen.dart:693`, `:772`, `:834` ·
`chat_screen.dart:304`, `:335` · `universal_search_screen.dart:284` ·
`add_edit_medication_screen.dart:92` · `health_manager_banner.dart:69`, `:80` ·
`document_repository_screen.dart:167`, `:390` · `service_booking_screen.dart:327`,
`:1018`, `:1037`

Spot-verified by reading the source: `health_manager_banner.dart:69` (`tel:` launch) and
`:80` (push `/chat`) are two visually near-identical rounded tiles with different
destinations and no `tooltip`; `chat_screen.dart:304` (attach photo) and `:335` (send) are
both bare.

### F6. `PaymentFailure.unverified` — colour contradicts the icon, and the body text fails AA in both appearances

`payment_service.dart:253-255` documents the state precisely: *"Checkout reported SUCCESS
but we could not verify it. Money has probably left the patient's account. NEVER offer a
retry here."* `payment_screen.dart:613-615` correctly suppresses the retry button. The
typed enum did its job at the control-flow layer.

**The presentation layer did not follow.** In `_buildResultScreen`
(`payment_screen.dart:446-635`) there are three colour decisions and the pending branch was
added to only two of them:

| Element | Line | Has a `_pendingVerification` branch? | Result in the pending state |
|---|---|---|---|
| Icon glyph | `:472-484` | **yes** — `Icons.schedule`, `hc.warning` | amber clock |
| Title | `:490-507` | **yes** — `hc.warning` | amber |
| **Icon well fill** | **`:466-471`** | **NO** — `isSuccess ? successLight : errorLight` | **red** |
| Message well + text | `:567-583` | **NO** — `errorLight` fill, `hc.error` text | **red on red** |

So an amber "pending" clock sits inside a **red error well**, above an explanatory
paragraph rendered in **error red on an error-red field**, on the screen that says *your
money probably left your account and you must not pay again*. `error` is the same token the
app uses for SOS.

**As an accessibility finding, precisely stated.** The checklist's first principle is
*"Colour is never the only carrier."* Here colour is not the *only* carrier — the clock
glyph and the localized title both carry "pending" — so the "meaning carried by colour
alone" red flag is **not** triggered, and I am not going to stretch it. The failure is a
different and arguably worse one, and it lands on real controls:

1. **§1.01 — the message text fails AA in BOTH appearances.** `hc.error` on `hc.errorLight`
   at `fontSize: 14` (`:572` fill, `:579-580` text):
   - light `#D32F2F` on `#FFEBEE` = **4.36:1** (need 4.5)
   - dark `#EF5350` on `#3A1F1F` = **4.32:1** (need 4.5)

   This is a **new finding**; round 3 did not measure this pair. It is not a one-appearance
   miss — it fails on both, by a similar margin, which is exactly the failure mode §1.03's
   two-appearance unit test exists to catch and which no test in this repo can catch.
2. **§1.02 — the well's boundary carries meaning and does not.** `errorLight` vs the page
   background: **1.08:1** light, **1.40:1** dark. The circle that colour-codes the outcome
   is barely distinguishable from the page; the colour semantic is carried almost entirely
   by a 120pt fill that is 1.08:1 from its surroundings. (The glyph itself is fine: amber on
   the red well measures 3.31:1 light / 8.69:1 dark, clearing the 3:1 non-text floor.)
3. **§8.05 — the outcome is never announced.** `_buildResultScreen` replaces the entire
   `Scaffold` body. There is no `liveRegion`, no `SemanticsService.sendAnnouncement`, no
   `FocusScope` and no `autofocus` anywhere in `payment_screen.dart` (5 `Semantics` nodes,
   all static labels). The single `liveRegion:` in the whole of `lib/` is in
   `demo_data_banner.dart:91`. A VoiceOver user who has just paid receives no announcement
   that the payment state resolved, in either direction.
4. **§8.01 / §7.01 — the recovery control is hardcoded English.** `:633` and `:651` render
   `const Text('Go Back')` on a screen that otherwise routes every string through `l.t(…)`.
   A Hindi-locale user gets a Latin-script button, and a Voice Control user speaking Hindi
   cannot address it by its visible label.

**Characterisation against the brief's question about the round-3 → round-4 pattern.** This
is neither a *surface* nor quite a *half-wire*. The behaviour the enum was introduced to
protect — no retry on an unverified payment — **is genuinely wired and correct**. What was
left unwritten is the presentation contract that should have travelled with the new third
state: the screen still has a two-state (success / failure) colour vocabulary while now
having three states. The right name for it is a **two-of-three edit**: the author added the
pending branch at the icon and the title and missed the two container fills.

---

## Prior-round status

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B1** white-on-orange 2.33:1 | Unchanged — **owner-accepted** | `theme.dart:32`, `:83`; measured 2.33:1, now documented as accepted risk. Graded Warning per brief |
| **B2** zero contrast assertions in `test/` | **Unchanged — 4th round** | `grep -rn "computeLuminance\|contrastRatio\|luminance" test/` → **0**, across 101 files / 1,819 tests |
| **B3** Dynamic Type clamped 1.4×, untested | **Unchanged — 4th round** | `main.dart:426-428` byte-identical; `textScaler` in `test/` → **0 files** |
| **B4** 17 of 54 icon buttons unlabelled | **Unchanged — exact** | Independent re-count: 54 / 37 / **17**, same 17 lines (§F5) |
| **B5** family-member removal swipe-only | **Unchanged — 4th round** | `family_members_screen.dart:319-340` still `Dismissible` + `confirmDismiss`; `_buildMemberCard:346` still `HousepitalCard > Row > [CircleAvatar, …]`, no trailing control |
| **H9** six sub-44pt targets | **Unchanged — all six** | Re-verified in source, one having moved line: `document_attach_widgets.dart:47-50` 18×18; `raise_concern_screen.dart:231-240` 22×22; `cart_screen.dart:883-890` 24×24; `payment_screen.dart:915-925` 24×24 (was `:864`); `article_list_screen.dart:188-196` ≈30pt; `care_calendar_screen.dart:355-358` ≈36pt |
| **M13/M14** chart `ExcludeSemantics`, `care_pulse_ring` double-announce | **Unchanged** | `care_pulse_ring.dart:86` still `Semantics(label:)` with no `excludeSemantics: true`; `ExcludeSemantics` in `lib/` still **4** |
| **M22** two ungated animations | **Unchanged** | `equipment_detail_screen.dart:1690`, `care_calendar_screen.dart:357` |
| **M25** 964 literal `fontSize`, 0 `textTheme.` | **Unchanged — exact** | 964 / 0. The `TextTheme` at `theme.dart:170-215`, `:360-395` remains dead code |
| **M26** 132 raw `Colors.white`, 178 all-variant | **Unchanged — exact** | 132 / 178 |
| §A `onError` token | **Still Pass** | Re-measured 4.98:1 light / 4.62:1 dark — both exact |
| §B nav pill contrast range | **Unchanged** | Range reproduces to the decimal (§F3) |
| §C demo notice announces once per session | **Unchanged** | `DemoDataBannerHost` still installed at `main.dart:434`, above the Navigator; `initState` still the only trigger |
| §D pill occludes ≥6 screens | **Unchanged**, and **now known to also absorb taps** | §F1 |
| §D "pill is transparent to touch" | **CORRECTED — was wrong** | §F1. `RenderParagraph.hitTestSelf => true`, `paragraph.dart:796` |
| §E demo-pill contrast backdrop-independent | **Still Pass** | `opacity: 0.92` unchanged at `demo_data_banner.dart:100` |
| §F `DemoMode` — 3 dead source constants | **Unchanged (still 3), 1 new constant wired** | 12 declared (`demo_mode.dart:24-35`, +`sourceVitals` this round), **9** resolved. Still dead: `sourceCareTeam:31`, `sourceCareCalendar:32`, `sourceProfile:33` |
| #42 false contrast comments in `theme.dart`/`app_colors.dart` | **Partially fixed — 7 corrections exact; 3 false claims survive, 1 dangerous** | §F2 |
| #26 `main_shell_test` default scale only | **Unchanged** | `main_shell_test.dart:291-293` |
| #31 ~20 `CircularProgressIndicator` unlabelled | **Unchanged / slightly worse** | **25** in `lib/`, **0** with `semanticsLabel` |
| #15 zero `FocusScope` | **Unchanged** | `grep -rho FocusScope lib` → **0** |

**Nothing regressed in a measurement.** The one thing that got worse is coherence: the
`orangeText` correction landed in the token files and not in the gate that enforces the
token, creating a contradiction that did not exist in round 3 (§F2).

---

## Control results

### §1 Contrast

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **1.01** Text 4.5:1 (3:1 large) | **Fail** | `payment_screen.dart:572`+`:580` 14pt = **4.36:1** light / **4.32:1** dark (new); `theme.dart:329-336` app-wide chip 12pt = **3.63:1**; `patient_profile_screen.dart:329-333` (medical conditions) **3.63:1**; `care_calendar_screen.dart:659-661`, `:869-872`, `:1201-1203`; `address_selection_screen.dart:338`; `staff_otp_verification_screen.dart:200-201` all **3.99:1** at 11–12pt | Body text on the payment-outcome and clinical-history screens is under AA in both appearances. **Fix:** swap the ≤14pt `orangeText` sites to `orangeStrong` (5.38:1) and darken the payment message text. Owner: **OWNER-TBD**, due before release |
| **1.02** Non-text UI 3:1 | **Fail** | Nav pill boundary **1.02:1** light / **1.22:1** dark (`glass.dart:162-164` white@0.6 edge over a near-white page); `payment_screen.dart:466-471` result well vs page **1.08:1** / **1.40:1**; dividers 1.32:1 / 1.47:1; calendar segmented thumb 1.17:1 / 1.27:1 | Controls whose boundary is their only affordance are effectively edgeless. The pill boundary is an **owner decision** ("read it as FROST"), reported as measurement; the payment well and the segmented thumb are not. **OWNER-TBD** |
| **1.03** Both appearances verified programmatically | **Fail** | `grep -rn "computeLuminance\|contrastRatio\|luminance" test/` → **0**. No test file is named for contrast/a11y/semantics | Fourth round. This is the control that would have caught 1.01's two-appearance failure, the 3.49:1 round-2 regression, and the three surviving false comments. **Blocks release** |
| **1.04** Paired foreground flips with appearance | **Warning** | `onError` genuinely flips and is correct: `#FFFFFF`/`#D32F2F` = 4.98:1, `#212121`/`#EF5350` = 4.62:1 (`theme.dart:50`, `:109`), used at all three `delete_account_screen.dart` sites. `onOrange` is hardcoded `#FFFFFF` in both palettes at **2.33:1** | The `onOrange` half is an **explicit owner decision** (`theme.dart:78-82`, CLAUDE.md), measured and recorded as accepted risk — graded Warning, not Fail, per the brief. Mitigation in force: on-orange text is kept ≥14px w600+. Approver: owner, 2026-06-11 |
| **1.05** Text over images/gradients scrimmed or worst-pixel measured | **Fail** | Nav pill has **no floor**: 3.52:1 light over dark imagery, 4.00:1 dark over light imagery (§F3), with `extendBody: true` making the backdrop arbitrary at every intermediate scroll offset; `glass.dart:139-152` chrome glass still `opacity: 0.55` with no worst-pixel guarantee; `home_screen.dart:600-602` promo scrim 0.45α → 3.36:1 worst case | The fix exists in the same file family and is proven: `demo_data_banner.dart:100` uses `opacity: 0.92` and holds within 0.25 across every backdrop. **OWNER-TBD** |

### §2 Dynamic Type

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **2.01** Busiest three screens at AX5 reflow | **Fail** | `main.dart:426-428` clamps at 1.4×; AX5 ≈ 3.1× is unreachable. `textScaler` in `test/` → **0 files**. **Unverified at any scale** | Fourth round. For an elderly-patient app this suppresses the single most-used accessibility setting on iOS. **Blocks release** |
| **2.02** Semantic type styles, not fixed sizes | **Fail** | **964** literal `fontSize:` in `lib/screens` + `lib/widgets`; **0** `textTheme.` references. The `TextTheme` at `theme.dart:170-215`, `:360-395` is dead code. No list of deliberate fixed sizes exists | Unchanged, fourth round. **OWNER-TBD** |
| **2.03** `minimumScaleFactor` a last resort with a ≥0.7 floor | **Fail** | `my_care_screen.dart:413-415` `FittedBox(fit: BoxFit.scaleDown)` around the vitals pill — `FittedBox` has **no floor parameter at all**; same pattern in `equipment_item_card.dart:127-128`, `:181-182` | Shrink-to-fit with no lower bound is precisely what the control forbids. **OWNER-TBD** |
| **2.04** Numbers users act on stay readable | **Fail** | `my_care_screen.dart:401-445` — the 16pt vital *value* and its unit sit inside the unbounded `FittedBox` in a **`width: 90`** pill; `equipment_item_card.dart:127-128` does the same to money | "Shrinking a total is losing the total." A vitals reading and a price are the two things in this app a user acts on. **OWNER-TBD** |
| **2.05** Container heights not hardcoded around one text size | **Fail** | `my_care_screen.dart:401` fixed `width: 90`; `demo_data_banner.dart:118-119` `maxLines: 1` + ellipsis on a clinical-safety warning; `care_calendar_screen.dart:551` day cell 43.4pt at 320pt; `care_calendar_screen.dart:817` `fontSize: 9.5`, below the app's own 11px floor | The demo pill truncates its warning inside the *supported* range (Hindi at 1.0×/320pt, English at 1.4×) — the designed failure mode of a "this is not your record" notice is to hide itself. **OWNER-TBD** |

### §3 Touch targets

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **3.01** Every tappable ≥44×44pt | **Fail** | Six verified in source: `document_attach_widgets.dart:47-50` **18×18**; `raise_concern_screen.dart:231-240` **22×22**; `cart_screen.dart:883-890` **24×24** (cart quantity stepper); `payment_screen.dart:915-925` **24×24**; `article_list_screen.dart:188-196` ≈**30pt**; `care_calendar_screen.dart:355-358` ≈**36pt** | Unchanged, fourth round. A correct 44pt stepper already exists in-repo at `services/widgets/quantity_button.dart:44` — the cart's is a hand-rolled 24pt clone. **OWNER-TBD** |
| **3.02** Destructive not adjacent to habitual without spacing/confirm | **Fail** | `settings_screen.dart:261-279` — "Delete account" one `Divider(height: 1)` below "Logout", same `hc.error`, same tile geometry, same icon family. Three destructive actions with no confirm: `care_calendar_screen.dart:1308-1314`, `cart_screen.dart:981`, `patient_profile_screen.dart:144-150` | A 1px separation between "end my session" and "erase my account" is a motor-accuracy trap. `confirmDestructiveAction` exists and has 8 correct call sites — these three bypass it. **OWNER-TBD** |
| **3.03** Multi-button rows use explicit per-button styles | **Pass** | Verified at the densest cases: `health_manager_banner.dart:69` and `:80` are two independent `IconButton`s each with its own `onPressed` and its own `IconButton.styleFrom`; `chat_screen.dart:304`/`:335` likewise. Flutter has no row-level button style that could fan one tap across siblings | The labelling defect on these same buttons is graded at 4.01, not here |
| **3.04** Gestures have visible-button equivalents | **Fail** | `family_members_screen.dart:319-340` — removing a family member is reachable **only** by `Dismissible(direction: endToStart)`. `_buildMemberCard:346` has no trailing `IconButton`, no `PopupMenuButton`, no `onTap` | Unreachable by VoiceOver, Switch Control, or keyboard — WCAG 2.1 §2.5.1 and §2.1.1. Fourth round. **Fix:** a trailing overflow button gated by the existing `canManage` (`:266`) calling `_showDeleteConfirmation`. **Blocks release** |

### §4 Screen reader

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **4.01** Icon-only controls labelled by action | **Fail** | **17 of 54** (§F5), line-for-line unchanged for a fourth round. Includes two visually near-identical tiles with different destinations (`health_manager_banner.dart:69` call / `:80` message), *send message* (`chat_screen.dart:335`), and three destructive deletes (`add_edit_medication_screen.dart:92`, `patient_profile_screen.dart:693`, `:834`) | An unlabelled destructive control is the worst case of this defect. **Fix:** one `tooltip:` per site. **Blocks release** |
| **4.02** Rows read as one sentence | **Fail** | `my_care_screen.dart:390-445` — the vitals pill has **no `Semantics` wrapper**; VoiceOver reads "Heart rate" / "72" / "bpm" as three nodes and the status is carried solely by an 8×8 coloured dot with no text, icon or label. `vitals_trend_grid.dart:64` omits the numeric reading from its label | The clinical status of a vital is inaudible. The correct pattern exists twice in-repo (`vitals_screen.dart`, `medications_screen.dart:220-235`). **Blocks release** |
| **4.03** Charts expose a text summary | **Warning** | `lib/screens/reports/vitals_screen.dart` carries **no `Semantics`** node; `vitals_trend_grid.dart:64` provides a label but omits the reading. No chart in the app is `ExcludeSemantics`-wrapped (`ExcludeSemantics` count in `lib/` = 4, none on a chart), so axis ticks leak as loose nodes | Round 3 called this the app's strongest area on the strength of no chart being *only* visual; on re-inspection the summaries are partial and the visuals are not hidden. Downgraded to Warning. **OWNER-TBD** |
| **4.04** Decorative images hidden from the a11y tree | **Warning** | `common_widgets.dart:131` labels the asset branch of `ProductImage`; `:134` leaves the network branch unlabelled | 100 bundled product photos are covered; the network path is not. **OWNER-TBD** |
| **4.05** Custom controls declare traits | **Fail** | `care_pulse_ring.dart:86` — `Semantics(label:)` with no `excludeSemantics: true` → doubled announcement at 4 call sites; `care_calendar_screen.dart:355-358` segmented view switch is a bare `GestureDetector` with no `button` trait and no selected state; `my_care_screen.dart:397` vitals pill `InkWell` announces no trait | Unchanged. **OWNER-TBD** |
| **4.06** Sheet/alert focus lands on the meaningful element | **Fail** | `grep -rho "FocusScope" lib` → **0**; `FocusTraversalGroup` → 0; one `autofocus` app-wide; ~25 modal sheets | Nothing directs focus on sheet presentation anywhere in the app. **OWNER-TBD** |
| **4.07** One full screen-reader pass of the top three flows on a real device | **BLOCKED-OWNER** | No artifact in the repo: `docs/` contains no accessibility evidence file; `find test -iname "*a11y*" -o -iname "*access*" -o -iname "*semantic*"` → none | See BLOCKED-OWNER section for what is required |

### §5 Motion, sound & state

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **5.01** Reduce Motion honoured | **Warning** | **17** `disableAnimations` gate sites in `lib/` — genuinely broad, including the payment result reveal (`payment_screen.dart:304-312`) and `care_pulse_ring.dart:84`. Two remain ungated: `equipment_detail_screen.dart:1690-1694` (250 ms controller), `care_calendar_screen.dart:357` (`AnimatedContainer` 150 ms) | Two of ~19 animated surfaces unguarded; both are short and non-parallax. **OWNER-TBD**, low severity |
| **5.02** No information only haptic or only sound | **Pass** | Every `HapticFeedback` call is paired with a visible state change — e.g. `payment_screen.dart:277-280` and `:297-298` set `_showResult` before the impact call. No audio-only signalling exists in `lib/` |
| **5.03** Nothing flashes >3×/s; auto-advance pausable | **Pass** | No `autoPlay` anywhere; the only `Timer.periodic` instances are a 1-minute duty refresh (`home_screen.dart:71`), a 1-second call duration counter (`video_consultation_screen.dart:75`) and the OTP timers — none animates content. CLAUDE.md bans infinite pulses and the code complies |
| **5.04** Time-limited flows generous or extendable | **Warning** | `otp_screen.dart:19-56` — 30 s resend cooldown plus a **5-minute expiry that locks the input and forces a resend**. There is no warning before expiry, no extension, and no preservation of partially-entered digits | 5 minutes is generous, but a hard lock with no prior warning is a cognitive-load failure for the app's elderly cohort. **OWNER-TBD** |

### §6 Process

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **6.01** Contrast assertions in the automated suite, both appearances | **Fail** | **0** across 101 test files. Also 0 `textScaler`, 0 semantics/a11y-named test files | Fourth round. **Blocks release** |
| **6.02** New colours enter through the token system **with their pairings**; hardcoded colour is a review flag | **Fail** *(was Warning in round 3)* | The gate is real and does enforce the token half: `check_design_consistency.sh` bans hex literals, `Colors.grey.shade*`, raw status colours. But (a) it scans **`lib/screens` only** — `lib/widgets` is unscanned, and `glass.dart`, `demo_data_banner.dart`, `common_widgets.dart`, `care_pulse_ring.dart` all live there; (b) it bans **no** `Colors.white`/`black`, of which there are **178**; (c) it has **no foreground/background pairing rule at all**; and (d) its one statement about a pairing — `:58` *"Text must use orangeText (4.6:1)"* and `:70`'s failure message — cites the exact figure `theme.dart:69-73` was rewritten this round to retire, and steers every violation into a token measured at **3.99:1** (§F2) | **Downgraded from Warning deliberately.** In round 3 the gate and the token comment agreed and were both wrong. This round the token comment was corrected and the gate was not, so the repo now contradicts itself — and the contradiction resolves in favour of the gate, because the gate fails builds. **Fix is two lines** in `check_design_consistency.sh:58`, `:70`: correct the figure and name `orangeStrong` as the remedy for text under 18pt. **OWNER-TBD, before release** |
| **6.03** A11y findings fixed at the priority of equal-impact functional bugs | **BLOCKED-OWNER** | Round-4 datum: `13e3656` closed four harmful *functional* defects in one commit; `9127713` corrected four *documentation* claims. Neither touched any of the five accessibility blockers, all of which are now **four rounds old**. `docs/KNOWN_ISSUES.md` does now carry the open a11y blockers, which is new and is the first tracker-shaped evidence in four rounds | Needs the owner's triage policy plus one release cycle of tracker evidence |

### §7 Assistive input, focus, and navigation *(first graded this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **7.01** Voice Control operable; visible labels match a11y names | **Fail** | 17 icon-only controls have no accessible name at all (§F5), so they cannot be addressed by voice. Where names exist they are English-only tooltips (`glass.dart:63` `'Home'`, `:79` `'Search'`) on a fully Hindi-localized app — a Hindi speaker's spoken label will not match. `payment_screen.dart:633`, `:651` and `main.dart:793` render `const Text('Go Back')`; `settings_screen.dart:276` renders hardcoded `'Delete account'` | Voice Control is the primary input for users with motor impairment. **Fix:** localize tooltips through `l.t(…)` and add the 17 missing names. **OWNER-TBD** |
| **7.02** Switch Control reaches, identifies and activates everything without traps | **Fail** | `family_members_screen.dart:319-340` — swipe-only removal is unreachable by scanning. `demo_data_banner.dart` overlay absorbs activation on the content beneath it on every route (§F1). 17 elements are reachable but unidentifiable | Definite failure on the swipe-only path; the rest is unverified on device. **Blocks release** |
| **7.03** Full Keyboard Access covers all common tasks | **Warning — unverified** | Web is a shipped target (CI builds `flutter build web --release`, `ci.yml:101-102`), so keyboard navigation is a live requirement. Flutter supplies default traversal, but the app adds **0** `FocusTraversalGroup`, **0** `FocusScope`, 1 `autofocus`; the swipe-only removal has no keyboard path | Not tested — recorded as Warning with "unverified" stated, not N/A. **OWNER-TBD** |
| **7.04** Pointer, hover, remote and focus-engine interactions work per platform | **Warning — unverified** | Six platform folders present (`ios`, `android`, `web`, `macos`, `windows`, `linux`); CI exercises **web** only, and only as a build. No hover states are defined outside Material defaults; `HousepitalCard` press-scale is touch-shaped (0.97 @ 120 ms) | Not tested on any pointer platform. **OWNER-TBD** |
| **7.05** Focus visible, logical order, not obscured by sticky bars, sheets, keyboards or overlays | **Fail** | The demo pill (a) **occludes** the first content line of at least six screens — `care_calendar_screen.dart:216` (+0 padding), `my_care_screen.dart:141`, `care_team_screen.dart:84`, `assistant_screen.dart:88`, `delete_account_screen.dart:215` (all +8), `billing_screen.dart:172` (+16), plus the Settings profile avatar — permanently, non-dismissibly, and unrecoverably by scrolling; and (b) **absorbs the hit test** over its content box on every route (§F1). Traversal order was also lost when it moved from Column child to `Positioned` Stack child (`main.dart:434`) | Both halves land on this control. Occlusion needs relocation; absorption needs one `IgnorePointer`. **Blocks release** |
| **7.06** Dragging and complex gestures have simple alternatives | **Fail** | `family_members_screen.dart:319-340` `Dismissible` is the sole path to a destructive action | Same root cause as 3.04. **Blocks release** |
| **7.07** Button Shapes, On/Off Labels, Differentiate Without Color, Bold Text, Increase Contrast, Reduce Transparency tested | **Fail** | Flutter surfaces all of these through `MediaQuery`. Counts in `lib/`: `boldText` **0**, `highContrast` **0**, `accessibleNavigation` **0**, `invertColors` **0**, `onOffSwitchLabels` **0**. Only `disableAnimations` (17) is honoured | **Reduce Transparency is the acute one for this app**: its entire chrome is `BackdropFilter` glass — nav pill, app bars, demo pill — and with the OS flag on, none of it degrades to an opaque surface. Increase Contrast would also be the correct escape hatch for the 3.52:1 pill floor and is unread. **OWNER-TBD, high** |

### §8 Cognitive accessibility, forms, and authentication *(first graded this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **8.01** Instructions, labels, navigation and help consistent | **Warning** | The nav contract is genuinely strong and enforced by test (`GlassAppBar` trailing order, cart always rightmost — `glass.dart:52-63`, CLAUDE.md). Against that: `'Go Back'` hardcoded English at `payment_screen.dart:633`, `:651`, `main.dart:793`; `'Delete account'` hardcoded at `settings_screen.dart:276` directly beneath a localized `l.t('logout')` | Mixed-language chrome on the two most consequential screens. **OWNER-TBD** |
| **8.02** Forms identify errors in text, associate each error with its field, preserve valid entries | **Warning** | 46 `TextFormField` with **32** `validator:` — Flutter associates validator output with the field automatically via `InputDecoration.errorText`, so the association half is satisfied by construction for those 32. The remaining 14 have no validator, and there is exactly **1** explicit `errorText` in `lib/` | Two-thirds covered by framework behaviour; the gap is unquantified per-field. **OWNER-TBD** |
| **8.03** Previously entered information not requested again | **Warning — unverified** | `otp_screen.dart:47-56` — on expiry the input is locked and the user must resend; entered digits are not preserved. No broader re-entry audit is possible from source without exercising the flows | **OWNER-TBD** |
| **8.04** Auth supports password managers, autofill, paste, passkeys | **Fail** | `grep -rho "autofillHints\|AutofillGroup" lib` → **0**. The login is phone + SMS OTP (`login_screen.dart:155`, `otp_screen.dart:130`); with no `AutofillHints.oneTimeCode` the iOS SMS auto-fill affordance never appears, so every user must read a code from a notification and retype it | This is the single highest-value one-line accessibility fix in the app for the elderly cohort, and it is absent. **OWNER-TBD, high** |
| **8.05** Status changes, validation results, loading completion and errors announced programmatically | **Fail** | **25** `CircularProgressIndicator` in `lib/`, **0** with `semanticsLabel` — including the account-deletion spinner (`delete_account_screen.dart:301-302`) covering a `SharedPreferences` write, a Firebase credential delete and a full `SessionScope.clearSession`. The payment outcome screen announces nothing (§F6.3). The whole app contains **one** `liveRegion` and **one** `SemanticsService` call, both in `demo_data_banner.dart` | The two most consequential asynchronous operations in the app — deleting your account and paying a bill — resolve in silence. **Blocks release** |
| **8.06** Timeouts and auto-dismiss provide warning, extension, pause or recovery | **Warning** | `otp_screen.dart:47-56` — 5-minute expiry with a hard input lock, no prior warning, no extension. Recovery (resend) exists | Recovery exists, warning does not. **OWNER-TBD** |

### §9 Media, orientation, zoom, and reflow *(first graded this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **9.01** Prerecorded video captioned | **N/A** | Rationale: the app plays no video. `grep -rn "VideoPlayer\|video_player\|Chewie" lib/ pubspec.yaml` → **0**. `video_consultation_screen.dart` is a call-timer UI with no media playback (`:75` is a 1-second `Timer.periodic`) | If live video consultation is ever wired to a real transport, this control becomes live and must be re-run |
| **9.02** Audio-only content has a transcript; essential visual video has audio description | **N/A** | Rationale: no prerecorded audio or video assets. The only audio surface is microphone **input** for the assistant (`ios/Runner/Info.plist` `NSMicrophoneUsageDescription`), which is input, not media content |
| **9.03** All applicable orientations and window sizes supported | **Pass** | `ios/Runner/Info.plist` `UISupportedInterfaceOrientations` = Portrait + LandscapeLeft + LandscapeRight; `~ipad` adds PortraitUpsideDown. `grep -rn "setPreferredOrientations\|DeviceOrientation" lib/` → **0** — no programmatic lock |
| **9.04** Reflow at 200% text/zoom without two-dimensional scrolling | **Fail** | 200% is **unreachable**: `main.dart:426-428` clamps at 1.4×. The comment at `:421-422` cites WCAG 1.4.4, which requires 200%. Reflow is untested at any scale (`textScaler` in `test/` → 0 files) | Same root cause as 2.01; recorded separately because it is a distinct WCAG obligation. **Blocks release** |
| **9.05** Auto-playing or auto-updating content pausable; audio does not start unexpectedly | **Pass** | No `autoPlay` in `lib/`. The three `Timer.periodic` instances update a duty label, a call timer and the OTP countdown — none moves focus, plays audio, or advances content |

### §10 Common-task matrix and store declarations *(first graded this round)*

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **10.01** Common-task inventory covering primary functionality plus first launch, login, purchase, settings, help, notifications | **Fail** | No such inventory exists. `docs/` contains `SCREEN_MAP.md`, `TEST_MAP.md`, `FEATURE_TRACKER.md` — screen and test inventories, not *task* inventories, and none records assistive-technology coverage | This is the artifact every other §10 control depends on, and it is the cheapest to produce. **OWNER-TBD** |
| **10.02** Device-by-common-task matrix with evidence per device family | **Fail** | Absent. No file under `docs/` or `test/` records a device, an assistive feature, and a result | **Blocks the Nutrition Label declaration below** |
| **10.03** Automated accessibility scans in CI | **Fail** | `.github/workflows/ci.yml` runs `pub get`, `flutter analyze`, the design gate, `flutter test --coverage`, a coverage gate, and a web release build. **No accessibility step.** Flutter ships `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, `iOSTapTargetGuideline` and `labeledTapTargetGuideline` in `flutter_test` — all four are directly applicable to the §1.01, §3.01 and §4.01 failures above, and none is used | Four of this report's blockers are mechanically detectable by a framework API already on the dependency graph. **Blocks release** |
| **10.04** Nutrition Label declarations supported by the completed matrix | **Fail** (source side) · declaration state **BLOCKED-OWNER** | No matrix exists (10.02), so no declaration can be *supported*. Whether declarations have been entered in App Store Connect is not visible from source | Declaring support that the matrix cannot evidence is a store-listing risk as well as an accessibility one |
| **10.05** Accessibility URL or statement accurate | **Fail** | No accessibility statement anywhere in the repo; `grep -rln "accessibility" docs/*.md` matches only `docs/CHANGELOG.md`. No support contact for accessibility issues is published | **OWNER-TBD** |
| **10.06** Periodic usability evaluation including people with relevant disabilities | **BLOCKED-OWNER** | No evidence in repo; not knowable from source | See BLOCKED-OWNER |

---

## Scorecard

| Section | Pass | Warning | Fail | N/A | BLOCKED-OWNER | Items |
|---|---|---|---|---|---|---|
| 1. Contrast | 0 | 1 | 4 | 0 | 0 | 5 |
| 2. Dynamic Type | 0 | 0 | 5 | 0 | 0 | 5 |
| 3. Touch targets | 1 | 0 | 3 | 0 | 0 | 4 |
| 4. Screen reader | 0 | 2 | 4 | 0 | 1 | 7 |
| 5. Motion, sound & state | 2 | 2 | 0 | 0 | 0 | 4 |
| 6. Process | 0 | 0 | 2 | 0 | 1 | 3 |
| 7. Assistive input, focus, nav | 0 | 2 | 5 | 0 | 0 | 7 |
| 8. Cognitive, forms, auth | 0 | 4 | 2 | 0 | 0 | 6 |
| 9. Media, orientation, zoom | 2 | 0 | 1 | 2 | 0 | 5 |
| 10. Matrix & store declarations | 0 | 0 | 5 | 0 | 1 | 6 |
| **Total** | **5** | **11** | **31** | **2** | **3** | **52** |

**Comparability with round 3.** Round 3 graded §§1–6 only: 5 Pass / 9 Warning / 12 Fail / 2
BLOCKED. On the same 28 controls, round 4 is **3 Pass / 5 Warning / 18 Fail / 0 N/A / 2
BLOCKED**. The apparent worsening is **not** a regression in the code — it is three
re-gradings on better evidence:

- §3.01 was ✅ in round 3 on the strength of a hit-testing claim that measurement has now
  disproved (§F1); the pill is an occluding, tap-absorbing overlay.
- §6.02 moved Warning → Fail because the `orangeText` correction created a documented
  contradiction with the enforcing gate (§F2).
- §4.03 moved ✅ → Warning after inspecting the vitals screen directly rather than by
  inference.

Every other §§1–6 verdict is materially the same finding as round 3, most of them
byte-identical. The 24 newly graded §§7–10 controls contribute 2 Pass / 6 Warning / 13
Fail / 2 N/A / 1 BLOCKED.

---

## Release blockers (every Fail)

Ordered by user harm. All 31 Fails are release-blocking under the checklist's release rule
unless formally accepted by a named authority; these eleven are the ones I would refuse to
sign off on.

1. **§8.05 — the two most consequential async operations resolve in silence.** 25
   `CircularProgressIndicator`, **0** `semanticsLabel`. Account deletion
   (`delete_account_screen.dart:301-302`) and payment outcome
   (`payment_screen.dart:446-635`) announce nothing. One `liveRegion` exists in the entire
   app.
2. **§7.05 / §3.01 — the demo pill occludes and absorbs on every route.** §F1. Occlusion on
   ≥6 screens including the DPDP §12 erasure screen; tap absorption over its content box
   app-wide. **Two independent fixes:** `IgnorePointer` (one line) for absorption;
   relocation to above the nav pill for occlusion.
3. **§4.01 — 17 of 54 icon buttons silent, fourth round unchanged to the line.** Includes
   three destructive deletes and two identical-looking buttons with different destinations.
4. **§3.04 / §7.02 / §7.06 — family-member removal is swipe-only, fourth round.**
   `family_members_screen.dart:319-340`. Unreachable by VoiceOver, Switch Control, or
   keyboard. WCAG 2.1 §2.5.1, §2.1.1.
5. **§1.01 — body text under AA in BOTH appearances on the payment-outcome screen** (4.36:1
   / 4.32:1, `payment_screen.dart:572`+`:580`) **and on the clinical-history chips** (3.63:1,
   `theme.dart:329-336`, `patient_profile_screen.dart:329-333`).
6. **§1.03 / §6.01 — zero contrast assertions, fourth round.** 0 across 101 files. This is
   the control that would have caught blocker 5 automatically.
7. **§2.01 / §9.04 — Dynamic Type clamped at 1.4×, untested, fourth round.**
   `main.dart:426-428`. WCAG 1.4.4 requires 200%; the code cites 1.4.4 while delivering 140%.
8. **§4.02 — clinical vitals status is colour-only and unlabelled.**
   `my_care_screen.dart:390-445`. An 8×8 dot is the sole carrier; the pill has no
   `Semantics`.
9. **§6.02 — the design gate enforces a token its own token file documents as failing.**
   §F2. `check_design_consistency.sh:58`, `:70` vs `theme.dart:69-73`. **Two-line fix.**
10. **§7.07 — Reduce Transparency, Increase Contrast, Bold Text and Differentiate Without
    Color are all unread.** For an app whose entire chrome is `BackdropFilter` glass with a
    3.52:1 floor, Reduce Transparency and Increase Contrast are the OS's own escape hatches
    and neither is honoured.
11. **§10.03 — no accessibility step in CI, while four of these blockers are detectable by
    `flutter_test` APIs already on the dependency graph** (`textContrastGuideline`,
    `iOSTapTargetGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`).

---

## Warnings requiring risk acceptance

| # | Warning | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | **§1.04** `onOrange` hardcoded `#FFFFFF` at **2.33:1** on every orange fill | The checklist's own red flag "white text hardcoded onto a brand colour". Measured, not estimated | **Explicit owner decision, 2026-06-11**, re-recorded in `theme.dart:78-82` and CLAUDE.md. In force: on-orange text kept ≥14px w600+ | Owner — **accepted** |
| W2 | **§4.03** chart/trend summaries partial; visuals not hidden from the reader | Trend direction and reading are not both exposed | `vitals_trend_grid.dart:64` gives a label; add the reading and `ExcludeSemantics` the visual | OWNER-TBD |
| W3 | **§4.04** `ProductImage` network branch unlabelled (`common_widgets.dart:134`) | Bundled 100 photos are covered; remote ones are not | Mirror the asset branch's label | OWNER-TBD |
| W4 | **§5.01** two ungated animations | `equipment_detail_screen.dart:1690`, `care_calendar_screen.dart:357`; both short, non-parallax | 17 other sites already gate correctly — copy the pattern | OWNER-TBD |
| W5 | **§5.04 / §8.06** OTP 5-min expiry hard-locks with no warning or extension | Elderly users retyping a code from a notification will hit it | Warn at 60 s; preserve entered digits across resend | OWNER-TBD |
| W6 | **§7.03 / §7.04** keyboard and pointer paths **unverified** on a shipped web target | CI builds web release but never exercises input | Add a keyboard-traversal test, or drop web from the release set | OWNER-TBD |
| W7 | **§8.01** `'Go Back'` ×3 and `'Delete account'` hardcoded English | Mixed-language chrome on payment and settings | Route through `l.t(…)`; keys exist for siblings | OWNER-TBD |
| W8 | **§8.02** 14 of 46 `TextFormField` have no validator | Error association satisfied by framework for the other 32 | Audit the 14 | OWNER-TBD |
| W9 | **§8.03** OTP re-entry after expiry | Digits not preserved | Preserve on resend | OWNER-TBD |

Also reported as measured fact against standing owner decisions, **not graded as failures**
per the brief: the floating glass pill nav as a design choice; the pill's **1.02:1** light /
**1.22:1** dark boundary ("read it as FROST"); its content-dependent **5.26 → 3.52:1**
selected-label range; manpower prices shown and directly bookable; and the `DemoData`
fallbacks themselves. The decisions are the owner's; the numbers are not.

---

## BLOCKED-OWNER — needs access I do not have

1. **§4.07 — manual VoiceOver pass on a physical device.** No artifact exists in the repo.
   **To clear this I need:** a physical-iPhone VoiceOver run of (a) Home → book → cart →
   checkout, (b) My Care → vitals → care calendar, (c) Settings → Delete account → confirm,
   pass/fail per step. **This round adds two specific questions only a device run can
   settle:** (i) whether the sample-data announcement is heard on screens *other* than the
   one foregrounded when the timeout fired — the once-per-session analysis at
   `main.dart:434` predicts it is not; and (ii) whether the pill's tap absorption (§F1) is
   perceived as an unresponsive control rather than a mis-tap, which determines whether the
   `IgnorePointer` fix is sufficient or relocation is required.
2. **§6.03 — accessibility findings triaged at functional-bug priority.** Round 4 supplies a
   mixed datum: `docs/KNOWN_ISSUES.md` now carries the open accessibility blockers for the
   first time — real progress — while all five round-1 accessibility blockers are now four
   rounds old and ten functional blockers have closed in the same window. **To clear this I
   need:** the owner's triage policy plus one release cycle of tracker evidence.
3. **§10.06 — periodic usability evaluation including people with relevant disabilities.**
   Not knowable from source. **To clear this I need:** a record of one evaluation session,
   its participants' relevant access needs, and its findings. Related: **§10.04**'s
   *declaration* state requires App Store Connect access I do not have, though the
   source-side requirement (a matrix to support it) is gradeable and fails.

---

## Limitations of this audit

- **MASTER-4.04: this is a SOURCE review, not a release-artifact review.** No IPA, no
  device, no production traffic, no App Store Connect, no Firebase console. Contrast figures
  are computed from token definitions and compositing arithmetic, not sampled from rendered
  pixels; a real device introduces display gamma, True Tone and the platform's own
  Increase-Contrast adjustments. This is an honest constraint of the assignment, not a
  finding.
- **Per the brief, no `flutter test` / `build` / `clean` / `analyze` was run.** The
  accessibility guideline APIs in `flutter_test` (`textContrastGuideline`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline`) would have produced first-party
  evidence for §§1.01, 3.01 and 4.01 and could not be exercised. The absence of those tests
  from the suite is itself graded at §10.03.
- **The hit-testing conclusion is derived from framework source at the pinned SDK**
  (Flutter 3.41.2, framework `90673a4eef`), corroborated by the owner's independent widget
  probe. I did not run the probe myself. The two agree, and the citation chain
  (`paragraph.dart:796` → `box.dart` `hitTest` → `stack.dart:701` →
  `box.dart` `defaultHitTestChildren`) is checkable by anyone with the same SDK.
- **Touch-target sizes are computed from declared `size:` and `padding:` values**, not
  measured from a laid-out tree. Where a parent imposes constraints not visible at the call
  site the effective target could differ; the six cited sites all declare their own geometry.
- **Dynamic Type behaviour above 1.4× is unobservable** because the app clamps there. All
  statements about AX5 are analysis of layout code, not observation.
- **§§7.03, 7.04, 8.03 are graded Warning with "unverified" stated plainly**, per the
  master rule that not-tested is not N/A. Only §§9.01 and 9.02 are graded N/A, each with a
  written applicability rationale.
- Firebase posture, `storage.rules` deployment, payment-key handling and PHI session-scoping
  are outside this control family and are covered by the security and post-launch audits.

---

## Overall result

☐ Pass ☐ Pass with accepted warnings ☑ **Hold** ☐ Reject

**Release blockers / conditions:** the eleven listed above. Four of the checklist's five
"stop the release" red flags stand (meaning carried by colour alone at
`my_care_screen.dart:390-445`; white hardcoded on a brand colour — owner-accepted; a control
under 44pt ×6; "looks fine" as the only contrast evidence, fourth round). The fifth — a
chart with no textual equivalent — is a Warning, not a red flag.

**Accepted risks and approver:** W1 (`onOrange` 2.33:1) — owner, 2026-06-11. The pill
boundary and the pill's contrast range are owner design decisions reported as measurement.

**Decision owner / signature / date:** OWNER-TBD.
