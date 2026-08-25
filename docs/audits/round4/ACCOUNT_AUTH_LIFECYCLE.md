# Account & Authentication Lifecycle — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Account & Authentication Lifecycle (AUTH family) ·
**Scope:** source review of `housepital_patient_app` @ `9127713` (branch `fix/five-tab-nav`)
and `../housepital-backend` (Firebase Functions + MySQL `housepital`). See Limitations.

**This module has never been audited.** There is no round-3 report for it, so there is no
prior-round status table. Where a round-3 finding from a *different* module (chiefly
`round3/SECURITY_PRIVACY_AUDIT.md`) already names something I re-derive here, I say so and
credit it rather than presenting it as new.

---

## Applicability

**MASTER-3.01 applies in full.** The app defines OTP sign-in (`lib/screens/auth/login_screen.dart`,
`otp_screen.dart`), Firebase phone authentication (`lib/services/firebase_service.dart:52-91`),
ID-token session management with a 50-minute refresh timer (`lib/providers/auth_provider.dart:76-116`),
a four-role permission matrix (`lib/utils/permissions.dart`), a family-members screen, a
multi-patient switcher (`app_provider.dart:187`), and an in-app account-deletion screen. The
backend defines `verifyAuth` / `requirePrimary` / `verifyPatientAccess` middleware, an onboarding
endpoint, and family invite/add/remove routes.

Not one of these is a candidate for N/A. The controls that come back N/A below do so on narrow,
written grounds (no passwords, no OAuth/SAML, no social login, no biometrics, no impersonation),
never because the area was unreachable or untested.

---

## The finding that governs every other one: authentication is switched off

`lib/main.dart:417-419`:

```dart
// NOTE: Auth gate disabled for demo mode. Enable before production release.
// home: Consumer<AuthProvider>(...),
home: const SplashScreen(),
```

`splash_screen.dart:15-18` then does `pushReplacementNamed('/home')` after two seconds,
unconditionally. `MainShell` is also the `default:` branch of `onGenerateRoute`
(`main.dart:771-773`). **No route in the app requires a signed-in user.**

Three consequences an external reviewer will check, all confirmed:

1. **The sign-in flow is not merely bypassed — it is unreachable and, if reached, dead-ends.**
   `LoginScreen` has no `case` in `onGenerateRoute` and no `Navigator` call anywhere in `lib/`
   targets it (`grep -rn "LoginScreen" lib` → definition only). `'/otp'` and `'/onboarding'`
   cases exist (`main.dart:446-450`) but nothing navigates to them. And
   `login_screen.dart:65-67` calls `auth.sendOtp(...)` and then **does not navigate** — it
   relies on the commented-out `Consumer<AuthProvider>` to rebuild `home` when the state
   becomes `otpSent`. `OtpScreen` likewise never navigates after `verifyOtp`. The screens were
   written for a gate that does not exist; re-enabling the one commented line is necessary but
   not sufficient.

2. **Every control in this checklist that presumes a signed-in user is presuming a user the
   build never produces.** I have graded the *code as written*, because that is what ships the
   day the gate is turned on, and I mark each such control accordingly rather than treating the
   gate as an excuse.

3. **The role that drives the entire permission layer is a hardcoded constant.**
   `app_provider.dart:20` — `String _currentUserRole = 'PRIMARY_CONTACT';` — and
   `app_provider.dart:22-25` `setUserRole(String role)` has **zero call sites** in `lib/`
   (verified by grep). No server response, no token claim, and no login result ever writes it.
   `clearSession()` (`:235`) resets it to `'PRIMARY_CONTACT'` — the *most* privileged value.
   This is round 3's **R3-4**, still open, and it is the reason the round-3 export-gating
   remediation is inert (see AUTH-5.04).

This is the round-2→3→4 trajectory the brief asks about, and the answer for this module is
unambiguous: **half-wires.** The data structures are right — a correct four-role matrix with
310 lines of tests, a `SessionScope` that enumerates stores, a deletion screen with unusually
honest copy. The behaviour they were built to enable is, in every case, left unwritten: the
role is never assigned, the invitation is never sent, the deletion request is never read, the
session is never revoked.

---

## Control results

### 1 · Identity model and necessity

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-1.01** Account required only when necessary | **Warning** | Persistent identity is genuinely necessary (medical records, payments, dispatch to a home address) and the rationale is written down in `delete_account_screen.dart:19-43` and `CLAUDE.md`. But no account is required at all: `main.dart:417-419`. | The failure mode is the inverse of the one this control guards. Clinical surfaces (vitals, daily reports, medications, documents, chat) open to anyone holding the phone. Mitigated today only by the fact that all of it is `DemoData`. **Owner: OWNER-TBD · Due: before first real-data build.** |
| **AUTH-1.02** Identity attributes, verification level, roles, membership, **account states**, sources of truth documented | **Fail** | Three contradictions between the two authoritative sources. (a) Roles: `permissions.dart:19-24` defines four (incl. `CARETAKER`); `sql/001_initial_schema.sql:51` is `ENUM('PRIMARY_CONTACT','FAMILY_MEMBER','PATIENT_SELF')` — **`CARETAKER` cannot be stored**, and `middleware/auth.ts:12` types the role as the three-value union. (b) Membership: the app models one user → many patients (`app_provider.dart:187` `switchPatient`, `/add-patient`); `schema:45` is `user_id VARCHAR(128) NOT NULL UNIQUE` — one user → exactly one patient. (c) **Account states do not exist**: no `status`/`deleted_at`/`suspended` column on `family_members` (`grep -n "status\|deleted_at" sql/001_initial_schema.sql` returns hits on nine other tables, none on `family_members`). | A role the product ships in its permission matrix cannot be persisted; a membership shape the product promises cannot be represented; there is no way to express "closed", "suspended", or "pending deletion" for an account. See the CRITICAL section below. |
| **AUTH-1.03** Anonymous / guest / progressive options considered | **Warning** | The app *is* an unauthenticated local-only experience, but by deferral, not design: `main.dart:417` "Enable before production release." No document evaluates a progressive-account or guest tier. | A deliberate guest tier (browse catalogue, no PHI) is probably the right product answer and would let the gate be enabled without losing the demo. Record the decision. **OWNER-TBD.** |
| **AUTH-1.04** Shared-device, family/household, caregiver, **minor**, workforce scenarios addressed | **Warning** | Household and shared-device are addressed unusually well — `session_scope.dart:20-43` states the threat model explicitly and the code acts on it. Caregiver is modelled (`CARETAKER`) though unassignable (1.02). **Minors are not addressed anywhere**: no age gate, no guardian-consent capture, and `patients.age` (`schema:12`) accepts any value. | India's DPDP Act 2023 §9 requires verifiable parental consent and bars tracking/behavioural monitoring for data principals who are children. A home-healthcare app with a paediatric-adjacent sister brand needs a written position. **OWNER-TBD · Due: before first real-data build.** |

