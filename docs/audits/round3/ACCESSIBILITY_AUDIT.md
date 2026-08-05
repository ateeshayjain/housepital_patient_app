# Accessibility Checklist (App-Agnostic) — Audit **round 3** vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Method:** read-only. `rg`/`grep`/`Read`, brace-matched AST-ish counting in Python, and WCAG 2.1
relative-luminance computation in Python over sRGB source-over compositing. No `flutter test` /
`build` / `clean` / `analyze` run (per the brief). Central results cited: `flutter analyze` clean,
design gate passes, 1,813 tests pass. Only this file was written.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **B1** White-on-orange 2.33:1 across all chrome | ❌ (owner override) | **Partial — materially reduced** | The nav is no longer an orange fill, so the two worst instances are gone. Remaining: `lib/config/theme.dart:228-241`/`:413-426` (every primary `ElevatedButton`), `:160`/`:340` (`onPrimary`), `lib/screens/home/home_screen.dart:822`,`:1871`, `lib/screens/care_team/care_team_screen.dart:287`, `lib/screens/chat/chat_screen.dart:337` |
| **B1b** Unselected nav labels 1.82:1 | ❌ | **✅ FIXED** | `lib/screens/main_shell.dart:144` — `unselectedItemColor: context.hc.grey`. Measured on the composited pill: **10.62:1** light / **7.95:1** dark. Was `onOrange @70%` = 1.82:1 |
| **B2** Zero contrast assertions in `test/` | ❌ | **Unchanged** | `grep -rn "contrast\|computeLuminance\|luminance" test/` → **0** |
| **B3** Dynamic Type clamped at 1.4×, untested | ❌ | **Unchanged** | `lib/main.dart:426-429` still `maxScaleFactor: 1.4`; `grep -rl "extScaler" test/` → **no files** |
| **B4** 17 of 54 icon buttons unlabelled | ❌ | **Unchanged — exact** | Independent brace-matched re-count below: **54 total / 37 labelled / 17 unlabelled**, and the 17 are line-for-line the same 17 |
| **B5** Family-member removal swipe-only | ❌ | **Unchanged** | `lib/screens/settings/family_members_screen.dart:319`,`:335-336`; `_buildMemberCard` (`:346`) is still `HousepitalCard > Row > [CircleAvatar, …]` with no trailing `IconButton`, no `PopupMenuButton`, no `onTap` |
| **H9** 7 sub-44pt targets (1 fixed in R2) | ❌ | **Unchanged (still 6)** | `document_attach_widgets.dart:47-50` (18×18), `cart_screen.dart:883-888` (24×24), `care_calendar_screen.dart:355-358` (~36pt), plus `raise_concern_screen.dart:230`, `payment_screen.dart:864`, `article_list_screen.dart:188` — all byte-identical |
| **M13/M14** chart `ExcludeSemantics`, `care_pulse_ring` double-announce | ❌ | **Unchanged** | `care_pulse_ring.dart:86` still `Semantics(label:…)` with no `excludeSemantics: true`. `ExcludeSemantics` app-wide went 3 → **4**; the +1 is the demo pill, not a chart |
| **M22** two ungated animations | ❌ | **Unchanged** | `equipment_detail_screen.dart:1690-1694` (250 ms controller, no `disableAnimations`), `care_calendar_screen.dart:357` (`AnimatedContainer` 150 ms) |
| **M25** 971 literal `fontSize:`, 0 `textTheme.` | ❌ regressed in R2 | **Partially recovered, still failing** | **964** literals (971 → 964; round 1 was 957). `textTheme.` still **0** |
| **M26** raw `Colors.white`/`black` | ❌ regressed in R2 | **✅ Regression REVERSED** | `Colors.white` (no numeric suffix) 135 → **132**, exactly round 1's figure. All-variant total 181 → **178**. The delta is the three `delete_account_screen.dart` hardcodes, now gone |
| **NEW-R2** delete-account white on `hc.error` = 3.49:1 dark | ❌ **REGRESSION** | **✅ FIXED — genuinely** | See §A. `onError` resolves per appearance and is used at all three sites |
| **NEW-R2** type-`DELETE` field has no accessible name | ❌ | **✅ FIXED** | `delete_account_screen.dart:281-284` — `labelText` now carries the instruction, `hintText` keeps the word, and the loose unlinked `Text` at old `:196` is gone |
| **NEW-R2** delete-account screen hardcoded English | ❌ | **✅ FIXED** | Zero raw user-facing strings remain in the file; 20+ `l.t(...)` calls, including `delete_account_confirm_word` so a Hindi user is not asked to type a Latin word |
| **NEW-R2** delete-account has no test | ❌ | **Unchanged** | `grep -rl "DeleteAccount\|delete_account" test/` → only `test/utils/permission_test.dart`; `grep -c delete test/screens/overflow_smoke_test.dart` → **0** |
| **NEW-R2** "Delete account" 1pt below "Logout", same red | ⚠️ | **Unchanged** | `lib/screens/settings/settings_screen.dart:261-279` — still `Divider(height: 1)` between them, both `context.hc.error` |
| **NEW-R2** banner silent to VoiceOver on appearance | ❌ | **✅ FIXED** | `lib/widgets/demo_data_banner.dart:74-84` + `:91` — see §C for the caveat |
| **NEW-R2** banner hardcoded English | ❌ | **✅ FIXED** | `demo_banner_message` / `demo_banner_short` present in **both** `assets/i18n/en.json:323`,`:354` and `hi.json:323`,`:354` |
| **NEW-R2** banner misses 7 demo-data paths | ❌ | **⚠️ Partial — 3 of 7** | See §D. Four sites still bypass, and three declared source constants are **dead code** |
| **NEW-R2** banner can be switched off while sample data is on screen | ❌ | **✅ FIXED** | `lib/data/demo_mode.dart:36`,`:46-54` — `Set<String>`; `markServingLiveData` removes only the named source |
| **NEW-R2** banner contrast 14.68:1 / 11.98:1 | ✅ | **✅ still passes** | Re-measured through the new translucent stack: **14.54–14.79:1** light, **12.02–12.35:1** dark, across every backdrop. See §E |
| **NEW-R2** five-tab nav targets 64×56 | ✅ | **✅ improved further** | Pill is inset 16pt/side → 5 items across 288pt at 320 width = **57.6 × ≥56** per item; still clears 44pt on both axes |

