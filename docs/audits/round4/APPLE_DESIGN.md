# House Design System — Apple-First Standard (DES) — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-11 · **Auditor:** Apple-Design (DES control family) · **Scope:** source review (see Limitations)
**Branch:** `fix/five-tab-nav` · **Round 3:** `9a80fe2` (`docs/audits/round3/APPLE_DESIGN_AUDIT.md`) · **Round 2:** `820060b`

**Method.** Read-only. Direct reads of `lib/config/theme.dart`, `lib/config/app_colors.dart`,
`lib/widgets/glass.dart`, `lib/widgets/demo_data_banner.dart`, `lib/widgets/common_widgets.dart`,
`lib/screens/main_shell.dart`, `lib/main.dart`, all five root-tab screens,
`lib/screens/reports/vitals_screen.dart`, `lib/screens/billing/payment_screen.dart`,
`lib/services/payment_service.dart`, `lib/providers/orders_provider.dart`,
`lib/providers/app_provider.dart`, `lib/utils/session_scope.dart`,
`scripts/check_design_consistency.sh`, `docs/KNOWN_ISSUES.md`, and the Flutter SDK at
`/opt/homebrew/share/flutter/packages/flutter/lib/src/rendering/paragraph.dart` (to settle the
hit-test dispute in §2). Contrast recomputed with a WCAG 2.x relative-luminance calculator
validated against `#767676`/white = 4.54 and black/white = 21.00.

Per the brief I did **not** run `flutter test`, `flutter build`, `flutter clean`, or `pod install`.

---

## Applicability

DES applies in full (DES-1.01, DES-1.03). This is an Apple-platform product: an iOS-first Flutter
app with an `ios/Runner` target, an iOS launch storyboard, an `AppIcon.appiconset`, and a design
system that explicitly names Apple idioms as its reference (`glass.dart:9-15`, `main_shell.dart:67-68`,
CLAUDE.md "Design system contract"). Nothing in the DES family is out of scope on grounds of
platform. Two sub-areas are **BLOCKED-OWNER** rather than N/A — design-file governance (DES-8.01)
and on-device design QA (DES-8.06) — because they require artifacts and access outside this repo.

Per MASTER-4.04, evidence here comes from **source**, not from a release artifact on a
production-like device. That is an honest constraint of this engagement, recorded in Limitations.

---

## Prior-round status

Every round-3 finding, re-verified at `9127713`.

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B1 (blocker)** Sample-data notice occludes titles on 4/5 tabs and the `/vitals` TabBar | **Still open — unchanged, and round 3's *mechanism* was wrong** | `demo_data_banner.dart` is byte-identical: absent from `git diff --stat 9a80fe2..9127713 -- lib/`. Still `Positioned(top: MediaQuery.of(context).padding.top + kToolbarHeight + 4, …)` at `:44-49`. **Correction:** round 3 §A-2 called it "pointer-transparent"; it is not. See §2 |
| **B2 (blocker)** `orangeText`/`orangeDark`/`warning` documented as passing AA when they fail | **Documentation Pass; the gate is now a Fail** | Comments corrected at `theme.dart:70-73, 76-77, 99-101, 277` and `app_colors.dart:66-72`. All three figures reproduce to the digit (§1). But `check_design_consistency.sh:58, 70` still enforce `orangeText` and still cite 4.6:1, and `theme.dart:334` was missed. See §1 |
| **B3 (blocker)** App icon not submission-quality; launch screen hardcoded white | **Still open — untouched for a third round** | `git log --oneline -3 -- ios/Runner/Assets.xcassets` → last touch `820060b` (round 2). `grep -c appearances .../AppIcon.appiconset/Contents.json` → **0**. `LaunchScreen.storyboard:22` still `red="1" green="1" blue="1" alpha="1"` |
| **H4** `onError` pairing reached 3 of 14 destructive sites; missed the shared helper | **Still open — unchanged** | `common_widgets.dart:520-523` still `backgroundColor: context.hc.error, foregroundColor: Colors.white` (**3.49:1** dark). `grep -rn "confirmDestructiveAction" lib` → **14**. `grep -rn "hc.onError" lib` → **3**, all in `delete_account_screen.dart:187, 294, 302` |
| **H5** Payment pending gated on an English substring — one translation from a double debit | **Pass — genuinely closed** | `payment_service.dart` now declares `enum PaymentFailure {notStarted, declined, unverified}`; `payment_screen.dart:288` is `final unverified = kind == PaymentFailure.unverified;`. The callback signature changed to `void Function(String message, PaymentFailure kind)` (`payment_service.dart:105`), so no caller can regress silently — it would not compile |
| **H6** Pending state colour-coded as a failure | **Still open — unchanged** | `payment_screen.dart:466-469` still `color: isSuccess ? context.hc.successLight : context.hc.errorLight`. The pending branch (`:475-483`) puts a warning-coloured `Icons.schedule` on a **red** 120pt well |
| **H7** GlassAppBar unpaired with `extendBodyBehindAppBar` | **Still open — and the ratio was mis-stated. It is 7 of 46, not 8** | `comm -12` of `grep -rl "GlassAppBar(" lib/screens` (**46**) and `grep -rl "extendBodyBehindAppBar: true" lib/screens` (**7**) → **7**. Round 3's 8 came from a looser grep that matched `service_catalog_screen.dart:127`, a *comment* explaining why that screen deliberately does **not** use it. Same 7/46 at `9a80fe2`. Ratio unchanged for three rounds; the number was wrong for two |
| **H8** Four header idioms across five tabs | **Still open — unchanged, 4 idioms confirmed** | Home: no `AppBar`, in-body 28/w800 greeting (`home_screen.dart:103`, `:736`). My Care + Billing: `GlassAppBar` + cross-fading body large title (`my_care_screen.dart:84`,`:153`; `billing_screen.dart:145`,`:185`). Services: 28/w800 inside `bottom:` (`service_catalog_screen.dart:129-167`). More: plain bar title only (`settings_screen.dart:88-92`) |
| **H9** SOS: one entry point, scrolls away | **Still open** | `home_screen.dart` SOS block remains inside the `SingleChildScrollView` at `:111` |
| **H10** Errors rendered as empty states | **Still open** | `notifications_screen.dart:47` and `transaction_log_screen.dart:60` still `showEmptyOnError: true` |
| **H11** Two unconfirmed destructive actions | **Still open** | `patient_profile_screen.dart:148, :164`; `care_calendar_screen.dart:1311-1313` |
| **H12** Booking wizard: raw `AppBar`, overloaded back, no `PopScope` | **Still open** | `service_booking_screen.dart:325-336`; `grep -rn PopScope lib \| wc -l` → **1** |
| **H13** Logout / deletion leave the user inside the authenticated app | **Still open** | `delete_account_screen.dart:161-162`; `settings_screen.dart:461`; `main.dart:418` auth gate still commented out |
| **M14** No test for `DemoDataBannerHost` | **Still open** | `grep -rn "DemoDataBannerHost\|demo_data_banner" test/` → **0** |
| **M15** Demo flag flip re-parents the whole app, dropping focus | **Still open** | `demo_data_banner.dart:38-39` — `if (!serving) return child;` … `return Stack(...)`. Type still changes |
| **M17** Hardcoded English on the payment screen | **Still open** | `payment_screen.dart:633` `const Text('Go Back')`, `:642` `'Retry Payment'`, `:651` `'Go Back'`, `:974` `'Got it'` |
| **M18** "NO border" claim is false | **Still open in code; now invisible on screen** | `glass.dart:162-163` unchanged (`glass.dart` absent from the round-3→4 diff). See §3 |
| **M19** Coloured drop shadow reads as non-native | **Still open** | `main_shell.dart:114-118` `context.hc.orange.withValues(alpha: 0.18)`, blur 24, offset (0,8) |
| **M20** `lib/widgets` outside the design gate | **Still open** | `check_design_consistency.sh:17` `SCAN_DIR="lib/screens"` |
| **M22** No haptic on account deletion; `heavyImpact` on a non-error pending state | **Still open** | `payment_screen.dart:297` fires `HapticFeedback.heavyImpact()` on the pending branch |
| **M23** Stale docs contradicting shipped code | **Partly Pass** | `theme.dart:248-251` and `app_colors.dart:66-72` corrected. `glass.dart:22` still documents trailing order `[custom…, cart, search, home]` while `:74-84` builds custom → home → search → cart. `theme.dart:334` still claims "orangeText keeps AA" |