### 2 · Enrollment and verification

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-2.01** Signup prevents enumeration, automation, duplicate identity, **unsafe default role**, **unverified privileged access** | **Fail** | Duplicate identity is handled (`auth.ts:82-89` → 409). Enumeration is not a live risk (the check runs post-authentication). But two unsafe defaults: (a) **client** — `app_provider.dart:20` hardcodes `PRIMARY_CONTACT`, the maximum role, for every user; (b) **server** — `middleware/auth.ts:44-53` assigns any authenticated-but-not-onboarded Firebase user `role = "FAMILY_MEMBER"` and `patientId = ""`, and `verifyPatientAccess` at `:105` reads `if (patientId && authReq.patientId && patientId !== authReq.patientId)` — an empty `authReq.patientId` is falsy, so **the tenant check is skipped entirely**. | Anyone who can complete a phone OTP with any number — no onboarding, no relationship to any patient — passes `verifyPatientAccess` for *every* `patientId`. `GET /patients/:patientId/family` (`family.ts:17-21`) is guarded by only `verifyAuth` + `verifyPatientAccess`, so that user can read any patient's full family roster (names, phones, emails, relationships) given a patient UUID. Fix: make the unonboarded branch fail closed, and make `verifyPatientAccess` reject when `authReq.patientId` is empty. |
| **AUTH-2.02** Verification matches actual risk | **Warning** | Phone OTP for the account holder is proportionate. Added family members are never verified: `family.ts:61-80` inserts a row with `user_id: ""` and no invite token; email is optional and unverified (`family_members_screen.dart:158`). | Not currently exploitable — an unverified member has no `user_id` and so cannot authenticate as themselves — but the roster is treated as authoritative for notification targeting. Tie member creation to the invite-acceptance flow that AUTH-5.02 says does not exist. |
| **AUTH-2.03** Codes scoped, expiring, single-use, rate-limited, replay-resistant, safe on another device | **Warning** | Scoping, single-use, server-side expiry and replay resistance are delegated to Firebase Phone Auth (`firebase_service.dart:58-91`) — a defensible choice I cannot verify from source. The app adds a 5-minute client expiry that locks the field (`otp_screen.dart:49-65, 128`). **Resend is unbounded**: `otp_screen.dart:230-237` re-arms a 30-second cooldown with no attempt counter and no cap. | An unbounded resend loop is the MFA-fatigue/SMS-pumping vector, and it is also a direct billing exposure. Add a resend cap (3–5) with escalating backoff. Firebase's own quotas are the only current mitigation and are **unverified** (needs console access). |
| **AUTH-2.04** Terms, privacy, marketing, **sensitive-processing** consents separated, versioned, recorded | **Fail** | One combined checkbox for Terms *and* Privacy (`login_screen.dart:23-25, 177-196`). No separate consent for processing health data. Not versioned. **Not recorded** — `_agreedToTerms` is widget state (`:25`), never persisted, never transmitted; no consent column exists in `family_members`. And both the "Terms" and "Privacy Policy" links push `'/about'` (`login_screen.dart:216, 236`), not the policies. | DPDP 2023 requires itemised notice and specific consent for health data, and requires the fiduciary to be able to *demonstrate* consent. Nothing here can be demonstrated. Also blocks App Review data-use declarations. |
| **AUTH-2.05** Abandoned/unverified accounts and proof data expire on schedule | **Warning** | No retention or cleanup mechanism in either repo. A Firebase user created by OTP who abandons onboarding leaves a Firebase Auth record with no `family_members` row and no expiry. | **Warning today because the sign-in flow is unreachable, so no such accounts accrue. This becomes a Fail on the day the gate is enabled.** Needs a documented retention schedule + a scheduled function. **OWNER-TBD.** |