---

## Round-2 repairs: adversarial review

### A. The `onError` token — the 3.49:1 regression is genuinely fixed ✅

This is the one repair that is not a surface. Both halves check out.

**The token resolves per appearance** (`lib/config/theme.dart:53` dark class, `:100` light class;
plumbed at `lib/config/app_colors.dart:56`, `:93`, `:123`):

| Appearance | `hc.error` | `hc.onError` | Ratio | 4.5:1 |
|---|---|---|---|---|
| Light | `#D32F2F` | `#FFFFFF` | **4.98 : 1** | ✅ |
| Dark | `#EF5350` | `#212121` | **4.62 : 1** | ✅ |
| *(dark, as it shipped in R2)* | `#EF5350` | `#FFFFFF` | *3.49 : 1* | *❌* |

Note the direction: it is the **dark** arm that got the dark ink. That is counter-intuitive and
therefore easy to get backwards, and it is right — dark mode's error red is the *lighter* red, so
dark ink is the correct pairing. `theme.dart:48-52` documents exactly this. Both classes carry a
comment stating the measured ratio, and both comments match my computation.

**Both call sites use it, and so does the third one round 2 named:**

| Site | file:line | Uses |
|---|---|---|
| Confirm-dialog "Delete" `ElevatedButton` | `delete_account_screen.dart:184-187` | `backgroundColor: hc.error` / `foregroundColor: hc.onError` ✅ |
| Main "Delete my account" button | `delete_account_screen.dart:293-294` | same ✅ |
| In-button `CircularProgressIndicator` | `delete_account_screen.dart:301-302` | `color: hc.onError` ✅ |

`grep -c "Colors.white" lib/screens/settings/delete_account_screen.dart` → **0**. The regression is
closed, and closed at the token layer rather than patched at the view — which is what the checklist's
§6.2 asks for.

**Two residual defects on the same button, both carried over from round 2 unchanged:**

1. `delete_account_screen.dart:293` — `backgroundColor: canSubmit ? hc.error : hc.grey` is still
   **dead code**. `ElevatedButton.styleFrom` builds its background property from
   `(backgroundColor, disabledBackgroundColor)`; with `disabledBackgroundColor` unset the disabled
   state resolves to `null` and falls through to the M3 default (`onSurface` @12% fill, @38% ink).
   `hc.grey` is never painted. Not a WCAG violation (disabled controls are exempt from 1.4.3) but
   the real disabled state is ≈2.3:1, and an elderly user who has ticked the box but mistyped the
   word gets a near-invisible button with no explanation. Round-2 finding #37, **unchanged**.
2. `:301-302` — the spinner still has **no `semanticsLabel`**. The 600 ms `Future.delayed` is gone
   (good), but the real work — a `SharedPreferences` write, a Firebase credential delete, a full
   `SessionScope.clearSession`, a logout — is now genuinely asynchronous and *longer*, and it is
   announced as silence after the most consequential tap in the app.

**Verdict: ✅ fixed, not a surface.** The token is correct, paired, per-appearance, documented with
accurate measured ratios, and used everywhere the hardcode was.

---

### B. The frosted pill nav — the numbers are right, but they are a **best case**, and the true worst case is content-dependent and cannot be reduced to one number ⚠️

**Your two figures reproduce exactly.** The stack is
`Container(warm shadow) > GlassSurface(sigma 36, opacity 0.78) > DecoratedBox(orangeLight @0.22) > BottomNavigationBar(transparent)`
(`lib/screens/main_shell.dart:94-137`). Compositing source-over in sRGB:

```
light:  fill = #FFFFFF @0.78   tint = hc.orangeLight = #FFF3E0 @0.22
dark:   fill = #1C1C1E @0.78   tint = hc.orangeLight = orangeMuted #3D2A12 @0.22
```
*(note: `orangeLight` is **not** `#FFF3E0` in dark — `HcPalette.dark()` maps it to `orangeMuted`
`#3D2A12`, `app_colors.dart:130`. The code comment at `main_shell.dart:122` implicitly assumes this
and lands on the right answer.)*

| Backdrop | Composite | Selected `#9A5C00`/`#F39314` | Unselected `#3D3D3D`/`#B0B0B0` |
|---|---|---|---|
| **LIGHT** white page `#FFFFFF` | `#FFFCF8` | **5.26 : 1** ✅ | 10.62 : 1 ✅ |
| LIGHT app bg `#F8F9FA` | `#FDFCF7` | 5.24 : 1 ✅ | 10.57 : 1 ✅ |
| LIGHT orange fill `#F39314` | `#FDEAD0` | 4.57 : 1 ✅ (margin 0.07) | 9.24 : 1 ✅ |
| LIGHT hero gradient `#FF6B35` | `#FFE3D6` | **4.41 : 1** ❌ | 8.90 : 1 ✅ |
| LIGHT mid-grey photo `#808080` | `#E9E7E2` | **4.35 : 1** ❌ | 8.79 : 1 ✅ |
| LIGHT dark photo `#000000` | `#D3D1CC` | **3.52 : 1** ❌ | 7.12 : 1 ✅ |
| **DARK** true black `#000000` | `#1F1A16` | **7.39 : 1** ✅ | 7.95 : 1 ✅ |
| DARK card `#1C1C1E` | `#231F1B` | 7.01 : 1 ✅ | 7.55 : 1 ✅ |
| DARK orange fill `#F39314` | `#48331A` | 5.10 : 1 ✅ | 5.49 : 1 ✅ |
| DARK white photo `#FFFFFF` | `#4A4642` | **4.00 : 1** ❌ | 4.31 : 1 ❌ |

So `#FFFCF8` / `5.26:1` and `#1F1A16` / `7.39:1` are **arithmetically exact** — for a **pure white
light backdrop and a pure black dark backdrop**. Those are the best cases, not the worst.

**Can a translucent pill over arbitrary scrolling content be measured at all? No — and that is the
honest finding.** Three things make the single number unsound:

1. **The backdrop is genuinely arbitrary.** `Scaffold(extendBody: true)` (`main_shell.dart:57`)
   is the whole point of the design — content glides *under* the pill. Everything in this app's
   scrollables can end up there: equipment product photos (`assets/images/products/`, 100 bundled
   images, arbitrary luminance), the hero gradients `#FF8C00`→`#FF6B35` (`app_colors.dart:31-32`),
   orange-filled cards, and the promo banner with its `black @0.45` scrim
   (`home_screen.dart:600-602`).
