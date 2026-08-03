# Accessibility Checklist (App-Agnostic) — Audit **round 2** vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Method:** read-only (`rg`/`grep`/`Read`, WCAG 2.1 relative-luminance computation in Python). No `flutter test` / `build` / `clean` run. No files changed except this report.

---

## Changed since round 1

Ten blockers were closed across the repo. **None of them was an accessibility blocker.** Of the five accessibility blockers named in round 1, **zero are fixed**; the round-2 work introduced **two new contrast failures**, **one new destructive-adjacency**, and **one correctness bug in the new honesty mechanism itself**.

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **B1** White-on-orange 2.33:1 across all chrome | **Unchanged** (owner override — reported as fact) | `lib/screens/main_shell.dart:90`, `lib/config/theme.dart:32`, `:70`, `:231`, `:416` |
| **B1b** Unselected nav labels 1.82:1 | **Unchanged** | `lib/screens/main_shell.dart:91` — `onOrange.withValues(alpha: 0.7)` |
| **B2** Zero contrast assertions in `test/` | **Unchanged** | `rg -c "contrast\|luminance" test/` → **0** |
| **B3** Dynamic Type clamped at 1.4×, untested | **Unchanged** | `lib/main.dart:425-428` still `maxScaleFactor: 1.4`; `rg "textScaler\|TextScaler" test/` → **0** |
| **B4** 17 of 54 icon buttons unlabelled | **Unchanged — and it did not grow** ✅ | Re-counted below: still **54 total / 37 labelled / 17 unlabelled**. The two new screens added zero `IconButton`s. |
| **B5** Family-member removal swipe-only | **Unchanged** | `lib/screens/settings/family_members_screen.dart:319-341`; `_showDeleteConfirmation` has exactly **one** caller, `:336`, inside `confirmDismiss` |
| **H9** 7 sub-44pt targets | **Partially fixed (1 of 7)** | Saved-item remove is now a 44×44 `IconButton` with a tooltip (`lib/screens/cart/cart_screen.dart:977-984`). The other six are byte-identical. |
| **M13/M14** chart `ExcludeSemantics`, `care_pulse_ring` double-announce | **Unchanged** | 3 `ExcludeSemantics` app-wide; `lib/widgets/care_pulse_ring.dart:86` still lacks `excludeSemantics: true` |
| **M22** two ungated animations | **Unchanged** | `lib/screens/services/equipment_detail_screen.dart:1690`, `lib/screens/calendar/care_calendar_screen.dart:357` |
| **M25** 957 literal `fontSize:`, 0 `textTheme.` | **Regressed** | now **971** literals, still **0** `textTheme.` references |
| **M26** raw `Colors.white`/`black` that don't flip | **Regressed** | 132 → **135** `Colors.white`; the +3 are all in the new `delete_account_screen.dart` (`:108`, `:216`, `:224`) |

### New in round 2

| New | Grade | Evidence |
|---|---|---|
| Sample-data banner contrast | ✅ | **14.68:1** light / **11.98:1** dark (see correction below) |
| Sample-data banner is silent to VoiceOver when it appears | ❌ | `lib/screens/main_shell.dart:137-140` — no `liveRegion`, no `SemanticsService.announce` |
| Sample-data banner is **hardcoded English** | ❌ | `lib/screens/main_shell.dart:153-154`, in a widget whose five sibling labels all use `l.t(...)` |
| Banner **misses 7 demo-data paths** | ❌ | 4 screens + `blog_provider` + `app_provider.loadPatients` never mark |
| Banner **can be switched off while sample data is still on screen** | ❌ | `lib/providers/app_provider.dart:247` — `DemoMode.reset()` is unconditional and un-counted |
| Delete-account button: white on `hc.error` = **3.49:1 in dark** | ❌ | `lib/screens/settings/delete_account_screen.dart:107-108`, `:214-216` |
| Delete-account: type-`DELETE` field has **no accessible name** | ❌ | `delete_account_screen.dart:199-208` — `hintText` only, no `labelText`, no `Semantics` |
| Settings: **"Delete account" sits 1pt below "Logout"**, both red | ⚠️ | `lib/screens/settings/settings_screen.dart:265-279` |
| Delete-account screen is **hardcoded English** and **has no test** | ❌ | zero `AppLocalizations` in the file; zero references in `test/` |
| Five-tab nav | ✅ **improved** | per-item target grew from 53.3×56 (6 tabs) to **64×56** at 320pt; contrast maths unchanged |

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | BLOCKED-OWNER | Items |
|---|---|---|---|---|---|
| 1. Contrast | 0 | 1 | 4 | 0 | 5 |
| 2. Dynamic Type | 0 | 0 | 5 | 0 | 5 |
| 3. Touch targets | 0 | 1 | 3 | 0 | 4 |
| 4. Screen reader | 1 | 3 | 2 | 1 | 7 |
| 5. Motion, sound & state | 3 | 1 | 0 | 0 | 4 |
| 6. Process | 0 | 1 | 1 | 1 | 3 |
| **Total** | **4** | **7** | **15** | **2** | **28** |

**Identical to round 1. Verdict: the app still does NOT pass this checklist.** Four of the five "stop the release" red flags remain present, and one of them (white text hardcoded onto a fill colour) was **reproduced on a second colour** by round-2 code.

---

## Round-2 specifics requested

### A. The sample-data banner — contrast measurement corrected

The parent's measurement was **19.15:1 light / 11.98:1 dark**. Recomputing from the resolved tokens:

```
banner fill : context.hc.warningLight        light #FFF3E0   dark #3A2D14
banner ink  : context.hc.black               light #212121   dark #F2F2F2
                                            (main_shell.dart:142, :149, :158)
```

| Appearance | Fill | Ink | Ratio | vs 4.5:1 |
|---|---|---|---|---|
| Light | `#FFF3E0` | `#212121` | **14.68 : 1** | pass |
| Dark | `#3A2D14` | `#F2F2F2` | **11.98 : 1** | pass |

**The dark figure (11.98:1) is confirmed exactly. The light figure is not 19.15:1 — it is 14.68:1.**
19.15:1 is what `#FFF3E0` gives against **pure black `#000000`**, and `HcPalette.light().black` is **`#212121`**, not `#000000` (`lib/config/theme.dart:79`). The 18pt info icon shares the same ink and therefore the same 14.68:1, comfortably over the 3:1 non-text floor.

Both pass by a wide margin. Contrast is the one thing about this banner that is not a problem.

### B. The banner at AX5 — ⚠️, and the clamp is what is hiding it

Structurally the banner is sound: `Text` inside `Expanded` inside `Row` (`main_shell.dart:151-161`), inside a `Padding` with no fixed height, as a **non-flex child of a `Column`** whose sibling is `Expanded(IndexedStack)` (`:58-71`). It wraps rather than truncates, and it grows rather than clipping. There is no `maxLines` and no `TextOverflow.ellipsis` — correct.

Two caveats:

1. **It is never actually exercised above 1.4×.** `lib/main.dart:425-428` still clamps `maxScaleFactor: 1.4`, so AX1–AX5 all collapse to 1.4×. At 1.4× the 12pt string becomes 16.8pt and occupies ≈3 lines / ≈85pt on a 320pt-wide device — fine.
2. **If the clamp is raised (which round-1 blocker B3 asks for), this banner is the first thing that breaks.** At a true AX5 ≈3.1×, 12pt → 37pt, ≈7 wrapped lines ≈ 373pt of banner. On a 568pt-tall SE, minus the 56pt nav bar and safe areas, the `Expanded` remainder goes to roughly 120pt — and if the banner's intrinsic height ever exceeds the column's constraints, `Expanded` resolves to zero and the `Column` **overflows**. Whoever raises the clamp must cap this banner (2–3 `maxLines` with a "Details" affordance, or make it scrollable) in the same change.
3. The `Icon(..., size: 18)` at `:149` is a fixed size and does **not** scale with text — at 3.1× the warning glyph is visually negligible next to 37pt text. Cosmetic, but it is the icon that signals "warning" pre-literately.