### 3 · Authenticators and login

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-3.01** Phishing-resistant authenticators; MFA matches risk | **Warning** | SMS OTP is the only authenticator (`firebase_service.dart:52-91`). No passkey option. **No step-up authentication for any sensitive action** — payment (`payment_screen`), Doctor Handover export (`handover_report_service.dart:323`), or account deletion (`delete_account_screen.dart:72-76`) require nothing beyond an already-open session. | NIST SP 800-63B-4 treats SMS as a restricted authenticator. Single-factor SMS is the near-universal Indian consumer norm and is defensible as an accepted risk; **the absence of any step-up on the destructive and financial paths is not** — see AUTH-8.03. **OWNER-TBD.** |
| **AUTH-3.02** Password guidance | **N/A** | No password authenticator exists anywhere in the app or backend (`grep -rn "password" lib` → zero auth-related hits). The control cannot apply. | — |
| **AUTH-3.03** OAuth/OIDC token validation | **Pass** | `middleware/auth.ts:34` `await auth.verifyIdToken(idToken)` — the Firebase Admin SDK performs full signature, issuer, audience, and expiry validation. Bearer-scheme parsing is strict (`:25-30`), and expiry is handled distinctly (`:65-66`). Covered by `functions/src/__tests__/auth.test.ts:46-108`. | Pass on the code. Note it is **unexercised**: the client is pointed at `https://api.housepital.in/v1` (`constants.dart:3`), which does not resolve. |
| **AUTH-3.04** Social login / platform-equivalent login | **N/A** | No social or third-party login is offered (no Google/Apple/Facebook sign-in in `pubspec.yaml` or `lib/`). App Review 4.8 does not trigger. | — |
| **AUTH-3.05** Biometrics unlock a protected credential | **N/A** | No biometric authentication is implemented — `local_auth` is absent from `pubspec.yaml`. The control is conditional on biometrics being used. | Recorded separately, not as an N/A dodge: **there is no app-lock of any kind** on a build that renders PHI. Raised under AUTH-4.01. |

### 4 · Session and device lifecycle

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-4.01** Session creation, idle/absolute expiry, refresh rotation, replay detection, revocation, logout, concurrent-session policy **defined and tested** | **Fail** | Creation and refresh exist (`auth_provider.dart:76-81`, 50-min timer; one-shot 401 recovery at `api_service.dart:87-96`). Everything else is absent: **no idle timeout, no absolute session lifetime, no app-lock, no replay detection, no revocation, no concurrent-session policy.** The Firebase refresh token is effectively permanent and the timer renews the ID token indefinitely. **Untested:** `auth_provider.dart:93` reaches `FirebaseAuth.instance.currentUser` **directly** instead of the injected `_firebaseService` — `FakeFirebaseService` (`test/_mocks/fake_firebase_service.dart:85`) overrides `getIdToken()` but cannot intercept the static, so `_refreshToken` and `handleUnauthorized` have **zero test coverage** (`grep -rn "handleUnauthorized\|_refreshToken" test/` → no hits). | The brief asked me to verify the `:93` claim: **confirmed, and it is worse than untestable.** In any environment where `FirebaseAuth.instance` is unavailable (unit test, Firebase init failure), `_refreshToken` throws → caught at `:99` → returns `false` → `handleUnauthorized` calls `logout()` (`:112`). A transient Firebase failure is therefore indistinguishable from a revoked refresh token, and the app's response to both is to sign the user out and wipe local prefs. Fix: route refresh through `_firebaseService` (add `getIdToken({bool forceRefresh})`), then test the 401→refresh→retry and 401→refresh-fail→logout paths. |
| **AUTH-4.02** Users can view and revoke active devices/sessions | **Warning** | Not implemented. No sessions or devices table in `sql/001_initial_schema.sql`; no screen in `lib/screens/settings/`. | "When risk warrants it" gives latitude for a single-device consumer app with a cheap OTP re-auth. Given the shared-phone threat model the code itself documents (`session_scope.dart:22-28`), a device list is the right eventual answer, but the sharper gap is revocation (4.03). **OWNER-TBD.** |
| **AUTH-4.03** Recovery, role removal, termination, compromise, deletion **revoke affected tokens promptly** | **Fail** | Nothing revokes anything. (a) **Role removal escalates privilege.** `family.ts:219` deletes the row; no `revokeRefreshTokens` call exists in the backend. `verifyAuth` re-reads `family_members` per request, so on the next request the removed member falls into the unonboarded branch (`middleware/auth.ts:44-53`) → `patientId = ""` → `verifyPatientAccess` becomes a no-op (per AUTH-2.01) → **they can still read the patient they were just removed from, and every other patient too.** Removal makes access broader, not narrower. (b) **The bearer token survives logout.** `auth_provider.dart:217-242` never clears `ApiService._authToken` (`api_service.dart:16`), and `IApiService` (`i_api_service.dart:12`) exposes only `setAuthToken(String)` — there is no clear method to call. Round 3 named this (`SECURITY_PRIVACY_AUDIT.md` store 8); **still open at HEAD.** (c) **FCM is never revoked.** `deleteToken` has zero call sites in `lib/` and no backend route deletes the `fcm_tokens` row, so push about a patient keeps arriving on a signed-out device. Round 3's **R3-6**; still open. | (a) is a genuine privilege-escalation-on-revocation and should be treated as the highest-severity item in this report alongside the CRITICAL section. |
| **AUTH-4.04** Token storage, transport, scope, rotation | **Warning** | Good: the ID token is held in memory only (`api_service.dart:16`) and is never written to `SharedPreferences` — I checked. Transport is HTTPS with no cleartext escape hatch (`constants.dart:3`; `grep` for `usesCleartextTraffic` / `NSAllowsArbitraryLoads` / `networkSecurityConfig` across `android/` and `ios/` → **no hits**). Refresh-token storage is the Firebase SDK platform default (iOS Keychain). Rotation is `getIdToken(true)` (`auth_provider.dart:95`). | The gap is scope/lifetime rather than storage: the in-memory token outlives the session (4.03b), and there is no `flutter_secure_storage` for the patient-scoped data that *is* persisted in plaintext prefs. The latter belongs to the Security & Privacy module; noted here only for completeness. |
| **AUTH-4.05** Account switching clears/partitions memory, caches, files, notifications, sync state | **Warning** | This is the strongest area in the module and the round-3 repairs held. `session_scope.dart:81-107` clears six providers, awaits `RemindersProvider`, cancels **OS-scheduled** medication reminders (`:100` — the leak that escaped the app entirely), clears `CacheService` blobs and loose prefs keys (`:119-138`). `SessionScope.install()` (`:61-71`) via `AppProvider.onPatientChanged` makes both switch paths — the sheet (`app_provider.dart:187`) and `loadPatients()` — fan out. 14 tests in `test/providers/patient_scope_isolation_test.dart`. **Two gaps.** (1) **`SessionScope` is imported by zero test files** — `grep -rn "session_scope" test/` returns nothing; the sole match in `patient_scope_isolation_test.dart:12` is a *comment*. The tests assert each provider's own `clearPatientScopedData()`; nothing asserts that `SessionScope` calls them, that `install()` wires the hook, or that `clearSession` runs `AppProvider.clearSession`. The integration point — the exact thing that broke in rounds 2 and 3 — is the untested part. (2) This is **patient** switching; there is no **account** switching. | The round-3 carried-open item "`SessionScope` imported by zero tests" is **confirmed still open at `9127713`**. One test that installs the hook, switches patients, and asserts the fan-out would close it. **OWNER-TBD · Due: next test pass.** |

