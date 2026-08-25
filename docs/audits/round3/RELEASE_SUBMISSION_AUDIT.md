# Release & App Store Submission — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** iOS App Store submission. The app has still **never been uploaded to App Store Connect**.
Graded against "shippable to the App Store", not "installs on my phone".

**Commands actually run this round (output cited inline):**
`sips` over all 15 appicon PNGs · a PIL bounding-box measurement of the 1024 icon ·
`nslookup api.housepital.in` · `curl -L` on apex and `www.` privacy URLs ·
`find ios -name "*.entitlements"` · `grep -c` over `Info.plist` and `project.pbxproj` ·
`git tag` · `git log 820060b..HEAD -- <appiconset>` · `git cat-file -e 820060b:<test>` ·
a per-source census of `DemoMode.markServingDemoData` / `markServingLiveData` ·
reading `url_launcher_ios-6.4.1/…/URLLauncherPlugin.swift` and `url_launcher-6.3.2/README.md`
out of `~/.pub-cache`.
**Not run** (per brief): `flutter test`, `flutter build`, `flutter clean`, `pod install`.
Cited central results: `flutter analyze` clean · design gate passes · 1,813 tests pass.

**Item basis:** the same 45 graded items as round 2, so the scorecards are comparable.

---

## Headline

**The checklist did not move. 3 ✅ / 16 ⚠️ / 25 ❌ / 1 N/A — identical to round 2, item for item.**

That is not because nothing happened. Real engineering landed. But of the four repairs I was asked
to adversarially review, **one is a genuine fix, two are partial, and one is a second layer of
exactly the pattern round 2 named** — a change that satisfies the literal wording of my
recommendation while producing none of its effect.

The single most important sentence in this report: **round 3 did not touch the top blocker.**
`grep -rn "fromEnvironment" lib/` returns two hits (`constants.dart:11` `ASSISTANT_API_URL`,
`constants.dart:23` `RAZORPAY_KEY`). There is still **no `DEMO_DATA` gate**, and
`app_provider.dart:134-143` still unconditionally installs `DemoData.patient` on every fresh
install. Round 1 answered that blocker with a banner. Round 2 answered it with a set-based flag.
Round 3 answered it with a smaller banner. The seed itself has never been touched.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **B1** App icon a 3.6× upscale, ~50 % canvas fill | ⚠️ | **⚠️ unchanged, byte-identical** | `git log 820060b..HEAD -- ios/Runner/Assets.xcassets/AppIcon.appiconset/` → **empty**. PIL bbox on the 1024: ink `x[255,768] y[184,838]` = 514×655 → **50.2 % width / 64.0 % height** |
| **B2** Camera/photo usage strings | ✅ | **✅ unchanged** | `grep -c NSCameraUsageDescription Info.plist` → 1 |
| **B3** Demo patient seeds on every fresh install | ❌ | **❌ unchanged in substance** | `grep -rn fromEnvironment lib/` → only `ASSISTANT_API_URL`, `RAZORPAY_KEY`. `app_provider.dart:134-143`, `:283-296` unchanged |
| **B4** `/delete-account` transmits nothing, no auth delete | ⚠️ | **⚠️ improved but still ⚠️** — credential delete is now attempted; the "request" reaches no server and is never read | `delete_account_screen.dart:78-93,126-138`; see §(a) |
| **B5** Privacy/Terms fail TLS on apex | ❌ | **❌ unchanged** | apex `curl` → HTTP `000`; `www.` → `200`. Four links: `about_screen.dart:98,104,110`, `referral_screen.dart:121` |
| **B6** `api.housepital.in` NXDOMAIN | ❌ | **❌ unchanged** | `nslookup` → `NXDOMAIN` |
| **B7** Placeholder Razorpay key in recorded build | ⚠️ | **⚠️ unchanged** | `DART_DEFINES` decodes to six Flutter metadata entries only — no `RAZORPAY_KEY` |
| **B8** `ITSAppUsesNonExemptEncryption` missing | ❌ | **❌ unchanged** | `grep -c` → `0` |
| **B9** No medical disclaimer in the UI | ❌ | **❌ unchanged** | same grep → **exactly one hit**, still inside a demo article body (`demo_articles.dart:192`) |
| **H10** No `.entitlements`, Push dead | ❌ | **❌ unchanged** | `find ios -name "*.entitlements"` → empty; `grep -c UIBackgroundModes` → `0` |
| **H11** `LSApplicationQueriesSchemes` absent | ❌ | **❌ unchanged; re-graded with new evidence** | `grep -c` → `0`. See §(e) — I got closer but still cannot close it on-device |
| **H12** No remote-config kill switch | ❌ | **❌ unchanged** | grep over `lib/` + `pubspec.yaml` → **no matches** |
| **H13** iPad declared + landscape unlocked | ❌ | **❌ unchanged** | `project.pbxproj:488,618,671` → `TARGETED_DEVICE_FAMILY = "1,2"` |
| **H14** Android release signs with debug keys | ❌ | **❌ unchanged** | `android/app/build.gradle.kts:34-38`, TODO still in place |
| **H15** Placeholder support number | ❌ | **❌ worse — there are THREE, not two** | `help_faq_screen.dart:352` (`tel:+919999999999`), `:365` (`wa.me/919999999999`), **and `staff_otp_verification_screen.dart:352` (`tel:+918888888888`)**, while `constants.dart:17,19` hold the real `9990911911` |
| **H16** Firestore/storage rules + key restrictions undeployed | ❌ | **❌ unchanged** | `storage.rules:6-11` still headed `!! DEPLOY REQUIRED !!`; `KNOWN_ISSUES.md` BUG-33 "deployment to console pending", BUG-34 "Open" |
| **M17** `debugPrint` in release | ⚠️ | **⚠️ unchanged** | `grep -rn debugPrint lib/ \| wc -l` → **34** |
| **M19** Banner double-counts top inset on My Care + Billing | ❌ (new in R2) | **✅ genuinely fixed** | banner removed from `main_shell.dart` (grep → no hits); now a Stack overlay from `main.dart:434`. It displaces nothing, so `my_care_screen.dart:141` / `billing_screen.dart:172` are correct again |
| **M21** CHANGELOG behind HEAD | ❌ (9 behind) | **❌ worse — now 14 behind** | newest entry `CHANGELOG.md:7` `[2026-06-13]` = `d89c0b8`; `git log --oneline d89c0b8..HEAD \| wc -l` → **14** |
| **§11 KNOWN_ISSUES** | ⚠️ | **⚠️ unchanged** | `:5` still "Last updated: **2026-05-28**"; BUG-34 still names `in.housepital.patient`, a package that does not exist |
| **§11 four docs assert six tabs** | ❌ | **⚠️ partially fixed, and newly re-broken** | `ARCHITECTURE.md:68`, `SCREEN_MAP.md:6`, `FEATURE_TRACKER.md:143` fixed. **Still wrong:** `SCREEN_MAP.md:73` "### CALENDAR TAB (Index 3)", `:81` "BILLING TAB (Index 4)", `:133` "MORE TAB (Index 4)" — two sections claim index 4, and Billing is actually 3 (`main_shell.dart:37-43`). **Newly wrong:** `SCREEN_MAP.md:6` now reads "5 tabs, **FIXED full-width solid-orange bar**" — correct when written at `0f2729e`, falsified three commits later by `d439928`'s floating glass pill |
| **§9 no `AuthProvider` test** | ⚠️ | **❌ my round-2 claim was WRONG** | `git cat-file -e 820060b:test/providers/auth_provider_test.dart` → **PRESENT at 820060b**; added in `4bcaadb`, 322 lines. Round 2 asserted the file did not exist. It did. Correcting the record |