### C. The banner to a screen reader — ❌, three defects

Placement is right: the banner is the **first child of the shell's body `Column`** (`main_shell.dart:64`), so in VoiceOver's reading order it precedes every screen's content on every tab. It emits exactly one text node; the bare `Icon` correctly emits none. That is where the good news stops.

1. **It is announced to nobody when it appears.** `markServingDemoData()` fires from a provider's `catch` branch *after a 5-second API timeout* (`lib/providers/app_provider.dart:250-260`, `my_care_provider.dart:49-50`, `medication_provider.dart:191`, `:236`, `billing_provider.dart:43`, `orders_provider.dart:199`). By then the user has already been reading the sample screen for five seconds. The `ValueListenableBuilder` at `main_shell.dart:137-140` swaps a `SizedBox.shrink()` for the banner with **no `liveRegion: true` and no `SemanticsService.announce`** — and there are **zero** of either anywhere in `lib/` (`rg -c liveRegion lib` → 0; `rg -c SemanticsService lib` → 0). A VoiceOver user who does not swipe back to the top of the screen is never told. This is precisely the "difference between a patient trusting a fake vital and not" that the brief names, and the banner does not currently make it.
2. **It is hardcoded English.** `main_shell.dart:153-154` is a raw Dart string literal, in the *same widget* where all five tab labels go through `l.t('tab_home')`…`l.t('tab_more')` (`:96-116`) and where `hi.json` supplies `"होम" / "मेरी देखभाल" / "सेवाएं" / "बिलिंग" / "और"`. A Hindi-locale patient in Delhi NCR gets a fully Hindi navigation bar and an English-only warning that their medical data is fake. This violates the project's own contract (CLAUDE.md, i18n section) and the `i18n_sync_test` guard cannot catch it because there is no key to be out of sync.
3. **It is not a header.** No `Semantics(header: true)`, so it does not appear in VoiceOver's heading rotor — the one navigation aid that would let a user check "is this real data?" without linear-swiping.

### D. The banner's coverage — ❌, seven paths bypass it, and one path turns it off

The mechanism is a **single un-counted boolean latch** (`lib/data/demo_mode.dart:16-27`). Two consequences:

**(i) Seven sample-data paths never set it.**

| Site | What it serves | Marks? |
|---|---|---|
| `lib/providers/app_provider.dart:137-138` | `_currentPatient = DemoData.patient` — the **patient identity itself** | **no** |
| `lib/providers/blog_provider.dart:38` | article list fallback | **no** |
| `lib/providers/blog_provider.dart:68` | single-article fallback | **no** |
| `lib/screens/settings/patient_profile_screen.dart:898` | `DemoData.medicalHistory` — **clinical history** | **no** |
| `lib/screens/my_care/widgets/doctor_advice_card.dart:46` | `DemoData.doctorRecommendations` — **doctor's advice** | **no** |
| `lib/screens/care_team/care_team_screen.dart:29`, `:31`, `:162-164` | supervisor + past staff | **no** |
| `lib/screens/calendar/care_calendar_screen.dart:1324` | `DemoData.icuServiceDetail.staffOnDuty` | **no** |

The four screen-level ones are worse than the provider ones: they read `DemoData` **unconditionally**, not as a fallback. Sample medical history and sample doctor recommendations render regardless of backend state, and the banner has no way to know.

**(ii) One successful endpoint takes the banner down for the whole app.**
`lib/providers/app_provider.dart:247` calls `DemoMode.reset()` when the *dashboard* API succeeds. `reset()` is unconditional (`demo_mode.dart:25-27`) — there is no reference count and no record of *which* provider is still serving demo data. So: dashboard succeeds → banner disappears → `MedicationProvider` is still serving `DemoData` medicines from its own `catch` at `:191` → the patient sees a sample medication schedule **with the honesty banner explicitly withdrawn**. The mechanism actively asserts the data is real.

**Fix:** replace the boolean with a `Set<String>` of provider ids; `markServingDemoData('medications')` / `clearDemoData('dashboard')`; banner shows while the set is non-empty and names the domains. Add `markServingDemoData` to the seven sites above.

**Also:** there is no widget test for the banner. `rg -l "DemoMode" test/` returns one file, `test/providers/patient_scope_isolation_test.dart`, which uses `reset()` as fixture teardown. The banner's visibility logic, its reset race, and its contrast are all untested.

### E. `delete_account_screen.dart` — touch targets, labelling, focus, separation

**Touch targets — ✅ all pass.**

| Control | file:line | Measured |
|---|---|---|
| "I understand" checkbox | `:185-194` | `CheckboxListTile` → `Checkbox` default 48×48 tap target (M3, `materialTapTargetSize` not overridden) ✅ |
| Type-DELETE field | `:199-208` | `OutlineInputBorder` default content padding → ≈56pt tall ✅ |
| "Delete my account" | `:210-228` | explicit `SizedBox(height: 48)` ✅ |
| Dialog "Keep my account" / "Delete" | `:81-115` | `TextButton`/`ElevatedButton` under M3 padded tap target → 48pt min ✅ |

**Labelling of the type-DELETE field — ❌.**
```dart
decoration: const InputDecoration(
  border: OutlineInputBorder(),
  hintText: _confirmWord,          // 'DELETE'
),                                  // delete_account_screen.dart:203-206
```
There is no `labelText`, no `Semantics(label:)`, and no `TextField(...)`-to-`Text` association. The instruction `Text('Type DELETE to confirm')` at `:196` is an **independent, unlinked semantics node**. VoiceOver therefore announces the field as roughly *"DELETE, text field"* — the confirmation word read as though it were the field's name, or worse, as though the field already contained it. A user who reaches the field by direct touch or rotor (rather than linear swiping past `:196`) has no way to know what to type. **Fix:** `labelText: 'Type $_confirmWord to confirm'` on the decoration and delete the loose `Text` at `:196`.

**Contrast — ❌ (new).** `foregroundColor: Colors.white` on `backgroundColor: context.hc.error` at both `:107-108` (dialog "Delete") and `:214-216` (main button):

| Appearance | Fill | Ink | Ratio | Required |
|---|---|---|---|---|
| Light | `hc.error` `#D32F2F` | `#FFFFFF` | **4.98 : 1** | 4.5 ✅ |
| Dark | `hc.error` `#EF5350` | `#FFFFFF` | **3.49 : 1** | 4.5 ❌ |

The button label is 16px/w600 from `elevatedButtonTheme` (`lib/config/theme.dart:238-240`). 16 logical px is below the 18.66px (14pt bold) large-text threshold, so 4.5:1 applies and dark mode misses it. This is the checklist red flag *"White text hardcoded onto a brand colour"* reproduced on a **second** colour — `HcPalette` has an `onOrange` pairing token but **no `onError`**, so the new code had nothing to reach for and hardcoded `Colors.white` three times (`:108`, `:216`, `:224`). Round 1's recommendation was to add paired tokens; round 2 added a new unpaired hardcode instead. **Fix:** add `onError` to `HcPalette` (`#FFFFFF` light / `#1C1C1E` dark, or darken dark-mode `error` to `#C62828`).

The disabled branch — `backgroundColor: _canSubmit ? hc.error : hc.grey` at `:214-215` — is **dead code**. `ElevatedButton.styleFrom` sets no `disabledBackgroundColor`, so when `onPressed` is null (`:218`) the property resolves to null and falls through to the M3 default (`onSurface` @12% fill, @38% ink, ≈2.3:1). Disabled controls are exempt from WCAG 1.4.3, so this is not a violation — but the code reads as if `hc.grey` were the disabled colour and it is not, and the real disabled state is near-invisible to an elderly user trying to work out why the button does nothing.

