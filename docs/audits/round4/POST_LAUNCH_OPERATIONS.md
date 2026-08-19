# Post-Launch Operations (App-Agnostic) — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 · **Auditor:** post-launch-ops · **Scope:** source review (see Limitations)
**Repo:** `/Users/ateeshayjain/WIPApps/Housepital/housepital_patient_app` · **Branch:** `fix/five-tab-nav`
**Prior:** round 3 `9a80fe2` · round 2 `820060b` · round 1 `803124d`

The app has **not launched**. Every control is graded as *readiness to operate on day 1*, not as
operational history. Where a control asks about a standing cadence, the absence of the cadence's
written definition is the finding — an unlaunched product can still have named owners and thresholds,
and this one has none.

---

## Applicability

**OPS applies in full.** The checklist's applicability clause is "every released product", and
MASTER-3.xx triggers here on four independent grounds:

1. **Regulated data.** The app stores and displays vitals, medication names and doses, allergies,
   and clinical daily reports. A silent failure is a clinical failure, not a cosmetic one.
2. **A real-world dispatch consequence.** Bookings send a nurse or caretaker to a physical address;
   SOS routes to an emergency number. Operations here move people, not pixels.
3. **Money moves.** Razorpay checkout, invoices, refunds.
4. **Standing legal obligations that outlive the release** — DPDP Act 2023 §12 erasure, CERT-In
   incident reporting. Both are *operational* duties with clocks, not build-time checkboxes.

Sections 7–9 (ownership/telemetry, incident & breach, continuity/retirement) are new in v2.0 and
have **never been audited on this repo**. Rounds 1–3 used the 28-control form; this round grades 43.
The scorecards are therefore not directly comparable and I say so in the Scorecard section rather
than implying a trend that the numbering change manufactured.

---

## Prior-round status

Round 3's findings, re-verified against `9127713`. Nothing below is carried on trust.

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B1** Clinical demo data silently substituted | **Improved, still open** | One new source wired (`sourceVitals`) and one new clear added. 12 sources declared, 9 mark, **2 clear**. See §A |
| **B2** Placeholder support numbers | **Pass — genuinely closed** | `help_faq_screen.dart:353-357,370` and `staff_otp_verification_screen.dart:353-354` now use `AppConstants.supportPhone`; both sites carry a comment naming the placeholder they replaced. `grep -rn "9999999999\|8888888888" lib/` → **0** |
| **B3** Android release signed with DEBUG keystore | **Still open, byte-identical** | `android/app/build.gradle.kts:34-37` `signingConfig = signingConfigs.getByName("debug")`; `ls android/key.properties` → *No such file or directory* |
| **B5** Auth gate disabled | **Still open, byte-identical** | `lib/main.dart:417-419` `// NOTE: Auth gate disabled for demo mode.` → `home: const SplashScreen()` |
| **B6** No iOS dSYM upload phase | **Still open** | `grep -c "upload-symbols" ios/Runner.xcodeproj/project.pbxproj` → **0**; `grep -c "Crashlytics" …` → **0** |
| **H8** Zero analytics | **Still open** | `grep -rn "firebase_analytics\|logEvent" lib/ pubspec.yaml functions/` → **0** |
| **H9** No flag / kill switch / force-upgrade | **Still open** | `grep -rniE "remote_config\|killSwitch\|forceUpgrade\|maintenanceMode" lib/ functions/ pubspec.yaml` → **0** |
| **H10** Non-fatals never reported (`logger.dart:63`) | **Still open, verbatim; count reconciled UPWARD** | `lib/utils/logger.dart:63` unchanged. **57**, not ~45 — see §E |
| **H12** Background-isolate errors uncaptured | **Still open** | `grep -rn "addErrorListener" lib/` → **0** |
| **H13** No account/data deletion path that lands | **Still open, and worse than round 3 knew** | Record still has zero readers; **plus** no re-auth path. See §D |
| **H14** Server-side prerequisites unverified | **Still open** | `.firebaserc` still `{"projects":{},"targets":{},"etags":{}}`; BUG-33/BUG-34 still Open |
| **H15** No user-symptom playbooks | **Still open** | `ls docs/` — no playbook, runbook, smoke-pass or support document. `TROUBLESHOOTING.md` is developer-facing (`:1-25`, "Flutter Build Failures") |
| **M16** Hardcoded version, no build number | **Partially improved** | `pubspec.yaml:4` is now `1.0.0+1` (a build number exists in the artifact). But the app still *displays* a hardcoded literal — `about_screen.dart:11` `_appVersion = '1.0.0'`, `settings_screen.dart:258` `'Housepital v1.0.0'`. `package_info_plus` still absent. A user cannot read the build number aloud |
| **M17** No in-app "What's new" | **Still open** | no matches in `lib/`, `assets/i18n/` |
| **M18** `KNOWN_ISSUES.md` stale | **Pass — genuinely closed** | Updated in `9127713` (`git log -- docs/KNOWN_ISSUES.md`). Now dated `:5` 2026-08-03 and carries an honest "Open — from the eleven-checklist audits" block at `:7-58` naming its own blockers. This was ten weeks and five commits stale in round 3 |
| **M19** Wrong package id in deploy docs | **Still open** | `docs/KNOWN_ISSUES.md:68` and `docs/DEPLOYMENT_GUIDE.md:345,346` still say `in.housepital.patient`; real id is `com.housepital.housepital_patient` (`build.gradle.kts:24`) |
| **M22** Severity ladder / SLA inert | **Still open** | `constants.dart:46` `concernSla` is a business-concern map, not an incident ladder; still unenforced |
| **§A.2** Notice stuck ON | **Still open** | `app_provider.dart:156` marks unconditionally; the success branch `:164-179` does not clear. See §A |
| **§B.2** No `IgnorePointer` on the overlay | **Still open — now CONFIRMED, not suspected** | See §B |
| **§D.1** `StoreMigrator` throw-safety | **Holds** | `store_migrator.dart:114-119` still guards the whole body; 9 tests in `test/services/store_migrator_test.dart` |
| **§D.2** Throw-safety traded a Crashlytics fatal for a silent swallow | **Still open** | `store_migrator.dart:117` logs to `Log.error`, which terminates at `debugPrint` (`logger.dart:59`) |
| **§D.3** No `.timeout()` on the pre-`runApp()` migrator | **Still open** | `store_migrator.dart:123` `await SharedPreferences.getInstance()` has no timeout; called at `main.dart:175`, before `runApp` at `:192` |
| **§18** New operational code under-tested | **Still open** | `grep -rln "demo_data_banner\|DemoDataBanner" test/` → **0**; `grep -rln "session_scope" test/` → **0**; `grep -rln "DeleteAccount" test/` → **0**; `grep -rln "PaymentFailure" test/` → **0** |

**Net:** two round-3 findings genuinely closed (support numbers, `KNOWN_ISSUES.md` staleness). Nothing
regressed. Everything else on the carried list is open, and most of it is byte-identical across four
rounds.

---

## Round-4 focus findings

### §A — Every `DemoMode` source, re-enumerated

The brief asks directly: is `markServingLiveData` called from two places or still one?

