# Round 4 — Synthesis

**Date:** 2026-08-20
**Scope:** 25 audit modules (Suite v2.0) against `fix/five-tab-nav`, plus the
Firebase/Express backend at `../housepital-backend`.
**Gate vocabulary:** Pass / Warning / Fail / N/A. *Not tested is not N/A.*

---

## The one-line finding

The app is not broken in the places anyone was looking. Round 4's defects
cluster in the seam between **code that is correct in isolation** and **code
that is correct against the thing it actually talks to** — and every one of
them was invisible because the app falls back to bundled sample data whenever
the backend is unreachable, and `api.housepital.in` does not resolve.

That fallback is a good demo property and it has been acting as a blindfold.
A backend where twenty endpoints could not return success presented, from
inside the app, as a backend that was merely offline.

---

## What each round has actually been about

| Round | The name for it | What it meant |
|---|---|---|
| 1 | Defects | Things that were wrong on their own terms |
| 2 | **Surfaces** | Features that rendered but were not wired |
| 3 | **Half-wires** | Wires connected at one end |
| 4 | **Wired-but-unwitnessed** | Wires connected at both ends, into a socket that was never energised — and nothing watching either end |

The round-4 pattern deserves stating plainly, because it is the one that
survives ordinary review: *a thing can be fully implemented, fully tested, and
completely non-functional, if the test and the implementation share the same
wrong assumption.*

Three examples of exactly that shape:

- **`createOrder` read `result['order_id']`.** The backend has always
  responded `razorpay_order_id`. The unit test's fake returned `order_id` —
  because it was written from the client's belief, not from the route. Four
  audit rounds passed. No real payment could ever have completed.
- **`AppConstants.vitalRanges` had its own test file** asserting the map was
  internally consistent. It was. It also disagreed with the app's *other*
  vital classifier about SpO₂, sugar and systolic BP, under key names neither
  shared.
- **`SessionScope`** had four call sites and zero test imports across three
  rounds. Round 4 found six defects in it in one pass.

---

## Severity, as measured

### Could have taken or lost money

| Defect | Effect |
|---|---|
| `PaymentScreen.amount` read as rupees when displayed and paise when charged | A ₹5,000 cart checkout displayed ₹5,000 and charged **₹50**. Billing compensated at its own end (`totalDue * 100`), so the same bill displayed **₹5,00,000** and charged correctly. Two entry points, wrong in opposite directions, each locally consistent. |
| `createOrder` field name | Every real payment died in the fail-closed guard. Nothing was mis-charged — the app was safe *by accident*. |
| `invoice_detail_screen` passed `'invoiceId'`, the route reads `'invoice_id'` | Payment recorded against no bill. |
| `payments.updated_at` written by five sites, column never existed | Every payment write errored. |

### Could have harmed someone

| Defect | Effect |
|---|---|
| `staff_profile_screen` fabricated `police_verified: true` | The only reachable path. **Every person who opened a staff profile was told their caregiver passed a police check Housepital never performed and this app never saw.** Plus a fabricated 4.8 rating, four invented named reviews, four "verified" compliance documents, and an entirely generated attendance grid with invented check-in times. |
| `needsAssessment` gate inverted | `if (availableForRent) return false` — and every ventilator, BiPAP, CPAP, oxygen concentrator, suction machine and pump in the catalog is rentable. The gate cleared all 48 of them and stopped **BiPAP masks**. Seventeen oxygen concentrators were not in the name list at all. |
| Assistant routed "bleeding ho raha hai" → `get_duty_days` | The duty branch matched the unanchored substring `din`; "blee-**din**-g" contains it. A bleed was answered with "Staff ki duty check kar raha hoon…". |
| Two vital classifiers | SpO₂ 91 was RED on one screen and BORDERLINE on another; sugar 190 YELLOW on one and ALERT on the other. Which screen a family opened decided how urgent a hypoxic reading looked. |
| `verifyPatientAccess` denied only when **both** ids were present and differed | `verifyAuth` assigns `patientId = ""` to any Firebase-authenticated caller with no `family_members` row. That blank claim satisfied the guard for **every patient id**. Firebase phone auth is open to anyone with a phone: sign in, never onboard, read any patient's medications, invoices, vitals, reports and family list. |
| Medication notification IDs overflowed 32 bits | Two medications colliding on one ID meant scheduling the second **silently replaced** the first. The patient is never reminded about one of their drugs and nothing reports an error. |
| EXIF GPS preserved on every uploaded photo | A wound photo sent to support carried the home coordinates of a bedbound patient, to a bucket readable by every authenticated account. |
| No medical disclaimer anywhere | The only one in the codebase was a sentence inside one blog article's body text. |

### Could not be trusted

- **CI has never executed a step.** 47 runs, all blocked on billing. The
  1,819-test figure had **zero independent attestation** — it was self-reported
  by the same machine that wrote the tests.
- The demo-data overlay pill **absorbed taps** on the app-bar actions beneath
  it (search, cart, calendar). Since the banner is up in every shipped build,
  those actions were dead for every user with no visual cue why.
- Design-gate and theme comments cited contrast ratios that match no pair of
  tokens in the file (`orangeText` "4.6:1" — measured **3.99:1**; dark orange
  "6.32:1 vs #1A1A1A" — a surface never defined).

---

## Gate recommendations

**24 Hold, 1 Reject.** AI/LLM Safety allows the offline-stub build only, and
holds on ever setting `ASSISTANT_API_URL`. Release & Store Submission is the
Reject.

**Master record: Reject for public release. Hold for internal field use.**

---

## What has been fixed, and what that does not mean

Waves 1–3 closed the code-side defects above. Every fix carries a regression
test, and several tests were rewritten because they had been *encoding the
defect* — `reserve_flow_negative_test.dart` asserted that an "Oxygen
Concentrator 5L" was one-tap purchasable, which is precisely the behaviour the
inverted gate produced.

Two of those tests are worth calling out as durable rather than incidental:

- `functions/src/__tests__/schema-conformance.test.ts` reads the migrations and
  the routes as text and fails when they drift. It needs no database, so it can
  run anywhere — the reason the original drift went unnoticed is that any test
  that would have caught it required infrastructure nobody had.
- `test/models/equipment_catalog_gate_test.dart` asserts the assessment rule
  against the **shipped catalog**, not against invented fixtures. The old rule
  was defensible in the abstract and wrong on the data.

**What this does not mean:** the thresholds in `vital_classifier.dart` are a
*safe default*, not a clinical authority. Where the two old classifiers
disagreed, the reconciled file takes the more conservative bound. A clinician
must confirm every row.

---

## Still blocked on the owner — cannot be closed by editing code

| Item | Why it needs a person |
|---|---|
| Clinical sign-off on vital thresholds and the assessment device list | Only Housepital's clinical policy can settle these |
| Legal review for the regulated-domain module | Medical-device and health-data positioning in India |
| CI billing lock | Until it clears, **no test result from this repo has independent attestation**, including every figure in this document |
| A deployed backend + real Razorpay key | The payment path is now correct in code and still unexercised end-to-end |
| An issue tracker and a named release authority | The release module's Reject rests partly on there being no one accountable for the go/no-go |
| Designer's vector for the app icon | |

---

## The recommendation

Do not ship publicly. The code-side defects are closed, but the two things that
would make that claim *checkable* — a CI run that actually executes, and a
backend the app can actually reach — are both still outstanding, and this
document is written by the same party that wrote the fixes.

An external audit is the right next step, and it should be given this file
alongside the 25 module reports rather than instead of them.