**Focus order — ✅ with one gap.** The body is a linear `ListView` (`:133`); DOM order equals visual order equals traversal order: intro → "What gets deleted" → "What we must keep" → call-us note → checkbox → instruction → field → button. Correct. Both dialogs are standard `AlertDialog`s with a `title`, so Flutter's `namesRoute`/`scopesRoute` semantics announce them on push. The gap: `_submitDeletionRequest` (`:53-89`) sets `_isSubmitting`, shows an unlabelled `CircularProgressIndicator` (`:223-224`, no `semanticsLabel`), waits 600ms, wipes the session, and *then* pushes the result dialog — a **600ms silent window** after the most consequential tap in the app.

**Destructive separation — ✅ on-screen, ⚠️ at the entry point.**
On the screen itself the separation is genuinely good: the destructive button is the last element, 24pt below the field (`:209`), and is triple-gated (checkbox ∧ typed word ∧ a confirm dialog). Nothing habitual is near it. This is the best-designed destructive flow in the app.

But the **route into it** is not:
```
lib/screens/settings/settings_screen.dart:263-279
  _settingsTile( title: l.t('logout'),        textColor: context.hc.error, … )
  const Divider(height: 1)
  _settingsTile( title: 'Delete account',     textColor: context.hc.error, … )
```
"Logout" — the habitual action — and "Delete account" — the destructive one — are **adjacent list tiles separated by a 1px divider**, in the **same red** (`#D32F2F` light / `#EF5350` dark), with the same tile geometry and both leading with a person-shaped icon (`Icons.person_remove_outlined`). Only the text distinguishes them, so this is not *meaning-by-colour-alone*, and a mistap navigates rather than deletes. But for a low-vision or motor-impaired user this is exactly checklist §3.2. **Fix:** a `SizedBox(height: 24)` and a section break, or move Delete account under a "Danger zone" header.

Two more on that line: `title: 'Delete account'` at `:276` is **hardcoded English** directly beneath `l.t('logout')` at `:265`; and `delete_account_screen.dart` contains **zero** `AppLocalizations` references across 247 lines of patient-facing legal copy about erasure rights. A Hindi-only user cannot read the screen that exercises their DPDP §12 right.

**Test coverage — ❌.** `rg -l DeleteAccountScreen test/` → nothing. The screen is absent from `test/screens/overflow_smoke_test.dart` (which covers 37 screens × 320/375/414). The app's newest legally-required flow has no overflow guard, no dark-mode guard, and no widget test.

### F. Did the five-tab nav change the contrast or target-size maths? — No contrast change; targets improved

The nav was restructured (`main_shell.dart:79-121`): a `Material(color: context.hc.orange)` now provides the surface, the `BottomNavigationBar` is `backgroundColor: Colors.transparent, elevation: 0`, and a `SafeArea(top: false)` sits between them.

- **Contrast: unchanged.** The composite fill is still exactly `#F39314` (an opaque `Material` under a transparent bar). Selected items `context.hc.onOrange` = `#FFFFFF` → **2.33:1**. Unselected `onOrange.withValues(alpha: 0.7)` composites to `#FBDFB8` → **1.82:1**. Both figures are byte-identical to round 1. The owner override on white-on-orange is noted; these are reported as measured fact, not as a demand to reverse.
- **Targets: improved.** `BottomNavigationBarType.fixed` with 5 items at 320pt gives **64 × 56 pt** per item (`kBottomNavigationBarHeight` = 56). At the historical 6 tabs it was 53.3 × 56 — both clear 44pt, so no pass/fail flipped, but the margin widened by 20%.
- **Untested at scale.** `test/screens/main_shell_test.dart:269-274` asserts no overflow at 320×568 — at **default text scale only**. With `type: fixed`, `selectedFontSize` 14 → 19.6 at the app's 1.4× cap, inside a 64pt slot, with Hindi labels like `"मेरी देखभाल"`. Flutter's `BottomNavigationBar` compensates by shrinking vertical padding, but nothing in the suite proves it. **Fix:** add a `textScaler: TextScaler.linear(1.4)` case to that test — it is a three-line change and it is the app's most-touched control.
- **Stale in-code comment:** `main_shell.dart:55-56` still says *"Liquid Glass: the body extends behind the translucent nav bar"*, contradicted 20 lines below by `:74-78` ("Stays SOLID BRAND ORANGE"). The bar is opaque.
- **Stale docs (still six tabs):** `docs/ARCHITECTURE.md:68` — *"(6 tabs: Home/My Care/Services/Calendar/Billing/More)"*; `docs/SCREEN_MAP.md:6` — *"MainShell -- 6 tabs"*. Also `lib/screens/services/service_catalog_screen.dart:127` says "6 tab bodies" where there are 7. No **test** asserts six tabs — `test/screens/main_shell_test.dart:228` correctly asserts five and no Calendar tab. ✅

### G. Icon-button re-count — it did not grow ✅

Brace-matched inventory of `lib/screens` + `lib/widgets`, excluding `IconButton.styleFrom`, counting a control as labelled if it carries `tooltip:` / `semanticLabel` or sits inside an enclosing `Semantics(`:

**54 `IconButton` constructors · 37 labelled · 17 unlabelled (31%) — identical to round 1.**

`delete_account_screen.dart` and the banner introduce **zero** new `IconButton`s, so the count held. The 17 are the same 17:

| file:line | Control |
|---|---|
| `lib/screens/my_care/widgets/health_manager_banner.dart:69` / `:80` | **Call** / **Message the health manager** — two visually identical circles, different destinations |
| `lib/screens/chat/chat_screen.dart:335` / `:304` | **Send message** / attach photo |
| `lib/screens/my_care/add_edit_medication_screen.dart:92` | **Delete medication** (destructive) |
| `lib/screens/settings/patient_profile_screen.dart:693` / `:834` / `:772` | Remove emergency contact (destructive) / remove medication (destructive) / add condition |
| `lib/screens/services/service_booking_screen.dart:1018` / `:1037` / `:327` | Decrease / increase sessions / back a wizard step |
| `lib/screens/documents/document_repository_screen.dart:167` / `:390` | Toggle search / close sheet |
| `lib/screens/settings/add_patient_screen.dart:273` | Add condition |
| `lib/screens/settings/family_members_screen.dart:123`, `lib/screens/search/universal_search_screen.dart:284`, `lib/screens/settings/help_faq_screen.dart:199` | Close sheet / clear query |

Two round-2 improvements worth crediting, both outside this count: `lib/screens/cart/cart_screen.dart:977-984` (saved-item remove gained both a tooltip and 44×44 constraints) and `lib/screens/calendar/care_calendar_screen.dart:1308-1310` (delete-reminder gained `tooltip: 'Delete reminder'` — though it still fires with no confirm).

---

## Findings

### 1. Contrast