2. **The `MediaQuery.padding.bottom` trick does not make the backdrop white.** `main_shell.dart:72-76`
   and `test/screens/main_shell_test.dart:220-235` are correct that the Scaffold reports the slot's
   full height as the body's bottom inset, so the *last* item of a scrollable clears the pill. But
   that only governs the terminal scroll position. At **every intermediate resting scroll offset** —
   which is where a user spends nearly all of their time on a long list like the equipment catalog —
   arbitrary content sits under the pill at rest. The failure is not transient.
3. **A 36-sigma blur does not lighten.** `BackdropFilter` averages; it does not raise luminance. A
   dark region larger than the blur kernel stays dark. So the `#000000` row above is a real
   photograph, not a theoretical limit.

**Plain statement, as asked:** the frosted pill's selected-item contrast is **content-dependent and
ranges from ≈5.26:1 down to ≈3.5:1 in light and ≈7.39:1 down to ≈4.0:1 in dark**. It passes AA over
the app's own page backgrounds (`#F8F9FA` / `#000000`, its resting state on short screens) and
**fails AA over dark imagery in light mode and light imagery in dark mode**. No single number is
honest here; the correct artifact is a *floor*, and the code has none. Two structural fixes exist
and neither is expensive: raise `opacity` toward ~0.90 (the demo pill already does exactly this,
`demo_data_banner.dart:100`, and its ink then holds ±0.15 across every backdrop — see §E), or add a
non-glass scrim behind the label row.

**Two further findings on the same control:**

- **The pill's own boundary is 1.02:1 against a white page** (`#FFFCF8` vs `#FFFFFF`) and **1.03:1**
  against the app background `#F8F9FA`. `GlassSurface` does still draw an edge
  (`glass.dart:162-164`, `Border.all(white @0.6)`) despite the "no border" note at
  `main_shell.dart:89-93` — it is simply white-on-white and invisible. The only remaining separation
  is the `orange @0.18` shadow at `main_shell.dart:102-106`. Checklist §1.2 asks for 3:1 on
  *borders that carry meaning*; the outline of the app's primary navigation control is a reasonable
  reading of that, and at 1.02:1 it fails. **This is an owner decision** ("read it as FROST instead")
  and is reported as measured fact, not as a demand to reverse — but the owner should know the
  measurement, because in dark mode the boundary is 1.22:1 and the pill effectively has no edge at all.
- **Selected state is not colour-alone ✅.** Selected vs unselected ink is only 2.02:1 against *each
  other*, but selection is also carried by `FontWeight.w700` (`main_shell.dart:145-147`) and a
  filled `activeIcon` (`:151`,`:156`,`:161`,`:166`,`:171`). Three redundant carriers — this part is
  right.
- **`orangeStrong` has exactly one call site** (`main_shell.dart:143`) and **is not used anywhere it
  fails**. Direct measurements: light `#9A5C00` on white = **5.38:1**, on `#F8F9FA` = **5.10:1**;
  dark `#F39314` on `#000000` = **8.99:1**, on card `#1C1C1E` = **7.29:1**. The `5.38:1` in the
  code comment is accurate. The only exposure is the composite range above.

---

### C. The demo notice as a Stack child — the announcement is **correct but fires once per session, not once per screen**, and the traversal-order guarantee has been lost ⚠️

**What genuinely improved:**
- `SemanticsService.sendAnnouncement(View.of(context), …, assertiveness: assertive)`
  (`demo_data_banner.dart:78-83`) is the **correct, non-deprecated** API on this SDK. Verified in
  `/opt/homebrew/share/flutter` (framework **3.41.2**): `SemanticsService.announce` is
  `@Deprecated('… deprecated after v3.35.0-0.1.pre')` and the doc says *"Prefer using
  sendAnnouncement instead."* The author reached for the right one.
- Firing it from `initState`'s post-frame callback is also right: `Semantics(liveRegion: true)`
  (`:91`) only re-announces on *label change*, and this label never changes — so `liveRegion` alone
  would have been silent. Both mechanisms together is the correct belt-and-braces. `liveRegion` count
  in `lib/` went 0 → **1**; `SemanticsService` 0 → **1**.
- `Semantics(label: …) > ExcludeSemantics(…)` (`:90-95`) is the right shape: one node carrying the
  full sentence `demo_banner_message`, with the abbreviated visual string suppressed. No
  double-announce.

**What the move from Column child to Stack child cost — this is the specific regression:**

As a Column child in round 2 the notice was the **first child of the shell body**, so it structurally
preceded every screen's content in VoiceOver's reading order, **on every screen, every time**. As a
`Positioned` Stack child installed from `MaterialApp.builder` (`main.dart:434`), the pill's semantics
node is a geometric sibling of the whole app's nodes, and Flutter sorts sibling nodes by position
(vertical bands, then horizontal). Its rect is `top = padding.top + kToolbarHeight + 4`, horizontally
**centred** (`demo_data_banner.dart:44-49`). On Settings that band also contains the profile row,
whose node starts at `x = 0`; the pill starts near `x ≈ 42`. It therefore reads **after** the first
content row, not before it. The "warning comes first" property is gone.

**And the announcement does not compensate on subsequent screens.** `DemoDataBannerHost` sits *above*
the Navigator (`main.dart:422-436`), so its element — and `_DemoDataPill`'s `State` — **persists
across every route push**. `initState` runs once, when `DemoMode.isServingDemoData` first flips true.
Concretely: the app opens, the dashboard fetch fails after ~5 s, `app_provider.dart:286` marks
`sourceDashboard`, the pill appears and announces once. The patient then navigates
Home → My Care → `/vitals` → `/medication-schedule` — **and is never told again**. On those screens
the notice is a mid-traversal node they must swipe onto.

That is still a real improvement over round 2's total silence, and the announcement is *assertive*, so
the first one interrupts. But the claim implied by the code comment at `:71-73` — that a VoiceOver
user is warned before hearing fake vitals — holds only for whichever screen happens to be foreground
when the timeout fires. **Fix:** re-announce on route change (a `NavigatorObserver` that calls
`sendAnnouncement` while `isServingDemoData.value` is true), or give the node a
`SemanticsSortKey`/`OrdinalSortKey` low enough to sort it first within its band.

