# Design — Home revamp, AI Assistant, Blogs/Education

**Date:** 2026-06-02
**Status:** Approved in brainstorming; pending spec review + user review
**Author:** brainstormed with Ateeshay Jain
**Repo:** housepital_patient_app (Flutter/Dart, Provider, Firebase + REST API)

---

## Overview

Three features designed together as one batch:

1. **Home screen layout (Layout B)** — reduce wasted top space; surface the Health Team (Health Manager + on-duty staff) first.
2. **AI Assistant** — a voice + text chatbot (Hinglish) that answers questions and takes confirmed actions, reachable via a floating button on every screen.
3. **Blogs / Education** — a section of care-education articles served from the backend with a demo fallback.

All three follow the codebase's established patterns: Provider state management, `IApiService` data access, and demo-data fallback when the API is unavailable.

---

## Feature 1 — Home Screen (Layout B)

### Goal
The current Home screen wastes the entire first viewport on a large hero banner + greeting block + a separate "Primary Contact" badge row, pushing the Health Team (the most-wanted info: who is caring for me + how to call them) below the fold.

### Changes (`lib/screens/home/home_screen.dart`)
New section order in the build tree:

1. Header (logo + search / cart / bell) — **unchanged**
2. **One-line greeting + badge** — "Hi Rajesh! · Primary Contact" on a single row (was a greeting block + separate badge row).
3. **(PATIENT_SELF role only)** the existing "Call my family caregiver" card stays at top, above the team card.
4. **Condensed Health Team card** — Health Manager + the *currently on-duty* staff only (driven by `app.activeDeployment`), each with a one-tap call action. If no active deployment, fall back to the existing fuller team list.
5. Today's Vitals → Medications snippet → Book Services → Today's Report → Payments — **existing order, unchanged**.
6. **Hero banner moves to the bottom**, still a carousel (auto-scroll + reduced-motion guard already implemented), demoted to a promo surface.

### Reuse / constraints
- `_buildHealthTeamCard` already exists — restructure to the condensed form and hoist above the hero.
- No new data: `activeDeployment` + `getHealthManager` already provide the needed fields.
- No new dependencies.
- Existing home-screen widget tests must continue to pass; update any that assert section order.

### Out of scope
- No redesign of the hero banner content itself (only its position/size).
- No change to the 5-tab bottom nav.

---

## Feature 2 — AI Assistant (voice + text, Hinglish)

### Goal
A family member can ask, in Hinglish, by voice or text:
- "Iss mahine ka bill kitna hai?" → hears the amount + due date
- "Mera staff iss hafte kitne din duty pe aaya?" → hears days present
- "Supervisor / health manager ko call karo" → confirms, then dials
- "Meri reports dikhao" / "cart kholo" → navigates the app

### Entry point
A glowing ✨ **floating action button (FAB)** on every screen → opens a full-screen assistant. This is **separate** from the existing Firestore-backed human coordinator chat (`lib/screens/chat/chat_screen.dart`), which is unchanged.

### Architecture (4 independently-testable layers)

```
[ Assistant UI ]  (Flutter) full-screen chat: message bubbles, mic button,
                  text field, action confirmation cards, "speaking…" indicator
        │
[ Voice I/O ]     (plugins) speech_to_text (mic → Hinglish text, hi-IN/en-IN);
                  flutter_tts (bot reply → spoken)
        │
[ Assistant brain ] (backend → LLM) app POSTs {user_text, context} to backend
                    /assistant endpoint → backend calls LLM with a fixed tool
                    list → returns structured {action, params, reply_text}
        │
[ Tool executor ] (Flutter) maps returned action to existing code paths
```