- ❌ **Text meets 4.5:1 against its actual background (3:1 for ≥18pt bold / ≥24pt regular).** Unchanged, plus one new failure.

  ```
  relative luminance #F39314 = 0.39969 ; #FFFFFF = 1.00000
  contrast = (1.00 + 0.05) / (0.39969 + 0.05) = 2.33 : 1
  ```
  There is no size at which white-on-`#F39314` passes any AA threshold.

  | Surface | file:line | Fill | Ink | Ratio |
  |---|---|---|---|---|
  | Bottom nav — selected | `lib/screens/main_shell.dart:90` | `#F39314` | `#FFFFFF` | **2.33 : 1** |
  | Bottom nav — unselected | `lib/screens/main_shell.dart:91` | `#F39314` | `#FBDFB8` (70% α) | **1.82 : 1** |
  | Every primary `ElevatedButton` | `lib/config/theme.dart:228-241` (light), `:413-426` (dark) | `#F39314` | `#FFFFFF` | **2.33 : 1** |
  | `colorScheme.onPrimary` | `lib/config/theme.dart:160`, `:340` | `#F39314` | `#FFFFFF` | **2.33 : 1** |
  | Round call/chat buttons | `lib/screens/home/home_screen.dart:822`, `:1871`; `lib/screens/care_team/care_team_screen.dart:287`; `lib/screens/chat/chat_screen.dart:337` | `#F39314` | white icon | **2.33 : 1** |
  | **NEW** — delete-account buttons, dark | `lib/screens/settings/delete_account_screen.dart:107-108`, `:214-216` | `hc.error` `#EF5350` | `Colors.white` | **3.49 : 1** |
  | Hero gradient stops | `lib/config/app_colors.dart:31-32` | `#FF8C00` / `#FF6B35` | white | 2.33 / 2.84 |

  **Owner override noted** for white-on-orange (CLAUDE.md design-system contract): reported as measured fact, not as a request to reverse. The **dark `#EF5350` failure is not covered by that override** — it is new code on a status colour, not the brand fill.

  Passing neutrals, for contrast: `#212121` on `#F8F9FA` = 10.30:1; dark `#F2F2F2` on `#1C1C1E` = 15.20:1; the new banner at 14.68:1 / 11.98:1. The failure is confined to filled brand/status surfaces.
  Secondary: `HousepitalColorsDark.textDisabled` `#7A7A7A` on card `#1C1C1E` = **3.96:1** (`lib/config/theme.dart:25` claims "4.2:1 on card").

  **Fix:** add `orangeFillText = #AA670E` (4.51:1) for text-bearing orange fills, keep `#F39314` for textless decorative fills, keep the white ink. Add an `onError` pairing token, or darken dark-mode `error` to `#C62828` (white → 5.9:1).

- ❌ **Non-text UI (icons, chart slices, meaningful borders) meets 3:1.** Unchanged.
  Orange icon on white = **2.33:1**; on `orangeLight #FFF3E0` = **2.13:1**. Light divider `#E0E0E0` on white = **1.32:1** (`lib/config/theme.dart:82`); dark divider `#2A2A2C` on true black = **1.47:1** (`:19`) — these carry the card and vitals-pill structure (`lib/screens/my_care/my_care_screen.dart:405`). Segmented-control thumb `black @8%` on `greyLighter` = **1.17:1** light / **1.27:1** dark (`lib/screens/calendar/care_calendar_screen.dart:357-360`) — mitigated by a declared `selected` trait and a text label, but visually near-invisible. `orangeMuted #3D2A12` on true black = **1.54:1**.

- ❌ **Contrast verified in BOTH appearances, programmatically in a unit test.** Unchanged — the round-1 blocker.
  `rg -c "contrast|luminance|Luminance" test/` → **0** across the entire 1,797-test suite. `test/widgets/dark_mode_test.dart` *does* resolve both appearances (`:38`, `:51`) but every assertion is token **identity** (`expect(p.black, HousepitalColorsDark.textPrimary)`), never a computed ratio. It proves the resolver flips; it cannot detect that the value it flips *to* is 2.33:1 — or that round-2 code added a 3.49:1. **Fix:** `test/widgets/contrast_test.dart` with a `Color.computeLuminance()`-based `contrastRatio(a, b)`, asserting every foreground/background pair in `HcPalette.light()` **and** `.dark()` against 4.5/3.0, seeded with the pairs in this report so it starts red on the known failures rather than silently green.

- ❌ **Filled elements use a PAIRED foreground that flips with appearance — never hardcoded white on a brand colour.** **Regressed.**
  `HousepitalColors.onOrange = #FFFFFF` (`lib/config/theme.dart:70`) **and** `HousepitalColorsDark.onOrange = #FFFFFF` (`:32`) — the pairing token exists and is plumbed through `HcPalette` (`lib/config/app_colors.dart:66-69`, `:95`, `:123`), but both arms resolve to the same white, so the flip is a no-op. **Owner override noted.**
  The regression: `HcPalette` has **no `onError` token**, so `delete_account_screen.dart` hardcoded `Colors.white` on `hc.error` three times (`:108`, `:216`, `:224`). Raw `Colors.white` in `lib/screens` + `lib/widgets` rose from 132 to **135**; those three are the delta.

- ⚠️ **Text over images/gradients has a scrim or is measured against the worst pixel.** Unchanged.
  Promo banner does it correctly — `Colors.black.withValues(alpha: 0.45)` (`lib/screens/home/home_screen.dart:600-602`); worst case (pure-white photo) → white on `#8C8C8C` = **3.36:1**, passing 3:1 for the large title, missing 4.5:1 for the subtitle (0.55 α would give 4.7:1). `GlassSurface` (`lib/widgets/glass.dart:139-152`) is a 24σ blur under **0.55 α** over arbitrary scrolling content with no scrim: light bar over dark content → `#8C8C8C`, primary ink holds at 4.79:1 ✅ but **orange app-bar glyphs drop to 1.44:1** ❌; dark bar over a white photo → `#828283`, `#F2F2F2` title = **3.43:1** ❌ against the 4.5 needed for the 20pt/w600 title.

### 2. Dynamic Type

- ❌ **Busiest three screens exercised at AX5.** Unchanged — round-1 blocker.
  `lib/main.dart:425-428` still clamps `maxScaleFactor: 1.4`. iOS AX5 ≈3.1×, so AX1–AX5 all collapse to 1.4× and the app **never renders any accessibility text size**. The in-code comment at `:420-421` cites "WCAG 1.4.4", which requires **200%**; 1.4× is 140%, so it fails the standard it names. `rg "textScaler|TextScaler" test/` → **0**; no screen is exercised at any scale. `test/screens/overflow_smoke_test.dart` varies width only (320/375/414). For an app whose core demographic is elderly home-care patients, this is the single highest-impact item on the checklist.

- ❌ **Every text style comes from the type system, not fixed point sizes.** **Regressed 957 → 971.**
  `rg -o "fontSize:\s*[0-9.]+" lib/screens lib/widgets | wc -l` = **971**; `rg -o "textTheme\." lib/screens lib/widgets | wc -l` = **0**. The `TextTheme` at `lib/config/theme.dart:170-215` / `:360-395` remains entirely dead. The +14 are the new screens: `delete_account_screen.dart` alone hardcodes 10 (`:139`, `:148`, `:167`, `:182`, `:192`, `:197`, `:242`, …) and the banner one (`:156`). The design gate prints a fontSize histogram but is echo-only (`scripts/check_design_consistency.sh`, "informational — does not affect pass/fail"). Sub-finding unchanged: `lib/screens/calendar/care_calendar_screen.dart:817` uses `fontSize: 9.5`, below the app's own documented 11px minimum.

- ❌ **`minimumScaleFactor` / line limits are a last resort with a floor (≥ ~0.7).** Partially improved, still failing.
  `FittedBox(fit: BoxFit.scaleDown)` sites fell from 14 to **10** — but **none of the ten has a floor**, and `BoxFit.scaleDown` shrinks without limit. Remaining: `lib/screens/reports/vitals_screen.dart:284`, `lib/screens/my_care/my_care_screen.dart:412`, `lib/screens/services/cards/equipment_item_card.dart:128`/`:164`/`:182`, `lib/screens/calendar/care_calendar_screen.dart:838`/`:840`, `lib/screens/services/service_catalog_screen.dart:151`, `lib/screens/services/widgets/equipment_category_rail.dart:320`, `lib/screens/my_care/service_detail_screen.dart:485`.