**Two.** It was one in round 3. It is now two — `app_provider.dart:292` and `vitals_screen.dart:129`.
The source list simultaneously grew from eleven to twelve (`sourceVitals`, `demo_mode.dart:35`). So
the ratio moved from 1-clear-for-11 to **2-clear-for-12**.

Full enumeration, every source constant at `demo_mode.dart:24-35`:

| # | Source | Marked at | Cleared at | Wired? |
|---|---|---|---|---|
| 1 | `sourceDashboard` | `app_provider.dart:305` | `app_provider.dart:292` | **both** |
| 2 | `sourceVitals` | `vitals_screen.dart:81` | `vitals_screen.dart:129` | **both** (but inert — §A.1) |
| 3 | `sourcePatientIdentity` | `app_provider.dart:156` | — | mark only |
| 4 | `sourceMedications` | `medication_provider.dart:191,236` | — | mark only |
| 5 | `sourceMyCare` | `my_care_provider.dart:50,98` | — | mark only |
| 6 | `sourceBilling` | `billing_provider.dart:43` | — | mark only |
| 7 | `sourceOrders` | `orders_provider.dart:237` | — | mark only |
| 8 | `sourceArticles` | `blog_provider.dart:40,70` | — | mark only |
| 9 | `sourceHandover` | `handover_report_service.dart:105` | — | mark only |
| 10 | `sourceCareTeam` | — | — | **DEAD** |
| 11 | `sourceCareCalendar` | — | — | **DEAD** |
| 12 | `sourceProfile` | — | — | **DEAD** |

Verification: `for s in …; do grep -rn "$s" lib/ test/ | grep -v demo_mode.dart | wc -l; done` returns
**0** for `sourceCareTeam`, `sourceCareCalendar` and `sourceProfile`. These are the same three that
were dead in round 3, covering the same four silent clinical surfaces round 3 named
(`patient_profile_screen.dart:898`, `care_event.dart`, `doctor_advice_card.dart:46`,
`care_team_screen.dart`, `care_calendar_screen.dart:1324`). `CLAUDE.md`'s storage contract now says
verbatim *"Declare a `source*` constant and wire its call in the same edit — an unused constant is
invisible to the analyzer and makes the list read complete when it isn't."* The contract was written
this round and the three violations it describes were not fixed in the same round. The rule is
documented and unenforced; nothing in `scripts/check_design_consistency.sh` or the test suite fails
on a dead source constant.

#### A.1 · The new vitals clear cannot fire

This is the round's sharpest operational finding, and it is structural rather than probabilistic.

`DemoMode._sync()` (`demo_mode.dart:65-67`) assigns `isServingDemoData.value = _activeSources.isNotEmpty`.
`ValueNotifier`'s setter is a no-op when the value is unchanged. The overlay is driven solely by that
notifier (`demo_data_banner.dart:35-38`).

`sourcePatientIdentity` is marked on **every cold start** — `app_provider.dart:150-157`, inside the
`if (_patients.isEmpty)` pre-API seed, which is true on every cold start — and **nothing clears it**;
the success branch at `:164-179` reassigns `_patients` and `_currentPatient` and never calls
`markServingLiveData`. So `_activeSources` is non-empty from the first frame of every session and
stays non-empty.

Therefore `markServingLiveData(DemoMode.sourceVitals)` at `vitals_screen.dart:129` removes an element
from a set that still has at least one other element, `_sync()` re-assigns `true` over `true`, and
**the pill does not come down**. The fix is correct in isolation and produces no user-visible effect
in any shipped configuration. This is the same shape as round 3's half-wires, one level out: the wire
is complete and the socket it plugs into is held down by an unfixed neighbour.

**A second-order consequence, and the reason the ordering of the fixes matters.** The clear at `:129`
is executed from `_mergedVitals`, which is called from `build()` (`vitals_screen.dart:141`). Mutating
`DemoMode` there writes to a `ValueNotifier` whose only listener is `DemoDataBannerHost` — installed
from `MaterialApp.builder` (`main.dart:434`), i.e. an **ancestor that has already built in this
frame**. Today that write never notifies, for the reason above. The day blocker 1 is fixed and
`_activeSources` can reach empty, this becomes a live `markNeedsBuild` on an already-built ancestor
during a descendant's build — Flutter's documented assertion failure. I have not executed the app, so
I state this as a source-level structural risk rather than an observed crash; the mitigation is one
line (`WidgetsBinding.instance.addPostFrameCallback`) and it must land in the *same* edit as the
blocker-1 fix, not after it.

**A third defect in the same function.** `_generateMockData()` marks unconditionally, and it is called
from `initState` (`:45`) **and again on every period change** (`:215`, inside `setState`). A patient
who has real readings and taps "30d" re-raises `sourceVitals`, which the next build clears. The mark
is not conditioned on the patient having no real data — the condition lives only in the clear. And in
the genuine no-readings case the mark is never cleared at all and persists app-wide for the process
lifetime, exactly like `sourceHandover`: opening `/vitals` once pins the pill over every other screen
until force-quit.

**Assessment of the fix as shipped:** the *clinical* half is real and valuable — `_mergedVitals`
(`:125-136`) no longer merges `Random(42)` data with real readings, and the doc comment at `:51-61`
correctly diagnoses why that was dangerous. That is a genuine safety improvement. The *signalling*
half is inert.

**Test coverage:** `test/screens/reports/vitals_screen_test.dart` (200 lines) contains **zero**
references to `DemoMode` or demo state. `grep -rln "DemoMode" test/` returns exactly one file
(`patient_scope_isolation_test.dart`), unchanged from round 3. Every defect in §A is invisible to the
1,819-test suite.

### §B — `IgnorePointer`: confirmed, not suspected

**Not added.** `grep -rn "IgnorePointer" lib/` returns **zero matches in the entire `lib/` tree** —
not merely zero in `demo_data_banner.dart`. `DemoDataBannerHost.build` (`demo_data_banner.dart:39-51`)
is a bare `Stack` with a `Positioned` child and no hit-test modifier anywhere in the subtree; the
pill's `GlassSurface` → `Container` with a `BoxDecoration` (`:96-108`) is hit-testable by default.

The owner's direct measurement (overlapping boxes, tap at the intersection, zero taps through) is
consistent with the source and, per the brief, upgrades this from a structural inference to a
**confirmed** defect. I record it as confirmed on the owner's measurement plus the source, and note
that I did not re-run the measurement myself.

Compounded, the shipped behaviour is: a permanently visible (§A.1), tap-absorbing pill positioned at
`MediaQuery.padding.top + kToolbarHeight + 4` (`:45`) — precisely where a screen without
`extendBodyBehindAppBar` starts its body content. It is a permanent dead zone over the first control
of those screens. It is now recorded in `docs/KNOWN_ISSUES.md:29-31`, which is an improvement in
honesty over round 3 (where it was recorded nowhere), and it is still not fixed, not tested, and not
in the `CLAUDE.md` design contract's demo-notice clause.

**Operationally this is a support-load defect, not only a UX one.** The two cheapest first questions
in any future diagnostic playbook — "does the button respond?" and "do you see the sample-data
pill?" — are both answered by this one widget, wrongly and identically for every user.

### §C — The notification-cancellation fix, assessed operationally

