# CI/CD & Software Supply Chain — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** CI/CD & Software Supply Chain (control family CICD) ·
**Scope:** source review of the repository, its GitHub Actions configuration and run history,
its lockfiles and signing configuration, and the two backend repositories (see Limitations)

---

## Applicability

MASTER-2.05 marks this module ALWAYS-REQUIRED, and the checklist's own applicability line
("Every project that builds or deploys software, including client-only apps and small teams")
admits no exemption for a solo-maintainer project. The repository builds and ships software:
it has a GitHub Actions workflow (`.github/workflows/ci.yml`), an Android and an iOS build
target, a Firebase Cloud Function deployed from `functions/`, and two backend code bases
(`../housepital-backend`, `../housepital-api`) that the app is intended to talk to. The
module applies in full.

**This module has never been audited.** No round-2 or round-3 report exists for it
(`docs/audits/` and `docs/audits/round3/` contain eleven other modules), so there is no
prior-round status table. This is a first look, and it was conducted systematically against
all 38 controls rather than assuming earlier rounds covered the ground.

Three round-3 carried-open items fall inside this module's scope and are re-verified below
rather than assumed: the Android debug keystore (CICD-6.01), the 40.3 MiB of unreferenced
assets (CICD-4.03), and the absent dSYM phase (CICD-4.03).

---

## The finding that governs this report

**The CI pipeline has never executed a single step.** Every one of the 47 workflow runs in
the repository's entire history — first run 2026-03-26, last run 2026-06-15 — failed, and
all failed for the same reason before any step started.

```
$ gh run list --limit 200 --json conclusion --jq '[.[].conclusion]|group_by(.)|map({k:.[0],n:length})'
[{"k":"failure","n":47}]

$ gh api repos/ateeshayjain/housepital_patient_app/actions/runs/27549359363/jobs \
    --jq '.jobs[] | "job=\(.name) concl=\(.conclusion) steps=\(.steps|length)"'
job=test concl=failure id=81431162165 steps=0

$ gh api repos/ateeshayjain/housepital_patient_app/check-runs/81431162165/annotations --jq '.[].message'
The job was not started because your account is locked due to a billing issue.
```

The same annotation is returned for runs sampled across the whole span — `23592105723`
(2026-03-26), `26567592320` (the single `pull_request` run, 2026-05-28), `27003391150`
(2026-06-05), `27113182750` (2026-06-08), `27549359363` (2026-06-15). Every job reports
`steps: 0`. Job durations are 3–12 seconds, consistent with a job that was refused, not one
that ran and failed.

The consequence is that **none** of the gates this repository relies on has ever run in CI:
not `flutter analyze` (ci.yml:34), not `scripts/check_design_consistency.sh` (ci.yml:41), not
the 1,819-test suite (ci.yml:55), not the 50 % coverage gate (ci.yml:66–79), not
`flutter build web --release` (ci.yml:102). The overflow, dark-mode and i18n guards named in
`CLAUDE.md` are test files under `test/` (`test/screens/overflow_smoke_test.dart`,
`test/widgets/dark_mode_test.dart`, `test/utils/i18n_sync_test.dart` — all present) and are
therefore covered by the `flutter test` step, which has never run. **All of them are hand-run
only.** The central results cited in the audit brief (analyze clean, design gate passes, 1,819
tests pass) are developer-machine results, not pipeline results.

This is not a case of gates being weak. It is a case of gates that are written down, badged in
`README.md:3`, cited as mandatory in `CONTRIBUTING.md:38-42`, and have never once executed.

A second, structurally independent finding compounds it: **the workflow would not have gated
this branch even if it could run.** `ci.yml:3-7` triggers only on `push` to `main` and
`pull_request` targeting `main`. The audited work sits on `fix/five-tab-nav`, 12 commits ahead
of `origin/main`, with no open PR (`gh pr list --state all` shows PRs #1–#17; none is for this
branch). No CI run exists for `fix/five-tab-nav`.

---

## Control results

### 1. Source and change control

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-1.01** Authoritative repositories, owners, branch protections, required reviews, emergency bypass documented | **Fail** | `CONTRIBUTING.md:9` ("Never push directly to `main`"), `:38-42` (PRs must pass CI), `:44` ("at least one approval required before merge") document the intent. None of it exists on the platform: `gh api .../branches/main/protection` → `404 Branch not protected`; `gh api .../rulesets` → `[]`; all 12 branches report `protected=false`. No `CODEOWNERS` file anywhere. No emergency-bypass authority named. `../housepital-api` (the Laravel staff API, with `composer.json` + a 311 KB `composer.lock`) is **not in version control at all** — `git rev-parse` in that directory returns `fatal: not a git repository`. | Impact: written policy provides no assurance; a reviewer reading CONTRIBUTING.md would materially misjudge the repo's controls. One of three code bases has no history, no review path, and no recovery point. Mitigation: `git init` + push `housepital-api`; add CODEOWNERS; name a bypass authority. Owner: OWNER-TBD (sole admin `ateeshayjain`). Due: before first release. |
| **CICD-1.02** Protected branches require passing checks and prevent unreviewed force push, history rewrite, or direct release changes | **Fail** | No protection and no rulesets (above). 189 commits on `origin/main`, 11 of them merge commits; the **last 17 commits on `main` were pushed directly**, with no merge commit and no PR, from 2026-06-05 (`434fb40`) through 2026-06-15 (`803124d`). Nothing prevents force push or history rewrite on `main`. | Impact: `main` can be rewritten silently; there is no point in history that is provably reviewed. Mitigation: enable a ruleset on `main` requiring PR + status checks + linear history. Owner: OWNER-TBD. Due: before first release. |
| **CICD-1.03** Commits, tags, release branches, and generated source identify the reviewed change and responsible actor | **Fail** | `git log --format="%h %G? %an <%ae>"` — every one of the last 15 commits returns `N` (no signature). Author email on all of them is `ateeshayjain@LTHYD-62310775.local`, a machine hostname, not a GitHub-verified address. `git tag -l` → empty (0 tags). `gh release list` → empty. No release branch convention exists. | Impact: no artifact can be tied to a commit, and no commit can be tied to a verified actor. Provenance is unestablishable end to end. Mitigation: enable commit signing; set `user.email` to the GitHub-verified address; tag every submitted build. Owner: OWNER-TBD. Due: before first release. |
| **CICD-1.04** Repository access follows least privilege, MFA, timely offboarding, periodic access review | **Warning** | `gh api .../collaborators` returns exactly one principal: `ateeshayjain` with `admin: true`. Repository is private (`"visibility":"private"`). MFA state for a personal account is not exposed by the API and could not be verified — see BLOCKED-OWNER. No access-review record exists in the repo. | Impact: least privilege is trivially satisfied by there being one person, but that same fact removes separation of duties everywhere else in this report. MFA unverified. Mitigation: confirm MFA on the GitHub account and the Apple/Google/Firebase/Razorpay accounts; record a review date. Owner: OWNER-TBD. Due: before first release. |
| **CICD-1.05** Sensitive changes to workflows, signing, permissions, dependencies, security controls, infrastructure receive designated review | **Fail** | No `CODEOWNERS`. Zero reviews on every PR sampled: `gh pr view 10/12/16 --json reviews,reviewDecision` returns `"reviews":[]` and an empty `reviewDecision` for all three; `mergedBy` equals `author` (`ateeshayjain`) in every case. `ci.yml` was last modified in `4ccdcde` (2026-06-11) with no review. Dependency changes (`pubspec.yaml`) have never been reviewed by a second party. | Impact: the workflow file, the signing configuration and the dependency set can all be changed by one actor with no second pair of eyes — the classic supply-chain single point of failure. Mitigation: at minimum, require a self-checklist commit trailer for workflow/signing/dependency changes until a second reviewer exists. Owner: OWNER-TBD. Due: before first release. |