### 5 · Authorization and privilege

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-5.01** Server-side authorization verifies tenant, role, ownership, relationship, object, action, **current account state** on every protected request | **Fail** | In the shipped build there is **no server-side authorization at all** — every provider serves `DemoData` and `api.housepital.in` does not resolve. In backend source: tenant check bypassable (AUTH-2.01); **object-level ownership missing** on two routes — `family.ts:129-189` (`PUT .../family/:memberId`) looks up the member by `memberId` alone with no `patient_id` comparison and no `requirePrimary`, and `family.ts:193-226` (`POST .../family/:memberId/remove`) has `requirePrimary` but likewise never checks `member.patient_id === patientId`. The **legacy** route at `:249` *does* check (`member.patient_id !== authReq.patientId → 403`), so the newer routes regressed against the older one. Current account state cannot be checked because it does not exist (AUTH-1.02). | Classic confused deputy with a user-supplied identifier: a `FAMILY_MEMBER` of patient X can rewrite the name/phone/email of any member of patient Y, and a `PRIMARY_CONTACT` of X can delete a member of Y. Fix: copy the legacy route's ownership check into both, and add `requirePrimary` to the PUT. |
| **AUTH-5.02** Invitations, joins, role grants, elevation, ownership transfer, delegation have approval, expiry, audit, revocation | **Fail** | **The invitation flow does not exist end to end — it does not exist at either end.** Client: `family_members_screen.dart:22-44` is a hardcoded `static final _mockMembers` list; `_showAddMemberSheet`'s submit handler (`:218-251`) validates the form, builds a `FamilyMember`, and calls `setState(() => _members.add(newMember))` — **no API call**, no invite, no persistence. It shows "*name* added" and the member is gone on the next mount. Removal is `_members.removeWhere` (`:65-67`). Every added member is hardcoded `'role': 'FAMILY_MEMBER'` (`:234`) — there is no role picker, so no role can be granted. No ownership transfer exists. Backend: `POST /patients/:patientId/family/invite` (`family.ts:103-125`) validates `phone`, then returns `{success:true}` — the comment at `:117-118` says "For now, just record the invitation" and **it records nothing**. There is no `invitations` table in `sql/001_initial_schema.sql`, no token, no expiry, no acceptance endpoint. No audit table anywhere. | The brief asked whether the flow exists end to end and whether `family.ts` supports it. **It exists at neither end.** The screen is a mock; the endpoint is a stub returning success. A primary contact who "adds" a family member has done nothing, and has been told they succeeded. |
| **AUTH-5.03** Admin/support impersonation visible, time-bound, logged | **N/A** | No impersonation capability exists in the patient app or in `housepital-backend` (`grep -rn "impersonat\|actAs\|onBehalfOf"` → no hits). The staff-side Laravel API `../housepital-api` is a different module's scope. | — |
| **AUTH-5.04** Privilege change and revocation propagate to sessions, sync, caches, background jobs, **exports**, shared links | **Fail** | Nothing propagates, because nothing changes. `setUserRole` has zero callers, so no server response can alter the client's role; it is `'PRIMARY_CONTACT'` from process start to process end. **This is what makes round 3's export remediation inert.** All three Doctor Handover call sites are now gated — `medications_screen.dart:60`, `medication_schedule_screen.dart:50-52`, `my_care_screen.dart:168` — but the gate evaluates `canUserPerform('PRIMARY_CONTACT', 'share_handover')`, which is `true` by construction (`permissions.dart:52`). The service itself is still ungated (`handover_report_service.dart:323`), so there is no defence in depth either. | The brief asked whether roles are enforced anywhere that matters or only used to hide UI. **Answer: only to hide UI, and not even that — with the role pinned to the maximum value, no UI is hidden and no export is withheld.** Round 3's B-4 is best restated as: the screen layer gained gates, the service layer did not, and neither can fire. |
| **AUTH-5.05** Cross-tenant / confused-deputy tests cover predictable, indirect, stale, user-supplied identifiers | **Fail** | Zero such tests in either repo. `functions/src/__tests__/auth.test.ts` covers five cases, all 401-shaped (missing header, wrong format, invalid token, expired token, valid token for a new user) — none exercise `verifyPatientAccess`, `requirePrimary`, an empty `patientId`, or a foreign `memberId`. On the client, `test/utils/permission_test.dart` (310 lines, 49 tests) tests `canUserPerform` as a pure function and never tests that a non-`PRIMARY_CONTACT` role is ever *assigned*. | Both defects in AUTH-2.01 and AUTH-5.01 are exactly what a stale-identifier and empty-tenant test would have caught. Three test cases would close this. |