`SessionScope.clearPatientData` now calls `MedicationReminderService().cancelAllReminders()`
(`session_scope.dart:99-104`), guarded by `try`/`catch`. The comment at `:96-98` is exactly right
about why this matters: OS-scheduled notifications outlive the app, so patient A's drug name and dose
firing on the lock screen after the phone changes hands is the one PHI leak in this codebase that
escapes the app entirely.

**Is it complete? No — for two reasons, and the second one is invisible by construction.**

**C.1 · The call can silently do nothing.** `cancelAllReminders()` (`medication_reminder_service.dart:248-251`)
opens with `if (kIsWeb || !_initialized) return;`. `_initialized` is per-process state on a singleton
(`:22-28`), set only by `init()`, which is called from exactly one place: `main.dart:179`, inside
`if (!kIsWeb)`. If `init()` has not completed or has thrown, `cancelAllReminders()` **returns
normally without cancelling anything and without throwing**. The scheduled notifications — which by
definition were written by a *previous* process and survive on the OS — remain scheduled, and the
`catch` at `session_scope.dart:101` never runs, because there is no exception. The fix's guard
protects against the one failure mode that cannot occur silently and is blind to the one that can.

**C.2 · A real failure is invisible.** When `cancelAll()` *does* throw — a platform-channel error, a
plugin fault — the handler is `Log.warn(...)` (`session_scope.dart:102-103`). `Log.warn` terminates
at `debugPrint` (`logger.dart:59`) with the Crashlytics forward still an unwired TODO at `:63`. In a
release build `debugPrint` reaches nobody. So the operator-visible consequence of a failure to cancel
**PHI notifications on a shared phone** is: nothing, anywhere, ever. The user sees a successful
patient switch. The next dose reminder fires the previous patient's medication name onto the lock
screen. No signal is produced at any layer.

**C.3 · Untested.** `grep -rln "session_scope" test/` → **0 files**. Round 3 recorded "SessionScope
imported by zero tests" as a known-open item; it is unchanged. `patient_scope_isolation_test.dart:12`
mentions `SessionScope` in a *comment* instructing future authors to update it, and does not import
it. The one PHI-leak-beyond-the-app path in the product is asserted by nothing.

**Verdict: incomplete.** The wiring is correct and the reasoning is correct; the guard is aimed at the
wrong failure, and the failure it does catch is reported to a dead sink.

### §D — The deletion obligation, restated as an operational commitment

**Unchanged from round 3, and materially worse than round 3 knew.** I verified the parallel module's
finding independently:

```
$ grep -rn "reauthenticate\|requires-recent-login\|requiresRecentLogin" lib/ test/
(no matches — 0)
```

`delete_account_screen.dart:128-138` calls `FirebaseService().currentUser.delete()` inside a
`try`/`catch`. Firebase rejects `delete()` with `auth/requires-recent-login` for any session older
than roughly five minutes. With **no re-authentication path anywhere in the codebase**, the realistic
sequence for a user who opens Settings some minutes into a session is:

1. the local record is written (`:104`);
2. `user.delete()` throws; the `catch` at `:134-138` logs `Log.warn` — to the dead logger — and sets
   nothing but a local `credentialDeleted = false`;
3. all local data is wiped (`:143` `SessionScope.clearSession`) and the user is signed out (`:145`);
4. a dialog shows `delete_account_done_login_pending` (`:156`) and a reference number.

**The phone is wiped. The account is not.** Signing in again with the same number returns the user to
the account. The screen's copy does not lie about this — it separates DONE from REQUESTED, which is
the honest design round 3 credited — but the *commitment* it makes is now demonstrably one the app
usually cannot keep on its own.

As an operational commitment, every element is still missing:

- **Receiver: none.** `grep -rn "pending_deletion\|pendingDeletionKey" lib/ test/ docs/ functions/`
  returns three code hits — the constant (`delete_account_screen.dart:60`), the single write (`:84`),
  and the logout preserve-list entry (`auth_provider.dart:233`). **Zero readers, in this repo or in
  either backend.**
- **Owner: none.** No name, rota, queue or mailbox in `docs/`. The commitment is made by the app and
  accepted by nobody.
- **Meter: none.** The 30-day clock starts on the patient's handset. Nothing counts requests, ages
  them, or alarms at day 25. There is no analytics SDK (H8) and `logger.dart:63` would drop the event
  if there were.
- **`deliveredToServer: false` still has no writer of `true`** (`:89`). It documents an intention and
  will read to whoever inherits the file as a working outbox.
- **Durability is bounded by the most likely next action.** `SharedPreferences` is app-scoped and
  destroyed on uninstall — the single most likely thing a user does after deleting their account.
- **Attribution is fake.** With the auth gate off (`main.dart:417-419`), the `patientId` written at
  `:88` is `DemoData.patient.id` for every user (`app_provider.dart:151`). One shared fake id across
  all requesters; a future replay could not tell two patients apart.
- **Zero tests.** `grep -rln "DeleteAccount" test/` → 0.

**This is an operational commitment with no owner, no receiver, no meter, no attribution, and a
mechanism that usually fails.** It is DPDP §12 and App Store 5.1.1(v) exposure that no amount of
client-side work closes, because the missing pieces are a person and a queue.

### §D-bis — NEW: the payment fix creates a *second* unowned SLA

The typed `PaymentFailure` (`payment_service.dart:246-256`) is good engineering and the doc comment
at `:237-245` is exactly right about why string-matching a localisable message was a double-debit
hazard. As a **code** fix it is the strongest of the four.

But trace `PaymentFailure.unverified` operationally. It is raised at `payment_service.dart:180-183`
and `:187-190` with the message *"Payment under verification — we'll confirm in 24 hours"*, in the
state the enum itself documents as *"Checkout reported SUCCESS but we could not verify it. Money has
probably left the patient's account."* (`:253-254`).

What happens next:

- `payment_screen.dart:281-299` sets `_pendingVerification = true` and re-renders. **That is all.**
- Nothing is persisted. Nothing is queued. Nothing is sent.
- The only trace is `Log.error` at `payment_service.dart:175-179` and `Log.warn` at `:216` — the dead
  logger again.

So the app tells a patient whose money has probably left their account that **someone will confirm
within 24 hours**, and there is no record on the device, no record on a server, no queue, no owner,
and no alarm. It is structurally the identical defect to the 30-day deletion promise, created fresh
in the same commit that was fixing the previous one — a durable-sounding commitment with no receiver.
This one has money attached and a 24-hour clock instead of a 30-day one.

Note the mitigating fact, stated so this is not inflated: with placeholder Razorpay keys the app runs
simulated checkout by design, so `isDemoPayments` is true and the `skippedDemo` branch calls success
(`:172-173`). The `unverified` path is reachable **only** with a real key — i.e. only in the exact
configuration in which real money moves.

### §E — `logger.dart:63`: the count, reconciled

Round 3 and `docs/KNOWN_ISSUES.md:41` both say "~45". A parallel module counts 57. **57 is correct**
for `lib/`, and here is the derivation:

```
$ grep -rn "Log\.warn"  lib --include="*.dart" | grep -v lib/utils/logger.dart | wc -l   → 52
$ grep -rn "Log\.error" lib --include="*.dart" | grep -v lib/utils/logger.dart | wc -l   →  5
                                                                                  total →  57
```