### 2. CI environment and credentials

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-2.01** Runners isolated, patched, ephemeral, do not trust unreviewed fork code with production secrets | **Pass** | `ci.yml:11` `runs-on: ubuntu-latest` — GitHub-hosted, ephemeral, vendor-patched. `ci.yml:6` uses `pull_request`, **not** `pull_request_target`, so fork code never runs with repository context. `grep -n "secrets\." .github/workflows/ci.yml` returns nothing: the workflow references no secrets at all, so no secret can reach fork code. The design is sound; note that it has never actually executed (see the governing finding), so this is a configuration-level pass. | — |
| **CICD-2.02** Secrets use a managed store, least-privilege scopes, environment separation, masked logs, rotation, revocation, expiry | **Fail** | CI uses no managed secret store — the only credential-shaped value is the hardcoded plaintext `rzp_test_ci_dummy_key` at `ci.yml:55` (deliberately a non-secret test value, per the brief; correct in itself). The two `--dart-define` inputs the app actually needs have **no CI path at all**: `RAZORPAY_KEY` (`lib/config/constants.dart:23-26`) and `ASSISTANT_API_URL` (`:10-11`). `docs/DEPLOYMENT_GUIDE.md:290` prescribes supplying the live key on the command line — `flutter build apk --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXXXXX` — which writes a live payment credential into shell history and into any build log that echoes the command. No rotation, revocation or expiry policy for any credential. `../housepital-api/.env` holds live values (`APP_KEY` and `DB_PASSWORD` non-empty) on an unversioned working tree with no managed store. **The one control that is right:** `functions/index.js:18,21,114,153` uses `defineSecret("ANTHROPIC_API_KEY")` and binds it per-function, so the Anthropic key never enters the client or the repo — consistent with the brief's statement and re-verified here (`git grep -l "sk-ant-"` across all 231 refs returns only audit-report and README prose, no key material). | Impact: a live Razorpay key is destined for shell history and unmasked build output; there is no store from which to rotate it. Mitigation: move `RAZORPAY_KEY`/`ASSISTANT_API_URL` into GitHub Actions secrets (or a release script reading from 1Password/Doppler) and never pass them literally on an interactive command line. Owner: OWNER-TBD. Due: before the first build that carries a live key. |
| **CICD-2.03** Third-party actions/plugins/build images pinned by immutable version or digest and reviewed before updates | **Fail** | Every action is pinned to a **mutable major tag**, not a digest: `actions/checkout@v4` (ci.yml:14), `subosito/flutter-action@v2` (:16), `actions/upload-artifact@v4` (:86 and :107). `gh api .../actions/permissions` → `{"enabled":true,"allowed_actions":"all","sha_pinning_required":false}`. `subosito/flutter-action` is a third-party (non-GitHub-owned) action with write access to the build environment. No review record for any action version. | Impact: a compromise or malicious retag of `subosito/flutter-action@v2` would execute in the build that produces the shipped bundle. Mitigation: pin all four uses to full commit SHAs; enable `sha_pinning_required`; restrict `allowed_actions`. Owner: OWNER-TBD. Due: before CI is unblocked and first used for a release. |
| **CICD-2.04** Workflow permissions, tokens, cloud roles, package publication, signing access, deployment authority minimal and auditable | **Warning** | Credit where due: `gh api .../actions/permissions/workflow` → `{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}` — the `GITHUB_TOKEN` is read-only by default and cannot self-approve, which is the correct posture even though `ci.yml` declares no explicit `permissions:` block (`grep -n "permissions:"` → none). Everything else fails the "minimal and auditable" test: signing access is one macOS keychain and one universally-known Android debug keystore (CICD-6.01); deployment authority is the owner's personal `firebase`/`gcloud` login; there is no publication automation and therefore no scoped publication credential; none of it is auditable. | Impact: token scope is fine; human authority is unbounded and unlogged. Mitigation: add an explicit `permissions: contents: read` block; move Firebase deploys to a service account with a recorded role. Owner: OWNER-TBD. Due: before first release. |
| **CICD-2.05** Compromise playbooks cover runner, source-control, package, signing, and deployment credential rotation | **Fail** | The only rotation text in the repository is `docs/DEPLOYMENT_GUIDE.md:437-444`, covering the Razorpay key alone — and it rests on a control that does not exist: *"If a production Razorpay key is ever committed by mistake (CI lint should catch this), rotate immediately…"*. There is no CI lint, no secret scanning, and no CI at all (governing finding). Nothing covers runner compromise, GitHub token compromise, Firebase secret compromise, signing-key compromise, or Play/App Store credential compromise. | Impact: on any compromise the response would be improvised, and the one written playbook instructs the reader to rely on a detective control that is absent. Mitigation: write a one-page rotation playbook per credential class and delete the false CI-lint claim. Owner: OWNER-TBD. Due: before first release. |

