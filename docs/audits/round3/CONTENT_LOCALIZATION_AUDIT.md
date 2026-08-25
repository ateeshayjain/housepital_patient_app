# Content & Localization Checklist (App-Agnostic) — Audit round 3 vs commit `9a80fe2`

**Date:** 2026-08-05 · **Round 2:** `820060b` · **Round 1:** `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** read-only. No files changed outside this report. Every verdict carries `path:LINE` or a
command + its output.
**Method:** one measurement script run over all three trees (`git archive <ref>` into
`/tmp/l10n_trees/{r1,r2,r3}`), so the round-1 → round-2 → round-3 series is like-for-like.
`flutter test` / `flutter build` deliberately NOT run per the brief.

---

## Headline

Round 2 filed two blockers against this round's author. **Both were genuinely worked on, and one of
them is the first repair in three rounds that is not a surface.** The deletion record is real,
durable, and verifiably survives the wipe. Thirty-two i18n key pairs landed in both languages with
real Devanagari — the first movement in the localization ratio since round 1, and it moved the right
way (14.2 % → 16.3 %).

But both repairs stop one step short of the user, in the same way:

- **Deletion (F-1):** the honesty landed *after* the irreversible tap. Everything the user reads
  *before* consenting still says their records get deleted. The reference number the copy tells them
  to quote on the phone exists only in a SharedPreferences key that **no code anywhere reads**.
- **Payments (F-2):** the pending screen is correct, and its one CTA — "Contact Housepital" —
  navigates to `/help-faq`, whose Call button dials **`tel:+919999999999`** and whose WhatsApp button
  opens **`wa.me/919999999999`**. The repair for "money moved and you have no way to reach us" routes
  the user to two placeholder numbers. This is round 1's B-1 finally becoming load-bearing.

---

## Round-2 findings: status now

| Finding | R2 grade | Now | Evidence |
|---|---|---|---|
| **F-1** Deletion promises 30-day erasure over a 600 ms `Future.delayed` | ❌ BLOCKER | ⚠️ **PARTIAL — the lie is gone, the mechanism still ends on the phone** | `delete_account_screen.dart:78-93` writes a durable record; `:95-169` orders record → credential delete → wipe → separate DONE/REQUESTED copy. No "scheduled", no "30 days", no "call to cancel" anywhere in `en.json`/`hi.json`. But see §"Adversarial review" A-1..A-4. |
| **F-2** "Payment Failed" + "under verification" + "Retry Payment" on one screen | ❌ BLOCKER | ✅ **FIXED at the screen** | `payment_screen.dart:473-475` `Icons.schedule`; `:478-480` `context.hc.warning`; `:491-492` `l.t('payment_pending_verification_title')`; `:611-624` no Retry, single "Contact Housepital" CTA with the reason in the code comment `:612-613`. |
| **F-3** Raw Razorpay `response.message` rendered verbatim | ❌ HIGH | ❌ **UNCHANGED — and now load-bearing** | `payment_service.dart:220` `_onFailureCallback?.call(response.message ?? 'Payment failed')` → `payment_screen.dart:293` → rendered at `:574`. Escalated to blocker: see B-2. |
| **F-4** "Call us" with no number; untappable numbers | ⚠️ HIGH | ❌ **UNCHANGED / WORSE** | `payment_screen.dart:336-339` still "call us" with no number. `delete_account` numbers are now inside `en.json`/`hi.json` (3 strings each) rendered as plain `Text` — still no `tel:` launcher, and no `url_launcher` import in the file. |
| **F-5** Phone hardcoded in a third display format | ⚠️ MEDIUM | ⚠️ **MOVED, NOT FIXED** | `grep -c "9990-911-911" assets/i18n/*.json` → `en.json:3`, `hi.json:3`. Zero phone literals remain in `delete_account_screen.dart`, but the number now lives in **six** translatable strings instead of two Dart literals. `AppConstants.supportPhone` (14 call sites) is still not used. |
| **F-6.1** One global demo bool cleared by one provider | ⚠️ MEDIUM | ✅ **FIXED** | `DemoMode` is now a source set; `demo_data_banner.dart:36` listens to `DemoMode.isServingDemoData` as a `ValueListenable`; `handover_report_service.dart:105` marks `sourceHandover`. |
| **F-6.3** Banner not a live region, icon unlabelled | ⚠️ | ✅ **FIXED, well** | `demo_data_banner.dart:90-95` `Semantics(liveRegion: true, label: demo_banner_message)` + `ExcludeSemantics` on the visual; `:74-84` a one-shot assertive `SemanticsService.sendAnnouncement` on appearance, with the reasoning in the comment. |
| **F-7a** Disabled CTA with no reason | ⚠️ | ❌ **UNCHANGED** | `delete_account_screen.dart:296` `onPressed: canSubmit ? … : null`. No line tells the user the checkbox + typed word are both required. `login_screen.dart:48-60` still holds the right pattern, still unused. |
| **F-7b** Consequence disclosed after consent | ⚠️ | ❌ **WORSE IN KIND** | The 30-day claim is gone, but the *entire* server-side caveat now appears only after the tap (`:149-168`). See A-1. |
| **F-8** Voice / register of new copy | ⚠️ | ⚠️ **IMPROVED** | "Payment Failed" no longer fires on the pending path. "Payment under verification" (institutional register) survives as the **body** text, untranslated — `payment_service.dart:180,186`. |
| **F-9** Every new string hardcoded English; zero new keys | ❌ HIGH | ✅ **FIXED for the three new surfaces** | 32 new key pairs, all present in both files, all used. See "Localization re-measurement". |
| **F-10** Neither new screen covered by the overflow guard | ⚠️ | ❌ **UNCHANGED** | `grep -rln "DeleteAccount\|delete_account" test/` → only `test/utils/permission_test.dart`. `grep -rln "DemoDataBanner\|demo_banner" test/` → **no match**. `overflow_smoke_test.dart:231` `locale: 'en'`, `:335` `supportedLocales: const [Locale('en')]`; `grep -rn "Locale('hi')" test/` → **zero**. |
| **B-3** Placeholder phones dialable | ❌ | ❌ **UNCHANGED — now escalated** | `help_faq_screen.dart:352` `tel:+919999999999`, `:365` `wa.me/919999999999`; `staff_otp_verification_screen.dart:352` `tel:+918888888888`. Now the destination of the payment-pending CTA. |
| **B-4** SOS ambulance → concern form | ❌ | ❌ **UNCHANGED** | `sos_screen.dart:89-91` "Book Housepital Ambulance" / "Request ACLS ambulance dispatch"; `:192-194` `_bookAmbulance` → `pushNamed('/raise-concern')`. |
| **B-5** `emergencyPhone == supportPhone` | ❌ | ❌ **UNCHANGED** | `constants.dart:17,19` — both `'9990911911'`. |
| **B-6** Two contradictory vital classifiers | ❌ | ❌ **UNCHANGED** | `lib/utils/vital_classifier.dart` present; `vitals_screen.dart:14` imports it and `:548` still calls `VitalHelper.getVitalStatus`; `my_care_screen.dart:12` imports the other. |
| **H-5** "Airtel-style" dunning copy | ❌ | ❌ **UNCHANGED** | `payment_reminder_service.dart:126` comment verbatim; `:135` "Pay now to avoid service interruption."; `:153` "Late charges may apply. Pay now." |
| **H-6** Legal consent English-only | ❌ | ⚠️ **ONE OF THREE FIXED** | `delete_account_screen.dart` is now fully localized. `rental_agreement_screen.dart:96` still hardcodes `'I agree to the rental terms and conditions'` while `agree_terms` sits translated and unused; `login_screen.dart:209-240` unchanged. |
| **H-7** Handover PDF has no clinical disclaimer | ❌ | ✅ **FIXED** | `handover_report_service.dart:127-141` — unconditional per-page header band: *"SAMPLE DATA - NOT A CLINICAL RECORD … Do not use it for clinical decisions."* English-only and hardcoded, but the PDF cannot render Devanagari anyway (M-4). |
| **H-8** Red vital says "Needs attention" and stops | ❌ | ❌ **UNCHANGED** | `vitals_screen.dart:846-858` — `'red'` still yields only `l.t('vital_status_alert')`. |
| **H-9** No `Intl.defaultLocale` / `initializeDateFormatting` | ❌ | ❌ **UNCHANGED** | `grep -rn "Intl.defaultLocale\|initializeDateFormatting" lib/` → **no matches**. |
| **H-10** Dai Maa's number presented as "our coordinator" | ❌ | ❌ **UNCHANGED** | `payment_methods_screen.dart:355,363,374`, `staff_replacement_screen.dart:227` — all `+91-90502-00183` = `daimaa_theme.dart:23`. |
| **H-11** Android launcher label is `housepital_patient` | ❌ | ❌ **UNCHANGED** | `android/app/src/main/AndroidManifest.xml:7`. |
| **M-1** Free localization wins | ⚠️ 95 | ⚠️ **97, none taken** | Script output below. 158 unused keys; 97 hold the exact English a screen hardcodes. `agree_terms`, `no_data_available`, `error_occurred`, `retry`, `loading` all still unused. |
| **M-3** Invoice money hand-formatted | ❌ | ❌ **UNCHANGED** | `invoice_pdf_service.dart:69` `'Rs ${amount.round()}'`. |
| **M-4** PDFs cannot render Devanagari | ❌ | ❌ **UNCHANGED** | `grep -n "Font\.\|loadFont\|ttf" lib/services/invoice_pdf_service.dart lib/services/handover_report_service.dart` → **no matches**. |
| **M-5** Pluralization | ❌ | ❌ **UNCHANGED** | `rental_agreement_screen.dart:54` `'${widget.durationMonths} month(s)'` + the `service_booking_screen` / `invoice_pdf_service` sites. |
| **M-10** `frequencyLabel` leaks snake_case | ❌ | ❌ **UNCHANGED** | `medication_models.dart:78` `default: return frequency;`. |
| **M-13** Deletion spinner has no copy | ⚠️ | ❌ **UNCHANGED** | `delete_account_screen.dart:297-303` — bare `CircularProgressIndicator` inside the button. It now covers a real multi-step operation (prefs write → Firebase delete → full wipe → sign-out), so the silent window is *longer* than the 600 ms it replaced. |
| **L-2** `'% off'` vs `'% OFF'` | ❌ | ❌ **UNCHANGED** | 3 × `% OFF` (`universal_search_screen.dart:247,496`, `package_detail_screen.dart:313`) vs `% off` (`cart_screen.dart:813`, `service_booking_screen.dart:282,2371`). |
| **L-5** Stale contrast comment | ❌ | ❌ **UNCHANGED** | `theme.dart:172` still reads "Dark ink on orange — white on orange is only ~2.3:1 (fails AA)". |
| **L-6** "PDF upload coming soon" | ❌ | ❌ **UNCHANGED** | `document_repository_screen.dart:599`. |
| **L-8** Sentence-case `'Delete account'` | ⚠️ | ❌ **UNCHANGED** | Now sourced from `delete_account_title` in both JSONs, so the inconsistency is locked into the string catalogue. |
| **L-10** Docs assert six tabs | ❌ | ⚠️ **MOSTLY FIXED** | `docs/ARCHITECTURE.md` / `docs/SCREEN_MAP.md` corrected at `0f2729e`; `FEATURE_TRACKER.md:143` documents the move. Residue: `service_catalog_screen.dart:127` still says "6 tab bodies" (that one is about the Services TabBar, not the nav — re-read, it is **correct**; withdrawing this half of L-10). |
| §9.1 spelling sweep | ✅ | ✅ **STILL CLEAN** | Misspelling regex over `lib/` → zero hits. New Hindi and English copy conforms; British/Indian spelling maintained. |

---

## Localization re-measurement (like-for-like, three trees, one script)

Script: `scratchpad/l10n_measure.py`. Counts `.t('…')` call sites and user-facing string literals
(`Text('…')` plus 15 named params) in `lib/screens` + `lib/widgets`, line comments stripped,
asset paths / routes / snake_case identifiers excluded.

```
803124d: localized=198 hardcoded=1183 share=14.3% zero-loc-files=56(685 lits) keys en/hi=321/321 unused=158 wins=96
820060b: localized=198 hardcoded=1200 share=14.2% zero-loc-files=57(700 lits) keys en/hi=321/321 unused=158 wins=97
9a80fe2: localized=231 hardcoded=1185 share=16.3% zero-loc-files=56(685 lits) keys en/hi=353/353 unused=158 wins=97
```

| Metric | `803124d` | `820060b` | `9a80fe2` | Δ R2→R3 |
|---|---:|---:|---:|---:|
| Localized call sites | 198 | 198 | **231** | **+33** |
| Hardcoded user-facing literals | 1,183 | 1,200 | **1,185** | **−15** |
| Localized share | 14.3 % | 14.2 % | **16.3 %** | **+2.1 pt** |
| Files with zero `l.t()` but ≥1 literal | 56 | 57 | **56** | −1 |
| Keys in `en.json` / `hi.json` | 321/321 | 321/321 | **353/353** | **+32 / +32** |
| Unused keys | 158 | 158 | 158 | 0 |
| Unused keys whose EN value is hardcoded anyway | 96 | 97 | **97** | 0 |

*This script is a faithful reconstruction, not round 2's exact one: it reports 198/1,200 where round 2
reported 199/1,176 at the same commit. **The deltas match exactly** (round 2 measured +17 hardcoded
and 0 localized from R1→R2; so does this script: 1,183 → 1,200, 198 → 198), and the key counts match
exactly (321/321). So the series above is comparable; only the absolute denominators differ by ~2 %.*

**Key-pair verification (the brief's specific ask):**

```
new EN keys: 32   new HI keys: 32
EN-only (missing from hi): []      HI-only: []
new keys whose HI has NO Devanagari: ['delete_account_confirm_word']
new keys where HI == EN:             ['delete_account_confirm_word']
changed EN values: []   changed HI values: []
key order identical en vs hi: True
```

All 32 are referenced from `lib/` (no dead additions). All 32 Hindi values are real, natural
Devanagari — not transliteration, not English, not machine-literal. Samples:

- `delete_account_done_server` → *"अनुरोध किया गया — अभी बाकी है: Housepital के पास रखे आपके रिकॉर्ड
  हमारी टीम को हटाने हैं…"* — correct register, keeps the brand name in Latin (right call).
- `delete_account_understand` → *"मैं समझता/समझती हूँ कि इसे वापस नहीं लिया जा सकता।"* — gender-inclusive
  verb pair, which is the correct Delhi-NCR convention for a consent line. Best new Hindi string.
- `demo_banner_message` → *"नमूना जानकारी दिख रही है — अभी हम Housepital से संपर्क नहीं कर पा रहे…"*

**The one exception is a documented contradiction.** `delete_account_screen.dart:68-69` says:

> *"The word the user must type. **Localized, so a Hindi-preferring user is not asked to type a Latin
> word they may not read.**"*

`hi.json` `delete_account_confirm_word` = **`"DELETE"`**. The mechanism is localized; the value is
not. A Hindi-preferring user is still asked to type a Latin word — the comment describes an intent
the JSON does not deliver. Either set it to `हटाएँ` (the app already uses that verb at
`delete_account_delete`) or delete the sentence from the comment. Filed as **M-1** below.
*(`_canSubmit` at `:72-76` uppercases both sides, which is a no-op for Devanagari — so a Devanagari
value would work, but only with exact-match typing. Worth a test either way; there is none.)*

---

## Round-2 repairs: adversarial review

### A-1 — ❌ HIGH · The honesty landed on the wrong side of the consent tap

Every string the user reads *before* the irreversible action states server-side deletion as an
accomplished fact. The word "request" does not appear anywhere on the pre-consent screen:

| Where | String | Reads as |
|---|---|---|
| `:218` `delete_account_intro` | "Deleting your account **removes** your Housepital profile and care history." | done |
| `:226` `delete_account_removed_title` | "**What gets deleted**" | done |
| `:233` `delete_account_removed_2` | "Care history, daily reports and vitals" | done |
| `:244` `delete_account_kept_title` | "**What we must keep**" — implies everything else goes | done |
| `:304` `delete_account_cta` | "**Delete my account**" | done |
| `:175` `delete_account_confirm_title` | "**Delete your account?**" | done |
| `:176` `delete_account_confirm_body` | "This cannot be undone. Your care history, reports and saved details **will be removed**." | done |

Only at `:157`, in the dialog that appears *after* `user.delete()` and `SessionScope.clearSession`
have already run, does the app say `delete_account_done_server`: *"Requested — not yet done: your
records held by Housepital still need to be deleted by our team."*

Round 2's complaint was that the copy lied. It no longer lies **at the end**. It still misleads
**at the start**, and the start is where consent is given. The file's own header comment (`:38-39`)
frames step 4 as the honesty step — but a disclosure that arrives after the button cannot inform the
decision the button made. `delete_account_confirm_body` is the last thing the user reads before
tapping and it is the single most confident claim on the screen.

**Fix (one string, no code):** change `delete_account_intro` to name the split up front — *"This
erases everything on this phone straight away. Your records held by Housepital have to be deleted by
our team, so you will need to call us to finish it — we'll show you a reference."*

### A-2 — ⚠️ HIGH · The reference number is real, durable, and reaches nobody

The mechanism is genuinely better than round 2's `Future.delayed`, and I verified the durability
claim rather than taking it:

- `delete_account_screen.dart:78-93` writes `housepital_pending_deletion` (reference, ISO timestamp,
  patientId, `deliveredToServer: false`) **before** anything destructive (`:101-104`).
- `auth_provider.dart:231-238` — `logout()` no longer calls `prefs.clear()`; it iterates
  `prefs.getKeys()` and skips a `preserved` set containing `'housepital_pending_deletion'`. ✅
- `cache_service.dart:38-44` — `clear()` only removes its own `_prefix` keys. ✅
- `session_scope.dart:45-50` — `_patientScopedPrefsKeys` is one entry, `housepital_saved_addresses`.
  Does not touch it. ✅

So the record survives. **And then nothing happens to it:**

```
$ grep -rn "pending_deletion\|pendingDeletionKey" lib/ test/
lib/providers/auth_provider.dart:233:      'housepital_pending_deletion',      ← preserve list
lib/screens/settings/delete_account_screen.dart:60:  static const String pendingDeletionKey = …  ← declaration
lib/screens/settings/delete_account_screen.dart:84:      pendingDeletionKey,                     ← the write
```

Three hits. **Zero readers. Zero tests.** No startup replay, no retry-on-connect, no screen that
surfaces a pending request, no way to retrieve the reference after the dialog is dismissed.

That matters for the copy, which is what this checklist grades. `delete_account_done_server` says:

> *"Call 9990-911-911 with the reference below to confirm."*

- **"the reference below"** is `DEL-` + `millisecondsSinceEpoch.toRadixString(36)` (`:80-81`) —
  minted on the handset, known only to the handset. The Housepital agent who answers has no system
  in which `DEL-MJ7K2Q0` means anything. Round 2's exact sentence — *"the agent who takes that call
  will find no record"* — is still true; the record moved from nowhere to the user's own phone.
- **"to confirm"** frames the call as verification of something already in motion. It is in fact the
  **only** initiation channel. A family that skips the call because it sounds optional never has
  their records deleted, and believes they do.
- The reference is shown **once**, in a `Text` inside a barrier-dismissible-false `AlertDialog`
  (`:149-168`), to a user who has just been logged out. It is **not** `SelectableText` — contrast
  `payment_screen.dart:552`, which makes the transaction ID selectable. Dismiss the dialog and the
  string is unrecoverable through any UI.
- The whole dialog is one concatenated `Text` (`:154-159`) — four sentences and a reference joined by
  `\n\n`. VoiceOver reads it as a single undifferentiated block; there is no heading structure
  separating "Done" from "Requested — not yet done", which is the distinction the whole redesign
  exists to make.

**Does "Requested — not yet done" convey that nobody may act on it?** Partially. "Not yet done" is
honest about state. It is silent about *agency* — it never says nobody at Housepital has been told.
The phrase "our team" (`delete_account_done_server`) actively implies the opposite: a team that
"still needs to" do something sounds like a team with a queue. **Fix:** *"Nobody at Housepital has
been told yet — the app can't reach our system. Please call 9990-911-911 and quote this reference.
Write it down now; you won't be able to see it again after this screen."*

### A-3 — ✅ · The payment-pending screen itself is correct, and correct for the right reasons

Verified element by element against round 2's table:

| Element | R2 | Now | Line |
|---|---|---|---|
| Icon | `Icons.cancel` red | `Icons.schedule`, `context.hc.warning` | `:473-480` |
| Title | "Payment Failed" | `payment_pending_verification_title` = "Payment pending confirmation" / "भुगतान की पुष्टि बाकी है" | `:491-492` |
| Title colour | error | warning, with the 3:1 large-text calculation in the comment `:500-503` | `:499-504` |
| Primary CTA | "Retry Payment" | **removed**; "Contact Housepital" only, with the reason stated in code | `:611-624` |
| Secondary | "Go Back" | "Go Back" (still hardcoded English, `:631`) | `:626-633` |

The comment at `:612-613` — *"Deliberately NO retry: paying again would debit twice for the same
bill"* — is exactly the right thing to leave behind for the next editor. The title is a genuine
improvement in register too: "pending confirmation" is home-care English where "under verification"
was back-office English.

**Three residual defects on the same screen:**

1. **The body still contradicts the title, in the opposite direction.** The failure-message block
   (`:565-582`) renders on the pending path too — `!isSuccess` is true — in a `context.hc.errorLight`
   container with `context.hc.error` text (`:570,578`). So an amber "Payment pending confirmation"
   sits directly above a **red** box. The colour semantics the title fixed are re-broken 80 lines
   down.
2. **The body text inside that red box is the untranslated English** *"Payment under verification —
   we'll confirm in 24 hours"* (`payment_service.dart:180,186`) — the exact institutional-register
   string round 2 flagged, now under a localized title. A Hindi user gets a Devanagari headline and
   an English explanation. This is round 2's F-9 asymmetry surviving inside the repair for F-2.
3. **Still no reference, and still no "don't pay again".** `grep -rn "pay again" lib/` → the only hit
   is a comment about double-taxation. `payment_screen.dart:292` reads
   `_transactionId = unverified ? _transactionId : null` — but `_transactionId` is only ever assigned
   on the *success* paths (`:275,351`), so it is null here in every reachable case; and the render
   guard at `:532` is `isSuccess && _transactionId != null`, which excludes the pending branch
   regardless. **That line is dead code that looks like a fix.** The user still has nothing to quote.

### A-4 — ❌ BLOCKER · The pending CTA routes to placeholder phone numbers

`payment_screen.dart:620-621`:

```dart
// '/support' does not exist; help-faq carries the real contact numbers.
onPressed: () => Navigator.pushNamed(context, '/help-faq'),
```

The comment asserts `/help-faq` "carries the real contact numbers". It does not:

```
lib/screens/settings/help_faq_screen.dart:352:  onTap: () => _launchUrl('tel:+919999999999'),
lib/screens/settings/help_faq_screen.dart:365:  'https://wa.me/919999999999?text=Hi,%20I%20need%20help%20with%20Housepital%20app'
```

Two of the three contact affordances on that screen are placeholders (`+919999999999`); only
`mailto:wecare@housepital.in` (`:358`) is real. So the end-to-end journey is: Razorpay took ₹1,06,200
→ we could not verify it → we correctly tell the user not to retry → we send them to a screen that
dials a nine-nines number. **This is the same round-1 blocker (B-1), but round 2's repair has now
made it the terminal step of a money-loss path.** It is materially worse than it was when the
placeholder numbers merely sat in a help screen nobody had been told to open.

Adjacent: `payment_screen.dart:336-339` still says *"call us and we will take it over the phone"*
with no number anywhere on the screen (round-2 F-4, unchanged).

### A-5 — ❌ BLOCKER · The pending/failed branch is decided by an English substring of raw gateway text

`payment_screen.dart:286`:

```dart
final unverified = message.contains('under verification');
```

The entire F-2 repair hinges on a substring match against a hardcoded English literal produced two
files away (`payment_service.dart:180,186`). Consequences:

- **Localizing `payment_service`'s message silently reverts F-2.** The moment someone does the
  obviously-correct thing — replace `"Payment under verification — we'll confirm in 24 hours"` with
  a `l.t()` call, which is exactly what this checklist has been asking for for three rounds — the
  Hindi string will not contain `'under verification'`, `unverified` becomes `false`, and the user
  gets back the red `Icons.cancel`, "Payment Failed", and **Retry Payment** on a paid invoice. The
  repair is booby-trapped against its own follow-up work.
- **`_handleError` is not covered.** `payment_service.dart:220` passes `response.message` straight
  through from Razorpay. Real gateway strings (`BAD_REQUEST_ERROR`, issuer decline text,
  `payment_capture` failures) render verbatim at `payment_screen.dart:574` — round 2's F-3, entirely
  unchanged, on the one screen where a non-technical message matters most. If a gateway string ever
  happened to contain the words "under verification" the app would suppress the Retry button on a
  genuinely failed payment instead.
- There is no `test/` coverage tying the two strings together; `grep -rn "under verification" test/`
  → no match.

**Fix:** pass a typed outcome (`enum PaymentOutcome { verified, pendingVerification, failed }`) from
`PaymentService` to the screen and localize the display strings independently; map `response.code` to
a plain-language message and log `response.message`.

### A-6 — ⚠️ · The demo pill: honest copy, one-line clamp

`demo_data_banner.dart:114-128` — `Flexible` + `maxLines: 1` + `TextOverflow.ellipsis` on the only
warning in the app that says the medical data on screen is fake.

- **EN** `demo_banner_short` = *"Sample data — not your live record"* (34 chars).
- **HI** = *"नमूना जानकारी — आपका असली रिकॉर्ड नहीं"* (38 chars, ratio 1.12), rendered in
  `NotoSansDevanagari` at 12/w600 with matras adding vertical but also horizontal advance.

Available width on a 320 pt device: 320 − 24 (Positioned insets) − 24 (pill padding) − 15 (icon) − 6
(gap) ≈ **251 pt**. The Hindi string is the marginal case; at the 1.4× text-scale ceiling
(`main.dart:413-424`) both languages clip. A clipped warning still starts with "Sample data" /
"नमूना जानकारी", so the *meaning* survives truncation — this is a well-chosen front-loaded string and
the failure mode is benign. Graded ⚠️ not ❌ for that reason. **Fix:** `maxLines: 2`; the pill is an
overlay and taller is free.

**Occlusion (the brief's explicit question).** The overlay is better than the strip it replaced, but
it is not free, and the trade is worse than the commit message implies. The strip cost every screen a
fixed band of dead space — visible, uniform, and never hiding anything. The pill costs *some* screens
an unpredictable 30 pt rectangle over live content at `padding.top + kToolbarHeight + 4`
(`:44-49`), centred horizontally, which is where a first list row's title sits. On a content
checklist the relevant harm is that **the occluded text is unreadable but still announced by
VoiceOver**, so sighted and screen-reader users get different content — and there is no test
(`grep -rln "DemoDataBanner" test/` → no match). On balance: overlay > strip, because the strip's
harm was universal and this one is conditional. But "known and unfixed" understates it — it is
unmeasured. **Fix:** offset the pill to the trailing edge, or bottom-align it above the nav pill
where the `extendBody` inset already reserves space.

### A-7 — ⚠️ · The phone number moved from Dart into the string catalogue

`grep -c "9990-911-911" assets/i18n/en.json assets/i18n/hi.json` → `3` and `3`.
Round 2 asked for `AppConstants.supportPhone`; what happened instead is that two Dart literals became
six translatable ones. The digits are still correct (`== AppConstants.supportPhone == '9990911911'`),
but:

- A phone number is now **translator-editable content**. `hi.json` carries three independent copies
  of it; a transposition in one of them is a silent, un-testable defect on the screen where calling
  is the only remaining route.
- The third display format (`9990-911-911`) is now baked into the catalogue alongside the bare
  `9990911911` (`sos_screen.dart:55`) and Dai Maa's `+91-90502-00183`.
- Still not tappable. `delete_account_screen.dart` has no `url_launcher` import; the numbers render as
  plain `Text` at `:257` and inside the `AlertDialog` at `:154-159`. Every other "call" affordance in
  the app launches `tel:` (`home_screen.dart:821`, `care_team_screen.dart:381`, `sos_screen.dart:248`,
  `payment_methods_screen.dart:363`).

**Fix:** `{phone}` placeholder in the three strings, filled from `AppConstants.supportPhone` at the
call site (the file already does exactly this pattern at `:281-283` for `{word}`), and wrap the
dialog line in a `TextButton` that launches `tel:`.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Voice & tone | 0 | 2 | 1 | 0 |
| 2. Microcopy | 0 | 2 | 1 | 0 |
| 3. State copy | 0 | 2 | 2 | 0 |
| 4. Terminology consistency | 0 | 1 | 1 | 0 |
| 5. Numbers, dates, currency | 0 | 2 | 2 | 0 |
| 6. Localization / i18n | 1 | 2 | 2 | 1 |
| 7. Accessibility copy | 1 | 1 | 1 | 0 |
| 8. Store / site / legal copy | 0 | 2 | 1 | 0 |
| 9. Proofreading | 2 | 1 | 1 | 0 |
| **Total (32 items)** | **4** | **15** | **12** | **1** |

**Identical to round 2 (4 / 15 / 12 / 1), and that is the honest result.** Four items improved
materially without crossing a grade threshold — §6.1 went 14.2 % → 16.3 % (still a fail at 16 %),
§7.1 gained two proper labels but is still 27/54 IconButtons without tooltips, §8.3 lost its false
30-day promise but gained A-1's pre-consent overclaim, §1.1 lost "Payment Failed"-on-pending but
keeps the "Airtel-style" dunning, the second tagline and the banned exclamation mark. One item got
materially worse at the same grade: §9.2, where the placeholder numbers are now the destination of a
money-loss path (A-4).

Round 1, restated on the same 32 items: 3 ✅ · 16 ⚠️ · 11 ❌ · 2 N/A.

---

## Findings

### §1 Voice & tone

- ⚠️ **Copy matches brand voice.** New Hindi copy is the best writing to land in three rounds —
  `delete_account_understand` (*"मैं समझता/समझती हूँ…"*) and `delete_account_active_service_note`
  are register-correct for a Delhi-NCR family. `payment_pending_verification_title` moves from
  back-office to home-care English. Unchanged off-brand surfaces: `invoice_pdf_service.dart:250`
  second tagline; `payment_reminder_service.dart:126` "Airtel-style"; `referral_screen.dart:119`
  exclamation mark.
- ❌ **No unexplained jargon or dev terms.** Unchanged: `care_packages.dart:19,28,66,75` ("ACLS
  ambulance on call", "BiPAP", "centralised vital monitoring"); `universal_search_screen.dart:92-93`
  ("RT (Ryles Tube) Change"); `medication_models.dart:78` still returns raw `every_other_day` onto a
  dosage row. New: raw Razorpay gateway text (A-5) and `DEL-MJ7K2Q0` (A-2) are both dev artefacts
  shown to patients.
- ⚠️ **Reading level.** Deletion screen is short sentences, second person, ~Grade 8 in both languages.
  `delete_account_kept_2` (*"Anything an ongoing medical or legal matter requires"* /
  *"कोई भी जानकारी जो चल रहे चिकित्सा या कानूनी मामले के लिए ज़रूरी हो"*) remains unbounded — a family
  reads it as "they keep what they like". Rental contract unchanged and still English-only.

### §2 Microcopy

- ⚠️ **CTAs are action verbs.** "Keep my account" / "Delete" (`delete_account_keep`/`_delete`) and
  "Delete my account" (`delete_account_cta`) are correct and correctly asymmetric. Removing "Retry
  Payment" from the pending path (A-3) is the single best microcopy change this round. Still
  hardcoded and vague on the same screen: `'Go Back'` (`payment_screen.dart:631,649`), `'Retry
  Payment'` (`:640`). The 24 vague labels elsewhere (`Text('OK')` ×5, `'Yes'`/`'No'`, `'Submit'`,
  `'Done'`, `'Confirm'`) unchanged.
- ❌ **Labels consistent across screens.** See §4. Plus: the deletion dialog's OK uses the new `ok`
  key while five other screens use a hardcoded `Text('OK')`.
- ⚠️ **Confirmations state the consequence.** `delete_account_confirm_body` states irreversibility —
  better than 6 of the 7 `confirmDestructiveAction` call sites, only 1 of which does
  (`order_tracking_screen.dart:588`). But it states the *wrong* consequence: it promises removal that
  A-1 shows is only requested.

### §3 State copy

- ⚠️ **Empty states.** Unchanged: `vitals_screen.dart:216` `'No data available'`, `:262` `'No data'`;
  `paginated_list.dart:126,154,233`. `no_data_available` still in both JSONs, still uncalled.
- ⚠️ **Loading copy honest and brief.** 25 `CircularProgressIndicator` sites, 1 with copy. The
  deletion spinner (`delete_account_screen.dart:297-303`) is still bare and now covers a genuinely
  multi-step operation — a prefs write, a Firebase credential delete that hits the network, a
  seven-provider wipe, and a sign-out — with no "Erasing your data…". Longer silent window than the
  600 ms placebo it replaced.
- ❌ **Error messages non-technical and actionable.** Raw Razorpay text unchanged
  (`payment_service.dart:220` → `payment_screen.dart:574`, A-5); `raise_concern_screen.dart:410`
  still `'Failed to submit: ${e.message}'`; "call us" with no number (`payment_screen.dart:336-339`);
  the 24-hour promise still has no mechanism; and the pending body renders red under an amber title
  (A-3.1). `delete_account_failed_body` is the counter-example and is genuinely good: *"Nothing has
  been deleted. Please try again, or call us on 9990-911-911."* — states the state, gives two actions.
- ❌ **Disabled actions tell the user why.** Unchanged at 5 sites and **not fixed** in the round-2
  repair: `delete_account_screen.dart:296`. `login_screen.dart:48-60` still holds the right pattern.

### §4 Terminology consistency

- ❌ **One term per concept.** All four round-1 collisions unchanged: (a) "Health Manager" /
  "coordinator" / "Care Team"; (b) red vital = `'Alert'` vs "Needs attention" vs `'alert'`;
  (c) support numbers in four display formats, one of them Dai Maa's; (d) duplicate keys
  `todays_vitals`/`today_vitals` and `borderline`/`vital_status_borderline` with divergent Hindi.
  New: the deletion flow introduces a fifth state vocabulary — "Done" / "Pending" / "Requested — not
  yet done" — that maps onto nothing else in the app.
- ⚠️ **Capitalization consistent.** `delete_account_title` = "Delete account" (sentence case) against
  Title Case AppBars everywhere else, now locked into both JSONs. Discount chips still 3 × `% OFF`
  vs 3 × `% off`.

### §5 Numbers, dates, currency

- ⚠️ **Currency per locale.** `helpers.dart:51-54` (`en_IN`) correct and used 114×; the 8 bypasses
  unchanged, including `invoice_pdf_service.dart:69` on the tax invoice. New payment path clean
  (`payment_screen.dart:511`).
- ❌ **Dates/times locale-correct.** No `Intl.defaultLocale`, no `initializeDateFormatting`. New:
  `_recordDeletionRequest` stores `requestedAt.toIso8601String()` (`:87`) but **shows the user no
  date at all** — the dialog gives a reference and no "requested on 5 August 2026", so a family
  calling three weeks later cannot say when they asked. The round-2 complaint ("a family cannot tell
  when the window closes") is unaddressed in a different way: there is now no window and no date.
- ❌ **Pluralization.** Unchanged: `rental_agreement_screen.dart:54` `month(s)` and the other 4 sites;
  no plural facility in `AppLocalizations.translate`.
- ⚠️ **Numeric precision for money.** Unchanged.

### §6 Localization / i18n

- ❌ **No hardcoded user-facing strings.** **231 : 1,185 → 16.3 %.** First improvement in three
  rounds (+33 call sites, +32 key pairs, −15 literals), and it is real work, not bookkeeping. Still a
  fail: five sixths of the app's words are outside the catalogue, 97 keys still hold English a screen
  hardcodes anyway, and `payment_screen`'s own failure block (`'Go Back'`, `'Retry Payment'`,
  `_failureMessage`) is still English inside a screen whose title is now localized.
- ✅ **Non-Latin scripts render correctly.** Unchanged and re-confirmed: `theme.dart:156-160`
  `_devanagariFallback` applied via `fontFamilyFallback` at `ThemeData` level. The 32 new Devanagari
  values render through the same path.
- ⚠️ **Layouts tolerate expansion.** New copy measured: `payment_pending_contact_us` expands 1.39×
  (18 → 25 chars) inside a full-width button — safe. `demo_banner_short` expands 1.12× inside a
  `maxLines: 1` clamp — marginal at 320 pt (A-6). Guard still English-only.
- N/A **RTL.** `main.dart:398-401` — `[Locale('en'), Locale('hi')]`, both LTR.
- ⚠️ **Text fits at largest accessibility size.** `main.dart:413-424` still clamps to 0.85–1.4. The
  deletion screen is now the app's longest-paragraph surface in two scripts and is in no overflow
  test (F-10 unchanged); the demo pill clips at 1.4× in both languages.
- ❌ **Formatters locale-aware, not string-built.** Unchanged.

### §7 Accessibility copy

- ⚠️ **Screen-reader labels meaningful.** Two genuine fixes: `delete_account_screen.dart:281-285`
  swaps `hintText` for `labelText` with the reason in the comment (round 2's exact finding), and
  `demo_data_banner.dart:90-95,74-84` gives the pill a `liveRegion`, a full-sentence label, and a
  one-shot assertive announcement. Unchanged: 27 of 54 IconButtons without `tooltip:`. New defect:
  the deletion result dialog is one concatenated `Text` (`:154-159`) read as an undifferentiated
  block, and its reference is not `SelectableText` (A-2).
- ❌ **Images/charts have alt text.** Unchanged — `vitals_screen.dart:345` `LineChart` still has no
  `Semantics` wrapper.
- ✅ **Status conveyed by text/icon, not colour alone.** Unchanged, and the new pending state pairs
  `Icons.schedule` + "Payment pending confirmation" correctly (`payment_screen.dart:473,491`).

### §8 Store / site / legal copy

- ❌ **Store listing copy accurate and current.** `AndroidManifest.xml:7` still
  `android:label="housepital_patient"`. Listing text BLOCKED-OWNER.
- ⚠️ **"What's New" / release notes.** Unchanged. `docs/CHANGELOG.md` is engineering-facing; no
  `fastlane/metadata`.
- ⚠️ **In-app legal text reads clearly and matches behaviour.** Net improvement. *Improved:* the
  false 30-day DPDP-shaped commitment is gone; the deletion surface is fully bilingual, which makes
  it the app's **only** properly localized consent surface; `handover_report_service.dart:127-141`
  now carries a real clinical disclaimer (round-2 H-7 closed). *Still wrong:* the pre-consent copy
  claims deletion (A-1); `login_screen.dart:216,236` both "Terms" and "Privacy Policy" push `/about`;
  `rental_agreement_screen.dart:96` consent still English-only with `agree_terms` translated and
  unused.

### §9 Proofreading

- ✅ **Spelling and grammar.** Misspelling sweep over `lib/` → zero hits. New Hindi reads naturally;
  no transliteration artefacts; Devanagari punctuation (`।`) used correctly.
- ❌ **No placeholder copy shipped.** `help_faq_screen.dart:352,365` and
  `staff_otp_verification_screen.dart:352` unchanged — and now reachable as the terminal step of the
  payment-pending flow (A-4). `document_repository_screen.dart:599` "PDF upload coming soon"
  unchanged. The `TODO(backend)` is gone from `delete_account_screen.dart` (the code now does
  something), which is a real improvement.
- ⚠️ **No truncated/overflowing strings.** Guard is real (37 screens × 320/375/414, Ahem) but still
  English-only, scaler-1.0-only, and still misses `DeleteAccountScreen` and `DemoDataBannerHost`.
  A-6 identifies a clamp that will truncate in Hindi at 320 pt.
- ✅ **Brand/product name consistent.** `Housepital` used correctly in all 32 new keys, including
  inside Devanagari sentences where keeping it Latin is the right call.

---

## Blockers

**B-1 · Placeholder phone numbers still dialable — and the payment-pending CTA now routes into
them.** `payment_screen.dart:620-621` → `help_faq_screen.dart:352` (`tel:+919999999999`), `:365`
(`wa.me/919999999999`); also `staff_otp_verification_screen.dart:352` (`tel:+918888888888`). The code
comment at `payment_screen.dart:618-619` asserts the opposite. *Round-1 blocker, escalated by
round 2's own repair.* (A-4)

**B-2 · The pending/failed branch is decided by an English substring, and raw gateway text still
reaches the user.** `payment_screen.dart:286` `message.contains('under verification')` against
`payment_service.dart:180,186`; `payment_service.dart:220` passes `response.message` through to
`payment_screen.dart:574`. Localizing the service message — the obvious next task — silently restores
"Payment Failed" + Retry on a paid invoice. *Escalated from round-2 H-1.* (A-5)

**B-3 · SOS "Book Housepital Ambulance" opens a support-ticket form.** `sos_screen.dart:89-91` →
`:192-194`. *Unchanged from rounds 1 and 2.*

**B-4 · `emergencyPhone == supportPhone`, presented as two escalation paths.** `constants.dart:17,19`.
*Unchanged from rounds 1 and 2.*

**B-5 · Two contradictory vital classifiers live on one screen.** `helpers.dart` `VitalHelper`
(`vitals_screen.dart:548`) vs `vital_classifier.dart` (`vitals_screen.dart:14`,
`my_care_screen.dart:12`). *Unchanged from rounds 1 and 2.*

*Round-2 B-1 (deletion) is **downgraded to HIGH** — the false statement is gone.
Round-2 B-2 (payment result screen) is **closed at the screen**; its residue is B-1/B-2 above.*

---

## High

**H-1 · The deletion screen states server-side erasure as fact everywhere before consent.** A-1 —
`delete_account_intro`, `delete_account_removed_*`, `delete_account_cta`, `delete_account_confirm_body`.
The "Requested — not yet done" honesty appears only at `delete_account_screen.dart:157`, after the
irreversible tap. *Downgraded from round-2 blocker; one string fixes it.*

**H-2 · The deletion reference reaches nobody and cannot be retrieved.** A-2 —
`housepital_pending_deletion` has three references in the tree, all write-side; no reader, no test.
Shown once, in a non-selectable `Text`, to a just-logged-out user. Copy says "call … to confirm" when
the call is the only way to *start*.

**H-3 · Untranslated English body under a localized pending title, inside a red error box.** A-3.1/.2 —
`payment_screen.dart:565-582` renders `context.hc.errorLight`/`context.hc.error` on the pending path;
the text is `payment_service.dart:180,186`.

**H-4 · "Call us" with no number.** `payment_screen.dart:336-339`. Numbers on the deletion screen are
present but untappable (`:257`, `:154-159`). *Unchanged.*

**H-5 · Payment-reminder copy threatens care interruption.** `payment_reminder_service.dart:126,135,
149,153`. Still contradicts `home_screen.dart:1578-1580`. Still unwired. *Unchanged.*

**H-6 · Legal consent English-only — two of three surfaces remain.** `rental_agreement_screen.dart:96`,
`login_screen.dart:209-240`. *Improved: the deletion surface is now fully bilingual.*

**H-7 · A red vital says "Needs attention" and stops.** `vitals_screen.dart:846-858`. *Unchanged.*

**H-8 · Dates/times locale-blind; Hindi untested end to end.** No `Intl.defaultLocale`; zero
`Locale('hi')` in `test/`; 32 new Devanagari strings shipped with no test that renders any of them.
*Unchanged and now covering more surface.*

**H-9 · Three support numbers, one of them Dai Maa's, in four display formats.**
`constants.dart:19`, `daimaa_theme.dart:23`, `en.json`/`hi.json` × 3 each. *Worsened by A-7.*

**H-10 · Android app is named `housepital_patient` on the home screen.** `AndroidManifest.xml:7`.
*Unchanged.*

---

## Medium / Low

**M-1 — `delete_account_confirm_word` is `"DELETE"` in Hindi, under a comment claiming it is not.**
`hi.json` vs `delete_account_screen.dart:68-69`. Either translate the value or delete the claim.
**M-2 — Deletion result dialog shows no date.** `:87` stores `requestedAt`; `:154-159` shows only the
reference. A family calling later cannot say when they asked.
**M-3 — Reference is not selectable.** `:158` plain `Text` vs `payment_screen.dart:552`
`SelectableText` for the transaction ID.
**M-4 — Deletion spinner still has no copy**, over a longer real operation. `:297-303`.
**M-5 — Disabled deletion CTA gives no reason.** `:296`.
**M-6 — Phone number is now translator-editable in six places.** A-7.
**M-7 — 97 free localization wins** (was 95/96). `agree_terms`, `no_data_available`, `error_occurred`,
`retry`, `loading`, `cancel`, `medications`, `sos`.
**M-8 — Sahayak is a third language following neither locale.** `assistant_executor.dart:292,343,411`.
**M-9 — Invoice money hand-formatted.** `invoice_pdf_service.dart:69`.
**M-10 — PDFs cannot render Devanagari.** No font loaded in either PDF service — so the new clinical
disclaimer and every invoice are English-only by construction.
**M-11 — Pluralization.** `rental_agreement_screen.dart:54` + 4 sites; no plural facility.
**M-12 — Duplicate keys with divergent Hindi.** `todays_vitals`/`today_vitals`;
`borderline`/`vital_status_borderline`.
**M-13 — Raw exception text to the user.** `raise_concern_screen.dart:410`.
**M-14 — Vitals chart silent to screen readers.** `vitals_screen.dart:345`.
**M-15 — `frequencyLabel` leaks snake_case.** `medication_models.dart:78`.
**M-16 — Dead "keep the transaction id" line on the pending path.** `payment_screen.dart:292` — the
value is always null there and the render guard at `:532` excludes the branch anyway.

**L-1 — 27 of 54 IconButtons have no tooltip.**
**L-2 — `'% off'` vs `'% OFF'`** — 3 vs 3 sites.
**L-3 — 25 bare spinners, 1 with copy;** `loading` key still unused.
**L-4 — Money truncated not rounded** at ~10 `formatCurrency(x.toInt())` sites.
**L-5 — Stale contrast comment.** `theme.dart:172`.
**L-6 — `'PDF upload coming soon'`.** `document_repository_screen.dart:599`.
**L-7 — 158 unused i18n keys** (97 recoverable per M-7).
**L-8 — Sentence-case `'Delete account'`** now baked into both JSONs.
**L-9 — Demo pill clamped to one line;** Hindi is marginal at 320 pt, both languages clip at 1.4×.
`demo_data_banner.dart:118-119`.
**L-10 — `'Go Back'` / `'Retry Payment'` hardcoded** inside a screen whose title is localized.
`payment_screen.dart:631,640,649`.

*Withdrawn from round 2:* the `service_catalog_screen.dart:127` "6 tab bodies" half of L-10 — on
re-reading it refers to the Services `TabBar`, not the bottom nav, and is correct.

---

## BLOCKED-OWNER

1. **Does a deletion request reach anyone today?** *(Carried from round 2, and now the pivot of
   H-1/H-2.)* The app writes `housepital_pending_deletion` to the handset and nothing reads it.
   *Need:* confirmation of whether an ops inbox / WhatsApp / CRM receives deletion requests, and
   whether an agent can look up a `DEL-…` reference. If not, `delete_account_done_server` must say so
   explicitly and `delete_account_intro` must warn before consent.
2. **Privacy policy / Terms body text (§8.3).** Live only at `housepital.in/privacy` and `/terms`
   (`about_screen.dart:100,104`). *Need:* the published text. Lower stakes than round 2 — the in-app
   30-day commitment is gone — but the policy may still state a window the app now contradicts by
   staying silent.
3. **App Store / Play listing copy (§8.1).** No `fastlane/metadata`. *Need:* current listing text, to
   check whether it claims ambulance booking (B-3) or Hindi support (16.3 % real).
4. **"What's New" release notes (§8.2).** *Need:* owner sign-off on whether notes are drafted outside
   the repo.
5. **Hindi sign-off on the 32 new strings.** They read as competent, natural Delhi-NCR Hindi to a
   non-native reviewer, and `delete_account_understand`'s समझता/समझती pairing is the right choice.
   *Need:* a native reviewer on two specifics — whether *"अनुरोध किया गया — अभी बाकी है"* lands as
   "we have not done this yet" rather than "it is in progress", and whether `delete_account_confirm_word`
   should become `हटाएँ` (M-1).

---

## Executive summary

1. **Counts (32 items): 4 ✅ · 15 ⚠️ · 12 ❌ · 1 N/A — identical to round 2.** 5 blockers (was 6),
   10 High, 16 Medium, 10 Low.
2. **F-2 is genuinely fixed at the screen.** No red X, no "Payment Failed", no Retry button on a
   payment that likely succeeded; amber `Icons.schedule`, a localized "Payment pending confirmation",
   and a single "reach a human" CTA — with the reasoning left in the code for the next editor.
3. **F-1 is half fixed.** The 30-day lie is gone and the durable record is real: I verified
   `auth_provider.dart:231-238` preserves the key and that `CacheService.clear` and `SessionScope`
   do not touch it. That is the first non-surface repair in three rounds.
4. **But both repairs stop one step short of the user.** The deletion honesty arrives *after* the
   irreversible tap while every pre-consent string still says "removes" / "gets deleted"; and the
   payment CTA's destination dials `+919999999999`.
5. **REGRESSED:** nothing at the same grade, but §9.2 got materially worse in severity — round 1's
   placeholder phone numbers are now the terminal step of a money-loss path (A-4), which is a direct
   consequence of round 2's own repair choosing `/help-faq`.
6. **Is a round-2 repair itself a surface?** Two are partial, one is booby-trapped. The deletion
   record is real but has **zero readers** — the reference number it hands the patient is minted on
   the handset and means nothing to anyone who answers the phone (A-2). The pending-payment branch is
   decided by `message.contains('under verification')` against a hardcoded English literal, so the
   next person who localizes that string silently restores the exact defect round 2 filed (A-5).
   And `payment_screen.dart:292` is dead code shaped like a fix.
7. **Localization genuinely moved for the first time: 14.2 % → 16.3 %**, +33 call sites, **+32 key
   pairs present in both `en.json` and `hi.json`**, all 32 used, all Hindi real Devanagari and
   natural — with one exception, `delete_account_confirm_word = "DELETE"`, sitting under a comment
   that claims Hindi users are not asked to type a Latin word.
8. **The 9990-911-911 question:** no longer hardcoded in Dart — but not `AppConstants` either. It
   moved into three EN and three HI strings, so a phone number is now translator-editable, in a third
   display format, and still not tappable.
9. **Top 5 remaining:** (1) the placeholder support numbers, now on a money path; (2) the
   substring-coupled payment branch plus raw Razorpay text; (3) the pre-consent deletion overclaim;
   (4) the write-only deletion record and its meaningless reference; (5) SOS ambulance → ticket form.
10. **FAIL for release on content grounds** — but this is the first round where the direction is
    right. The three ship-today fixes are one string (`delete_account_intro`), one constant
    (`AppConstants.supportPhone` into `help_faq_screen.dart:352,365`), and one enum
    (`PaymentOutcome` instead of `message.contains`).
