# Content & Localization — Audit round 4 · Suite v2.0 · commit `9127713`

**Date:** 2026-08-03 · **Auditor:** Content & Localization module · **Scope:** source review (see Limitations)
**Branch:** `fix/five-tab-nav` · **Round 3:** `9a80fe2` · **Round 2:** `820060b` · **Round 1:** `803124d`
**Checklist:** Content & Localization (App-Agnostic), control family L10N, Suite v2.0 — 48 controls across §1–§12.

---

## Applicability

Applies in full. The product ships user-facing prose on every surface, declares **two**
locales (`main.dart` `supportedLocales: [Locale('en'), Locale('hi')]`) with a real
translation catalogue (`assets/i18n/en.json`, `hi.json`, 353 keys each), and distributes to
a market — Delhi NCR — where Hindi is the majority language of the intended user (a family
member managing home healthcare for an elderly or oncology patient). §6 and §10–§12
therefore apply as written, not conditionally.

The health context raises the stakes on §1–§3 specifically: this app's words tell a family
what a blood-oxygen reading means, whether an ambulance is coming, and whether their
medical records have been erased. Copy defects here are not polish defects.

§11.05 (bidi) and §6.04 (RTL) are the only genuine N/A controls — both declared locales are
LTR.

---

## Headline

**Round 3 filed two blockers. Both are genuinely fixed, and this time the fix is neither a
surface nor a half-wire — it is a real, complete repair.** That is the first time in four
rounds I can write that sentence without a caveat attached.

**And nothing else in this module moved at all.** Localization is flat to the digit:
identical call-site count, identical literal count, identical key count, zero lines changed
in either `i18n` JSON between `9a80fe2` and `9127713`. The pattern round 4 fits is neither
"surfaces" nor "half-wires" — it is **narrow and correct**: the two named defects were
repaired properly and the module's twenty other open findings were not touched.

Two things are materially worse than round 3 knew:

1. **The deletion copy is now provably false, not merely early.** Round 3 graded it "the
   honesty landed on the wrong side of the consent tap". Parallel round-4 modules
   established — and I verified independently — that there is **no re-authentication path
   anywhere in `lib/`**, so `user.delete()` fails for any session older than ~5 minutes,
   and the deletion request reaches nobody. The account is not deleted; signing in again
   restores it. Against that reality the screen requires the user to tick **"I understand
   this cannot be undone."** It can be undone. The app makes the user affirm a false
   statement as a precondition of proceeding.

2. **This round's vitals fix created a new content defect on the clinical screen.** The
   sample-vs-real transition it introduces is explained to the user **nowhere** — all of the
   honesty lives in Dart doc comments. Saving one blood-sugar reading silently blanks four
   other vital charts that a second earlier showed 180 days of trend.

One claim circulating from other round-4 modules is **wrong and is corrected here**: it is not
true that the app has zero medical disclaimers. A good one exists and closes 28 article
bodies. The real finding is that it appears on every surface where the user *reads* and none
where the user *acts* — vitals, medications, SOS, the handover PDF, the assistant. See MED-1.

---

## Round-3 findings: status now

| Round-3 finding | Status now | Evidence |
|---|---|---|
| **B-1** Placeholder phones dialable; payment-pending CTA routes into them | ✅ **FIXED — completely** | All three sites now use the constant. `help_faq_screen.dart:357` `tel:+91${AppConstants.supportPhone}`; `:370-371` `wa.me/91${AppConstants.supportPhone}`; `staff_otp_verification_screen.dart:354` `tel:+91${AppConstants.supportPhone}`. `AppConstants.supportPhone = '9990911911'` (`constants.dart:19`). **Repo-wide sweep for `9999999999`/`8888888888` over `*.dart *.json *.xml *.yaml *.plist` in `lib/`, `android/`, `ios/`, `assets/` → zero hits.** Remaining hits are test fixtures (`test/providers/my_care_provider_test.dart:29`) and prior audit prose. The comment at `payment_screen.dart:618-619` ("help-faq carries the real contact numbers") is now **true**. |
| **B-2** Pending/failed branch decided by English substring | ✅ **FIXED — properly typed** | `payment_service.dart:246-259` `enum PaymentFailure { notStarted, declined, unverified }`; callback signature `:105` `void Function(String message, PaymentFailure kind)`; raised at `:147` (notStarted), `:182`/`:189` (unverified), `:224` (declined). Consumed at `payment_screen.dart:288` `final unverified = kind == PaymentFailure.unverified;`. `grep -rn "contains('under verification')" lib/` → **zero hits.** The enum doc comment `:239-245` records exactly why. Retry is now offered only on `notStarted`/`declined`, both of which are money-safe. |
| **B-2 (second half)** Raw Razorpay `response.message` rendered verbatim | ❌ **UNCHANGED** | `payment_service.dart:223-224` `_onFailureCallback?.call(response.message ?? 'Payment failed', PaymentFailure.declined)` → `payment_screen.dart:296` `_failureMessage = message` → rendered at `:573-578`. Gateway strings (`BAD_REQUEST_ERROR`, issuer decline text) still reach the patient verbatim. |
| **B-3** SOS "Book Housepital Ambulance" opens a support-ticket form | ❌ **UNCHANGED** | `sos_screen.dart:88-89` `title: 'Book Housepital Ambulance'`, `subtitle: 'Request ACLS ambulance dispatch'` → `:192-194` `_bookAmbulance` → `Navigator.pushNamed(context, '/raise-concern')`. Both strings hardcoded English. |
| **B-4** `emergencyPhone == supportPhone`, presented as two escalation paths | ❌ **UNCHANGED** | `constants.dart:17` `emergencyPhone = '9990911911'`; `:19` `supportPhone = '9990911911'`. Rendered as two distinct rows at `sos_screen.dart:55-56` and `:66`. |
| **B-5** Two contradictory vital classifiers | ❌ **UNCHANGED — and now demonstrably contradictory on one screen** | See §Medical-safety copy, MED-2. `vitals_screen.dart:568` uses `VitalHelper.getVitalStatus` (`helpers.dart:19-24` → `AppConstants.vitalRanges`); `vitals_screen.dart:716` uses `classifyVital` (`vital_classifier.dart`). |
| **H-1** Pre-consent copy states server-side erasure as fact | ❌ **UNCHANGED — and escalated to a blocker** | No `delete_account_*` string changed (`git diff 9a80fe2 9127713 -- assets/i18n/` is empty). Now judged against the account-not-deleted reality: see §Deletion copy. |
| **H-2** Deletion reference reaches nobody; cannot be retrieved | ❌ **UNCHANGED** | `grep -rn "pending_deletion\|pendingDeletionKey" lib/ test/` → 3 hits, all write-side (`auth_provider.dart:233` preserve-list, `delete_account_screen.dart:60` declaration, `:84` the write). Zero readers, zero tests. |
| **H-3** Untranslated English body under a localized pending title, in a red box | ❌ **UNCHANGED** | `payment_screen.dart:572-579` renders `_failureMessage` in a `context.hc.errorLight` container with `context.hc.error` text on the pending path (`!isSuccess` is true). Text is `payment_service.dart:181,188` `"Payment under verification — we'll confirm in 24 hours"` — still a hardcoded English literal. Amber title (`:499-504`), red body 80 lines down. |
| **H-4** "Call us" with no number | ❌ **UNCHANGED** | `payment_screen.dart:336-339` — *"call us and we will take it over the phone"*, no number on the screen. |
| **H-5** Payment-reminder copy threatens care interruption | ❌ **UNCHANGED** | `payment_reminder_service.dart:126` "Airtel-style" comment; `:135` "Pay now to avoid service interruption."; `:153` "Late charges may apply. Pay now." |
| **H-6** Legal consent English-only — 2 of 3 surfaces | ❌ **UNCHANGED** | `rental_agreement_screen.dart:95-96` `const Text('I agree to the rental terms and conditions')` while `agree_terms` sits translated and unused; `login_screen.dart:212-240` unchanged, both "Terms" (`:216-218`) and "Privacy Policy" (`:236`) push `/about`. |
| **H-7** A red vital says "Needs attention" and stops | ❌ **UNCHANGED** | `vitals_screen.dart:866-872` — `status == 'red'` → `label = l.t('vital_status_alert')` = "Needs attention" / "ध्यान देने की ज़रूरत". No action, no threshold, no number to call. |
| **H-8** Dates locale-blind; Hindi untested end to end | ❌ **UNCHANGED** | `grep -rn "Intl.defaultLocale\|initializeDateFormatting" lib/` → zero. `grep -rn "Locale('hi')" test/` → **zero**. 353 Hindi strings ship with no test that renders one. |
| **H-9** Three support numbers in four display formats | ⚠️ **IMPROVED, not closed** | The Dart-side placeholder formats are gone (B-1). Still live: `constants.dart:19` `9990911911`; `en.json`/`hi.json` × 3 each as `9990-911-911`; `daimaa_theme.dart:23` `+91-90502-00183` surfaced as "our coordinator" at `payment_methods_screen.dart:355,363,374`. |
| **H-10** Android launcher label is `housepital_patient` | ❌ **UNCHANGED** | `android/app/src/main/AndroidManifest.xml:7` `android:label="housepital_patient"`. (`ios/Runner/Info.plist:10` `CFBundleDisplayName` = "Housepital Patient" — correct; `:18` `CFBundleName` = `housepital_patient`.) |
| **M-1** `delete_account_confirm_word` = "DELETE" in Hindi under a comment claiming otherwise | ❌ **UNCHANGED — verbatim** | `assets/i18n/hi.json:339` `"delete_account_confirm_word": "DELETE"` (identical to `en.json:339`). Comment unchanged at `delete_account_screen.dart:68-69`: *"The word the user must type. Localized, so a Hindi-preferring user is not asked to type a Latin word they may not read."* See L10N-11.04 for the compounding defect. |
| **M-2/3/4/5** Deletion dialog: no date, non-selectable reference, bare spinner, unexplained disabled CTA | ❌ **ALL UNCHANGED** | `delete_account_screen.dart:87` stores `requestedAt`, `:154-159` shows only the reference in a plain concatenated `Text`; `:296` `onPressed: canSubmit ? … : null`; `:297-303` bare `CircularProgressIndicator`. |
| **M-9** Invoice money hand-formatted | ❌ **UNCHANGED** | `invoice_pdf_service.dart:69` `String _fmtAmount(num amount) => 'Rs ${amount.round()}';` |
| **M-10** PDFs cannot render Devanagari | ❌ **UNCHANGED** | No font load in either PDF service. |
| **M-11** Pluralization | ❌ **UNCHANGED** | `rental_agreement_screen.dart:54` `'${widget.durationMonths} month(s)'`; `service_booking_screen.dart:952,1460` `'name(s)'`; `:2175` `'file(s)'`; `invoice_pdf_service.dart:212` `'$months month(s)'`. |
| **M-12** Duplicate keys with divergent Hindi | ❌ **UNCHANGED** | `todays_vitals` = "आज के विटल्स" vs `today_vitals` = "आज के वाइटल्स"; `borderline` = "सीमा रेखा" vs `vital_status_borderline` = "सीमा पर". |
| **M-15** `frequencyLabel` leaks snake_case | ❌ **UNCHANGED** | `medication_models.dart:78` `default: return frequency;` |
| **M-16** Dead "keep the transaction id" line on the pending path | ❌ **UNCHANGED** | `payment_screen.dart:294` `_transactionId = unverified ? _transactionId : null;` — `_transactionId` is assigned only on success paths, and the render guard `:531` is `isSuccess && _transactionId != null`. Still code shaped like a fix. |
| **L-2** `'% off'` vs `'% OFF'` | ❌ **UNCHANGED** | 4 × `% OFF` (`universal_search_screen.dart:247,496`, `package_detail_screen.dart:313`, `packages_tab.dart:83`) vs 4 × `% off` (`cart_screen.dart:813`, `equipment_detail_screen.dart:753`, `equipment_item_card.dart:151`, `service_booking_screen.dart:282`). |
| **L-5** Stale contrast comment in `theme.dart` | ✅ **FIXED** | Corrected in `9127713` (`git diff 9a80fe2 9127713 -- lib/config/theme.dart lib/config/app_colors.dart`). Out of this module's scope but verified as claimed. |
| **L-6** `'PDF upload coming soon'` | ❌ **UNCHANGED** | `document_repository_screen.dart:599`. |
| **L-7** 158 unused i18n keys | ❌ **UNCHANGED** | Script output below — 158 at all four commits. |
| **L-10** `'Go Back'` / `'Retry Payment'` hardcoded inside a localized screen | ❌ **UNCHANGED** | `payment_screen.dart:630`, `:639`, `:648`. |
| §9.1 spelling sweep | ✅ **STILL CLEAN** | Misspelling regex over `lib/` → zero hits. |