across 16 files. Adding `test/` gives 58; counting all four levels (`debug`/`info` included) gives 69,
but `debug` and `info` are deliberately dropped in release (`logger.dart:55-57`) and are not what the
TODO is about. So the correct figure for "warn/error sites that reach no remote sink in a release
build" is **57**.

The discrepancy matters beyond arithmetic: `docs/KNOWN_ISSUES.md` was **updated this round** (commit
`9127713`) and the number it was updated with is wrong by 27%. The documentation pass carried a stale
figure forward from the round-3 report rather than re-measuring. That is a small instance of the
pattern this round is otherwise about.

**Why this line still ranks first among non-blockers, now with two more dependents than round 3:**
`StoreMigrator` degrades silently by design (`store_migrator.dart:114-119`), so this line is the only
difference between a healthy and a failed migration; the deletion flow's two failure paths land here
(`delete_account_screen.dart:106,136`); **new this round**, the notification-cancellation failure path
lands here (`session_scope.dart:102`) and the payment-unverified path lands here
(`payment_service.dart:175,216`). Four of this round's own repairs report their failures into a sink
that reaches nobody in a release build.

### §F — Operational readiness of this round's four fixes

| Fix | Code quality | Operationally ready? | The gap |
|---|---|---|---|
| **Per-patient order keys + `StoreMigrator` v2** | Strong. Frozen literals (`store_migrator.dart:65-73`), quarantine rather than overwrite, failed step does not advance the stamp (`:164-178`), always stamps (`:187`). 9 tests | **No** | §F.1 below |
| **Migration runs before `runApp`** | Correct placement (`main.dart:175`) and fully throw-safe | **No** | Failure is invisible (§E); still no `.timeout()` at `store_migrator.dart:123` — a hang is an indefinite splash with no crash report, which `logger.dart` alone will not cover |
| **Notification cancellation** | Correct call, correct reasoning | **No** | §C — silent no-op path, dead-logger failure path, zero tests |
| **Typed `PaymentFailure`** | Strongest of the four as code | **No** | §D-bis — creates a 24-hour SLA with no receiver |

#### F.1 · `__quarantine_v1_*` — a support capability that support cannot invoke

`store_migrator.dart:20-22` and `:62-64` make an explicit, written promise: *"support can retrieve a
patient's order history"* from `__quarantine_v1_*`. Assessed as the brief asks — does support now need
to know about this?

Yes, and support cannot act on it:

1. **No support-facing document mentions it.** `grep -rn "__quarantine" docs/` returns hits only in
   `docs/audits/` — i.e. only in audit reports, none of which is a runbook. It is absent from
   `TROUBLESHOOTING.md`, `DEPLOYMENT_GUIDE.md` and `KNOWN_ISSUES.md`.
2. **Nobody is told a quarantine happened.** The only announcement is `Log.warn` at `:220`, which
   terminates at `debugPrint`. Support learns a patient's history was quarantined only if the patient
   notices their orders are gone and calls.
3. **No reader exists.** `grep -rn "__quarantine" lib/` returns only the definition, the doc comments
   and the write. No screen, no export, no diagnostic surface reads those keys.
4. **No mechanism reaches a key on a patient's phone.** There is no remote-config, no diagnostic
   export, no support tooling. A support agent told "retrieve it from `__quarantine_v1_*`" has no
   action available.
5. **Some are destroyed before support could use them.** `auth_provider.dart:231-238` preserves
   exactly two keys on logout; `__quarantine_v*` is not one, so a logout — including the automatic
   one inside the account-deletion flow — destroys the recovery copy.

A documented recovery guarantee that cannot be invoked is worse than none, because it will be quoted
to a patient. **Fix: one paragraph in a support runbook that does not yet exist, plus a diagnostic
screen that lists quarantine keys — or, cheaper and more honest, delete the promise from the doc
comment until the mechanism exists.**

### §G — The pattern this round

Round 1 → 2 found **surfaces** (a banner instead of a gate; `Future.delayed` instead of a request).
Round 2 → 3 found **half-wires** (correct data structures, the behaviour they enable left unwritten).

Round 4's work is **neither**. Every one of the four fixes is a complete, correct mechanism with the
behaviour written. Three of the four were the strongest engineering in any round so far. The pattern
is one level further out, and I would name it **correct wires into dead sockets**:

| Fix | The wire | The socket it terminates in |
|---|---|---|
| `sourceVitals` clear | complete and correct | a `ValueNotifier` pinned `true` by an unfixed neighbour (§A.1) |
| `cancelAllReminders` | complete and correct | a guard aimed at the wrong failure, reporting to a dead logger (§C) |
| `StoreMigrator` v2 + quarantine | complete, correct, tested | a support promise no support process exists to honour (§F.1) |
| Typed `PaymentFailure` | complete, correct, best of the four | a 24-hour commitment with no receiver (§D-bis) |

This is harder to catch than a half-wire, because each file now reads correctly *and its immediate
caller reads correctly too*. The defect only appears when you follow the value one hop further — to
the notifier that never flips, the logger that never forwards, the queue that does not exist, the
runbook that was never written. Every one of those four terminals is a **known, four-round-old,
unfixed item** (`logger.dart:63`, `app_provider.dart:156`, no playbooks, no owners). The team is
building good mechanisms onto an operational substrate that has not been built at all, and the
substrate is cheaper than any of the mechanisms already shipped.

**The honest one-line summary of round 4: the code got better and the operation did not change.**

---