**One latent defect:** at `:94` the semantic label is `l?.t('demo_banner_message')` — nullable — while
the *visual* string at `:116-117` has an English fallback `?? 'Sample data — not your live record'`.
If `AppLocalizations` is ever absent the pill renders visible English text with a **null** semantic
label inside `ExcludeSemantics`, i.e. it becomes completely invisible to a screen reader while
remaining visible on screen. Low likelihood (`Localizations` is an ancestor of `MaterialApp.builder`),
but it is the exact inversion of the failure the widget exists to prevent, and the fallback should be
on both or neither.

---

### D. Occlusion: is it better or worse than the displacement it replaced? — **Worse than the brief says, and it is not confined to Settings** ❌

**What the checklist actually fails on.** Being blunt, as asked: the checklist has **no line item that
says "do not occlude content."** Occlusion per se is a usability defect, not a codified accessibility
failure, and I am not going to invent a clause. What it *does* fail is narrower and real:

| Checklist line | Verdict | Why |
|---|---|---|
| §2.1 "content reflows or wraps — it does not **truncate meaning away**" | ❌ | The pill's own text is `maxLines: 1, overflow: TextOverflow.ellipsis` (`demo_data_banner.dart:118-119`). Truncation is the **designed** failure mode of a clinical-safety warning |
| §1.5 "text over images/gradients has a scrim or is measured against the worst pixel" | ✅ | Measured against every backdrop — see §E. This one it passes, decisively |
| §3.1 "every tappable element is ≥44×44pt including its padding" | ✅ (not implicated) | The pill is **transparent to touch**: `ClipRRect > BackdropFilter > DecoratedBox > Padding > Row` — every one is a `RenderProxyBox` whose `hitTestSelf` is `false`, and `Stack` continues to the sibling below. It hides an affordance; it does not steal the tap |
| §5 "no information arrives ONLY as …" / time limits | N/A | — |

**Where it actually occludes — the brief understates this.** The pill's top is
`MediaQuery.padding.top + kToolbarHeight + 4` (`:45`). Its height is ≈29pt at 1.0× (7+7 padding +
~15pt line box), ≈35pt at the app's 1.4× ceiling. So it occupies content-relative y ∈ [4, 33].
Every screen following the CLAUDE.md glass convention — *"scroll padding `MediaQuery.padding.top +
kToolbarHeight`"* — puts its first content line in exactly that band:

| Screen | Scroll top pad | First content line vs pill |
|---|---|---|
| `lib/screens/calendar/care_calendar_screen.dart:216` | `padding.top + kToolbarHeight` (**+0**) | occluded from its very first pixel row |
| `lib/screens/settings/delete_account_screen.dart:203`,`:215` | `topPad + 8` | first line of the erasure explainer occluded |
| `lib/screens/my_care/my_care_screen.dart:141` | `+ 8` | first line occluded |
| `lib/screens/care_team/care_team_screen.dart:84` | `+ 8` | first line occluded |
| `lib/screens/assistant/assistant_screen.dart:88` | `+ 8` | first line occluded |
| `lib/screens/billing/billing_screen.dart:172` | `+ 16` | top ~17pt of the first line occluded |
| `lib/screens/settings/settings_screen.dart:86-100` (**no** `extendBodyBehindAppBar`) | `ListView` from y=0 | clips the top ~15pt of the 72pt profile avatar; stops just above the patient name at y≈36 |

So Settings is, if anything, the **mildest** case — it loses the top of an avatar. The severe cases
are the care calendar, My Care, and the account-deletion screen. Note the last one especially: the
pill covers the opening line of the screen that exercises a DPDP §12 erasure right.

**And it is unrecoverable.** The pill is explicitly *"Persistent and non-dismissible"* (`:57-59`) with
no dismiss control, no drag, no settings toggle. Scrolling does not help: scrolling up moves the
occluded line further under the app bar; the only way to see it is an over-scroll bounce, which is
not a resting state. Compositing through `0.92 × 0.92` leaves **0.64%** of the underlying content —
effectively opaque, so it is clean occlusion rather than an illegible smear. That is the one mercy.

**Worse or better than the displacement it replaced?** Different, not better. The strip stole a fixed
band of *every* screen and pushed everything down; the pill hides a variable band of *every* screen
and pushes nothing. Both cost the same real estate. The pill's genuine wins are that it no longer
double-counts the status-bar inset and no longer forces per-screen inset maths — which is a
maintainability win, not an accessibility one. The accessibility trade is roughly neutral, and it is
strictly negative on the screens where `+0`/`+8` padding puts a whole line behind it. **This is
"known and unfixed" per the brief and I am grading it as an open defect, not an owner decision** —
the brief presents it as a defect awaiting assessment, not as a decision already taken.

**Cheapest real fix:** move the pill to the *bottom* of the screen, just above the nav pill, where
`MediaQuery.padding.bottom` already reserves space and nothing starts. It would occlude nothing and
require no per-screen change — preserving the exact property (`:24-27`) the current design was built for.

---

### E. Demo-pill contrast through the new translucent stack — ✅ and, unlike the nav, **backdrop-independent**

Stack is `GlassSurface(opacity 0.92)` → `Container(hc.warningLight @0.92)` → text `hc.black`
(`demo_data_banner.dart:96-126`). Because both layers are at 0.92, the backdrop contributes
0.08 × 0.08 = **0.64%**:

| Appearance | Backdrop | Composite | Ink | Ratio |
|---|---|---|---|---|
| Light | `#FFFFFF` | `#FFF4E2` | `#212121` | **14.79 : 1** |
| Light | `#000000` | `#FDF2E1` | `#212121` | **14.54 : 1** |
| Light | `#F39314` | `#FFF3E1` | `#212121` | **14.69 : 1** |
| Dark | `#000000` | `#372B15` | `#F2F2F2` | **12.35 : 1** |
| Dark | `#FFFFFF` | `#392D16` | `#F2F2F2` | **12.02 : 1** |
| Dark | `#F39314` | `#392C15` | `#F2F2F2` | **12.14 : 1** |

Total spread **0.25** light / **0.33** dark. The round-2 figures (14.68 / 11.98) survive within
rounding. The `size: 15` icon shares the ink and clears the 3:1 non-text floor by 4–5×.

