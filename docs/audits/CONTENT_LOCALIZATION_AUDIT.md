# Content & Localization Checklist (App-Agnostic) — Audit round 2 vs commit `820060b`

**Date:** 2026-08-03 · **Previous round:** commit `803124d` · **Branch:** `fix/five-tab-nav`
**Scope:** read-only. No files changed. Every verdict carries `path:LINE` or a command + its output.
**Method:** `rg`/`grep`/`python3` static scans over `lib/`, `assets/i18n/`, `ios/`, `android/`, `docs/`, `test/`.
`flutter test` / `flutter build` deliberately NOT run per the brief. Round-1 numbers were re-derived
with a single script run against **both** trees (`git archive 803124d` into a scratch dir) so the
round-1 → round-2 delta is like-for-like rather than method-for-method.

---

## Changed since round 1

Ten blockers were fixed repo-wide. **Exactly one of them was mine** (B-5). Everything else I graded
❌ or ⚠️ in round 1 is unchanged, and the new code has introduced fresh content failures — including
one screen whose own doc comment claims an honesty property its code does not have.

| Round-1 finding | Status now | Evidence |
|---|---|---|
| **B-5** iOS camera/photo purpose strings missing | ✅ **FIXED — and well written** | `ios/Runner/Info.plist:73-76`. Both strings are in the voice of the two that already existed and name the real use ("photograph prescriptions, lab reports and anything you need to show your care team"). No jargon, no legalese. Best copy to land this round. |
| **B-1** Placeholder phones dialable | ❌ **UNCHANGED** | `lib/screens/settings/help_faq_screen.dart:352` `tel:+919999999999`, `:365` `wa.me/919999999999`; `lib/screens/my_care/staff_otp_verification_screen.dart:352` `tel:+918888888888` |
| **B-2** SOS "Book Housepital Ambulance" → support ticket | ❌ **UNCHANGED** | `lib/screens/sos/sos_screen.dart:89-91` title/subtitle; `:192-193` `_bookAmbulance` → `Navigator.pushNamed(context, '/raise-concern')` |
| **B-3** `emergencyPhone == supportPhone` | ❌ **UNCHANGED** | `lib/config/constants.dart:17,19` — both `'9990911911'` |
| **B-4** Two contradictory vital classifiers | ❌ **UNCHANGED** | `lib/utils/helpers.dart:7-24` (`VitalHelper`, reads `AppConstants.vitalRanges`) and `lib/utils/vital_classifier.dart` both still present and both still live in `vitals_screen.dart` |
| **H-1** "Airtel-style" dunning copy | ❌ **UNCHANGED** | `lib/services/payment_reminder_service.dart:126` comment; `:135` "Pay now to avoid service interruption."; `:153` "Late charges may apply. Pay now." |
| **H-2** Legal consent English-only | ❌ **UNCHANGED** | `rental_agreement_screen.dart:96` still hardcodes the English of the translated `agree_terms` key |
| **H-3** Handover PDF has no clinical disclaimer | ❌ **UNCHANGED** | `lib/services/handover_report_service.dart:274-277` |
| **H-4** Red vital says "Needs attention" and stops | ❌ **UNCHANGED** | `lib/screens/reports/vitals_screen.dart:846-858` `_statusRow` — `'red'` still yields only `vital_status_alert` |
| **H-5** No `Intl.defaultLocale` / `initializeDateFormatting` | ❌ **UNCHANGED** | `grep -rn "Intl.defaultLocale\|initializeDateFormatting" lib/` → **no matches** |
| **H-6** Dai Maa's number presented as "our coordinator" | ❌ **UNCHANGED** | `payment_methods_screen.dart:355,363,374`, `staff_replacement_screen.dart:227` — all `+91-90502-00183` = `daimaa_theme.dart:23` |
| **H-7** Android launcher label is `housepital_patient` | ❌ **UNCHANGED** | `android/app/src/main/AndroidManifest.xml:7` |
| **M-1** 85 free localization wins | ⚠️ **WORSE — now 95** | 160 unused keys; 95 of them hold the exact English string a screen hardcodes (was 85). None taken. |
| **M-3** Invoice money hand-formatted | ❌ **UNCHANGED** | `lib/services/invoice_pdf_service.dart:69` `'Rs ${amount.round()}'` |
| **M-4** PDFs cannot render Devanagari | ❌ **UNCHANGED** | `grep -n "Font\.\|loadFont\|theme:"` on both PDF services → **no matches** |
| **M-5** Pluralization | ❌ **UNCHANGED** | 5 `(s)` sites still present (`rental_agreement_screen.dart:54`, `service_booking_screen.dart:952,1460,2175`, `invoice_pdf_service.dart:212`) |
| **M-10** `frequencyLabel` leaks snake_case | ❌ **UNCHANGED** | `lib/models/medication_models.dart:78` `default: return frequency;` |
| **L-2** `'% off'` vs `'% OFF'` | ❌ **UNCHANGED** | 4 `% OFF` (`packages_tab.dart:83`, `package_detail_screen.dart:313`, `universal_search_screen.dart:247,496`) vs `% off` (`cart_screen.dart:813`, `equipment_detail_screen.dart:753`) |
| **L-5** Stale contrast comment in `theme.dart` | ❌ **UNCHANGED** | `lib/config/theme.dart:159` still reads "Dark ink on orange — white on orange is only ~2.3:1 (fails AA)" above a white `onPrimary` |
| §9 spelling sweep | ✅ **STILL CLEAN** | misspelling regex over all of `lib/` → **zero hits** |

