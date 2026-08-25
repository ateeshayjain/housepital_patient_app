# Handover — Housepital Patient App

**Date:** 2026-08-25
**Verified for this document:** 1,983 app tests / 0 failures; 85 backend tests;
39 screens × 4 passes in the overflow sweep; 5 accepted route gaps; migrations
001→006 apply clean to MySQL 8. Every figure re-derived from a run or a file
before this file was written, not carried over from an earlier note.
**State:** `main` in both repos is green locally, unmerged work: none.
**Recommendation: do not ship publicly yet.** Reasons below, and none of them
are code.

---

## 1. Read these three things first, in this order

1. **`docs/audits/round5/RE_VERIFICATION.md`** — the current, honest count of
   what is fixed and what is not. **578 of 685 audit Fail rows are still
   open.** Every other number in this repo should be read after that one.
2. **`docs/audits/round4/SYNTHESIS.md`** — what the four audit rounds each
   found, and why each round found the previous round's fixes insufficient.
3. **`CLAUDE.md`** — the contracts that are load-bearing. Several encode
   decisions that look wrong until you know the history (white-on-orange at
   2.33:1, manpower prices shown, the five-tab nav).

---

## 2. The single most important thing to fix

**CI has never executed a step.** Forty-seven runs; every one fails in about
two seconds with:

> *The job was not started because recent account payments have failed or your
> spending limit needs to be increased.*

This is a billing problem, not a test problem. But its consequence is that
**every quality figure in this repository is a self-report from a developer
machine** — including "1,983 tests pass", which is true and unattested.

Until it clears, no reviewer can distinguish a repo with 1,983 passing tests
from one that claims to have them. Clear the billing lock before anything
else; it converts the whole test suite from an assertion into evidence.

---

## 3. What was fixed, briefly

Four audit rounds, five merged PR sets. Selected by **harm**, not by count —
which is why the row count moved only 16%.

| Class | Examples |
|---|---|
| Could take money | Rupees/paise mismatch (a ₹5,000 cart charged ₹50); `createOrder` read a field the backend never sends, so no real payment could complete |
| Could harm someone | Fabricated `police_verified: true` on caregiver profiles; an inverted device gate that cleared every ventilator and concentrator; "bleeding ho raha hai" routed to staff attendance; EXIF GPS on every uploaded photo; medication reminder IDs colliding so a drug was silently never scheduled |
| Could not be trusted | Four disagreeing vital-sign classifiers; the only caregiver-removal control wired to a 404; four surfaces reporting success for actions that never happened |
| Structural | Cross-patient data access via an auth guard that failed open; 20 backend queries against columns that never existed |

Full detail in the PR bodies (#18–#21 app, #2–#4 backend) and the round-4
module reports.

---

## 4. What is deliberately left open, and why

### Blocked on a person, not on code

| Item | Who |
|---|---|
| Clinical sign-off on the vital-sign thresholds and the assessment device list | A clinician. The current values take the **more conservative** bound wherever the old classifiers disagreed — a safe default, explicitly **not** clinical authority. |
| Legal review: medical-device positioning, DPDP, health-data handling | Counsel |
| CI billing lock | Account owner |
| A deployed backend and a real Razorpay key | Ops |
| An issue tracker and a **named release authority** | You. The release module's Reject rests partly on nobody being accountable for the go/no-go. |
| App icon vector | Designer |

### Blocked on a product decision

Five client API calls still have no route. They are listed as
`ACCEPTED_MISSING` in `route-conformance.test.ts` with two guards: the list
cannot silently grow, and an entry must be deleted once its route exists.

- `GET /services/:id/slots` — needs a staff-availability model
- `GET /patients/:id/equipment-orders`, `POST /equipment-orders/:id/return` —
  needs a decision on whether `bookings` or `equipment_deployments` is
  authoritative
- `GET /articles`, `GET /articles/:id` — no CMS; the app bundles its articles
  and they work offline

### Code-shaped work that remains

Real, tractable, and enumerated in the round-4 module reports:
accessibility beyond contrast (964 literal `fontSize:` and zero `textTheme.`
references), the default-path blur cost (3–4 `BackdropFilter`s per root tab),
data-lifecycle retention and erasure, upgrade path, notifications, and the
trust-and-safety **policy** — which is a business document, not code.

---

## 5. Before you deploy anything

**The migrations and the backend code ship together or not at all.**

```bash
mysql -h <host> -u <user> -p housepital < sql/005_schema_code_reconciliation.sql
mysql -h <host> -u <user> -p housepital < sql/006_missing_route_tables.sql
```

Both are guarded and re-runnable — verified against MySQL 8, where 001→006
apply clean (27 tables, 375 columns) and a re-run is a no-op. **Neither has
ever run against production data.** Verify against a copy first.

`main` on the backend already contains routes that query columns 005 and 006
add. Deploying the code without the migrations replaces one set of
unknown-column errors with another.

Then, before every backend deploy:

```bash
cd housepital-backend && ./scripts/check_schema_drift.sh
```

Exit 0 = the routes and the migrations agree. **Exit 1 = do not deploy.**

---

## 6. Four checks that exist because the usual ones could not run

These need **no database and no network**. That is the point: the reason all
four classes of defect survived is that every check capable of catching them
required infrastructure nobody had.

| Check | Catches |
|---|---|
| `functions/src/__tests__/schema-conformance.test.ts` | A query against a column the migrations do not create |
| `functions/src/__tests__/route-conformance.test.ts` | A client call with no backend route |
| `functions/src/__tests__/vital-classifier.test.ts` | The Dart and TypeScript threshold tables drifting apart |
| `scripts/check_design_consistency.sh` | Banned colour and component patterns in `lib/screens` |

Plus the 39-screen × 4-pass overflow sweep, whose fourth pass (200% text) is
the **only** evidence behind the 2.0× text clamp in `main.dart`. Deleting that
pass turns a measured limitation into a claim.

---

## 7. Things that will look like bugs and are not

- **Staff profiles show no verification badges.** Correct. The app cannot
  verify anyone, and the fallback used to invent a police check. Empty is
  truthful.
- **The attendance grid carries a "Sample attendance" banner.** Every cell is
  generated locally; there is no attendance feed yet.
- **Oxygen concentrators and ventilators do not add to the cart in one tap.**
  They route to the assessment flow. BiPAP *masks* do add freely — that is the
  right way round.
- **"Rating submitted!" now says the feedback stayed on the device.** It did.
  Nothing was ever sent.
- **The demo-data pill is up constantly.** `api.housepital.in` does not
  resolve, so every provider serves bundled sample data.

---

## 8. A pattern worth knowing before you write tests here

Five of the checks written across rounds 4 and 5 found bugs **in themselves**
before they found anything in the product:

- a payment fake that returned `{'order_id': ...}` — the client's *imagined*
  field name, not the backend's actual response. That is precisely why the
  bug survived four rounds of review.
- a SQL parser truncated by a semicolon inside a comment
- a Dart/TypeScript differ that ran past the end of one function into the next
- a keyword blacklist that deleted two real column names
- a source-text assertion that failed on the *documentation of the fix it was
  testing*

The common thread: each was built from what the author expected rather than
from the artefact. **A fake built from the code under test can only ever
confirm that code.** Build it from the contract.

---

## 9. Honest limitations of this handover

This document, the audits, the fixes and the tests were all produced by the
same party. Rounds 1–4 each found the previous round's fixes insufficient,
which is evidence the process works — and also evidence that a single reviewer
misses things repeatedly.

**An external audit is the right next step**, and it should be given the
25 module reports and `RE_VERIFICATION.md` *alongside* this file, not instead
of it.