**This is the proof that §B's problem is solvable in the same codebase.** The demo pill and the nav
pill are the same `GlassSurface` primitive; the demo pill chose `opacity: 0.92` with an explicit
comment — *"this is a warning over arbitrary content, so legibility beats translucency"* (`:98-100`) —
and is therefore backdrop-independent. The nav pill chose `0.78` and is not. One author, one commit
range, two opposite decisions, and only one of them was measured against a worst pixel.

---

### F. Demo-source coverage — 3 of 7 wired, and **three declared constants are dead code** ⚠️

The `Set<String>` rewrite (`lib/data/demo_mode.dart:36-66`) is correct and closes round-2's
"one endpoint takes the banner down for everyone" defect: `markServingLiveData` removes only the named
source (`:52-54`), `reset()` is `@visibleForTesting` (`:57-58`), and `app_provider.dart:273` now
clears `sourceDashboard` alone.

But of round 2's seven un-marking sites, **three** were wired and **four** were not:

| Site | Serves | Marks now? |
|---|---|---|
| `lib/providers/app_provider.dart:142` | patient identity | ✅ `sourcePatientIdentity` |
| `lib/providers/blog_provider.dart:40`, `:70` | article list / single article | ✅ `sourceArticles` |
| `lib/screens/settings/patient_profile_screen.dart:898` | `DemoData.medicalHistory` — **clinical history** | ❌ |
| `lib/screens/my_care/widgets/doctor_advice_card.dart:46` | `DemoData.doctorRecommendations` — **doctor's advice** | ❌ |
| `lib/screens/care_team/care_team_screen.dart:29`,`:31`,`:162-164` | supervisor + past staff | ❌ |
| `lib/screens/calendar/care_calendar_screen.dart:1324` | `DemoData.icuServiceDetail.staffOnDuty` | ❌ |

And the tell: `demo_mode.dart` declares **11** source constants; `grep -rn "DemoMode\.source" lib/`
resolves **8**. `sourceCareTeam` (`:31`), `sourceCareCalendar` (`:32`) and `sourceProfile` (`:33`)
have **zero** call sites — exactly the four missing screens. The repair added the *identifiers* for
the sites round 2 named and did not add the *calls*. The file's own instruction at `:23` — *"Add a
constant here in the same edit that adds a fallback"* — was followed backwards.

In practice `sourceDashboard` fails first on every cold start, so the pill is up anyway and the
patient is not currently misled. But the four screens read `DemoData` **unconditionally**, not as a
fallback: when the backend lands and every provider goes live, the pill will come down while sample
medical history and a sample doctor's advice are still rendering. The mechanism will then assert
those are real. Same failure mode as round 2, deferred to the day the backend ships.

---

## Dynamic Type at AX5 — does it break the pill nav or the overlay pill?

**AX5 is unreachable, so strictly the answer is "neither — because the app refuses to render it."**
`lib/main.dart:426-429` still clamps `maxScaleFactor: 1.4`. iOS AX5 ≈ 3.1×, so AX1–AX5 all collapse
to 1.4×. `grep -rl "extScaler" test/` → **no files**; nothing is exercised at any scale. That is
round-1 blocker B3, round-2 blocker 3, **unchanged for a third round**, and it is what makes the
question unanswerable by observation. Analysis of both controls at the reachable ceiling and at a
hypothetical uncapped AX5:

**Overlay pill — does not break; it truncates, which for this content is worse.**
`maxLines: 1, overflow: TextOverflow.ellipsis` (`:118-119`) means it *cannot* overflow — the layout is
safe at any scale and the warning is what gives way. Usable text width at 320pt is
`320 − 24 (Positioned insets) − 24 (h-padding) − 21 (icon + gap) ≈ 251pt`. The English short string is
34 characters; at 12px Archivo (~0.52 em advance) it needs ≈212pt and fits; at the app's own **1.4×**
ceiling it needs ≈295pt and **ellipsizes** — inside the app's supported range, today. The Hindi string
(`hi.json:354`, ~37 Devanagari clusters, wider advances) is at or past the threshold at **1.0×** on a
320pt device. At an uncapped AX5 both truncate to roughly the first two words. These are nominal-advance
estimates, not rendered measurements — but the *finding* does not depend on the exact threshold: an
ellipsized single line is the designed failure mode for a message whose entire purpose is to say
"this is not your record," and §2.1 names truncating meaning away as a failure. Round 2 flagged that
the banner would be the first casualty of raising the clamp; the redesign answered that by making the
casualty silent instead of visible.

**Pill nav — grows rather than breaking at 1.4×; unverified, and it eats the screen at AX5.**
`BottomNavigationBar(type: fixed)` sizes itself with a `minHeight` of `kBottomNavigationBarHeight`
(56), so it *grows* with text rather than overflowing; `selectedFontSize` defaults to 14 (only
`fontWeight` is overridden, `main_shell.dart:145-147`), so at 1.4× the label is 19.6px and the pill
gains roughly 6–8pt. Because the pill is in the `bottomNavigationBar` slot, that growth is reported
back as body inset and nothing clips. At an uncapped AX5 the label is 43.4px in a 57.6pt-wide item
slot; `BottomNavigationBarItem.label` is rendered as a plain `Text` with no `maxLines`, so Hindi labels
like `"मेरी देखभाल"` (`hi.json`, tab_my_care) wrap to two lines and the pill approaches ~80pt of
content plus 16pt of margins — roughly a sixth of a 568pt SE screen, before the overlay pill's own
growth at the top. **None of this is tested.** `test/screens/main_shell_test.dart:291-296` asserts no
overflow at 320×568 at **default scale only** — round-2 finding #20, unchanged. This remains a
three-line fix (add a `textScaler: TextScaler.linear(1.4)` case) on the app's most-touched control.

**Verdict: N/A-by-clamp, ⚠️ at the reachable ceiling for the overlay pill (truncates today, in
Hindi, at 320pt), and unverified for the nav.**

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | BLOCKED-OWNER | Items |
|---|---|---|---|---|---|
| 1. Contrast | 1 | 2 | 2 | 0 | 5 |
| 2. Dynamic Type | 0 | 0 | 5 | 0 | 5 |
| 3. Touch targets | 0 | 1 | 3 | 0 | 4 |
| 4. Screen reader | 1 | 4 | 1 | 1 | 7 |
| 5. Motion, sound & state | 3 | 1 | 0 | 0 | 4 |
| 6. Process | 0 | 1 | 1 | 1 | 3 |
| **Total** | **5** | **9** | **12** | **2** | **28** |