---

## Round-2 repairs: adversarial review

### (a) `/delete-account` — does a local record + credential delete satisfy 5.1.1(v)? **No.**

**What genuinely improved, and it is not nothing.** The 600 ms `Future.delayed` is gone.
`delete_account_screen.dart:126-138` now calls `FirebaseService().currentUser` →
`await user.delete()`. The dialog copy is rewritten to separate what is DONE from what is
REQUESTED (`:148-159`), with three distinct localized strings and a reference number. The false
"scheduled for deletion within 30 days" promise is gone — `delete_account_done_server` now reads
*"Requested — not yet done: your records held by Housepital still need to be deleted by our team."*
That is honest, and honesty was the specific defect round 2 called worse than the missing feature.
The screen is fully localized in EN and HI.

**Now the precise 5.1.1(v) question the brief asked.**

*Does Apple accept a request that reaches no server?* No — and this is the crux.
Guideline 5.1.1(v), in force since 30 June 2022, requires an app that supports account creation
to support account **deletion initiated from within the app**, and Apple's supporting guidance is
explicit on two points: the flow must delete the account and its associated data rather than
deactivate or hide it, and directing the user to an external channel as the *only* way to complete
deletion is insufficient. There is one narrow carve-out — apps in highly regulated industries
(Apple's own examples include healthcare) that are legally obliged to perform additional identity
verification may *initiate* deletion in-app and hand off to a verification step. Housepital could
plausibly stand on that carve-out: DPDP 2023 §12 plus Indian tax retention on invoices is a real
regulatory posture, and the screen already separates "what gets deleted" from "what we must keep".

**But the carve-out requires the in-app action to initiate something at the provider.** This one
initiates nothing. `_recordDeletionRequest` (`:78-93`) writes a JSON blob to
`SharedPreferences` under `housepital_pending_deletion`. I searched the entire tree for any reader:

```
grep -rn "housepital_pending_deletion\|pendingDeletionKey" lib/ test/ scripts/ docs/
  lib/providers/auth_provider.dart:233        ← preserve-list literal
  lib/screens/settings/delete_account_screen.dart:60   ← the constant
  lib/screens/settings/delete_account_screen.dart:84   ← the write
```

Three references: the constant, the write, and a string literal in a preserve-list. **Nothing ever
reads it.** There is no replay path, no upload-on-reconnect, no UI that surfaces it, no test. The
file's own doc comment (`:41-43`) says "When the backend lands, replace `_recordDeletionRequest`'s
local write with the real endpoint" — i.e. the record is explicitly a placeholder for a request,
not a request.

The consequence is sharper than "incomplete". The reference `DEL-…` is generated on-device
(`:80-81`, a base-36 millisecond timestamp) and exists in **no system a Housepital agent can
query**. The dialog tells the user to "Call 9990-911-911 with the reference below to confirm". A
user who does that will quote a number the company has never seen. That is functionally the
"contact support to delete your account" pattern Apple rejects, wearing the costume of a tracked
request — and it is arguably a worse user experience than plain support handoff, because it
manufactures the impression of a ticket.

*Does deleting the auth credential alone count?* It is the most valuable line in the change, and
it is **structurally insufficient in the general case and unreliable in this one.**

- **Insufficient in general:** 5.1.1(v) requires associated data to go too. Today no server-side
  patient record exists, so wiping device + credential arguably is complete — but that is an
  accident of `api.housepital.in` not resolving, and it stops being true the day it does. The
  screen's own copy admits this ("your records held by Housepital still need to be deleted").
- **Unreliable here, and this is the buried defect:** `user.delete()` is wrapped in a bare `catch`
  (`:134-138`) that logs a warning and continues. Firebase throws `requires-recent-login` for any
  session older than roughly five minutes. `grep -rn "reauth\|requires-recent-login\|reauthenticate" lib/`
  → **zero hits**. Round 2's recommended fix was *"call `FirebaseAuth.currentUser.delete()` **with
  re-auth-on-`requires-recent-login`**"* — the re-auth is precisely the part that was dropped. So
  the **default** path, not the edge case, is: credential not deleted → `credentialDeleted = false`
  → the user is shown `delete_account_done_login_pending` = *"Pending: we could not remove your
  login automatically. Call us and we will do it."*
- **On the reviewer's most likely path it never even fires.** `splash_screen.dart` routes to
  `/home` with no auth gate, so a reviewer who never signs in has `currentUser == null` (`:130`),
  the `if` is skipped, and they get the same "call us" copy.

**Verdict: ⚠️, unchanged in grade.** It is a better ⚠️ than round 2's — the lie is gone and the
code now attempts the right operation. But the two things that would make it pass, a request that
leaves the device and a re-auth so the credential actually dies, are both still absent, and the
"durable local record" is write-only. **This is the second layer of the round-2 pattern**: my
recommendation said "persist the request"; what was built persists a request that no one will ever
receive, read, or replay.

**To make it compliant, in order:** (1) wrap `user.delete()` in a `reauthenticateWithCredential`
retry on `requires-recent-login` — this alone converts the common case from failure to success and
needs no backend; (2) write the request to Firestore `deletion_requests/{uid}` (the SDK is already
a dependency, the collection needs no new infrastructure) and keep the local record only as an
offline outbox with a real flush-on-reconnect; (3) surface the pending record somewhere a user or
support agent can see it; (4) delete or repoint `help_faq_screen.dart:156`'s "email us" paragraph
so there is one deletion story.

### (b) The demo-data notice as an overlay pill — re-assessed under 2.1 / 2.3.1 / 1.4.1

**The coverage fix is real and is the best thing in this round.** `main.dart:434` installs
`DemoDataBannerHost(child: child!)` from `MaterialApp.builder`, **above the Navigator**. That is
the correct architectural position and it directly answers my round-2 criticism that the banner
"lives in one widget, in `MainShell`'s Column, so it covers exactly the five root tabs". The
notice now renders over `/vitals`, `/medication-schedule`, `/care-team`, `/care-calendar` and the
other pushed clinical routes I listed. For **1.4.1** that is the change that mattered most: round 2
said the banner was "not improved at all where it matters most" because `/vitals` renders
colour-coded `DemoData.vitalsHistory` with no warning. It is now covered. Credit where due.

**The prominence regression is also real.** A full-width strip reading *"Showing sample data — we
can't reach Housepital right now"* became a 12 px, single-line, `maxLines: 1` +
`TextOverflow.ellipsis` pill reading *"Sample data — not your live record"*
(`demo_data_banner.dart:114-127`). Under large Dynamic Type that string ellipsises — the warning
is the one piece of text in the app that must survive accessibility scaling, and it is the piece
built to truncate.

**Does a subtler warning make the demo-data build more or less shippable? Neither — and that is
the point.** 2.1 is a **completeness** requirement, not a disclosure requirement. Shrinking the
label does not make the content final. A reviewer on a fresh install still lands on Rajesh Kumar,
72, post-stroke, with five named prescriptions including *Insulin Glargine 10 units at bedtime*
(`demo_data.dart:28-68`), because `app_provider.dart:134-143` still installs it unconditionally.
The rejection ground is identical at any font size. The only thing a quieter pill changes is the
probability the reviewer reads the confession off the first screen — which is not a compliance
improvement, it is a hope.

- **2.1 — ❌ unchanged.** The seed is ungated. No `DEMO_DATA` define exists.
- **2.3.1 — ⚠️, modestly improved.** Twelve previously unlabelled pushed routes are now labelled.
  Offset by the three unwired sources and the latch, below.
- **1.4.1 — ⚠️, materially improved but not cleared.** `/vitals` is covered. Still no medical
  disclaimer anywhere in the UI (grep → one hit, in a demo article body), and the handover PDF
  remains a 1.4.1 exhibit in its own right (§c).

**Three defects the redesign introduced or left standing:**

1. **Three declared sources are never wired.** `demo_mode.dart:31-33` declares
   `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile`. A census of every call site:

   | source | `markServingDemoData` | `markServingLiveData` |
   |---|---|---|
   | dashboard | 1 | 1 |
   | patient-identity | 1 | **0** |
   | medications | 2 | **0** |
   | my-care | 2 | **0** |
   | billing | 1 | **0** |
   | orders | 1 | **0** |
   | articles | 2 | **0** |
   | handover-report | 1 | **0** |
   | **care-team** | **0** | 0 |
   | **care-calendar** | **0** | 0 |
   | **profile** | **0** | 0 |

   `grep -rn "DemoMode" lib/screens/my_care/care_team_screen.dart lib/screens/my_care/care_calendar_screen.dart lib/models/care_event.dart lib/screens/settings/patient_profile_screen.dart`
   → **no output**. These are the exact three unmarked sources round 2 named. What round 3 added
   was the *constant*, not the call. The enumeration now looks complete in `demo_mode.dart` while
   the screens it names are as unmarked as they were. That is the round-2 pattern again, in
   miniature: the artifact that makes the fix legible was produced; the fix was not.

2. **Seven of eight wired sources never clear.** Only `sourceDashboard` calls
   `markServingLiveData` (`app_provider.dart:273`). Once medications, billing, orders, my-care,
   articles, patient-identity or handover raise the flag, it stays raised for the process lifetime.
   `demo_mode.dart:16-17` names this exact defect as a reason for the redesign — *"`MyCareProvider`
   raised it and never lowered it, so a healthy backend showed a permanent false alarm"*. The
   redesign fixed the "one provider lowers for all" half and left the "never lowers" half in place
   for 7 of 8 sources. A warning that can never come down is one a user learns to ignore.

3. **The pill occludes content and steals taps.** It is `Positioned(top: padding.top +
   kToolbarHeight + 4, …)` in a Stack (`demo_data_banner.dart:44-49`) with **no `IgnorePointer`**
   (grep → none). A `Positioned` child with an opaque `Container` decoration absorbs pointer events
   in its bounds. `settings_screen.dart:87-93` has **no** `extendBodyBehindAppBar`, so its body
   starts at exactly `padding.top + kToolbarHeight` — the pill lands 4 px into the first content
   row, which is the profile `InkWell` that navigates to `/patient-profile` and contains the
   avatar's own photo-picker `GestureDetector` (`:97-110`). So on Settings the notice both covers
   and disables the first interactive element on the screen.
   **Overlay-occlusion vs the displacement it replaced:** the displacement was cosmetic dead space
   on two of five tabs. The occlusion swallows taps on an unbounded set of screens, silently. That
   is worse in kind, though smaller in area. The correct shape is the current overlay position
   **plus `IgnorePointer`** — one line, and the notice has no interactive affordance to lose.

4. **No test covers it.** `grep -rln "DemoDataBanner\|demo_banner\|DemoMode" test/` → only
   `test/providers/patient_scope_isolation_test.dart`. Three shapes of this widget have now
   regressed in three consecutive rounds and nothing asserts its behaviour.

### (c) The handover PDF "SAMPLE DATA" band — does it resolve the round-2 worst finding? **Partly.**

**The band is real and correctly placed.** `handover_report_service.dart:127-142` puts it in
`pw.MultiPage`'s `header:` callback, so it renders on **every page**, not just the first — which is
the property that matters for a document that gets printed, split, or photographed a page at a
time. The wording is specific and unhedged: *"SAMPLE DATA - NOT A CLINICAL RECORD. This report was
generated while the Housepital service was unreachable and contains placeholder information. Do not
use it for clinical decisions."* Red-on-red50. That is a genuine mitigation and it is more than I
expected.

**Why it does not resolve the finding.**

- **The document is still 100 % fabricated.** `:107-115` still assigns every section from
  `DemoData` by hardcoded assignment — patient, medical history, active medications, the full
  vitals series, today's report, services, staff on duty, appointments. Round 2's fix had two
  halves — drive it from live providers **or** watermark it, *and* **"refuse to export at all if no
  real patient record has ever loaded"**. The refusal was not implemented. There is no guard: the
  export is always available and its only possible output is placeholder content.
- **The warning is the smallest text in the document.** `fontSize: 8` (`:138`) against a `18` pt
  title (`:167`), `10` pt subtitle, `9–10` pt body. The disclaimer is set smaller than everything
  it disclaims.
- **A label on a detached artifact is the weakest possible mitigation.** The whole purpose of this
  feature is to produce something that leaves the app and is handed to a treating physician
  (`Printing.sharePdf`). Every other warning in the app has the app's context around it; this one
  is on its own, competing with a Housepital logo, a "Doctor Handover Report" H1, and a
  *"Housepital Doctor Handover Report — page N of M"* footer that all say *authentic*.
- **New defect — a global side effect inside a builder.** `:105` calls
  `DemoMode.markServingDemoData(DemoMode.sourceHandover)` from inside `buildHandoverPdf`. Since
  `sourceHandover` is never cleared (table above), **generating one report latches the app-wide
  pill on permanently**, even on a fully healthy backend. A document builder should not mutate
  global UI state.
- **Latent inversion.** The band is unconditional, and `:97-98` states the future backend swap
  "only changes the sources, not the PDF". The day real data flows, this stamps *"NOT A CLINICAL
  RECORD"* across a genuine clinical record. A warning that will be wrong in both directions at
  different times is one clinicians learn to disregard.

**So: does a fabricated clinical document remain a problem regardless of its watermark? Yes.**
For **1.4.1** the risk is reduced but not removed, because the mitigation is a small label on an
artifact engineered to be separated from its context. For **2.1** the watermark is irrelevant — an
export feature whose only possible output is placeholder content is non-final functionality, and
labelling it as such is a confession, not a cure. The blocker stands, downgraded in severity from
"the single highest-risk artefact in the app" to "a labelled fabricated document that should not
be shippable at all". **Minimum acceptable fix:** make the band conditional on
`DemoMode.isServingDemoData`, raise it to ≥12 pt, move the `markServingDemoData` call out of the
builder, and **hard-refuse the export when no real patient record has ever loaded** — which is the
half of the round-2 recommendation that was skipped.

### (d) The icon (unchanged this round) — exact designer deliverable

`git log 820060b..HEAD -- ios/Runner/Assets.xcassets/AppIcon.appiconset/` → **empty**. All 15 PNGs
are byte-identical to round 2. `sips` re-confirms every size correct, `hasAlpha: no`, `space: RGB`
— **it will pass ITMS-90717 upload validation.** A fresh measurement of the 1024 sharpens round 2's
estimate: non-white ink occupies `x[255,768] y[184,838]` = 514×655 px on a 1024 canvas, i.e.
**50.2 % of width, 64.0 % of height**. Typical single-glyph marks fill 70–80 %. It also carries no
iOS 18 appearance variants — `grep -c "appearances\|luminosity\|tinted" Contents.json` → **0**, and
the directory holds only the 15 light-mode PNGs.

**The exact deliverable to request from the designer — one email:**

> **Source (required):** the vector master of the Housepital mark — SVG, AI, or PDF — with the
> "O"-and-nurse-cap glyph drawn as a **standalone icon**. Not a crop from the wordmark: the current
> icon was cut out of `assets/images/housepital_logo.png`, 1200×312 with alpha, lettering that was
> never designed to stand alone.
>
> **A. `Icon-App-1024x1024@1x.png`** — 1024×1024, sRGB, **no alpha channel** (flattened onto an
> opaque background; a transparent 1024 is rejected at upload as ITMS-90717), **no baked-in rounded
> corners or drop shadow** (iOS applies its own squircle mask), background full-bleed to all four
> edges, mark scaled to **~72 % of canvas width** and optically centred — up from today's 50.2 %.
>
> **B. The other 14 sizes** — 20/29/40/60/76/83.5 pt at their required scales (20, 29, 40, 58, 60,
> 76, 80, 87, 120 ×2, 152, 167, 180 px), each **rendered from the vector at its target size**, not
> resampled down from the 1024. Same no-alpha, no-corner-radius constraints.
>
> **C. iOS 18 variants (recommended, not required for approval)** — a **dark** version (mark on a
> dark background, no white plate) and a **tinted** version (single-channel greyscale artwork that
> the system recolours). These need `appearances` entries in `Contents.json`; the modern Xcode 16
> workflow takes one 1024 per appearance.

This is **BLOCKED-OWNER**. Nothing in this repo can make a 143×182 raster crisp at 1024.
It does not block *upload*; it is a visible quality signal on the largest, most-scrutinised asset
in the submission and gives a reviewer standing under 4.0 (Design).

### (e) `LSApplicationQueriesSchemes` and the SOS dial path — closer, still not closable here

Round 2 flagged this on the plugin's documented contract and said it was a two-minute device check
it could not run. I still cannot run it — `flutter build`/`run` are forbidden this round, and this
is an iOS-runtime behaviour. But I got two pieces of harder evidence out of `~/.pub-cache`:

1. **The plugin does exactly what round 2 assumed.** `url_launcher_ios-6.4.1/…/URLLauncherPlugin.swift:27-33`:
   `func canLaunchUrl(url:)` → `launcher.canOpenURL(url)`. It is a direct
   `-[UIApplication canOpenURL:]` call, with no allow-listing of its own.
2. **The plugin's own README names `tel` explicitly.** `url_launcher-6.3.2/README.md:47-57`:
   *"Add any URL schemes passed to `canLaunchUrl` as `LSApplicationQueriesSchemes` entries in your
   Info.plist file, otherwise it will return false"* — and its worked example lists exactly
   `<string>sms</string>` and `<string>tel</string>`.

Current state: `grep -c LSApplicationQueriesSchemes ios/Runner/Info.plist` → **0**.
`grep -rhno "Uri.parse('[a-z]*:" lib/` → **11 `tel:` and 1 `https:`**. Five sites gate on
`canLaunchUrl`: `sos_screen.dart:251` (**the emergency dial path**),
`assistant_screen.dart:40`, `staff_otp_verification_screen.dart:353` (all three literal `tel:`),
plus `help_faq_screen.dart:408` and `about_screen.dart:168` (variable URL — `tel:`, `mailto:` and
`https:` respectively). Note the site list has shifted since round 2: `payment_methods_screen.dart`
no longer gates, `about_screen.dart` now does.

**The honest position, stated as uncertainty rather than resolved:** Apple's `canOpenURL:`
documentation imposes the declaration requirement on apps linked against iOS 9+, and the plugin
author's README is unambiguous that `tel` needs declaring. Against that, the
`LSApplicationQueriesSchemes` allow-list exists as a privacy control against apps enumerating
*third-party* apps, and schemes handled by Apple's own system apps are widely observed to return
`YES` undeclared. I could not resolve which behaviour applies on this build, and I will not claim
I did. **What makes the uncertainty moot: the fix is four strings in a plist and costs nothing.**
Add it regardless of which way the runtime falls — that converts an unresolved question into a
non-question.

Graded **❌** on the documented contract with the caveat above. Mitigating: `sos_screen.dart:258-275`
degrades to a "Could not auto-dial" dialog with copy-to-clipboard, so CLAUDE.md's "SOS is never
blocked" rule is honoured in spirit — the path degrades rather than dead-ends. But an emergency
call that requires the user to read a number and retype it during an emergency is a bad outcome for
a plist key.

**Fix:** `<key>LSApplicationQueriesSchemes</key><array><string>tel</string><string>sms</string><string>mailto</string></array>`

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Version & build | 0 | 2 | 1 | 0 |
| 2. Flags & configuration | 0 | 2 | 2 | 0 |
| 3. Backend / services prod-ready | 0 | 0 | 4 | 0 |
| 4. Build provenance & signing | 0 | 1 | 2 | 0 |
| 5. Privacy & compliance | 1 | 1 | 4 | 0 |
| 6. Listing / launch assets | 0 | 1 | 3 | 1 |
| 7. Reviewer / stakeholder notes | 0 | 0 | 3 | 0 |
| 8. Build & package | 0 | 2 | 0 | 0 |
| 9. Pre-ship QA | 1 | 3 | 0 | 0 |
| 10. Staged rollout | 0 | 1 | 2 | 0 |
| 11. Submit / deploy & record | 0 | 1 | 3 | 0 |
| 12. Rollback / hotfix plan | 1 | 2 | 1 | 0 |
| **TOTAL (45 items)** | **3** | **16** | **25** | **1** |

Round 2: 3 ✅ · 16 ⚠️ · 25 ❌ · 1 N/A. Round 1 (same basis): 3 ✅ · 14 ⚠️ · 27 ❌ · 1 N/A.
**Net movement round 2 → round 3: zero.** Two items improved *within* ⚠️ (account deletion, the
demo notice's route coverage), one ❌ was genuinely closed and replaced by a different ❌-class
defect at the same grade (banner inset → pill occlusion), and two ❌ items got worse without
changing grade (CHANGELOG 9→14 behind; a third placeholder phone number).

**One-glance gate:** tests ✅ (1,813 pass centrally) · no QA flag on ⚠️ ·
prod backend ready ❌ (NXDOMAIN) · privacy URL + disclosure ❌ (apex TLS `000`) ·
build id bumped ⚠️ (`1.0.0+1`) · clean-install QA ❌ (fresh install still shows a fabricated
patient) → **DO NOT SHIP.**

---

## Findings

### Blockers (must fix before any submission)

1. **Demo patient data seeds on every fresh install, ungated** — `app_provider.dart:134-143`,
   `:283-296`. No `DEMO_DATA` define exists (`grep fromEnvironment` → 2 unrelated hits). Three
   rounds of increasingly sophisticated *labelling*; the seed has never been gated. **2.1.**
2. **The handover PDF is a fabricated clinical document with no export guard** —
   `handover_report_service.dart:107-115`. The SAMPLE band (`:127-142`) is a real mitigation on
   every page, but the data is still 100 % `DemoData`, the warning is 8 pt (smallest text in the
   document), the "refuse to export" half of the fix was skipped, and `:105` latches the global
   demo flag on permanently as a side effect. **1.4.1 / 2.1.**
3. **`/delete-account` initiates nothing at Housepital and usually fails to delete the credential** —
   `delete_account_screen.dart:78-93` (write-only local record, zero readers), `:126-138` (bare
   catch, no re-auth, so `requires-recent-login` is the normal path). **5.1.1(v).**
4. **Privacy Policy / Terms fail TLS on the apex domain** — apex `curl` → HTTP `000`; `www.` → 200.
   Four links: `about_screen.dart:98,104,110`, `referral_screen.dart:121`. `constants.dart:20`
   already holds the correct `www.housepital.in`.
5. **Production API host does not exist** — `api.housepital.in` NXDOMAIN.
6. **Placeholder Razorpay key in the recorded build config** — `DART_DEFINES` carries no
   `RAZORPAY_KEY`, so `constants.dart:23` falls back to `rzp_test_XXXXXXXXXX` → simulated checkout.
7. **`ITSAppUsesNonExemptEncryption` missing** — every upload stalls in Missing Compliance.
8. **No medical disclaimer anywhere in the UI** while `vital_classifier.dart:5-14` colour-codes
   vitals at clinical thresholds. Grep → one hit, inside a demo article body.
9. **App icon is a 3.6× raster upscale filling 50.2 % of the canvas** — unchanged, byte-identical.

### High

10. **No `.entitlements` file; Push capability absent** — FCM fully wired and dead in production.
11. **`LSApplicationQueriesSchemes` absent while `canLaunchUrl('tel:')` gates the SOS dial path** —
    `sos_screen.dart:251` + 4 sites; see §(e). Fix is 4 plist strings; add regardless.
12. **No Crashlytics dSYM upload phase** — `grep -cE "crashlytics|upload-symbols|dSYM"` → 0.
13. **No feature-flag / remote-config kill switch** — grep → no matches.
14. **iPad declared (`TARGETED_DEVICE_FAMILY = "1,2"`) and landscape unlocked**, both untested.
15. **`storage.rules`, `firestore.rules` and API-key restrictions all undeployed** — live posture
    unknown. `storage.rules:6-11` still headed `!! DEPLOY REQUIRED !!`.
16. **Android release signs with debug keys** — `android/app/build.gradle.kts:34-38`.
17. **Three placeholder support numbers, not two** — `help_faq_screen.dart:352,365` and
    **`staff_otp_verification_screen.dart:352`** (`tel:+918888888888`), while the real number sits
    in `constants.dart:17,19`.
18. **The demo-data pill steals taps and occludes first-row content** —
    `demo_data_banner.dart:44-49`, no `IgnorePointer`; lands 4 px into `settings_screen.dart:93`'s
    profile row and its avatar photo-picker. One-line fix.
19. **Three declared `DemoMode` sources are never wired** — `sourceCareTeam`, `sourceCareCalendar`,
    `sourceProfile` (`demo_mode.dart:31-33`) have zero call sites. Care team, care calendar and
    patient profile still render fabricated clinical content with no signal.
20. **Seven of eight wired `DemoMode` sources never clear** — only `sourceDashboard` calls
    `markServingLiveData`. The notice latches on for the process lifetime; `demo_mode.dart:16-17`
    names this exact bug as a reason for the redesign.

### Medium / Low

21. 34 `debugPrint` calls in `lib/` ship in release, several interpolating exception objects.
22. Version hardcoded in `about_screen.dart:11` and `settings_screen.dart:258`; three inconsistent
    app identifiers across iOS / Android / `KNOWN_ISSUES.md:26`.
23. `CFBundleLocalizations` absent — the store will list a 321-key Hindi build as English-only.
24. CHANGELOG **14** commits behind HEAD (was 9), date-keyed rather than version-keyed.
25. `KNOWN_ISSUES.md:5` last updated 2026-05-28; records none of three audit rounds; BUG-34 still
    names `in.housepital.patient`, a package that does not exist.
26. `SCREEN_MAP.md` internally inconsistent: `:73` "CALENDAR TAB (Index 3)", `:81` "BILLING TAB
    (Index 4)", `:133` "MORE TAB (Index 4)" — two sections at index 4, and Billing is 3
    (`main_shell.dart:37-43`). **`:6` newly falsified** — says "FIXED full-width solid-orange bar"
    three commits before `d439928` restored the floating glass pill.
27. No git tags; no release-tagging process.
28. `LaunchScreen.storyboard:22` background white while `splash_screen.dart:24` paints orange.
29. `CFBundleDisplayName` "Housepital Patient" (18 chars) truncates on the Home Screen.
30. 81 MB assets (78 MB product photos) — likely over the 200 MB cellular threshold once linked.
31. No test asserts the demo notice's layout, coverage or hit-testing — three shapes, three
    regressions, zero coverage.
32. `storage.rules` ownership model assumes `auth.uid == patientId`, which denies family members.
33. **Correction to round 2:** `test/providers/auth_provider_test.dart` **does** exist (322 lines,
    added in `4bcaadb`, present at `820060b`). Round 2's "no `AuthProvider` test file" was wrong.

---

## BLOCKED-OWNER — what only the owner can supply

Unchanged in substance from round 2; **nothing on this list moved in round 3.**

1. **Apple Developer enrolment + App Store Connect app record** — bundle ID
   `com.housepital.housepitalPatient` (must match `project.pbxproj:690` exactly).
2. **Privacy policy at `https://www.housepital.in/privacy`** (verified 200; apex fails TLS),
   covering: phone, health data, prescription/report photographs, home address, Razorpay payment
   data, Crashlytics/Performance diagnostics, and — if `ASSISTANT_API_URL` is set — that assistant
   messages reach a third-party AI provider.
3. **Support URL + a real support phone/WhatsApp number** to replace all **three** placeholders.
4. **Marketing URL** (optional).
5. **App Store screenshots** — 6.7" and 6.5" iPhone mandatory; 12.9" iPad also mandatory unless
   `TARGETED_DEVICE_FAMILY` drops to `"1"`. Must not show the "Rajesh Kumar" record.
6. **Name, subtitle, description, keywords, promotional text** — no diagnostic/treatment claims.
7. **Age-rating questionnaire answers** — answer "Medical/Treatment Information" honestly.
8. **Category** — Primary: Medical; Secondary: Health & Fitness.
9. **App Privacy nutrition-label answers** — Health, Contact Info, User Content, Financial Info,
   Identifiers, Diagnostics, with linkage and purpose per category.
10. **Real Razorpay `rzp_live_…` key** via `--dart-define`, after KYC.
11. **Production backend** — stand up `api.housepital.in/v1` or repoint `apiBaseUrl` at the deployed
    Cloud Functions URL. **Plus three console deploys still pending:** `firebase deploy --only
    firestore:rules`, `--only storage`, and the API-key restrictions (fix BUG-34's package name
    first).
12. **APNs `.p8` key** uploaded to Firebase, after Push is enabled in Xcode.
13. **Firebase Auth test phone number**, quoted in the review notes.
14. **Export-compliance decision** — confirm HTTPS-only standard encryption.
15. **Business decision: iPad and landscape in or out?** Two-line change to drop them.
16. **Business decision: does Sahayak ship in 1.0?** If yes it needs an AI disclaimer and a privacy
    disclosure.
17. **Designer's vector of the Housepital mark** — full spec in §(d) above.
18. **Deletion-request destination** — decide where a request lands. Firestore
    `deletion_requests/{uid}` needs no new infrastructure and the SDK is already a dependency.
19. **New — device check on `tel:` + `LSApplicationQueriesSchemes`** (§e). One `flutter run` on a
    physical iPhone, tap SOS, observe whether the dialer opens or the fallback dialog appears.
    *Or skip it entirely and just add the four plist strings.*

---

## Ordered runway to submission (updated for round 3)

**Phase 0 — half a day, mechanical, no decisions needed.** Every value already exists in the repo:
`ITSAppUsesNonExemptEncryption` · `CFBundleLocalizations` (en, hi) ·
`LSApplicationQueriesSchemes` (tel, sms, mailto) · `www.` on the four apex URLs
(`about_screen.dart:98,104,110`, `referral_screen.dart:121`) · the real support number in all
**three** placeholder sites · `TARGETED_DEVICE_FAMILY = "1"` + portrait lock ·
`LaunchScreen.storyboard:22` → brand orange · **`IgnorePointer` around the demo pill** ·
**move `markServingDemoData` out of `buildHandoverPdf`** · wire the three unwired `DemoMode`
sources and add `markServingLiveData` to the seven that latch.

**Phase 1 — the review-compliance work (a few days), in this order:**
1. **Gate the seed.** `const bool.fromEnvironment('DEMO_DATA')` defaulting to `false` on
   `app_provider.dart:134-143` and `:283-296`, plus honest empty states. *This is the one that
   unblocks the most.*
2. **Guard the handover export** — refuse when no real patient record has loaded; make the band
   conditional and ≥12 pt.
3. **Finish `/delete-account`** — `reauthenticateWithCredential` on `requires-recent-login`, then a
   Firestore `deletion_requests/{uid}` write with the local record demoted to an offline outbox
   that actually flushes.
4. Medical disclaimer on vitals + daily reports; AI notice on Sahayak.
5. Enable Push in Xcode + `UIBackgroundModes`; add the Crashlytics `upload-symbols` phase.

**Phase 2 — assets and owner decisions (parallel with Phase 1).**
Designer's vector → regenerate all 15 icons at ~72 % canvas fill (+ optional iOS 18 dark/tinted) ·
iPad/landscape decision · Sahayak decision · privacy-policy content.

**Phase 3 — the real dependencies (owner-led, longest lead time).**
Stand up the production API or repoint `apiBaseUrl` · `firebase deploy --only firestore:rules` and
`--only storage` · API-key restrictions (fix BUG-34's package name first) · Razorpay KYC and a live
key · Firebase test phone number.

**Phase 4 — release hygiene, then ship.**
`firebase_remote_config` with `assistant_enabled` / `payments_enabled` / `force_upgrade` ·
CHANGELOG up to date (**14** commits) and version-keyed · `KNOWN_ISSUES.md` refreshed with three
rounds · fix `SCREEN_MAP.md`'s tab indices **and** its now-false nav description · a widget test for
the demo notice · `package_info_plus` for the version string · tag `v1.0.0` · archive with
distribution signing and a bumped build number · **TestFlight internal first** · then submit with
review notes covering the 3.1.5(a) real-world-services rationale, the test phone number, the
disclaimer placement, and the second account for role testing.

---

## Executive summary

1. **Round 3 counts: 3 ✅ / 16 ⚠️ / 25 ❌ / 1 N/A across 45 items — identical to round 2.** Zero net
   checklist movement.
2. **Genuinely fixed:** the demo notice's route coverage. Moving it to `MaterialApp.builder`
   (`main.dart:434`) puts it above the Navigator, so `/vitals`, `/medication-schedule` and ten other
   pushed clinical routes are finally labelled — the exact structural criticism round 2 made. The
   inset double-count that the previous shape introduced is gone with it.
3. **Also real:** the deletion screen now attempts `FirebaseAuth.currentUser.delete()` and its copy
   no longer lies — the 30-day promise is replaced by an explicit DONE-vs-REQUESTED split. The
   handover PDF's SAMPLE band renders on every page with unhedged wording.
4. **REGRESSED:** the pill absorbs taps (no `IgnorePointer`) and lands 4 px into the first content
   row of screens without `extendBodyBehindAppBar` — on Settings it covers and disables the profile
   row and its photo-picker. Traded cosmetic displacement for silent tap-stealing. CHANGELOG slipped
   from 9 to 14 commits behind. `SCREEN_MAP.md:6` was corrected then re-falsified three commits
   later by the nav revert. A third placeholder phone number surfaced.
5. **Yes — one round-2 repair is itself a surface, and it is the deletion "durable local record".**
   It is written and never read: three references in the whole tree (constant, write, preserve-list
   literal), no replay, no UI, no test. The on-device reference `DEL-…` exists in no system a
   support agent can query, so the dialog's "call us with this reference" sends users to quote a
   number Housepital has never seen. My round-2 fix said "persist the request"; what shipped
   persists a request nobody will ever receive.
6. **A second, smaller instance:** `demo_mode.dart:31-33` added constants for the three unmarked
   sources round 2 named — `sourceCareTeam`, `sourceCareCalendar`, `sourceProfile` — with **zero
   call sites**. The enumeration now reads complete while the screens are as unmarked as before.
   Separately, 7 of 8 wired sources never clear, reinstating the "permanent false alarm" bug the
   file's own comment cites as the reason for the redesign.
7. **And the blocker was not attempted.** No `DEMO_DATA` gate exists. Three rounds have produced a
   banner, a set-based flag, and a smaller banner; `app_provider.dart:134-143` is unchanged. 2.1 is
   a completeness requirement — no label satisfies it, and a *subtler* label does not make the demo
   build more shippable, it only makes the confession quieter.
8. **Top 5 remaining:** (i) gate the demo seed; (ii) guard the handover export and stop the builder
   mutating global state; (iii) re-auth + a server-side write for deletion; (iv) Phase 0's plist and
   URL one-liners, which are half a day for four blockers and two highs; (v) the owner-blocked
   dependencies — backend, rules deploys, live Razorpay key, designer's vector.
9. **Self-correction:** round 2 asserted no `AuthProvider` test file existed. It did —
   `test/providers/auth_provider_test.dart`, 322 lines, present at `820060b`. And I still could not
   settle the `tel:`/`LSApplicationQueriesSchemes` runtime question; I have the plugin source and
   its README saying `tel` must be declared, and I am not going to claim a device check I did not
   run. Add the four strings anyway — it costs nothing and retires the question.
10. **Verdict: FAIL. Do not submit.** The pattern round 2 named has not gone away; it has become
    more sophisticated. The surfaces are now better-written, better-commented and more
    self-aware — `delete_account_screen.dart:24-43` and `demo_mode.dart:11-20` both open by
    narrating the previous attempt's dishonesty — and they still stop at the same boundary, where
    the fix would need a server, a designer, or a console. Well-documented candour about a gap is
    not the same as closing it, and a comment explaining why the last version was a surface is not
    evidence that this one isn't.
