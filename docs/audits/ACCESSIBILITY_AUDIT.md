# Accessibility Checklist (App-Agnostic) — Audit vs commit `803124d` + working tree

**Date:** 2026-08-03 · **Auditor:** accessibility-audit agent · **Method:** read-only (`rg`/`grep`/`Read`, `bash scripts/check_design_consistency.sh`, WCAG 2.1 relative-luminance computation in Python). No `flutter test`/`build`/`clean` run. No files changed.

**Tree audited:** HEAD `803124d` **plus uncommitted working-tree changes** to `CLAUDE.md`, `lib/screens/main_shell.dart`, `lib/screens/my_care/my_care_screen.dart`, `test/screens/main_shell_test.dart` — i.e. the **five-tab** nav (Home/My Care/Services/Billing/More) with the care calendar moved to a My Care app-bar action routed to `/care-calendar` (`lib/screens/main_shell.dart:36-42`, `lib/screens/my_care/my_care_screen.dart:48-54`).

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

**Verdict: the app does NOT pass this checklist.** Four of the five "stop the release" red flags are present.

---

## The headline number the owner asked for

### White (`#FFFFFF`) on Housepital orange (`#F39314`)

```
relative luminance #F39314 = 0.39969
relative luminance #FFFFFF = 1.00000
contrast ratio = (1.00 + 0.05) / (0.39969 + 0.05) = 2.33 : 1
```

| Requirement | Threshold | Measured | Result |
|---|---|---|---|
| Body text (< 18pt regular / < 14pt bold) | 4.5 : 1 | **2.33 : 1** | ❌ **fails by 1.93×** |
| Large text (≥ 18pt regular / ≥ 14pt bold) | 3.0 : 1 | **2.33 : 1** | ❌ fails |
| Non-text UI (icons, borders) | 3.0 : 1 | **2.33 : 1** | ❌ fails |

There is no size at which white-on-`#F39314` passes any WCAG AA threshold.

**Where this ships today**

| Surface | file:line | Fill | Ink | Ratio |
|---|---|---|---|---|
| Bottom nav — selected tab icon + label | `lib/screens/main_shell.dart:68`, `:78` | `hc.orange` `#F39314` | `hc.onOrange` `#FFFFFF` | **2.33 : 1** |
| Bottom nav — **unselected** tab icon + label | `lib/screens/main_shell.dart:79` | `#F39314` | `#FFFFFF` @ 70% α → composites to `#FBDFB8` | **1.82 : 1** |
| Primary `ElevatedButton` label (16pt/w600) | `lib/config/theme.dart:227-238` (light), `:412-424` (dark) | `#F39314` | `#FFFFFF` | **2.33 : 1** |
| `labelLarge` button text token | `lib/config/theme.dart:210-215`, `:387-395` | `#F39314` | `#FFFFFF` | **2.33 : 1** |
| `colorScheme.onPrimary` | `lib/config/theme.dart:160`, `:340` | `#F39314` | `#FFFFFF` | **2.33 : 1** |
| Round call/chat action buttons | `lib/screens/home/home_screen.dart:822`, `:1871`; `lib/screens/care_team/care_team_screen.dart:287`; `lib/screens/chat/chat_screen.dart:337` | `#F39314` | white icon | **2.33 : 1** |
| Hero gradient start stop | `lib/config/app_colors.dart:31` `#FF8C00` | — | white | **2.33 : 1** |
| Hero gradient end stop | `lib/config/app_colors.dart:32` `#FF6B35` | — | white | 2.84 : 1 |

This is identical in light and dark: `HousepitalColors.onOrange = Color(0xFFFFFFFF)` (`lib/config/theme.dart:70`) and `HousepitalColorsDark.onOrange = Color(0xFFFFFFFF)` (`lib/config/theme.dart:32`).

### Smallest change that keeps the owner's white text

**Do not change the ink.** Add a darker *text-bearing* orange fill token, keep `#F39314` for large decorative fills (hero washes, illustration blocks) where no text sits on it.

Binary-searched down the value axis of `#F39314` (HSV h=34.2°, s=0.918) — the hue and saturation are untouched, only brightness:

| New token | Hex | White-on-fill ratio | Covers |
|---|---|---|---|
| `orangeFillLarge` | **`#D58112`** | **3.01 : 1** | icons + ≥18pt/≥14pt-bold white text (AA large + non-text) |
| `orangeFillText` | **`#AA670E`** | **4.51 : 1** | all white body text (AA) |

Concrete minimum edit (4 sites, no screen churn):

1. `lib/config/theme.dart` — add `static const Color orangeFillText = Color(0xFFAA670E);` to `HousepitalColors` and `HousepitalColorsDark`.
2. `lib/config/app_colors.dart` — expose it on `HcPalette.light()` / `.dark()`.
3. `lib/screens/main_shell.dart:68` — `color: context.hc.orangeFillText` (nav labels are 12–14pt, so they need the 4.5:1 variant; the bar stays unmistakably Housepital orange). Also drop the `withValues(alpha: 0.7)` on `:79` — encode unselected via the outline-vs-filled icon pair already present at `:82-105`, not via opacity.
4. `lib/config/theme.dart:229`, `:414` — `backgroundColor: HousepitalColors.orangeFillText` for `elevatedButtonTheme`.

Everything else (`#F39314` as an accent stroke on dark, chart lines, hero gradients without text) is untouched. Orange on true black already measures **8.99 : 1** and on the dark card `#1C1C1E` **7.29 : 1** — dark mode's orange accent is fine; only *white-on-orange* is broken.

### Related: three code comments now assert a compliance the code does not have

These are load-bearing because a future reader will trust them:

- `lib/config/app_colors.dart:62-64` — *"White on orange fails AA (~2.3:1), so both modes use the same dark ink (6.3:1 on orange)."* The field it documents is `#FFFFFF`.
- `lib/config/theme.dart:229` — *"// Dark text on orange — 6.3:1 vs white's ~2.3:1 (brand fill kept)."* `foregroundColor` is `onOrange` = white.
- `lib/config/theme.dart:212` — *"// Used on buttons — match onPrimary so it passes AA on orange fills."* It does not pass AA.
- `lib/config/theme.dart:324-325` and `:417` — *"Buttons keep brand orange, but use dark text … passes 6.32:1 vs white's 2.7:1."* Same.

