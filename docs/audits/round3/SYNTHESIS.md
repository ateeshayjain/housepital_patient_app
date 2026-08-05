# Round 3 synthesis — eleven checklists vs `9a80fe2`

**Date:** 2026-08-03 · Round 2: `820060b` · Round 1: `803124d`
Individual reports sit beside this file. Round 2 remains at `docs/audits/*.md`;
round 1 is recoverable at commit `9c39dc1`.

## The one-sentence result

Every checklist still FAILS, but the *kind* of failure changed for the third time, and
this round it changed for the better.

| Round | What the fixes were | Auditors' phrasing |
|---|---|---|
| 1 → 2 | **Surfaces** — a banner instead of a gate, a `Future.delayed` instead of a request, an upscale instead of a re-export | "each surface now *claims* the thing is handled, which makes the residue harder to see than the original defect" |
| 2 → 3 | **Half-wires** — correct data structures, built from the audit's own recommended wording, with the behaviour those structures exist to enable left unwritten | "harder to catch, because each file reads as correct in isolation" |

Two independent auditors state that **no round-2 repair is a surface**. That is real progress.
It is also the first round with movement in the ✅ column on accessibility (4 → 5) and upgrade
path (0 → 2).

## The half-wire pattern, in three examples

**`DemoMode` as a set of sources.** Eleven source constants declared; eight wired; one
(`markServingLiveData`) call site, for the dashboard only. `reset()` is `@visibleForTesting`, so
**no production path ever empties the set** — and `loadPatients()` raises `sourcePatientIdentity`
in an unconditional pre-API seed that fires on every cold start. The notice would therefore be
permanently lit on a perfectly healthy backend. The set fixed over-clearing by making
under-clearing certain — the exact failure the file's own doc comment cites as its reason for
existing. And because unused public constants are invisible to `flutter analyze`,
`sourceCareTeam` / `sourceCareCalendar` / `sourceProfile` make the enumeration *read* complete
while the four screens they name stay unmarked.

**`StoreMigrator`'s three defects.** All three genuinely fixed, verified by trace. But
`_migrations` is empty and private, so the entire loop body is unexecuted by all ten new tests:
the `catch`, the early `return`, and the `version++` can all be deleted with 1,813 tests still
passing. The most dangerous of the three defects is the untested one, while three of the ten
tests exercise `quarantine()`, which has zero production callers.

**`SessionScope`.** The store diff is now genuinely empty — every provider field and every
patient-scoped prefs key is reached, with real disk assertions. But `SessionScope` is imported by
**zero tests** (one grep hit, and it is a comment) across **three** call sites; delete any one and
the suite stays green. The primitives are guarded; the wiring is not.

## Defects introduced by the round-2 repairs

Ranked by harm. Every one is self-inflicted this round.

| # | Defect | Evidence |
|---|---|---|
| 1 | **Patient switch permanently destroys the outgoing patient's order history.** Storage is keyed globally; the repair now writes `[]` to disk on clear. `patient_scope_isolation_test.dart:273` asserts the destruction as the contract — a test certifying data loss | orders_provider.dart:11-12, :212-219 |
| 2 | **Scheduled OS medication notifications are never cancelled** — patient A's drug name and dose fires on the lock screen after a full logout | security r3, one-line fix |
| 3 | **`vitals_screen.dart:50-70` fabricates 7–180 days of BP/pulse/SpO₂/temp/sugar from `Random(42)` and merges them with real readings**, with no demo flag and no `sourceVitals` constant | sync r3 |
| 4 | **Payment pending is one translation away from a double debit** — the branch is `message.contains('under verification')` against a hardcoded English literal two files away. Localising that string, as the i18n contract requires, restores red "Payment Failed" + Retry on a paid invoice | payment_screen.dart:286 |
| 5 | **"Contact Housepital" on the money-loss path dials `+919999999999`** — I routed it to `/help-faq` under a comment claiming it carries the real numbers | payment_screen.dart:620, help_faq_screen.dart:352 |
| 6 | **The overlay pill absorbs touches** (measured directly — overlapping boxes, tap at the intersection, zero taps reached the control) and occludes the first content line of ≥6 screens, landing on large titles, the patient-switcher chip, and the `/vitals` TabBar | probe + apple/post-launch/release r3 |
| 7 | **`loadPatients` guard clears `AppProvider` only** — meds, orders, cart, assistant transcript, reminders, addresses, ratings and the disk cache survive. The test asserts exactly the one field the implementation clears | app_provider.dart:156-160 |
| 8 | **`logout()` deletes `__quarantine_*`**, defeating the recovery mechanism `StoreMigrator` exists to provide | auth_provider.dart:229-236 |
| 9 | **Blur surfaces per frame doubled, 2 → 4** (≈22% of a 390×844 screen). The σ bump is the smaller half; each `BackdropFilter` is a separate render-pass flush | perf r3 |
| 10 | **Reachable double-tap race** — both `SessionScope` call sites are unguarded async handlers with no busy flag; the second `nav.pop()` pops MainShell | home_screen.dart:1767, settings_screen.dart:455 |

