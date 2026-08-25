# Post-Launch Operations Checklist (App-Agnostic) — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-03 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Auditor:** post-launch-ops agent · **Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app`
**Method:** read-only. Every verdict cites `file:line` or a command with its output. No `flutter test` /
`build` / `clean` was run (concurrent agents); central results cited from the brief.

The app has **not launched**. Every item is graded as *readiness to operate on day 1*, not as
operational history.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| B1 · Clinical demo data silently substituted | ⚠️ | ⚠️ **partial — race half-fixed, coverage half-fixed, and a NEW stuck-on failure introduced** | `lib/data/demo_mode.dart:21-66`; only 3 of 7 named silent sources now mark; `markServingLiveData` has **one** call site in the entire tree. See §A |
| B2 · Placeholder support numbers | ❌ | ❌ **unchanged** | `lib/screens/settings/help_faq_screen.dart:352` `tel:+919999999999`, `:365` `wa.me/919999999999`; `lib/screens/my_care/staff_otp_verification_screen.dart:352` `tel:+918888888888` |
| B3 · Android release signed with DEBUG keystore | ❌ | ❌ **unchanged (re-verified, byte-identical)** | `android/app/build.gradle.kts:34-37`; `ls android/key.properties` → No such file or directory |
| B4 · Payments never verified server-side | ✅ | ✅ **holds** | `lib/screens/billing/payment_screen.dart` still the only `openCheckout` path; billing "Pay Now" rerouted per `5fa6d95` |
| B5 · Auth gate disabled | ❌ | ❌ **unchanged (re-verified)** | `lib/main.dart:417-419` `// NOTE: Auth gate disabled for demo mode.` → `home: const SplashScreen()`; `lib/screens/splash_screen.dart:14-18` pushes `/home` after 2 s |
| B6 · No iOS dSYM upload phase | ❌ | ❌ **unchanged (re-verified)** | `grep -c "upload-symbols" ios/Runner.xcodeproj/project.pbxproj` → **0**; `grep -c "Crashlytics" …` → **0** |
| B7 · iOS crashes on camera/photo | ✅ | ✅ **holds** | `ios/Runner/Info.plist:73-76` |
| H8 · Zero analytics | ❌ | ❌ **unchanged** | no `firebase_analytics` / `logEvent` in `lib/`, `functions/`, `pubspec.yaml` |
| H9 · No flag / kill switch / force-upgrade | ❌ | ❌ **unchanged** | `grep -rniE "remote_config\|killSwitch\|forceUpgrade\|maintenanceMode"` over `lib/ functions/ pubspec.yaml` → no matches |
| H10 · Non-fatals never reported (`logger.dart:63`) | ❌ | ❌ **unchanged verbatim — and its cost went UP** | `lib/utils/logger.dart:63-65` TODO unchanged. See §D.2 for the observability regression it now conceals |
| H11 · Android `<queries>` missing | ❌ | ❌ **unchanged, and now breaks a third surface** | `android/app/src/main/AndroidManifest.xml:39-48` — only `PROCESS_TEXT`. Now also blocks `android.speech.RecognitionService`. See §F.6 |
| H12 · Background-isolate errors uncaptured | ❌ | ❌ **unchanged** | `grep -rn "addErrorListener" lib/` → no matches |
| H13 · No account/data deletion path | ⚠️ | ⚠️ **record is now durable; the receiver is still nobody** | `lib/screens/settings/delete_account_screen.dart:60,78-91`; `lib/providers/auth_provider.dart:230-236`. **Zero readers.** See §C |
| H14 · Server-side prerequisites unverified | ❌ | ❌ **unchanged** | `.firebaserc` still `{"projects":{},"targets":{},"etags":{}}`; `docs/KNOWN_ISSUES.md:25` BUG-33, `:26` BUG-34 untouched; `storage.rules` still shows no deploy evidence |
| H15 · No user-symptom playbooks | ❌ | ❌ **unchanged** | `ls docs/` — same 15 files + `audits/`; nothing added since round 2 |
| M16 · Hardcoded version, no build number | ❌ | ❌ **unchanged** | `package_info_plus` still absent from `pubspec.yaml` |
| M17 · No in-app "What's new" | ❌ | ❌ **unchanged** | no matches in `lib/`, `assets/i18n/` |
| M18 · `KNOWN_ISSUES.md` stale | ❌ | ❌ **unchanged — now ten weeks + two commits stale** | `docs/KNOWN_ISSUES.md:5` still "Last updated: 2026-05-28"; `:53` BUG-14 still false; `:39` BUG-07 still "cause unknown" against a green 1,813-test suite. `0f2729e` updated six docs and skipped this one |
| M19 · Wrong package id in deploy docs | ❌ | ❌ **unchanged** | `docs/KNOWN_ISSUES.md:26` still `in.housepital.patient`; real id `com.housepital.housepital_patient` (`android/app/build.gradle.kts:24`) |
| M22 · Severity ladder / SLA inert | ❌ | ❌ **unchanged** | `docs/KNOWN_ISSUES.md:90` TD-11; `lib/config/constants.dart:52-57` |
| §6.1(c) · App-side schema stamp | ✅ | ✅ **holds, and is now tested** | `lib/services/store_migrator.dart:33,35`; `test/services/store_migrator_test.dart` (174 lines, 9 tests) |
| §A.2 · Banner absent on pushed routes | ❌ (blocker 1) | ✅ **genuinely fixed** | `lib/main.dart:433-434` — `DemoDataBannerHost` installed from `MaterialApp.builder`, above the Navigator. See §B |
| §A.3 · `reset()` racy in both directions | ❌ (blocker 3) | ⚠️ **false-negative fixed; false-positive made CERTAIN** | `lib/data/demo_mode.dart:46-54`; `lib/providers/app_provider.dart:273` is the only clear. See §A.2 |
| §B · `StoreMigrator` unsafe boundary | ⚠️ (high 9) | ⚠️ **throw-safety real; hang-safety unchanged; observability regressed** | `lib/services/store_migrator.dart:56-67,113-125,134`; still no `.timeout()` at `:70`. See §D |