Round 1: 4 / 7 / 15 / 2. Round 2: 4 / 7 / 15 / 2. Round 3: **5 / 9 / 12 / 2** — the first movement in
three rounds. Three ❌ became ⚠️ or ✅: §1.4 *paired foreground* (the `onError` token), §1.1 *text
contrast* (the 1.82:1 nav label is gone; the 3.49:1 button is gone), and §4.6 *async state announced*
(first `liveRegion` + `sendAnnouncement` in the codebase).

**The app still does NOT pass this checklist.** Four of the five "stop the release" red flags remain.

---

## Red flags (checklist's own "stop the release" list)

| Red flag | R1 | R2 | R3 | Evidence |
|---|---|---|---|---|
| Any meaning carried by colour alone | YES | YES | **YES** | `my_care_screen.dart:378-386`,`:420-427`; `home_screen.dart:1009`; `care_calendar_screen.dart:594-607` |
| White text hardcoded onto a brand colour | YES | YES ×2 | **YES ×1** | `theme.dart:32`,`:78` (`onOrange = #FFFFFF`, 2.33:1, **owner override**). The second instance (white on `hc.error`) is **fixed** — see §A |
| A chart with no textual equivalent | NO | NO | **NO** | Still the strongest area |
| A control under 44pt because "it fits the design" | YES | YES | **YES** | `document_attach_widgets.dart:47` (18×18); `cart_screen.dart:883` (24×24) |
| "Looks fine" as the only contrast evidence | YES | YES | **YES** | Zero contrast assertions in `test/` for a third round — and this round the untested surface is a **translucent** one, where "looks fine" is not even wrong, it is undefined |

---

## Blockers

1. **No contrast assertion exists anywhere in the suite — third round.**
   `grep -rn "contrast\|computeLuminance\|luminance" test/` → **0** across 1,813 tests. It hid 2.33:1
   for the whole release history, silently accepted 3.49:1 in round 2, and this round it accepted a
   nav whose selected-item contrast is **content-dependent between 3.5:1 and 7.4:1** with no floor
   asserted anywhere. **Fix:** `test/widgets/contrast_test.dart` with a `Color.computeLuminance()`
   ratio helper, asserting every `HcPalette.light()` **and** `.dark()` pair against 4.5/3.0 — seeded
   with the pairs in this report so it starts red on the known failures. Add a composite case for the
   pill: `alphaBlend(orangeLight@0.22, alphaBlend(white@0.78, worstBackdrop))`.

2. **Dynamic Type is capped at 1.4× and never tested — third round.**
   `lib/main.dart:426-429`; zero `textScaler` in `test/`. AX1–AX5 are all suppressed for an
   elderly-patient app, and the code comment still cites "WCAG 1.4.4", which requires 200%. New this
   round: the sample-data warning **already truncates inside the supported range** (Hindi at 1.0× /
   320pt; English at 1.4×). **Fix:** raise to ≥2.0, add `TextScaler.linear(1.4)` / `2.0` axes to
   `overflow_smoke_test.dart` and to `main_shell_test.dart:291`, and give the demo pill 2 `maxLines`.

3. **17 of 54 icon-only buttons are silent to VoiceOver — third round, unchanged to the line.**
   Independent brace-matched count reproduces round 2 exactly: 54 constructors, 37 carrying `tooltip:`
   / `semanticLabel` / an enclosing labelled `Semantics`, **17 bare**. Includes *call the health
   manager* and *message the health manager* — two visually identical circles with different
   destinations (`health_manager_banner.dart:69`,`:80`) — *send message* (`chat_screen.dart:335`), and
   three destructive deletes (`add_edit_medication_screen.dart:92`,
   `patient_profile_screen.dart:693`,`:834`). **Fix:** one `tooltip:` line each.

4. **Removing a family member is still swipe-only — third round.**
   `family_members_screen.dart:319`,`:335-336`. `_buildMemberCard` (`:346`) has no trailing control.
   Unreachable via VoiceOver, Switch Control, or keyboard — WCAG 2.1 §2.5.1 and §2.1.1. **Fix:** a
   trailing overflow `IconButton` gated by the existing `canManage` (`:266`), calling
   `_showDeleteConfirmation`.

5. **The frosted pill nav has no contrast floor over arbitrary content.** §B. Selected item ranges
   ≈5.26 → **3.52:1** (light, dark imagery) and ≈7.39 → **4.00:1** (dark, light imagery), with
   unselected also dropping to 4.31:1 in dark. The single quoted figure is a best case. **Fix:** raise
   `GlassSurface.opacity` toward 0.90 as the demo pill already does (`demo_data_banner.dart:100`), or
   scrim the label row — then assert the floor per blocker 1.

6. **The sample-data pill occludes the first content line of at least six screens, permanently and
   without a dismiss.** §D. `care_calendar_screen.dart:216` (+0), `my_care_screen.dart:141`,
   `care_team_screen.dart:84`, `assistant_screen.dart:88`, `delete_account_screen.dart:215` (all +8),
   `billing_screen.dart:172` (+16), plus the Settings profile avatar. Not confined to Settings as the
   brief states. **Fix:** move the pill above the nav pill at the bottom, where
   `MediaQuery.padding.bottom` already reserves the space.

---

## High

7. **The demo-data warning announces once per session, not once per screen** — §C.
   `DemoDataBannerHost` lives above the Navigator (`main.dart:434`), so `_DemoDataPillState.initState`
   runs once ever. A patient who navigates to `/vitals` after the announcement fired on Home is never
   told again, and the Stack placement removed the "read first" traversal guarantee the Column child had.
8. **Four sample-data paths still bypass the notice, and three declared source constants are dead
   code** — §F. `patient_profile_screen.dart:898`, `doctor_advice_card.dart:46`,
   `care_team_screen.dart:29`/`:31`/`:162`, `care_calendar_screen.dart:1324`;
   `demo_mode.dart:31`,`:32`,`:33` have zero call sites.
9. **Clinical vitals status is colour-only and unlabelled** — `my_care_screen.dart:378-441`.
   An 8×8 green/yellow/red dot, no text, no icon, no `Semantics` on the pill. Unchanged. The correct
   pattern exists twice in-repo (`vitals_screen.dart:846-869`, `medications_screen.dart:220-235`).