The comments describe the pre-reversal state. They should be corrected to state the measured 2.33:1 and name the owner override, whatever is decided about the fill.

---

## Findings

### 1. Contrast

- ❌ **Text meets 4.5:1 against its actual background (3:1 for ≥18pt bold / ≥24pt regular).** — evidence: the table above; `lib/screens/main_shell.dart:68/78/79`, `lib/config/theme.dart:227-238`. The **neutral** palette is genuinely good (`#212121` on `#F8F9FA` = 10.30:1; dark `#F2F2F2` on `#1C1C1E` = 15.20:1; `#B0B0B0` on `#1C1C1E` = 7.85:1; `#6B6B6B` on white = 5.33:1) — the failure is confined to the orange family. **Impact:** the persistent bottom nav, every primary CTA, and every call/chat button in the app. **Fix:** the `orangeFillText` token above.
  - Secondary text failure: `HousepitalColorsDark.textDisabled` `#7A7A7A` on the card `#1C1C1E` = **3.96:1** (`lib/config/theme.dart:25`) — the comment on that line claims "4.2:1 on card". It is used as tertiary text/icon colour via `hc.greyLight`.

- ❌ **Non-text UI (icons, chart slices, progress bars, meaningful borders) meets 3:1.** — evidence:
  - Orange icon on white card = **2.33:1**; on `orangeLight #FFF3E0` = **2.13:1** (`lib/config/theme.dart:307-312` uses `orangeText` for the *label* but the chip's own icon/edge is raw orange in several screens).
  - Light divider `#E0E0E0` on white = **1.32:1** (`lib/config/theme.dart:82`); dark divider `#2A2A2C` on true black = **1.47:1** (`:19`). These carry the card/vitals-pill structure (`lib/screens/my_care/my_care_screen.dart:405`).
  - Segmented-control selected thumb, `hc.black @ 8%` on `greyLighter` = **1.17:1** light, **1.27:1** dark (`lib/screens/calendar/care_calendar_screen.dart:367-369`). *Mitigated* — the trait is declared (`Semantics(button: true, selected: selected)` at `:352-354`) and the label is text, so the meaning is not colour-only; but the visual selected state is effectively invisible at 3:1.
  - `orangeMuted` dark chip `#3D2A12` on true black = **1.54:1** (`lib/config/theme.dart:33`).
  **Fix:** raise divider to ≥3:1 where it is the only boundary (or drop it and rely on tone/elevation, which the calm-Apple direction already prefers); use `orangeFillLarge #D58112` for orange glyphs on light surfaces; give the segmented thumb a ≥3:1 fill or an outline.

- ❌ **Contrast verified in BOTH appearances, programmatically in a unit test.** — evidence: `rg -n "contrast|luminance|Luminance" test/` returns **zero hits across the entire suite**. `test/widgets/dark_mode_test.dart` **does** resolve both appearances (`HousepitalTheme.lightTheme` at `:38` and `HousepitalTheme.darkTheme` at `:51`) — but every assertion is token **identity**, never a computed ratio: `expect(p.black, HousepitalColorsDark.textPrimary)` (`:60`), `expect(p.divider, …)` (`:62`). It proves the resolver flips; it cannot detect that the value it flips *to* is 2.33:1. `test/screens/dark_mode_sweep_test.dart` likewise renders both modes without measuring anything. **Impact:** exactly the failure mode the checklist warns about — a one-appearance-blind suite that has hidden a 2.33:1 failure across the entire release history. **Fix:** add `test/widgets/contrast_test.dart` with a `Color.computeLuminance()`-based `contrastRatio(a, b)` helper, and assert every foreground/background pair in `HcPalette.light()` **and** `HcPalette.dark()` against 4.5/3.0. Seed it with the pairs in this report so the suite starts red on the known failures rather than silently green.

- ❌ **Filled elements use a PAIRED foreground that flips with appearance — never hardcoded white on a brand colour.** — evidence: `HousepitalColors.onOrange = Color(0xFFFFFFFF)` (`lib/config/theme.dart:70`) **and** `HousepitalColorsDark.onOrange = Color(0xFFFFFFFF)` (`:32`). The pairing token exists and is correctly plumbed through `HcPalette` (`lib/config/app_colors.dart:95`, `:123`) — but both arms resolve to the same white, so the flip is a no-op. **Owner override noted:** white-on-orange is an explicit, re-confirmed owner decision (CLAUDE.md:56-58). This item is graded ❌ against the objective standard, not as a request to reverse the decision — the measured fact is 2.33:1 and the recommended remedy keeps the white ink and darkens the fill.

- ⚠️ **Text over images/gradients has a scrim or is measured against the worst pixel.** — evidence:
  - ✅ Promo banner does this correctly: `ColorFilter.mode(Colors.black.withValues(alpha: 0.45), BlendMode.darken)` (`lib/screens/home/home_screen.dart:600-603`). Worst case (a pure-white photo) → white on `#8C8C8C` = **3.36:1** — passes 3:1 for the large banner title, misses 4.5:1 for the subtitle. Raising the scrim to 0.55 α gives 4.7:1.
  - ⚠️ `GlassSurface` (`lib/widgets/glass.dart:139-152`) is a 24σ blur under a **0.55 α** fill over arbitrary scrolling content — no scrim, no worst-pixel measurement. Light bar over dark content composites to `#8C8C8C`: primary ink `#212121` holds at **4.79:1** ✅ but **orange app-bar glyphs drop to 1.44:1** ❌. Dark bar over a white photo composites to `#828283`: `#F2F2F2` ink = **3.43:1** ❌ (needs 4.5 for the 20pt/w600 title at `lib/config/theme.dart:403-407`). **Fix:** raise `opacity` to ~0.75 for the app bar, or add a 1px `divider`-strength bottom edge and a subtle vertical scrim behind the title row.

### 2. Dynamic Type

- ❌ **Busiest three screens exercised at AX5.** — evidence: `lib/main.dart:417-424` clamps system scaling to `maxScaleFactor: 1.4`. iOS AX5 is ≈3.1×; the app therefore **never renders any accessibility text size** — AX1 through AX5 all collapse to 1.4×. The in-code comment cites "WCAG 1.4.4", but 1.4.4 requires **200%** resize; 1.4× is 140%, so the clamp fails even the standard it names. Separately, `rg "textScaler|textScaleFactor|TextScaler" test/` returns **zero hits in the entire test suite** — no screen is exercised at any scale. `test/screens/overflow_smoke_test.dart` varies only width (320/375/414 at `devicePixelRatio: 1.0`, `_wrap` ~`:328-335`) and leans on the Ahem font as an *incidental* proxy. **Impact:** the largest and most common accessibility setting among elderly home-care patients — the app's core demographic — is silently ignored. **Fix:** raise the clamp to at least 2.0 (ideally remove it), then add a `textScaler: TextScaler.linear(2.0)` and `3.0` axis to `overflow_smoke_test.dart` for Home / My Care / Services and fix what breaks.

- ❌ **Every text style comes from the type system, not fixed point sizes.** — evidence: `rg -o "fontSize:\s*[0-9.]+" lib/screens lib/widgets | wc -l` = **957**. `rg -o "textTheme\." lib/screens lib/widgets | wc -l` = **0**. The `TextTheme` carefully defined in `lib/config/theme.dart:170-215` and `:360-395` is **entirely unused** — not one screen or widget reads it. The design gate prints a fontSize histogram but is explicitly echo-only (`scripts/check_design_consistency.sh`, "informational — does not affect pass/fail"). The histogram shows the sprawl: 95×11pt, 191×12pt, 200×13pt, 184×14pt, 61×15pt, 138×16pt, plus one-offs at 9.5, 14.5, 22, 32, 36. **Note:** Flutter's `textScaler` still scales literal `fontSize` values, so this does not by itself break scaling — it breaks *governance*: there is no semantic scale to reason about, no way to change a role app-wide, and no reason listed for any fixed size. **Fix:** adopt the canon already documented in CLAUDE.md (28/w800 display, 16/w600 section header, …) as named `TextTheme` roles and make the gate fail on new raw `fontSize:` in `lib/screens`.
  - Sub-finding: `lib/screens/calendar/care_calendar_screen.dart:817` uses `fontSize: 9.5`, below the app's own documented **11px minimum** (CLAUDE.md:82).

- ❌ **`minimumScaleFactor` / line limits are a last resort with a floor (≥ ~0.7).** — evidence: 14 `FittedBox(fit: BoxFit.scaleDown)` sites, **none with a floor** — `BoxFit.scaleDown` shrinks without limit. Sites: `lib/screens/reports/vitals_screen.dart:283`, `lib/screens/my_care/my_care_screen.dart:411`, `lib/screens/services/cards/equipment_item_card.dart:127`/`:163`/`:181`, `lib/screens/calendar/care_calendar_screen.dart:838`/`:840`, `lib/screens/services/service_catalog_screen.dart:150`, `lib/screens/services/widgets/equipment_category_rail.dart:319`, `lib/screens/my_care/service_detail_screen.dart:484`. Additionally 104 `maxLines:` and 93 `TextOverflow.ellipsis`. **Fix:** replace `FittedBox` on value-bearing text with `Text(minFontSize)`-equivalent clamping (or let the container grow), and reserve `scaleDown` for decorative headers.

- ❌ **Numbers users act on (money, dates, doses) remain fully readable at AX sizes.** — evidence, and this is the same red flag the checklist names verbatim ("shrinking a total is losing the total"):
  - `lib/screens/services/cards/equipment_item_card.dart:125-127` — the **discounted price row** lives in a `SizedBox(height: 16)` with `FittedBox(scaleDown)`. At 1.4× the price shrinks inside a 16pt box instead of the card growing.
  - `lib/screens/services/cards/equipment_item_card.dart:179-181` — the **price** in a `SizedBox(height: 18)`, same treatment.
  - `lib/screens/my_care/my_care_screen.dart:404-413` — the **vitals value** (heart rate, BP, SpO₂) in a fixed `width: 90` pill (comment says 90×88) under `FittedBox(scaleDown)`. A clinical number that shrinks.
  - `lib/screens/reports/vitals_screen.dart:283` — the vitals **hero value** under `scaleDown`.
  **Fix:** drop the fixed `height:` on the two price rows and let the grid tile's `mainAxisExtent` grow; give the vitals pill an intrinsic height.

- ❌ **Container heights are not hardcoded around one text size.** — evidence: `rg -o "height: [0-9]+" lib | wc -l` = **1080**. Text-bearing examples above, plus `lib/screens/my_care/service_detail_screen.dart:459-462` (fixed 44pt pill height wrapping a `FittedBox` label) and `lib/screens/calendar/care_calendar_screen.dart:355` (`Container(height: 44)` segmented control). **Fix:** convert text-bearing fixed heights to `ConstrainedBox(minHeight:)`.

### 3. Touch targets

- ❌ **Every tappable element is ≥44×44pt including padding.** — evidence. *Flutter caveat first:* both themes set `useMaterial3: true` (`lib/config/theme.dart:154`, `:334`) and neither overrides `materialTapTargetSize`, so `IconButton` keeps its 48×48 `_InputPadding` hit region even when `padding`/`constraints` are zeroed. There are **zero** `MaterialTapTargetSize.shrinkWrap` in the codebase. The real violations are all **raw gesture widgets**, which get no such padding:

  | # | file:line | Control | Measured |
  |---|---|---|---|
  | 1 | `lib/widgets/document_attach_widgets.dart:47` | `GestureDetector` → bare `Icon(Icons.close, size: 18)` — remove attachment | **18 × 18** |
  | 2 | `lib/screens/support/raise_concern_screen.dart:231` | remove evidence photo; `padding: all(4)` + `Icon(size: 14)`, and `Positioned(top:2,right:2)` overlaps the thumbnail | **22 × 22** |
  | 3 | `lib/screens/cart/cart_screen.dart:883` (`_qtyButton`) | **cart quantity stepper** (− and +); `Padding(all(4))` + `Icon(size: 16)` | **24 × 24** |
  | 4 | `lib/screens/billing/payment_screen.dart:803` | GST explainer `InkWell`; `Padding(all(4))` + `Icon(size: 16)` | **24 × 24** |
  | 5 | `lib/screens/articles/article_list_screen.dart:187` (`_FilterChip`) | `InkWell` + `vertical: 8` on 12pt text | ≈ **32pt** tall |
  | 6 | `lib/screens/calendar/care_calendar_screen.dart:355` | Day/Week/Month/Year segmented control; `height: 44` minus `padding: all(4)` | ≈ **36pt** tall |
  | 7 | `lib/screens/calendar/care_calendar_screen.dart:551` (`_dayCell`) | calendar day cell; `crossAxisCount: 7`, `childAspectRatio: 0.82`, `gridHPad = 8` when width < 360 (`:210-211`) | **43.4 × 52.9 at 320pt** — 0.6pt short |

  Violation #3 is the sharpest: `lib/screens/services/widgets/quantity_button.dart:44` **already implements the correct 44pt-reserved stepper** with an explicit Apple-HIG comment, and the cart hand-rolls a 24×24 one instead. **Fix:** replace `_qtyButton` with the shared `QuantityButton`; wrap #1/#2/#4 in `ConstrainedBox(BoxConstraints(minWidth: 44, minHeight: 44))`; give the calendar grid `childAspectRatio` a floor so the cell never drops under 44pt at 320pt.

  Credit where due — the codebase has clearly been through a pass: `lib/widgets/common_widgets.dart:688-691` (star rating, 44×44 with a docstring), `lib/screens/cart/cart_screen.dart:272`/`:863`/`:980` (all 44×44 citing WCAG 2.5.5), `lib/screens/home/home_screen.dart:410`/`:496`, `lib/screens/assistant/assistant_screen.dart:307`/`:317` (48×48), `lib/screens/services/cards/equipment_item_card.dart:404`, `lib/screens/services/cards/staff_role_card.dart:770`, `lib/screens/services/cards/diagnostic_card.dart:98`. The **bottom nav is fine**: standard `BottomNavigationBar`, 5 fixed items, `kBottomNavigationBarHeight = 56` → 64 × 56 per item at 320pt (`lib/screens/main_shell.dart:71`).

- ❌ **Destructive actions are not adjacent to habitual ones without spacing or a confirm.** — evidence. A shared `confirmDestructiveAction` helper exists (`lib/widgets/common_widgets.dart:501-530`) with **8 call sites** — but three destructive actions bypass it, and two of those sit ~4pt from a habitual control:

  | Action | file:line | Problem |
  |---|---|---|
  | **Delete reminder** | `lib/screens/calendar/care_calendar_screen.dart:1308-1314` | `IconButton(Icons.close)` → `RemindersProvider.delete(r.id)` fires **immediately**. No confirm, no undo, persisted data (`lib/providers/reminders_provider.dart:150`). The ✕ is `SizedBox(width: 4)` from the card body (`:1307`). |
  | **Remove saved-for-later item** | `lib/screens/cart/cart_screen.dart:982` | `cart.removeSaved(index)` unconfirmed, `SizedBox(width: 4)` (`:975`) from the habitual **"Move to Cart"** `ElevatedButton` (`:965-972`). The sibling *cart* remove at `:865` **is** confirmed — inconsistent. |
  | **Remove emergency contact** | `lib/screens/settings/patient_profile_screen.dart:145-150` (button `:693`) | Unconfirmed, while `_removeMedication` 80 lines below on the **same screen with an identical affordance** *is* confirmed (`:225-236`). |

  **Fix:** route all three through `confirmDestructiveAction`, or add an undo snackbar; widen the 4pt gaps to ≥8pt.

- ⚠️ **Rows with MULTIPLE buttons use explicit per-button styles so one tap fires one action.** — evidence: the iOS "row-level default style fires every button" bug has no Flutter analogue, so the item does not map literally. The equivalent hazard — **nested tap targets with different destinations** — is present at 6 sites, two of them serious:
  - `lib/screens/home/home_screen.dart:774` — an `InkWell(onTap: → /chat)` wraps the entire care-team row, which *also* contains a `tel:` `IconButton` (`:818`) and a chat `IconButton` (`:839`) separated by `SizedBox(width: 4)` (`:834`). A tap 1–2pt outside the call button's ink area **silently opens chat instead of placing a call**. Same 4pt pattern at `lib/screens/care_team/care_team_screen.dart:282-317` (`home_screen.dart:833` says it copies it).
  - `lib/screens/auth/login_screen.dart:183` — `InkWell` toggles the **consent checkbox**; inside it sit the `Checkbox` (`:192`) and two unpadded 13pt inline "Terms"/"Privacy" links (`:214`, `:234`). A near-miss on a link toggles consent.
  - Benign: `lib/screens/services/cards/diagnostic_card.dart:39` (outer + inner call the identical handler), `lib/screens/calendar/care_calendar_screen.dart:946` (standard `ListTile` trailing), `lib/screens/settings/settings_screen.dart:100` (intentional, commented `:96`), `lib/widgets/common_widgets.dart:43` vs `:71` (toast action label is an unpadded bare `Text` — a miss dismisses the toast and loses the action).

- ❌ **Gestures have visible-button equivalents.** — evidence: **`lib/screens/settings/family_members_screen.dart:319-345`**. Removing a family member — a role/permission-bearing entity that routes notifications — is reachable **only** by `Dismissible(direction: endToStart)`. `_buildMemberCard` (`:344-408`) has no trailing `IconButton`, no `PopupMenuButton`, no `onTap`. Unreachable via VoiceOver, Switch Control, or keyboard; WCAG 2.1 §2.5.1 + §2.1.1. (The `confirmDismiss` at `:334-337` correctly returns `false` and defers to a dialog — the *confirmation* is right, the *discoverability* is not.) **Fix:** add a trailing overflow `IconButton` gated by the same `canManage` check at `:266`/`:317`, calling `_showDeleteConfirmation`. **Non-issues confirmed:** zero `onLongPress`, zero `onHorizontalDrag`, zero `ReorderableListView`, zero `Draggable` in `lib/`; the three `DraggableScrollableSheet`s are sheet containers opened by normal taps.

### 4. Screen reader (VoiceOver / TalkBack)

- ❌ **Every icon-only control has an accessibility label that says what it DOES.** — evidence: brace-matched inventory of `lib/screens` + `lib/widgets` (excluding `IconButton.styleFrom`): **54 real `IconButton` constructors, 37 labelled (tooltip or an enclosing `Semantics(label:)`), 17 unlabelled = 31%.** Worst offenders by file:line:

  | file:line | Control | Reads as |
  |---|---|---|
  | `lib/screens/my_care/widgets/health_manager_banner.dart:69` | **Call the health manager** (`tel:`) | silent |
  | `lib/screens/my_care/widgets/health_manager_banner.dart:80` | **Message the health manager** (`/chat`) | silent |
  | `lib/screens/chat/chat_screen.dart:335` | **Send message** | silent |
  | `lib/screens/chat/chat_screen.dart:304` | Attach photo | silent |
  | `lib/screens/my_care/add_edit_medication_screen.dart:92` | **Delete medication** (destructive) | silent |
  | `lib/screens/settings/patient_profile_screen.dart:693` | Remove emergency contact (destructive) | silent |
  | `lib/screens/settings/patient_profile_screen.dart:834` | Remove medication (destructive) | silent |
  | `lib/screens/services/service_booking_screen.dart:1018` / `:1037` | Decrease / increase session count | silent |
  | `lib/screens/services/service_booking_screen.dart:327` | Back a wizard step | silent |
  | `lib/screens/settings/patient_profile_screen.dart:772`, `lib/screens/settings/add_patient_screen.dart:273` | Add condition | silent |
  | `lib/screens/documents/document_repository_screen.dart:167` / `:390` | Toggle search / close sheet | silent |
  | `lib/screens/settings/family_members_screen.dart:123`, `lib/screens/search/universal_search_screen.dart:284`, `lib/screens/settings/help_faq_screen.dart:199` | Close sheet / clear query | silent |

  The two `health_manager_banner.dart` buttons are the most damaging: two visually identical circular tiles, one dials a phone and one opens chat, and a screen-reader user cannot tell them apart. **Impact:** two of the app's care-contact paths and three destructive actions are unreachable by name. **Fix:** add `tooltip:` (which Flutter promotes to the semantic label) to all 17 — a mechanical one-line-each change. The house pattern is already right in `lib/widgets/glass.dart:62`/`:78`/`:110` and `lib/screens/cart/cart_screen.dart:860` (`'Remove ${cartItem.name} from cart'`).

- ⚠️ **Rows read as one sentence (label + value + state).** — evidence, mixed:
  - ✅ `StatusBadge` (`lib/widgets/common_widgets.dart:222-262`) always renders text **and** wraps it in `Semantics('Status: $text')` (`:237`) — used by orders, billing, family, calendar.
  - ✅ `lib/screens/my_care/medications_screen.dart:220-235` — per-dot `Semantics` label on the 7-day adherence strip. This is the template.
  - ❌ `lib/screens/my_care/my_care_screen.dart:378-441` (`_vitalPill`) — the `InkWell` has **no `Semantics` label**, so VoiceOver reads three loose fragments ("Heart rate" / "78" / "bpm") and **never announces the green/yellow/red clinical status** at all (`:381-386`, dot at `:420-427`).
  - ⚠️ `lib/screens/my_care/widgets/vitals_trend_grid.dart:64` — button label is `'$title, ${card.status}'` and **omits the numeric reading** (`card.label`, `:124`).

- ⚠️ **Charts expose a text summary; the visual is hidden, the summary is not.** — evidence: the **summary half is done well everywhere**, the **hiding half is done nowhere**.
  - `lib/screens/reports/vitals_screen.dart:345` — `fl_chart LineChart`. Rich text equivalent exists: hero value `:291`, unit `:303`, "Latest reading" + date `:319-327`, Average/Highest/Lowest stat cards `:464-468`, prose insights `:536-552` ("varied between X and Y", "Outside safe range on N occasions"), legend `:452`. But the chart is **not** `ExcludeSemantics`-wrapped, so the axis-tick `Text` widgets at `:361` and `:377` leak as bare context-free nodes ("120", "8 Aug", …).
  - `lib/screens/my_care/widgets/vitals_trend_grid.dart:136` — 24px sparkline, not excluded; status text at `:111-118`, value at `:123-131`.
  - `lib/widgets/care_pulse_ring.dart:86-87` — correctly labelled (`'$N percent'`) but **without `excludeSemantics: true`**, so its `center` child (`'86%'`, `'3/5'`) emits a **second node → doubled announcement**. Four call sites: `lib/screens/home/home_screen.dart:1436`, `lib/screens/my_care/my_care_screen.dart:229`, `lib/screens/my_care/medications_screen.dart:169`, `lib/screens/reports/daily_report_screen.dart:281`.
  - 5 `LinearProgressIndicator` data gauges (`lib/screens/calendar/care_calendar_screen.dart:1459`, `lib/screens/my_care/service_detail_screen.dart:210`, `lib/screens/my_care/widgets/active_service_card.dart:123`, `lib/screens/my_care/widgets/billing_summary_section.dart:80`, `lib/screens/services/equipment_detail_screen.dart:1206`) — all five have an adjacent numeric text equivalent ✅, none is excluded ⚠️.
  - The ~20 `CircularProgressIndicator` are indeterminate loading spinners (not gauges) — none carries a label, so **loading state is announced as silence** (`lib/widgets/paginated_list.dart:110`/`:207`, `lib/widgets/common_widgets.dart:455`, `lib/screens/assistant/assistant_screen.dart:193`).
  **Fix:** wrap each chart/gauge visual in `ExcludeSemantics`; add `excludeSemantics: true` to `care_pulse_ring.dart:86`; add `semanticsLabel: 'Loading'` to the spinners.

- ⚠️ **Decorative images are hidden from the accessibility tree.** — evidence: 7 images carry explicit semantics, 8 do not, and the split is **asymmetric within the same widget**: `ProductImage` labels its **asset** branch (`lib/widgets/common_widgets.dart:131` → `'Product photo'`) but not its **network** branch (`:134`). Same asymmetry at `lib/screens/services/cards/equipment_item_card.dart:218` vs `:225`, `lib/screens/services/equipment_detail_screen.dart:448` vs `:458` and `:1895` vs `:1905`. Also unhandled: `lib/screens/search/universal_search_screen.dart:466`, `lib/screens/cart/cart_screen.dart:676`/`:929`, `lib/screens/articles/article_detail_screen.dart:94`. Practical impact is **low** — `CachedNetworkImage` emits no semantics node by default — but identical content announces differently depending on whether the photo is bundled or remote. Icons are fine: 293 `Icon(Icons.*)`, zero `semanticLabel`, which is correct-by-default in Flutter (a bare `Icon` emits no node). Only **3 `ExcludeSemantics`** exist app-wide (`lib/screens/home/home_screen.dart:509`, `lib/screens/calendar/care_calendar_screen.dart:877`, `lib/screens/my_care/my_care_screen.dart:492`).

- ✅ **Custom controls declare traits (button, selected, adjustable).** — evidence: the calendar segmented control declares `Semantics(button: true, selected: selected, label: '$label view')` (`lib/screens/calendar/care_calendar_screen.dart:351-354`); `StatusBadge` declares `Semantics('Status: …')` (`lib/widgets/common_widgets.dart:237`); the SOS button declares `label:` + `button: true` with an explicit interaction hint (`lib/widgets/common_widgets.dart:593-595`, *"Emergency SOS. Double-tap to open emergency contacts"*); star rating (`:688`), assistant FAB (`lib/widgets/assistant_fab.dart`), quantity button, category rail, catalog search bar and 20 other widgets all carry `Semantics`. 72 `Semantics(` sites total.

- ❌ **Sheet/alert focus lands on the meaningful element; focus order follows visual order.** — evidence: **25 `showModalBottomSheet`** calls in `lib/`, and across the whole app only **2** focus-management sites (`lib/screens/documents/document_repository_screen.dart:158` `autofocus: true`, `lib/screens/search/universal_search_screen.dart:132` `requestFocus()`). Zero `FocusScope`, zero `FocusTraversalGroup`, zero `SemanticsService.announce`, zero `liveRegion`. **Impact:** opening any of the 25 sheets (equipment detail, lab test, staff role, add reminder, address form, …) leaves screen-reader focus unmanaged; asynchronous state changes (cart updated, booking confirmed, quote pending) are never announced. **Fix:** add `SemanticsService.announce` on the async success paths and a `FocusScope`/`autofocus` on each sheet's first meaningful control.

- **BLOCKED-OWNER** — **One full screen-reader pass of the top three flows per release, on a real device, eyes closed.** No artifact of a manual VoiceOver pass exists in the repo (`docs/audits/` contains five prior audits, none an a11y device pass). **To clear this I would need:** the owner (or a tester) to run VoiceOver on a physical iPhone through (1) Home → book a service → cart → checkout, (2) My Care → vitals → care calendar, (3) Billing → invoice → PDF, and record pass/fail per step. A static audit cannot substitute.

### 5. Motion, sound & state

- ⚠️ **Reduce Motion is honoured.** — evidence: **11 `lib/` sites gate on `MediaQuery.of(context).disableAnimations`** — `lib/screens/calendar/care_calendar_screen.dart:251`/`:1080`/`:1602`/`:1709`, `lib/screens/billing/payment_screen.dart:256`, `lib/screens/billing/billing_screen.dart:156`, `lib/screens/my_care/medications_screen.dart:329`, `lib/screens/my_care/staff_otp_verification_screen.dart:105`, `lib/screens/my_care/my_care_screen.dart:101`, `lib/screens/my_care/medication_schedule_screen.dart:322`, `lib/screens/services/tabs/equipment_tab.dart:267`, `lib/screens/services/booking_confirmation_screen.dart:126`, `lib/screens/orders/order_tracking_screen.dart:120`, `lib/widgets/care_pulse_ring.dart:84`. **Zero `.repeat()` anywhere** — the unbounded pulse was deliberately removed (`lib/screens/orders/order_tracking_screen.dart:103`). Two gaps:
  - `lib/screens/services/equipment_detail_screen.dart:1690-1691` — a 250ms `AnimationController` driven by `_toggle()` (`:1708`) with **no `disableAnimations` check**.
  - `lib/screens/calendar/care_calendar_screen.dart:358` — `AnimatedContainer(duration: 150ms)` on the segmented thumb, ungated, while four other animations on the same screen are gated.
  **Fix:** two one-line ternaries matching the house pattern.

- ✅ **No information arrives ONLY as a haptic or ONLY as a sound.** — evidence: all 8 `HapticFeedback` sites accompany a visible state change — SOS button (`lib/widgets/common_widgets.dart:605`, alongside the red button + label at `:614-620`), payment success/failure (`lib/screens/billing/payment_screen.dart:234`/`:246`), booking confirmation (`lib/screens/services/booking_confirmation_screen.dart:114`), medication taken (`lib/screens/my_care/medications_screen.dart:298`, `lib/screens/my_care/medication_schedule_screen.dart:302`), calendar (`lib/screens/calendar/care_calendar_screen.dart:1742`), patient switch (`lib/screens/home/home_screen.dart:491`). No audio-only signals in `lib/`.

- ✅ **Nothing flashes more than 3×/second; auto-advancing content can be paused.** — evidence: zero `.repeat()`; the fastest animation is 100ms one-shot (`lib/screens/home/home_screen.dart:232`, `:1249`). The home promo banner is a **manual** `PageView.builder` (`lib/screens/home/home_screen.dart:43`, `:577`) — **no autoplay timer**, so there is nothing to pause. The 6 `Timer.periodic` instances are data/state timers (sync 96, video call duration 75, token refresh 78, duty status at 1-minute intervals 70, OTP resend/expiry), none drives a visual flash.

- ✅ **Time-limited flows are generous or extendable.** — evidence: `lib/screens/auth/otp_screen.dart:25` — **300s (5 min)** OTP expiry with an explicit lock-and-resend path (`:48-64`), and a **30s** resend cooldown (`:36`) after which the user can extend indefinitely. Toast/snackbar durations are 3–6s for informational messages (`lib/screens/services/cards/equipment_item_card.dart:367`, `lib/screens/packages/package_detail_screen.dart:608`, `lib/utils/notification_router.dart:89`, `lib/screens/support/raise_concern_screen.dart:358`) and none is the sole carrier of an action.

### 6. Process

- ❌ **Contrast assertions live in the automated suite and resolve BOTH appearances.** — evidence: see §1 item 3. Zero contrast/luminance assertions in `test/`. `test/widgets/dark_mode_test.dart` resolves both appearances (`:38`, `:51`) but asserts token identity only. This is the literal parenthetical in the checklist — *"a one-appearance suite once hid a 2.3:1 failure for a full release"* — except here the suite resolves both appearances and still hides a 2.33:1 failure, because it measures nothing.

- ⚠️ **New colours enter through the design-token system with their pairings; a hardcoded colour in a view is a review flag.** — evidence: the gate is real and currently **passes** (`bash scripts/check_design_consistency.sh` → `✓ Design-consistency check passed`). It fails the build (`exit 1`) on: `circular(14)`, `Colors.grey.shade*`, raw Material status hues, `Color(0xFF…)` outside a 9-entry allowlist, raw brand orange used as a *text* colour, `CircleAvatar`-wrapping-`Icon`, and retired service-identity colours. Gaps:
  - **Scope is `lib/screens` only** (`SCAN_DIR="lib/screens"`). `lib/widgets` is unscanned except by the non-gating histogram — which is why `lib/widgets/glass.dart:147` `const Color(0xFF1C1C1E)` (not allowlisted) and `lib/widgets/document_attach_widgets.dart:314`/`:316` `Colors.amber` (the only two non-neutral Material hues left in the app) both survive.
  - **`Colors.white` / `Colors.black` / `Colors.white70` are on no ban list** — 195 occurrences across `lib/screens` + `lib/widgets` (white 132, transparent 15, white70 13, black 8, white24 7, black12 7, …). These bypass `context.hc.white` / `hc.black` and therefore **do not flip in dark mode**. Worst: `lib/screens/consultation/video_consultation_screen.dart` (21), `lib/screens/home/home_screen.dart` (16), `lib/screens/services/service_booking_screen.dart` (14), `lib/screens/packages/package_detail_screen.dart` (10).
  - **The gate cannot see the actual failure in this audit.** Its orange rule bans raw orange as *text* colour; it has no rule for *white text on an orange fill*, which is the 2.33:1 problem.
  - **Overall this item is the strongest part of the system** — hex literals and named hues are genuinely eradicated from `lib/screens` (6 `Color(0x…)`, all allowlisted). **Fix:** extend `SCAN_DIR` to `lib/widgets`, ban bare `Colors.white`/`Colors.black`, and add a contrast rule keyed on `onOrange`.

- **BLOCKED-OWNER** — **Accessibility findings get fixed at the same priority as functional bugs of equal user impact.** This is a team-process assertion with no repo artifact to verify. `docs/audits/` shows five prior audits (documentation, performance, post-launch ops, security/privacy, upgrade path) and no accessibility audit — this is the first. **To clear this I would need:** the owner to confirm the triage policy, and one release cycle of evidence that a11y findings entered the same tracker/priority queue as functional bugs.

---

## Red flags (checklist's own "stop the release" list)

| Red flag | Present? | Evidence |
|---|---|---|
| Any meaning carried by colour alone | **YES** | `lib/screens/my_care/my_care_screen.dart:420-427`; `lib/screens/home/home_screen.dart:1009`; `lib/screens/calendar/care_calendar_screen.dart:594-607` |
| White text hardcoded onto a brand colour | **YES** | `lib/config/theme.dart:32`, `:70` — `onOrange = #FFFFFF` in both palettes; **2.33:1** (explicit owner decision) |
| A chart with no textual equivalent | **NO** | Every chart and gauge has an adjacent text equivalent — the strongest area of the audit |
| A control under 44pt because "it fits the design" | **YES** | `lib/widgets/document_attach_widgets.dart:47` (18×18); `lib/screens/cart/cart_screen.dart:883` (24×24) |
| "Looks fine" as the only contrast evidence | **YES** | Zero contrast assertions in `test/`; the palette comments assert ratios the code does not have |

---

## Blockers (must fix before release)

1. **White-on-orange is 2.33:1 across the entire persistent chrome.** `lib/screens/main_shell.dart:68/78/79` (nav, incl. 1.82:1 unselected), `lib/config/theme.dart:227-238`/`:412-424` (every primary CTA), `:160`/`:340` (`onPrimary`). **Fix:** add `orangeFillText = #AA670E` (4.51:1) for text-bearing orange fills; keep the white ink; keep `#F39314` for textless decorative fills. Drop the 0.7 α on unselected nav items and carry selection with the outline/filled icon pair already present.
2. **No contrast assertion exists anywhere in the suite.** `rg "contrast|luminance" test/` → 0 hits. **Fix:** `test/widgets/contrast_test.dart` asserting every `HcPalette.light()` **and** `.dark()` pair against 4.5/3.0 via `Color.computeLuminance()`.
3. **Dynamic Type is capped at 1.4× and never tested.** `lib/main.dart:417-424`; zero `textScaler` in `test/`. AX1–AX5 are all suppressed for an elderly-patient app. **Fix:** raise the clamp to ≥2.0 and add a `TextScaler.linear(2.0)`/`3.0` axis to `overflow_smoke_test.dart` for Home/My Care/Services.
4. **17 of 54 icon-only buttons are silent to VoiceOver**, including *call the health manager* and *message the health manager* (`lib/screens/my_care/widgets/health_manager_banner.dart:69`/`:80` — two identical circles with different destinations), *send message* (`lib/screens/chat/chat_screen.dart:335`), and three destructive deletes. **Fix:** add `tooltip:` to all 17.
5. **Removing a family member is swipe-only** (`lib/screens/settings/family_members_screen.dart:319-345`) — unreachable via VoiceOver, Switch Control, or keyboard. **Fix:** trailing overflow button gated by the existing `canManage`.

## High

6. **Clinical vitals status is colour-only and unlabelled** — `lib/screens/my_care/my_care_screen.dart:378-441`. An 8×8 green/yellow/red dot with no text, no icon, no shape variation, and no `Semantics` on the pill. The **same classifier is rendered correctly** 400 lines away in `lib/screens/reports/vitals_screen.dart:846-869` (distinct icon + localized text), and `lib/screens/my_care/medications_screen.dart:220-235` is the textbook shape+colour+label pattern. Copy either.
7. **Attendance text mislabels four of six statuses** — `lib/screens/home/home_screen.dart:1005-1016` renders `status == 'checked_in' ? 'On Duty' : 'Waiting'` while `AttendanceHelper.getStatusColor` (`lib/utils/helpers.dart:65-82`) returns six distinct colours. *late*, *absent*, *on_leave* and *checked_out* are distinguished by colour only **and are actively mislabelled as "Waiting"**.
8. **Three destructive actions with no confirm**, two of them 4pt from a habitual control — `lib/screens/calendar/care_calendar_screen.dart:1308-1314` (delete reminder, persisted, no undo), `lib/screens/cart/cart_screen.dart:982` (next to "Move to Cart"), `lib/screens/settings/patient_profile_screen.dart:145-150`. A `confirmDestructiveAction` helper already exists (`lib/widgets/common_widgets.dart:501-530`) with 8 correct call sites.
9. **Touch targets 18–24pt** — `lib/widgets/document_attach_widgets.dart:47` (18×18), `lib/screens/support/raise_concern_screen.dart:231` (22×22), `lib/screens/cart/cart_screen.dart:883` (24×24 cart stepper), `lib/screens/billing/payment_screen.dart:803` (24×24). The correct 44pt stepper already exists at `lib/screens/services/widgets/quantity_button.dart:44`.
10. **Money and vitals shrink instead of the container growing** — `lib/screens/services/cards/equipment_item_card.dart:125-127`/`:179-181` (prices in fixed 16/18pt boxes under floorless `FittedBox(scaleDown)`), `lib/screens/my_care/my_care_screen.dart:404-413` (vitals value in a fixed 90×88 pill).
11. **Nested tap targets on a call button and a consent checkbox** — `lib/screens/home/home_screen.dart:774` vs `:818` (a near-miss on "call" opens chat), `lib/screens/auth/login_screen.dart:183` vs `:214`/`:234`.
12. **25 modal sheets with no focus management and no `SemanticsService.announce`** anywhere in `lib/`.

## Medium / Low

13. Charts are never `ExcludeSemantics`-wrapped — axis ticks leak as bare nodes (`lib/screens/reports/vitals_screen.dart:361`, `:377`).
14. `care_pulse_ring.dart:86` lacks `excludeSemantics: true` → the percentage is announced twice, at 4 call sites.
15. `lib/screens/my_care/widgets/vitals_trend_grid.dart:64` — semantics label omits the numeric reading.
16. `ProductImage` labels its asset branch (`lib/widgets/common_widgets.dart:131`) but not its network branch (`:134`); same asymmetry at 3 other sites.
17. ~20 `CircularProgressIndicator` with no `semanticsLabel` — loading is announced as silence.
18. `GlassSurface` at 0.55 α gives no worst-pixel guarantee: dark-mode title over a white photo = **3.43:1**; orange glyphs over dark content = **1.44:1** (`lib/widgets/glass.dart:139-152`).
19. Promo banner scrim is 0.45 α → **3.36:1** worst case; 0.55 α would give 4.7:1 (`lib/screens/home/home_screen.dart:600-603`).
20. Dark `textDisabled` `#7A7A7A` on card `#1C1C1E` = **3.96:1**, not the 4.2:1 its comment claims (`lib/config/theme.dart:25`).
21. Dividers carry structure at **1.32:1** light / **1.47:1** dark; segmented thumb at **1.17:1** / **1.27:1**.
22. Two ungated animations — `lib/screens/services/equipment_detail_screen.dart:1690`, `lib/screens/calendar/care_calendar_screen.dart:358`.
23. Calendar day cell is **43.4pt wide at 320pt** (`lib/screens/calendar/care_calendar_screen.dart:551`, `:210-211`), and the `width < 360` branch is exercised by no test (the calendar is absent from `overflow_smoke_test.dart`).
24. `fontSize: 9.5` at `lib/screens/calendar/care_calendar_screen.dart:817` violates the app's own 11px floor.
25. **957 literal `fontSize:` values and 0 `textTheme.` references** — the `TextTheme` in `lib/config/theme.dart:170-215`/`:360-395` is dead code.
26. **195 raw `Colors.white`/`Colors.black`** in `lib/screens` + `lib/widgets` that do not flip in dark mode — worst `lib/screens/consultation/video_consultation_screen.dart` (21).
27. Design gate scans `lib/screens` only — `lib/widgets/glass.dart:147` (un-allowlisted hex) and `lib/widgets/document_attach_widgets.dart:314`/`:316` (`Colors.amber`) escape.
28. Stale contrast claims in `lib/config/app_colors.dart:62-64` and `lib/config/theme.dart:212`, `:229`, `:324-325`, `:417`.
29. `overflow_smoke_test.dart` covers 37 of 55 screens (~67%); the calendar, main shell, care team, chat, login, payment, order tracking and address screens are uncovered.

## BLOCKED-OWNER

- **§4.7 — manual VoiceOver device pass.** Need a physical-iPhone VoiceOver run of the three top flows (book→cart→checkout; My Care→vitals→care calendar; Billing→invoice→PDF) with pass/fail recorded per step. Static analysis cannot substitute.
- **§6.3 — a11y findings triaged at functional-bug priority.** Need owner confirmation of the triage policy plus one release cycle of tracker evidence. This is the first accessibility audit in `docs/audits/`.

---

## Notes on what was deliberately NOT flagged

Per the shared brief, the following are owner decisions or demo-mode behaviour and are reported as measured fact, not as defects to reverse: white-on-orange ink (`onOrange = #FFFFFF`), the fixed full-width solid-orange bottom nav, manpower prices being shown and directly bookable, and the demo-mode `DemoData` fallbacks. The nav is now **five** tabs, not six — the audit reflects the working tree (`lib/screens/main_shell.dart:36-42`) and the care calendar's new home on the My Care app bar (`lib/screens/my_care/my_care_screen.dart:48-54`), which correctly carries `tooltip: 'Care calendar'`.