**Summary of movement:** 3 fixed (B-1, B-2, L-5), 1 partially improved (H-9), **24 unchanged**,
0 regressed structurally — but 2 re-graded harder on new evidence (H-1 → blocker; §3.01 →
Fail) and 1 new defect introduced (VIT-1, below).

---

## Round-4 focus item 1 — Are the two claimed fixes real?

### 1a · `AppConstants.supportPhone` is what is actually dialled — **verified, Pass**

Round 3 counted three placeholder numbers. I checked all three and swept for more.

```
$ grep -rn "9999999999\|8888888888\|9876543210\|1234567890\|0000000000" \
    --include="*.dart" --include="*.json" --include="*.xml" \
    --include="*.yaml" --include="*.plist" . | grep -v "^./docs/audits/"
   → only test/ fixtures and docs/TROUBLESHOOTING.md:109 (Firebase test-number setup)
```

Zero placeholder numbers remain in any shipped path. The three former sites:

| Site | Round 3 | Now |
|---|---|---|
| `help_faq_screen.dart` Call | `tel:+919999999999` | `:357` `_launchUrl('tel:+91${AppConstants.supportPhone}')` |
| `help_faq_screen.dart` WhatsApp | `wa.me/919999999999` | `:370-371` `'https://wa.me/91${AppConstants.supportPhone}?text=…'` |
| `staff_otp_verification_screen.dart` Call Support | `tel:+918888888888` | `:354` `Uri.parse('tel:+91${AppConstants.supportPhone}')` |

`AppConstants.supportPhone` resolves to `'9990911911'` (`constants.dart:19`), so the dialled
string is `tel:+919990911911` — the real Housepital number. **The constant is not merely
imported; it is interpolated into the URI that `launchUrl` receives.** The comments left
behind (`help_faq_screen.dart:353-355`, `staff_otp_verification_screen.dart:352-353`) name
the old placeholder and the reason, which is the right artefact to leave.

The end-to-end money-loss journey round 3 traced now terminates on a real number:
`payment_screen.dart:620` → `/help-faq` → `:357` → `+919990911911`. **Round 3's B-1 is
closed.**

*Residual (Warning, not Fail):* `staff_otp_verification_screen.dart:352` still carries
`// NOTE: Support number to be updated with production contact details.` — a stale TODO
above a line that now uses the production constant. Cosmetic, but it will mislead the next
editor into thinking the number is still fake.

### 1b · The pending-vs-failed branch is typed — **verified, Pass**

```
$ grep -rn "under verification" lib/
lib/services/payment_service.dart:181:  "Payment under verification — we'll confirm in 24 hours",
lib/services/payment_service.dart:188:  "Payment under verification — we'll confirm in 24 hours",
$ grep -rn "contains('under verification')" lib/
   → no matches
```

The string is now **only** a display payload; no control flow reads it. The branch is
`payment_screen.dart:288` `final unverified = kind == PaymentFailure.unverified;`, fed by
the typed enum. Round 3's booby-trap — *"localizing that message silently restores Retry on
a paid invoice"* — is disarmed: translating `payment_service.dart:181,188` now changes only
what the user reads.

I checked the enum is exhaustive against the money-safety rule it exists to enforce:

| `PaymentFailure` | Raised at | Money moved? | Retry offered? | Correct? |
|---|---|---|---|---|
| `notStarted` | `:147` (gateway would not open) | No | Yes (`payment_screen.dart:645`) | ✅ |
| `declined` | `:224` (`_handleError`) | No | Yes | ✅ |
| `unverified` | `:182` (`skippedDemo` with a real key), `:189` (`failed`) | **Probably yes** | **No** — `:611-624` "Contact Housepital" only | ✅ |

The doc comment at `payment_service.dart:239-259` records the history and the invariant
("NEVER offer a retry here"). This is the highest-quality repair this module has seen in
four rounds.

*But the repair is still untested for the property that matters.* `grep -rn "PaymentFailure"
test/` → no matches. Nothing asserts that `unverified` suppresses Retry. The invariant is
documented in prose and enforced by one `if`.

*And the two residual defects on that screen are unchanged:* the body renders the raw
gateway/English string in a **red** `errorLight` box under the **amber** pending title
(`payment_screen.dart:572-579` vs `:499-504`), and `'Go Back'`/`'Retry Payment'` are still
hardcoded English inside a localized screen.

---

## Round-4 focus item 2 — Localization re-measurement, like-for-like, four commits

Round 3's script (`scratchpad/l10n_measure.py`) is not in the repository and not recoverable
from any ref. I reconstructed it from round 3's stated method — count `.t('…')` call sites
and user-facing literals (`Text('…')` plus 15 named params) across `lib/screens` +
`lib/widgets`, line comments stripped, asset paths / routes / snake_case identifiers
excluded — and ran the same script over all four trees exported with `git archive`.

Script: `<scratchpad>/l10n_measure.py`. Trees: `<scratchpad>/l10n_trees/{r1,r2,r3,r4}`.

```
803124d: localized=198 hardcoded=1222 share=13.9% zero-loc-files=57(724 lits) keys en/hi=321/321 unused=158 wins=48
820060b: localized=198 hardcoded=1239 share=13.8% zero-loc-files=58(739 lits) keys en/hi=321/321 unused=158 wins=48
9a80fe2: localized=231 hardcoded=1223 share=15.9% zero-loc-files=57(724 lits) keys en/hi=353/353 unused=158 wins=48
9127713: localized=231 hardcoded=1223 share=15.9% zero-loc-files=57(724 lits) keys en/hi=353/353 unused=158 wins=48
```

**Calibration against round 3 (honest disclosure).** My reconstruction reproduces round 3's
`localized` series **exactly** (198 / 198 / 231), its key counts **exactly** (321/321 →
353/353), and its unused-key count **exactly** (158). My `hardcoded` denominator runs ~39
higher at every commit (1,223 vs 1,185 at `9a80fe2`) — round 3 disclosed the same ~2 %
denominator drift against round 2. **The deltas agree**: round 3 measured R1→R2 as +17
hardcoded / +0 localized; I measure +17 / +0. Round 3 measured R2→R3 as −15 / +33; I measure
−16 / +33. My `wins` sub-metric (48) diverges from round 3's (97) because I require an exact
value match; I report my own number rather than claim theirs.

