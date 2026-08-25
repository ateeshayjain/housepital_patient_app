# Round 5 — re-verification of the round-4 Fail rows

**Date:** 2026-08-25
**Baseline audited by round 4:** commit `9127713`
**Code re-verified against:** `main` after PRs #18, #19 (app) and #2, #3 (backend)
**Method:** mechanical partition, verified by hand where it mattered. No module
report was rewritten; this is a delta against the existing 25.

---

## The headline

| | Fail rows |
|---|---|
| Round 4 recorded | **685** |
| Candidates for **closed** — subject matches a fix that was made and tested | **107** |
| **Still open** | **578** |

If you take one number from this document, take 578. The four merged PRs
closed roughly **16%** of the recorded Fail rows.

That is not a disappointing result; it is the correct one, and it is the reason
this re-verification was worth doing before handing anything to an external
auditor. The fixes were selected by *harm*, not by count — they were the
defects that could take money, injure someone, or state a falsehood. Those are
a small fraction of an audit's rows and almost all of its risk. Closing them
does not move the row count much, and a report that implied otherwise would be
the same kind of false comfort the audits keep finding in the product.

---

## How each row was classified

Fail-closed throughout: **a finding is open unless positively shown otherwise.**

1. Enumerate every file changed since the round-4 baseline (44 in the app,
   plus the backend routes, migrations and scripts). This is ground truth from
   `git diff`, not inference.
2. A Fail row citing **no changed file** cannot have been fixed by these
   changes. Still open, no further analysis.
3. A Fail row citing a changed file is a *candidate* only. It is matched
   against the list of fixes actually made, subject by subject.
4. A row that cites a changed file but whose subject was never addressed is
   **still open** — touching a file does not fix everything in it.

| Class | Count | Verdict |
|---|---|---|
| Subject matches a verified fix | 107 | Closed (candidate) |
| Cites a changed file, subject not addressed | 182 | **Open** |
| Cites only unchanged files | 131 | **Open** |
| Cites no file — process, policy, evidence | 265 | **Open** |

---

## What was actually closed

| Fix | Fail rows it addresses |
|---|---|
| session/quarantine (wave 1) | 25 |
| staff profile fabrication | 22 |
| Log.sink -> Crashlytics | 12 |
| verifyPatientAccess | 7 |
| splash 2s / startup | 7 |
| money units (rupees/paise) | 4 |
| glass contrast / blur | 3 |
| android receivers/<queries> | 3 |
| terms/privacy TLS | 3 |
| API_BASE_URL dart-define | 3 |
| EXIF GPS | 3 |
| SCHEDULE_EXACT_ALARM | 3 |
| vital classifier unified | 3 |
| notification ID overflow | 2 |
| backend schema drift | 2 |
| demo overlay ate taps | 1 |
| vitals per-chart sample | 1 |
| createOrder field name | 1 |
| needsAssessment inverted | 1 |
| false success messages | 1 |

Every one carries a regression test, and the tests are named for the defect
rather than the function.

---

## Two corrections to the method itself

**The first pass was wrong, and wrong in the flattering direction.** It tried
to auto-close rows by grepping for the code they quoted and treating "snippet
no longer found" as evidence of a fix. That produced 103 "closed" rows —
including one that reported `IgnorePointer` as *gone* from the demo banner,
when adding `IgnorePointer` was the fix. Absence of a grep match is not
evidence of anything; line numbers shift, files move, and prose gets matched as
code. The method was replaced with the git-diff partition above, which cannot
close a row for a file nobody touched.

**The classifier repeated the exact bug it was classifying.** The pattern for
the assistant finding was `bleeding|din|...` — unanchored, so `din` matched
"rea**din**g", "fin**din**g" and "inclu**din**g", and the fix appeared to
address 65 rows instead of 3. That is the same defect as
`RegExp(r'duty|din|...')` matching "blee**din**g", written by the same author,
one day later, while documenting it. Short unanchored alternation is worth
treating as a code smell on sight.

---

## What "still open" contains

The 578 are not 578 distinct problems. The largest recurring root causes:

| Root cause | Fail rows mentioning it |
|---|---|
| CI has never executed a step (billing lock) | 51 |
| Privacy / consent / retention artefacts absent | 54 |
| Legal or regulatory positioning unreviewed | 56 |
| No reachable backend | 39 |
| No monitoring, alerting or dashboards | 37 |
| No real Razorpay key | 31 |
| No runbook, on-call or incident process | 27 |
| No named owner or release authority | 26 |
| Untested code paths | 45 |

Most of these cannot be closed by editing code, and several cannot be closed
by me at all. The genuinely code-shaped remainder — accessibility contrast and
text scaling, `TextTheme` adoption, default-path blur cost, missing backend
routes, data lifecycle — is real work and is enumerated in the module reports
that already exist.

---

## Recommendation, unchanged

Do not ship publicly. The severity profile has improved substantially; the row
count has not, and neither has the evidence base. Nothing here has been
independently attested, because CI still cannot run a step, and this document
was written by the same party that wrote the fixes.