## Control results

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **OPS-1.01** Phased release ON unless written reason | **Fail** | Android release is debug-signed (`build.gradle.kts:34-37`; no `key.properties`), so no Play track exists and staged rollout is unavailable. iOS phased release is an App Store Connect toggle — no evidence in repo | No rollout to slow if week-one data is bad. **Mitigation:** create a release keystore; enable phased release on both stores. **OWNER-TBD. Due: before submission** |
| **OPS-1.02** Halt criteria decided IN ADVANCE | **Fail** | Nothing in `docs/` defines a crash rate, report count or data-loss signal that pauses a rollout. `DEPLOYMENT_GUIDE.md:429-433` names a Crashlytics *alert* threshold (>0.1% fatal in 1h) — an alert is not a halt criterion, and it is an unexecuted console step | Nobody knows in advance what stops the release. **OWNER-TBD** |
| **OPS-1.03** Rollback story named for THIS release | **Fail** | `DEPLOYMENT_GUIDE.md:488-491` names three levers. Android "halt rollout" is unavailable (1.01); iOS correctly states no rollback exists; there is **no feature flag or kill switch** (`grep -rniE "remote_config\|killSwitch\|forceUpgrade\|maintenanceMode"` → 0). The only remaining lever is "ship a hotfix", and no hotfix surface is named | The migrator hang (`store_migrator.dart:123`, pre-`runApp`) is precisely the failure with no remedy short of a store update. **OWNER-TBD** |
| **OPS-1.04** Server-side prerequisites verified done, not remembered | **Fail** | `.firebaserc` = `{"projects":{},"targets":{},"etags":{}}`; `storage.rules` undeployed (`KNOWN_ISSUES.md:17`); BUG-33 and BUG-34 both Open pending console action (`:67,68`). The repo cannot distinguish "not deployed" from "deployed and drifted" | Chat and concern-photo paths unprotected until deployed. **OWNER-TBD. Due: before release** |
| **OPS-1.05** Release notes honest, user-visible changes named | **Fail** | No store metadata anywhere: `find . -iname "*fastlane*" -o -iname "*release_notes*"` → nothing but `.metadata`. `docs/CHANGELOG.md` is 51 KB of engineering history and never reaches a user | **OWNER-TBD** |
| **OPS-1.06** Previous release archive retained and installable | **N/A** | **Rationale:** this is the first release; `pubspec.yaml:4` `version: 1.0.0+1`, and no prior build has ever been distributed. There is no previous archive that could be retained. The control cannot apply to a v1 | Becomes live at v1.0.1 — record the retention location now |
| **OPS-2.01** Crash reports checked DAILY first week, threshold written | **Fail** | Crashlytics *is* wired (`main.dart:117-126`, release-only) — real. But `grep -c "upload-symbols" ios/Runner.xcodeproj/project.pbxproj` → **0** on an iOS-first app, so every iOS report arrives unsymbolicated; no named daily reader; the threshold lives in an unexecuted console step | The signal is collected and unreadable, and nobody is assigned to read it. **OWNER-TBD** |
| **OPS-2.02** Store reviews / beta feedback read on a schedule, triaged four ways | **Fail** | No rubric, cadence or owner in `docs/` | **OWNER-TBD** |
| **OPS-2.03** User-visible failure surfaces treated as monitoring | **Fail** | The one such surface — the sample-data pill — is stuck ON for every user on a healthy backend (§A.1) and absorbs taps (§B). A warning that is always lit carries zero information | Round 3 downgraded this ⚠️→❌; it stays Fail. Week-one "did you see it?" is unanswerable. **Mitigation:** §A.1 fix list |
| **OPS-2.04** First-48h smoke pass on a production install | **Fail** | No `docs/SMOKE_PASS.md` or equivalent; `ls docs/` shows no smoke, playbook or runbook file | **OWNER-TBD. Due: release day** |
| **OPS-3.01** Severity ladder written down (S1–S4) | **Fail** | `constants.dart:46` `concernSla` is a per-concern-type business map, not an incident ladder; `KNOWN_ISSUES.md` TD-11 records it is neither enforced nor alerted. No S1–S4 definition anywhere | Every incident will be triaged from scratch under pressure. **OWNER-TBD** |
| **OPS-3.02** Each severity has a target response | **Fail** | Nothing defines acknowledge / workaround-comms / fix targets | **OWNER-TBD** |
| **OPS-3.03** Known-issue communication path exists | **Fail** | None of the three named forms exists: no review-reply template, no TestFlight notes, no support reply template. `KNOWN_ISSUES.md` is internal | Silence is the documented failure mode. Partial mitigation: the support phone is now real (4.01). **OWNER-TBD** |
| **OPS-3.04** Expedited-review criteria known in advance | **Fail** | No mention in any doc | **OWNER-TBD** |
| **OPS-3.05** Post-incident cause becomes a checklist line or a test | **Warning** | The practice is **demonstrably real for audit findings**: `test/services/store_migrator_test.dart` (9 tests) and `test/providers/orders_persistence_test.dart` were written directly from round-3 findings, and `CLAUDE.md`'s storage/session contracts encode the causes as rules. But it is applied inconsistently — this round's notification-cancellation, delete-account, `PaymentFailure` and demo-banner fixes have **zero** tests each — and no written policy requires it | Impact: causes convert to tests only when the author remembers. **Mitigation:** make "a test or a `CLAUDE.md` line per fix" a PR checklist item. **OWNER-TBD. Due: before release** |
| **OPS-4.01** Support channel real, monitored, answered within a stated window | **Warning** | **Improved this round.** Placeholders are gone: `help_faq_screen.dart:353-357,370` and `staff_otp_verification_screen.dart:353-354` now use `AppConstants.supportPhone` (`constants.dart:19` = `9990911911`); `grep -rn "9999999999\|8888888888" lib/` → 0. Remaining gap: no published response window, and monitoring is unverifiable from source | Round-3 blocker 3 is closed. **Mitigation:** publish hours and a response window in the store listing and in-app; confirm `wecare@housepital.in` is monitored. **OWNER-TBD** |
| **OPS-4.02** Diagnostic playbooks for the top three symptoms of THIS app | **Fail** | No playbook exists. `TROUBLESHOOTING.md:1-25` is developer-facing ("Flutter Build Failures", `flutter pub get` conflicts) and last updated 2026-03-24. The app's three most likely symptoms — "my medicine list is wrong", "it says sample data", "I paid and it didn't confirm" — have no documented question order | Every support call starts from zero. Compounded: the sample-data pill (§A.1) makes the most obvious diagnostic question useless. **OWNER-TBD. Due: before release** |
| **OPS-4.03** A user can produce diagnostics without engineering | **Fail** | Version is a hardcoded literal — `about_screen.dart:11` `_appVersion = '1.0.0'`, `settings_screen.dart:258` — with no build number; `package_info_plus` is absent from `pubspec.yaml`, so the displayed string cannot drift back into sync with `1.0.0+1`. There is **no** surface exposing `StoreMigrator.currentVersion`, the pending-deletion reference after the dialog closes, or the `__quarantine_v1_*` keys support is told to retrieve (§F.1). No data export | Support cannot establish which build a caller is on, nor whether their data was migrated or quarantined. **Mitigation:** add `package_info_plus` and a Settings diagnostics row showing version+build, schema version, and any quarantine keys. **OWNER-TBD** |
| **OPS-4.04** Destructive advice appears only with data consequences spelled out | **Warning** | The one destructive flow in the app is exemplary: `delete_account_screen.dart:24-43` documents the honesty standard, `:148-168` separates DONE from REQUESTED, and a typed confirm word gates it (`:70-76`). **But** there are no playbooks at all (4.02), so there is no document in which "reinstall" or "erase" advice could be governed — and a reinstall destroys the pending-deletion record (§D) and every `__quarantine_v*` key (§F.1), which nothing warns about | The standard exists in code and not in support material. **Mitigation:** when playbooks are written, carry `delete_account_screen.dart:24-30`'s standard into them verbatim. **OWNER-TBD** |
| **OPS-4.05** Household/multi-user playbooks cover the OTHER person's phone | **Fail** | This app is explicitly multi-user — `session_scope.dart:22-28` describes a patient watched by themselves, a primary contact and family members on shared handsets. No playbook covers the reporter-is-not-the-affected-device case. The one leak that crosses devices (OS-scheduled reminders, §C) can fail silently with no signal | The most likely confusing report ("Mum's phone shows the wrong medicines") has no documented path. **OWNER-TBD** |
| **OPS-5.01** Confirmed user bug becomes a regression test before the fix ships | **Warning** | Mixed and verifiable. **Yes:** per-patient order keys are covered (`orders_persistence_test.dart`, `patient_scope_isolation_test.dart:304-330`) and `StoreMigrator` has 9 tests. **No:** `grep -rln` returns **0 test files** for each of `session_scope`, `DeleteAccount`, `PaymentFailure`, and `demo_data_banner` — four of this round's own repairs | The habit exists but is not enforced, so it tracks author attention rather than risk. **Mitigation:** as 3.05. **OWNER-TBD** |
| **OPS-5.02** User words preserved in the tracker | **Fail** | There is no tracker — `docs/KNOWN_ISSUES.md` is a hand-maintained markdown table. One owner quote survives, in a source comment (`demo_data_banner.dart:21`, *"why is there so much space wasted here"*), which is good practice and is the only instance | Duplicate reports will not be findable. **OWNER-TBD** |
| **OPS-5.03** Visible changelog closes the loop | **Fail** | `docs/CHANGELOG.md` exists and is current (51 KB, updated `9127713`) but is developer-facing and never reaches a user; no in-app "What's new" (`grep` in `lib/`, `assets/i18n/` → 0); no store release notes (1.05) | A reporter cannot see their bug fixed. **OWNER-TBD** |
| **OPS-5.04** Requests triaged against the roadmap on a cadence | **Warning** | `docs/FEATURE_TRACKER.md` (32 KB) exists and is a real roadmap artifact. No cadence, no dated decisions, no "no" recorded against any request | A dated "no" beats an eternal "maybe"; today there are neither. **OWNER-TBD** |
| **OPS-6.01** Schema-deploy runbook is a living document, executable at midnight | **Warning** | Strong in parts: `DEPLOYMENT_GUIDE.md:327-448` gives console URLs, exact CLI commands and a verification step, and the storage-rules deploy was moved into the pre-launch block this round; the app-side stamp exists and is tested (`store_migrator.dart:34` `currentVersion = 2`; 9 tests). **The gap is precisely "environment names":** `.firebaserc` is empty, so the guide's own `firebase deploy --only storage` at `:394-397` fails from this tree without an explicit `--project`. Round 3 passed the *stamp* sub-item; at whole-control granularity this is a Warning, not a regression | A stressed human running the documented command at midnight gets an error. **Mitigation:** `firebase use --add`, commit `.firebaserc`. **OWNER-TBD. Due: before release** |
| **OPS-6.02** Export/backup verified WORKING in every release | **Fail** | There is no user data export. PDFs exist for invoices and the doctor handover (`invoice_pdf_service.dart`, `handover_report_service.dart`) but neither is an account export. All state is `SharedPreferences`, app-scoped, destroyed on uninstall, with no backup path — so the user's "last resort" does not exist to rot | On uninstall the patient loses manually entered vitals, orders, reminders and the deletion reference, irrecoverably. **OWNER-TBD** |
| **OPS-6.03** Account/data deletion paths re-verified each release, including server copies | **Fail** | §D. No re-auth path (`grep` → 0), so `user.delete()` usually throws and the Firebase account survives; signing in again restores it. The local record has zero readers; `deliveredToServer` has no writer of `true`; no server copy is ever contacted; zero tests | **Release-blocking.** DPDP §12 and App Store 5.1.1(v). **Mitigation, in order:** (1) `reauthenticateWithCredential` with a fresh OTP before `delete()`; (2) write the same JSON to a Firestore collection in the same `try`; (3) name an owner and a weekly queue slot. **OWNER-TBD. Due: before submission** |
| **OPS-6.04** Privacy labels and policy re-read when a release adds a data type | **Fail** | No app-level `ios/Runner/PrivacyInfo.xcprivacy` (only vendored Pod manifests under `ios/Pods/`), while the app uses `NSUserDefaults`, a required-reason API. The privacy policy is a remote URL and owes the 30-day deletion commitment. This release adds no new data type — it removes one (fabricated vitals) — so the drift is inherited, not created | App Review rejection risk. **OWNER-TBD. Due: before submission** |
| **OPS-7.01** Every critical promise has owner, health signal, observation method, escalation threshold | **Fail** | No owner is named anywhere in `docs/` for any promise. The app makes at least three explicit commitments with clocks — 30-day deletion (`delete_account_screen.dart`), 24-hour payment verification (`payment_service.dart:181,188`), `concernSla` (`constants.dart:46`) — and **none has an owner, a signal, or a threshold** | Three timed promises to patients, zero accountable parties. **OWNER-TBD. Due: before release** |
| **OPS-7.02** Alerts actionable, deduplicated, severity-routed, tested; each links to runbook + person | **Fail** | `DEPLOYMENT_GUIDE.md:427-440` *describes* alerts to configure (velocity >0.1%/1h, new-issue email+Slack, perf p95). None is configured — it is a console checklist item under `## 8. Post-Deployment Checklist` (`:449-462`) with every box unticked. No runbook exists to link to; no person is named | **OWNER-TBD** |
| **OPS-7.03** Synthetic monitoring exercises critical public journeys | **Fail** | None. `api.housepital.in` does not resolve and nothing probes it; no uptime check on the assistant Cloud Function; no journey probe for checkout or SOS. Not N/A — the app has critical public journeys (payment, SOS dispatch) | The team would learn the API is down from users. **OWNER-TBD** |
| **OPS-7.04** Release health compared against previous stable | **Fail** | No analytics (`grep -rn "firebase_analytics\|logEvent"` → 0), no previous stable, no dashboard comparing crash/latency/error/support/refund signals | Unmeasurable at v1; the *mechanism* is absent, which is what this control grades. **OWNER-TBD** |
| **OPS-7.05** Monitoring respects consent and privacy; logs avoid unnecessary personal data | **Fail** | `main.dart:123-124` calls `setCrashlyticsCollectionEnabled(true)` unconditionally in every non-debug build, with **no consent prompt and no opt-out** anywhere in the app. Under DPDP that is processing without notice or consent. The second half of the control passes by accident: `Log.warn`/`Log.error` messages that could carry PHI never leave the device only because `logger.dart:63` is unwired — so wiring that TODO (which this report ranks first among non-blockers) will simultaneously create a consent problem unless the messages are reviewed | **Wiring `logger.dart:63` must be paired with a PHI review of all 57 call sites and a consent decision.** **OWNER-TBD. Due: with the logger fix** |
| **OPS-8.01** Incident roles defined (commander, tech lead, comms, scribe, decision authority) | **Fail** | No role definition in any document, scaled or otherwise | **OWNER-TBD** |
| **OPS-8.02** Status and customer-communication path for outages, data-integrity failures, security incidents, vendor outages | **Fail** | No status page, no comms template, no vendor-outage plan. Vendor exposure is concrete: Razorpay, Firebase, and Anthropic (assistant) are all single points with no documented degradation path | **OWNER-TBD** |
| **OPS-8.03** Security/privacy incidents have containment, evidence preservation, credential rotation, legal assessment, notification playbooks | **Fail** | One-fifth exists: `DEPLOYMENT_GUIDE.md:441-447` documents Razorpay key rotation. No containment, evidence-preservation, legal-assessment or notification playbook. Evidence preservation is structurally hard here — `logger.dart:63` means there is nothing to preserve | **OWNER-TBD. Due: before release** |
| **OPS-8.04** Contractual and regulatory notification clocks, contacts, decision records known before an incident | **Fail** | Nothing in the repo names **CERT-In's 6-hour incident reporting direction** or **DPDP breach notification**, both of which bind an Indian entity processing health data. No Data Protection Officer, no grievance officer, no regulator contact | Highest-consequence gap in sections 7–9: a clock the team does not know exists starts at hour zero. **OWNER-TBD. Due: before release** |
| **OPS-8.05** Post-incident reviews blameless, time-bound, corrective actions tracked to verified completion | **Warning** | No incident process exists. **But** a genuine and unusually rigorous analogue is running: four audit rounds with per-finding status carried forward and independently re-verified (this document's Prior-round table), which is blameless, time-bound and tracked to verified completion. The machinery is real and is pointed at audits rather than incidents | **Mitigation:** reuse the audit round format as the post-incident review template — it is already better than most. **OWNER-TBD** |
| **OPS-9.01** Backup restore and failover drills on a schedule; RTO/RPO recorded | **Fail** | No user-data backup exists to restore (6.02). `DEPLOYMENT_GUIDE.md:483-486` mentions `mysqldump` before migrations — a backup instruction, not a drill, on a database this app does not reach. No RTO/RPO defined | **OWNER-TBD** |
| **OPS-9.02** Domains, certs, signing assets, store agreements, payment methods, vendors, quotas, service accounts have owners and expiry alerts | **Fail** | The Android **signing asset is a debug keystore** the team does not control the lifecycle of (`build.gradle.kts:34-37`); `api.housepital.in` does not resolve and has no recorded owner; `.firebaserc` names no project; the Anthropic spend cap is a manual console step recorded nowhere; no expiry alert for anything | A signing key with no owner is an app that cannot be updated. **OWNER-TBD. Due: before submission** |
| **OPS-9.03** Dependencies, OS changes, security advisories, store-policy changes reviewed on a defined patch cadence | **Fail** | `.github/workflows/ci.yml` is the only automation; no `dependabot.yml`, no `renovate.json`. `KNOWN_ISSUES.md` CI-02 pins Flutter 3.41.2 with a note to bump in lockstep — a good practice, but no cadence is defined and no advisory or store-policy review is scheduled | **OWNER-TBD** |
| **OPS-9.04** Feature flags and temporary mitigations expire; long-lived exceptions have owners and review dates | **Fail** | There is no flag system at all (1.03). The long-lived temporary mitigations are all in source with no owner and no review date: the commented-out auth gate (`main.dart:417-419`, "Enable before production release" — unchanged for four rounds), the debug-signing TODO (`build.gradle.kts:35-36`), `logger.dart:63`, and the assistant's build-time `--dart-define` switch (`constants.dart:10-11`), which is one flag from exposing an unauthenticated LLM endpoint | Four "temporary" states, none with an expiry. **OWNER-TBD** |
| **OPS-9.05** Sunset plan covers notice, export, retention/deletion, support, backend shutdown, delisting, security updates | **Fail** | No sunset plan. Materially: there is no export (6.02) and no working deletion (6.03), which are the two components a sunset most depends on | **OWNER-TBD** |

---

## Scorecard

**Pass 0 · Warning 7 · Fail 35 · N/A 1** (of 43) · **BLOCKED-OWNER 0 graded as such** — see note.

| Section | Pass | Warning | Fail | N/A |
|---|---|---|---|---|
| 1. Release mechanics | 0 | 0 | 5 | 1 |
| 2. Monitoring cadence | 0 | 0 | 4 | 0 |
| 3. Incident response | 0 | 1 | 4 | 0 |
| 4. Support readiness | 0 | 2 | 3 | 0 |
| 5. Feedback → roadmap | 0 | 2 | 2 | 0 |
| 6. Data stewardship | 0 | 1 | 3 | 0 |
| 7. Ownership, telemetry, alerting | 0 | 0 | 5 | 0 |
| 8. Incident and breach management | 0 | 1 | 4 | 0 |
| 9. Continuity, maintenance, retirement | 0 | 0 | 5 | 0 |
| **Total** | **0** | **7** | **35** | **1** |

**Comparability warning — read before trending these numbers.** Rounds 1–3 graded the 28-control form
(sections 1–6). This round grades 43 controls; sections 7–9 are new in v2.0 and have never been
audited here. On the **sections 1–6 subset**, round 4 is **0 Pass · 6 Warning · 21 Fail · 1 N/A**
against round 3's 1 ✅ / 12 ⚠️ / 13 ❌ / 2 N/A.

That subset movement is a **grading-rigour change, not a regression, and I state it plainly rather
than letting it read as decline**:

- Round 3's single ✅ was awarded to a *sub-item* (the app-side schema stamp, §6.1(c)). Under v2.0's
  control-level grading, OPS-6.01 is graded whole and the empty `.firebaserc` makes it a Warning. The
  stamp itself is unchanged and still good.
- Several round-3 ⚠️s were "the artifact exists but is inert". v2.0's Warning definition requires a
  recorded impact, mitigation and owner; where an inert artifact has no owner and no due date, v2.0
  puts it at Fail. I have applied that consistently.
- **No control's underlying evidence got worse this round.** Two got better (4.01, and M18 feeding
  5.03/6.01's documentation base).

**On BLOCKED-OWNER:** most Fails above are console-, person- or process-shaped and could arguably be
graded BLOCKED-OWNER. I have deliberately not done so, because the brief's rule is that a missing
owner is a *finding*, not an access limitation — I can verify from source that no owner is named
anywhere, and that verification is complete. BLOCKED-OWNER is reserved below for items where I would
need a console or a device to reach a verdict at all.

---

## Release blockers (every Fail, consolidated)

Thirty-five Fails, consolidated into the twelve distinct defects that produce them:

1. **The deletion obligation does not work and has no owner** (OPS-6.03). No re-auth path
   (`grep → 0`), so the Firebase account usually survives and signing in again restores it; the local
   record has zero readers; nothing reaches a server; zero tests. DPDP §12 / 5.1.1(v). §D
2. **The sample-data notice is stuck ON for every user on a healthy backend** (OPS-2.03). Nine sources
   mark, two clear, and `sourcePatientIdentity` (`app_provider.dart:156`) is marked unconditionally on
   every cold start and never cleared — which also makes this round's new vitals clear inert. §A
3. **The notice overlay absorbs taps** (OPS-2.03, 4.02). `grep -rn "IgnorePointer" lib/` → **0 in the
   entire tree**; confirmed by the owner's direct measurement. A permanent dead zone over the first
   content row of every non-`extendBodyBehindAppBar` screen. §B
4. **Three declared `DemoMode` sources are still dead** (OPS-2.03), leaving four clinical/identity
   surfaces serving `DemoData` unmarked — including allergies and conditions under a "synced"
   subtitle. `CLAUDE.md` now forbids exactly this and the violations predate the rule. §A
5. **Android release is debug-signed** (OPS-1.01, 1.03, 9.02). No Play track, therefore no phased
   release and no halt lever; the signing asset has no owner.
6. **Auth is disabled** (OPS-6.03, 7.05). `main.dart:417-419`. It makes deletion records
   unattributable (every request carries `DemoData.patient.id`) and blocks the Firestore receiver that
   would fix blocker 1.
7. **iOS crash reports will be unsymbolicated** (OPS-2.01). `grep -c "upload-symbols" …` → 0, on an
   iOS-first app. Four rounds unchanged.
8. **`logger.dart:63` is unwired — 57 warn/error sites reach no remote sink** (OPS-2.01, 7.02, 8.03).
   **Four of this round's own repairs report their failures into it**: the migrator, the deletion
   flow, the notification cancellation, and the payment-unverified path. §E
9. **The notification-cancellation fix has a silent no-op path** (OPS-4.05). `cancelAllReminders()`
   returns without cancelling when `!_initialized` and throws nothing, so the `try`/`catch` cannot see
   it; a genuine failure logs to the dead logger. Zero tests. §C
10. **The payment fix creates a second unowned SLA** (OPS-7.01). "We'll confirm in 24 hours" on a
    probably-charged payment, with nothing persisted, queued, sent or alarmed. §D-bis
11. **No operational substrate at all** (OPS-1.02, 1.05, 2.02, 2.04, 3.01–3.04, 4.02, 4.03, 4.05,
    5.02, 5.03, 7.01–7.04, 8.01–8.04, 9.01, 9.03–9.05). No named owner for any promise, no halt
    criteria, no severity ladder, no playbooks, no alerts configured, no synthetic monitoring, no
    incident roles, **no awareness of CERT-In's 6-hour clock or DPDP breach notification**, no sunset
    plan. This is the single largest cluster and the cheapest to close — it is writing, not code.
12. **Server-side prerequisites unverified** (OPS-1.04, 6.01). `.firebaserc` empty; `storage.rules`
    undeployed; BUG-33/BUG-34 open. The repo cannot tell "not deployed" from "deployed and drifted".

---

## Warnings requiring risk acceptance

| # | Control | Impact | Mitigation | Owner / due |
|---|---|---|---|---|
| W1 | OPS-4.01 | Support number is real but no response window is published and monitoring is unverified from source | Publish hours + window in store listing and in-app; confirm `wecare@housepital.in` is staffed | **OWNER-TBD** · before release |
| W2 | OPS-4.04 | The destructive-flow honesty standard exists in code and in no support material; reinstall silently destroys the deletion record and all quarantine keys | Carry `delete_account_screen.dart:24-30`'s standard into the playbooks when written; warn about reinstall consequences | **OWNER-TBD** · with 4.02 |
| W3 | OPS-3.05 / OPS-5.01 | Fix-to-test conversion tracks author attention, not risk; four of this round's repairs have zero tests | PR checklist line: every fix ships a test or a `CLAUDE.md` contract line | **OWNER-TBD** · before release |
| W4 | OPS-5.04 | Roadmap artifact exists; no triage cadence and no dated "no" | Monthly triage slot; record decisions with dates in `FEATURE_TRACKER.md` | **OWNER-TBD** · post-launch |
| W5 | OPS-6.01 | The documented deploy command fails from this tree because `.firebaserc` names no project | `firebase use --add housepital-patient`; commit `.firebaserc`; re-verify the guide's commands run verbatim | **OWNER-TBD** · before release |
| W6 | OPS-8.05 | No incident-review process; the audit-round machinery is a strong analogue pointed elsewhere | Adopt the audit round format as the post-incident template | **OWNER-TBD** · before release |
| W7 | §A.1 latent | Fixing blocker 2 makes `vitals_screen.dart:129` a live `markNeedsBuild` on an already-built ancestor during build | Wrap the clear in `addPostFrameCallback` **in the same edit** as the blocker-2 fix | **OWNER-TBD** · with blocker 2 |

**Accepted risks (owner decisions — recorded, not graded):** white on Housepital orange (2.33:1,
measured); manpower prices shown and directly bookable; the floating glass pill nav. None of these
affects an OPS control.

---

## BLOCKED-OWNER — needs access I do not have

| Item | What is needed |
|---|---|
| **Deletion-request owner, queue and 30-day clock** | Who receives a request, where the queue lives, who is accountable on day 30, what they do with a row. No repo artifact can answer this |
| **Payment-verification owner and 24-hour clock** (new this round) | Who confirms a `PaymentFailure.unverified` payment within 24 hours, and how they learn one occurred |
| Storage / Firestore rules live posture | `firebase use --add`, then `firebase deploy --only storage,firestore:rules`; paste CLI output + console "Last published" timestamp into `KNOWN_ISSUES.md`, plus a cross-account 403 test |
| API-key restrictions (BUG-34) | Console action against the **correct** package id (`com.housepital.housepital_patient`, not `in.housepital.patient`), then verification output |
| Crashlytics alerts + a named daily reader | Console config per `DEPLOYMENT_GUIDE.md §7a.5`, plus a named person for week 1 |
| Phased release ON | Play staged rollout + App Store Connect phased release — after signing is fixed |
| Store release-notes text | Owner-written user-facing notes for v1.0.0 |
| First-48h smoke pass | Owner to run a to-be-written `docs/SMOKE_PASS.md` on a real device from the store build |
| Support channel monitored, window published | Confirm `wecare@housepital.in` is monitored; confirm `9990911911` staffing hours |
| Expedited-review criteria | Owner sign-off on what qualifies |
| CERT-In / DPDP notification contacts | Regulator contacts, grievance officer, and the decision record for who declares a breach |
| Anthropic spend cap + alert | Console budget limit and Cloud Functions budget alert, values and date recorded in `KNOWN_ISSUES.md` **before** `ASSISTANT_API_URL` is ever set |
| Notched-device check of the overlay footprint | Confirm occlusion on Settings and on any screen without `extendBodyBehindAppBar` |

---

## Limitations of this audit

1. **MASTER-4.04: this is a SOURCE review.** No evidence comes from a release artifact or a
   production-like environment. Per the brief this is an honest constraint, not a failure, but it
   bounds several verdicts: I cannot confirm what is deployed to Firebase, what the store listings
   say, whether the support number is answered, or whether any console alert exists.
2. **No `flutter test` / `build` / `clean` / `pod install` was run** (concurrent agents). Central
   results cited from the brief: `flutter analyze` clean, design gate passes, 1,819 tests pass across
   101 files. Test-quality findings come from reading test sources and from `grep` over `test/`.
3. **The app was not executed.** Two findings are structural inferences from source and are labelled
   as such rather than as observations: the latent build-phase notifier write (§A.1, W7) and the
   `!_initialized` silent-no-op path (§C.1). Both are one runtime check away from confirmation and I
   recommend that check rather than asking anyone to take my reasoning on trust.
4. **The `IgnorePointer` finding rests on the owner's direct measurement plus the source.** I verified
   the source (`grep -rn "IgnorePointer" lib/` → 0 tree-wide); I did not re-run the tap measurement.
5. **Sections 7–9 are a first look on this repo.** Per the brief I graded them systematically rather
   than assuming rounds 1–3 covered the ground; where a control is graded Fail purely on the absence
   of a document, I have said so in the evidence column rather than implying a deeper search failed.
6. **Never-launched product.** Every "standing cadence" control is graded on whether the cadence is
   *defined*, since it cannot yet be *performed*. That is the only reading under which these controls
   are gradeable at all, and I have applied it uniformly.
7. **Not graded here:** the assistant Cloud Function's security posture, which round 3 covered at
   length in its §F. I re-verified the four load-bearing facts (`functions/index.js:17` `onRequest`,
   `:116` `cors: true`, `:26` `claude-opus-4-8` default, no `maxInstances`/`verifyIdToken`) and they
   are unchanged, but the full assessment belongs to the AI/LLM-safety module in this round.