### 6 · Recovery and account change

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-6.01** Recovery resists enumeration, SIM swap, mailbox compromise, social engineering, token replay, recovery-loop abuse | **Warning** | There is no distinct recovery flow — sign-in *is* recovery. Possession of the SIM yields full account access with no second factor, no new-device notification, and no cooling-off. Recovery-loop abuse is unbounded on the client (AUTH-2.03). | SIM swap is a complete takeover of a medical record with zero friction and zero signal to the legitimate holder. Phone-OTP-only is the Indian consumer norm and is defensible **as a named accepted risk**; the total absence of any compensating control is not. Minimum mitigation: notify the previous session on a new-device sign-in (AUTH-7.03), and require a fresh OTP for deletion (AUTH-8.03). **OWNER-TBD.** |
| **AUTH-6.02** Recovery provides accessible alternatives; not solely dependent on a lost device/number | **Fail** | Recovery depends entirely on retaining the phone number. There is no alternative factor, no recovery contact, no email fallback, no in-app support-recovery path. The only route offered anywhere is a phone number in deletion copy (`en.json` → `delete_account_active_service_note`, `9990-911-911`). | A user who loses their number loses their entire care history with no path back. For a geriatric/palliative patient base — where the account holder may be an adult child managing an elderly parent's care and number changes are common — this is a foreseeable, high-frequency event. Pairs with 6.04 as **one** remediation item. |
| **AUTH-6.03** Email/phone/identity changes require recent authentication and **notify existing channels** | **Fail** | There is no flow to change the account's own login phone number (no screen, no route, no endpoint). Meanwhile `family.ts:148-154` lists `"phone"` and `"email"` among `allowedFields` on `PUT .../family/:memberId`, so a member's contact details can be rewritten with **no recent-auth requirement, no notification to the affected member, and — per AUTH-5.01 — no ownership check.** | Changing a member's phone silently redirects every notification and, once invite-acceptance is built, the identity binding. Requires recent-auth + notify-both-channels before this endpoint is exposed. |
| **AUTH-6.04** Recovery codes / backup authenticators generated, stored, rotated, consumed, revoked securely | **Fail** | None exist in any form. | The mechanism gap behind 6.02. Not graded N/A: absence of an unimplemented safeguard is a gap, not an inapplicable control. |
| **AUTH-6.05** Support-led recovery has identity standards, separation of duties, evidence handling, approval, audit, escalation | **Fail** | Nothing documented in the repo. And this is not theoretical: the app's **primary** deletion outcome routes the user to unspecified phone support — `en.json` → `delete_account_done_login_pending`: "Pending: we could not remove your login automatically. Call us and we will do it." (see AUTH-8.04 for why this is the *usual* branch). | The app actively directs users into a manual support process for a destructive, identity-bearing account action, and no identity-verification standard, approval step, or audit trail sits behind it. Either build the re-auth path so support is not needed, or write the support procedure. **OWNER-TBD.** |

### 7 · Abuse detection and response

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-7.01** Rate, velocity, reputation, fraud controls on login, signup, verification, invitation, privileged operations | **Warning** | Real limiters exist server-side: `index.ts:32-51` — `generalLimiter` 100/15 min, `authLimiter` 5/15 min on `/auth`, `paymentLimiter` 10/15 min. **But** `app.set("trust proxy", …)` is never called (`grep -rn "trust proxy\|keyGenerator" functions/src` → no hits), so behind Cloud Functions/GFE `req.ip` is not reliably the client address and the per-IP keying may collapse to a single shared bucket — which would turn `authLimiter` into a **global** 5-per-15-minutes cap and a trivial denial of service. Client-side, OTP resend is uncapped (AUTH-2.03), and the OTP send path calls Firebase directly and never traverses these limiters at all. | The limiter effectiveness is **unverified** and needs production traffic or a staging deploy to settle — see BLOCKED-OWNER. Set `trust proxy` explicitly and confirm the key. |
| **AUTH-7.02** Detection for credential stuffing, spraying, **MFA fatigue**, bot signup, session theft, impossible travel, mass account actions | **Fail** | No detection layer of any kind. No App Check / Play Integrity / DeviceCheck configured (round 3 `SECURITY_PRIVACY_AUDIT.md` B-2 recorded the assistant function as having "no App Check"; nothing has been added). No auth-event logging beyond `logger.error` on failure paths. MFA fatigue is actively enabled by the uncapped resend. Stuffing/spraying are not applicable to OTP, but bot signup and mass account actions are, and neither is watched. | Enable Firebase App Check and cap resends; those two close the practically reachable vectors. Full anomaly detection is not proportionate pre-launch — this Fail is a *low-severity* member of the list. |
| **AUTH-7.03** Security notifications privacy-safe, actionable, localized, accessible, with a safe route to revoke or report | **Fail** | Zero security notifications. No new-device alert, no sign-in alert, no role-change alert, no removal alert. The delivery infrastructure exists and is unused for this purpose (FCM in `firebase_service.dart:300-367`; a `notification_log` table at `sql/001_initial_schema.sql:403`). | The single cheapest mitigation for the SIM-swap exposure in 6.01, and it is one message on an already-built channel. |
| **AUTH-7.04** Lockout avoids DoS and provides a **recoverable, explained** state | **Fail** | The app has no lockout of its own, and it mis-reports Firebase's. `auth_provider.dart:146-153` wraps `verifyOtp` in a bare `catch (e)` and sets the fixed string `'Invalid OTP. Please try again.'` for **every** exception — including `too-many-requests`, `session-expired`, and network failure. (The *send* path does better: `firebase_service.dart:65` passes `e.message` through.) | A rate-limited user is told their correct code is wrong, with no explanation, no wait time, and no recovery route — so they retry, deepening the block. Branch on `FirebaseAuthException.code` (not on the message string — `CLAUDE.md` forbids branching on user-facing text) and surface a distinct, localized "too many attempts, try again in N minutes". |