**Net movement, round 3 → 4.** Two genuine closures (typed `PaymentFailure`; the contrast comments,
which are now accurate). One **regression** (the design gate is now internally inconsistent with the
token file it polices — §1). One **correction to the audit record itself**: the overlay pill absorbs
taps, it is not pointer-transparent (§2), and the pairing ratio is 7/46, not 8/46.

**Which pattern does this round fit?** Round 1→2 was *surfaces*; round 2→3 was *half-wires*. Round
3→4 is a third pattern: **documentation caught up with the code while the enforcement did not.**
`9127713` is honest about what is broken — `docs/KNOWN_ISSUES.md:40-41` names the gate problem in
the team's own words — but nothing that a CI run can see changed. The truthful comment and the
false gate now sit in the same repository, and only one of them blocks a commit.

---

## The six questions this round was asked

### §1. The contrast comments were corrected. Are they right, and is the gate now internally inconsistent?

**The corrections are accurate.** Recomputed independently:

| Token | Value | Comment now says | I measure | Verdict |
|---|---|---|---|---|
| `orangeText` (`theme.dart:74`) | `#B86E00` on white | "MEASURED 3.99:1 … FAILS 4.5:1 for body text" (`:70-73`) | **3.986:1** | correct |
| `orangeDark` (`theme.dart:76`) | `#CC6E00` on white | "MEASURED 3.62:1 … (comment claimed 4.5:1)" (`:76-77`) | **3.622:1** | correct |
| `warning` (`theme.dart:101`) | `#E65100` on white | "MEASURED 3.79:1 … clears the 3:1 floor, not 4.5:1" (`:99-100`) | **3.789:1** | correct |
| `orangeStrong` (`theme.dart:110`) | `#9A5C00` on white | "5.38:1" (`:108-109`) | **5.379:1** | correct |

`app_colors.dart:66-72` and `theme.dart:248-251` also now correctly record white-on-orange as an
**owner decision measured at 2.33:1**, with an explicit instruction not to revert it. Per the brief,
that is accepted risk, not a defect, and it is now documented the way an accepted risk should be.
**This is the best documentation work in four rounds. It should not be undersold.**

**And yes — the gate is now internally inconsistent, and that is a regression.**

```
scripts/check_design_consistency.sh:57-58
#    and on orangeLight tints (~2:1). Text must use orangeText (4.6:1) — or
#    onOrange when the text sits ON an orange fill.

scripts/check_design_consistency.sh:70
report "Raw orange as text color is banned (2.3:1 on white) — use context.hc.orangeText, or onOrange on orange fills"
```

The gate's *only* prescribed remedy for orange text is `orangeText` — the token whose own source
file, 40 lines into `theme.dart`, now says in capitals that it **FAILS 4.5:1 for body text**.

Before `9127713` the gate and the token file agreed on a false number. Wrong, but coherent: a
developer reading either got the same (bad) answer. After `9127713` they disagree, and **the one
that fails a build is the wrong one**. A developer who writes orange text, trips the gate, and does
exactly what the failure message tells them to do now ships a documented AA failure — with CI's
approval. That is a worse governance position than round 3, notwithstanding better prose.

Two aggravating specifics:

- **`theme.dart:334` was missed, and it is the one site where the false claim governs real small
  text.** `// Raw orange on orangeLight is ~2:1 — orangeText keeps AA.` on the app-wide `chipTheme`,
  whose label is `fontSize: 12, fontWeight: w500` (`:330-336`). `#B86E00` on `#FFF3E0` measures
  **3.63:1** — a 12px chip label, comfortably body text, failing AA under a comment that says it
  passes. `orangeStrong` on the same fill measures **4.90:1** and would fix it.
- **`orangeStrong` is still used at exactly one site.** `grep -rn orangeStrong lib` → declarations in
  `app_colors.dart:64, 102, 132` and `theme.dart:55, 110`, plus **one** consumer:
  `main_shell.dart:155`. The gate does not mention `orangeStrong` at all (0 hits in the script), so
  the correct token is invisible to the only automation that could promote it. Meanwhile `orangeText`
  has **86** references across `lib/`, including the app-wide `TextButton` foreground
  (`theme.dart:280`).

**Fix, unchanged from rounds 1–3 and now cheaper than ever, because the measurement work is done:**
re-point `orangeText` to `#9A5C00`; or retire `orangeText` to a documented large-text-only role,
re-point `theme.dart:280` and `:335` to `orangeStrong`, and rewrite
`check_design_consistency.sh:57-58` and `:70` to name `orangeStrong` with the measured figure.

**Outcome: Fail (DES-8.04), carried into DES-3.02 and DES-6.02.**

### §2. The overlay pill is unchanged — and it DOES absorb taps. Round 3 was wrong.

**Confirmed unchanged.** `demo_data_banner.dart` does not appear in
`git diff --stat 9a80fe2..9127713 -- lib/`. `:44-49` still hard-positions at
`MediaQuery.of(context).padding.top + kToolbarHeight + 4` — a constant resolved once, above the
Navigator, against a context that knows nothing about the route beneath it.

**Correcting the audit record.** Round 3 §A-2 stated the pill is pointer-transparent and concluded
"users can tap a tab they cannot see." That is **false**, and I retract it on this evidence:

```
/opt/homebrew/share/flutter/packages/flutter/lib/src/rendering/paragraph.dart:796
  bool hitTestSelf(Offset position) => true;
```

The pill's leaves are an `Icon` (`demo_data_banner.dart:112`, which builds a `RichText`) and a `Text`
(`:115-127`). Both render as `RenderParagraph`, and `RenderParagraph.hitTestSelf` returns `true`
unconditionally. `RenderStack` hit-tests children in reverse paint order, so the `Positioned` pill is
tested **before** the route beneath it. Any tap landing inside the pill's glyph boxes terminates
there. `docs/KNOWN_ISSUES.md:27` records the same conclusion from the owner's side ("absorbs touches
and occludes the first content row"). The owner's probe and the SDK source agree.

**The corrected finding is worse for the user, not better.** The pill has **no `onTap`**. So it is
not an overlay you can tap through — it is an **inert tap sink**. The affected controls look present,
are partly hidden, and do nothing when pressed. That is the failure users report as "the app is
broken", not as "something is covering it", and it is materially harder to diagnose from a support
call than a pass-through would be.

Geometry, derived from declared constants (iPhone 14/15/16 `padding.top` ≈ 47, `kToolbarHeight` = 56).
Pill occupies **y ≈ 107 → 138** (7 + 7 vertical padding around a ~17pt row), centred, ~245pt wide on
a 393pt screen:

| Screen | What sits at y 107–138 | Consequence |
|---|---|---|
| `/vitals` (`vitals_screen.dart:154-160`) | `GlassAppBar(bottom: TabBar)` → bar spans 47→149; the **TabBar label band** is y ≈ 103–149 | Covers ~31 of 46pt of the TabBar **and eats taps on the labels**. This is the screen whose own dartdoc (`demo_data_banner.dart:15-17`) names sample data as the case that "actually does harm" |
| `/my-orders` (`services/my_orders_screen.dart`) | same `GlassAppBar(bottom: TabBar)` shape | same |
| **Home** (`home_screen.dart:376-430`) | logo y 53–79 → patient-switcher chip, `ConstrainedBox(minHeight: 44)` at `:409-411`, y ≈ 81–125 → greeting from y ≈ 131 | Covers the chip's lower band and the top edge of the 28/w800 greeting, **and steals roughly the bottom 18pt of the chip's 44pt hit region** — a hit area that `:406-408` deliberately widened to 44pt citing WCAG 2.5.5. A prior accessibility fix is silently undone by the overlay |
| **Services** (`service_catalog_screen.dart:136-141`) | 28/w800 "Book Services" inside `bottom:`, y ≈ 103–147 | Pill sits on the screen's own large title |
| **My Care** / **Billing** | body large title from y = 111 / 119 | Covers 27 / 19 pt of a 28pt title line |
| **More** (`settings_screen.dart:93` bare `ListView`) | 72pt profile row from y ≈ 103 | Clips the avatar |