10. **Attendance text mislabels four of six statuses** — `home_screen.dart:1005-1016` vs
    `helpers.dart:65-82`. Unchanged.
11. **Three destructive actions with no confirm**, two 4pt from a habitual control —
    `care_calendar_screen.dart:1308-1314`, `cart_screen.dart:981`,
    `patient_profile_screen.dart:144-150`. Unchanged; `confirmDestructiveAction` still has 8 correct
    call sites.
12. **Six touch targets at 18–36pt** — `document_attach_widgets.dart:47` (18×18),
    `raise_concern_screen.dart:230` (22×22), `cart_screen.dart:883` (24×24 **cart stepper**),
    `payment_screen.dart:864` (24×24), `article_list_screen.dart:188` (~32pt),
    `care_calendar_screen.dart:355` (~36pt). Unchanged. The correct 44pt stepper already exists at
    `services/widgets/quantity_button.dart:44`.
13. **Money and vitals shrink instead of the container growing** —
    `equipment_item_card.dart:127-128`,`:181-182`, `my_care_screen.dart:401-412`. Unchanged.
14. **Nested tap targets on a call button and a consent checkbox** — `home_screen.dart:774` vs `:818`;
    `login_screen.dart:183` vs `:214`/`:234`. Unchanged.
15. **25 modal sheets with no focus management.** `liveRegion`/`SemanticsService` now exist — but at
    exactly **one** site each, both in `demo_data_banner.dart`. Zero `FocusScope`, zero
    `FocusTraversalGroup`, one `autofocus`. Unchanged apart from the banner.
16. **The account-deletion flow is still untested.** `grep -rl "DeleteAccount\|delete_account" test/`
    → only `test/utils/permission_test.dart`; absent from `overflow_smoke_test.dart` (0 hits). Its
    contrast, its localization, its `labelText`, and its `onError` pairing were all fixed this round
    and **none of them is guarded**. The next edit can undo all of it silently.

---

## Medium / Low

17. `delete_account_screen.dart:301-302` — deletion spinner still has no `semanticsLabel`; the
    now-genuinely-async work is announced as silence.
18. `delete_account_screen.dart:293` — `canSubmit ? hc.error : hc.grey` remains dead code;
    `styleFrom` sets no `disabledBackgroundColor`, so the real disabled state is the M3 ≈2.3:1 default.
19. `settings_screen.dart:276` — `title: 'Delete account'` is still **hardcoded English**, directly
    beneath `l.t('logout')` at `:266`, on a screen whose target screen is now fully localized.
20. `settings_screen.dart:261-279` — "Delete account" still sits one `Divider(height: 1)` below
    "Logout", same `hc.error`, same tile geometry, same person-icon family.
21. `demo_data_banner.dart:94` vs `:116` — semantic label is nullable while the visual string has an
    English fallback; a missing `Localizations` would render the warning **visible but unreadable to a
    screen reader**.
22. `demo_data_banner.dart:112` — `Icon(size: 15)` is a fixed size and does not scale with text.
    Unchanged in kind from round 2 (was `size: 18`); at 1.4× the warning glyph is proportionally smaller still.
23. `demo_data_banner.dart:78-83` — no `MediaQuery.supportsAnnounceOf` check before
    `sendAnnouncement`, which the SDK doc recommends; and on Android the platform has deprecated
    announcement events, so the `liveRegion` at `:91` is the only mechanism that reaches TalkBack.
24. The pill nav's boundary is **1.02:1** light / **1.22:1** dark against the page. `GlassSurface`
    still draws a `white @0.6` edge (`glass.dart:162-164`) despite the "no border" note at
    `main_shell.dart:89-93` — it is invisible, not absent. **Owner decision, reported as measurement.**
25. `main_shell.dart:55-56` — round-2 finding #18 is **resolved**: the "translucent nav bar" comment
    is now accurate, because the bar actually is translucent again. ✅
26. `main_shell_test.dart:291-296` still tests 320×568 at default scale only; no `textScaler` case.
27. Charts are never `ExcludeSemantics`-wrapped — `vitals_screen.dart:361`,`:377` axis ticks leak.
    `ExcludeSemantics` count 3 → 4, and the +1 is the demo pill.
28. `care_pulse_ring.dart:86` still lacks `excludeSemantics: true` → doubled announcement, 4 call sites.
29. `vitals_trend_grid.dart:64` — semantics label omits the numeric reading.
30. `ProductImage` labels its asset branch (`common_widgets.dart:131`) but not its network branch (`:134`).
31. ~20 `CircularProgressIndicator` with no `semanticsLabel`.
32. `glass.dart:139-152` — the **chrome** glass is still `opacity: 0.55` with no worst-pixel guarantee:
    dark title over a white photo ≈3.43:1; orange glyphs over dark content ≈1.44:1. The nav pill's
    0.78 and the demo pill's 0.92 are both improvements on this; the app bars were not touched.
33. Promo banner scrim is 0.45 α → 3.36:1 worst case (`home_screen.dart:600-602`).
34. Dark `textDisabled` `#7A7A7A` on card `#1C1C1E` = 3.96:1, not the 4.2:1 claimed at `theme.dart:25`.
35. Dividers carry structure at 1.32:1 light / 1.47:1 dark; segmented thumb 1.17:1 / 1.27:1.
36. Two ungated animations — `equipment_detail_screen.dart:1690`, `care_calendar_screen.dart:357`.
37. Calendar day cell 43.4pt wide at 320pt (`care_calendar_screen.dart:551`); `width < 360` branch untested.
38. `fontSize: 9.5` at `care_calendar_screen.dart:817`, below the app's own 11px floor.
39. **964** literal `fontSize:` (971 → 964, round 1 was 957) and **0** `textTheme.`; the `TextTheme` at
    `theme.dart:170-215`/`:360-395` is still dead code.
40. **132** raw `Colors.white` + 46 other `Colors.white*`/`black*` = **178** in `lib/screens` +
    `lib/widgets` (was 181). Regression reversed; the underlying count is unchanged from round 1.
41. Design gate still scans `lib/screens` only and bans no `Colors.white`/`black`
    (`scripts/check_design_consistency.sh:17`, `:42`) — it would not catch a re-introduction of the
    3.49:1 hardcode, and it has no rule for foreground/background *pairs*.
