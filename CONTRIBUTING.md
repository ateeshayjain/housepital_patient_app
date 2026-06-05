# Contributing to Housepital Patient App

Created in audit batch 3 (2026-05-28) to formalise the conventions we've been using ad-hoc. Skim this once before opening your first PR.

---

## Branching

- **All work on feature branches.** Never push directly to `main`.
- **Naming:** `fix/<topic>` for bug fixes, `feat/<topic>` for new features, `chore/<topic>` for tooling/docs, `test/<topic>` for test-only changes.
- **Examples:** `fix/audit-batch-3-production-test-coverage`, `feat/dai-maa-sub-brand`, `chore/bump-flutter-3.41`.
- **Long-lived branches:** none. Merge to `main` weekly cadence at minimum, even if you have to feature-flag work behind a constant in `lib/config/constants.dart`.

## Commits

- **Conventional Commits.** Prefix with `fix:`, `feat:`, `docs:`, `chore:`, `test:`, `refactor:`.
- **Body:** explain the **why**, not the what (the diff shows what).
- **Co-author line:** if Claude or another agent wrote significant code, add `Co-Authored-By: ...` so the human reviewer knows.

```text
fix: stop OtpScreen leaking timers on dispose

pin_code_fields v8.0.1 auto-disposes the controller; our dispose()
called .dispose() again which threw and prevented the timer cancels.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## Pull Requests

- **All PRs must pass CI** (`.github/workflows/ci.yml`):
  1. `flutter analyze --no-fatal-warnings --no-fatal-infos`
  2. `flutter test --reporter=expanded`
  3. `flutter build web --release`
- **PR description** must include:
  - Summary of what changed and why
  - Test plan (manual smoke tests for UI changes)
  - Screenshots/recordings for visual changes
  - Link to any audit findings being addressed (e.g. "audit M-9, M-13")
- **Reviews:** at least one approval required before merge.
- **Merge strategy:** **squash & merge** unless the branch contains multiple genuinely-distinct logical commits (rare).

## Code style

- **Linting:** `analysis_options.yaml` is the source of truth. Don't disable lints inline (`// ignore: ...`) unless necessary — if you must, add a comment explaining why.
- **Formatting:** `dart format` runs in CI implicitly via the analyzer; format your changes before pushing.
- **Imports:** package imports first (`package:flutter/...`, `package:provider/...`), then project imports (`../models/...`, `../widgets/...`). No relative dot-slash imports across `lib/` — use package-style if importing from another top-level dir.
- **Public methods:** dartdoc (`///`) on anything exported or that another widget calls.
- **Private widgets:** prefix with `_` and put them at the bottom of the file, not in a separate file. Promote to a separate file in `lib/widgets/` if used by more than one screen.

## Testing

- **Every bug fix has a regression test.** No exceptions.
- **New widgets:** at minimum a smoke test that pumps the widget and verifies it doesn't throw.
- **New providers/services:** unit tests covering happy path + error path + edge cases.
- **Run before push:** `flutter test` should be green locally.
- **Test naming:** `test('refundAmount is totalAmount - 100 when cancelled within 24h grace', () { ... })` — describe the **behavior**, not the implementation. Future devs reading test names should understand the contract without reading the code.

## File ownership & non-overlap (for parallel-agent workflows)

When dispatching multiple agents (`Agent` tool) to work in parallel, give each non-overlapping file ownership. The convention this repo follows:

- One agent owns one "domain" of files (e.g. all `test/services/*`, or all `lib/screens/billing/*`).
- Agents flag adjacent issues they spot outside their domain but don't fix them — the orchestrator picks them up.
- All agents run validation (`flutter test` on their owned tests + `flutter analyze` on touched files) before reporting done.
- Integration is the orchestrator's job: single comprehensive commit with structured message documenting each agent's work.

## What NOT to commit

The `.gitignore` blocks the obvious patterns, but as of 2026-05-28 it also blocks Firebase config (`google-services.json`, `GoogleService-Info.plist`) and `.env`. Distribute these via secure channel (1Password, Doppler, or direct hand-off). Never:

- Commit a real Razorpay live key (always pass via `--dart-define` at build)
- Commit `.env` files (only `.env.example`)
- Commit auto-generated build outputs (`build/`, `coverage/`)
- Commit IDE configs unique to your machine (`.idea/`)

## Audit batches & how we work

This project has been through 3 audit-and-fix batches (see PRs #10, #11, #12). Each batch followed the same pattern:

1. **Audit phase** — read-only agents scan against a specific dimension (functionality, brand, a11y, etc.)
2. **Synthesis phase** — orchestrator (Claude) groups findings by file ownership domain
3. **Fix phase** — parallel agents dispatch fixes, each owning a non-overlapping file set
4. **Integration phase** — orchestrator validates (analyze + test + build), commits with structured message, opens PR

If you're starting a new batch, follow the same pattern. It scales linearly with the number of fix agents and keeps merge conflicts to zero.

## Getting unstuck

- Architecture questions → [ARCHITECTURE.md](./ARCHITECTURE.md)
- "How do I run this locally?" → [docs/ENVIRONMENT_SETUP.md](./docs/ENVIRONMENT_SETUP.md)
- "Where does X live?" → [docs/SCREEN_MAP.md](./docs/SCREEN_MAP.md) for screens, [docs/API_REFERENCE.md](./docs/API_REFERENCE.md) for endpoints
- "Why does the build fail with kernel-size assertion?" → [docs/KNOWN_ISSUES.md § CI-01](./docs/KNOWN_ISSUES.md) — use `--no-tree-shake-icons` workaround
- General context on the project → [PROJECT.md](./PROJECT.md)

Ping `@ateeshayjain` if stuck.
