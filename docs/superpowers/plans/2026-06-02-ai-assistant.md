# AI Assistant Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A voice + text Hinglish assistant, reachable via a floating button on every screen, that answers questions (this month's bill, staff duty-days) and takes confirmed actions (call health manager/nurse/SOS, navigate the app), powered by a backend-mediated LLM.

**Architecture:** 4 independently-testable layers — (1) Assistant UI (full-screen chat + mic + confirm cards), (2) Voice I/O (`speech_to_text`, `flutter_tts`), (3) Brain (`AssistantService` POSTs to backend `/assistant`, which calls the LLM and returns a structured `{action, params, reply_text}`), (4) Tool executor (maps the action to existing code: `getBillingSummary`, `getAttendanceHistory`, `tel:` calls, `Navigator`). Read-only answers render instantly; side-effectful `place_call` hard-confirms; `navigate` uses a light inline confirm. Ships against a documented stub + demo responses until the backend endpoint is live.

**Tech Stack:** Flutter/Dart, Provider, `IApiService`, `canUserPerform`, `url_launcher`, new deps `speech_to_text` + `flutter_tts`.

**Base branch:** new feature branch `feat/ai-assistant` off the current working branch (independent of the other two feature branches).

---

## File Structure

- **Create:** `lib/models/assistant_models.dart` — `AssistantRequest`, `AssistantResponse`, `AssistantAction` enum, `AssistantMessage` (chat bubble model)
- **Create:** `lib/services/assistant_service.dart` — `Future<AssistantResponse> ask(AssistantRequest)`; POSTs `/assistant`; includes a demo/stub mode that pattern-matches a few canned Hinglish phrases so the feature works before the backend exists
- **Create:** `lib/services/voice_service.dart` — thin wrapper over `speech_to_text` (listen → text) + `flutter_tts` (speak); all platform plugin calls isolated here so the provider/executor stay testable
- **Create:** `lib/providers/assistant_provider.dart` — conversation messages, calls `AssistantService`, drives `VoiceService`, holds pending-confirmation state
- **Create:** `lib/screens/assistant/assistant_screen.dart` — full-screen chat UI: bubbles, mic button, text field, confirmation cards, speaking indicator
- **Create:** `lib/screens/assistant/assistant_executor.dart` — maps an `AssistantResponse` to an effect (read billing/duty, place call, navigate); pure logic given an `IApiService` + a `BuildContext`/callback, so it's unit-testable
- **Create:** `lib/widgets/assistant_fab.dart` — the reusable ✨ floating button
- **Modify:** `lib/main.dart` — register `AssistantProvider`; route `/assistant`
- **Modify:** the app shell so the FAB shows on every screen — add `AssistantFab` to the `MainShell`/`Scaffold` that wraps the tabbed screens (read `lib/screens/main_shell.dart` first to find the right Scaffold)
- **Modify:** `pubspec.yaml` — `speech_to_text`, `flutter_tts`
- **Modify:** `ios/Runner/Info.plist` — `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`
- **Modify:** `android/app/src/main/AndroidManifest.xml` — `RECORD_AUDIO` permission
- **Tests:** `test/models/assistant_models_test.dart`, `test/screens/assistant/assistant_executor_test.dart`, `test/providers/assistant_provider_test.dart`, `test/screens/assistant/assistant_screen_test.dart`

---

## Task 1: Dependencies + platform permissions

**Files:** `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1:** Add `speech_to_text` and `flutter_tts` (latest compatible) to `pubspec.yaml`; `flutter pub get`; note resolved versions.
- [ ] **Step 2:** Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Housepital uses the microphone so you can speak to the assistant.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Housepital uses speech recognition to understand your questions.</string>
```
- [ ] **Step 3:** Add to `AndroidManifest.xml` (above `<application>`): `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
- [ ] **Step 4:** `flutter analyze` → 0 issues. Commit.

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "chore: add speech_to_text + flutter_tts deps and mic permissions"
```

---

## Task 2: Models (TDD)

**Files:** Create `lib/models/assistant_models.dart`; Test `test/models/assistant_models_test.dart`

- [ ] **Step 1: Write failing tests** for `AssistantResponse.fromJson`:
  - valid `get_billing` action parses
  - unknown action string → `AssistantAction.none` (safe)
  - **valid action + missing/invalid params → still parses, params empty (executor handles the safety)**
  - `place_call` with `target: health_manager` parses params

```dart
test('unknown action degrades to none', () {
  final r = AssistantResponse.fromJson({'action': 'launch_rockets', 'reply_text': 'x'});
  expect(r.action, AssistantAction.none);
});
test('place_call parses target param', () {
  final r = AssistantResponse.fromJson({'action':'place_call','params':{'target':'health_manager'},'reply_text':'Calling…'});
  expect(r.action, AssistantAction.placeCall);
  expect(r.params['target'], 'health_manager');
});
```

- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement** `assistant_models.dart`:
  - `enum AssistantAction { getBilling, getDutyDays, placeCall, navigate, none }` with a `fromString` that maps unknown → `none`
  - `AssistantResponse { action, Map<String,dynamic> params, String replyText }` — tolerant `fromJson`
  - `AssistantRequest { text, patientId, role, locale }` with `toJson`
  - `AssistantMessage { role: user|assistant, text, optional pendingAction }` for the chat UI
- [ ] **Step 4: Run — expect PASS.** Commit.

```bash
git add lib/models/assistant_models.dart test/models/assistant_models_test.dart
git commit -m "feat: assistant models with safe action parsing + tests"
```

---

## Task 3: AssistantService (backend client + demo stub)

**Files:** Create `lib/services/assistant_service.dart`

- [ ] **Step 1: Implement** `AssistantService` with an injected `http.Client` (for testing) + a `bool useStub` flag (default true until backend ships):
  - `Future<AssistantResponse> ask(AssistantRequest req)`
  - When `useStub`: pattern-match the request text for the 4 known intents (regex on Hinglish keywords: `bill|mahine`, `duty|din|aaya`, `call|phone|baat`, `report|cart|services|kholo|dikhao`) and return a canned `AssistantResponse`. Anything unmatched → `action: none, replyText: "Main yeh abhi nahi samajh paya — menu se try karein."`
  - When not stub: `POST $apiBaseUrl/assistant` with the request JSON, parse `AssistantResponse.fromJson`. On network/parse error → return `AssistantResponse(action: none, replyText: <degradation msg>)` (never throw to the UI).
- [ ] **Step 2: Write tests** `test/services/assistant_service_test.dart`: stub mode returns correct action per sample phrase; HTTP 500 / network error → `none` + message (use a mocked client).
- [ ] **Step 3: Run — PASS.** Analyze. Commit.

```bash
git add lib/services/assistant_service.dart test/services/assistant_service_test.dart
git commit -m "feat: AssistantService with backend client + Hinglish stub"
```

---

## Task 4: Tool executor (TDD — the safety-critical core)

**Files:** Create `lib/screens/assistant/assistant_executor.dart`; Test `test/screens/assistant/assistant_executor_test.dart`

The executor takes an `AssistantResponse` + dependencies (`IApiService`, current role, callbacks for `onConfirmCall`, `onNavigate`, `onSpeak`) and produces an `ExecutorResult` describing what should happen — it does NOT itself call `Navigator`/`launchUrl` (those are injected callbacks), so it's fully unit-testable.

- [ ] **Step 1: Write failing tests:**
  - `get_billing` → reads `IApiService.getBillingSummary` (mocked), result text contains the amount → no confirmation needed
  - `get_duty_days` → reads `getAttendanceHistory` (mocked), computes days-present **client-side** for the period, returns summary text
  - `place_call target=health_manager` → returns a `RequiresConfirmation` result with the right name+number; the call callback is NOT invoked until confirm
  - `place_call` with a target that has **no phone on file** → returns safe `none`/degradation, no confirmation, no crash
  - `navigate route=/vitals` → returns a `Navigate` result (light confirm), callback carries `/vitals`
  - **permission gate:** role=FAMILY_MEMBER asking to `pay`-adjacent action → blocked message via `canUserPerform`
  - unknown/`none` action → degradation message, no side effects

- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement** `assistant_executor.dart`:
  - `Future<ExecutorResult> execute(AssistantResponse r, {required IApiService api, required String role, required String patientId})`
  - `ExecutorResult` variants: `Answer(text)`, `RequiresConfirmation(text, ConfirmableAction)`, `Navigate(route, text)`, `Blocked(text)`, `Degraded(text)`
  - billing/duty → `Answer`; place_call → validate target→number, gate on `canUserPerform`, else `RequiresConfirmation`; navigate → `Navigate`; null/unknown → `Degraded`
  - duty-days period computed locally from the returned attendance list (existing `getAttendanceHistory(patientId, {page})` has no period param — slice client-side)
- [ ] **Step 4: Run — PASS.** Commit.

```bash
git add lib/screens/assistant/assistant_executor.dart test/screens/assistant/assistant_executor_test.dart
git commit -m "feat: assistant tool executor with confirm/permission/safety + tests"
```

---

## Task 5: VoiceService (thin, isolated wrapper)

**Files:** Create `lib/services/voice_service.dart`

- [ ] **Step 1: Implement** a minimal wrapper: `Future<bool> initSpeech()`, `Future<void> listen(onResult)`, `Future<void> stopListening()`, `Future<void> speak(text, {locale})`, `bool get isListening`. All `speech_to_text`/`flutter_tts` calls live ONLY here. Handle mic-permission-denied → return false from `initSpeech` (caller falls back to text). Guard with `kIsWeb` where the plugins are limited.
- [ ] **Step 2: Analyze.** (No unit test for the plugin internals — they need a device; the provider test mocks this service.) Commit.

```bash
git add lib/services/voice_service.dart
git commit -m "feat: VoiceService wrapper for speech_to_text + flutter_tts"
```

---

## Task 6: AssistantProvider (TDD)