- ❌ **Numbers users act on (money, dates, doses) remain fully readable at AX sizes.** Unchanged — the checklist's own red flag, verbatim.
  - `lib/screens/services/cards/equipment_item_card.dart:127-128` — discounted **price row** inside a fixed-height box under floorless `scaleDown`.
  - `lib/screens/services/cards/equipment_item_card.dart:181-182` — **price**, same treatment.
  - `lib/screens/my_care/my_care_screen.dart:401-412` — the **vitals value** (heart rate, BP, SpO₂) in a fixed `width: 90` / `height: 88` pill under `scaleDown`. A clinical number that shrinks. The comment at `:407-408` explicitly says the real font "fits the 90×88 pill at scale 1" — i.e. the design is calibrated to exactly one text size.
  - `lib/screens/reports/vitals_screen.dart:284` — the vitals **hero value** under `scaleDown`.

- ❌ **Container heights are not hardcoded around one text size.** Unchanged.
  `rg -o "height: [0-9]+" lib | wc -l` ≈ 1,080. Text-bearing examples above, plus `lib/screens/my_care/service_detail_screen.dart:459-462` (44pt pill wrapping a `FittedBox` label) and `lib/screens/calendar/care_calendar_screen.dart:355` (`Container(height: 44)` segmented control). The new `SizedBox(height: 48)` at `delete_account_screen.dart:210` is a text-bearing fixed height too — benign at 1.4× (16px label → 22.4px in 48pt), but it would clip at a true AX size.

### 3. Touch targets

- ❌ **Every tappable element is ≥44×44pt including padding.** 1 of 7 fixed.
  *Flutter caveat first:* both themes set `useMaterial3: true` and neither overrides `materialTapTargetSize`, so `IconButton` keeps its 48×48 `_InputPadding` hit region even with zeroed `padding`/`constraints`; there are zero `MaterialTapTargetSize.shrinkWrap` in the codebase. The violations are all **raw gesture widgets**, which get no such padding.

  | # | file:line | Control | Measured | Round 2 |
  |---|---|---|---|---|
  | 1 | `lib/widgets/document_attach_widgets.dart:47-50` | `GestureDetector` → bare `Icon(size: 18)`, remove attachment | **18 × 18** | unchanged ❌ |
  | 2 | `lib/screens/support/raise_concern_screen.dart:230-240` | remove evidence photo; `padding: all(4)` + `Icon(size: 14)`, `Positioned(top:2,right:2)` overlaps the thumbnail | **22 × 22** | unchanged ❌ |
  | 3 | `lib/screens/cart/cart_screen.dart:883-888` (`_qtyButton`) | **cart quantity stepper**; `Padding(all(4))` + `Icon(size: 16)` | **24 × 24** | unchanged ❌ |
  | 4 | `lib/screens/billing/payment_screen.dart:864-874` | GST explainer `InkWell`; `Padding(all(4))` + `Icon(size: 16)` | **24 × 24** | unchanged ❌ (moved from `:803`) |
  | 5 | `lib/screens/articles/article_list_screen.dart:188-194` (`_FilterChip`) | `InkWell` + `vertical: 8` on 12pt text | ≈ **32pt** tall | unchanged ❌ |
  | 6 | `lib/screens/calendar/care_calendar_screen.dart:355` | Day/Week/Month/Year segmented control; `height: 44` minus `padding: all(4)` | ≈ **36pt** tall | unchanged ❌ |
  | 7 | `lib/screens/calendar/care_calendar_screen.dart:551` (`_dayCell`) | calendar day cell; `crossAxisCount: 7`, `childAspectRatio: 0.82`, `gridHPad = 8` under 360pt | **43.4 × 52.9 at 320pt** | unchanged ❌ |
  | — | `lib/screens/cart/cart_screen.dart:977-984` | saved-item remove | **44 × 44** | **FIXED ✅** |

  Violation #3 remains the sharpest: `lib/screens/services/widgets/quantity_button.dart:44` already implements the correct 44pt-reserved stepper with an explicit Apple-HIG comment, and the cart hand-rolls a 24×24 one instead.
  **New code passes:** every control on `delete_account_screen.dart` clears 44pt (see §E). **Nav improved:** 64×56 per item at 320pt with five tabs.

- ❌ **Destructive actions are not adjacent to habitual ones without spacing or a confirm.** Unchanged, plus one new.
  `confirmDestructiveAction` (`lib/widgets/common_widgets.dart:501`) still has exactly **8** call sites (`patient_profile_screen.dart:230`, `family_members_screen.dart:57`, `address_selection_screen.dart:167`, `cart_screen.dart:606`, `:866`, `add_edit_medication_screen.dart:259`, `document_repository_screen.dart:528`, `my_orders_screen.dart:741`) and the same three destructive actions bypass it:

  | Action | file:line | Problem |
  |---|---|---|
  | **Delete reminder** | `lib/screens/calendar/care_calendar_screen.dart:1308-1314` | `RemindersProvider.delete(r.id)` fires immediately. No confirm, no undo, persisted (`lib/providers/reminders_provider.dart:150`). `SizedBox(width: 4)` from the card body. *(Gained a tooltip in round 2 — the label is fixed, the confirm is not.)* |
  | **Remove saved-for-later item** | `lib/screens/cart/cart_screen.dart:981` | `cart.removeSaved(index)` unconfirmed, 4pt from the habitual **"Move to Cart"** button. The sibling *cart* remove at `:866` **is** confirmed — still inconsistent. *(Target and tooltip fixed in round 2; the confirm is not.)* |
  | **Remove emergency contact** | `lib/screens/settings/patient_profile_screen.dart:144-150`, button `:693` | `_removeEmergencyContact` unconfirmed, while `_removeMedication` on the **same screen with an identical affordance** *is* confirmed (`:230`). |
  | **NEW — Delete account tile** | `lib/screens/settings/settings_screen.dart:263-279` | Sits 1px (`Divider(height: 1)`) below **Logout**, same red, same tile shape, same person-icon family. Mistap navigates rather than deletes, so ⚠️ not ❌ on its own — but it is a new instance of the pattern. |

- ⚠️ **Rows with MULTIPLE buttons use explicit per-button styles so one tap fires one action.** Unchanged.
  The iOS "row-level default style fires every button" bug has no Flutter analogue; the equivalent hazard — **nested tap targets with different destinations** — is present at 6 sites, two of them serious. `lib/screens/home/home_screen.dart:774` — an `InkWell(onTap: → /chat)` wraps the entire care-team row, which also contains a `tel:` `IconButton` (`:818`) and a chat `IconButton` (`:839`) separated by `SizedBox(width: 4)`; a tap 1–2pt outside the call button's ink area **silently opens chat instead of placing a call**. Same pattern at `lib/screens/care_team/care_team_screen.dart:282-317`. `lib/screens/auth/login_screen.dart:183` — an `InkWell` toggles the **consent checkbox** while two unpadded 13pt inline "Terms"/"Privacy" links sit inside it (`:214`, `:234`); a near-miss on a link toggles consent.

- ❌ **Gestures have visible-button equivalents.** **Unchanged — round-1 Blocker B5 did not land.**
  `lib/screens/settings/family_members_screen.dart:319-341`. Removing a family member — a role/permission-bearing entity that routes notifications — is reachable **only** by `Dismissible(direction: endToStart)`. `_showDeleteConfirmation` has exactly one caller: `:336`, inside `confirmDismiss`. `_buildMemberCard` (`:344+`) has no trailing `IconButton`, no `PopupMenuButton`, no `onTap`. Unreachable via VoiceOver, Switch Control, or keyboard — WCAG 2.1 §2.5.1 and §2.1.1. The `confirmDismiss` correctly returns `false` and defers to a dialog, so the *confirmation* is right and the *discoverability* is not. **Fix:** a trailing overflow `IconButton` gated by the same `canManage` check at `:317`, calling `_showDeleteConfirmation`.
  Non-issues re-confirmed: zero `onLongPress`, zero `onHorizontalDrag`, zero `ReorderableListView`, zero `Draggable` in `lib/`.