**Net for round 3:** 1 round-2 blocker genuinely closed (banner route coverage). 2 items materially
improved but not closed (StoreMigrator throw-safety, deletion durability). 1 item **regressed**
(the sample-data notice as a monitoring signal — §A.2/§B.3). 15 items byte-identical to round 2,
several of which are byte-identical to round 1. `docs/KNOWN_ISSUES.md` was not touched by any of the
five commits since round 1.

---

## Round-2 repairs: adversarial review

Four repairs landed in my scope. Two are real, one is a half-repair that made a different failure
certain, and one moved a failure from *visible* to *invisible*.

### The pattern this round

Round 2's headline was **surfaces**: a banner instead of a gate, a `Future.delayed` instead of a
request. Round 3's pattern is different and subtler — **the repairs are structurally correct and
operationally incomplete**. The mechanism is right every time; the last wire is missing every time:

| Repair | Mechanism | Missing wire |
|---|---|---|
| `DemoMode` becomes a set | correct — per-source, `mark`/`clear` | **7 of 8 sources never call `clear`.** One call site exists |
| 11 source constants declared | correct — one per known fallback | **3 are never referenced** (`sourceCareTeam`, `sourceCareCalendar`, `sourceProfile`) |
| Notice becomes an overlay | correct — above the Navigator, displaces nothing | **no `IgnorePointer`**, and it sits exactly where non-glass screens start content |
| Deletion record made durable | correct — survives `logout()` by name | **zero readers.** `deliveredToServer:false` has no writer of `true` |
| `StoreMigrator.run()` made throw-safe | correct — whole body guarded, tested | **the catch logs to a dead logger**; a throw that used to reach Crashlytics now reaches nothing |

This is a recognisable failure mode: the *data structure* was fixed from the audit's own suggested
wording ("make the flag a set… each provider clears only its own key on success" — round 2 §A.3) and
the *behaviour change that the structure exists to enable* was not written. A reviewer reading
`demo_mode.dart` alone would call it fixed. It is the second half of the same sentence that is missing.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Release mechanics | 0 | 3 | 2 | 1 |
| 2. Monitoring cadence | 0 | 0 | 4 | 0 |
| 3. Incident response | 0 | 3 | 2 | 0 |
| 4. Support readiness | 0 | 1 | 3 | 1 |
| 5. Feedback → roadmap | 0 | 3 | 1 | 0 |
| 6. Data stewardship | 1 | 2 | 1 | 0 |
| **Total (28)** | **1** | **12** | **13** | **2** |

Round 2: 1 ✅ / 13 ⚠️ / 12 ❌ / 2 N/A. Round 1: 1 ✅ / 11 ⚠️ / 14 ❌ / 2 N/A.