### New this round — three surfaces of new user-facing copy, all of it hardcoded English

`git diff 803124d HEAD -- assets/i18n/` is **empty**. Not one key was added, in either language, for
any of the new copy below. Meanwhile hardcoded user-facing literals rose by 17.

| Metric (same script, both trees) | `803124d` | `820060b` | Δ |
|---|---:|---:|---:|
| Localized call sites in `lib/screens` + `lib/widgets` | 199 | **199** | **0** |
| Hardcoded user-facing literals | 1,159 | **1,176** | **+17** |
| Localized share | 14.7 % | **14.5 %** | **−0.2 pt** |
| Files with zero `l.t()` but ≥1 hardcoded literal | 56 (668 literals) | **57 (683)** | +1 file |
| Keys in `en.json` / `hi.json` | 321 / 321 | **321 / 321** | **0** |
| Unused keys whose EN value is hardcoded anyway | 85 | **95** | +10 |

*(Round 1 reported 1,246 hardcoded / 13.8 %; that used a slightly wider named-parameter set. The
table above is one script over both trees, so the **direction and size of the delta** is the reliable
figure. Coverage did not improve and got marginally worse.)*

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Voice & tone | 0 | 2 | 1 | 0 |
| 2. Microcopy | 0 | 2 | 1 | 0 |
| 3. State copy | 0 | 2 | **2** | 0 |
| 4. Terminology consistency | 0 | 1 | 1 | 0 |
| 5. Numbers, dates, currency | 0 | 2 | 2 | 0 |
| 6. Localization / i18n | 1 | 2 | 2 | 1 |
| 7. Accessibility copy | 1 | 1 | 1 | 0 |
| 8. Store / site / legal copy | 0 | 2 | 1 | 0 |
| 9. Proofreading | 2 | 1 | 1 | 0 |
| **Total (32 items)** | **4** | **15** | **12** | **1** |

**Round 1, restated on the same 32 items:** 3 ✅ · 16 ⚠️ · 11 ❌ · 2 N/A.
Net: **+1 ✅** (Info.plist strings, §8) and **+1 ❌** — §3.3 "error messages are non-technical and
actionable" drops from ⚠️ to ❌ because of the new payment-failure path (F-1/F-2 below).

*Two round-1 bookkeeping errors corrected here:* the round-1 table summed to 32 while labelling
itself "27 items"; and §9.2 was graded ⚠️ while the same finding was simultaneously filed as
**Blocker B-1**. Three dead phone numbers shipping is a fail, so §9.2 is ❌ this round. Neither
correction reflects a code change.

---

## New-copy review (round-2 focus)

### F-1 — ❌ BLOCKER · The deletion screen promises a deletion that nothing schedules

`lib/screens/settings/delete_account_screen.dart`

The screen's own header comment sets the honesty bar explicitly (`:17-24`):

> "It therefore does two things and says so plainly: it wipes everything on THIS DEVICE immediately,
> and **it records a deletion request for Housepital to complete** within the statutory window."

It does the first thing. **It does not do the second.** `_submitDeletionRequest` (`:53-89`) is:

```
setState(() => _isSubmitting = true);
// TODO(backend): POST /account/delete once api.housepital.in exists…
await Future<void>.delayed(const Duration(milliseconds: 600));   // :59
SessionScope.clearSession(context);
await context.read<AuthProvider>().logout();
```

No network call, no queued request, no local record, no analytics event, no email. The 600 ms delay
is a spinner, nothing more. The request is not recorded anywhere.

The user is then shown (`:72-79`):

> "Deletion requested … Your Housepital records are **scheduled for deletion** and will be removed
> **within 30 days**. We keep only what the law requires us to keep — invoices, for tax records.
> If you change your mind, **call us on 9990-911-911** before then."

Every clause after the first sentence is false or unactionable:
- **"scheduled for deletion"** — nothing was scheduled. No system anywhere knows this happened.
- **"within 30 days"** — a statutory-sounding commitment (DPDP 2023 §12) with no mechanism behind it.
- **"call us … before then"** — the user is invited to *cancel* a request that does not exist. The
  agent who takes that call will find no record, which is the worst version of this interaction: the
  family concludes Housepital lost their deletion request, or that it silently went through.
- The user is logged out immediately (`:65`), so they cannot re-open the app to check status.

This is not a missing feature — the file argues correctly (`:22-24`) that overstating erasure "would
be worse than the missing feature." **The copy does the exact thing the comment forbids.**

*What IS honest:* `'Everything on this phone has been erased.'` is substantively true. All local
persistence is SharedPreferences (`lib/services/cache_service.dart:14,23,39,47,58`) and
`AuthProvider.logout` (`lib/providers/auth_provider.dart:222-223`) calls `prefs.clear()`.
Photos previously uploaded via `firebase_service.dart:116-137` are server-side and are **not**
covered by that sentence — but the sentence is scoped to "this phone", so it holds.

**Fix (copy-only, ships today, no backend needed):** say what actually happened.
> "Everything on this phone has been erased. Your records on our servers are not deleted yet — we
> can't reach our system from the app right now. **Call 9990911911 or email wecare@housepital.in and
> ask for account deletion; we'll confirm within 30 days.** We keep invoices, which Indian tax law
> requires."