On Home this is the **default state of the default tab** of a demo-data build.

**Apple's rule, restated.** Transient status floats, occludes, and leaves — the volume HUD, the
AirPods card, "Copied". Persistent status participates in chrome and **displaces**:
`UINavigationItem.prompt` is the exact iOS precedent, a system-laid-out line above the nav bar that
grows the bar for as long as the condition holds. The one persistent iOS overlay — the status-bar
pill for an active call or screen recording — is inside the status bar (occludes nothing),
system-laid-out, and **tappable**. The Housepital condition is persistent for the whole session
(`api.housepital.in` does not resolve), non-dismissible by design, and clinical. Every attribute says
chrome. The implementation chose the transient mechanism **and** made it inert.

**Recommendation (unchanged in direction, sharpened by the tap finding): move it into
`GlassAppBar.bottom:`.**

### The concrete migration

The repo already contains a working instance of exactly this shape — `service_catalog_screen.dart`
puts a 44pt large title above a `TabBar` inside `bottom:` and sizes it correctly. Copy that.

**Step 1 — a `PreferredSizeWidget` that is zero-height when not serving.** New widget in
`lib/widgets/demo_data_banner.dart`:

```dart
class DemoNoticeBar extends StatelessWidget implements PreferredSizeWidget {
  const DemoNoticeBar({super.key, this.bottom});

  /// The screen's own bottom (a TabBar), if any. Stacked below the notice.
  final PreferredSizeWidget? bottom;

  static const double _noticeHeight = 34.0;

  @override
  Size get preferredSize => Size.fromHeight(
        (DemoMode.isServingDemoData.value ? _noticeHeight : 0.0) +
            (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: DemoMode.isServingDemoData,
        builder: (context, serving, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (serving) const SizedBox(height: _noticeHeight, child: _DemoDataPill()),
            if (bottom != null) bottom!,
          ],
        ),
      );
}
```

**Step 2 — teach `GlassAppBar` to wrap it.** `glass.dart:31-53` already sums
`bottom.preferredSize.height` into `preferredSize`, so the Scaffold does the inset arithmetic and
**no screen changes its scroll padding**. That is precisely the property the overlay was built to
obtain, and the slot obtains it without occluding anything. Add one field and one line:

```dart
// glass.dart — GlassAppBar
final bool showDemoNotice;                    // default true

@override
Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (_effectiveBottom?.preferredSize.height ?? 0));

PreferredSizeWidget? get _effectiveBottom =>
    showDemoNotice ? DemoNoticeBar(bottom: bottom) : bottom;
// …and pass `bottom: _effectiveBottom` to the inner AppBar at :86.
```

This is one edit and it covers **all 46** `GlassAppBar` screens, including `/vitals` and
`/my-orders`, whose existing `bottom: TabBar` becomes `DemoNoticeBar`'s child rather than being
covered by a floating pill.

**Step 3 — remove the overlay.** Delete `DemoDataBannerHost` from `main.dart:434`; `builder:` reverts
to returning the `MediaQuery` directly. This also closes M15 for free — there is no longer a widget
whose `runtimeType` flips, so the app is no longer re-parented and keyboard focus is no longer
dropped mid-typing.

**Step 4 — Home is the one gap, and it is H8, not an objection to the pattern.**
`home_screen.dart:103` has no `AppBar`. Either give Home a `GlassAppBar` (which also closes one of
the four header idioms) or insert `const DemoNoticeBar()` as the first child of the `Column` at
`:118`, above `_buildHeader`. The second is three lines and displaces rather than occludes.

**Step 5 — make it interactive** (this is the part the current pill cannot do at all, being inert).
Wrap the pill in an `InkWell` that opens a sheet listing `DemoMode.activeSources` — the data already
exists at `demo_mode.dart:43` and is currently rendered nowhere — with a **Retry**. DES-2.07 requires
that an unavailable-service state say what is saved, queued, blocked, or at risk; today it says none
of those things.

**Step 6 — the regression test that does not exist** (M14, 0 hits in `test/`). One assertion, modelled
on `main_shell_test.dart:220-247`, which does exactly this for the nav pill:

```dart
testWidgets('demo notice displaces, never overlaps, the /vitals TabBar', (t) async {
  DemoMode.markServingDemoData(DemoMode.sourceVitals);
  await t.pumpWidget(app());
  expect(
    t.getRect(find.byType(DemoNoticeBar)).overlaps(t.getRect(find.byType(TabBar))),
    isFalse,
  );
});
```

**Outcome: Fail (DES-4.07, DES-5.01, DES-2.07).**

### §3. `GlassSurface` still draws a border. Is the white hairline visible after the frost change?

**The border is still there.** `glass.dart` does not appear in the round-3→4 diff at all:

```
glass.dart:158-165
child: DecoratedBox(
  decoration: BoxDecoration(
    color: fill,
    borderRadius: borderRadius,
    border: borderRadius != null
        ? Border.all(color: edge, width: 0.5)     // ← white @0.6 light, @0.08 dark
        : Border(top: BorderSide(color: edge, width: 0.5)),
```

`main_shell.dart:122` passes `borderRadius: BorderRadius.circular(32)`, so the nav pill takes the
`Border.all` branch. `main_shell.dart:102` — *"Owner's call: no border — read it as FROST instead"* —
remains **false at the code level**. Round 3's M18 stands.

**But the answer to "visible or lost?" is: lost — and that is the more interesting finding.**

Compositing the light case over the app's near-white pages (`#F8F9FA`/`#FFFFFF`), in paint order:

| Layer | Over a white page | Result |
|---|---|---|
| `GlassSurface` fill: white @ **0.78** (`main_shell.dart:127`) | white over white | `#FFFFFF` |
| `GlassSurface` border: white @ **0.6** (`glass.dart:152`) | white over white | `#FFFFFF` |
| Inner tint: `orangeLight #FFF3E0` @ 0.22 (`main_shell.dart:135`) — a **child** `DecoratedBox`, so it paints *over* the border too | applied to both | fill `#FFFCF8`, border `#FFFCF8` |

Fill and hairline resolve to the **same colour**: contrast ≈ **1.00:1**. The hairline is not merely
subtle — over a white page it is arithmetically indistinguishable, because both layers are white
sources over a white backdrop and both receive the identical tint on top. It becomes faintly visible
only over saturated scrolling content, where the 0.6 border lets ~40% of the backdrop through against
the fill's ~22%.

**So the owner's "white on white is a bit off" complaint was cosmetically resolved by raising the
fill, not by removing the border — and the code and comment now disagree in a way that is primed to
regress.** `glass.dart:129-131` documents the default `opacity = 0.55` with the reasoning *"0.55 lets
scrolling content visibly bleed through the material — frosted glass over a white page is invisible
at higher fills."* That is the correct Liquid Glass instinct, and it is the exact change that would
resurrect the white hairline. Anyone acting on §4's recommendation to make the pill glassier — lower
`opacity` toward 0.6 — will bring back the visible white-on-white edge, and neither
`main_shell.dart:102` ("no border") nor `glass.dart:162` warns them. A wrong comment that is
accidentally right about the current appearance is the worst of the three states.

**Fix:** either pass an explicit `border: Border.none` capability through `GlassSurface` and correct
`main_shell.dart:102`, or — better, and what Apple actually does — make `edge` **adaptive**: a light
specular hairline against dark content and a dark one against light. Apple's Liquid Glass does have
an edge; the correct answer is neither "none" nor "always white".

**Outcome: Warning (DES-3.06) — visual impact currently nil, latent regression documented.**

### §4. Header-idiom count and the `GlassAppBar` / `extendBodyBehindAppBar` pairing

**Pairing: 7 of 46 — not 8.** Round 3's figure was a grep artifact and I am correcting the record.

```
comm -12 <(grep -rl "GlassAppBar("             lib/screens | sort)   # 46
         <(grep -rl "extendBodyBehindAppBar: true" lib/screens | sort)   #  7
→ 7:  assistant_screen · billing_screen · care_calendar_screen · care_team_screen
      my_care_screen · service_detail_screen · delete_account_screen
```