**Files:** Create `lib/providers/assistant_provider.dart`; Test `test/providers/assistant_provider_test.dart`

- [ ] **Step 1: Write failing tests** (inject a fake `AssistantService`, fake executor deps, fake `VoiceService`):
  - sending a text message appends a user bubble + an assistant bubble with the reply
  - a `place_call` response sets a `pendingConfirmation`; confirming invokes the call callback; cancelling clears it
  - a read-only answer speaks the reply via VoiceService (verify `speak` called)
  - network-degraded response shows the degradation bubble, no crash
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** `AssistantProvider`: holds `List<AssistantMessage>`, `pendingConfirmation`, `isListening`, `isThinking`; `sendText(text)` → service.ask → executor.execute → append bubble / set pending / speak; `startVoice()`/`stopVoice()` via VoiceService; `confirmPending()` / `cancelPending()`.
- [ ] **Step 4: Run — PASS.** Commit.

```bash
git add lib/providers/assistant_provider.dart test/providers/assistant_provider_test.dart
git commit -m "feat: AssistantProvider orchestrating service+executor+voice + tests"
```

---

## Task 7: Assistant UI + FAB

**Files:** Create `lib/screens/assistant/assistant_screen.dart`, `lib/widgets/assistant_fab.dart`; Test `test/screens/assistant/assistant_screen_test.dart`

- [ ] **Step 1: Implement `AssistantFab`** — a `FloatingActionButton` with the ✨ icon + Housepital orange, `Semantics(button, label: 'Open assistant')`, ≥44pt, that `Navigator.pushNamed(context, '/assistant')`.
- [ ] **Step 2: Implement `AssistantScreen`** — `Consumer<AssistantProvider>`: a scrolling message list (user/assistant bubbles), a `RequiresConfirmation` rendered as a **confirmation card** ("📞 Calling Sunita Devi · 98xxx — Confirm / Cancel" with two buttons wired to `confirmPending`/`cancelPending`), a bottom bar with a text field + mic button (mic toggles `startVoice`/`stopVoice`, shows a "Sun raha hoon…" listening state), and a "speaking…" indicator. All strings Hinglish-friendly. A11y labels on the mic + send.
- [ ] **Step 3: Widget test** — pump with a seeded provider: a `place_call` pending state renders a confirm card; tapping Confirm calls the provider's confirm; tapping Cancel clears it. A read-only answer renders as a bubble. Mic button is present and ≥44pt.
- [ ] **Step 4: Run — PASS.** Analyze. Commit.

```bash
git add lib/screens/assistant/assistant_screen.dart lib/widgets/assistant_fab.dart test/screens/assistant/assistant_screen_test.dart
git commit -m "feat: assistant full-screen UI + confirm cards + FAB"
```

---

## Task 8: Wire provider, route, and FAB-everywhere

**Files:** Modify `lib/main.dart`, `lib/screens/main_shell.dart`

- [ ] **Step 1:** Register `AssistantProvider` in `MultiProvider` (`create: (_) => AssistantProvider(...)` with `assistantService`, `apiService`, `voiceService`).
- [ ] **Step 2:** Add route `case '/assistant': return MaterialPageRoute(builder: (_) => const AssistantScreen());`
- [ ] **Step 3:** Read `lib/screens/main_shell.dart`; add `floatingActionButton: const AssistantFab()` to the shell Scaffold that hosts the tabbed pages so it appears on Home/MyCare/Services/Billing/Settings. (If individual screens own their Scaffolds, place it on the shell that wraps the `IndexedStack`.)
- [ ] **Step 4:** Analyze + run assistant tests. Commit.

```bash
git add lib/main.dart lib/screens/main_shell.dart
git commit -m "feat: register assistant provider/route + FAB on app shell"
```

---

## Task 9: Full verification

- [ ] **Step 1:** `flutter analyze` → No issues.
- [ ] **Step 2:** `flutter test` → green (baseline + all new assistant tests).
- [ ] **Step 3:** `flutter build web --release` → clean (voice plugins must be `kIsWeb`-guarded so web still builds/runs; assistant on web = text-only is acceptable).
- [ ] **Step 4:** Smoke (iOS sim, since voice needs a real platform): tap the ✨ FAB → type "iss mahine ka bill kitna hai" → get billing answer; type "health manager ko call karo" → confirm card appears → Confirm dials; tap mic → speak → transcription appears.
- [ ] **Step 5:** Final commit of any mock/test updates.

---

## Backend dependency (separate repo — NOT built here)
`POST /assistant` → `{action, params, reply_text}` per the spec contract. Until live, `AssistantService.useStub = true` keeps the feature working with canned Hinglish responses. Flip `useStub` to false (or env-flag it) when the endpoint ships.

## Done criteria
- `flutter analyze` = 0 issues; full suite green; web build clean
- ✨ FAB on every tabbed screen → assistant opens
- Text + voice input both work (voice on device); replies spoken
- 4 tools work against the stub; `place_call` hard-confirms; `navigate` light-confirms; permission-gated; malformed responses degrade safely