Make the phone number a `tel:` launcher, not plain text — this is now the only route the user has.

**Better fix:** persist the request locally *before* wiping (it survives, keyed outside the cleared
namespace) or fire a Firestore write, then the current copy becomes true.

### F-2 — ❌ BLOCKER · "Payment Failed" and "Payment under verification" are on screen together, above a "Retry Payment" button

`lib/screens/billing/payment_screen.dart` + `lib/services/payment_service.dart`

The result screen renders, top to bottom:

| Element | Source | Content |
|---|---|---|
| Icon | `payment_screen.dart:458-462` | `Icons.cancel`, `context.hc.error` (red) |
| Title | `:469-472` | **"Payment Failed"** |
| Amount | `:484-490` | **₹1,06,200** at 36 pt |
| Body | `:539-554` | **"Payment under verification — we'll confirm in 24 hours"** |
| CTA | `:590-591` | **"Retry Payment"** |
| CTA | `:598-600` | "Go Back" |

Three problems, in order of how much money they can cost a family:

1. **"Retry Payment" is the primary CTA on a payment that may have succeeded.** Both paths that
   produce this message (`payment_service.dart:179-181` `skippedDemo` with a real key, and `:184-187`
   `failed`) are reached *after* Razorpay reported success — the money has very likely left the
   account and only our verification is unresolved. Offering "Retry Payment" as the big filled button
   invites a second debit for the same invoice. Nothing on the screen says "do not pay again."
2. **The title contradicts the body.** "Failed" is terminal; "under verification" is pending. A
   family reads the red X and the 36 pt amount and concludes they were charged and it failed —
   the opposite of what "we'll confirm in 24 hours" means.
3. **There is no reference and no contact.** `_transactionId` is explicitly nulled on every failure
   path (`:245,280,323`), so the transaction-ID block (`:506-537`) does not render. The user has
   nothing to quote and no number to call. "We'll confirm in 24 hours" is a promise with no
   mechanism — there is no ticket, no push wiring, and `api.housepital.in` does not resolve. (24 h is
   also just `AppConstants.concernSla['medium']`, which this path never touches.)

**Fix (copy-only):** title `'Payment being confirmed'`, neutral/amber icon not red `Icons.cancel`;
body: *"Your bank may have already debited ₹X. **Please don't pay again.** We're confirming with the
bank and will update you within 24 hours — call 9990911911 with this invoice number if you need it
sooner."*; demote "Retry Payment" to an outlined secondary and promote "Call Housepital" to primary.
Show the invoice/order reference even on failure.

### F-3 — ❌ HIGH · Raw Razorpay gateway text is rendered to the user

`lib/services/payment_service.dart:220` — `_onFailureCallback?.call(response.message ?? 'Payment failed')`
flows straight into `_failureMessage` (`payment_screen.dart:281`) and onto the screen (`:548`).
Razorpay's `PaymentFailureResponse.message` carries gateway strings ("BAD_REQUEST_ERROR", issuer
decline text, `payment_capture` errors). This is the exact §3.3 defect round 1 flagged at three
sites — now reproduced on the payment screen, the one place a non-technical message matters most.
**Fix:** log `response.message`, show a mapped plain-language message keyed on `response.code`.

### F-4 — ⚠️ HIGH · "Call us" with no number; "call 9990-911-911" with no dialer

- `payment_screen.dart:325-327` — *"…please pay from the Housepital mobile app, or **call us** and we
  will take it over the phone."* No number anywhere on the screen. Dead end.
- `delete_account_screen.dart:78,181` — the number is present but is **plain `Text`**, not tappable,
  on the two screens where calling is the only remaining action. Every other "call" affordance in the
  app launches `tel:` (`home_screen.dart:821`, `care_team_screen.dart:381`, `sos_screen.dart:56`).

### F-5 — ⚠️ MEDIUM · The new copy hardcodes the phone number, in a third format

**Digits check: `9990-911-911` == `AppConstants.supportPhone` == `AppConstants.emergencyPhone` ==
`'9990911911'` (`lib/config/constants.dart:17,19`). The number is correct.** Two issues remain:

1. It is a **hardcoded literal** at `delete_account_screen.dart:78` and `:181`, not
   `AppConstants.supportPhone`. Every other reference in `lib/` goes through the constant (14 sites).
   If ops changes the number, these two survive it — on the deletion screen, where the copy has just
   told the user this is their only way back.
2. It introduces a **third display format**. The constant renders bare (`sos_screen.dart:55` →
   "Call 9990911911"); Dai Maa's renders `+91-90502-00183`; this one renders `9990-911-911`.
   **Fix:** add `AppConstants.supportPhoneDisplay = '+91 99909 11911'` and use it everywhere.

### F-6 — ⚠️ MEDIUM · The sample-data banner is honest, but a single global flag takes it down too early

`lib/screens/main_shell.dart:132-170` + `lib/data/demo_mode.dart`

**The copy is right.** *"Showing sample data — we can't reach Housepital right now, so this is not
your live record."* — plain, non-technical, states the cause and the consequence, no "offline mode"
jargon, no blame. Correctly non-dismissible (`:129-131` documents why). This is the second-best copy
to land this round. Three defects around it:

1. **`DemoMode.isServingDemoData` is one global bool, and `AppProvider` resets it unilaterally.**
   `lib/providers/app_provider.dart:247` calls `DemoMode.reset()` the moment the *dashboard* fetch
   succeeds — clearing the banner even though `MedicationProvider` (`:191,236`),
   `BillingProvider` (`:43`), `MyCareProvider` (`:50,98`) and `OrdersProvider` (`:199`) may still be
   serving `DemoData`. Partial recovery therefore removes the warning while the medication list is
   still the sample patient's. That is worse than no banner: the user has now been told the data is
   live. **Fix:** make it a `Set<String>` of provider tags; `reset(tag)` clears only its own.
2. **`BlogProvider` never marks.** `lib/providers/blog_provider.dart:38,68` fall back to
   `DemoData.articles` with no `markServingDemoData()`. Low clinical stakes (bundled education
   content is legitimately bundled), but it is the one fallback path the brief asked about that was
   missed.
3. **The banner is not a live region.** No `Semantics(liveRegion: true)`, and the
   `Icon(Icons.info_outline)` at `:149` has no `semanticLabel`. A VoiceOver user who is mid-screen
   when the banner appears is not told.

### F-7 — ⚠️ MEDIUM · The deletion screen repeats two known round-1 defects in brand-new code

- **Disabled CTA with no reason** (round-1 §3.4 ❌). `delete_account_screen.dart:218`
  `onPressed: _canSubmit ? _confirm : null` — the button is dead until both the checkbox is ticked
  *and* `DELETE` is typed, with no line saying so. `login_screen.dart:48-60` has had the right
  pattern all along.
- **Consequence disclosed after consent, not before.** The confirm dialog (`:96-99`) says "This
  cannot be undone. Your care history, reports and saved details will be removed." — good, and
  better than 6 of the 7 existing destructive dialogs. But the 30-day server window and the invoice
  retention only appear *after* the irreversible tap (`:74-78`). They are on the screen behind
  (`:164-176`), which is correct, but the dialog is the last thing the user reads.

### F-8 — ⚠️ · Voice and reading-level assessment of the new copy

Judged against *"Hospital-like expertise. Home-like care."* for a Delhi NCR family:

| Copy | Verdict |
|---|---|
| Sample-data banner (`main_shell.dart:153-154`) | **Good.** Plain, no jargon, states cause + consequence. |
| `Info.plist:74,76` purpose strings | **Good.** Names the real use, warm, no legalese. |
| "What gets deleted" bullets (`delete_account_screen.dart:152-155`) | **Good.** Concrete nouns a family recognises — "profile, address and contacts", "Medicines, reminders and documents". |
| "What we must keep" (`:170-175`) | **Mostly good.** *"Invoices and payment records, which Indian tax law requires us to retain"* — names the reason, correct register. But *"Anything an ongoing medical or legal matter requires"* is vague enough to cover anything; a family reads it as "they can keep what they like." Tighten to a bounded example. |
| *"If a service is currently running at your home, please call … first so we can close it properly"* (`:180-182`) | **Excellent.** This is the sentence that most shows the product understands its user — someone with a nurse in the house right now. |
| "Keep my account" / "Delete" dialog buttons (`:103,114`) | **Good.** Outcome verbs, not Yes/No. Correctly asymmetric. |
| "Payment Failed" (`payment_screen.dart:472`) | **Off-brand.** Title Case shout on a red screen; contradicts its own body. |
| "Payment under verification" (`payment_service.dart:180,186`) | **Institutional register.** "Under verification" is bank/back-office language, not home-care language. "We're confirming this with your bank" says the same thing in the app's voice. |
| *"Nothing has been charged — please try again in a moment"* (`payment_screen.dart:247-248`) | **Best new payment string.** Answers the only question that matters, immediately. Keep this one and model the others on it. |

**Reading level:** the deletion screen is short sentences, second person, ~Grade 8 — appropriate.
Two exceptions: "statutory" concepts survive as *"which Indian tax law requires us to retain"*
(fine) and *"Anything an ongoing medical or legal matter requires"* (abstract).

### F-9 — ❌ · What all of this means for a Hindi-preferring user

Every string in F-1 through F-8 is **hardcoded English**. `git diff 803124d HEAD -- assets/i18n/` is
empty; `delete_account_screen.dart` contains **zero** `l.t()` calls; `main_shell.dart` has `l` in
scope at `:53` and the banner three lines later does not use it.

Concretely, a user who has set the app to Hindi:

- **Deletes their account entirely in English.** The consent checkbox *"I understand this cannot be
  undone."* (`:191`), the "What we must keep" tax-retention disclosure, and the 30-day promise are
  all English. This is an irreversible action taken on the basis of text the app already knows the
  user did not choose to read. It sits alongside round-1 **H-2** (rental T&C and login consent also
  English-only) — the app now has **three** consent surfaces that ignore the user's locale.
- **Must type the Latin word `DELETE`** (`:40,196`) into the confirmation field. Defensible as a
  convention, but on an otherwise-English screen it compounds rather than stands alone.
- **Is told their payment succeeded in Hindi and failed in English.** `payment_screen.dart:470-472`:
  success uses `l.t('payment_successful')`; failure is a hardcoded `'Payment Failed'`. The locale
  holds while things go well and drops exactly when the user needs to understand what happened to
  ₹1,06,200. The same asymmetry runs through the whole failure block (`'Retry Payment'` `:591`,
  `'Go Back'` `:600`, and every `_failureMessage`).