42. Stale contrast claim, now demonstrably false: `lib/config/app_colors.dart:67-68` still says
    *"White on orange fails AA (~2.3:1), so both modes use the same **dark ink** (6.3:1 on orange)"* —
    directly above `onOrange = HousepitalColors.onOrange` which is `#FFFFFF`. `theme.dart:212`,`:230`,
    `:415` carry the same pre-reversal claims. A future reader will trust these.
43. `overflow_smoke_test.dart` covers 37 of ~56 screens; delete-account, calendar, main shell, care
    team, chat, login, payment, order tracking and address remain uncovered.

---

## BLOCKED-OWNER

- **§4.7 — manual VoiceOver device pass.** Still no artifact in the repo. **To clear this I need:** a
  physical-iPhone VoiceOver run of (1) Home → book → cart → checkout, (2) My Care → vitals → care
  calendar, (3) Settings → Delete account → confirm, pass/fail per step. **New this round, and it is
  the only way to settle two of my findings:** the run must record (a) *on which screens* the
  sample-data announcement is heard, to confirm §C's once-per-session analysis, and (b) whether the
  overlay pill's occlusion is perceived as content loss by a low-vision user at 1.4×. Static analysis
  cannot substitute for either.
- **§6.3 — a11y findings triaged at functional-bug priority.** Round 3 supplies the first *positive*
  datum: two accessibility defects (the `onError` pairing, the silent banner) were fixed in the same
  commit range as functional work, and one (the 1.82:1 nav label) was fixed incidentally by a design
  change. But four of five accessibility blockers are now **three rounds old** while ten functional
  blockers closed in one. **To clear this I need:** the owner's triage policy plus one release cycle
  of tracker evidence.

---

## Notes on what was deliberately NOT graded as failures

Per the brief: white-on-orange ink (`onOrange = #FFFFFF`, **2.33:1**) on the remaining orange fills;
manpower prices shown and directly bookable; the floating glass pill nav as a design choice; and the
`DemoData` fallbacks themselves. All are reported as measured fact. The pill's **1.02:1 boundary** and
its **content-dependent 3.5–5.3:1 label contrast** are reported as measurements against the owner's
"no border / read it as frost" decision — the decision is the owner's, the numbers are not.

The occlusion of the sample-data pill is graded as an **open defect**, not an owner decision: the brief
presents it as "known and unfixed" and asks for an assessment, which is a different thing from a call
already made.

`storage.rules` / Firebase posture, payment-key handling and PHI session-scoping are outside this
checklist and are covered by the security and post-launch audits.

---

## Executive summary

1. **Counts: 5 ✅ / 9 ⚠️ / 12 ❌ / 2 BLOCKED-OWNER** — the first movement in three rounds (R1 and R2 were both 4/7/15/2).
2. **Genuinely fixed:** the `onError` token — light `#FFFFFF` on `#D32F2F` = **4.98:1**, dark `#212121` on `#EF5350` = **4.62:1**, used at all three `delete_account_screen.dart` sites (`:187`, `:294`, `:302`), with **zero** `Colors.white` left in the file. Fixed at the token layer, not patched at the view.
3. **Also genuinely fixed:** the delete-account `labelText` (`:281-284`), full localization of that screen, the banner's English hardcode, the banner's silence (first `liveRegion` + `sendAnnouncement` in the codebase, using the correct non-deprecated 3.41.2 API), the `DemoMode` boolean→`Set` rewrite, and the 1.82:1 unselected nav label — now **10.62:1**.
4. **REGRESSED:** nothing, in the strict sense. Round 2's `Colors.white` regression (135 → 132) and `fontSize` regression (971 → 964) both reversed. But the **nav lost its measurable contrast floor**: the old orange bar was a bad *known* number; the new frosted pill is an *unknown* one.
5. **Is a round-2 repair itself a surface? Two are, partially.** (a) The **`DemoMode` source set** declares 11 constants and wires 8 — `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` have zero call sites, so the four screens round 2 named still bypass the notice; the repair added the identifiers and not the calls. (b) The **overlay pill's announcement** fires once per *session*, not per screen, because the host sits above the Navigator — and the move from Column child to Stack child silently gave up the "read first" traversal guarantee it used to have.
6. **On the nav measurement you asked me to verify independently:** `#FFFCF8` / **5.26:1** and `#1F1A16` / **7.39:1** reproduce **exactly** — but only for a pure-white light backdrop and a pure-black dark one. With `extendBody: true` the backdrop is arbitrary at every intermediate scroll position, and a 36σ blur does not lighten. The honest figure is a **range: 5.26 → 3.52:1 light, 7.39 → 4.00:1 dark**. A translucent pill over arbitrary content cannot be reduced to one number, and the code has no floor. The demo pill proves the fix is available in the same file family: at `opacity: 0.92` its ink holds within **0.25** across every backdrop.
7. **On occlusion:** it fails §2.1 (the pill's own text is `maxLines: 1` + ellipsis — it truncates the warning rather than wrapping it, in Hindi at 1.0×/320pt and in English at the app's 1.4× ceiling). It passes §1.5 and does not implicate §3.1 — the pill is transparent to hit-testing. But the brief understates the scope: it occludes the first content line of **at least six screens**, not just Settings, including the care calendar (+0 padding), My Care, and the account-deletion screen; Settings is the mildest case. It is non-dismissible and unrecoverable by scrolling.
8. **Dynamic Type at AX5:** unreachable — `main.dart:426-429` still clamps at 1.4× for a third round, and `test/` has zero `textScaler`. At the reachable ceiling the overlay pill **truncates** (it cannot break, by design) and the nav pill **grows ~6–8pt without overflowing**, untested. At an uncapped AX5 the nav would consume ~96pt of a 568pt screen with wrapped Hindi labels.
9. **Top 5 remaining:** (1) zero contrast assertions, third round — and the newest surface is translucent, where "looks fine" is not even wrong; (2) Dynamic Type clamped at 1.4×, third round; (3) 17 of 54 icon buttons silent, third round, unchanged to the line; (4) family-member removal swipe-only, third round; (5) the pill nav's missing contrast floor plus the six-screen occlusion.
10. **Verdict: FAIL.** Four of five "stop the release" red flags stand. Three ❌ genuinely became ⚠️/✅ this round and the work behind them was real — but every one of round 1's five accessibility blockers is now three rounds old, and the newest chrome shipped without a single automated contrast assertion behind it.