### 4. Screen reader (VoiceOver / TalkBack)

- ❌ **Every icon-only control has an accessibility label that says what it DOES.** Unchanged at **17 of 54 (31%)** — see §G for the full table. It did not grow; the new screens added no icon buttons. The two `health_manager_banner.dart` buttons (`:69`, `:80`) remain the most damaging — two visually identical circular tiles, one dials a phone and one opens chat, indistinguishable to a screen-reader user. **Fix:** add `tooltip:` (Flutter promotes it to the semantic label) to all 17 — one line each. The house pattern is already correct in `lib/widgets/glass.dart:62`/`:78`/`:110` and `lib/screens/cart/cart_screen.dart:860`.

- ⚠️ **Rows read as one sentence (label + value + state).** Unchanged, plus one new.
  ✅ `StatusBadge` renders text **and** wraps it in `Semantics('Status: $text')` (`lib/widgets/common_widgets.dart:237`). ✅ `lib/screens/my_care/medications_screen.dart:220-235` — per-dot `Semantics` on the 7-day adherence strip; this is the template.
  ❌ `lib/screens/my_care/my_care_screen.dart:378-441` (`_vitalPill`) — the `InkWell` has **no `Semantics` label**, so VoiceOver reads three loose fragments ("Heart rate" / "78" / "bpm") and **never announces the green/yellow/red clinical status** (`:379-386`, dot at `:420-427`).
  ⚠️ `lib/screens/my_care/widgets/vitals_trend_grid.dart:64` — label is `'$title, ${card.status}'`, omitting the numeric reading.
  ❌ **NEW** — `delete_account_screen.dart:196` + `:199-208`: the instruction and the field it governs are two unlinked nodes; the field's only accessible name is the hint `"DELETE"`.

- ⚠️ **Charts expose a text summary; the visual is hidden, the summary is not.** Unchanged — the summary half is done well everywhere, the hiding half nowhere.
  `lib/screens/reports/vitals_screen.dart:345` (`fl_chart LineChart`) has a rich text equivalent — hero value `:291`, unit, "Latest reading" + date, Average/Highest/Lowest cards `:464-468`, prose insights `:536-552` — but is **not** `ExcludeSemantics`-wrapped, so axis-tick `Text` widgets at `:361`/`:377` leak as bare context-free nodes. Same for the 24px sparkline (`lib/screens/my_care/widgets/vitals_trend_grid.dart:136`) and 5 `LinearProgressIndicator` gauges (each with a correct adjacent numeric equivalent, none excluded). `lib/widgets/care_pulse_ring.dart:86` is correctly labelled (`'$N percent'`) but still lacks `excludeSemantics: true`, so its `center` child emits a **second node → doubled announcement** at 4 call sites. ~20 `CircularProgressIndicator` carry no `semanticsLabel`, so loading is announced as silence — now including the deletion spinner at `delete_account_screen.dart:223`. Only **3 `ExcludeSemantics`** exist app-wide.

- ⚠️ **Decorative images are hidden from the accessibility tree.** Unchanged; one improvement.
  `ProductImage` labels its **asset** branch (`lib/widgets/common_widgets.dart:131` → `'Product photo'`) but not its **network** branch (`:134`); same asymmetry at `lib/screens/services/cards/equipment_item_card.dart:218` vs `:225` and `lib/screens/services/equipment_detail_screen.dart:448`/`:458`/`:1895`/`:1905`. Practical impact is low (`CachedNetworkImage` emits no semantics node by default), but identical content announces differently depending on bundling. Credit: `lib/screens/support/raise_concern_screen.dart:223-225` now carries `semanticLabel: 'Evidence photo N of M'`. 293 bare `Icon(Icons.*)` with no `semanticLabel` is correct-by-default in Flutter.

- ✅ **Custom controls declare traits (button, selected, adjustable).** Unchanged, still the strongest screen-reader area. 72 `Semantics(` sites: calendar segmented control declares `button: true, selected: selected, label: '$label view'` (`lib/screens/calendar/care_calendar_screen.dart:351-354`); `StatusBadge` `:237`; SOS button carries `label:` + `button: true` + an interaction hint (`lib/widgets/common_widgets.dart:593-595`); star rating, assistant FAB, quantity button, category rail and ~20 others. `article_list_screen.dart:180-182` declares `button: true, selected: isSelected, label: 'Filter by $label'`.

- ❌ **Sheet/alert focus lands on the meaningful element; focus order follows visual order.** Unchanged.
  **25 `showModalBottomSheet`** in `lib/`, and app-wide exactly **1** focus-management site (`lib/screens/documents/document_repository_screen.dart:158` `autofocus: true`) — down from 2. **Zero** `FocusScope`, **zero** `FocusTraversalGroup`, **zero** `SemanticsService.announce`, **zero** `liveRegion`. Opening any of the 25 sheets leaves screen-reader focus unmanaged, and asynchronous state changes (cart updated, booking confirmed, **sample-data banner appearing**, **account deletion submitted**) are never announced. Round-2 code added two more silent async transitions (`delete_account_screen.dart:59-68`, `main_shell.dart:137-140`). `delete_account_screen`'s own linear `ListView` order is correct ✅.

- **BLOCKED-OWNER** — **One full screen-reader pass of the top three flows per release, on a real device, eyes closed.** No artifact exists in the repo; `docs/audits/` holds six audits, none a device a11y pass. **To clear this I need:** the owner or a tester to run VoiceOver on a physical iPhone through (1) Home → book a service → cart → checkout, (2) My Care → vitals → care calendar, (3) Settings → Delete account → confirm, recording pass/fail per step. Static analysis cannot substitute. Flow (3) is newly in scope this round.

### 5. Motion, sound & state

- ⚠️ **Reduce Motion is honoured.** Unchanged.
  **13 `lib/` sites gate on `MediaQuery.of(context).disableAnimations`** — across `care_calendar_screen.dart` (4), `payment_screen.dart:256`, `billing_screen.dart:156`, `medications_screen.dart:329`, `staff_otp_verification_screen.dart:105`, `my_care_screen.dart:101`, `medication_schedule_screen.dart:322`, `equipment_tab.dart:267`, `booking_confirmation_screen.dart:126`, `order_tracking_screen.dart:120`, `care_pulse_ring.dart:84`. **Zero `.repeat()` anywhere.** Two gaps remain:
  - `lib/screens/services/equipment_detail_screen.dart:1690-1694` — a 250ms `AnimationController` with **no `disableAnimations` check**.
  - `lib/screens/calendar/care_calendar_screen.dart:357` — `AnimatedContainer(duration: 150ms)` on the segmented thumb, ungated, while four animations on the same screen are gated.
  The new banner and delete screen introduce no animation ✅.

- ✅ **No information arrives ONLY as a haptic or ONLY as a sound.** Unchanged. All 8 `HapticFeedback` sites accompany a visible state change; no audio-only signals in `lib/`.

- ✅ **Nothing flashes more than 3×/second; auto-advancing content can be paused.** Unchanged. Zero `.repeat()`; fastest animation is a 100ms one-shot. The home promo banner is a **manual** `PageView.builder` with no autoplay timer. The 6 `Timer.periodic` instances are data/state timers; none drives a visual flash.

- ✅ **Time-limited flows are generous or extendable.** Unchanged. `lib/screens/auth/otp_screen.dart:25` — 300s OTP expiry with a lock-and-resend path and a 30s resend cooldown after which the user can extend indefinitely. Toasts are 3–6s and none is the sole carrier of an action. The new deletion flow has **no** time limit ✅ and offers a 30-day reversal window with a phone number (`delete_account_screen.dart:74-78`) ✅.

### 6. Process