- **Is warned that their medical data is fake, in English** (`main_shell.dart:153`). The one banner
  whose entire purpose is to stop a family trusting the wrong chart.

**Cost to fix all of it: about 25 key pairs.** The infrastructure, the guard test
(`test/utils/i18n_sync_test.dart`), and the Devanagari font fallback (`theme.dart:146-148,156`,
verified round 1 against the `cmap` tables) are all already in place and working.

### F-10 — ⚠️ · Neither new screen is covered by the overflow guard

`test/screens/overflow_smoke_test.dart` covers 37 screens; `DeleteAccountScreen` is not among them
(`grep -n "DeleteAccount\|delete_account"` → no match), and there is no widget test for it anywhere
(`grep -rln "DeleteAccountScreen" test/` → no match). It is the app's longest-paragraph screen and
its ListView contains two cards of wrapped body text plus a `CheckboxListTile` title. The suite is
also still `locale: 'en'` (`:231`) with `supportedLocales: const [Locale('en')]` (`:335`), and
`Locale('hi')` appears **zero** times in the entire test tree — so round-1 H-5 stands unchanged and
now covers more untested surface.

---

## Findings (full checklist, round 2)

### §1 Voice & tone

- ⚠️ **Copy matches brand voice consistently.** The best copy remains excellent — `empty_state.dart:4-5`
  encodes the voice rule; the 28 articles in `demo_articles.dart` are model work (chulha smoke, Delhi
  AQI, achaar/papad for BP, consistent closing disclaimer). New copy mostly upholds it (F-8). Four
  off-brand surfaces, all unchanged: `invoice_pdf_service.dart:250` ships a **second tagline**
  ("Housepital - ICU-grade care at home.") against `en.json:3`; `payment_reminder_service.dart:126`
  is still commented "Airtel-style"; `referral_screen.dart:119` still carries the banned exclamation
  mark; and new: `'Payment Failed'` (F-8).