### 3. Dependencies and third-party components

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-3.01** Direct and transitive dependencies inventoried through lockfiles and an SBOM with source, version, license, integrity | **Fail** | **Dart is good.** `pubspec.lock` is committed and complete: **162 packages — 33 direct main, 4 direct dev, 125 transitive**; 157 from `hosted`, 5 from `sdk`, **0 git and 0 path dependencies**; all 157 hosted entries carry a `sha256:` and **none is null**. `sdks: dart ">=3.11.0 <4.0.0", flutter ">=3.38.4"` (pubspec.lock:1285-1287). **iOS is good.** `ios/Podfile.lock` is committed with per-pod `SPEC CHECKSUMS`, a `PODFILE CHECKSUM`, and `COCOAPODS: 1.16.2`. **Android is not.** `android/.gitignore:1` ignores `gradle-wrapper.jar`, so the wrapper binary that bootstraps every Android build is absent from version control, and `android/gradle/wrapper/gradle-wrapper.properties` sets `distributionUrl=…gradle-8.14-all.zip` with **no `distributionSha256Sum`** — the Gradle distribution is fetched over the network and never verified. **Node is not.** `git ls-files functions` returns exactly four files (`.gitignore`, `README.md`, `index.js`, `package.json`) — **there is no `package-lock.json`**, so the deployed Cloud Function's dependencies (`@anthropic-ai/sdk: ^0.71.0`, `firebase-functions: ^6.4.0`) resolve freshly, and differently, on every deploy. **No SBOM exists** anywhere in the repo or either backend (`find` for `*sbom*`/`*cyclonedx*`/`*spdx*` → nothing). No license inventory. | Impact: two of four ecosystems have no reproducible inventory; the Function that holds the Anthropic key installs unpinned transitive npm code at deploy time. No SBOM means no way to answer "are we affected?" when an advisory lands. Mitigation: commit `functions/package-lock.json`; add `distributionSha256Sum`; un-ignore `gradle-wrapper.jar`; generate a CycloneDX SBOM per release. Owner: OWNER-TBD. Due: before first release. |
| **CICD-3.02** New dependencies receive necessity, maintainer, security, privacy, license, update, and abandonment review | **Fail** | No dependency-review record exists in `CONTRIBUTING.md`, `docs/`, or any PR. The gap is demonstrated concretely: **`flutter_markdown` is discontinued upstream and is still a direct dependency** at `pubspec.yaml:69` (`flutter_markdown: ^0.7.0`, resolved to 0.7.7+1). Its own shipped README says so verbatim — *"**This project has been discontinued**, and will not receive further updates"* — and its CHANGELOG announced it two releases before the pinned one (`0.7.6+2`: "Updates README to indicate that this package will be discontinued"). This is the package the toolchain reports as "1 package is discontinued". It renders the Care Guides article bodies (`pubspec.yaml:68` comment). Nothing in the repository records the abandonment or a migration plan. | Impact: a user-facing rendering path depends on unmaintained code that will not receive security or Flutter-compatibility fixes; a future Flutter SDK bump can strand it. Mitigation: record the abandonment in `docs/KNOWN_ISSUES.md` with an owner and a migration target (the upstream issue flutter/flutter#162966 tracks community alternatives); adopt a written intake review for new packages. Owner: OWNER-TBD. Due: next dependency-touching change. |
| **CICD-3.03** Dependency updates run compatibility and regression tests and are not merged solely because a bot opened them | **Warning** | No update automation exists at all — no `.github/dependabot.yml`, no `renovate.json` (`find` → nothing), so the "merged solely because a bot opened it" hazard is vacuously absent. But the positive half of the requirement is unmet: there is no documented update cadence, and the regression suite that would validate an update has never run in the pipeline. All 37 direct dependencies use caret ranges, so `flutter pub upgrade` can move 125 transitive packages with only hand-run tests behind it. | Impact: dependency drift is unmonitored and un-gated. Mitigation: enable Dependabot on `pubspec.yaml` + `functions/package.json` once CI can run, so updates land as PRs that must pass the suite. Owner: OWNER-TBD. Due: after CI is unblocked. |
| **CICD-3.04** Known vulnerabilities have severity, exploitability, affected-path, mitigation, owner, and remediation deadline | **Fail** | No scanning of any kind. `gh api .../vulnerability-alerts` → `404 "Vulnerability alerts are disabled."`; `gh api .../automated-security-fixes` → `{"enabled":false,"paused":false}`; `security_and_analysis` on the repo object is null. `ci.yml` contains no `dart pub audit`/OSV step, no `npm audit`, no CodeQL. `docs/KNOWN_ISSUES.md` has a `## Build / CI` section (CI-01/02/03) but no dependency-vulnerability register. Whether any of the 162 Dart packages, the `functions/` npm tree, or `../housepital-api`'s `composer.lock` currently carries an advisory is **unverified** — there is no mechanism that would tell anyone. | Impact: a known-vulnerable transitive dependency would ship undetected in a healthcare app handling patient data. Mitigation: enable Dependabot alerts (one click, free on private repos); add an OSV/`npm audit` step with a blocking threshold. Owner: OWNER-TBD. Due: before first release. |
| **CICD-3.05** Apple third-party SDK privacy manifests and signatures, data collection, required-reason APIs, update provenance verified | **Warning** | 24 `PrivacyInfo.xcprivacy` files are present under `ios/Pods` — the whole Firebase/abseil/gRPC/nanopb/leveldb/Promises/GTMSessionFetcher set, plus `razorpay-pod`'s inside both slices of `RazorpayStandard.xcframework`. `image_picker_ios`, `share_plus`, `url_launcher_ios`, `flutter_local_notifications`, `sqflite_darwin` and `shared_preferences_foundation` each ship one in the resolved version. **No manifest was found** in the resolved `path_provider_foundation 2.6.0`, `speech_to_text 7.4.0`, `flutter_tts 4.2.5`, or `printing 5.14.3`. **The app itself has no privacy manifest** — `find -L ios/Runner -name "*.xcprivacy"` returns nothing, and `ios/Runner/` contains no `PrivacyInfo.xcprivacy`. There is also **no `.entitlements` file anywhere under `ios/`**, despite FCM push being a shipped feature. SDK *signature* verification and required-reason-API declarations can only be checked against a built `.ipa`, which this source-only audit cannot produce — stated plainly as **unverified**, not N/A. | Impact: App Store submission will be rejected or warned for the missing app-level manifest; unmanifested SDKs may trip required-reason checks. Overlaps the Release/Submission module — flagged here as a supply-chain provenance gap, not re-litigated as a store issue. Mitigation: add `ios/Runner/PrivacyInfo.xcprivacy`; verify the four unmanifested plugins against Apple's list at their shipped versions. Owner: OWNER-TBD. Due: before first TestFlight upload. |

### 4. Build integrity and reproducibility

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-4.01** Release builds start from a clean, identified source state using versioned toolchains, SDKs, configuration, and dependency resolution | **Fail** | The toolchain pin itself is genuinely good and worth crediting: `ci.yml:22` pins `flutter-version: '3.41.2'` with a comment explaining why lockstep matters; the local machine matches exactly (`flutter --version` → `Flutter 3.41.2 • stable`, engine `d96704abcce`, Dart 3.11.0) and `.metadata` records `revision: "90673a4eef275d1a6692c26ac80d6d746d41a73a"`. But **there is no release build anywhere in the pipeline.** The only build step is `flutter build web --release` (ci.yml:102) — the web bundle is not the shipped artifact — and it has never executed. iOS and Android release artifacts are built by hand on the owner's Mac, from a working tree, on a branch (`fix/five-tab-nav`) that is not `main`. Nothing enforces the toolchain version locally either: no `.fvmrc`, no `.fvm/`, no `.tool-versions` (all absent). | Impact: the artifact that reaches users is produced by an unrecorded, unrepeatable, manual process from an un-merged branch. Mitigation: add an iOS/Android build job; build releases from a tagged commit only. Owner: OWNER-TBD. Due: before first release. |
| **CICD-4.02** Generated projects, code, schemas, assets, privacy manifests, entitlements, and version values are reproducible and checked for drift | **Fail** | `pubspec.yaml:4` reads `version: 1.0.0+1` and **has never been incremented across 189 commits on `main` plus 12 on this branch** — `docs/DEPLOYMENT_GUIDE.md:466` lists "Version number bumped in pubspec.yaml" as a manual checklist item, which is the whole control. No drift check exists for any generated artefact: `lib/config/firebase_options.dart` and `ios/Runner/GeneratedPluginRegistrant.m` are generated and committed with no regeneration comparison; `ios/Podfile.lock` and `pubspec.lock` are never verified as up to date with their manifests in any automated step. No entitlements file exists to check (CICD-3.05). No privacy manifest exists to check. | Impact: build/version collisions on submission; silent divergence between a manifest and its generated output. Mitigation: bump version from CI or a release script; add a `git diff --exit-code` drift check after `flutter pub get` / `pod install`. Owner: OWNER-TBD. Due: before first release. |
| **CICD-4.03** Debug/test code, development endpoints, sample data, private symbols, and unused assets do not enter the release artifact | **Fail** | **Sample data ships and is the app's actual data source.** `lib/data/demo_data.dart` (28 KB) and `lib/data/demo_articles.dart` (60 KB) are in `lib/`, therefore compiled into every release binary, and per the brief the app "ships a demo-data build" with `DemoData` fallbacks serving every provider. **A dev endpoint ships**: `lib/config/constants.dart:3` `apiBaseUrl = 'https://api.housepital.in/v1'`, a host that does not resolve. **Unused assets ship, and the round-3 figure is confirmed, not merely repeated**: of 448 files under `assets/images`, a name-reference scan against `lib/` and both catalog JSONs finds **206 referenced and 241 unreferenced, totalling 42,547,432 bytes = 40.5 MiB**; they ship regardless because `pubspec.yaml:85` declares `assets/images/products/` as a whole directory. **Symbols**: no dSYM upload phase exists (round-3 carried-open item, re-confirmed — `docs/DEPLOYMENT_GUIDE.md:438` flags it as a manual "verify" and nothing automates it). No CI check exists for any of these. | Impact: ~40 MiB of dead weight in a Delhi-NCR download, demo data indistinguishable from real data at the binary level, and unusable iOS crash reports. Mitigation: enumerate `assets/images/products/` explicitly or prune; add a bundle-size and asset-reference check to CI. Owner: OWNER-TBD. Due: before first release. |
| **CICD-4.04** Artifacts include version, build, commit, environment, architecture, and provenance metadata sufficient to trace their origin | **Fail** | `version: 1.0.0+1` is static (above). No commit SHA is baked into the binary — `lib/config/constants.dart` carries no build metadata, and `package_info_plus` is not a dependency (absent from `pubspec.yaml` and from all 162 lockfile entries). There is no build-info surface in the app. CI artifacts are labelled only `coverage-${{ github.run_id }}` and `ci-debug-${{ github.run_id }}` (ci.yml:90, 111), and zero have ever been produced. With no tags and no releases (CICD-1.03), an artifact in the field cannot be traced to a commit by any means. | Impact: a crash report or a user bug report cannot be mapped to source. Mitigation: inject `--dart-define=GIT_SHA=$(git rev-parse HEAD)` and surface it on the More/About screen. Owner: OWNER-TBD. Due: before first release. |
| **CICD-4.05** Reproducibility or equivalence checks detect unexpected differences between nominally identical release builds where feasible | **Warning** | Nothing exists — no build hashing, no artifact digest record, no rebuild comparison. The control's "where feasible" qualifier is genuine relief here: Flutter AOT release builds are not bit-reproducible without dedicated effort, so a strict equivalence check is not a reasonable near-term ask for this project. What *is* feasible and still absent is recording a SHA-256 of every shipped artifact alongside its commit. | Impact: a substituted or tampered artifact could not be detected after the fact. Mitigation: record `shasum -a 256` of every IPA/AAB in a release log next to its tag. Owner: OWNER-TBD. Due: first release. |

### 5. Automated quality and security gates

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-5.01** Required unit, integration, contract, UI/smoke, accessibility, migration, and platform tests run at the appropriate pipeline stage | **Fail** | The workflow declares the right stages in the right order — analyze (ci.yml:34) → design gate (:41) → tests (:55) → coverage (:66) → build (:102) — and the test corpus is real (101 `*_test.dart` files; the three named guards all exist). **None has ever run.** See the governing finding: 47/47 runs, `steps: 0`, "account is locked due to a billing issue". Beyond that: there is no integration or contract test against either backend, no on-device UI/smoke stage, and no platform (iOS/Android) build or test stage at all. | Impact: the entire quality argument for this codebase rests on results a single developer reports from a single machine, with no independent reproduction. This is the release blocker from which most others follow. Mitigation: resolve the GitHub billing lock, or move CI to a runner that will execute; until then, no build should be treated as gated. Owner: OWNER-TBD. Due: **immediately — blocks release.** |
| **CICD-5.02** Static analysis, secret scanning, dependency scanning, license checks, configuration validation, and artifact scanning have blocking thresholds | **Fail** | Of six required scan classes, **one and a half are declared and none runs.** Static analysis is present but deliberately de-fanged: `ci.yml:34` `flutter analyze --no-fatal-warnings --no-fatal-infos`, documented at `docs/KNOWN_ISSUES.md:57` (CI-03) as blocked on a 284-issue backlog. The design gate (`scripts/check_design_consistency.sh`) is a real blocking check with `exit 1` on seven banned patterns — good design, never executed. A coverage threshold exists (`COVERAGE_THRESHOLD: "50.0"`, ci.yml:68) — never executed. **Absent entirely:** secret scanning (repo `security_and_analysis` is null), dependency scanning (alerts `404 disabled`), license checks, configuration validation (nothing validates `firestore.rules`/`storage.rules`), artifact scanning. `docs/DEPLOYMENT_GUIDE.md:439-441` asserts a CI lint would catch a committed live Razorpay key; **no such control exists.** | Impact: a committed live payment key, a vulnerable dependency, or a non-compiling security rule would all pass unnoticed. Mitigation: enable GitHub secret scanning + push protection and Dependabot alerts (both free, both one click); add `firebase deploy --only firestore:rules --dry-run` style validation. Owner: OWNER-TBD. Due: before first release. |
| **CICD-5.03** Flaky or quarantined checks have owner, issue, expiry, risk assessment, and visible release impact | **Fail** | The pipeline as a whole has been in a hard-failed state for its entire 82-day recorded life with no owner, no issue, no expiry and no risk assessment recorded anywhere. `docs/KNOWN_ISSUES.md` §Build/CI tracks three items (CI-01 tree-shake-icons flake, CI-02 Flutter pin, CI-03 analyzer strictness) — **none of them is the billing lock**, which is the only thing actually stopping the pipeline. The `README.md:3` CI badge renders the failing state to every reader with no accompanying explanation. | Impact: the one condition that invalidates every CI claim in the repo is the one condition not written down. Mitigation: add a `CI-04` row naming the billing lock, its owner and its remediation date; remove or annotate the badge until it is green. Owner: OWNER-TBD. Due: immediately. |
| **CICD-5.04** Pipeline results cannot be silently overridden; exceptions record actor, reason, evidence, approver, expiration | **Fail** | There is nothing to override because nothing blocks: no branch protection, no required checks (CICD-1.02). Demonstrated concretely — **PR #10 was merged with its `test` check at `FAILURE`**: `gh pr view 10 --json statusCheckRollup` → `[{"concl":"FAILURE","name":"test"}]`, `mergedBy: ateeshayjain`, `reviews: []`. No exception record exists for that merge or any other. The subsequent 17 commits bypassed PRs entirely. | Impact: failing checks have already been merged into `main` with no recorded justification, and the mechanism that allowed it is still open. Mitigation: require the `test` check on `main` once it can pass. Owner: OWNER-TBD. Due: before first release. |
| **CICD-5.05** Test reports and evidence are retained with the artifact for the required audit/support period | **Fail** | Retention is configured correctly in principle — `retention-days: 14` for coverage (ci.yml:94) and `7` for debug output (:115), uploaded on `if: always()` — but **zero artifacts have ever been produced**, so nothing has ever been retained. Worse, the run logs themselves are already gone: `gh run view 27549359363 --log-failed` → `log not found: 81431162165`, for the most recent run. There is no artifact to attach evidence to (CICD-4.04) and no release to attach it against (CICD-1.03). | Impact: no test evidence exists for any build, and none can be reconstructed. Mitigation: once CI runs, attach the coverage summary and test report to a tagged release rather than to an expiring run. Owner: OWNER-TBD. Due: first release. |

### 6. Signing, provenance, and publication

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-6.01** Signing identities, certificates, notarization credentials, package keys, and store roles are hardware/managed protected and access-controlled | **Fail** | **Confirmed, and it is a supply-chain control failure, not merely a release-hygiene one.** `android/app/build.gradle.kts:34-39`: `release { // TODO: Add your own signing config for the release build. / signingConfig = signingConfigs.getByName("debug") }`. No `key.properties` exists — verified absent at both `android/key.properties` and `android/app/key.properties`; `android/.gitignore:12` reserves the name. The Android debug keystore is `~/.android/debug.keystore` with the publicly documented alias `androiddebugkey` and password `android`, auto-generated identically on every Android developer machine in the world. **The signing key for this app's release build is therefore not a secret at all**: any third party can compile an APK that Android's package manager accepts as a signed update to `com.housepital.housepital_patient`, and any user who sideloads it gets it. On iOS, `ios/Runner.xcodeproj/project.pbxproj` uses `CODE_SIGN_STYLE = Automatic` with `DEVELOPMENT_TEAM = 3M5BRKQ345` and `"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer"` — a **development**, not distribution, identity — resident in one local macOS keychain, with no hardware protection, no managed store, and no CI signing path. | Impact: for a healthcare app, an attacker-signed update path is the highest-severity supply-chain defect available. Mitigation: generate a release keystore, store it and its password in a managed secret store, wire `key.properties`, and switch iOS to a distribution identity managed outside a single laptop. Owner: OWNER-TBD. Due: **blocks any Android distribution, including internal testing.** |
| **CICD-6.02** Artifacts, containers, packages, manifests, and SBOM/provenance attestations are signed or integrity-protected | **Fail** | No SBOM (CICD-3.01), therefore no SBOM signature. No provenance attestation (no `actions/attest-build-provenance` or equivalent in `ci.yml`). No checksum is recorded for any build (CICD-4.05). Android artefacts are "signed" with a key whose private material is public (above). Nothing in the release path is integrity-protected. | Impact: no consumer of an artifact — store, tester, or auditor — can verify it came from this source. Mitigation: sign with a real key, publish artifact digests, add build-provenance attestation once CI runs. Owner: OWNER-TBD. Due: before first release. |
| **CICD-6.03** Publication verifies target repository/store, package identity, version uniqueness, checksum, signer, and intended release channel | **Fail** | No publication automation exists; `gh release list` and `git tag -l` are both empty. Version uniqueness is structurally impossible: `version: 1.0.0+1` has never moved (CICD-4.02), so two submissions would collide. **Package identity is not even internally consistent — three different identifiers are in play**: Android `applicationId = "com.housepital.housepital_patient"` (`android/app/build.gradle.kts:26`, still carrying the stock Flutter comment `// TODO: Specify your own unique Application ID`); iOS `PRODUCT_BUNDLE_IDENTIFIER = com.housepital.housepitalPatient` (`ios/Runner.xcodeproj/project.pbxproj:507,690,713`); and `docs/KNOWN_ISSUES.md:68` instructs the reader to restrict the Firebase Android API key to **`in.housepital.patient`**, an identifier that matches neither. Nobody has reconciled them. | Impact: the documented Firebase key restriction, if applied as written, would be scoped to a package that does not exist — the restriction would either break the app or silently protect nothing. Mitigation: pick one identity scheme, correct KNOWN_ISSUES.md:68, and remove the stock TODO. Owner: OWNER-TBD. Due: before first release. |
| **CICD-6.04** Signing-key rotation and compromise procedures preserve the ability to update users safely | **Fail** | No key-rotation or key-compromise procedure exists in `docs/DEPLOYMENT_GUIDE.md` §9 or anywhere else — §9 covers Cloud Functions, database and app-store rollback only. The situation is worse than "undocumented": because the Android release key is the universally known debug key (CICD-6.01), the signing identity is **already effectively compromised before the first release**, and Android's update model binds an installed app to its signing key. Recovering from that after distribution requires Play App Signing key rotation or a new package name — neither is planned or mentioned. | Impact: a post-launch discovery of key compromise would have no safe recovery path for already-installed users. Mitigation: enrol in Play App Signing before first upload (which makes upload-key rotation recoverable) and document the procedure. Owner: OWNER-TBD. Due: before first Android upload. |

### 7. Deployment and rollback

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-7.01** Environment promotion uses the same verified artifact; production is not rebuilt from mutable inputs after approval | **Fail** | There is no promotion model — every target is a fresh local build (CICD-4.01). The rollback procedure prescribes precisely what the control forbids: `docs/DEPLOYMENT_GUIDE.md:473-479` — `git checkout <previous-commit>` / `cd functions && npm install && npm run build` / `firebase deploy --only functions`. Because `functions/` has **no `package-lock.json`** (CICD-3.01), that `npm install` re-resolves every caret-ranged transitive dependency at rollback time. **A rollback would therefore not restore the previously running code**; it would build new, unreviewed dependency versions during an incident. | Impact: the documented emergency procedure introduces fresh supply-chain risk at the moment of highest pressure. Mitigation: commit `functions/package-lock.json` and use `npm ci`; keep the built artifact rather than rebuilding. Owner: OWNER-TBD. Due: before first Functions deploy to production. |
| **CICD-7.02** Deployment permissions, approvals, separation of duties, maintenance windows, and emergency paths match risk | **Fail** | One principal with `admin: true` is author, reviewer, merger, builder, signer and deployer (CICD-1.04, 1.05, 5.04). No GitHub Environments are configured, so no deployment approval gate exists. No maintenance window and no emergency path are documented anywhere in `docs/DEPLOYMENT_GUIDE.md`. For an app in a regulated-adjacent domain handling patient vitals, medication schedules and payments, this does not match risk. | Impact: a single compromised laptop or account is sufficient to ship arbitrary code to patients. Mitigation: at minimum, introduce a second approver for production Firebase deploys and store-submission steps. Owner: OWNER-TBD. Due: before first release. |
| **CICD-7.03** Database/schema/configuration/flag order, compatibility window, monitoring, halt criteria, rollback or forward-fix, and owner are recorded | **Warning** | Partially met and honestly written. `docs/DEPLOYMENT_GUIDE.md:481-486` records the database position: *"MySQL does not have built-in migration rollback in this setup"*, prescribes a `mysqldump` backup before any migration, and requires staging first. What is **not** recorded: migration/deploy **order** relative to the client release, the backward-compatibility window between an old app version and a new schema, halt criteria, and a named owner. This matters concretely because the brief records that `../housepital-backend` (MySQL `housepital`) and `../housepital-api` (MySQL `housepital_db`) define the same entities with **incompatible schemas** — an ordering and compatibility problem with no recorded rule. | Impact: a schema change could break installed app versions with no defined compatibility window and no halt criterion. Mitigation: add an order/compatibility/halt section to §9 and name an owner. Owner: OWNER-TBD. Due: before first backend deploy that the app depends on. |
| **CICD-7.04** Canary, phased, blue-green, or other staged rollout is used when practical with automatic or human halt signals | **Warning** | `docs/DEPLOYMENT_GUIDE.md:490` names the Android mechanism correctly — *"Use Google Play Console staged rollout, halt rollout, or rollback to previous version"* — and `:491` correctly states that App Store Connect has no rollback. Nothing staged is defined for Cloud Functions or the web bundle (both are all-at-once `firebase deploy`). No halt **signal** is defined for any channel: no error-rate threshold, no Crashlytics alert wired to a rollout decision. No staged rollout has ever been exercised (zero releases). | Impact: a bad release reaches 100 % of users on iOS and Functions with no automatic brake. Mitigation: define a Crashlytics-backed halt threshold and use Play staged rollout for the first several releases. Owner: OWNER-TBD. Due: first release. |
| **CICD-7.05** Post-deployment verification checks the production artifact, configuration, critical journeys, telemetry, and data integrity | **Warning** | A real 12-item checklist exists at `docs/DEPLOYMENT_GUIDE.md:452-467`, and it is better than most: health check 200, phone OTP on a real handset, Cloud SQL connectivity, **Firestore rules deployed AND verified in console**, API-key restrictions, App Check monitor→enforce, Crashlytics/Performance alerts, Razorpay test payment, push on a real device, seed data, production API URL, version bump. Gaps against the control: no verification of the **artifact** itself (no checksum/signer check), no **data-integrity** check, no evidence capture, and no owner or sign-off line. It is also entirely manual, and several of its items are round-3 carried-open (notably `storage.rules` still undeployed per the brief). | Impact: verification depends on one person remembering to run a list, with no record that it was run. Mitigation: convert to a signed-off release record with evidence per item. Owner: OWNER-TBD. Due: first release. |

### 8. Pipeline continuity and audit

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **CICD-8.01** Build and release systems have backup, recovery, vendor outage, quota, certificate expiry, and account lockout plans | **Fail** | This control is not hypothetically unmet — **the account-lockout scenario it asks about is the current, continuous, 82-day state of the system**: `"The job was not started because your account is locked due to a billing issue"`, returned identically for runs on 2026-03-26, 2026-05-28, 2026-06-05, 2026-06-08 and 2026-06-15. There was no alert, no plan and no fallback runner; the condition simply persisted, and the repository's own documentation continued to describe CI as a mandatory gate throughout. Additionally: no backup of the iOS signing keychain (single Mac), no Apple certificate-expiry tracking, no Actions-minutes quota monitoring, no documented recovery for the unversioned `../housepital-api`. | Impact: the project has already lost its entire build-verification capability once, indefinitely, without noticing in writing. Mitigation: restore billing or move to a self-hosted/alternative runner; add certificate-expiry and quota reminders; back up signing material. Owner: OWNER-TBD. Due: **immediately — blocks release.** |
| **CICD-8.02** Audit logs cover repository, CI, secret, signing, package, cloud, store, and production release actions, protected from alteration | **Fail** | The repository is under a **personal** account, and GitHub's audit-log API is organisation-only, so no repository audit log exists to review. Force-push and history-rewrite events on `main` are therefore both possible (CICD-1.02) and undetectable. CI logs are the only pipeline record and they expire — already gone for the most recent run (`gh run view … --log-failed` → `log not found`). There is no signing log, no publication log and no production-release log, because none of those actions has ever been performed through a system that records them. | Impact: no forensic capability whatsoever if a compromise is suspected. Mitigation: move the repository into an organisation to obtain audit logging; export CI evidence to durable storage. Owner: OWNER-TBD. Due: before first release. |
| **CICD-8.03** Pipeline dependencies and permissions reviewed periodically and after personnel, vendor, architecture, or threat changes | **Fail** | `.github/workflows/ci.yml` was last changed in `4ccdcde` (2026-06-11) and carries no review record (CICD-1.05). The three third-party action versions have never been re-pinned or re-reviewed since first written (CICD-2.03). No review cadence is documented in `CONTRIBUTING.md` or `docs/`. The checklist's own cadence line — baseline before first release, targeted review on every pipeline/dependency/build change, full review annually — has no counterpart in the project. | Impact: pipeline configuration drifts unreviewed while the actions it trusts move underneath it. Mitigation: adopt the checklist cadence explicitly in CONTRIBUTING.md. Owner: OWNER-TBD. Due: before first release. |
| **CICD-8.04** A tabletop or controlled drill verifies compromise containment and trusted rebuild from known-good source | **Fail** | No drill, tabletop or rebuild exercise is recorded anywhere. More consequentially, **a trusted rebuild is currently not achievable** even if attempted: CI cannot start (CICD-8.01); `functions/` has no lockfile so the deployed Function cannot be rebuilt identically (CICD-3.01, 7.01); the Gradle distribution is fetched unverified (CICD-3.01); `../housepital-api` has no version control at all, so there is no "known-good source" to rebuild it from; and no tag identifies any previously shipped state (CICD-1.03). | Impact: on compromise, the project could not demonstrate a clean rebuild. Mitigation: fix the four prerequisites above, then run one tabletop. Owner: OWNER-TBD. Due: after CI is restored. |

---

## Scorecard

**Pass 1 · Warning 9 · Fail 28 · N/A 0** (38 controls) **+ BLOCKED-OWNER 4**

| Family | Pass | Warning | Fail |
|---|---|---|---|
| 1. Source and change control | 0 | 1 | 4 |
| 2. CI environment and credentials | 1 | 1 | 3 |
| 3. Dependencies and third-party components | 0 | 2 | 3 |
| 4. Build integrity and reproducibility | 0 | 1 | 4 |
| 5. Automated quality and security gates | 0 | 0 | 5 |
| 6. Signing, provenance, and publication | 0 | 0 | 4 |
| 7. Deployment and rollback | 0 | 3 | 2 |
| 8. Pipeline continuity and audit | 0 | 0 | 4 |

No control was graded N/A. Every control in this family can apply to a client app built and
released by a small team, and the checklist says so explicitly.

---

## Release blockers (every Fail)

Ordered by supply-chain severity, not by control number.

1. **CICD-5.01 / 8.01 — CI has never executed a single step.** 47/47 runs blocked by
   `"your account is locked due to a billing issue"`, 2026-03-26 → 2026-06-15, `steps: 0` on
   every job. `flutter analyze`, the design gate, the 1,819-test suite, the coverage gate and
   the release build are hand-run only. Everything else in this report is downstream of this.
2. **CICD-6.01 / 6.02 / 6.04 — Android release signs with the debug keystore.**
   `android/app/build.gradle.kts:36-38`; no `key.properties` anywhere. The private key is the
   world-readable `androiddebugkey`/`android` default. Any party can produce an accepted
   update to `com.housepital.housepital_patient`. No rotation or recovery path exists.
3. **CICD-1.02 / 1.05 / 5.04 — No branch protection, no reviews, failing checks merged.**
   `branches/main/protection` → 404; `rulesets` → `[]`; zero reviews on any PR; PR #10 merged
   by its own author with `test` at `FAILURE`; last 17 commits on `main` pushed directly.
4. **CICD-3.01 / 7.01 — `functions/` has no `package-lock.json`.** The Cloud Function that
   holds `ANTHROPIC_API_KEY` re-resolves caret-ranged npm dependencies on every deploy, and
   the documented rollback (`DEPLOYMENT_GUIDE.md:473-479`) would install *new* dependency
   versions mid-incident rather than restoring the previous code.
5. **CICD-3.04 / 5.02 — Zero vulnerability, secret, license or artifact scanning.**
   Dependabot alerts `404 disabled`, automated fixes `enabled:false`, no secret scanning.
   `DEPLOYMENT_GUIDE.md:439-441` claims "CI lint should catch this" for a committed live
   Razorpay key — that control does not exist.
6. **CICD-2.02 — No managed secret store; live Razorpay key prescribed on the command line.**
   `DEPLOYMENT_GUIDE.md:290` puts `rzp_live_…` into shell history and build logs.
7. **CICD-2.03 — All GitHub Actions pinned to mutable major tags**, including the third-party
   `subosito/flutter-action@v2`; `sha_pinning_required: false`.
8. **CICD-3.02 — `flutter_markdown` is discontinued upstream** and is still a direct
   dependency (`pubspec.yaml:69`), with no abandonment record or migration plan.
9. **CICD-4.01 / 4.02 / 4.04 — No release build pipeline, no version bump, no provenance.**
   `version: 1.0.0+1` unchanged across 201 commits; no commit SHA in the artifact; zero tags;
   zero releases; iOS/Android built by hand from an unmerged branch.
10. **CICD-4.03 — Demo data, a non-resolving dev endpoint and 40.5 MiB of unreferenced assets
    ship in the release artifact** (241 of 448 image files, 42,547,432 bytes, measured), with
    no dSYM phase.
11. **CICD-6.03 — Three conflicting app identities.** Android
    `com.housepital.housepital_patient`, iOS `com.housepital.housepitalPatient`, and
    `KNOWN_ISSUES.md:68` instructing key restriction to `in.housepital.patient`.
12. **CICD-1.01 / 8.04 — `../housepital-api` is not in version control at all.** No `.git`, no
    remote, no history — with a live `.env` on disk. There is no known-good source to rebuild
    the staff API from.
13. **CICD-1.03 / 8.02 — No commit signing, no verified author identity, no audit log.** All
    commits `%G? = N`, authored from `ateeshayjain@LTHYD-62310775.local`; personal-account
    repos have no audit-log API; CI logs already purged.
14. **CICD-5.03 / 5.05 / 8.03 — The pipeline's own failure is not tracked, no test evidence is
    retained, and the pipeline configuration is never reviewed.** `KNOWN_ISSUES.md` §Build/CI
    tracks three items, none of which is the billing lock; the `README.md:3` badge advertises
    a pipeline that has never been green.
15. **CICD-7.02 — One principal is author, reviewer, merger, builder, signer and deployer**,
    with no deployment approval gate and no documented emergency path.

**Cheapest high-value fixes** (hours, not days): commit `functions/package-lock.json`; enable
Dependabot alerts and secret scanning (two clicks); SHA-pin the four action uses; add a
`permissions: contents: read` block; delete the false "CI lint should catch this" sentence;
generate a release keystore and wire `key.properties`.

---

## Warnings requiring risk acceptance

| # | Control | Risk | Proposed mitigation | Owner | Due |
|---|---|---|---|---|---|
| W1 | CICD-1.04 | MFA on GitHub/Apple/Google/Firebase/Razorpay unverified; single admin means no separation of duties | Confirm MFA on all five accounts; record an access-review date | OWNER-TBD | Before first release |
| W2 | CICD-2.04 | `GITHUB_TOKEN` posture is correct (read-only, cannot self-approve) but human deployment authority is unbounded and unlogged | Add explicit `permissions:` block; move Firebase deploys to a scoped service account | OWNER-TBD | Before first release |
| W3 | CICD-3.03 | No dependency-update automation or cadence; 37 caret-ranged direct deps over 125 transitives, validated only by hand-run tests | Enable Dependabot on `pubspec.yaml` + `functions/package.json` once CI runs | OWNER-TBD | After CI restored |
| W4 | CICD-3.05 | App has no `PrivacyInfo.xcprivacy`; four resolved plugins ship none; SDK signatures and required-reason APIs unverifiable from source | Add the app manifest; verify the four plugins; re-check against a built `.ipa` | OWNER-TBD | Before first TestFlight |
| W5 | CICD-4.05 | No artifact digest recorded for any build; bit-reproducibility genuinely infeasible for Flutter AOT | Record `shasum -a 256` per shipped artifact in a release log | OWNER-TBD | First release |
| W6 | CICD-7.03 | Migration order, compatibility window, halt criteria and owner unrecorded, against two backends with incompatible schemas | Add an order/compatibility/halt section to `DEPLOYMENT_GUIDE.md` §9 | OWNER-TBD | Before first backend deploy |
| W7 | CICD-7.04 | Staged rollout named for Android only; no halt signal defined for any channel; never exercised | Define a Crashlytics-backed halt threshold; use Play staged rollout for early releases | OWNER-TBD | First release |
| W8 | CICD-7.05 | Post-deployment checklist is real and reasonably complete but manual, unowned, and captures no evidence; omits artifact and data-integrity checks | Convert §8 to a signed-off release record with per-item evidence | OWNER-TBD | First release |
| W9 | CICD-3.01 (partial) | Gradle wrapper jar gitignored and distribution fetched without `distributionSha256Sum` | Un-ignore the jar; add the checksum property | OWNER-TBD | Before first Android build |

*(W9 is recorded here for tracking; the parent control CICD-3.01 is graded Fail on the SBOM
and `functions/` lockfile gaps and appears in the blocker list.)*

---

## BLOCKED-OWNER — needs access I do not have

| # | Question | Access required |
|---|---|---|
| B1 | Is MFA enabled on the GitHub account, and on the Apple Developer, Google Play, Firebase and Razorpay accounts? | Account security settings |
| B2 | What exactly is the GitHub billing lock, when did it start, and is it recoverable? The API exposes only the annotation text; billing state is not readable with the available token scopes (`gist, read:org, repo`). | GitHub billing settings |
| B3 | Are Play App Signing / App Store Connect roles, certificates and their expiry dates configured? Nothing about store-side signing or roles is inspectable from source. | Play Console, App Store Connect |
| B4 | Are the Firebase API-key restrictions and App Check settings from `DEPLOYMENT_GUIDE.md` §7a actually applied? This bears directly on CICD-6.03, since the documented restriction targets a package identifier (`in.housepital.patient`) that matches neither shipped app. | Firebase / Google Cloud console |

---

## Limitations of this audit

- **MASTER-4.04: this is a source-and-platform-metadata audit, not an artifact audit.** No
  release artifact exists to inspect — zero tags, zero GitHub releases, no IPA or AAB. Per
  the audit brief I did not run `flutter build`, `flutter test`, `flutter clean` or
  `pod install`. Statements about what enters the release artifact (CICD-4.03) are derived
  from source, `pubspec.yaml` asset declarations and a filesystem reference scan, not from a
  built bundle. SDK signature verification and required-reason-API declarations (CICD-3.05)
  require a built `.ipa` and are recorded as unverified, not N/A.
- **CI history is partially unrecoverable.** All 47 runs failed before executing a step, and
  their logs have expired (`gh run view --log-failed` → `log not found`). The failure cause is
  established from check-run annotations retrieved via the API, which persist; step-level
  detail does not exist because no step ran.
- **`flutter analyze` clean, design gate passing, and 1,819 tests passing are cited from the
  audit brief's central results**, as instructed. I did not re-run them, and — this is the
  point of the report — neither has any pipeline.
- **The unreferenced-asset figure (241 files / 42,547,432 bytes / 40.5 MiB) is a
  filename-reference scan** of `assets/images/**` against `lib/`, `assets/equipment_catalog.json`
  and `assets/lab_tests_catalog.json`. Assets referenced by constructed (rather than literal)
  paths would be counted as unreferenced. It corroborates the round-3 figure of 40.3 MiB
  independently, which raises confidence in both.
- **Platform state I could read is limited to what the available token grants** (`gist,
  read:org, repo`): branch protection, rulesets, collaborators, PRs, reviews, check
  conclusions, run annotations, Actions permissions and Dependabot/security-analysis flags
  were all read directly. Billing state and account MFA were not — see BLOCKED-OWNER.
- **`../housepital-api` could not be assessed for change control at all** because it is not a
  git repository. Its `composer.json`/`composer.lock` and `package.json` were read from disk;
  nothing can be said about who changed them or when.
- **Owner-decision items** (white on Housepital orange, manpower pricing, the glass pill nav)
  are outside this module and are not graded here.