## Corrections to things stated in the round-2 commits

- **"No border on the pill" is false.** Only the *orange* border was removed; `GlassSurface`
  still draws `Border.all(white @0.6, 0.5)` whenever `borderRadius != null`. The white hairline
  on a white page — the original complaint — is still there.
- **The pill contrast figures (5.26:1 / 7.39:1) are a best case, not a fact.** They are correct
  for a pure-white and pure-black backdrop. With `extendBody: true` the backdrop is arbitrary at
  every intermediate scroll offset. Honest range: **5.26 → 3.52:1 light, 7.39 → 4.00:1 dark**.
  The demo pill at `opacity: 0.92` holds within 0.25 across all backdrops; the nav pill at 0.78
  does not.
- **`onError` reached 3 of 14 destructive sites**, all in one screen. The shared
  `confirmDestructiveAction` helper (`common_widgets.dart:522`, 14 call sites) still hardcodes
  `Colors.white` = 3.49:1 in dark, invisible to the gate because it scans `lib/screens` only.
- **`SCREEN_MAP.md` now declares five tabs and enumerates six** — the header line was fixed and
  the list below it was not.

## The design argument worth accepting

Apple's rule: *transient* status occludes and leaves; *persistent* status participates in chrome
and displaces. `UINavigationItem.prompt` is the precedent. Round 2 never objected to the banner
displacing content — it objected to the inset being counted **twice**, which was a one-line
arithmetic fix. The repair replaced the mechanism instead, and inherited occlusion, touch
absorption, truncation (`maxLines: 1` ellipsises the warning in Hindi and at the 1.4× ceiling),
and a whole-subtree re-parent on flag flip.

The correct home is `GlassAppBar.bottom:` — it sizes itself via `preferredSize`, so no screen
does inset maths, which is the exact property the overlay was chasing.

## What is now genuinely settled

- **Payments.** One importer, one `openCheckout` call site, no third path, guard on the right
  axis (`isDemoPayments` is a positive whitelist), `patientId == null` fails closed. Structural.
- **`onError`** at the token layer, with the dark arm correctly getting dark ink.
- **Route coverage** for the demo notice — it is above the Navigator and reaches pushed routes.
- **The `SessionScope` store diff** — empty against a tree-built enumeration.
- **`ANTHROPIC_API_KEY`** — clean on every ref, third independent verification. Settled; it does
  not need a fourth pass.
- **Localization moved for the first time**: 14.2% → 16.3%, 353/353 key pairs, all real
  Devanagari.

## Backend findings (new this round)

Two auditors independently reached **merge, don't sync**, with evidence round 2 lacked:

- The staff DB has **no `patients` table at all** — patients are denormalised columns on
  `deployments`. The two schemas disagree on identity, grain
  (`UNIQUE(deployment_id,date)` vs `UNIQUE(staff_id,date)` — neither is a total function for the
  business) and vocabulary (three enum pairs meaning the same thing).
- **`family_members.user_id` is `UNIQUE` and `auth.ts:38` takes `.first()`** — the server
  structurally cannot return two patients, so the patient-switch feature that two rounds of PHI
  work exist to protect would 403 against a real backend.
- `verifyPatientAccess` passes through when `patientId` is `""`, giving cross-patient reads by
  id guessing.
- Live code-vs-schema drift: `medications.ts:217` queries `patient_id` on a table without that
  column; `ratings.ts:37,48` uses `family_member_id` where the column is `rated_by`.

Zero production rows today makes this a schema exercise now and a live-patient migration later.

## The highest-leverage single item

A **`user_patients` custom claim** issued by the backend. The same missing primitive blocks
Storage isolation, Firestore isolation, and a safe tool-using assistant simultaneously. Every
"can't scope per patient" finding in this round traces back to it.

## Storage rules: deploy, with conditions

The security audit's verdict is **deploy as-is** — strictly tighter than the plausible live
default, and satisfiable (both upload sites match, no `.uid` needed). Conditions:
1. Fix `CLAUDE.md`'s "per-patient paths" wording — it reads as isolation the rules explicitly disclaim.
2. **Disable anonymous auth** (`firebase.json:17`) — it converts "any patient" into "anyone".
3. Add bucket quota/lifecycle guards.

Known and unprotected: cross-patient reads of *known* keys, cross-patient **writes** into another
patient's concern batch (permanent, since `update,delete: if false`), and `getDownloadURL()`
bearer tokens that bypass rules entirely and cannot be revoked by a rules change.