- ❌ **No unexplained jargon or dev terms.** Unchanged: `care_packages.dart:19,28,66,75` ("ACLS
  ambulance on call", "BiPAP", "centralised vital monitoring" inside a ₹90,000/mo package);
  `universal_search_screen.dart:92-93` ("RT (Ryles Tube) Change"); `demo_data.dart:221,530`.
  Dev-term leak `medication_models.dart:78` (`default: return frequency;` → `every_other_day` on a
  dosage row) **unchanged**. New jargon: "Payment under verification" (F-8).
- ⚠️ **Reading level fits the audience.** New deletion copy is appropriate (F-8). Rental contract
  (`rental_agreement_screen.dart:74-85`) and catalog service names unchanged and still English-only.

### §2 Microcopy

- ⚠️ **CTAs are action verbs.** Dominant pattern still good, and the new "Keep my account" / "Delete"
  pair (`delete_account_screen.dart:103,114`) is a genuine improvement on the app's usual Yes/No.
  The 24 vague labels are unchanged (`Text('OK')` ×5 incl. `cart_screen.dart:663`, `'Yes'`/`'No'`
  ×2 each, `'Submit'`, `'Done'`, `'Confirm'`) and the new screen adds `'Done'`
  (`delete_account_screen.dart:84`). **"Retry Payment" is worse than vague — it is wrong** (F-2).
- ❌ **Labels consistent across screens.** See §4 — unchanged, plus a third phone format (F-5).
- ⚠️ **Confirmations state the consequence.** `confirmDestructiveAction`
  (`common_widgets.dart:501-525`) is still used at 7 sites with **only 1** stating irreversibility
  (`order_tracking_screen.dart:588`); `document_repository_screen.dart:531` still does not.
  The new deletion dialog does state it (`delete_account_screen.dart:96-99`) — but discloses the
  30-day window only afterwards (F-7).

### §3 State copy

- ⚠️ **Empty states.** Unchanged: `vitals_screen.dart:216` `'No data available'`, `:262` `'No data'`,
  `paginated_list.dart:126,154,233`. `no_data_available` still exists in both JSONs, still uncalled.
- ⚠️ **Loading copy honest and brief.** Unchanged: 24 bare `CircularProgressIndicator`s vs 1 with
  copy (`payment_screen.dart:311`). The new deletion spinner (`delete_account_screen.dart:220-225`)
  is bare — no "Erasing your data…" — during a 600 ms wait the user believes is deleting their
  medical history. On-device PDF generation still silent.
- ❌ **Error messages are non-technical and actionable.** *(⚠️ → ❌ this round.)* Round-1 leaks
  unchanged (`raise_concern_screen.dart:410`, `patient_profile_screen.dart:297`, `main.dart:768`),
  and the new payment path adds: raw Razorpay text to the user (F-3), a title that contradicts its
  body (F-2), an actionless 24-hour promise, and "call us" with no number (F-4).
- ❌ **Disabled actions tell the user why.** Unchanged at 5 sites, and **re-committed in new code** at
  `delete_account_screen.dart:218` (F-7). Correct pattern still sitting unused at
  `login_screen.dart:48-60`.

### §4 Terminology consistency

- ❌ **One term per concept.** All four round-1 collisions unchanged:
  (a) escalation contact = "Health Manager" / "coordinator" / "Care Team";
  (b) red vital = `'Alert'` (`common_widgets.dart:281`) vs `'Needs attention'` (`vital_status_alert`)
  vs `'alert'` (`helpers.dart:21`);
  (c) three support numbers, one of them Dai Maa's — **now four display formats** with F-5;
  (d) `todays_vitals`/`today_vitals` → `आज के विटल्स` vs `आज के वाइटल्स`;
  `borderline`/`vital_status_borderline` → `सीमा रेखा` vs `सीमा पर`.
- ⚠️ **Capitalization consistent.** AppBar titles uniformly Title Case; `'Delete account'`
  (`delete_account_screen.dart:128`, `settings_screen.dart:276`) is sentence case and breaks that
  pattern (`About`, `Care Guides`, `Care Team`, `EMI Options`, `Order Tracking`…). Discount chips
  still mixed: 4× `% OFF` vs 2× `% off`.

### §5 Numbers, dates, currency

- ⚠️ **Currency per locale.** `helpers.dart:51-54` (`en_IN`, lakh grouping) still correct and used
  114×; the 8 bypasses unchanged, including `invoice_pdf_service.dart:69` on the **tax invoice**.
  New code is clean — `payment_screen.dart:485` uses `DateHelper.formatCurrency`. ✅ on the new path.
- ❌ **Dates/times locale-correct.** Unchanged. No `Intl.defaultLocale`, no `initializeDateFormatting`;
  12 raw `DateFormat` calls in the care calendar; four hand-rolled month arrays; three time formats
  (chat still 24-hour at `chat_screen.dart:448-451`); `formatRelative` still has no "Yesterday".
  New: `delete_account_screen.dart:76` states "within 30 days" with no date arithmetic and no
  concrete date shown — a family cannot tell when the window closes.
- ❌ **Pluralization.** Unchanged: 5 `(s)` sites + 4 "1 weeks/months/years/days" bugs
  (`staff_profile_screen.dart:1193-1195`, `payment_reminder_service.dart:48`).
  `AppLocalizations.translate` (`app_localizations.dart:29-37`) still has no plural facility.
- ⚠️ **Numeric precision for money.** Unchanged: ~10 `formatCurrency(x.toInt())` truncation sites;
  `PaymentReminder.amount` still `double`.

### §6 Localization / i18n

- ❌ **No hardcoded user-facing strings.** **199 localized : 1,176 hardcoded → 14.5 %.** Zero new
  localized call sites and zero new keys this round while 17 new literals landed (F-9). 95 keys now
  hold the exact English a screen hardcodes. `agree_terms` still hardcoded at
  `rental_agreement_screen.dart:96`. Whole surfaces still unlocalized: 28 articles (zero Devanagari),
  Sahayak (romanized Hinglish regardless of locale), login consent, rental contract — **plus the
  three new surfaces**.
- ✅ **Non-Latin scripts render correctly.** Unchanged and re-confirmed: `Archivo.ttf` has no
  Devanagari coverage, `NotoSansDevanagari.ttf` does, and the fallback is wired at `ThemeData` level
  (`theme.dart:146-148,156`) so it applies across the whole `textTheme`. ₹ (U+20B9) in both.
- ⚠️ **Layouts tolerate expansion.** Mean HI/EN ratio 0.99, but short button labels expand up to
  2.14× (`re_book`, `pay_now`). Guard still English-only (F-10).
- N/A **RTL.** `main.dart:398-401` — `[Locale('en'), Locale('hi')]`, both LTR. Zero
  `EdgeInsetsDirectional`/`AlignmentDirectional` in `lib/` if a target is ever added.
- ⚠️ **Text fits at largest accessibility size.** `main.dart:413-424` still clamps `textScaler` to
  0.85–1.4 citing WCAG 1.4.4 (which asks 200 %). Still untested — overflow suite runs at scaler 1.0.
  The new deletion screen's dense body text is the worst new candidate for a 1.4× clip.
- ❌ **Formatters locale-aware, not string-built.** Unchanged — see §5.

### §7 Accessibility copy

- ⚠️ **Screen-reader labels meaningful.** Best examples unchanged and exemplary
  (`common_widgets.dart:319`, `billing_screen.dart:262`, `payment_screen.dart:524-525,614`).
  28 of 54 `IconButton`s still have no `tooltip:`. New: the sample-data banner is not a live region
  and its icon is unlabelled (F-6.3); the deletion screen's confirm `TextField` (`:199-208`) has a
  `hintText` but no `labelText`/`semanticLabel`, so VoiceOver reads only "DELETE, text field".
- ❌ **Images/charts have alt text.** Unchanged. The 240 px vitals `LineChart`
  (`vitals_screen.dart:345`) still has no `Semantics` wrapper. Sparkline variant still does it right
  (`vitals_trend_grid.dart:63-65`).
- ✅ **Status conveyed by text/icon, not colour alone.** Unchanged. `VitalCard`
  (`common_widgets.dart:360-376`) renders icon + text label; `helpers.dart:84-101` pairs every status
  colour with a distinct icon. The new payment result also pairs icon + title (though both are
  *wrong* about the state — F-2).

### §8 Store / site / legal copy

- ❌ **Store listing copy accurate and current.** `AndroidManifest.xml:7` still
  `android:label="housepital_patient"` — the Android home screen still shows a package slug.
  *(The iOS purpose-string half of this item is now ✅ — `Info.plist:73-76`.)* Listing text itself
  remains BLOCKED-OWNER.
- ⚠️ **"What's New" / release notes.** Unchanged. `docs/CHANGELOG.md` is engineering-facing (commit
  SHAs, `_priceMultiplier`, `check_design_consistency.sh`); no `fastlane/metadata` under `ios/` or
  `android/`.
- ⚠️ **In-app legal text reads clearly and matches behaviour.** Improved and regressed at once.
  *Improved:* `delete_account_screen.dart` is a real DPDP §12 / App Store 5.1.1(v) surface where
  there was none, correctly reachable from Settings (`settings_screen.dart:273-279`), and the
  retention disclosure names its legal basis.
  *Regressed:* that same screen makes a **30-day statutory-sounding promise with nothing behind it**
  (F-1). Unchanged: `login_screen.dart:216,236` — both "Terms" and "Privacy Policy" push `/about`;
  `handover_report_service.dart:274-277` still has no clinical disclaimer;
  `invoice_pdf_service.dart:244-246` still handles the quote case well.

### §9 Proofreading

- ✅ **Spelling and grammar.** Misspelling sweep over all of `lib/` → **zero hits**. Convention
  consistently British/Indian English (`behaviour`, `colour`, `cancelled`, `centralised`,
  `recognise`, `organis*`). New copy conforms.
- ❌ **No placeholder copy shipped.** *(⚠️ → ❌; see scorecard note.)* Three placeholder phone numbers
  still dialable — `help_faq_screen.dart:352,365`, `staff_otp_verification_screen.dart:352`, the last
  still carrying its own admission on `:351` ("Support number to be updated with production contact
  details"). `document_repository_screen.dart:599` still ships "PDF upload coming soon". And a new
  `TODO(backend)` at `delete_account_screen.dart:56` gates a promise the copy makes anyway (F-1).
- ⚠️ **No truncated/overflowing strings on smallest viewport.** Guard is real (37 screens ×
  320/375/414, Ahem) but still English-only, scaler-1.0-only, and now misses both new screens (F-10).
- ✅ **Brand/product name consistent.** 740 `Housepital`; 7 `HOUSEPITAL` all deliberate wordmarks;
  37 lowercase all technical identifiers. New copy uses `Housepital` correctly throughout.
  *(Android launcher label filed under §8 as store metadata.)*

---

## Blockers

**B-1 · Deletion screen promises a 30-day erasure that nothing records.** F-1 —
`delete_account_screen.dart:53-89` (no persistence), copy at `:72-79`. The file's own comment
(`:17-24`) forbids exactly this. **New this round.**

**B-2 · "Payment Failed" + "under verification" + "Retry Payment" on one screen.** F-2 —
`payment_screen.dart:469-472,539-554,590-591`, `payment_service.dart:179-187`. Invites a double
debit on a payment that likely succeeded. **New this round.**

**B-3 · Placeholder phone numbers still dialable.** `help_faq_screen.dart:352,365`,
`staff_otp_verification_screen.dart:352`. *Unchanged from round 1.*

**B-4 · SOS "Book Housepital Ambulance" opens a support-ticket form.**
`sos_screen.dart:89-91` → `:192-193`. *Unchanged from round 1.*

**B-5 · `emergencyPhone == supportPhone`, presented as two escalation paths.**
`constants.dart:17,19`; `sos_screen.dart:51-67`. *Unchanged from round 1.*

**B-6 · Two contradictory vital classifiers on one screen.** `helpers.dart:7-24` vs
`vital_classifier.dart:24-76`; both live in `vitals_screen.dart:548,696`. SpO₂ 91 → *borderline* in
one, *red* in the other. *Unchanged from round 1.*

---

## High

**H-1 · Raw Razorpay gateway text rendered to the user.** F-3 — `payment_service.dart:220` →
`payment_screen.dart:281,548`. **New.**

**H-2 · Every new user-facing string is hardcoded English; zero new i18n keys.** F-9 — deletion
consent, tax-retention disclosure, sample-data warning and payment-failure copy. The success message
is localized and the failure message is not (`payment_screen.dart:470-472`). **New.**

**H-3 · Sample-data banner is cleared globally by one provider's recovery.** F-6.1 —
`app_provider.dart:247`. The banner comes down while other providers still serve `DemoData`. **New.**

**H-4 · "Call us" with no number, and untappable numbers.** F-4 — `payment_screen.dart:325-327`;
`delete_account_screen.dart:78,181`. **New.**

**H-5 · Payment-reminder copy threatens care interruption.** `payment_reminder_service.dart:126,135,
143,149,153` — still commented "Airtel-style", still contradicts `home_screen.dart:1578-1580` ("Your
care continues uninterrupted."). Still unwired (latent, not live). *Unchanged.*

**H-6 · Legal consent presented only in English — now three surfaces.**
`rental_agreement_screen.dart:96` (with `agree_terms` translated and unused),
`login_screen.dart:209-240`, and now `delete_account_screen.dart` in full. *Worsened.*

**H-7 · Doctor handover PDF carries no clinical disclaimer.**
`handover_report_service.dart:274-277`. *Unchanged.*

**H-8 · A red vital says "Needs attention" and stops.** `vitals_screen.dart:846-858`. *Unchanged.*

**H-9 · Dates/times locale-blind; Hindi untested end to end.** No `Intl.defaultLocale`; four
hand-rolled month arrays; three time formats; zero `Locale('hi')` in `test/`. *Unchanged.*

**H-10 · Three support numbers, one of them Dai Maa's.** `constants.dart:19` vs
`daimaa_theme.dart:23` presented as "our coordinator" at `payment_methods_screen.dart:355,363,374`
and `staff_replacement_screen.dart:227`. *Unchanged.*

**H-11 · Android app is named `housepital_patient` on the home screen.**
`AndroidManifest.xml:7`. *Unchanged.*

---

## Medium / Low

**M-1 — 95 one-line localization wins already paid for** (was 85). `agree_terms`, `error_occurred`,
`no_data_available`, `tagline`, `cancel` (6 files), `retry`, `medications`, `sos`, `loading`.
**M-2 — Sahayak is a third language following neither locale.** `assistant_executor.dart:292,343,411`,
`assistant_service.dart:95-181`; breadcrumbs cite English menu labels absent in Hindi mode.
**M-3 — Invoice money hand-formatted.** `invoice_pdf_service.dart:69` → `Rs 106200`, on line items,
subtotal, GST and grand total (`:217,230,233,236`).
**M-4 — PDFs cannot render Devanagari.** No font loaded in either PDF service.
**M-5 — Pluralization.** 5 `(s)` sites + 4 "1 weeks/months/years/days" bugs; no plural facility in
`AppLocalizations`.
**M-6 — Duplicate keys with divergent Hindi.** `todays_vitals`/`today_vitals`;
`borderline`/`vital_status_borderline`.
**M-7 — Raw exception text to the user.** `raise_concern_screen.dart:410`,
`patient_profile_screen.dart:297`, `main.dart:768`, plus F-3.
**M-8 — Vitals chart silent to screen readers.** `vitals_screen.dart:345`.
**M-9 — Disabled CTAs give no reason.** 5 sites + `delete_account_screen.dart:218` (**new**).
**M-10 — `frequencyLabel` leaks snake_case.** `medication_models.dart:78`.
**M-11 — Phone number hardcoded in new copy, in a third display format.** F-5 —
`delete_account_screen.dart:78,181`. **New.**
**M-12 — `BlogProvider` demo fallback never marks demo mode.** `blog_provider.dart:38,68`. **New.**
**M-13 — Deletion spinner has no copy** during a wait the user believes is erasing medical history.
`delete_account_screen.dart:220-225`. **New.**

**L-1 — 28 of 54 IconButtons have no tooltip.**
**L-2 — `'% off'` vs `'% OFF'`** — 4 vs 2 sites.
**L-3 — 24 bare spinners, 1 with copy;** `loading` key still unused.
**L-4 — Money truncated not rounded** at ~10 `formatCurrency(x.toInt())` sites.
**L-5 — Stale contrast comment.** `theme.dart:159` still contradicts the owner's white-on-orange
decision, directly above `onPrimary: HousepitalColors.onOrange`.
**L-6 — `'PDF upload coming soon'`** at `document_repository_screen.dart:599`.
**L-7 — 160 unused i18n keys** (95 recoverable per M-1).
**L-8 — Sentence-case `'Delete account'`** breaks the Title Case AppBar convention.
**L-9 — Sample-data banner not a live region**, icon unlabelled. `main_shell.dart:141-160`. **New.**
**L-10 — Stale docs assert six tabs / a Calendar tab.** `docs/ARCHITECTURE.md:68`,
`docs/SCREEN_MAP.md:6` (and its `:10`, `:15`, `:73-77` sections). Both still live and both false —
`test/screens/main_shell_test.dart:228` asserts five tabs and no Calendar tab. Also
`lib/screens/services/service_catalog_screen.dart:127` says "6 tab bodies".

---

## BLOCKED-OWNER

1. **App Store / Play listing copy (§8.1).** No `fastlane/metadata`, no listing text in the repo.
   *Need:* current App Store Connect and Play Console text (description, subtitle, keywords,
   screenshot captions) to check against shipped behaviour — specifically whether it claims ambulance
   booking (B-4) or Hindi support (14.5 % real).
2. **Privacy policy / Terms body text (§8.3).** Live only at `housepital.in/privacy` and `/terms`
   (`about_screen.dart:100,104`). *Need:* the published text — and this round it matters more, because
   `delete_account_screen.dart` now makes a **30-day erasure commitment in-app** (F-1). If the policy
   states a different window, or states one at all, they must agree.
3. **Does a deletion request reach anyone today? (F-1).** *Need:* owner confirmation of whether any
   out-of-band process (ops inbox, WhatsApp, CRM) receives deletion requests. If not, the copy must be
   rewritten before release; if yes, the copy must name that route.
4. **"What's New" release notes (§8.2).** *Need:* owner sign-off on whether user-facing notes are
   drafted outside the repo.
5. **Hindi copy sign-off.** `hi.json` reads as competent, natural Hindi (315/321 values carry real
   Devanagari; the 6 identical-to-English are legitimate acronyms). *Need:* a native Delhi-NCR
   reviewer on register — the clinical terms (`वाइटल्स`, `सीमा रेखा`, `खुराक`) and whether the
   आप-form is right for a caregiver addressing a parent's care.

---

## Verdict

**FAIL for release on content grounds.** Six blockers, four of them carried unchanged from round 1
and two newly introduced by this round's own fixes.