- ❌ **Contrast assertions live in the automated suite and resolve BOTH appearances.** Unchanged — see §1 item 3. Zero contrast/luminance assertions in `test/`. This is the literal parenthetical in the checklist — *"a one-appearance suite once hid a 2.3:1 failure for a full release"* — except here the suite resolves both appearances and **still** hides a 2.33:1 failure, and this round it silently accepted a **new** 3.49:1 one.

- ⚠️ **New colours enter through the design-token system with their pairings; a hardcoded colour in a view is a review flag.** Unchanged; the gaps it leaves were exercised this round.
  The gate is real and currently **passes**. It fails the build on `circular(14)`, `Colors.grey.shade*`, raw Material status hues, `Color(0xFF…)` outside a 9-entry allowlist, raw brand orange as a *text* colour, `CircleAvatar`-wrapping-`Icon`, and retired service-identity colours. Hex literals and named hues are genuinely eradicated from `lib/screens`. But:
  - **`SCAN_DIR="lib/screens"` only** (`scripts/check_design_consistency.sh:17`) — `lib/widgets` is unscanned except by the non-gating histogram, which is why `lib/widgets/glass.dart:147` (`const Color(0xFF1C1C1E)`, not allowlisted) and `lib/widgets/document_attach_widgets.dart:314`/`:316` (`Colors.amber`) survive.
  - **`Colors.white` / `Colors.black` are on no ban list** — line 42 bans only red/blue/green/teal/purple. 181 occurrences across `lib/screens` + `lib/widgets` (white 135, white70 13, black 8, white24 7, black12 7, …). This is exactly why the gate **passed** the three new `Colors.white`-on-`hc.error` hardcodes in `delete_account_screen.dart`, which is inside `SCAN_DIR`.
  - **It has no rule for white-text-on-a-filled-surface**, which is the 2.33:1 and 3.49:1 problem.
  **Fix:** extend `SCAN_DIR` to `lib/widgets`, ban bare `Colors.white`/`Colors.black`, and add a rule keyed on `foregroundColor: Colors.white` paired with any `backgroundColor:` token.

- **BLOCKED-OWNER** — **Accessibility findings get fixed at the same priority as functional bugs of equal user impact.** Round 2 supplies the first real evidence, and it is negative: **ten blockers were closed between `803124d` and `820060b`, and none of the five accessibility blockers was among them** — including B4 (17 silent icon buttons, ~17 one-line edits) and B5 (family-member removal unreachable by screen reader, one trailing button). Whether that reflects triage policy or sequencing is not something the repo can tell me. **To clear this I need:** the owner to confirm the triage policy, and one release cycle of tracker evidence that a11y findings entered the same queue as functional bugs.

---

## Red flags (checklist's own "stop the release" list)

| Red flag | Round 1 | Round 2 | Evidence |
|---|---|---|---|
| Any meaning carried by colour alone | YES | **YES** | `lib/screens/my_care/my_care_screen.dart:420-427`; `lib/screens/home/home_screen.dart:1009`; `lib/screens/calendar/care_calendar_screen.dart:594-607` |
| White text hardcoded onto a brand colour | YES | **YES ×2** | `lib/config/theme.dart:32`, `:70` (`onOrange = #FFFFFF`, 2.33:1, owner override) **and now** `lib/screens/settings/delete_account_screen.dart:108`, `:216` (white on `hc.error`, **3.49:1 dark**, no override) |
| A chart with no textual equivalent | NO | **NO** | Every chart and gauge has an adjacent text equivalent — still the strongest area |
| A control under 44pt because "it fits the design" | YES | **YES** | `lib/widgets/document_attach_widgets.dart:47` (18×18); `lib/screens/cart/cart_screen.dart:883` (24×24) |
| "Looks fine" as the only contrast evidence | YES | **YES** | Zero contrast assertions in `test/`; palette comments still assert ratios the code does not have |

---

## Blockers (must fix before release)