**Why backend-mediated (not direct app→LLM):** keeps the LLM API key server-side (app never holds it — consistent with the project's secrets rule), allows model changes without an app release, and centralizes per-message cost control.

### The 4 v1 tools
The LLM selects exactly one tool per query; it cannot invent free-form actions.

| Intent       | Reads (existing API)                | Action                                            |
|--------------|-------------------------------------|---------------------------------------------------|
| `get_billing`   | `IApiService.getBillingSummary`  | speaks amount + due date; offers "open Billing"   |
| `get_duty_days` | `IApiService.getAttendanceHistory` | speaks days present this week/month             |
| `place_call`    | health-manager / nurse / SOS number | **confirmation card** → `url_launcher` `tel:`   |
| `navigate`      | —                                 | `Navigator.pushNamed` to the target screen        |

### Backend contract (NEW work in the separate backend repo)
`POST /assistant`
- **Request:** `{ "text": string, "patient_id": string, "role": string, "locale": "hi-IN"|"en-IN" }`
- **Response:** `{ "action": "get_billing"|"get_duty_days"|"place_call"|"navigate"|"none", "params": { ... }, "reply_text": string }`
- `params` examples: `place_call` → `{ "target": "health_manager"|"nurse"|"sos" }`; `navigate` → `{ "route": "/billing" }`; `get_duty_days` → `{ "period": "week"|"month" }`.
- The app ships against a **documented stub + demo responses** until the endpoint is live, so the feature is buildable and testable now.

### Safety — confirm before acting (user-chosen)
- Read-only answers (`get_billing`, `get_duty_days`) render instantly.
- Any side-effectful action (`place_call`, `navigate`) renders a **confirmation card** ("📞 Calling Sunita Devi · 98xxx — Confirm / Cancel"); the action fires only on Confirm. This is essential because a voice mishear ("call" vs "cancel") must never auto-dial.

### Permissions
The executor respects the existing `canUserPerform(role, action)` matrix. Example: a FAMILY_MEMBER asking to pay hears "I can show the bill, but only the primary contact can pay." Calls/answers permitted per role.

### Graceful degradation
- No network → "I need an internet connection for that" + offer the manual screen.
- LLM/backend error → "I didn't catch that — try rephrasing, or use the menu."
- Mic permission denied → fall back to text input, prompt to enable mic in settings.

### New dependencies
- `speech_to_text` (mic → text, supports hi-IN/en-IN)
- `flutter_tts` (spoken replies)
- `url_launcher` (already present — reused for `tel:`)

### v1 scope boundaries (explicitly later)
- **Stateless per query** — each question independent; multi-turn pronoun resolution ("call him") is later.
- Assistant does **not** surface blog articles in v1 (that's a Feature 2 × Feature 3 tie-in for later).
- No proactive/notification-driven assistant messages.

### Components (new files)
- `lib/screens/assistant/assistant_screen.dart` — full-screen chat UI
- `lib/providers/assistant_provider.dart` — conversation state, calls backend, drives voice I/O
- `lib/services/assistant_service.dart` — `POST /assistant` client (+ demo stub)
- `lib/models/assistant_models.dart` — `AssistantRequest`, `AssistantResponse`, `AssistantAction` enum
- `lib/widgets/assistant_fab.dart` — the reusable floating button
- Tool executor logic (in provider or a dedicated `assistant_executor.dart`)

### Testing
- Unit: each tool executor path (billing/duty/call/navigate) with a mocked `IApiService`.
- Unit: `AssistantResponse` parsing (valid, malformed, unknown action → safe "none").
- Unit: permission gating (FAMILY_MEMBER pay attempt → blocked message).
- Widget: confirmation card renders for `place_call`/`navigate`; Confirm fires, Cancel aborts.
- Widget: network/LLM error → degradation message.
- Voice I/O plugins mocked (no real mic in tests).

---

## Feature 3 — Blogs / Education

### Goal
A section of care-education articles (e.g. "Caring for a bedridden patient", "Post-ICU recovery at home", "Diabetes diet").

### Architecture (mirrors existing demo-fallback pattern)

```
[ Blog list screen ]   scrollable cards: cover image, title, category chip, read-time
[ Blog detail screen ] cover + title + markdown body + share
        │
[ BlogProvider ]       ChangeNotifier — list/detail, loading/error state
        │
[ IApiService ]        NEW: getArticles({category}), getArticle(id)
        │
   backend /articles ── falls back to DemoData.articles when API unavailable
```

### Data model (`Article`)
`id, title, summary, body (markdown), coverImageUrl, category, readMinutes, publishedAt`.
Body rendered with `flutter_markdown` so backend authors can publish rich text without app releases.

### Entry point
- A tile in the Home **Book Services / Quick Actions** grid: "📚 Care Guides".
- Route `/articles` (list) and `/article` (detail). **Not** a bottom-nav tab (keeps the 5-tab bar intact, consistent with the assistant being a FAB not a tab).

### Demo fallback
4–5 bundled starter articles in `DemoData.articles` so the section is never empty offline.

### New dependencies
- `flutter_markdown` (article body rendering)

### Components (new files)
- `lib/screens/articles/article_list_screen.dart`
- `lib/screens/articles/article_detail_screen.dart`
- `lib/providers/blog_provider.dart`
- `lib/models/article.dart`
- `DemoData.articles` (extend existing demo data)
- `IApiService` + `ApiService` + `IApiService` mock: `getArticles`, `getArticle`

### v1 scope boundaries (explicitly later)
- Categories are simple string tags (no nested taxonomy).
- No search/bookmark/like in v1.
- No assistant ↔ article tie-in in v1.

### Testing
- Unit: `Article` JSON round-trip.
- Unit: `BlogProvider` success / API-error-falls-back-to-demo / empty.
- Widget: list renders cards; tapping routes to detail; markdown body renders.

---

## Cross-cutting

- **Branch:** new feature branch off the current batch-5 head (`fix/audit-batch-5-...`) or `main` once the PR stack merges — decide at implementation time.
- **Analyzer:** must remain at 0 issues (the bar set by batch 5).
- **Tests:** full suite stays green; new features add their own tests.
- **CI:** the per-platform smoke-launch gap (flagged in batch 5) should ideally be closed before/with this work, since these features touch `main()` (FAB injection) and add native plugins (speech/tts) — exactly the class of change that runtime-only failures hide behind a green build.
- **Build order suggestion:** Feature 1 (smallest, immediate visible win) → Feature 3 (medium, self-contained) → Feature 2 (largest, depends on new plugins + backend stub).

---

## Open items / dependencies on others

1. **Backend `/assistant` endpoint** — new work in the separate backend repo; app builds against a stub until live.
2. **Backend `/articles` endpoint** — same; demo fallback covers the gap.
3. **LLM provider + prompt** — backend-side decision (model, the tool-list system prompt, cost limits).
4. **Firebase / platform** — speech & tts are native plugins; iOS needs mic-usage Info.plist strings; Android needs `RECORD_AUDIO` permission.