### 8 · Account deletion and closure

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| **AUTH-8.01** Accessible in-app initiation path where platform policy requires it | **Pass** | Route `'/delete-account'` (`main.dart:749-751`) reachable from Settings (`settings_screen.dart:278`). Satisfies App Review 5.1.1(v) at the *initiation* level. Copy is localized in both `en.json` and `hi.json` (27 keys each, zero missing — verified). The confirm field uses `labelText` rather than `hintText` so VoiceOver has an accessible name (`delete_account_screen.dart:281-284`). | Pass on initiation only. Whether the deletion *completes* is 8.04, and it does not. |
| **AUTH-8.02** Deletion explains consequences for purchases, shared/owned content, **other members**, exports, legal retention, backups, **re-registration** | **Warning** | The copy is genuinely good and the doc comment at `delete_account_screen.dart:24-43` is an honest account of a prior overclaim. It covers what is deleted (4 bullets), what is retained and why (Indian tax law on invoices; ongoing medical/legal matters), an active-service warning with a phone number, and — best of all — a done-vs-requested split in the final dialog (`:153-159`). **Missing:** the effect on **other family members** (the backend refuses to remove a primary contact at all — `family.ts:212-216` — so deleting the primary contact's account orphans the household); **backups**; and **re-registration** (since the credential usually survives, signing in again with the same number restores the account — see 8.04). | Add three sentences. Low effort, and re-registration in particular is a statement the user will otherwise discover by accident. **OWNER-TBD.** |
| **AUTH-8.03** Authentication, grace/reversal period, cancellation, immediate security revocation | **Fail** | The destructive action requires **no authentication whatsoever** — `_canSubmit` (`delete_account_screen.dart:72-76`) is a checkbox plus typing the word "DELETE". No re-auth, no OTP, no biometric (none exists). No grace or reversal period. No cancellation path: the local record is written with `'deliveredToServer': false` (`:89`) and **no screen displays it or offers to withdraw it**. | Anyone holding an unlocked phone — on a device explicitly modelled as shared and passed between family members and hired caretakers — can irreversibly wipe the patient's local care history in about ten seconds. Require a fresh OTP before submit, and add a 7-day reversible window. |
| **AUTH-8.04** Deletion completes across authoritative stores, processors, devices, sessions, notifications, retention schedules, and is **verifiable** | **Fail** | **The brief asked what the user actually experiences. Here it is, traced.** `delete_account_screen.dart:126-138` calls `FirebaseService().currentUser.delete()`. Firebase rejects `delete()` with `auth/requires-recent-login` for any session older than roughly five minutes, and **there is no re-authentication path anywhere in the codebase** — `grep -rn "reauthenticate\|requires-recent-login\|requiresRecentLogin" lib test ../housepital-backend/functions/src` returns **zero hits**. The `catch` at `:134-138` swallows the failure and only logs it. So in the realistic case — a user opens Settings some minutes into a session — the sequence is: all local data is wiped (`:143` `SessionScope.clearSession`), the user is signed out (`:145`), and a dialog says "Pending: we could not remove your login automatically. Call us and we will do it." **The Firebase credential survives, the phone number stays registered, and signing in again with the same number returns them to the account.** Server-side: nothing is sent — the "durable request" is a `SharedPreferences` JSON blob under `housepital_pending_deletion` that **no code ever reads** (`grep` → one constant, one write at `:84`, one preserve-list entry at `auth_provider.dart:233`; zero readers). This is round 3's **R3-5**, still open. Notifications: the FCM token is never deleted and the `fcm_tokens` row never removed, so push about the patient continues to arrive. Verifiable only by telephoning support. | The user's honest summary: *the phone is wiped, the account is not.* The copy does not lie about this — which is why 8.02 is only a Warning — but the outcome still fails 5.1.1(v) and DPDP §12. Fix order: (1) call `reauthenticateWithCredential` with a fresh OTP before `delete()`; (2) delete the FCM token and its row; (3) build the read-and-replay side of `pendingDeletionKey` so the write is not decorative. |
| **AUTH-8.05** Banned, deceased, organization-owned, child, fraud-held, legally retained accounts have documented exception workflows | **Fail** | No account-state model (AUTH-1.02) and no documented workflow for any of these categories. Legal retention is acknowledged in copy (`delete_account_kept_2`) with no mechanism behind it. | For a home-healthcare provider serving geriatric, oncology, and palliative patients, **the deceased-patient workflow is routine, not an edge case** — and today the app has no state to express it, no way for a family to close a deceased patient's record, and deletion copy that speaks only to the account holder deleting their own account. This is the finding in this section most specific to what Housepital actually does. |

---

## CRITICAL — `family_members.user_id UNIQUE` and `.first()` versus multi-patient accounts

The brief flagged this as critical. It is, and it is worse than a single constraint.

**The constraint.** `sql/001_initial_schema.sql:45`:

```sql
user_id VARCHAR(128) NOT NULL UNIQUE COMMENT 'Firebase Auth UID',
```

`family_members` is the join table between a Firebase user and a patient — it carries both
`user_id` and `patient_id` (`:45-46`). A `UNIQUE` index on `user_id` therefore means **one row
per Firebase user, and so exactly one patient per account, forever.** `middleware/auth.ts:40-42`
and `auth.ts:23-25` both take `.first()`, which is not the cause but is consistent with it, and
which means the middleware silently picks one membership even if the constraint were lifted.

**The product promise this breaks.** Multiple patients per account is a core promise and the
client is already built for it: `AppProvider._patients` is a list, `switchPatient` (`:187`)
exists, there is a switcher in the Home header (`home_screen.dart:1775`), `/add-patient` is a
shipped route (`main.dart:538`), and `SessionScope` exists *specifically* to make switching safe.
An adult child managing both parents is the ordinary case for this business.

**The backend already contradicts itself about it.** `patients.ts:34-45` is written for the
many-to-many world:

```ts
const memberships = await db("family_members").where("user_id", authReq.uid).select("patient_id");
const patientIds = memberships.map((m: any) => m.patient_id);
const patients = await db("patients").whereIn("id", patientIds);
```

`whereIn` over a set that the schema guarantees has at most one element. One of these two files
is wrong, and the schema is the one that will win at runtime.

**A second, immediate defect falls out of the same constraint.** `family.ts:61-63` adds a family
member with:

```ts
user_id: "",   // Will be linked when user registers
```

`user_id` is `NOT NULL`, so `NULL` — which MySQL would allow to repeat under a `UNIQUE` index —
is not available, and the empty string is a real value. **The first family member added anywhere
in the database claims `""`; the second insert, for any patient, in any household, fails with
`ER_DUP_ENTRY`,** surfacing to the user as the generic `500 {"error":"Failed to add family
member"}` at `:95-96`. The endpoint works exactly once per deployment. This is invisible today
only because `family_members_screen.dart` never calls it (AUTH-5.02).

**Also blocked by the same table.** The `role` column (`:51`) is
`ENUM('PRIMARY_CONTACT','FAMILY_MEMBER','PATIENT_SELF')` — `CARETAKER`, which `permissions.dart:23`
defines and `permission_test.dart:133-171` tests in nine assertions, has no storable value.

**Minimum fix:** drop the `UNIQUE` on `user_id`; add `UNIQUE KEY uk_user_patient (user_id,
patient_id)`; make `user_id` nullable and insert `NULL` (not `""`) for un-linked invitees; add
`CARETAKER` to the role enum; replace `.first()` in `middleware/auth.ts` with an explicit
active-patient selection (header or path parameter) and re-derive `role` per patient rather than
per user. Note that this last point means `AuthRequest.role` is **the wrong shape** — role is a
property of a (user, patient) pair, not of a user, and every `requirePrimary` check inherits that
error.

---

## Answers to the specific questions asked

| Question | Answer |
|---|---|
| What does the commented-out auth gate mean for controls that assume a signed-in user? | The build never produces a signed-in user, so those controls are graded against the code as written — which is what ships the day the line is uncommented. Beyond the bypass: `LoginScreen` is unroutable, and neither `LoginScreen` nor `OtpScreen` navigates after its action, because both were written to be rebuilt *by* the gate. Uncommenting `main.dart:418` alone leaves the user stuck on the login screen. |
| Is `auth_provider.dart:93` reaching `FirebaseAuth.instance` directly, and is refresh untestable? | **Confirmed.** `FakeFirebaseService` cannot intercept a static, and `handleUnauthorized`/`_refreshToken` have zero test coverage. The assessment is that it is worse than untestable: any `FirebaseAuth.instance` failure is caught, returns `false`, and forces a `logout()`, so a transient failure is handled identically to a revoked token. |
| Does logout preserve only what it should? Does anything patient-scoped survive? | **The two preserved keys are correct and nothing patient-scoped survives the sweep** — `auth_provider.dart:231-238` removes every key except `housepital_schema_version` and `housepital_pending_deletion`, so per-patient order keys, addresses, and daily ratings all go. **But two things that should not survive do, because they are not `SharedPreferences` keys and the sweep cannot see them:** `ApiService._authToken` (in-memory, never cleared, no clear method on `IApiService`) and the registered FCM token (device- and server-side). And the preserved `housepital_pending_deletion` is never read by anything, so preserving it currently achieves nothing. |
| Is there a re-auth path for `currentUser.delete()`? What does the user experience? | **No re-auth path exists** (zero grep hits for `reauthenticate`). For any session older than ~5 minutes the user experiences: local data wiped, signed out, told "Pending: we could not remove your login automatically. Call us and we will do it", handed a reference number that exists only in a local key nothing reads — and, if they sign in again with the same number, they get the account back. |
| Are roles enforced anywhere that matters, or only used to hide UI? | **Neither, in effect.** The matrix is correct and well tested as a pure function; the UI gates are wired at 31 call sites including all three handover exports. But `setUserRole` has zero callers, so the role is the constant `'PRIMARY_CONTACT'` and every gate returns `true`. Round 3's ungated-export finding is now half-fixed: screens gate, the service layer does not, and neither can fire. |
| Do family invitations exist end to end, and does `family.ts` support them? | **No, at both ends.** The screen is a hardcoded mock list with an in-memory add and no API call; the `/invite` endpoint validates a phone number and returns `{success:true}` while recording nothing; there is no invitations table, token, expiry, or acceptance endpoint. |
| `family_members.user_id UNIQUE` + `.first()` — what does it mean for multi-patient accounts? | Multi-patient accounts are **structurally impossible**, while the client and `patients.ts:34-45` are both already built for them. It additionally makes `family.ts`'s add-member endpoint fail on the second use across the entire database, and makes the `CARETAKER` role unstorable. Full analysis and fix above. |

---

## Scorecard

**Pass 2 · Warning 13 · Fail 21 · N/A 4** (40 controls) · **BLOCKED-OWNER 2**

The 21 Fails collapse into **seven** remediation items; they are not 21 independent defects.

---

## Release blockers (every Fail)

Ranked. The first three are the ones I would not ship past under any framing.

1. **Broken tenant isolation, and privilege that *widens* on removal** — AUTH-2.01, 4.03, 5.01,
   5.04, 5.05. `middleware/auth.ts:105` short-circuits on an empty `authReq.patientId`, so any
   OTP-authenticated user with no membership passes `verifyPatientAccess` for every patient; and
   because removal drops a member into exactly that state, `family.ts:219` makes access broader.
   Plus two routes missing object-ownership checks that the legacy route already has.
2. **`family_members.user_id UNIQUE`** — AUTH-1.02, 5.02. Blocks the multi-patient promise,
   breaks add-member after the first row database-wide, and makes `CARETAKER` unstorable.
3. **Deletion does not complete and cannot be re-authenticated** — AUTH-8.03, 8.04, 6.05.
   No re-auth for `delete()`, no OTP before the destructive action, a write-only deletion record,
   FCM never revoked, and the fallback is an undocumented phone-support process.
4. **The role is a hardcoded constant** — AUTH-5.04 (and the cause of 2.01's client half).
   Every permission gate in the app returns `true`. One line to assign, but until then the
   entire authorization layer is decorative.
5. **Session lifecycle is undefined and untested** — AUTH-4.01, 4.03. No expiry, no revocation,
   no app-lock; bearer token survives logout; refresh path untestable and fails toward logout.
6. **Consent is not captured, separated, or versioned** — AUTH-2.04, and no identity/state model
   behind it (1.02). Combined checkbox, links pointing at `/about`, nothing recorded.
7. **No recovery infrastructure, no security notifications, no explained lockout** — AUTH-6.02,
   6.03, 6.04, 7.02, 7.03, 7.04, 8.05. Individually lower severity; collectively this is the
   absence of the whole abuse-and-recovery half of the lifecycle. The two cheapest wins inside it:
   branch `verifyOtp`'s error on `FirebaseAuthException.code` (7.04), and send a new-device
   notification on the channel that already exists (7.03).

---

## Warnings requiring risk acceptance

| # | Control(s) | Risk | Proposed mitigation | Owner / due |
|---|---|---|---|---|
| W1 | 1.01, 1.03 | Clinical surfaces open with no identity; guest tier never designed | Enable the gate behind a deliberate guest tier; write the necessity decision | OWNER-TBD · before first real-data build |
| W2 | 1.04 | Minors' data processed with no guardian-consent model (DPDP §9) | Written position + age/guardian capture at onboarding | OWNER-TBD · before first real-data build |
| W3 | 2.02, 2.03 | Unverified family members; **uncapped OTP resend** (fatigue + SMS-pumping cost) | Cap resends at 3–5 with backoff; bind member creation to invite acceptance | OWNER-TBD · with the invite build |
| W4 | 2.05 | No expiry for abandoned unverified accounts — **becomes a Fail when the gate is enabled** | Retention schedule + scheduled cleanup function | OWNER-TBD · with gate enable |
| W5 | 3.01, 6.01 | SMS OTP is the sole factor; SIM swap is a silent full takeover of a medical record | Accept SMS-only (Indian norm) **but** add new-device notification and step-up OTP on delete/pay | OWNER-TBD |
| W6 | 4.02 | No device/session visibility or revocation | Sessions table + settings screen, post-launch | OWNER-TBD |
| W7 | 4.04 | In-memory token outlives the session; nothing in secure storage | Add `clearAuthToken()` to `IApiService`, call from `logout()` | OWNER-TBD · same edit as blocker 5 |
| W8 | 4.05 | **`SessionScope` still imported by zero tests** (round-3 carried item, confirmed open) | One integration test: `install()` → switch → assert fan-out | OWNER-TBD · next test pass |
| W9 | 7.01 | `trust proxy` unset — rate-limiter keying may collapse to one global bucket | Set `trust proxy` explicitly; verify the key against a staging deploy | OWNER-TBD |
| W10 | 8.02 | Deletion copy omits effect on other members, backups, and re-registration | Three sentences | OWNER-TBD |

---

## BLOCKED-OWNER — needs access I do not have

- **B1 — Firebase Console.** Phone-auth quotas, SMS region/abuse settings, App Check enrolment,
  API-key restrictions, and whether `revokeRefreshTokens` has ever been used. AUTH-2.03, 3.01,
  7.01, 7.02 are graded on client/backend source only; the console holds evidence that could
  move 2.03 and 7.01 in either direction.
- **B2 — A deployed backend with production-like traffic.** `api.housepital.in` does not resolve,
  so no control in families 3–5 could be exercised against a running service. In particular the
  `trust proxy` / rate-limiter-keying question (W9) and the tenant-isolation defect in blocker 1
  are read from source and have not been demonstrated against a live endpoint.

---

## Limitations of this audit

1. **MASTER-4.04 — this is source review, not release-artifact review.** No IPA, no signed build,
   no device, no production traffic. Every verdict is derived from source at `9127713` plus
   `../housepital-backend` at its working-tree state.
2. **Per the brief I did not run `flutter test`, `flutter build`, or `flutter clean`.** Test
   findings come from reading test sources and from `grep` over `test/`. The central results the
   brief authorises me to cite (analyze clean, design gate passes, 1,819 tests pass) are recorded
   but are not evidence about *this* module's coverage — the coverage gaps I report (zero tests
   for `handleUnauthorized`, zero test imports of `SessionScope`, zero cross-tenant tests) are
   absences I verified by grep, not by running anything.
3. **Firebase-internal behaviour is asserted from documented platform behaviour, not observed.**
   Specifically the `auth/requires-recent-login` window on `User.delete()` (~5 minutes) and the
   60-minute ID-token lifetime. Both are stable, documented Firebase behaviours and the code
   comments in `auth_provider.dart:26-30` and `delete_account_screen.dart:135` assume the same
   values; the *code path* consequences I describe (the swallowed catch, the absent re-auth) are
   verified directly in source.
4. **The backend was read at its working-tree state**, not at a tagged release, and I did not
   verify that `sql/001_initial_schema.sql` matches any deployed database.
5. **`../housepital-api` (Laravel, staff-side) was not audited.** It is a different identity
   domain and belongs to another module's scope; where the two schemas conflict, the brief
   already records it.
6. **I made no code changes.** This file is the only thing written.