Round 3 grepped `extendBodyBehindAppBar` without `: true`, which also matched
`service_catalog_screen.dart:127` — a **comment** stating why that screen deliberately opts out
("the TabBar + 6 tab bodies need their own under-scroll pass"). That opt-out is *reasoned*, which is
more than the other 38 can say, but it is not compliance. The same 7/46 holds at `9a80fe2`, so the
ratio is genuinely three rounds flat; only the number was wrong for two of them.

Consequence, per DES-4.07: **39 of 46 screens render a glass bar that content stops beneath rather
than glides under.** The app therefore ships two visibly different bar materials, and which one you
get is a per-screen accident.

**Header idioms: still four across five tabs. Confirmed by direct read, unchanged.**

| Tab | Idiom | Evidence |
|---|---|---|
| Home | **No `AppBar` at all**; a 28/w800 greeting inside the scroll view | `home_screen.dart:103` (`Scaffold` → `body:` directly), `:736` |
| My Care | `GlassAppBar` + cross-fading body large title | `my_care_screen.dart:84`, `:153` |
| Billing | same as My Care | `billing_screen.dart:145`, `:185` |
| Services | 28/w800 title inside `GlassAppBar.bottom:` above a `TabBar` | `service_catalog_screen.dart:129-167` |
| More | **Plain bar title only, no large title anywhere** | `settings_screen.dart:88-92` (`title: Text(l.t('settings_title'))`; the `fontSize: 28` at `:121` is the avatar's initials, not a title) |

Apple's large-title pattern makes the title the anchor of a screen. This app has three different
answers to "where is the title" plus one screen with no large title, **and** a floating pill that
lands on whichever answer a given tab chose. The two findings compound: H8 is what makes the
overlay's fixed `kToolbarHeight` offset wrong on every screen simultaneously.

**Outcome: Fail (DES-2.02, DES-4.07).**

### §5. The payment pending state and the per-patient orders behaviour, as user-visible design

#### 5a. Payment pending — the logic defect is closed, the perceptual defect is not

**Closed, and closed properly.** `payment_service.dart` now declares `PaymentFailure {notStarted,
declined, unverified}` with a dartdoc that states the reason in full, and the callback signature is
`void Function(String message, PaymentFailure kind)`. `payment_screen.dart:288` reads
`kind == PaymentFailure.unverified`. Because the *signature* changed, this cannot silently regress —
a future edit that drops the discriminator does not compile. That is the difference between this fix
and the round-2 fixes that were "half-wires": the type system now holds the contract. Round-3 H5 is a
clean **Pass**.

**Not closed: the screen still reads as a failure.** `payment_screen.dart:466-469`:

```dart
color: isSuccess ? context.hc.successLight : context.hc.errorLight,
```

The pending branch renders a warning-coloured `Icons.schedule` (`:475-483`) on a **red-tinted** 120pt
well. The `_pendingVerification` ternary is threaded through the icon (`:475`), its colour (`:480`),
the title text (`:493`) and the title colour (`:501`) — **but not the well**, which is the single
largest coloured element on the screen and the first thing the eye resolves.

So a patient whose money has probably left their account sees a large red circle. At squint distance
and in grayscale the screen reads "Payment Failed" — the exact misreading the state was built to
prevent. Colour here is not merely absent as a differentiator (DES-2.06); it is an *actively wrong*
one, on the highest-consequence screen in the product. **One-line fix:**
`_pendingVerification ? context.hc.warningLight : context.hc.errorLight`.

Three smaller ones, all carried:
- **Hardcoded English on the money screen** — `:633` `'Go Back'`, `:642` `'Retry Payment'`, `:651`
  `'Go Back'`, `:974` `'Got it'`. The i18n contract in CLAUDE.md is unambiguous, and this is the
  screen a Hindi-speaking patient most needs to understand.
- **`HapticFeedback.heavyImpact()` fires for pending** (`:297`). Heavy impact is the error haptic.
  Pending is not an error; the phone tells the patient it is, contradicting the text.
- Button heights 52 (`:616`) and 48 (`:628`) on the same screen.

**Credit where due.** The *content* decisions here are first-rate: no Retry ("paying again would debit
twice for the same bill"), a route to a human via `/help-faq` because `/support` does not exist, and
an honest contrast comment at `:497-499` correctly reasoning that 24pt/w700 is large text so the 3:1
floor applies. The instinct is better than most production payment screens. The presentation layer
just has not caught up with it.

#### 5b. Per-patient orders — the data loss is genuinely fixed; the user-visible behaviour is not

**The destructive bug is really gone.** `orders_provider.dart:249-262` — `clearPatientScopedData()`
no longer calls `_persistAndNotify()`; it drops memory and sets `_patientId = null`. Storage is keyed
`housepital_orders_<patientId>` (`:76-80`), and `setPatient()` (`:86-93`) clears memory then reads the
incoming patient's key. **Nothing is written on a switch**, so neither patient's history can be
overwritten. `SessionScope.install()` (`:59-70`) + `AppProvider.onPatientChanged` (`app_provider.dart:62`)
wire both switch paths. As a data-integrity fix this is correct and I can find no hole in it.

**As user-visible design, a patient switch does not visibly preserve history — for two independent
reasons, both reachable in the build that ships.**

**(i) In a demo build, the per-patient key is never adopted.** `app_provider.dart:149-158`:

```dart
if (_patients.isEmpty) {
  _currentPatient = DemoData.patient;
  _patients = [DemoData.patient];
  DemoMode.markServingDemoData(DemoMode.sourcePatientIdentity);
  notifyListeners();            // ← no _announcePatient(...)
}
```

The only `_announcePatient` on this path is at `:175`, **inside the `try`** that calls
`_apiService.getPatients()`. `api.housepital.in` does not resolve, so that call always throws and
control goes to the `catch` at `:179`. Result: `OrdersProvider._patientId` stays `null`, and
`_ordersKey` evaluates to `'housepital_orders__none'` (`:78`, via `_patientId ?? '_none'`) for the
entire session. Every order the user places lands in the `_none` bucket. **The per-patient keying is
inert in the only build that runs**, until the user manually opens the switcher.

**(ii) When they do switch, their history visibly disappears.** The switcher renders only when
`app.patients.length > 1` (`home_screen.dart:401`), which a user reaches via `/add-patient` →
`AppProvider.addPatient` (`app_provider.dart:245-249`, in-memory, `TODO(persistence)`). Then, in one
session:

1. Patient A places an order → persisted to `housepital_orders__none` (A was never announced).
2. Switch to B → `switchPatient` → `_announcePatient(B.id)` → `setPatient('B')` → reads
   `housepital_orders_B`, empty.
3. Switch back to A → `setPatient(A.id)` → reads `housepital_orders_<A.id>`, **also empty** — A's
   real order sits under `_none` and that key is never read again once any patient is announced.

A's orders are **not destroyed** (a cold start constructs `OrdersProvider()` with `_patientId == null`,
`:82-84`, and reads `_none` again, so they return). The round-3 blocker is genuinely closed. But what
the patient *experiences* in that session is: "I switched to my mother's profile and back, and my
order history is gone." Correct storage, wrong perceived behaviour — a DES-4.06 / DES-2.04 failure
(state not preserved across a context change) rather than a data-loss one.

**(iii) And the empty state lies.** `orders_provider.dart:235-238`:

```dart
if (_orders.isEmpty) {
  _orders = DemoData.orders;
  DemoMode.markServingDemoData(DemoMode.sourceOrders);
}
```

Any patient whose key is empty — which is every newly added patient, and patient A in step 3 above —
renders **the same fabricated order history under a different name**. So the visible answer to "did my
switch preserve history?" is "every patient has identical orders", which is more misleading than an
empty state would be. The only signal that this is fabricated is the demo pill — which, per §2, is
sitting on the screen title and eating taps.

**Fix (design, not storage):** announce on the demo-seed path too (`app_provider.dart:157`), and gate
the `DemoData.orders` fallback behind an explicit demo flag so a genuinely empty patient renders a
real empty state ("No orders yet") rather than someone else's.

**Outcome: Fail (DES-6.05, DES-2.07); DES-4.06 Fail.**

---

## Control results

| Control | Outcome | Evidence | Impact / mitigation (Warnings and Fails) |
|---|---|---|---|
| DES-1.01 HIG treated as external guidance | **Pass** | `glass.dart:9-15` explicitly frames the material as *"a Flutter approximation"* of a system-rendered one; CLAUDE.md cites Apple idioms without claiming to supersede them | — |
| DES-1.02 House tokens labelled as house decisions | **Pass** | Improved this round. `app_colors.dart:66-72`, `theme.dart:76-81`, `:248-251` label white-on-orange as an owner decision with the date (2026-06-11) and the measured 2.33:1 | — |
| DES-1.03 Platform behavior wins over house rule | **Warning** | One device class only; the pill's geometry (`main_shell.dart:89-96`) is fixed at all widths | Impact: iPad/regular-width users get a stretched phone layout. Mitigation: iPhone-only launch. Owner: OWNER-TBD. Due: before any iPad listing |
| DES-1.04 Exceptions record rationale, platforms, a11y impact, owner, review date, validation | **Warning** | Rationale + owner + date present for onOrange (`theme.dart:76-81`) and the pill (`main_shell.dart:77-88`); `docs/KNOWN_ISSUES.md:44-47` lists three accepted risks | Impact: no **review date** and no **validation evidence** on any exception; the newly-documented `orangeText` failure is a code comment, not a recorded exception. Owner: OWNER-TBD. Due: before submission |
| DES-1.05 Device/orientation/window/input/appearance/a11y matrix maintained | **Fail** | No such matrix in the repo. `overflow_smoke_test.dart` covers 320/375/414 **at scale 1 only**; `main.dart:426-429` clamps textScaler 0.85–1.4 with no test at the ceiling; no orientation or input-method coverage. Unverified, not N/A | Blocks release: the supported-configuration set is undefined, so "tested" has no denominator |
| DES-2.01 Clear primary purpose + obvious next action | **Warning** | Screens are purposeful, but on 4 of 5 tabs the default state has the sample-data pill on the title (§2) | Impact: 3-second comprehension degraded on the default tab. Fix: §2 migration. Owner: OWNER-TBD |
| DES-2.02 Predictable across equivalent contexts | **Fail** | 4 header idioms / 5 tabs (§4); 7 of 46 glass screens paired (§4); 3 destructive-confirmation idioms (`common_widgets.dart:520`, `delete_account_screen.dart:174`, and 2 unconfirmed sites) | Blocks release: equivalent screens behave visibly differently with no purposeful explanation |
| DES-2.03 Hierarchy reflects task importance | **Warning** | Home leads with a promo banner carousel (`home_screen.dart:127` → `_buildHeader`) above the greeting and the care team; SOS is inside the scroll view (`:111`) | Impact: the emergency action can scroll off a clinical home screen. Owner: OWNER-TBD. Due: pre-launch |
| DES-2.04 Prevent errors, preserve work, explain consequences, recovery | **Warning** | Payment pending is exemplary (§5a); delete-account confirmation depth exceeds the bar. But `patient_profile_screen.dart:148, :164` and `care_calendar_screen.dart:1311-1313` delete with no confirmation and no undo; `grep -rn PopScope lib` → **1** | Impact: three silent data losses. Fix: route through `confirmDestructiveAction` **after** fixing its contrast (DES-6.02) |
| DES-2.05 Progressive disclosure without concealing costs | **Pass** | Manpower prices shown and bookable per the owner rule; `OrdersProvider.isQuotePending` prevents ₹0 renders | — |
| DES-2.06 Understandable without colour alone | **Fail** | `payment_screen.dart:466-469` — pending renders on `errorLight`. Colour is an actively wrong differentiator on the money screen (§5a) | Blocks release: one-line fix, highest-consequence screen |
| DES-2.07 Offline / unavailable-service behaviour matches promise | **Fail** | The app's permanent state is demo. Signal = the inert pill (§2). `DemoMode.activeSources` (`demo_mode.dart:43`) is rendered nowhere; `orders_provider.dart:235-238` presents fabricated history as content (§5b) | Blocks release: nothing states what is saved, queued, blocked, or at risk |
| DES-2.08 No deceptive patterns | **Pass** | No confirm-shaming, false urgency, or hidden costs found. Pending deliberately withholds a Retry that would double-debit (`payment_screen.dart:613-615`) | — |
| DES-3.01 Semantic text styles / scalable tokens; Dynamic Type, Bold Text, expansion | **Fail** | No semantic text-style layer: raw `fontSize` literals throughout, gate histogram shows no 17pt body and no 34pt large title. Dynamic Type **clamped at 1.4×** (`main.dart:426-429`) below the platform range, untested at the ceiling. No `boldText` handling (`grep -rn boldText lib` → 0) | Blocks release: a house cap on Dynamic Type with no evidence it was needed |
| DES-3.02 Semantic dynamic roles + paired fg/bg tokens | **Warning** | `context.hc.*` is a real light/dark semantic layer, gate-enforced in `lib/screens`. But `onError` reaches 3 of 17 sites; `common_widgets.dart:522` hardcodes `Colors.white` on `hc.error`; `check_design_consistency.sh:17` scans `lib/screens` only | Impact: the pairing exists but is not the runtime strategy everywhere. Fix: extend `SCAN_DIR` to `lib/widgets` |
| DES-3.03 Light/dark/increased-contrast/reduced-transparency/differentiate-without-colour/tinted | **Fail** | Light + dark defined and guarded (`test/widgets/dark_mode_test.dart`). `grep -rn "accessibleNavigation\|highContrast\|boldText\|invertColors" lib/` → **0**. Increased contrast, reduced transparency and differentiate-without-colour are undefined and untested | Blocks release: two stacked `BackdropFilter`s with no Reduce Transparency path is a direct DES-3.06 interaction |
| DES-3.04 Spacing tokens form a flexible scale | **Warning** | No spacing or radius constants anywhere; `lib/config/constants.dart` is API/business only; 19 distinct `circular(n)` values | Impact: drift, not breakage. Owner: OWNER-TBD |
| DES-3.05 Safe areas, Dynamic Island, keyboards, split view, Stage Manager, resizable windows | **Fail** | Nav pill safe-area handling is correct **and tested** (`main_shell_test.dart:220-247`) — real credit. But `demo_data_banner.dart:45` hard-positions on a constant matching no screen (§2), and there is no split-view / Stage Manager / resizable-window handling | Blocks release via the overlay; multitasking is a scope decision needing DES-1.05 |
| DES-3.06 Standard materials / Liquid Glass in intended layers; responsive to a11y | **Fail** | Layering discipline is genuinely correct — `glass.dart:12-15` restricts glass to chrome and that holds. But `opacity: 0.78` (nav) and `0.92` (pill) mean the blur does almost no visible work; the border is drawn and invisible (§3); no Reduce Transparency response; `KNOWN_ISSUES.md:35` records four `BackdropFilter` surfaces per frame | Blocks release on the a11y-response clause of the control |
| DES-3.07 App icons: current tooling + appearance variants; system applies masks | **Fail** | `grep -c appearances .../AppIcon.appiconset/Contents.json` → **0**; last touched `820060b` (round 2). `LaunchScreen.storyboard:22` hardcoded white → white flash into a true-black app (`theme.dart:16`) on every dark-mode cold start | Blocks release. Third round untouched. Needs the designer's vector |
| DES-3.08 SF Symbols / platform-standard icons | **Warning** | Material icons throughout (`Icons.*`) on an iOS-first product; no custom-symbol optical-weight spec | Impact: recognisable but not platform-native. Deliberate Flutter trade-off — should be recorded as a DES-1.04 exception. Owner: OWNER-TBD |
| DES-3.09 Images: rights, scale, appearance variants, alternatives | **Warning** | Logo has light/dark variants + `semanticLabel` (`home_screen.dart:389-400`) — correct. But 40.3 MiB unreferenced assets ship (`KNOWN_ISSUES.md:34`); ~31 catalog items on placeholder icons | Impact: binary size + inconsistent catalog. Fix: pure delete |
| DES-4.01 Navigation scales compact ↔ regular | **Fail** | Five-tab pill at every width; no sidebar or split view; widest tested width 414 | Blocks release only if iPad is in scope — which DES-1.05 does not say. Resolve the matrix first |
| DES-4.02 Standard components where they satisfy the task | **Warning** | `BottomNavigationBar` inside a custom pill is a reasoned custom control (DES-6.08). But `service_booking_screen.dart:325-336` uses a raw `AppBar` with a hardcoded `Icons.arrow_back`, bypassing `GlassAppBar` | Impact: the booking wizard is visibly not part of the app. Owner: OWNER-TBD |
| DES-4.03 Location, back, dismissal, deep-link, restoration predictable and tested | **Fail** | `service_booking_screen.dart:325-336` overloads back with step-decrement, no `PopScope` (1 in the whole tree); `delete_account_screen.dart:161-162` `popUntil(isFirst)` and `settings_screen.dart:461` `nav.pop()` land the user back **inside** the authenticated app after deletion/logout; `main.dart:418` auth gate commented out | Blocks release: "your account is deleted" → the Home tab of a working app |
| DES-4.04 Modal reserved for focused tasks; least disruptive form | **Warning** | 25 `showModalBottomSheet` sites with drifting geometry; 59 SnackBars + 8 `showTopToast` | Impact: inconsistent, not broken. Owner: OWNER-TBD |
| DES-4.05 Actions placed consistently; discoverable across input methods | **Warning** | The `GlassAppBar` trailing contract is real and largely honoured. But `glass.dart:22` documents `[custom…, cart, search, home]` while `:74-84` builds custom → home → search → cart — the spec contradicts its own implementation | Fix: correct the dartdoc (free) |
| DES-4.06 Resizable/multiwindow preserve content, focus, selection, unfinished work | **Fail** | `demo_data_banner.dart:38-39` changes the returned widget's `runtimeType` on flag flip, re-parenting the Navigator subtree and recreating the unkeyed `FocusScope` — keyboard focus drops mid-typing. Plus §5b: a patient round-trip visibly loses order history | Blocks release. Free fix: `Stack(children: [child, if (serving) Positioned(…)])`, or it disappears entirely under the §2 migration |
| DES-4.07 Navigation and content remain distinct under glass | **Fail** | The pill is chrome painted on content and absorbing its taps (§2); 39 of 46 glass screens do not pair `extendBodyBehindAppBar`, so content stops at an opaque edge instead of gliding under (§4) | **Primary release blocker.** Fix: §2 Steps 1–6 |
| DES-5.01 Touch targets + spacing; hit area safe | **Fail** | The overlay absorbs taps (`paragraph.dart:796`) over the patient-switcher chip's deliberately-widened 44pt region (`home_screen.dart:406-411`) and the `/vitals` TabBar labels (§2) | Blocks release: an inert sink over live controls, and a prior WCAG 2.5.5 fix silently undone |
| DES-5.02 Keyboard/pointer/trackpad/Pencil/voice/switch/gaze | **Fail** | No keyboard shortcuts, focus traversal, or pointer affordances found; not tested. Hardware keyboards and pointers are available on the target platform, so this is not N/A | Blocks release under DES-9.04 unless the DES-1.05 matrix formally scopes them out |
| DES-5.03 Standard gestures retain meaning; custom gestures never the only path | **Pass** | No custom gesture recognisers replacing a sole path to an action | — |
| DES-5.04 Drag/motion/long-press/swipe/hover have accessible alternatives | **Warning** | No hover states; swipe actions were not exhaustively traced. Stated plainly: partly unverified | Impact: unknown. Fix: enumerate during the DES-9.01 task inventory |
| DES-5.05 Focus appearance and order explicit | **Fail** | No `FocusTraversalGroup`/`FocusNode` ordering work; the overlay drops focus (DES-4.06); the pill mounts once above the Navigator so it is last in traversal and does not re-announce on push (`demo_data_banner.dart:74-84`) | Blocks release for Switch Control / keyboard users |
| DES-5.06 Timely visual feedback; haptics enhance, not carry, meaning | **Warning** | `HousepitalCard` press-scale is consistent app-wide. But `payment_screen.dart:297` fires `heavyImpact` for **pending**, contradicting the text; `delete_account_screen.dart` has **0** `HapticFeedback` on the destructive commit | Impact: haptics carry the wrong meaning on the money screen. Fix: two lines |
| DES-5.07 Motion respects Reduce Motion; timing tested in context | **Pass** | `disableAnimations` gated in 11 files, including `payment_screen.dart:307-315` (`_playResultAnimations`) and `care_pulse_ring.dart:84`. Genuinely well done | — |
| DES-6.01 Components document purpose, anatomy, variants, states, semantics, platform differences | **Warning** | `glass.dart:9-30`, `demo_data_banner.dart:9-27`, `orders_provider.dart:66-80` carry unusually good contract dartdoc. But no component catalogue exists, and `glass.dart:22` is factually wrong about its own build order | Impact: docs are strong but unverified against code. Fix: a lint or test asserting the trailing order |
| DES-6.02 Buttons: semantic roles, scarce primary emphasis, destructive styling | **Fail** | `common_widgets.dart:520-523` — `backgroundColor: context.hc.error, foregroundColor: Colors.white` = **3.49:1** in dark, across **14** `confirmDestructiveAction` call sites; `settings_screen.dart:463-465` (Logout) sets no foreground and inherits white | Blocks release: every destructive confirm in the app fails AA in dark mode. Invisible to the gate (`SCAN_DIR="lib/screens"`) |
| DES-6.03 Forms: labels, purpose, guidance, validation timing, error association, autofill | **Warning** | `delete_account_screen.dart:279-283` uses `labelText` with a comment explaining that a hint alone leaves no accessible name — exemplary. Elsewhere unverified; `:277`'s local `OutlineInputBorder` contradicts the app `InputDecorationTheme` | Impact: partly unverified. Owner: OWNER-TBD |
| DES-6.04 Selection controls expose name, role, value, state | **Warning** | Not systematically verified; no counter-example found | Stated as unverified, not N/A |
| DES-6.05 Lists/cards/charts define loading, empty, error, offline, stale, partial, success | **Fail** | `notifications_screen.dart:47` and `transaction_log_screen.dart:60` `showEmptyOnError: true` render errors as empty states. The **stale** state renders as real content (`orders_provider.dart:235-238`, §5b) | Blocks release: a failed fetch and "you have nothing" are indistinguishable, on a clinical app |
| DES-6.06 Destructive actions communicate scope and reversibility | **Fail** | `patient_profile_screen.dart:148` bare `_emergencyContacts.removeAt(index)`, `:164` same for conditions, `care_calendar_screen.dart:1311-1313` `RemindersProvider().delete(r.id)` — all unconfirmed, all a few blocks from `patient_profile_screen.dart:230`'s correct `confirmDestructiveAction` | Blocks release: emergency-contact deletion with no confirm and no undo |
| DES-6.07 Long content, localization, largest text, small/large windows, reduced motion, high contrast | **Fail** | Hardcoded English at `payment_screen.dart:633, 642, 651, 974`; largest text clamped at 1.4× and untested; high contrast undefined (DES-3.03) | Blocks release: the payment screen is not localized |
| DES-6.08 Custom controls only when standard cannot; equivalent behaviour/a11y/focus/testing | **Warning** | The nav pill is the model answer: custom, justified in-code (`main_shell.dart:77-88`), and **tested** by six real assertions (`main_shell_test.dart:189-296`). The demo overlay is the counter-example: custom, unjustified against an existing standard slot, **0** tests | Impact: the same author, in the same batch, produced both — and the defects landed precisely where the tests were not. Fix: §2 Step 6 |
| DES-7.01 First launch explains value before optional data/permissions | **Warning** | `main.dart:419` `home: const SplashScreen()` with the auth-gated `home:` commented out at `:418`, so the shipping first-launch path is not the designed one. Partly unverified | Owner: OWNER-TBD. Due: with the auth gate |
| DES-7.02 Permission requests in context with a denied-state path | **Warning** | Not systematically traced. Stated as unverified | Fix: enumerate during DES-9.01 |
| DES-7.03 Settings: conventions, safe defaults, reversible, account/privacy controls | **Warning** | Account deletion is discoverable and exemplary in its confirmation depth. But it lands the user back inside the app (DES-4.03), and `KNOWN_ISSUES.md:20-21` records that no deletion request reaches any server | Impact: a privacy control that does not do what it says. Blocks release under a different family; Warning here |
| DES-7.04 Search, sharing, undo/redo, copy/paste, document handling, printing, feedback | **Warning** | Universal search and on-device PDF export/print exist (`invoice_pdf_service.dart`, `handover_report_service.dart`). **No undo anywhere**, which is what makes DES-6.06 bite | Fix: undo would downgrade three Fails |
| DES-7.05 Notifications/widgets expose accurate, privacy-safe state | **Warning** | Improved this round: `session_scope.dart:96-104` now calls `MedicationReminderService().cancelAllReminders()` on a patient switch, closing a real lock-screen PHI leak (patient A's drug name firing after the phone changes hands). Deep-link correctness from a notification is unverified | Credit the fix; the remaining gap is unverified, not N/A |
| DES-7.06 Purchases show price, period, renewal, trial, restore, cancellation before commitment | **Warning** | Prices, line items and totals are shown before payment. Monthly manpower packages (₹18k–90k/mo) do not surface renewal or cancellation terms | Impact: recurring-commitment terms absent. Owner: OWNER-TBD. Due: pre-launch |
| DES-7.07 Help, support, privacy, version, diagnostics, export, deletion findable | **Pass** | `/help-faq` carries real numbers via `AppConstants.supportPhone` (placeholder numbers removed in `13e3656`); delete-account and PDF export are reachable from Settings | — |
| DES-8.01 Design files: components, variants, tokens, documented source of truth | **BLOCKED-OWNER** | No design files in the repo; I cannot see Figma or any design source | Needs: the design source-of-truth link |
| DES-8.02 Every common journey includes normal/loading/empty/error/offline/permission/destructive/recovery | **Fail** | No journey inventory exists; and the states that do exist are wrong (DES-6.05) or absent (DES-6.06) | Blocks release. Depends on DES-9.01 |
| DES-8.03 Specs identify native components/APIs, content behaviour, house tokens, exceptions | **Warning** | CLAUDE.md is an unusually strong implementation-side spec and does label house tokens and owner exceptions with dates. No design-side spec | Impact: one-sided handoff. Owner: OWNER-TBD |
| DES-8.04 Design and implementation tokens synchronized or compared; drift detected before release | **Fail — REGRESSED this round** | `check_design_consistency.sh:58, 70` enforce `orangeText` citing 4.6:1; `theme.dart:70-73` documents the same token as 3.99:1 and failing body text; `theme.dart:334` still claims it "keeps AA" on a 12px chip label measuring **3.63:1** (§1) | **Blocks release.** The sole drift detector now *enforces the drift*: following its failure message ships a documented AA failure with CI approval |
| DES-8.05 Handoff includes interaction, animation purpose, focus order, a11y labels, localization, analytics | **Warning** | Animation purpose and localization behaviour are documented in CLAUDE.md and in-code. Focus order and analytics are absent | Impact: assistive-tech handoff incomplete. Owner: OWNER-TBD |
| DES-8.06 Design QA compares the release artifact on real devices | **BLOCKED-OWNER** | No device-QA record in the repo; I audited source (MASTER-4.04) | Needs: a device pass on a TestFlight build |
| DES-9.01 Common-task inventory and device/input matrix complete | **Fail** | Neither artifact exists (see DES-1.05). Unverified, not N/A | Blocks release: nothing defines what "complete for this release" means |
| DES-9.02 Critical journeys pass hierarchy, comprehension, error-prevention, recovery, a11y, localization, platform-authenticity | **Fail** | Payment: hardcoded English + red-coded pending (§5a). Patient switch: visibly loses history (§5b). Every tab: the pill on the title (§2) | Blocks release: the two highest-consequence journeys both fail |
| DES-9.03 Standard components and SDK behaviour evaluated before approving custom | **Warning** | Done and recorded for the nav pill, including the round-5 reversal history (`main_shell.dart:77-88`). **Not done for the overlay**: `GlassAppBar.bottom:` already exists, already sizes via `preferredSize` (`glass.dart:52-53`), and is already used for this exact shape at `service_catalog_screen.dart:132-167` | Impact: the standard component was in the repo and was not evaluated. Fix: §2 |
| DES-9.04 Light/dark + a11y appearances, largest text, orientations, multitasking, keyboard/pointer verified | **Fail** | Dark mode is verified (`dark_mode_test.dart`). Increased contrast, reduced transparency, 1.4× text, orientation, multitasking, keyboard and pointer are **not** — unverified, not N/A | Blocks release |
| DES-9.05 All loading, empty, error, offline, permission, purchase, destructive, support states designed and implemented | **Fail** | Errors as empty states (DES-6.05); stale as real content (§5b); three unconfirmed destructives (DES-6.06) | Blocks release |
| DES-9.06 Open design risks have evidence, severity, owner, due date, explicit acceptance | **Fail** | `docs/KNOWN_ISSUES.md:7-47` is genuinely good — it records evidence and severity, and `:40-41` names the gate inconsistency in the team's own words. But **no owner and no due date on any item**, and the three round-3 blockers carry into round 4 with no recorded acceptance by a named authority | Blocks release: the suite requires impact, ticket, owner, due date, mitigation **and** approver. Only the first two exist |

---

## Scorecard

**Pass 8 · Warning 24 · Fail 29 · N/A 0 · BLOCKED-OWNER 2** (63 controls)

| Family | Pass | Warning | Fail | BLOCKED-OWNER |
|---|---|---|---|---|
| DES-1 Authority & scope (5) | 2 | 2 | 1 | 0 |
| DES-2 Human-centered principles (8) | 2 | 3 | 3 | 0 |
| DES-3 Adaptive visual foundations (9) | 0 | 4 | 5 | 0 |
| DES-4 Navigation & modality (7) | 0 | 3 | 4 | 0 |
| DES-5 Input & interaction (7) | 2 | 2 | 3 | 0 |
| DES-6 Components & state contracts (8) | 0 | 4 | 4 | 0 |
| DES-7 System experiences (7) | 1 | 6 | 0 | 0 |
| DES-8 Artifacts & handoff (6) | 0 | 2 | 2 | 2 |
| DES-9 Design review gate (6) | 0 | 1 | 5 | 0 |

*Not comparable to round 3's totals: that report scored an 83-row v1.0 checklist; this scores the
63 v2.0 DES controls. The comparable figures are in Prior-round status, which is finding-by-finding.*

---

## Release blockers (every Fail)

Ordered by consequence. **1–4 are the ones that must not survive a fifth round.**

1. **DES-8.04 — the design gate enforces a documented AA failure (REGRESSED this round).**
   `check_design_consistency.sh:58, 70` mandate `orangeText` citing 4.6:1; `theme.dart:70-73`
   documents the same token as 3.99:1 and failing body text; `theme.dart:334` still asserts it
   "keeps AA" on a 12px chip label that measures **3.63:1**. The correction pass fixed 5 of 6 sites
   and left the enforcing one. **Fix:** re-point `orangeText` to `#9A5C00`, or retire it to a
   large-text-only role, re-point `theme.dart:280`/`:335` to `orangeStrong`, and rewrite the gate's
   rule and failure message. ~30 minutes, and all the measurement is already done.

2. **DES-4.07 / DES-5.01 / DES-2.07 — the sample-data notice occludes titles and absorbs taps.**
   `demo_data_banner.dart:44-49`, unchanged for two rounds. Confirmed a tap sink via
   `paragraph.dart:796` (round 3's "pointer-transparent" is retracted). It is an inert overlay over
   the `/vitals` TabBar labels and over Home's patient-switcher chip. **Fix:** the six-step
   `GlassAppBar.bottom:` migration in §2 — the slot already sizes itself, so no screen changes its
   scroll padding, and the same shape is already shipping at `service_catalog_screen.dart:132-167`.

3. **DES-3.07 — the app icon and launch screen.** 0 `appearances`; untouched since `820060b`.
   `LaunchScreen.storyboard:22` hardcoded white flashes into a true-black app on every dark cold
   start. **Third consecutive round untouched.** Needs the designer's vector.

4. **DES-6.02 — every destructive confirm fails AA in dark mode.** `common_widgets.dart:520-523`,
   **14** call sites, plus `settings_screen.dart:463-465` with no foreground at all. Invisible to the
   gate because `SCAN_DIR="lib/screens"` (`check_design_consistency.sh:17`). **Fix the helper before
   consolidating anything into it** — consolidating `delete_account_screen`'s correct 4.62:1 dialog
   into it today would replace a right answer with a wrong one.

5. **DES-2.06 — the payment pending state is colour-coded as a failure.** `payment_screen.dart:466-469`.
   One line: `_pendingVerification ? context.hc.warningLight : context.hc.errorLight`.

6. **DES-6.07 — hardcoded English on the payment screen.** `:633, 642, 651, 974`.

7. **DES-6.06 — three unconfirmed destructive actions.** `patient_profile_screen.dart:148, :164`;
   `care_calendar_screen.dart:1311-1313`.

8. **DES-6.05 / DES-9.05 — errors rendered as empty states, and stale data rendered as content.**
   `notifications_screen.dart:47`, `transaction_log_screen.dart:60`, `orders_provider.dart:235-238`.

9. **DES-4.03 — deletion and logout land the user back inside the authenticated app.**
   `delete_account_screen.dart:161-162`, `settings_screen.dart:461`, `main.dart:418`.

10. **DES-4.06 — a patient switch visibly loses order history**, and the demo-flag flip drops keyboard
    focus. `app_provider.dart:149-158` (no announce on the demo-seed path), `orders_provider.dart:235-238`,
    `demo_data_banner.dart:38-39`. The *data* is safe; the *experience* is not.

11. **DES-2.02 — four header idioms across five tabs; 7 of 46 glass screens paired.**

12. **DES-3.01 / DES-3.03 / DES-9.04 — no semantic type layer; Dynamic Type clamped at 1.4× untested;
    increased contrast, reduced transparency and Bold Text undefined** (`grep` → 0 hits).

13. **DES-1.05 / DES-9.01 / DES-8.02 — no supported-configuration matrix and no journey inventory**,
    so "verified" has no denominator. Fixing this reframes 4.01, 5.02 and 9.04.

14. **DES-3.05 / DES-3.06 — safe-area and material controls**, both failing through the overlay and
    the absent Reduce Transparency path.

15. **DES-5.02 / DES-5.05 — keyboard, pointer and focus order absent and untested.**

16. **DES-9.02 / DES-9.06 — the two critical journeys fail review; open risks carry no owner, due
    date, or recorded acceptance.**

---

## Warnings requiring risk acceptance

Every Warning above carries an impact line. These need a named approver before ship, per the suite's
Warning rule (impact, evidence, ticket, owner, due date, mitigation, approver):

| # | Warning | Impact | Proposed owner / due |
|---|---|---|---|
| W1 | **Accepted risks are recorded without review dates or validation evidence** (DES-1.04). `KNOWN_ISSUES.md:44-47` names three owner decisions correctly — but "accepted" with no approver signature is not acceptance under v2.0 | The three owner decisions (white-on-orange 2.33:1, manpower pricing, the pill nav) are **correct as decisions** and must not be re-litigated. They need a signature line, not a re-argument | OWNER (product) / before submission |
| W2 | `GlassSurface` draws a border the comment says was removed (§3) | Currently invisible (1.00:1 against its own fill). **Latent:** lowering `opacity` toward `glass.dart`'s documented 0.55 default resurrects the white-on-white hairline the owner complained about, with no warning in code | OWNER-TBD / with any glass tuning |
| W3 | Coloured drop shadow + 0.78 fill make the pill read as a card, not system chrome (`main_shell.dart:114-118`, `:127`) | Cosmetic; the pill is otherwise the best-built chrome in the app | OWNER (design) / post-launch |
| W4 | Material icons rather than SF Symbols on an iOS-first product (DES-3.08) | Deliberate Flutter trade-off; should be a recorded DES-1.04 exception rather than an unstated default | OWNER-TBD / pre-submission |
| W5 | 40.3 MiB unreferenced assets (DES-3.09) | Binary size. Pure delete | OWNER-TBD / pre-submission |
| W6 | No undo anywhere (DES-7.04) | This is what makes DES-6.06 a blocker rather than an annoyance | OWNER-TBD / pre-launch |
| W7 | `heavyImpact` on a non-error pending state; 0 haptics on account deletion (DES-5.06) | Haptics carry the wrong meaning on the money screen. Two lines | OWNER-TBD / with blocker 5 |
| W8 | Monthly package renewal/cancellation terms not surfaced (DES-7.06) | ₹18k–90k/mo commitments without stated terms | OWNER (product) / pre-launch |
| W9 | Single device class; no iPad/regular-width story (DES-1.03, DES-4.01) | Scope decision, not a defect — but it must be *written down* in the DES-1.05 matrix, which would convert two Fails to N/A with rationale | OWNER (product) / before the matrix |

---

## BLOCKED-OWNER — needs access I do not have

| Item | Control | What I would need |
|---|---|---|
| Design source of truth (components, variants, tokens, naming) | DES-8.01 | The Figma/design file link. Nothing in the repo indicates one exists |
| Design QA against the release artifact on real devices | DES-8.06, DES-9.04 | A TestFlight build + a device pass. MASTER-4.04 requires artifact evidence; I audited source |
| Exact pixel overlap of the pill against each screen's first content row | DES-4.07 evidence | A simulator capture with `DemoMode.isServingDemoData == true`, or the widget test in §2 Step 6. The **mechanism** is certain (constants + SDK hit-test source); the pixel figures depend on device inset and rendered text metrics |
| Whether the frosted pill reads as glass or as a card on a real device | DES-3.06 | A device capture while scrolling colourful content under it. `sigma: 36 / opacity: 0.78` is measurable from source; how much backdrop survives a 78% fill is a rendering judgement |
| Whether the icon passes App Review 2.3.8 | DES-3.07 | A TestFlight upload. Source proves 0 `appearances`; only Apple decides |
| VoiceOver traversal order with the overlay present | DES-5.05 | A device VoiceOver pass. Source proves the pill is the last child of the top-level `Stack`; it does not prove where the reader lands |
| "3-second" / squint / grayscale comprehension with real users | DES-9.02 | The checklist defines these as human tests; my grades are structural proxies |
| Dynamic Type at 1.4× with the overlay up | DES-3.01, DES-6.07 | The pill's height grows with text scale while its `top` is a constant, so at 1.4× it extends further into content. `overflow_smoke_test.dart` runs at scale 1 only |

---

## Limitations of this audit

1. **Source review only.** Per MASTER-4.04, evidence should come from the release artifact in a
   production-like environment. I read source at `9127713`. No build, no simulator, no device, no
   TestFlight. Everything above is derived from code, declared constants, and the Flutter SDK.
2. **I did not run the test suite**, per the brief (concurrent agents). Central results cited as
   given: `flutter analyze` clean, design gate passes, 1,819 tests across 101 files. Test-quality
   findings come from reading test **sources**.
3. **Geometry is derived, not measured.** The pill-overlap table uses `padding.top` ≈ 47 (iPhone
   14/15/16), `kToolbarHeight` = 56, `largeTitleHeight` = 44, `TabBar` ≈ 46. The *mechanism* —
   a constant offset against per-screen content origins — is certain; the pixel numbers are not.
4. **Contrast is computed, not measured on a display.** WCAG 2.x relative luminance, validated
   against `#767676`/white = 4.54 and black/white = 21.00. Composited values (the pill fill, the
   border) assume the app's own near-white page colours.
5. **Some controls are marked Warning with "unverified" stated plainly** — DES-5.04, DES-6.03,
   DES-6.04, DES-7.02 — rather than graded N/A. Not tested is not N/A.
6. **I corrected two round-3 assertions** (the pill's pointer transparency; the 8/46 pairing count).
   Both corrections are backed by primary evidence cited inline. Round-3 findings I could not
   independently re-derive are marked as carried, not re-asserted.
7. **Owner decisions were measured and reported, never graded Fail** — white on orange (2.33:1),
   manpower pricing, and the floating glass pill. Where they interact with a control I graded the
   *surrounding* implementation, not the decision.

---

*Read-only audit. No files under `lib/`, `test/`, `scripts/`, `ios/`, or `docs/audits/round3/` were
modified. The only file written is this report.*