| Metric | `803124d` R1 | `820060b` R2 | `9a80fe2` R3 | `9127713` R4 | **Δ R3→R4** |
|---|---:|---:|---:|---:|---:|
| Localized call sites | 198 | 198 | 231 | **231** | **0** |
| Hardcoded user-facing literals | 1,222 | 1,239 | 1,223 | **1,223** | **0** |
| **Localized share** | 13.9 % | 13.8 % | 15.9 % | **15.9 %** | **0.0 pt** |
| Files with zero `l.t()` but ≥1 literal | 57 | 58 | 57 | **57** | 0 |
| Keys `en.json` / `hi.json` | 321/321 | 321/321 | 353/353 | **353/353** | **0 / 0** |
| Unused keys | 158 | 158 | 158 | **158** | 0 |
| Unused keys whose EN value a screen hardcodes | 48 | 48 | 48 | **48** | 0 |

**Corroboration independent of the script:**

```
$ git diff --stat 9a80fe2 9127713 -- assets/i18n/
   (empty — not one byte changed in either catalogue)
$ git diff 9a80fe2 9127713 -- lib/ | grep -c "^+.*\.t("   → 0
$ git diff 9a80fe2 9127713 -- lib/ | grep -c "^-.*\.t("   → 0
```

### The trend, stated plainly

**Localization moved once, in round 3, and then stopped.** R1 → R2 was flat and slightly
negative (13.9 % → 13.8 %; +17 literals, no new keys). R2 → R3 was the one real advance
(+2.1 pt, +33 call sites, +32 key pairs — the deletion and demo-banner surfaces). **R3 → R4
is zero on every metric**, to the digit, with a null diff on both JSON files.

At 15.9 %, **five sixths of the words this app shows a user are outside the catalogue.** The
concentration is severe and unchanged: the top three files alone hold 269 hardcoded literals
against 4 localized call sites.

| File | hardcoded | localized |
|---|---:|---:|
| `lib/screens/services/assessment_request_screen.dart` | 124 | 2 |
| `lib/screens/services/service_booking_screen.dart` | 84 | 0 |
| `lib/screens/settings/patient_profile_screen.dart` | 61 | 2 |
| `lib/screens/home/home_screen.dart` | 56 | 1 |
| `lib/screens/services/data/catalog_seeds.dart` | 46 | 0 |
| `lib/screens/services/equipment_detail_screen.dart` | 45 | 0 |
| `lib/screens/documents/document_repository_screen.dart` | 40 | 0 |
| `lib/screens/calendar/care_calendar_screen.dart` | 40 | 0 |

Shipping a Hindi locale selector against a 15.9 % catalogue means a Hindi-preferring user
gets a Devanagari app bar over an English screen body on 57 of the app's screens. That is
the substance of L10N-6.01 and it is unchanged.

**48 of the 158 unused keys hold the exact English that a screen hardcodes anyway** —
`agree_terms`, `no_data_available`, `confirm`, `add_to_cart`, `go_to_cart`, `chat`,
`how_it_works`, `female`, `copy_code`, `emi_options`, `customer_reviews`… Each is a
one-line, zero-risk swap. None was taken this round, including `no_data_available`, which is
hardcoded on the very screen this round rewrote (`vitals_screen.dart:236`).

---

## Round-4 focus item 3 — The deletion copy, judged against what deletion actually does

The copy did not change (`git diff 9a80fe2 9127713 -- assets/i18n/` is empty). What changed
is what round 4 knows about the behaviour it describes. I verified the two load-bearing
claims first-hand rather than taking them from the other modules:

```
$ grep -rn "reauthenticate\|reauthenticateWith\|requires-recent-login\|requiresRecentLogin" lib/ test/
   → no matches
$ grep -rn "pending_deletion\|pendingDeletionKey" lib/ test/
   → 3 hits, all write-side. Zero readers. Zero tests.
```

`delete_account_screen.dart:127-140`:

```dart
final user = FirebaseService().currentUser;
if (user != null) {
  await user.delete();
  credentialDeleted = true;
}
} catch (e) {
  // Usually needs a recent login. The local record above still stands.
  Log.warn('Firebase account delete failed (may need reauth)', …);
}
```

The author knew (`:136`). There is no re-auth path to recover with, so for any session older
than Firebase's recent-login window the credential survives, `credentialDeleted` is `false`,
and — since the request record has no reader and no server ever hears about it — **the
account and all server-side records remain intact. Signing in again restores everything.**

Now the copy, in the order a user meets it:

| Order | Where | String | True? |
|---|---|---|---|
| 1 | `:218` `delete_account_intro` | "Deleting your account **removes** your Housepital profile and care history." | **False.** It removes neither. |
| 2 | `:226` `delete_account_removed_title` | "What gets deleted" | **False framing** — 3 of its 4 bullets are server-side. |
| 3 | `:233` `delete_account_removed_2` | "Care history, daily reports and vitals" | **False.** Untouched. |
| 4 | `:244` `delete_account_kept_title` | "What we must keep" — invoices, legal holds | **False by implication.** Exhaustive framing; they keep everything. |
| 5 | `:290` `delete_account_understand` | **"I understand this cannot be undone."** — a required checkbox | **False, and the user must affirm it.** |
| 6 | `:304` `delete_account_cta` | "Delete my account" | Overclaims. |
| 7 | `:176` `delete_account_confirm_body` | "This cannot be undone. Your care history, reports and saved details **will be removed**." | **False in both sentences.** Last thing read before the tap. |
| — | *irreversible tap* | | |
| 8 | `:152` `delete_account_done_title` | **"Deletion started"** | **False.** Nothing started anywhere. |
| 9 | `:155` `delete_account_done_device` | "Done: everything stored on this phone has been erased." | **True**, modulo the deliberately preserved `pendingDeletionKey`. |
| 10 | `:156` `..._done_login_pending` | "Pending: we could not remove your login automatically. Call us and we will do it." | Honest about the failure; **silent on the consequence** — that the account still works. |
| 11 | `:157` `delete_account_done_server` | "Requested — not yet done: … **our team** … Call 9990-911-911 with the reference below to confirm." | "our team" implies a queue. Nobody has been told. "to confirm" frames the only initiation channel as optional verification. |

**Round 3 called this "the honesty landed on the wrong side of the consent tap" and graded
it HIGH. That was correct on round 3's evidence and is too generous on round 4's.** The
problem is not sequencing. Eight of the eleven strings are false statements about what the
software does, and the two most prominent — the required consent checkbox and the result
dialog's title — are false in the direction that harms the user most: they tell a family
their medical records are irrecoverably gone when the records are intact and the account is
one sign-in away.

Two consequences beyond the checklist's ordinary scope, stated because this is health data
in India:

- **The consent is void of meaning.** DPDP-shaped erasure consent collected against an
  operation that does not erase is not a UX defect; it is a representation the company
  cannot substantiate. **BLOCKED-OWNER:** whether `housepital.in/privacy` states an erasure
  commitment the app contradicts.
- **The failure is silent in the safe-looking direction.** A family that wanted their data
  gone believes it is gone. There is no surface anywhere in the app that would ever tell
  them otherwise.

**Minimum honest copy, no code change:** `delete_account_intro` → *"This erases everything
on this phone straight away. Your records held by Housepital cannot be deleted from the app —
you must call us to do that."*; `delete_account_understand` → *"I understand the data on this
phone will be erased."*; `delete_account_done_title` → *"Erased from this phone"*;
`delete_account_done_server` → *"Nobody at Housepital has been told yet. Please call
9990-911-911 and quote this reference — write it down now, you will not be able to see it
again."* And where `credentialDeleted == false`, say the account still works.

### `delete_account_confirm_word` — still "DELETE" in Hindi

```
assets/i18n/en.json:339:  "delete_account_confirm_word": "DELETE",
assets/i18n/hi.json:339:  "delete_account_confirm_word": "DELETE",
```

Unchanged, under an unchanged comment at `delete_account_screen.dart:68-69` claiming the
opposite. **Round 3's M-1 stands verbatim.**

Worth adding what round 3 flagged only parenthetically: the comparison at `:72-76` is
`_confirmController.text.trim().toUpperCase() == _confirmWord(l).toUpperCase()`. Dart's
`toUpperCase()` is locale-independent and a **no-op on Devanagari**, so if the value were
corrected to `हटाएँ` the gate would demand exact-match typing of a conjunct with a
nukta-bearing character (ए + ँ) on a Hindi keyboard — a materially harder gate than "DELETE"
is for an English user. Fixing the string alone would trade one accessibility defect for
another. There is no test on this path either way (`grep -rn "confirm_word" test/` → no
matches). This is L10N-11.04's evidence as much as M-1's.

---

## Round-4 focus item 4 — The vitals sample/real transition (never audited before)

This round changed `vitals_screen.dart` so that real readings are never merged with the
`Random(42)` sample trend: if any real reading exists in the window, only real readings show;
otherwise the sample trend shows and raises `DemoMode.sourceVitals`
(`vitals_screen.dart:81`, `:120-135`).

**The engineering judgement is right. The content work that the change requires was not
done.** Four findings, all new.