**One item moved, and it moved backwards.** §2.3 ("user-visible failure surfaces are treated as
monitoring") goes ⚠️ → ❌. Round 2 upgraded it because a failure surface existed; round 3 downgrades
it because that surface is now **stuck on** (§A.2) and therefore carries zero information. A warning
that is always lit is not a monitor. The route-coverage blocker being fixed does not offset this —
it makes it worse, because the always-on notice is now always-on on *every* route.

Nothing moved to ✅ in three rounds.

---

## Findings

### §A — `DemoMode` as a set: is the race genuinely gone?

**Half of it. The other half was made certain rather than merely likely.**

`lib/data/demo_mode.dart:21-66` is well designed and its doc comment (`:11-20`) diagnoses the
round-2 problem exactly right. `markServingLiveData` (`:52-54`) removes only the named source, so
one provider can no longer speak for another. That part is real.

#### A.1 · Which sources mark now, and which are still silent

Round 2 named seven silent demo sources. Three were wired; four were not.

| Round-2 site | Now | Evidence |
|---|---|---|
| `handover_report_service` (the doctor PDF) | ✅ **marked** | `lib/services/handover_report_service.dart:105` `markServingDemoData(sourceHandover)` — plus the "SAMPLE DATA" header band |
| `app_provider` patient identity | ✅ **marked** | `lib/providers/app_provider.dart:142` `markServingDemoData(sourcePatientIdentity)` |
| `blog_provider` articles | ✅ **marked** | `lib/providers/blog_provider.dart:40,70` |
| `patient_profile_screen:898` — allergies & conditions | ❌ **still silent** | `lib/screens/settings/patient_profile_screen.dart:898` `_buildMedicalHistory(DemoData.medicalHistory)`, still under a "…synced" subtitle |
| `care_event.dart` — the whole Care Calendar | ❌ **still silent** | `lib/models/care_event.dart:57,71,97,105-106,118` |
| `doctor_advice_card:46` — clinical advice | ❌ **still silent** | `lib/screens/my_care/widgets/doctor_advice_card.dart:46` |
| `care_team_screen:29,31,162-164` | ❌ **still silent** | `lib/screens/care_team/care_team_screen.dart:29,31,162,164` |
| (also) `care_calendar_screen:1324` staff-on-duty | ❌ **still silent** | `lib/screens/calendar/care_calendar_screen.dart:1324` |

**The fingerprint of the incomplete repair is in the file itself.** Eleven source constants are
declared at `demo_mode.dart:24-34`. Three are never referenced anywhere in `lib/` or `test/`:

- `sourceCareTeam` (`:31`)
- `sourceCareCalendar` (`:32`)
- `sourceProfile` (`:33`)

Those are precisely the three unwired sites above. The author enumerated round 2's list into
constants — the comment at `:22-23` even says "Add a constant here in the same edit that adds a
fallback" — and then wired only some of them. An unused public `static const` is invisible to
`flutter analyze`, so the suite is clean and the design gate passes while three declared promises
sit unkept. **The constant list reads as coverage and is not coverage.**

**New silent source, not on round 2's list.** `lib/main.dart:234,237,260` constructs
`AssistantProvider` with `DemoData.patient.id`, `DemoData.healthManager` and
`DemoData.icuDeployment.id`, and hardcodes `const role = UserRole.primaryContact` (`:236`). Nothing
marks. This matters far more than it did last round: it is the identity **every assistant action
executes against** (§F.2), and the owner intends the assistant to become the primary interface.

#### A.2 · The false-positive direction is not fixed — it is now guaranteed

`grep -rn "markServingLiveData" lib/` returns **exactly one** call site outside the class itself:

```
lib/providers/app_provider.dart:273:      DemoMode.markServingLiveData(DemoMode.sourceDashboard);
```

Eight sources can mark. **One can clear.** The seven that mark and never clear:

| Source | Marked at | Cleared |
|---|---|---|
| `sourcePatientIdentity` | `app_provider.dart:142` | never — `loadPatients()`'s success branch (`:150-162`) does not clear |
| `sourceMedications` | `medication_provider.dart:191,236` | never |
| `sourceMyCare` | `my_care_provider.dart:50,98` | never |
| `sourceBilling` | `billing_provider.dart:43` | never |
| `sourceOrders` | `orders_provider.dart:199` | never |
| `sourceArticles` | `blog_provider.dart:40,70` | never |
| `sourceHandover` | `handover_report_service.dart:105` | never |

`DemoMode.reset()` (`:56-62`) is annotated `@visibleForTesting` and its only caller is
`test/providers/patient_scope_isolation_test.dart:213`. **There is no production path that empties
the set.**

Two consequences, both certain rather than probabilistic:

1. **The notice is on from the first frame of every session, on a perfectly healthy backend.**
   `loadPatients()` marks `sourcePatientIdentity` in an *unconditional* pre-API seed
   (`app_provider.dart:135-143` — the `if (_patients.isEmpty)` guard is true on every cold start),
   and the success branch never clears it. Home mounts → mark → API succeeds → still marked. Round 2
   warned the banner would "cry wolf on the happy path"; the set rewrite made that the *only* path.
2. **One handover PDF pins it for the process lifetime.** `handover_report_service.dart:105` marks
   on every `buildHandoverPdf()` call. That mark is correct for the PDF (which travels beyond the
   app and carries its own printed band) but it is scoped to the whole app and never cleared, so a
   family member who exports one report sees "Sample data — not your live record" over live vitals
   until they force-quit.

So: the race round 2 described as "a hidden banner over sample medication data **and** a spurious
banner over live data" has had its first half fixed and its second half converted from a race into a
constant. **This is a regression in operational value**, because an intermittent false alarm is a
bug and a permanent false alarm is noise the user learns to ignore in week one — which costs the
signal its value in exactly the incident it was built for. Support's diagnostic question ("do you
see the sample-data pill?") now has the answer "yes" for every user, always.

**Fix (small):** add `markServingLiveData(<own source>)` to the success branch of each of the seven
providers, in the same `try` that currently only assigns data; wire the three dead constants at
their four silent sites; scope `sourceHandover` to the PDF's own render rather than the app.

#### A.3 · Test coverage of the repair

`grep -rln "DemoMode\|DemoDataBanner\|demo_data_banner" test/` → two files:
`test/providers/patient_scope_isolation_test.dart` (AppProvider dashboard path only) and
`test/services/store_migrator_test.dart` (unrelated). **No test asserts the notice renders**, none
asserts a source clears, and `test/screens/main_shell_test.dart` — *rewritten this round* in
`d439928` — does not mention it. Every defect in §A.1 and §A.2 is invisible to the 1,813-test suite.

**Grade: ⚠️.** Right structure, one wire in eight connected.

---

### §B — The overlay: does it render on pushed routes?

**Yes. Verified structurally.** `lib/main.dart:422-436` — `MaterialApp.builder` wraps `child` (the
Navigator) in `DemoDataBannerHost` (`:434`), inside the text-scaling `MediaQuery`. Everything the
root navigator pushes — `/medication-schedule` (`main.dart:580`), `/vitals`, `/patient-profile`,
`/care-calendar`, `/care-team` — is below that wrapper, as are dialogs and modal routes. Round 2's
blocker 1 is **closed**. `lib/widgets/demo_data_banner.dart:13-27` also documents both prior wrong
shapes so they are not re-adopted, which is good practice.

Three operational caveats, one of them unrecorded anywhere.

**B.1 · Occlusion vs displacement — overlay is the better trade, but not as placed.**
The brief asks for a judgement. Overlay is right: displacement was a *global* cost (every glass app
bar pushed down, a quarter of the first screen lost) paid on every screen whenever the notice showed;
occlusion is a *local* cost paid only where content starts high. And only the overlay can cover
pushed routes at all. **But the chosen y is the worst available one.** The pill sits at
`MediaQuery.padding.top + kToolbarHeight + 4` (`demo_data_banner.dart:45`) — which is precisely
where a non-`extendBodyBehindAppBar` screen begins its body. `lib/screens/settings/settings_screen.dart:87-93`
is a `Scaffold` with `GlassAppBar` and **no** `extendBodyBehindAppBar`, and its `ListView` has no top
padding, so its first child — the profile row at `:95-99` — is under the pill. Moving the pill to the
**bottom**, above the floating nav pill, costs nothing: the nav pill already reserves its own bottom
inset (`CLAUDE.md`, bottom-nav contract) and no screen starts content there.

**B.2 · It absorbs taps. Nothing in the repo notes this.**
`demo_data_banner.dart:39-50` is a bare `Stack` with a `Positioned` child; there is no
`IgnorePointer` (`grep -c "IgnorePointer" lib/widgets/demo_data_banner.dart` → **0**). The
`GlassSurface` → `Container` with a `BoxDecoration` (`:96-108`) is hit-testable, so the pill swallows
taps in its footprint. Combined with §A.2 (permanently on) and B.1 (positioned on the first row),
the app as it stands ships a **permanently visible, tap-eating pill over the first control of every
non-glass screen**. On Settings that control is the profile row. This is a one-word fix
(`IgnorePointer(ignoring: true, child: …)`) and it is not in `KNOWN_ISSUES.md`, the CLAUDE.md
contract, or any test.

**B.3 · As a monitoring signal it is now worse than in round 2.** See §A.2. Grading §2.3 ❌.

**Grade: ✅ for route coverage · ⚠️ for placement · ❌ for its value as a signal.**

---

### §C — The deletion obligation: an SLA with no meter

The repair is real as far as it goes. `lib/screens/settings/delete_account_screen.dart:78-91` writes
`housepital_pending_deletion` — reference, ISO timestamp, patient id, `deliveredToServer:false` —
*before* anything else, and `lib/providers/auth_provider.dart:230-236` replaces the old
`prefs.clear()` with a preserve-list so the record survives logout. The screen also now deletes the
Firebase credential (`:126-136`) rather than only signing out, and separates DONE from REQUESTED in
its dialog (`:148-168`). Compared with round 2's `Future.delayed(600ms)` under a 30-day promise, this
is a genuine improvement in honesty.

**Operationally, it is still zero.** `grep -rn "pending_deletion\|pendingDeletionKey" lib/ test/ docs/ functions/`
returns exactly three hits: the constant (`:60`), the write (`:84`), and the logout preserve-list
(`auth_provider.dart:233`). **There is no read. Anywhere.** Not on next boot, not in Settings, not in
an export, not in a test, not in a doc.

Assessed as the brief asks — as an operational commitment:

- **Owner: none.** No name in `docs/`, no rota, no queue. The commitment is made by the app and
  accepted by nobody.
- **Meter: none.** The 30-day clock starts on the patient's phone. Nothing counts requests, ages
  them, or alarms at day 25. There is no analytics SDK (H8) to carry even a bare event, and
  `logger.dart:63` would drop it if there were.
- **Durability is bounded by the trigger.** `SharedPreferences` is app-scoped on both platforms and
  is destroyed on uninstall. Uninstalling is the single most likely next action of a user who just
  deleted their account. So the "durable" record is most likely to be erased precisely in the case
  where it was the only evidence.
- **`deliveredToServer:false` is a schema for a process that does not exist.** No code writes `true`;
  there is no queue, no retry, no replay-on-boot, and `lib/services/api_service.dart` still has no
  deletion endpoint. The field documents an intention, which is honest, but it will read as a
  working outbox to whoever inherits this file.
- **The inbound path is still a phone line with no ticket system** (`delete_account_screen.dart`
  publishes 9990-911-911; `docs/KNOWN_ISSUES.md:90` TD-11 records that the concern SLA "is not
  enforced or alerted").
- **Auth is off** (`main.dart:417-419`), so `patientId` in the record is `DemoData.patient.id`
  (`app_provider.dart:137`) for every user — one shared fake id across all requesters. Even a future
  replay could not tell two patients apart.

**Minimum process to make this real** — the smallest set that turns a promise into an obligation
somebody can be held to. None of it needs the backend:

1. **A receiver, today.** Write the same JSON to Firestore `deletion_requests/{deviceOrUid}` in the
   same `try` as the local write. It needs no schema, no server code, and it is queryable by one
   person in a console. *(Blocked on §E.2 — with auth off, `request.auth` is null and
   `firestore.rules` deny-by-default will reject the write. Enabling anonymous auth, already
   configured at `firebase.json:15`, is the unblock.)*
2. **A replay.** On the next successful boot with a reachable backend, read the key and POST it;
   set `deliveredToServer:true` only on a 2xx. Ten lines, and it is what makes the record durable
   in fact rather than in name.
3. **A named owner and a weekly slot** in `docs/`: who opens the queue every Monday, what they do
   with a row, and who covers them. A queue nobody reads is the same failure with extra steps.
4. **A visible receipt.** Show the pending reference and its date in Settings after deletion, so the
   patient holds evidence the app made a promise. Today the reference appears once, in a dialog,
   after which the app has no surface that admits the request exists.
5. **Copy that matches (2).** Until the replay ships, say "recorded on this device and sent to
   Housepital when we reconnect" rather than a bare 30-day guarantee. The file's own header
   (`:24-30`) already holds this standard; the dialog copy does not yet meet it.

Add the deletion commitment to the privacy policy (still ❌ under §6.4).

**Grade: ⚠️** — the request is now recorded; the obligation is still unowned and unmeasured.

---

### §D — `StoreMigrator`: blast radius, and the observability trade

#### D.1 · Throw-safety: ✅ genuinely fixed, and tested

`lib/services/store_migrator.dart:56-67` — `run()` now wraps the **entire** `_run()` body, so
`SharedPreferences.getInstance()` (`:70`), every `prefs.setInt` (`:76,123,128,134`) and everything in
`quarantine()` (`:151-169`) are inside the guard. Round 2's "the never-throws contract is not
enforced at the boundary" is closed. Two related repairs are also real:

- **A failed step no longer advances the stamp** (`:113-125`): it logs, stamps the last *good*
  version, and returns so the step is retried next launch. Round 2's item 4 closed.
- **The `while (1 < 1)` hole is closed** (`:134`): `_migrateFrom` always leaves a stamp.
- **`_v1Keys` replaced by `prefs.getKeys()`** (`:139-144`), with the reasoning preserved at `:37-43`.

And it now has tests: `test/services/store_migrator_test.dart`, 174 lines, 9 tests across first
install, pre-versioning, idempotence, downgrade, corrupt stamp, and quarantine typing. The
"never throws" case is pinned at `:117-128` with a corrupt (`String`) stamp. This is the strongest
piece of work in the round-2 repair set.

#### D.2 · Observability: ❌ — and the repair made this specific case *worse*

Every failure path still reports only through `Log.warn` / `Log.error` —
`store_migrator.dart:64,80,93,108,114,167` — and `lib/utils/logger.dart:63-65` is unchanged verbatim:

```dart
// TODO(observability): forward warn/error to FirebaseCrashlytics.recordError
// here once a non-fatal reporting policy is decided. Kept as a single
// chokepoint so that wiring is a one-line change.
```

In a release build `debugPrint` reaches nobody. So a migration that skipped a step, quarantined a
store, or aborted entirely produces **zero** signal on a real phone. That was round 2's finding and
it is unchanged.

**What is new, and worth ranking above it: for one important class of failure, the repair moved the
signal from *visible* to *invisible*.** Before `5fa6d95`, a platform-channel throw at
`getInstance()` escaped `run()`, escaped the `await` at `main.dart:174`, and was caught by
`runZonedGuarded` (`main.dart:100`) → recorded to Crashlytics as a fatal. Terrible UX (black screen),
but the team **learned about it**. After `5fa6d95` the same throw is swallowed at `:63-66`, logged to
the dead chokepoint, and the app starts normally on **un-migrated data**. The user experience is
correctly improved; the operational visibility went from "unsymbolicated fatal in Crashlytics" to
"nothing, anywhere, ever". Silent-continue is the right behaviour *only* if the continue is reported.
Right now it is the definition of a silent failure.

**Ranking.** Across this whole checklist, wiring `logger.dart:63` is **the single highest-value line
of code available**, and it is worth strictly more this round than last, for three compounding
reasons: (a) `StoreMigrator` now degrades silently by design, so the log line is the *only*
difference between a healthy migration and a failed one; (b) the deletion flow's two failure paths
(`delete_account_screen.dart:105,133`) log the same way — a patient whose credential deletion failed
is invisible; (c) the assistant, which the owner wants as the primary interface, does not even reach
the dead logger (§F.5). I rank it **High-1**, above every other non-blocker in this report.

#### D.3 · Residual blast radius: the hang, not the throw

`try/catch` converts a *throw* into a survivable event. It does nothing for a *hang*.
`grep -c "timeout" lib/services/store_migrator.dart` → the `getInstance()` await at `:70` still has
no `.timeout(...)`, unlike every API call in the app (`app_provider.dart:255`,
`medication_provider.dart:200` — 5 s). It sits before `runApp()` (`main.dart:174`). A hung platform
channel is an **indefinite splash**: no crash, therefore no crash report, therefore no Crashlytics
signal even after `logger.dart` is wired — only ANRs on Android and one-star reviews on iOS. With no
kill switch (H9) and no phased-release lever on Android (debug signing, B3), there is no remedy
short of a store update.

This is now the *larger* half of the original finding, and it is untouched. Three lines:
`.timeout(const Duration(seconds: 3))`, skip migration on timeout, log the skip.

**Grade: ⚠️** — good design, throw-safe and tested, hang-unsafe and unobservable, on the critical
path of every cold start.

---

### §E — Re-verification of the three untouched items

- ❌ **Android release is debug-signed.** `android/app/build.gradle.kts:32-38`:
  `signingConfig = signingConfigs.getByName("debug")`, TODO comment intact.
  `ls android/key.properties` → *No such file or directory*. No `signingConfigs { create("release") }`.
  **Unchanged across all three rounds.** Consequence for this checklist: §1.1 phased release and
  §1.3's "halt the phase" rollback are unavailable on Android, and §1.6 cannot begin.
- ❌ **Auth gate disabled.** `lib/main.dart:417-419` — the commented-out `Consumer<AuthProvider>` and
  "Enable before production release" are unchanged; `lib/screens/splash_screen.dart:14-18`
  `pushReplacementNamed('/home')` after 2 s. **Unchanged.** It silently invalidates three other
  repairs: §C.1 (no uid to record a deletion against, and Firestore rules deny an unauthenticated
  write), §A (with no session the demo fallback is not a degraded state but the *only* state), and
  §F.1 (there is no identity for the assistant endpoint to verify even if it wanted to).
- ❌ **No iOS dSYM upload phase.** `grep -c "upload-symbols" ios/Runner.xcodeproj/project.pbxproj`
  → **0**; `grep -c "Crashlytics" …` → **0**. Six `PBXShellScriptBuildPhase` entries
  (`:280-390`): Flutter embed_and_thin, Pods frameworks, two Podfile.lock diffs, Pods resources,
  Flutter build. None uploads symbols. On an iOS-first app, every crash — including the
  `runZonedGuarded` fatal that §D.2 describes — arrives unreadable. **Unchanged.**

---

### §F — NEW: operational readiness of a voice-first AI assistant

The owner intends the assistant to become the primary interface, driven by voice. Assessed as a
production service, not a demo feature. **Grade: ❌ — not operable as a primary interface.**

Today it is inert: `AssistantService` uses the offline Hinglish stub because
`AppConstants.assistantApiUrl` is empty (`lib/config/constants.dart:10-11`;
`lib/main.dart:249-252` → `useStub: assistantUrl.isEmpty`), and `.firebaserc` is empty so nothing has
been deployed from this tree. That inertness is the *only* thing standing between the app and every
issue below — and it is a single `--dart-define` away from being switched off, all at once, with no
staged exposure.

#### F.1 · No authentication — the endpoint is open to the internet

`functions/index.js:112-119` uses `onRequest` (raw HTTPS) with `cors: true`, i.e. any origin.
`grep -cE "maxInstances|appCheck|verifyIdToken|enforceAppCheck|authorization" functions/index.js` → **0**.
There is no ID-token check, no App Check, no shared secret, no `onCall`. The URL is printed by
`firebase deploy` (`functions/README.md`) and compiled into the shipped binary via
`--dart-define=ASSISTANT_API_URL`, where it is trivially recoverable from an APK or IPA. Anyone who
finds it is a user of the owner's Anthropic account.

#### F.2 · Role is client-asserted and fails **open**

`index.js:142-149` reads `role` from the request body and, when it is unrecognised, silently
substitutes `"primary_contact"` — the **most** privileged role. The comment at `:139-141` claims
defence-in-depth ("the app-side executor independently re-checks permissions against the real role"),
but the app-side role is itself a hardcoded literal: `lib/main.dart:236`
`const role = UserRole.primaryContact`. The "independent" check re-checks the same constant. There is
no second factor anywhere. Separately, `patient_id` is in the documented contract at `index.js:3` and
is **never read** by the handler — so the server cannot tell whose behalf it is acting on, which is
why it can neither log per patient (§F.5) nor limit per patient (§F.3).

The one action with a real-world dispatch consequence is also the one with no gate on either side:
`lib/screens/assistant/assistant_executor.dart:479-483` deliberately never role-gates `sos`. That is
correct per the inviolable "SOS is never blocked" rule, and it is exactly why an unauthenticated
endpoint that can *route to* SOS deserves a gate at the perimeter instead.

#### F.3 · No rate limit, no cost ceiling — and failure is silent-by-design

`grep -rniE "ratelimit|maxRequests|requestsPerMinute|throttle"` over `lib/` and `functions/` → no
matches. The only bounds in the function are `slice(0, 1000)` on input (`:129`) and `max_tokens: 512`
(`:157`) — both cap the cost of **one** call, not the number of calls. The runtime options
(`:113-119`) set region, memory, timeout and cors, but **no `maxInstances`**, so concurrency runs to
the platform default. There is no budget alert in the repo; `functions/README.md` tells the owner to
"set a budget/spend limit in the console" — a manual step with no verification, tracked nowhere,
joining BUG-33 and BUG-34 in the untracked-console-prerequisite pile.

The default model is `claude-opus-4-8` (`index.js:26`) — the priciest tier, selected by an env var
nobody has set. **Unauthenticated + unlimited + most-expensive-by-default** is the canonical
bill-drain shape. And the drain is invisible: every error path returns `200` with `DEGRADED`
(`:191-195`), so an abuser sees success, the app shows a polite Hinglish message, and the first
signal the owner receives is an invoice.

The client adds nothing: `grep -c "timeout" lib/services/assistant_service.dart` → **0**. The POST at
`assistant_service.dart:51-57` has no timeout, unlike every other network call in the app.

#### F.4 · Nothing about deployment is verified

`.firebaserc` is `{"projects":{},"targets":{},"etags":{}}`, so `firebase deploy --only functions`
cannot run from this tree without an explicit `--project`. There is no deploy log, no function URL
recorded, no secret-set confirmation. Same posture as `storage.rules` (§H14) — the repo cannot
distinguish "not deployed" from "deployed and drifted".

#### F.5 · No record of what it was asked to do on a patient's behalf

`grep -n "console\." functions/index.js` returns **one line**: `:192`
`console.error("assistant error:", err)` — the failure path only. On success, nothing records the
user's words, the chosen action, the params, the role, or any request id. On the client,
`grep -rn "Log\." lib/screens/assistant/ lib/providers/assistant_provider.dart lib/services/assistant_service.dart`
returns **zero hits**: the executor logs via bare `debugPrint`
(`assistant_executor.dart:310,340,367,397,407,441,463`), so the assistant is the one subsystem that
does not even reach the (dead) chokepoint at `logger.dart:63`.

Consequence, stated as an operator would meet it: when a family member calls and says *"the app
booked a nurse I never asked for"* — or *"it called the ambulance"* — there is no record of what was
said, what the model decided, what the confirm card showed, or whether the user tapped Confirm. For a
home-healthcare service that is not a telemetry gap; it is the **absence of a clinical audit trail**
for actions taken in a patient's name. It is also the mechanism by which an LLM routing mistake
becomes unfalsifiable in both directions: the company cannot prove it did not happen, and the family
cannot prove it did.

Credit where due: confirm-before-act is genuinely well built and is the right control.
`assistant_provider.dart:47,110-111,131-143` holds a `pendingConfirmation` and fires only on explicit
confirm (button **or** a typed/spoken "haan/yes", `:56-61`); calls, concerns, bookings, renewals and
staff replacements all route through `RequiresConfirmation`
(`assistant_executor.dart:190-201,252-263,469-497`). Nothing about that design is wrong. It simply
leaves no trace.

#### F.6 · Voice specifically

- **iOS is ready.** `ios/Runner/Info.plist:69-72` declares `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` with sensible copy.
- **Android will fail silently.** `RECORD_AUDIO` is declared
  (`android/app/src/main/AndroidManifest.xml:5`), but the `<queries>` block (`:39-48`) contains only
  `PROCESS_TEXT`; `grep -c "RecognitionService" android/app/src/main/AndroidManifest.xml` → **0**.
  `speech_to_text` needs `<intent><action android:name="android.speech.RecognitionService"/></intent>`
  for package visibility on API 30+. Without it `initialize()` returns false
  (`lib/services/voice_service.dart:45-61`) and `listen()` early-returns at `:69` — **no error, no
  toast, no log**. The intended primary interface would be a dead microphone button on modern
  Android. This is the *same missing manifest block* as round 1's H11 `tel:`/`mailto:` finding: one
  fix, three broken surfaces.
- **It adds a data type.** Audio is transcribed on-device, but the resulting transcript leaves the
  device to a third-party LLM. §6.4 (privacy labels/policy) was already ❌; promoting voice to the
  primary interface turns that from a policy gap into a submission defect, and the app carries no
  "AI-generated, may be inaccurate" disclosure and no in-app opt-out — the switch is a build-time
  `--dart-define` (`constants.dart:10-11`).
- **Voice removes the reading step that the sample-data notice depends on.** A user driving the app
  by voice hears answers; the visual pill (§B) is not in that loop. The pill's
  `SemanticsService.sendAnnouncement` (`demo_data_banner.dart:74-84`) fires for screen-reader users,
  not for TTS assistant replies. So a voice user asking "aaj insulin mila?" can be read a sample
  answer with no spoken caveat — and with §A.2 the visual caveat is meaningless anyway.

**Minimum to make the assistant operable as a primary interface** (ordered, none large):
1. Convert to `onCall` or verify a Firebase ID token; enable App Check. Requires the auth gate (§E).
2. Derive `role` and `patient_id` server-side from the verified token; delete the client-supplied
   `role` fail-open default.
3. Set `maxInstances`, add a per-uid rate limit, pin a non-Opus default model, and record the
   console budget alert in `KNOWN_ISSUES.md` with a date.
4. Log every turn server-side: request id, uid/patient id, role, action chosen, params, confirmed
   yes/no. Retain per the privacy policy. This is the audit trail.
5. Add the `RecognitionService` `<queries>` entry and surface an explicit error when
   `initSpeech()` returns false.
6. Add the AI disclosure + an in-app toggle, and update the privacy policy for the transcript.
7. Add `.timeout(...)` to the client POST.

---

## Blockers (must fix before release)

1. **The sample-data notice is stuck ON for every user on a healthy backend** —
   `app_provider.dart:142` marks `sourcePatientIdentity` unconditionally on every cold start and
   nothing clears it (`markServingLiveData` has one call site, `app_provider.dart:273`). A permanent
   warning is not a warning. **Regression in operational value vs round 2.** §A.2
2. **Four clinical/identity surfaces still serve `DemoData` with no mark** —
   `patient_profile_screen.dart:898` (allergies/conditions under a "synced" subtitle),
   `care_event.dart:57,71,97,105-106,118` (the whole Care Calendar),
   `doctor_advice_card.dart:46` (clinical advice), `care_team_screen.dart:29,31,162-164`,
   `care_calendar_screen.dart:1324`. Their three source constants exist and are never used
   (`demo_mode.dart:31,32,33`). §A.1
3. **Support numbers are still placeholders** — `help_faq_screen.dart:352,365`,
   `staff_otp_verification_screen.dart:352`. Unchanged for three rounds.
4. **Android release is debug-signed** — `android/app/build.gradle.kts:32-38`; no `key.properties`.
   No Play track, therefore no phased release and no "halt the rollout" lever. Unchanged.
5. **Auth is disabled** — `main.dart:417-419`, `splash_screen.dart:14-18`. Unchanged, and it now
   blocks the fix for the deletion queue (§C) and for assistant auth (§F.1).
6. **iOS crash reports will be unsymbolicated** — `grep -c upload-symbols` → 0, on an iOS-first app.
   Unchanged.
7. **The 30-day deletion promise still has no receiver, no owner and no meter** — the record is
   durable but has zero readers; `deliveredToServer:false` has no writer of `true`; the local record
   dies on uninstall, the action most likely to follow. §C
8. **If `ASSISTANT_API_URL` is set, an unauthenticated, unrate-limited, uncapped LLM endpoint goes
   live in one build flag** — `functions/index.js:112-119` with client-asserted, fail-open role at
   `:142-149`, no `maxInstances`, Opus by default (`:26`), and no success-path logging. §F

## High

9. **`logger.dart:63` still unwired — now the highest-value line in the audit.** `StoreMigrator`
   degrades silently *by design* after `5fa6d95`, so this line is the only difference between a
   healthy migration and a failed one; the deletion flow's two failure paths land here too; and a
   platform-channel throw that previously reached Crashlytics now reaches nothing. §D.2
10. **`StoreMigrator` can still hang a cold start** — no `.timeout()` on
    `SharedPreferences.getInstance()` (`store_migrator.dart:70`), pre-`runApp()`
    (`main.dart:174`). A hang produces no crash report at all. §D.3
11. **The notice overlay absorbs taps and occludes the first row** — no `IgnorePointer`
    (`demo_data_banner.dart:39-50`), positioned at `padding.top + kToolbarHeight + 4` (`:45`), which
    is exactly where non-`extendBodyBehindAppBar` screens start (`settings_screen.dart:87-93`).
    Compounded by blocker 1 into an always-present dead zone. §B.1/B.2
12. **Voice will silently fail on Android 11+** — no `RecognitionService` `<queries>` entry
    (`AndroidManifest.xml:39-48`); `voice_service.dart:69` returns with no error. Same missing block
    as the `tel:`/`mailto:` failure. §F.6
13. **No assistant audit trail** — one `console.error` on the failure path only
    (`functions/index.js:192`); zero `Log.` calls in the entire assistant subsystem. §F.5
14. **`storage.rules` / `firestore.rules` / API-key restrictions still undeployed and untracked** —
    `.firebaserc` empty; `KNOWN_ISSUES.md:25,26` unchanged. Live posture unknown.
15. **No analytics · no flag / kill switch / force-upgrade · no background-isolate capture** —
    all three unchanged.
16. **Android `<queries>` missing for `tel:`/`mailto:`/`https:`** — the whole non-SOS support surface
    fails `canLaunchUrl` on API 30+.
17. **Still no user-symptom diagnostic playbooks** — and the one diagnostic question the app
    offered ("do you see the sample-data pill?") is now useless because the answer is always yes.
18. **New operational code still under-tested** — `StoreMigrator` is now well covered (9 tests), but
    there is still **no test that the notice renders** (`grep -rln demo_data_banner test/` → none;
    `main_shell_test.dart` was rewritten this round without it), no test that any source clears, and
    no test for `DeleteAccountScreen`.

## Medium / Low

19. `docs/KNOWN_ISSUES.md:5` still "Last updated: 2026-05-28" — untouched by all five commits since
    round 1, including `0f2729e` which updated six other docs. BUG-14 (`:53`) still false; BUG-07
    (`:39`) still contradicts a green 1,813-test suite. (Medium)
20. `docs/KNOWN_ISSUES.md:26` still names package `in.housepital.patient`; real id is
    `com.housepital.housepital_patient` (`build.gradle.kts:24`). (Medium)
21. No `PrivacyInfo.xcprivacy` in `ios/`; privacy policy is a remote URL only, and now owes both the
    30-day deletion commitment **and** the voice/LLM transcript. (Medium — submission requirement)
22. Version string hardcoded with no build number; `package_info_plus` absent; the store schema
    version (`StoreMigrator.currentVersion`) and the pending-deletion reference are likewise
    invisible to support. (Medium)
23. Halt criteria, expedited-review criteria, incident severity ladder, `concernSla` — all still
    inert. (Medium)
24. No in-app "What's new"; `docs/CHANGELOG.md` never reaches a user. (Medium)
25. Three declared-but-unused `DemoMode` source constants (`demo_mode.dart:31,32,33`) read as
    coverage and are not; `flutter analyze` cannot see them. (Low, but it is the tell for blocker 2)
26. Support phone still has three literals (`constants.dart:19`, `delete_account_screen.dart` ×2).
    (Low)
27. `AssistantProvider` is constructed entirely from `DemoData` with a hardcoded
    `UserRole.primaryContact` (`main.dart:234-237,260`) and marks no `DemoMode` source — the identity
    every assistant action executes against. (Medium, rising to High the day voice ships)
28. `android/app/src/main/AndroidManifest.xml:7` app label still `housepital_patient`. (Low)
29. `functions/README.md` cost guidance ("set a budget limit in the console") is an untracked manual
    prerequisite, like BUG-33/34. (Low)

## BLOCKED-OWNER

| Item | What is needed |
|---|---|
| Storage / Firestore rules live posture | `firebase use --add housepital-patient`, then `firebase deploy --only storage,firestore:rules`; paste the CLI output + console "Last published" timestamp into `KNOWN_ISSUES.md`, plus a cross-account 403 test |
| API-key restrictions (BUG-34) | Console action against the **correct** package id, then verification output |
| **Deletion-request owner and 30-day clock (§C)** | Who receives a request, where the queue lives, who is accountable on day 30, and what they do with a row |
| **Anthropic spend cap + alert (§F.3)** | Console budget limit on the API key and a Cloud Functions budget alert, with the values and date recorded in `KNOWN_ISSUES.md` before `ASSISTANT_API_URL` is ever set |
| **Assistant data-retention decision (§F.5)** | How long turn logs are kept, who may read them, and what the privacy policy will say — needed before logging is added, not after |
| Phased release ON | Play staged rollout + App Store Connect phased release — after signing is fixed |
| Store release-notes text | Owner-written user-facing notes for v1.0.0 |
| Crashlytics alerts + a daily reader | Console config per `DEPLOYMENT_GUIDE.md §7a.5`, plus a named person for week 1 |
| Store review / beta triage | Named owner, weekly slot, four-way rubric |
| First-48h smoke pass | Owner to run a to-be-written `docs/SMOKE_PASS.md` on a real device from the store build |
| Support channel monitored, window published | Confirm `wecare@housepital.in` is monitored; confirm `9990911911` staffing hours |
| Privacy policy vs shipped data set | Must now cover vitals, medication names, photos, **voice transcripts sent to a third-party LLM**, phone, address, **and the 30-day deletion commitment** |
| Notched-device check of the notice overlay | Confirm the pill's occlusion footprint on Settings and on any screen without `extendBodyBehindAppBar` |
| Expedited-review criteria | Owner sign-off on what qualifies |

---

## Executive summary

1. **Round-3 counts: 1 ✅ · 12 ⚠️ · 13 ❌ · 2 N/A of 28.** Round 2 was 1/13/12/2, round 1 was
   1/11/14/2. Three rounds, still one pass.
2. **Genuinely fixed:** the notice now renders on every pushed route (`main.dart:433-434`) — round 2's
   blocker 1, closed properly and above the Navigator; `StoreMigrator.run()` is fully throw-safe,
   stops rather than advancing on a failed step, always stamps, and now has 9 real tests; three of
   seven silent demo sources (handover PDF, patient identity, articles) now mark; the deletion
   request is a durable local record that survives logout.
3. **REGRESSED:** the sample-data notice as a monitoring signal. `markServingLiveData` has exactly
   one call site (`app_provider.dart:273`); `sourcePatientIdentity` is marked unconditionally on
   every cold start (`:142`) and never cleared. On a perfectly healthy backend the warning is on
   from the first frame, forever. Round 2 predicted "cries wolf"; the set rewrite made it certain.
   §2.3 drops ⚠️ → ❌.
4. **Is any round-2 repair itself a surface?** Not in round 2's sense — none of these is fake. But
   three of five are **half-wires**: the set has one clear, the deletion record has zero readers, and
   the eleven source constants include three that are never referenced. The *data structures* were
   built from the audit's own recommended wording; the *behaviour* those structures exist to enable
   was not written. That is harder to catch than a `Future.delayed`, because the file under review
   reads as correct in isolation.
5. **Second-order finding on `StoreMigrator`:** making it throw-safe moved a platform-channel failure
   from a Crashlytics fatal to a swallowed log line on a dead logger. The user experience improved
   and the observability went to zero. Silent-continue is right only if the continue is reported.
6. **The bigger half of the migrator risk is untouched:** still no timeout at
   `store_migrator.dart:70`, pre-`runApp()`. A hang yields no crash report at all, so `logger.dart`
   alone will not cover it.
7. **Nothing on the untouched list moved.** Debug keystore, disabled auth gate and the missing dSYM
   phase are byte-identical across all three rounds; `docs/KNOWN_ISSUES.md` has not been edited since
   before round 1, while `0f2729e` updated six neighbouring docs.
8. **Voice-first assistant: not operable as a primary interface.** No auth (`onRequest`, `cors:true`),
   client-asserted role that fails open to `primary_contact`, `patient_id` documented and never read,
   no rate limit, no `maxInstances`, Opus by default, every error returning 200 — and one
   `console.error` on the failure path as the entire record of what was done in a patient's name.
   On Android the microphone would silently not work at all (missing `RecognitionService` `<queries>`).
   All of it is one `--dart-define` from being live simultaneously.
9. **Top 5 remaining:** (1) the always-on sample-data notice + four unmarked clinical surfaces;
   (2) `logger.dart:63` — one line, now the difference between a silent migration failure and a
   visible one; (3) auth gate + debug keystore, which between them block the deletion queue, the
   assistant's auth, and every rollback lever; (4) unauthenticated uncapped assistant endpoint with
   no audit trail; (5) the deletion obligation's missing owner, queue and meter.
10. **Verdict: FAIL.** Not ready to operate. One blocker closed, one regressed, six carried
    unchanged from round 1. The app can now warn a patient on every screen and cannot stop warning
    them; it can record a deletion request nobody reads; and it is one build flag from putting an
    open LLM endpoint in front of patients with no record of what it did.