1. **White-on-orange is 2.33:1 across the entire persistent chrome — and round 2 added a second white-on-fill failure.** `lib/screens/main_shell.dart:90`/`:91` (nav, incl. 1.82:1 unselected), `lib/config/theme.dart:228-241`/`:413-426` (every primary CTA), `:160`/`:340` (`onPrimary`) — owner override, reported as fact. **NOT covered by the override:** `lib/screens/settings/delete_account_screen.dart:107-108`, `:214-216` — `Colors.white` on `hc.error` = **3.49:1 in dark mode**, on the button that deletes a medical account. **Fix:** add `onError` to `HcPalette` (or darken dark `error` to `#C62828`); add `orangeFillText = #AA670E` (4.51:1) for text-bearing orange fills.
2. **No contrast assertion exists anywhere in the suite.** `rg "contrast|luminance" test/` → 0, across 1,797 tests. It hid 2.33:1 for the whole release history and this round it silently accepted 3.49:1. **Fix:** `test/widgets/contrast_test.dart` asserting every `HcPalette.light()` **and** `.dark()` pair against 4.5/3.0 via `Color.computeLuminance()`.
3. **Dynamic Type is capped at 1.4× and never tested.** `lib/main.dart:425-428`; zero `textScaler` in `test/`. AX1–AX5 are all suppressed for an elderly-patient app. Note that the **new sample-data banner will be the first casualty** when the clamp is raised — cap it in the same change. **Fix:** raise to ≥2.0 and add `TextScaler.linear(2.0)`/`3.0` axes to `overflow_smoke_test.dart` for Home / My Care / Services.
4. **17 of 54 icon-only buttons are silent to VoiceOver** — unchanged from round 1 — including *call the health manager* and *message the health manager* (`lib/screens/my_care/widgets/health_manager_banner.dart:69`/`:80`, two identical circles with different destinations), *send message* (`lib/screens/chat/chat_screen.dart:335`), and three destructive deletes. **Fix:** `tooltip:` on all 17.
5. **Removing a family member is still swipe-only** (`lib/screens/settings/family_members_screen.dart:319-341`) — unreachable via VoiceOver, Switch Control, or keyboard. Round-1 blocker, unfixed. **Fix:** trailing overflow button gated by the existing `canManage`.
6. **NEW — the sample-data banner does not do the job it was added for.** It is silent when it appears (no `liveRegion`, no `SemanticsService.announce`, `main_shell.dart:137-140`); it is English-only in a Hindi-capable shell (`:153-154`); **seven sample-data paths never raise it** (`app_provider.dart:137-138` — the patient identity itself; `blog_provider.dart:38`/`:68`; `patient_profile_screen.dart:898` — medical history; `doctor_advice_card.dart:46` — doctor's advice; `care_team_screen.dart:29`/`:31`/`:162`; `care_calendar_screen.dart:1324`); and **one successful endpoint takes it down for the whole app** (`app_provider.dart:247` — `DemoMode.reset()` is unconditional and un-counted, so a live dashboard hides the warning while sample medications are still on screen). **Fix:** reference-count by provider id; mark the seven sites; add `liveRegion: true`; move the string into `en.json`/`hi.json`.

## High

7. **Clinical vitals status is colour-only and unlabelled** — `lib/screens/my_care/my_care_screen.dart:378-441`. An 8×8 green/yellow/red dot with no text, no icon, no shape variation, no `Semantics` on the pill. The same classifier is rendered correctly in `lib/screens/reports/vitals_screen.dart:846-869` (distinct icon + localized text) and `lib/screens/my_care/medications_screen.dart:220-235` is the textbook shape+colour+label pattern. Copy either.
8. **Attendance text mislabels four of six statuses** — `lib/screens/home/home_screen.dart:1005-1016` renders `status == 'checked_in' ? 'On Duty' : 'Waiting'` while `AttendanceHelper.getStatusColor` (`lib/utils/helpers.dart:65-82`) returns six distinct colours. *late*, *absent*, *on_leave* and *checked_out* are distinguished by colour only **and are actively mislabelled as "Waiting"**.
9. **Three destructive actions with no confirm**, two of them 4pt from a habitual control — `lib/screens/calendar/care_calendar_screen.dart:1308-1314`, `lib/screens/cart/cart_screen.dart:981`, `lib/screens/settings/patient_profile_screen.dart:144-150`. `confirmDestructiveAction` already exists with 8 correct call sites.
10. **Six touch targets at 18–36pt** — `lib/widgets/document_attach_widgets.dart:47` (18×18), `lib/screens/support/raise_concern_screen.dart:230` (22×22), `lib/screens/cart/cart_screen.dart:883` (24×24 cart stepper), `lib/screens/billing/payment_screen.dart:864` (24×24), `lib/screens/articles/article_list_screen.dart:188` (~32pt), `lib/screens/calendar/care_calendar_screen.dart:355` (~36pt). The correct 44pt stepper already exists at `lib/screens/services/widgets/quantity_button.dart:44`.
11. **Money and vitals shrink instead of the container growing** — `lib/screens/services/cards/equipment_item_card.dart:127-128`/`:181-182`, `lib/screens/my_care/my_care_screen.dart:401-412` (vitals value in a fixed 90×88 pill whose comment admits it is calibrated to scale 1).
12. **Nested tap targets on a call button and a consent checkbox** — `lib/screens/home/home_screen.dart:774` vs `:818`; `lib/screens/auth/login_screen.dart:183` vs `:214`/`:234`.
13. **25 modal sheets with no focus management, and zero `SemanticsService.announce` / `liveRegion` anywhere in `lib/`** — now covering two new async transitions (banner appearance, deletion submission).
14. **NEW — the type-DELETE field has no accessible name** — `lib/screens/settings/delete_account_screen.dart:199-208`. `hintText` only; the instruction at `:196` is an unlinked node. **Fix:** `labelText: 'Type DELETE to confirm'`.
15. **NEW — the whole account-deletion flow is English-only and untested.** Zero `AppLocalizations` in `delete_account_screen.dart` (247 lines of DPDP/erasure copy); `title: 'Delete account'` hardcoded at `settings_screen.dart:276` directly under `l.t('logout')`; zero references in `test/`; absent from `overflow_smoke_test.dart`.

## Medium / Low

16. **NEW** — "Delete account" sits 1px below "Logout", same red, same tile shape (`lib/screens/settings/settings_screen.dart:263-279`). Add a section break.
17. **NEW** — the banner's `Icon(size: 18)` (`main_shell.dart:149`) is fixed and does not scale with text.
18. **NEW** — stale in-code comment: `main_shell.dart:55-56` says the nav bar is "translucent"; `:74-78` and the rendered `Material` say it is solid orange.
19. Stale docs still asserting six tabs / a Calendar tab: `docs/ARCHITECTURE.md:68`, `docs/SCREEN_MAP.md:6`; and `lib/screens/services/service_catalog_screen.dart:127` says "6 tab bodies" where there are 7. No **test** is stale — `test/screens/main_shell_test.dart:228` correctly asserts five tabs and no Calendar tab.
20. `test/screens/main_shell_test.dart:269-274` tests 320×568 at **default text scale only**; add a `TextScaler.linear(1.4)` case.
21. Charts are never `ExcludeSemantics`-wrapped — axis ticks leak as bare nodes (`lib/screens/reports/vitals_screen.dart:361`, `:377`).
22. `lib/widgets/care_pulse_ring.dart:86` lacks `excludeSemantics: true` → percentage announced twice, at 4 call sites.
23. `lib/screens/my_care/widgets/vitals_trend_grid.dart:64` — semantics label omits the numeric reading.
24. `ProductImage` labels its asset branch (`lib/widgets/common_widgets.dart:131`) but not its network branch (`:134`); same asymmetry at 3 other sites.
25. ~20 `CircularProgressIndicator` with no `semanticsLabel` — loading is announced as silence, now including `delete_account_screen.dart:223`.
26. `GlassSurface` at 0.55 α gives no worst-pixel guarantee: dark title over a white photo = **3.43:1**; orange glyphs over dark content = **1.44:1** (`lib/widgets/glass.dart:139-152`).
27. Promo banner scrim is 0.45 α → **3.36:1** worst case; 0.55 α gives 4.7:1 (`lib/screens/home/home_screen.dart:600-602`).
28. Dark `textDisabled` `#7A7A7A` on card `#1C1C1E` = **3.96:1**, not the 4.2:1 its comment claims (`lib/config/theme.dart:25`).
29. Dividers carry structure at **1.32:1** light / **1.47:1** dark; segmented thumb at **1.17:1** / **1.27:1**.
30. Two ungated animations — `lib/screens/services/equipment_detail_screen.dart:1690`, `lib/screens/calendar/care_calendar_screen.dart:357`.
31. Calendar day cell is **43.4pt wide at 320pt** (`lib/screens/calendar/care_calendar_screen.dart:551`, `:210-211`), and the `width < 360` branch is exercised by no test.
32. `fontSize: 9.5` at `lib/screens/calendar/care_calendar_screen.dart:817` violates the app's own 11px floor.
33. **971** literal `fontSize:` values (up from 957) and **0** `textTheme.` references — the `TextTheme` at `lib/config/theme.dart:170-215`/`:360-395` is still dead code.
34. **181** raw `Colors.white`/`Colors.black*` in `lib/screens` + `lib/widgets` that do not flip in dark mode (white 132 → **135**); worst file `lib/screens/consultation/video_consultation_screen.dart` (21).
35. Design gate scans `lib/screens` only and bans no `Colors.white`/`black` — `lib/widgets/glass.dart:147` and `lib/widgets/document_attach_widgets.dart:314`/`:316` escape entirely, and the three new white-on-error hardcodes passed inside the scanned directory.
36. Stale contrast claims that a future reader will trust: `lib/config/app_colors.dart:64-66` (*"both modes use the same dark ink (6.3:1 on orange)"* — the field is `#FFFFFF`), `lib/config/theme.dart:212`, `:230`, `:415`. These describe the pre-reversal state and should be corrected to state the measured 2.33:1 and name the owner override.
37. `delete_account_screen.dart:214-215` — the `_canSubmit ? hc.error : hc.grey` disabled branch is dead code; `styleFrom` sets no `disabledBackgroundColor`, so M3 defaults (~2.3:1) apply. Not a WCAG violation (disabled controls are exempt) but misleading, and the gating is near-invisible.
38. `overflow_smoke_test.dart` covers 37 of ~56 screens (~66%); calendar, main shell, care team, chat, login, payment, order tracking, address **and now delete-account** are uncovered.

## BLOCKED-OWNER

- **§4.7 — manual VoiceOver device pass.** Need a physical-iPhone VoiceOver run of three top flows (book → cart → checkout; My Care → vitals → care calendar; **Settings → Delete account → confirm**) with pass/fail per step. Static analysis cannot substitute.
- **§6.3 — a11y findings triaged at functional-bug priority.** Need the owner's triage policy plus one release cycle of tracker evidence. Round 2 supplies the first datum and it is negative: ten blockers closed, zero of them the five accessibility blockers.

---

## Notes on what was deliberately NOT flagged

Per the shared brief, these are owner decisions or demo-mode behaviour and are reported as measured fact, not as defects to reverse: white-on-orange ink (`onOrange = #FFFFFF`, **2.33:1**), the fixed full-width solid-orange five-tab bottom nav with white icons, manpower prices being shown and directly bookable, and the `DemoData` fallbacks themselves. The **dark-mode white-on-`hc.error` failure (3.49:1)** is *not* covered by the white-on-orange override — it is new code on a status colour with no corresponding owner decision, and `HcPalette` has no `onError` token for it to have used.

`storage.rules` / Firebase deployment posture, payment-key handling, and PHI session-scoping are outside this checklist's scope and are covered by the security and post-launch audits in this directory.