### VIT-1 · ❌ **Fail** — One real reading silently blanks four charts

The entry sheet writes exactly **one** vital per reading. `vitals_screen.dart:721-737`
constructs a `VitalReading` in which every field except the selected `_vitalKey` is `null`:

```dart
systolic:    _vitalKey == 'bp'          ? primary : null,
temperature: _vitalKey == 'temperature' ? primary : null,
spo2:        _vitalKey == 'spo2'        ? primary : null,
sugar:       _vitalKey == 'sugar'       ? primary : null,
pulse:       _vitalKey == 'pulse'       ? primary : null,
```

`_mergedVitals` (`:126-135`) then applies its all-or-nothing rule to **all five tabs at
once**. So a family that records one blood-sugar reading makes `real.isNotEmpty` true
globally; the BP, Temperature, SpO2 and Pulse tabs fall through to `spots.isEmpty` at
`:281-283` and render:

```dart
return const Center(child: Text('No data'));
```

**Four vital charts that showed 180 days of trend one tap earlier now show the bare words
"No data".** The only feedback the user gets is `reading_saved` — *"Reading saved"* / *"रीडिंग
सहेज ली गई"* (`:110-114`). Nothing tells them the sample trend was a placeholder, that it has
now been retired, or that the other four charts will fill in as they add readings.

Before this round the mock baseline always populated every tab, so these two empty states
were effectively unreachable. **This round made them reachable in ordinary use and left the
copy at "No data".**

### VIT-2 · ❌ **Fail** — Nothing on the screen distinguishes sample from real

```
$ grep -n "sample\|Sample\|demo\|Demo" lib/screens/reports/vitals_screen.dart
```
Every hit is a Dart doc comment (`:55-60`, `:123`) or an identifier. **Zero user-facing
strings.** The chart, the stat cards, the average/min/max, the "latest reading" hero and the
alert count render identically whether the numbers were measured from the patient or
invented by `Random(42)` at `:52-83`.

The sole user-visible signal is the app-wide pill: `demo_banner_short` = *"Sample data — not
your live record"*, clamped to `maxLines: 1` with ellipsis (`demo_data_banner.dart:118-119`),
floating at top-centre. It is generic — it never says *which* data is sample — and round 3
measured it as marginal for clipping in Hindi at 320 pt. A fabricated 180-day clinical trend
is disclosed by a 34-character one-line pill that does not name the screen it is talking
about.

### VIT-3 · ⚠️ **Warning** — The demo warning flickers, and announces a false alarm

`_periodChip.onSelected` (`:216-219`) calls `_generateMockData()` on every 7d/30d/90d/All
tap, and `_generateMockData` raises the flag **unconditionally** at `:81` — including for a
patient who has real readings. The lowering happens later, during `build`, at `:129`. Each
tap therefore drives `DemoMode.isServingDemoData` false → true → false, mounting the pill.

`_DemoDataPillState.initState` (`demo_data_banner.dart:69-86`) fires a **one-shot assertive
`SemanticsService.sendAnnouncement`** on every mount. So a VoiceOver user with genuinely real
vitals hears *"Showing sample data — we can't reach Housepital right now, so this is not your
live record"* — assertively, interrupting — **every time they change the date range**. The
app tells a blind user their real clinical data is fake, repeatedly, and is wrong every time.

### VIT-4 · ⚠️ **Warning** — The sample flag latches on for the session

`dispose()` (`:86-89`) disposes only the `TabController`. `markServingLiveData(sourceVitals)`
is reachable only from `_mergedVitals` during this screen's `build`. So a patient with **no**
readings — the exact case the sample trend exists for — leaves `vitals-trend` in
`DemoMode._activeSources` permanently, and the pill then floats over Home, Billing, Services
and More for the rest of the session.

This is the general shape of a defect the brief lists as known-open, and I can now quantify
it: **12 sources are declared, 10 raise a flag, and only 2 ever lower one.**

```
$ grep -rn "markServingLiveData" lib/ | grep -v demo_mode.dart
lib/providers/app_provider.dart:…  markServingLiveData(DemoMode.sourceDashboard);
lib/screens/reports/vitals_screen.dart:129: markServingLiveData(DemoMode.sourceVitals);
```

`sourceMedications`, `sourceBilling`, `sourceOrders`, `sourceArticles`, `sourceMyCare`,
`sourcePatientIdentity`, `sourceCareTeam`, `sourceHandover` are latch-on-only. The banner's
copy is present tense — *"we **can't** reach Housepital **right now**"* — and that claim is
asserted for the remainder of the session regardless of recovery. Graded here as a **content**
defect: the string makes a live claim the mechanism cannot retract.

*Credit where due:* `sourceVitals` is one of only two sources that can clear itself. The
round-4 author wired both halves. The defect is in the ordering and the lifetime, not the
intent.

---

## Round-4 focus item 5 — Medical-safety copy

### MED-1 · ❌ **Fail** — The disclaimer exists, and it is on the one surface where the user only reads

**Correction to a claim other round-4 modules have circulated, and which I initially
reproduced.** It is *not* true that there are zero medical disclaimers in `lib/`. There is a
real one, it is well written, and it is applied consistently:

```
$ grep -c "talk to your doctor or your Housepital Health Manager" lib/data/demo_articles.dart
28
$ grep -rn "general guidance" lib/ | grep -v demo_articles   → no matches
```

> *"This is general guidance. For your specific situation, talk to your doctor or your
> Housepital Health Manager."*

It closes **28** article bodies in `lib/data/demo_articles.dart` — correct register, names a
real escalation path, and sits under genuinely careful safety copy inside the articles
themselves (`:33` *"When it is an emergency … Use the prescribed reliever inhaler and seek
urgent help if:"*; `:25` *"Never change the oxygen flow rate on your own. More is not always
safer."*). Someone on this team knows exactly how to write this.

**And it appears on none of the surfaces where the user acts.** The correct finding is
narrower than "there are no disclaimers" and worse than it sounds:

| Surface | What the user does there | Disclaimer? |
|---|---|---|
| Articles (`demo_articles.dart`) | reads | ✅ ×28 |
| Vitals screen — classifies BP/SpO2/sugar into severity bands | reads a clinical judgement | ❌ none |
| Medications — dose, frequency, adherence, reminders | acts on a dose | ❌ none |
| SOS | acts in an emergency | ❌ none |
| Doctor handover PDF — leaves the app to a clinician | shares a record | ⚠️ see below |
| Sahayak assistant — free-form generated replies | asks a question | ❌ none (MED-6) |

Two further defects in the same area:

- **The disclaimer is markdown baked into 28 string literals**, not a reusable component and
  not an i18n key. It cannot be reused on the clinical surfaces without copy-paste, and it is
  English-only inside a Hindi-supporting app.
- **The handover PDF's band is a demo-data notice, not a medical disclaimer, and it is
  unconditional.** `handover_report_service.dart:133-135` prints *"SAMPLE DATA - NOT A
  CLINICAL RECORD … Do not use it for clinical decisions."* on **every** page of **every**
  handover report, including one built entirely from real readings. It is the right warning
  wired to no condition — so it will be routinely disregarded by the clinicians it is
  addressed to, which is the failure mode of crying wolf. It is also hardcoded English and,
  per M-10, the PDF cannot render Devanagari at all. The vitals table it sits above
  (`:240-265`) carries no status column and no threshold legend.

Graded a content Fail under L10N-8.03 and L10N-12.01: the app classifies blood-oxygen
saturation, blood pressure and blood glucose into severity bands, schedules doses, and
exports a clinical summary, with no text on any of those surfaces telling the user this is
not a substitute for clinical judgement.

### MED-2 · ❌ **Fail** — The same reading gets two different severity words on one screen

Two independent classifiers with **different thresholds** and **different key names** are
both live on `vitals_screen`:

- `vital_classifier.dart` `classifyVital(…)` — used by the entry sheet (`vitals_screen.dart:716`) and `my_care_screen.dart:381`.
- `helpers.dart:7-24` `VitalHelper.getVitalStatus` → `AppConstants.vitalRanges` (`constants.dart:31-38`) — used by the trend page's alert counter (`vitals_screen.dart:568`).

Worked from the source, same number into both:

| Reading | `classifyVital` | `VitalHelper` | What the user sees |
|---|---|---|---|
| **SpO2 91 %** | `'red'` (`<92`) → "Needs attention" | `low`=90, `normalLow`=95 → `'borderline'` | Sheet shows a **red alert**; the chart's `alertCount` **does not increment**. |
| **Sugar 190 mg/dl** | `'yellow'` (`140–200`) → "Borderline" | `high`=180 → `'alert'` | Exactly inverted. |
| **Systolic 95** | `'green'` (`90–130`) → "Normal" | `normalLow`=100 → `'borderline'` | "Normal" and "Borderline" for one number. |

The two systems are not even keyed alike — `vital_classifier` uses `bp_systolic`,
`AppConstants.vitalRanges` uses `systolic` — which is why they were never reconciled. Round 3
filed this as structural (B-5); the **content** consequence is that the app gives a family
contradictory clinical severity words for one measurement, on one screen, in one session.

### MED-3 · ❌ **Fail** — A red vital names a state, or says nothing at all

`vitals_screen.dart:866-872`: `status == 'red'` → `label = l.t('vital_status_alert')` =
**"Needs attention"** / **"ध्यान देने की ज़रूरत"**.

That is the entire content of the app's most severe clinical signal. No threshold ("SpO2
below 92 %"), no action ("call your nurse"), no number, no escalation, no link to SOS —
despite `AppConstants.emergencyPhone` and the SOS screen both existing. `vital_status_alert`
is also the *softest* of the three labels in register: "Needs attention" reads as a
housekeeping note, and the Hindi is softer still. Unchanged from rounds 1–3.

**Worse on the other two surfaces that render the same classification.** There are three,
and they disagree in vocabulary, in localization, and in whether they use words at all:

| Surface | Renders a red vital as | Localized? |
|---|---|---|
| `vitals_screen.dart:869-871` | "Needs attention" + warning triangle | ✅ both locales |
| `my_care_screen.dart:378-433` | **an 8 × 8 coloured dot and nothing else** | — no status word exists to localize |
| `vitals_trend_grid.dart:112` (`service_detail_screen.dart:108`) | **"Critical"** — `card.status[0].toUpperCase() + card.status.substring(1)` | ❌ raw model token |

- `my_care_screen.dart:398-433` computes `classifyVital(...)` into `statusColor` and renders
  it as a bare `Container(width: 8, height: 8, shape: BoxShape.circle)`. The adjacent `Text`
  is the vital's **name** ("BP", "SpO2"), not its status. There is no `Semantics` wrapper on
  the pill. **On My Care, a critical vital is conveyed by colour alone** — see L10N-7.03.
- `vitals_trend_grid.dart:112` capitalises the raw model token (`my_care_models.dart:278`
  `// normal, warning, critical`) straight onto the badge, giving a **third** severity
  vocabulary — Normal/Warning/**Critical** against Normal/Borderline/**Needs attention** — in
  English only, in a Hindi-supporting app. `:289` `status: json['status'] ?? 'normal'` means
  any unexpected server value is printed verbatim. `:65` passes the same lowercase raw token
  to screen readers as `label: '$title, ${card.status}'`, so VoiceOver announces "BP,
  critical" in English regardless of locale.
- `notification_preferences_screen.dart:81` names the push channel **"Vitals RED Alert"** —
  the internal colour-code vocabulary surfaced as a user-facing setting.

So a family can see the same reading described as "Needs attention", as "Critical", and as an
unlabelled red dot, on three screens of one app, in two vocabularies and one language.

### MED-4 · ❌ **Fail** — "Request ACLS ambulance dispatch" opens a support ticket

`sos_screen.dart:86-91`:

```dart
_sosOption(context,
  icon: Icons.medical_services,
  title: 'Book Housepital Ambulance',
  subtitle: 'Request ACLS ambulance dispatch',
  onTap: () => _bookAmbulance(context),
),
```

`:192-194`:

```dart
void _bookAmbulance(BuildContext context) {
  Navigator.pushNamed(context, '/raise-concern');
}
```

Graded here as a **content** failure, which is the framing this checklist requires and which
prior rounds did not fully apply:

- **L10N-1.02 (no unexplained jargon).** "ACLS" is Advanced Cardiac Life Support. It is
  unexpanded, untranslated, and appears on the emergency screen — the one surface where the
  reader is a frightened family member, not a clinician.
- **L10N-2.01 (CTAs are action verbs that describe what happens).** "Book" and "dispatch"
  both denote a completed dispatch action. The control is a navigation to a concern form.
- **L10N-2.03 (state the consequence).** No copy anywhere says a ticket is being raised,
  that response is on the concern SLA (`constants.dart` `concernSla: emergency → 2 hours`),
  or that this is not how to get an ambulance now.
- **L10N-6.01.** Both strings are hardcoded English on a screen a Hindi-preferring family
  will reach in a crisis.

The honest copy costs nothing: *"Ask Housepital to arrange an ambulance"* / *"We will call you
back. For an ambulance now, dial 102 or 112."* The screen already has a `sos_112` key.

Compounding it: `constants.dart:17` and `:19` are the **same number** presented as two
distinct escalation paths at `sos_screen.dart:55-56` ("Call 9990911911") and `:66` — so the
one thing on the emergency screen that does dial out offers the user a choice that is not a
choice. Unchanged since round 1.

### MED-5 · ❌ **Fail** — Dosage copy is ambiguous, and a missed dose says nothing

- **Dosage is unvalidated free text.** `add_edit_medication_screen.dart:113`
  `labelText: 'Dosage (e.g., 500mg)'` — a `String` with a placeholder hint and no
  normalization. `stockUnit` is a *separate* dropdown (`:45` `['tablets','units','ml','puffs']`)
  with no tie to it, so `dosage: "5"` + `stockUnit: "ml"` saves cleanly and renders
  "Amlodipine 5" over "22 ml left".
- **"units" is overloaded.** `medications_screen.dart:523,542` render
  `'${med.stockCount} ${med.stockUnit ?? "units"} left'`. The fallback word for a *missing*
  unit is "units" — which is simultaneously the real insulin dose unit in this app's own data
  (`demo_data.dart:526` `dosage: '10 units'`, `:534` `stockUnit: 'units'`). A tablet with no
  recorded unit reads "22 units left" and is indistinguishable from an insulin count.
- **The reminder carries no dose.** `medication_reminder_service.dart:149-150` — title
  `'${medication.name} ${medication.dosage}'`, body **`'Time to take your medication'`**. The
  `instructions` field ("Take on empty stomach, 30 min before breakfast",
  `demo_data.dart:515`) never reaches the notification. `:371-381` silently substitutes app
  default slots (`thrice_daily → 08:00/14:00/21:00`) with no copy saying these are defaults
  rather than prescriber-set times.
- **A missed dose renders no text at all.** `medication_schedule_screen.dart:285-291` — the
  missed branch returns `SizedBox.shrink()`; icon and colour only. There is no
  missed-dose guidance anywhere in the app ("do not double up", "ask your nurse"). The key
  `missed_yesterday` exists in **both** locales (`en.json:156` / `hi.json:156`) and is
  rendered by nothing (`grep -rn "missed_yesterday" lib/` → no matches).
- `medication_models.dart:78` `default: return frequency;` — an unmapped frequency renders
  raw `every_other_day` onto a dosage row **and into the handover PDF**
  (`handover_report_service.dart:231` `_cell('${m.dosage} - ${m.frequencyLabel}')`).
  `medications_screen.dart:487` interpolates `med.form` raw and lowercase
  (`'${med.form} · ${med.frequencyLabel} · ${med.instructions ?? ""}'`), leaving a dangling
  `·` when instructions are null.
- **None of the medication surface is localized** — every string in
  `medication_reminder_service.dart`, `add_edit_medication_screen.dart` and the
  `medications_screen.dart` lines above is hardcoded English, while 17 medication keys sit
  translated in both catalogues (`en.json:143-159`).

### MED-6 · ⚠️ **Warning** — The assistant has no clinical guardrail in its copy or its prompt

The shipped local stub is transactional and safe: every reply in `assistant_service.dart`
(`:84-196`) is a booking/billing/call action in Hinglish, with no symptom, dose or triage
branch, and SOS routes to a confirm card (`:162`).

But **nothing in the copy scopes the assistant**, and the server prompt does not either:

- The greeting `assistant_screen.dart:133-135` — *"Namaste! Main aapki madad ke liye hoon.
  Pooch sakte hain: …"* — states no limits. There is no "I can't answer medical questions"
  string anywhere in `assistant_service.dart`, `assistant_screen.dart`,
  `assistant_executor.dart`, `assistant_local_actions.dart` or `assistant_fab.dart`.
- `functions/index.js:38-60` — the live `SYSTEM_PROMPT` returns a free-form `reply_text`
  (schema `:107`, no enum, no length cap). Its only guardrails are financial and factual
  (`:59` *"Never invent specific numbers, amounts, names, or dates"*; `:60` *"never imply you
  charged anything"*). **There is no instruction forbidding medical guidance and none routing
  symptom questions to a clinician.** A symptom message falls to `action: "none"` (`:52`,
  "general questions") while the model still emits warm free-form Hinglish.

Graded Warning rather than Fail because `assistantApiUrl` defaults to empty
(`constants.dart:11-12`), so shipped builds run the safe stub. It becomes a Fail the day the
endpoint is configured, and the copy fix (a scope line in the greeting, a refusal string, a
medical clause in the prompt) should land before then, not after.

### MED-7 · ⚠️ **Warning** — Consent and escalation copy

- Consent surfaces: `delete_account_*` is fully bilingual (the app's only properly localized
  consent surface); `rental_agreement_screen.dart:95-96` and `login_screen.dart:212-240` are
  hardcoded English, with `agree_terms` sitting translated and unused. Both "Terms" and
  "Privacy Policy" at `login_screen.dart:216,236` push `/about`, which links out to
  `housepital.in/terms` and `/privacy` (`about_screen.dart:98,104`) — so the two links are
  not distinguishable at the point of consent.
- **No consent copy exists for clinical data sharing.** `my_care_screen.dart:553` fires
  `Printing.sharePdf` on the full medical history with no confirmation dialog and no consent
  string; `family_members_screen.dart:116-195` grants a new family member vitals-alert and
  attendance visibility with no consent string on either side.
- `family_members_screen.dart:382-384` renders `member.role.replaceAll('_', ' ')` — the raw
  role constant, shown to the user as **"FAMILY MEMBER"** in screaming snake case.
- `care_team_screen.dart:354` labels a row **"Ambulance — 24x7 Emergency"** and dials
  `AppConstants.emergencyPhone` (`:380-381`) — the Housepital ops line, not a dispatcher —
  with no `canLaunchUrl` guard and no failure dialog, unlike `sos_screen.dart:247-289`.
- Arriving at `/raise-concern` from the SOS ambulance button does **not** pre-select the
  "Emergency" urgency chip (`raise_concern_screen.dart:176`), so the default SLA copy the
  user reads is *"We will respond within 24-72 hours."* (`:381-385`).
- `payment_reminder_service.dart:126,135,153` — dunning copy threatening service
  interruption ("Pay now to avoid service interruption") on a home-healthcare account,
  contradicting `home_screen.dart:1581` ("Your care continues uninterrupted."). Unchanged.

---

## Control results

| Control | Outcome | Evidence | Impact / mitigation (Warnings and Fails) |
|---|---|---|---|
| **L10N-1.01** Brand voice consistent | Warning | New deletion/payment Hindi is register-correct; unchanged off-brand: `payment_reminder_service.dart:126,135,153`, `invoice_pdf_service.dart:250`, `referral_screen.dart:119` | Telco-style dunning on a care account. Owner: OWNER-TBD. Mitigation: rewrite 3 strings; service is unwired today. |
| **L10N-1.02** No jargon / dev terms | **Fail** | `sos_screen.dart:89` "ACLS"; `care_packages.dart:19,28,66,75` "BiPAP", "centralised vital monitoring"; `universal_search_screen.dart:92-93` "RT (Ryles Tube)"; `medication_models.dart:78` raw `every_other_day`; raw Razorpay text `payment_screen.dart:573-578`; `family_members_screen.dart:384` `role.replaceAll('_',' ')` → "FAMILY MEMBER"; `vitals_trend_grid.dart:112,65` raw `status` token to badge and to VoiceOver; `notification_preferences_screen.dart:81` "Vitals RED Alert" | Clinical acronyms and raw model/enum identifiers on emergency, dosage, vitals and settings surfaces. |
| **L10N-1.03** Reading level | Warning | Deletion copy ~Grade 8 both languages; `delete_account_kept_2` unbounded; rental contract English-only | Owner: OWNER-TBD. |
| **L10N-2.01** CTAs are action verbs | Warning | `payment_screen.dart:630,639,648` `'Go Back'`/`'Retry Payment'`; ~24 vague labels (`Text('OK')` ×5, `'Yes'`, `'Submit'`, `'Done'`) | Also MED-4: "Book"/"dispatch" describe an action the control does not perform. |
| **L10N-2.02** Labels clear and consistent | **Fail** | Duplicate keys `todays_vitals`/`today_vitals` with divergent Hindi (विटल्स / वाइटल्स); `borderline`/`vital_status_borderline` (सीमा रेखा / सीमा पर); `vitals_screen.dart:154` titles a 7–180-day trend "Today's Vitals" | Two Hindi spellings of "vitals" ship simultaneously. |
| **L10N-2.03** Confirmations state the consequence | **Fail** | `delete_account_confirm_body`, `delete_account_understand` — both state a consequence that does not occur (§focus 3). 6 of 7 `confirmDestructiveAction` sites still state none | Round 3 graded ⚠️; re-graded on round 4's evidence that the stated consequence is false. |
| **L10N-3.01** Empty states explain + tell how to add | **Fail** | `vitals_screen.dart:236` `'No data available'`, `:282` `'No data'` — **newly reachable** via VIT-1; `paginated_list.dart:126,154,233`; `no_data_available` translated and unused | Round 3 graded ⚠️ when these were unreachable. This round made them ordinary. |
| **L10N-3.02** Loading copy honest and brief | Warning | 25 `CircularProgressIndicator` sites, 1 with copy; `delete_account_screen.dart:297-303` bare over prefs-write → Firebase delete → 7-provider wipe → sign-out | Owner: OWNER-TBD. `loading` key exists, unused. |
| **L10N-3.03** Errors non-technical and actionable | **Fail** | `payment_service.dart:223-224` → `payment_screen.dart:573-578` raw gateway text; `raise_concern_screen.dart:410` `'Failed to submit: ${e.message}'`; `payment_screen.dart:336-339` "call us" with no number | Raw `BAD_REQUEST_ERROR`-class strings on the money-loss screen. |
| **L10N-3.04** Disabled actions say why | **Fail** | `delete_account_screen.dart:296` `onPressed: canSubmit ? … : null` + 4 further sites; `login_screen.dart:48-60` holds the right pattern, unused | Unchanged from rounds 1–3. |
| **L10N-4.01** One term per concept | **Fail** | **Three severity vocabularies for one classification** — Normal/Borderline/"Needs attention" (`vitals_screen.dart:869-878`), Normal/Warning/**Critical** (`vitals_trend_grid.dart:112`), and an unlabelled colour dot (`my_care_screen.dart:421-433`); "Health Manager"/"coordinator"/"Care Team"; support numbers in 3 formats + Dai Maa's; deletion's 5th state vocabulary ("Done"/"Pending"/"Requested — not yet done") | No glossary in `docs/`. MED-2 shows the two threshold sets behind these words also disagree. |
| **L10N-4.02** Capitalization consistent | Warning | 4 × `% OFF` vs 4 × `% off`; `delete_account_title` sentence case against Title Case AppBars, locked into both JSONs | Owner: OWNER-TBD. |
| **L10N-5.01** Currency per locale | Warning | `helpers.dart:51-54` `en_IN` correct, used 114×; 8 bypasses incl. `invoice_pdf_service.dart:69` `'Rs ${amount.round()}'` on the tax invoice | Owner: OWNER-TBD. |
| **L10N-5.02** Dates/times locale-correct | **Fail** | `grep -rn "Intl.defaultLocale\|initializeDateFormatting" lib/` → zero. `helpers.dart:28-38` hardcodes `'h:mm a'`, `'dd MMM yyyy'` | Hindi users get English month names and forced 12-hour time. |
| **L10N-5.03** Pluralization via plural rules | **Fail** | `rental_agreement_screen.dart:54`, `service_booking_screen.dart:952,1460,2175`, `invoice_pdf_service.dart:212` — `month(s)`/`name(s)`/`file(s)`. `app_localizations.dart:29-36` has no plural facility | Hindi has different plural morphology; `(s)` is untranslatable. |
| **L10N-5.04** Numeric precision for money | Warning | ~10 `formatCurrency(x.toInt())` truncation sites | Owner: OWNER-TBD. |
| **L10N-6.01** No hardcoded user-facing strings | **Fail** | **231 : 1,223 → 15.9 %**, unchanged from `9a80fe2`. 57 files with zero `l.t()`; top file 124 literals / 2 calls | Five sixths of the app's words bypass the catalogue. |
| **L10N-6.02** Target scripts render correctly | **Pass** | `theme.dart:156-160` `_devanagariFallback` via `fontFamilyFallback` at `ThemeData` level; bundled `NotoSansDevanagari`; all 353 Hindi values route through it | — |
| **L10N-6.03** Layouts tolerate expansion | Warning | `demo_banner_short` 1.12× inside `maxLines: 1` (`demo_data_banner.dart:118-119`), marginal at 320 pt; overflow guard is English-only | Owner: OWNER-TBD. Fix: `maxLines: 2`. |
| **L10N-6.04** RTL handled | **N/A** | `main.dart:398-401` `supportedLocales: [Locale('en'), Locale('hi')]` — both LTR; no RTL locale is declared or distributed | Rationale recorded. Revisit if Urdu/Arabic is added. |
| **L10N-6.05** Text fits at largest accessibility size | Warning | `main.dart:413-424` clamps 0.85–1.4×; demo pill clips at 1.4× in both languages; deletion screen (longest two-script surface) in no overflow test | Owner: OWNER-TBD. |
| **L10N-6.06** Formatters locale-aware, not string-built | **Fail** | `helpers.dart:28-38` fixed `DateFormat` patterns with no locale; `invoice_pdf_service.dart:69` string-built currency | — |
| **L10N-7.01** Screen-reader labels meaningful | Warning | 27 of 54 `IconButton`s carry `tooltip:`; deletion result dialog is one concatenated `Text` (`:154-159`); reference not `SelectableText` | Owner: OWNER-TBD. |
| **L10N-7.02** Images/charts have alt text | **Fail** | `vitals_screen.dart:365` `LineChart` has no `Semantics` wrapper — the app's primary clinical visualization is silent to VoiceOver | — |
| **L10N-7.03** Status by text/icon, not colour alone | **Fail** | `my_care_screen.dart:398-433` renders a classified vital as an 8×8 coloured dot with **no status text and no `Semantics`** — the adjacent `Text` is the vital's name, not its status. Also: the payment pending path renders an amber title over a red `errorLight` body (`:499-504` vs `:572-579`) | Round 3 graded ✅ on the vitals *screen*, which does pair icon + word; the My Care pill was not examined. A critical vital is colour-only for a colour-blind or low-vision user on the app's main care surface. |
| **L10N-8.01** Store listing copy accurate | **Fail** | `AndroidManifest.xml:7` `android:label="housepital_patient"` — the user-visible launcher name. No `fastlane/metadata`; listing text BLOCKED-OWNER | Ships with a snake_case identifier as its Android app name. |
| **L10N-8.02** "What's New" / release notes | Warning | No `fastlane/`; `docs/CHANGELOG.md` is engineering-facing | Owner: OWNER-TBD. Unverified whether notes are drafted outside the repo. |
| **L10N-8.03** Legal/in-app text matches behaviour | **Fail** | §focus 3 — 8 of 11 deletion strings misstate behaviour; MED-1 — zero medical disclaimers; `login_screen.dart:216,236` Terms and Privacy both push `/about` | Erasure consent collected against an operation that does not erase. |
| **L10N-9.01** Spelling and grammar | **Pass** | Misspelling regex over `lib/` → zero hits; Devanagari punctuation (`।`) correct; no transliteration artefacts | — |
| **L10N-9.02** No placeholder copy shipped | Warning | **Improved** — all three placeholder phone numbers fixed (§focus 1a). Remaining: `document_repository_screen.dart:599` `'PDF upload coming soon.'`; stale `// NOTE: Support number to be updated` at `staff_otp_verification_screen.dart:352` | Round 3 graded ❌. `rzp_test_XXXXXXXXXX` is by design per CLAUDE.md. Owner: OWNER-TBD. |
| **L10N-9.03** No truncation on smallest viewport | Warning | `overflow_smoke_test.dart` real (37 screens × 320/375/414, Ahem) but `:231` `locale: 'en'`, `:335` `supportedLocales: [Locale('en')]`, scaler 1.0; misses `DeleteAccountScreen`, `DemoDataBannerHost`, `VitalsScreen` | Owner: OWNER-TBD. |
| **L10N-9.04** Brand name spelled/cased consistently | Warning | "Housepital" correct in all prose incl. inside Devanagari sentences; `AndroidManifest.xml:7` and `Info.plist:18` `CFBundleName` = `housepital_patient` | Failed at 8.01; not double-counted. |
| **L10N-10.01** Pseudolocalization | **Fail** | `grep -rni "pseudo" lib/ test/ scripts/` → zero. No pseudolocale target, no missing-resource exercise | Not tested is not N/A. |
| **L10N-10.02** Automated checks fail on missing/orphaned/duplicate/hardcoded | **Fail** | `test/utils/i18n_sync_test.dart` (74 lines) enforces EN↔HI key parity, `{param}` parity, and non-empty — genuinely good. It does **not** detect orphaned-vs-code (158 unused keys ship), duplicates (`todays_vitals`/`today_vitals`), or hardcoded strings (1,223 ship) | 2 of 4 required classes covered; nothing fails the build on the two largest. |
| **L10N-10.03** Translator context per string | **Fail** | Both catalogues are flat `key: value` JSON. No descriptions, no comments, no screenshots, no grammatical notes, no `.arb` metadata | A translator sees `delete_account_kept_2` with no indication it is legal text. |
| **L10N-10.04** Locale-aware plural/gender/select; no fragment assembly | **Fail** | `app_localizations.dart:29-36` `translate` does only `replaceAll('{k}', v)` — no plural/gender/select. `delete_account_screen.dart:154-159` assembles the result dialog from 4 translated fragments joined by `\n\n`; payment title and body are localized in different files | Fragment assembly is exactly what the control forbids. |
| **L10N-10.05** Locale fallback deliberate and tested | **Fail** | `app_localizations.dart:29` `String text = _localizedStrings[key] ?? key;` — a miss renders the **raw key** on screen, not the English value. No fallback chain is loaded. `load()` `:18-26` reads one file. Only the guard test prevents it | The known regression this guards against ("today_report" shipped literally) is a runtime hole, not a fixed one. |
| **L10N-10.06** Fonts/language assets available offline | **Pass** | `Archivo` + `NotoSansDevanagari` bundled in `pubspec.yaml`; `google_fonts` removed per CLAUDE.md; no runtime font download | — |
| **L10N-11.01** Calendars, time zones, DST, 12/24h via locale APIs | **Fail** | No `initializeDateFormatting`; `helpers.dart:28-38` hardcodes `'h:mm a'` (12-hour) and `'dd MMM yyyy'`; no time-zone handling; `delete_account_screen.dart:87` stores `toIso8601String()` and displays no date at all | 24-hour preference and Hindi month names both ignored. |
| **L10N-11.02** Units, addresses, names, phone numbers per market | Warning | `Validators.indianMobile` correct for input; display side shows one number in 3 formats + Dai Maa's `+91-90502-00183` presented as "our coordinator" | Owner: OWNER-TBD. |
| **L10N-11.03** Unicode, grapheme clusters, safe truncation | Warning | Devanagari renders correctly (6.02); truncation is by `maxLines`+ellipsis (framework-safe). No normalization/case-folding handling anywhere; no test exercises combining marks | Owner: OWNER-TBD. Unverified for input paths. |
| **L10N-11.04** Locale-aware search, comparison, case folding, sorting | **Fail** | `delete_account_screen.dart:72-76` gates account deletion on `.toUpperCase()` equality — locale-independent and a **no-op on Devanagari**, which is why `delete_account_confirm_word` cannot simply be translated (M-1). Search is plain `contains`; no `Collator` anywhere | The one place case folding is load-bearing is the irreversible-action gate. |
| **L10N-11.05** Bidi isolation; mirroring only where meaningful | **N/A** | Both declared locales are LTR (`main.dart:398-401`); no bidi values are composed | Rationale recorded. |
| **L10N-12.01** Native reviewer on production locales incl. safety/health copy | **Fail** | No sign-off artefact in the repo; `grep -rn "Locale('hi')" test/` → **zero**; 353 Hindi strings including all consent and vital-status copy ship unreviewed; MED-1 shows the safety copy does not exist to review | Health and legal copy in a second language with no qualified review. |
| **L10N-12.02** Localized screenshots / visual regression | **Fail** | `overflow_smoke_test.dart:231,335` pin `Locale('en')` and scaler 1.0; no golden/screenshot test in any locale; no large-text capture | The Hindi UI has never been rendered in CI. |
| **L10N-12.03** Notifications, PDFs, exports, help content in the locale inventory | **Fail** | `invoice_pdf_service.dart` / `handover_report_service.dart` load no Devanagari font — both PDFs are English-only by construction; `payment_reminder_service.dart:135,153` notification bodies hardcoded English; `help_faq_screen.dart` FAQ content hardcoded English | Every artefact that leaves the app is English-only. |
| **L10N-12.04** Store metadata localized and consistent with the binary | **Fail** | No `fastlane/` directory; no metadata of any kind in the repo; nothing to localize against a binary that declares `hi` support | Listing content itself is BLOCKED-OWNER; the absence of any metadata pipeline is verifiable and graded here. |
| **L10N-12.05** Translation changes versioned and traceable to source-string revision | Warning | Changes are in git (`13e3656` added 32 pairs); no TMS, no source-string revision linkage, no translator attribution, no review record | Owner: OWNER-TBD. Git history is a partial substitute. |

---

## Scorecard

**Pass 3 · Warning 17 · Fail 26 · N/A 2** (48 controls) · BLOCKED-OWNER 5 (listed below;
each is additionally graded above rather than left ungraded)

### Like-for-like against round 3

Round 3 graded 32 items (§1–§9 only). On that identical subset:

| | Pass | Warning | Fail | N/A |
|---|---:|---:|---:|---:|
| Round 3 (`9a80fe2`) | 4 | 15 | 12 | 1 |
| **Round 4 (`9127713`)** | **2** | **14** | **15** | **1** |

Every difference is accounted for, and none of it is drift:

- **9.02 ❌ → Warning** — *genuine improvement.* All three placeholder phone numbers fixed.
- **2.03 ⚠️ → Fail** — re-graded: the stated consequence is now known to be false.
- **3.01 ⚠️ → Fail** — new defect: VIT-1 made the bare empty states reachable.
- **8.03 ⚠️ → Fail** — re-graded against the account-not-deleted reality.
- **7.03 ✅ → Fail** — re-graded on evidence no round has examined: `my_care_screen.dart:398-433`
  conveys a critical vital by colour alone. Round 3 checked the vitals *screen*, which pairs
  icon + word correctly, and did not check the My Care pill.
- **9.04 ✅ → Warning** — re-grade on evidence round 3 documented (`AndroidManifest.xml:7`)
  but did not carry into the grade.

§10–§12 (16 controls) were never graded by round 3. They score **1 Pass · 3 Warning · 11 Fail
· 1 N/A** — the localization *engineering* is materially weaker than the localization
*content*, which is the expected shape for a project with a hand-rolled `translate()` and no
TMS.

---

## Release blockers (every Fail)

Ordered by harm, not by control number.

1. **L10N-8.03 / 2.03 — The account-deletion flow requires the user to affirm a false
   statement and then reports a deletion that did not happen.** 8 of 11 strings misstate
   behaviour; `delete_account_understand` ("I understand this cannot be undone") is a
   required checkbox and is false; `delete_account_done_title` ("Deletion started") is false.
   Verified: no re-auth path (`grep reauthenticate lib/ test/` → zero), request record has
   zero readers. `delete_account_screen.dart:127-140`, `assets/i18n/{en,hi}.json`.
   *Fixable in 5 strings, no code.*
2. **L10N-1.02 / 2.01 / 2.03 — "Book Housepital Ambulance" / "Request ACLS ambulance
   dispatch" opens a support-ticket form.** `sos_screen.dart:88-89` → `:192-194`. Unexpanded
   clinical acronym, hardcoded English, on the emergency screen. Unchanged since round 1.
3. **L10N-8.03 / 12.01 — The medical disclaimer exists only on article-reading screens.**
   28 occurrences in `demo_articles.dart`; none on vitals, medications, SOS, the handover PDF
   or the assistant. The handover PDF's band is a demo-data notice, is unconditional, and
   prints "SAMPLE DATA — NOT A CLINICAL RECORD" on real reports
   (`handover_report_service.dart:133-135`).
4. **L10N-2.02 / 4.01 — Two vital classifiers with different thresholds are live on one
   screen**, producing opposite severity words for SpO2 91 %, sugar 190, systolic 95
   (`vitals_screen.dart:568` vs `:716`) — and **three different severity vocabularies** across
   the three surfaces that render the result.
5. **L10N-7.03 — A critical vital is conveyed by colour alone on My Care.**
   `my_care_screen.dart:398-433` — 8×8 coloured dot, no status word, no `Semantics`.
6. **L10N-3.01 — One saved reading silently blanks four vital charts** (VIT-1), landing on a
   bare `'No data'`. New this round. `vitals_screen.dart:126-135`, `:281-283`, `:721-737`.
7. **L10N-1.02 / 3.03 — Dosage copy is ambiguous and a missed dose says nothing.**
   Unvalidated free-text `Dosage` (`add_edit_medication_screen.dart:113`); `stockUnit ??
   "units"` collides with the real insulin unit (`medications_screen.dart:523,542`); the
   reminder body carries no dose or instruction (`medication_reminder_service.dart:150`);
   missed doses render `SizedBox.shrink()` (`medication_schedule_screen.dart:285-291`).
8. **L10N-3.03 — Raw Razorpay gateway text still reaches the patient** on the payment screen.
   `payment_service.dart:223-224` → `payment_screen.dart:573-578`.
9. **L10N-6.01 / 6.06 / 5.02 / 5.03 / 11.01 — The localization substrate.** 15.9 % localized
   and flat; no `Intl.defaultLocale`; no plural facility; hand-built date and currency
   formats.
10. **L10N-10.01 / 10.02 / 10.03 / 10.04 / 10.05 — Localization engineering.** No
    pseudolocalization; the guard catches 2 of 4 required classes; no translator context; no
    plural/gender/select and fragment-assembled sentences; **no runtime locale fallback — a
    missing key renders the raw key.**
11. **L10N-12.01 / 12.02 / 12.03 / 12.04 — Localization QA and distributed surfaces.** Zero
    `Locale('hi')` in `test/`; no localized visual regression; every PDF, notification and
    export is English-only; no store metadata pipeline.
12. **L10N-3.04 — Disabled actions never say why**, including the deletion CTA.
13. **L10N-7.02 — The clinical chart is silent to screen readers.** `vitals_screen.dart:365`.
14. **L10N-8.01 — Android launcher label is `housepital_patient`.**
15. **L10N-11.04 — Case folding is load-bearing on the irreversible-action gate and is a
    no-op on Devanagari**, which is why M-1 cannot be fixed by editing the string alone.

---

## Warnings requiring risk acceptance

All 17 Warnings are tabulated above with impact and mitigation. Owner is `OWNER-TBD`
throughout — no `CODEOWNERS`, ticket system or assignee is discoverable from the repository.
The four with the shortest path to closure:

| # | Warning | Fix | Cost |
|---|---|---|---|
| 1 | L10N-9.02 stale `// NOTE: Support number to be updated` above a line that now uses the production constant (`staff_otp_verification_screen.dart:352`) | Delete the comment | 1 line |
| 2 | L10N-6.03 demo pill clips the only fake-medical-data warning in the app | `maxLines: 2` (`demo_data_banner.dart:118`) | 1 line |
| 3 | L10N-4.02 `% OFF` vs `% off` | Pick one across 8 sites | 8 lines |
| 4 | L10N-3.02 `loading`, L10N-3.01 `no_data_available`, L10N-8.03 `agree_terms` translated and unused while the same English is hardcoded | 48 free wins; take the 3 on consent/clinical screens first | ~3 lines each |

---

## BLOCKED-OWNER — needs access I do not have

1. **Does a deletion request reach anyone, by any channel?** *(Carried from rounds 2 and 3;
   now the pivot of blocker 1.)* I can prove the app tells nobody. I cannot prove an ops
   inbox, WhatsApp queue or CRM does not receive these out of band. **Need:** confirmation,
   and whether an agent can resolve a `DEL-…` reference. If not, the copy must say so
   before consent.
2. **Published privacy policy and terms text.** Live only at `housepital.in/privacy` and
   `/terms` (`about_screen.dart:98,104`). **Need:** the text, to check whether it states an
   erasure commitment the app contradicts, and whether it carries the medical disclaimer the
   binary lacks (MED-1).
3. **App Store / Play listing copy and metadata.** No `fastlane/`. **Need:** current listing
   text, to check whether it claims ambulance booking (blocker 2) or Hindi support (15.9 %
   real).
4. **"What's New" / release notes.** **Need:** owner confirmation whether notes are drafted
   outside the repo.
5. **Native Hindi sign-off on all 353 strings**, especially consent and vital-status copy.
   The 32 strings added in round 3 read as competent Delhi-NCR Hindi to a non-native
   reviewer. **Need** specifically: whether *"अनुरोध किया गया — अभी बाकी है"* lands as "we have
   not done this" rather than "it is in progress"; whether "ध्यान देने की ज़रूरत" is strong
   enough for a red vital (MED-3); and the `delete_account_confirm_word` decision, given that
   `हटाएँ` interacts badly with the `toUpperCase()` gate (L10N-11.04).

---

## Limitations of this audit

- **The working tree was modified by a concurrent process during this audit.** At the end of
  my run `git status --porcelain` reported `lib/providers/app_provider.dart`,
  `lib/providers/auth_provider.dart`, `lib/screens/home/home_screen.dart` and
  `lib/services/store_migrator.dart` as modified. **None of these edits are mine** — this
  module made no code changes; my only writes were this report and files under my scratchpad.
  The changes are storage/session/forced-logout repairs belonging to another round-4 module's
  domain. **Impact on this report: none, and verified rather than assumed.** The localization
  measurement read the four trees via `git archive <ref>`, not the worktree. Of the two dirty
  files I cite, I re-checked every cited line against `git show 9127713:<file>` — all match
  (`home_screen.dart:487,821,874`; `auth_provider.dart:233`). Every other file I cite is clean
  in the worktree. One inherited citation was corrected in the process:
  round 3's `home_screen.dart:1578-1580` is `:1581` at this commit. **Anyone re-running my
  greps against a later worktree may see shifted line numbers; all citations in this report
  are anchored to `9127713`.**
- **MASTER-4.04: this is a source review, not a release-artifact review.** No IPA/AAB was
  built or inspected; no device or simulator was run; no production traffic was observed.
  Rendering claims (Devanagari fallback, clipping thresholds, pill occlusion) are reasoned
  from source and geometry, not photographed. That is an honest constraint of the brief, not
  a finding.
- **`flutter test` / `flutter build` / `flutter analyze` were NOT run**, per the brief's
  concurrency rule. Central results cited where relevant: analyze clean, design gate passes,
  1,819 tests across 101 files pass. Test-quality findings come from reading test sources.
- **The localization script is a reconstruction.** Round 3's `scratchpad/l10n_measure.py` is
  not in the repository. Mine reproduces round 3's `localized`, key and unused-key series
  exactly and its deltas to within 1; the `hardcoded` denominator runs ~3 % higher and the
  `wins` sub-metric uses a stricter match (48 vs 97). **The R3→R4 conclusion does not depend
  on the script** — `git diff 9a80fe2 9127713 -- assets/i18n/` is empty and the net `.t(`
  delta is 0.
- **Hindi quality is assessed by a non-native reviewer.** Grammar, register, script
  correctness and terminology consistency are checkable and were checked; idiomatic
  appropriateness for a Delhi-NCR family under stress is not, and is BLOCKED-OWNER item 5.
- **Behavioural claims imported from other round-4 modules were re-verified here, not
  assumed** — specifically the absence of a re-auth path and the zero-reader deletion record
  (commands and outputs in §focus 3). Where I could not verify (whether a request reaches
  ops by another channel), I said so rather than grading it.
- **One imported claim was wrong and is corrected here.** The circulating statement that
  there are "ZERO medical disclaimers anywhere in `lib/` or either i18n file" is **false**,
  and my first pass reproduced it before a wider sweep found the counter-evidence: a real,
  well-written disclaimer closes 28 article bodies in `lib/data/demo_articles.dart`
  (`grep -c` output in MED-1). The accurate finding — that the disclaimer is confined to
  reading surfaces and absent from every acting surface — is narrower, verifiable, and more
  useful. Any round-4 synthesis that repeats the "zero" phrasing should be corrected against
  this. It is a reminder that a negative grep is only as good as its patterns: mine required
  a space after "consult", and the shipped string says "talk to your doctor".
- **Backends were not read for this module.** `../housepital-backend` and `../housepital-api`
  define no user-facing copy that the patient app renders; the app is pointed at neither and
  `api.housepital.in` does not resolve. Server-provided content is therefore out of scope
  for L10N-10.05's server-content clause, which I graded on the client fallback alone.
  `functions/index.js` **was** read (MED-6) because its `SYSTEM_PROMPT` generates
  user-facing reply text; it is outside `lib/` and outside the demo build path, which is why
  MED-6 is a Warning and not a Fail.
- **Owner decisions were measured, not graded:** white on Housepital orange, manpower pricing
  visibility, the floating glass pill nav. None affects a control in this module.
