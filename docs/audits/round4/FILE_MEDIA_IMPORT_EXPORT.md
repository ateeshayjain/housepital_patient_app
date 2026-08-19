# File, Media, Import & Export — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** File/Media Import & Export · **Scope:** source review (see Limitations)

## Applicability

MASTER-3.09 activates control family FILE for any product that "accepts, creates, previews,
transforms, stores, syncs, exports, downloads, or shares files or media." This app does all
of these:

| Surface | Evidence |
|---|---|
| Accepts images (camera + gallery) | `image_picker` at six call sites — `settings_screen.dart:70`, `patient_profile_screen.dart:205`, `chat_screen.dart:121`, `raise_concern_screen.dart:96`, `document_repository_screen.dart:613,631`, `return_screen.dart:316` |
| Uploads to cloud object storage | `firebase_service.dart:116` `uploadFile()` → `putFile` |
| Enforces server-side limits | `storage.rules` (10 MiB + `contentType.matches('image/.*')`) |
| Creates and exports PDFs | `invoice_pdf_service.dart`, `handover_report_service.dart` |
| Shares to external apps | `Printing.sharePdf`, `SharePlus.instance.share` (`document_repository_screen.dart:442`) |
| Downloads / launches external content | `_openDocument()` → `launchUrl` (`document_repository_screen.dart:510`) |
| Renders remote media | `ProductImage` / `CachedNetworkImage` (`common_widgets.dart:108-138`) |

The module applies in full. **No round-3 report exists for this module** — this is the first
look, so I worked the checklist systematically rather than diffing prior findings.

---

## The headline finding, stated first

**Nothing in this codebase, or in either backend, strips EXIF metadata from uploaded photos.
Worse: `image_picker` actively re-attaches GPS coordinates after resizing, on both platforms.**

This is not an inference from "we didn't find stripping code." It is positive evidence from the
resolved plugin source:

**Android** (`image_picker_android 0.8.13+14`, per `pubspec.lock`):
`ImageResizer.java:69` calls `copyExif(imagePath, file.getPath())` after every resize, which
delegates to `ExifDataCopier.copyExif()`. That copier's attribute list contains **32 `TAG_GPS_*`
entries**, including:

```java
ExifInterface.TAG_GPS_LATITUDE,          // ExifDataCopier.java:102
ExifInterface.TAG_GPS_LONGITUDE,         // ExifDataCopier.java:104
ExifInterface.TAG_GPS_ALTITUDE,          // ExifDataCopier.java:106
ExifInterface.TAG_GPS_TIMESTAMP,         // ExifDataCopier.java:107
ExifInterface.TAG_GPS_DATESTAMP,         // ExifDataCopier.java:129
```

So passing `maxWidth`/`imageQuality` — which a reader might reasonably assume re-encodes the
image clean — **does not** drop location. The plugin resizes, then deliberately puts the GPS
block back.

**iOS** (`image_picker_ios 0.8.13+6`): `pickImage`'s `requestFullMetadata` parameter defaults to
`true` (`image_picker-1.2.1/lib/image_picker.dart:78`), and **no call site in this repo overrides
it** (`grep -rn "requestFullMetadata" lib/ test/` → no matches). With it true,
`FLTImagePickerPlugin.m:574` resolves the original `PHAsset`, then
`FLTImagePickerPhotoAssetUtil.m:45` reads metadata via
`getMetaDataFromImageData:` — which is `CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)`,
i.e. **every** property dictionary including `kCGImagePropertyGPSDictionary` — and
`FLTImagePickerPhotoAssetUtil.m:89` writes it back onto the re-encoded JPEG via
`imageFromImage:withMetaData:`.

**Neither backend remediates it.** `housepital-backend/functions/src/config/firebase.ts:10`
exports `admin.storage()` but nothing consumes it for these paths; `grep -rniE "exif"` across
both `../housepital-backend` and `../housepital-api` returns nothing.

**Consequence.** The camera-source call sites are used to photograph prescriptions and equipment
inside the patient's home; the gallery-source call sites read photos the phone's camera already
geotagged. Every such upload carries the patient's **home coordinates** to Firebase Storage, at a
precision of a few metres. For a Delhi NCR home-healthcare app whose users are elderly and
chronically ill patients, an EXIF GPS pair *is* the home address. Combined with FILE-4.02 below
(download tokens that cannot be revoked), a location disclosure here is permanent.

Graded at **FILE-3.03 (Fail)** and **FILE-7.04 (Fail)**.

---

## Control results

### 1. Format and trust inventory

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-1.01 | **Fail** | No format/limit inventory exists in `docs/`. The de-facto limits are scattered and mutually inconsistent across the six picker sites: `maxWidth` is 512 (`settings_screen.dart:70`, `patient_profile_screen.dart:205`), 1024 (`chat_screen.dart:123`), 1200 (`raise_concern_screen.dart:99`), and **absent** (`document_repository_screen.dart:613,631`; `return_screen.dart:316`). `imageQuality` is 75 / 80 / 85 / unset across the same sites. | A reviewer cannot state the app's accepted-format envelope. The two unbounded sites can emit 10–20 MB originals from a modern phone camera, which exceed the `storage.rules` 10 MiB cap and fail as a generic error. **Owner: OWNER-TBD. Fix: one `MediaIntakePolicy` constant set consumed by all six sites, plus a table in `docs/`.** |
| FILE-1.02 | **Fail** | Trust is derived from a client assertion, not content. Both upload sites hardcode the type: `contentType: 'image/jpeg'` (`chat_screen.dart:136`, `raise_concern_screen.dart:331`). `firebase_service.dart:134` passes that string straight into `SettableMetadata` with no inspection of the bytes. | The `storage.rules` `contentType.matches('image/.*')` test (`storage.rules:70`) can only ever see the string the client chose to send, so it validates nothing an attacker controls. See FILE-2.01. |
| FILE-1.03 | **Warning** | No explicit allow/deny/sandbox decision for any high-risk format. The rules' `image/.*` glob would admit `image/svg+xml` (active content) if a client asserted it. No archive, font, or document format is accepted anywhere. | Blast radius is bounded today: no server-side parser, thumbnailer, or OCR consumes these objects (`grep` of both backends), and the patient app never renders them (FILE-5.01). Risk lands on whatever the staff app does with the bytes — out of this repo. **Owner: OWNER-TBD. Fix: narrow the rule to an explicit `image/(jpeg|png|heic)` allowlist.** |
| FILE-1.04 | **Fail** | No documented retention, deletion, moderation, licensing, or ownership position for uploaded photos. `storage.rules:76,84` set `allow update, delete: if false` — objects are **immutable and permanent**, with no expiry and no client or server deletion path anywhere in either repo. | India's DPDP Act requires erasure on request and purpose-limited retention. Today a patient's prescription photo — with GPS attached — cannot be deleted by the patient, by support, or by the app. This is a compliance gap, not just a hygiene one. **Owner: OWNER-TBD.** |

### 2. Intake and validation

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-2.01 | **Fail** | No magic-byte or signature check exists. `firebase_service.dart:126-137` checks only `file.exists()`, then uploads. Declared type is the hardcoded literal from the caller. | Any bytes can be stored as `image/jpeg`. Mismatches do not fail — they are asserted away. Server-side rules cannot compensate because Firebase Storage rules cannot inspect object content. **Fix requires either a client-side signature sniff or a backend-issued upload URL (option 2 in `storage.rules:47-49`).** |
| FILE-2.02 | **Fail** | No pre-upload budget is enforced client-side: `grep -n "length()\|lengthSync\|fileSize\|statSync"` over `firebase_service.dart`, `chat_screen.dart`, `raise_concern_screen.dart` → **no matches**. The only bound is `storage.rules:69` (`size < 10 * 1024 * 1024`), and `docs/KNOWN_ISSUES.md:19` records that file as **undeployed**. | With the rules undeployed the effective size limit is **unbounded**. Even once deployed, the check happens after the full body is transferred, so an oversize photo burns the patient's mobile data before failing with the generic "Couldn't send photo" (`chat_screen.dart:144`). **Owner: OWNER-TBD. Fix: check `File.lengthSync()` before `putFile` and deploy the rules.** |
| FILE-2.03 | **Warning** | Traversal is mitigated — both upload sites reduce the picker path with `p.basename(...)` (`chat_screen.dart:132`, `raise_concern_screen.dart:327`). Not mitigated: object keys are guessable and rules grant `allow read: if isSignedIn()` (`storage.rules:74,82`), so any authenticated user can read any patient's photo by guessing a path. The `concerns/{patientId}_{batchTs}/` key packs two ids into one segment using `_`, a character legal inside every patient id. | `storage.rules:11-40` documents both issues candidly and explains why a `request.auth.uid == patientId` rule would deny 100% of uploads (`grep -rn "\.uid" lib/` → zero hits). That honesty is a real mitigation for the reviewer, but not for the user. **Owner: OWNER-TBD. Fix: custom claims (`storage.rules:44-46`), and split the concerns path into two segments.** |
| FILE-2.04 | **N/A** | No archive format is accepted, produced, or expanded anywhere in the app. The only formats crossing the boundary are picker-sourced images and app-generated PDFs. Zip-slip, symlink escape, decompression bombs, and recursive archives have no reachable code path. | Written rationale recorded; this is a genuine non-applicability, not an untested control. |
| FILE-2.05 | **Warning** | `firebase_service.dart:139-142` wraps the upload in a broad `catch` that logs and returns `null`; both callers handle the null with user-facing copy (`chat_screen.dart:141-149`, `raise_concern_screen.dart:353-360`). That part is sound. But nothing validates before upload, and 4 of 6 picker sites have no `try`/`catch` at all (see FILE-7.02). | Malformed input is not *handled*, it is *forwarded*. No crash results, but there is no safe-failure design either. **Owner: OWNER-TBD.** |

### 3. Processing and transformation

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-3.01 | **Warning** | No antivirus, content-safety, or malware scan on any upload path in either repo. No server-side parser/thumbnailer exists to sandbox. Plugin versions are current (`image_picker 1.2.1`), so patching is not the gap. | Bounded by the absence of server-side processing, but a stored-malware vector into the coordinator/staff app remains unassessed. **Owner: OWNER-TBD.** |
| FILE-3.02 | **Fail** | `image_picker` writes to the OS temp directory; nothing in the app cleans those files after upload success, failure, or cancellation. Worse, `app_provider.dart:121` **persists a temp path into permanent storage**: `prefs.setString('profile_photo_path', path)`, re-read at `app_provider.dart:114`. | iOS purges `tmp/` under storage pressure and on some upgrades. The stored path then dangles, and `settings_screen.dart:115` builds `FileImage(File(_profilePhotoPath!))` with **no `errorBuilder`** — the avatar throws into the Flutter error handler on every rebuild. Same pattern at `patient_profile_screen.dart`. **Fix: copy the picked file into the app's documents directory and store that path.** |
| FILE-3.03 | **Fail** | **EXIF/GPS is preserved, not stripped — see "The headline finding" above for the full plugin-source evidence chain.** No stripping library is present (`pubspec.yaml` has no `exif`, `image`, or `flutter_image_compress` entry), no call site sets `requestFullMetadata: false`, and neither backend post-processes. | Patient home coordinates are embedded in every prescription and evidence photo, and reach an object store whose access tokens cannot be revoked (FILE-4.02). **This is the single highest-severity finding in this module. Owner: OWNER-TBD. Fix (smallest viable): pass `requestFullMetadata: false` at all six sites — this alone kills the iOS path; for Android, re-encode the bytes before upload, since the plugin re-attaches GPS regardless.** |
| FILE-3.04 | **Warning** | `raise_concern_screen.dart:313-339` batches uploads 3-at-a-time and reports partial failure honestly (`_uploadEvidence` returns only successful URLs; `:346-360` tells the user how many failed). Good. But retry re-enters `_uploadEvidence` with a **new** `batchTs` (`:317`), so the previously-succeeded objects are re-uploaded under a fresh prefix and the originals are orphaned — permanently, because `storage.rules:84` forbids delete. | Duplicate billing-free but unbounded storage growth, and orphans that no one can remove. Not idempotent. **Owner: OWNER-TBD.** |
| FILE-3.05 | **Pass** | PDFs are built with the `pdf` package's declarative widget tree (`invoice_pdf_service.dart`, `handover_report_service.dart`) — no embedded JavaScript, no forms, no external resource references. Generated output gains no privilege over its source. | — |

### 4. Storage, sync, and access

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-4.01 | **Fail** | Two distinct scope failures. (a) Upload paths carry `patientId` but rules cannot enforce it — `storage.rules:33-35` states plainly that the file "does NOT stop one authenticated user from reading another patient's photo." (b) The **profile photo is stored under a single global preferences key**, `'profile_photo_path'` (`app_provider.dart:114,121`), with no patient in the key. `SessionScope.clearPatientData()` (`session_scope.dart:81-106`) never touches it, and it is absent from `_patientScopedPrefsKeys`. | Switching from patient A to patient B leaves **A's face photo displayed on B's profile screen**. This directly violates the CLAUDE.md contract that patient-scoped state is enumerated in `SessionScope`. **Owner: OWNER-TBD.** |
| FILE-4.02 | **Fail** | `firebase_service.dart:138` returns `await ref.getDownloadURL()`, and `chat_screen.dart:151-154` → `:82-88` writes that URL into the Firestore chat document (`'imageUrl': ?imageUrl`). A Firebase download URL embeds a permanent `?token=` that is evaluated **before** Security Rules and is not subject to them. | The token is bearer-grade, never expires, and **a `storage.rules` change cannot revoke it** — only rotating the object's token via the Admin SDK can, and no such path exists. Every chat photo URL persisted to Firestore is therefore a permanent, unauthenticated, publicly-fetchable link to a patient photo carrying GPS EXIF. Anyone who can read the chat document (or a backup, export, or log of it) holds that link forever. **Owner: OWNER-TBD. Fix: store the storage *path*, not the download URL, and resolve to a short-lived signed URL at render time.** |
| FILE-4.03 | **Warning** | `putFile` is used directly (`firebase_service.dart:137`) with no resumable-session management, no integrity hash, no deduplication, no per-patient quota, and no cleanup of abandoned parts. | On the flaky mobile networks this app targets, a large upload restarts from zero. Combined with FILE-3.04, failed attempts accumulate as unreachable orphans. **Owner: OWNER-TBD.** |
| FILE-4.04 | **Warning** | Firebase Storage applies Google-managed encryption at rest by default; no CMEK, bucket-level retention, or residency configuration is declared in `firebase.json` or `storage.rules`. Account-switch behaviour is unsafe — see FILE-4.01(b). Data residency is unverified and matters for DPDP. | **Unverified**, not N/A: bucket location and encryption posture are console-side. Recorded under BLOCKED-OWNER. |
| FILE-4.05 | **Fail** | No delete, revoke, replace, move, rename, or version operation exists for uploaded objects — `storage.rules:76,84` deny all of them, and no server path substitutes. Separately, the document repository's delete is **memory-only**: `document_repository_screen.dart:535` does `setState(() => _documents.removeWhere(...))` against a `List` field in `State`, with no persistence layer behind it. | "Document deleted" (`:538`) is shown to the user for an operation that survives only until the widget is disposed. Deletion does not propagate anywhere because nothing was ever stored. **Owner: OWNER-TBD.** |

### 5. Preview, playback, and accessibility

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-5.01 | **Fail** | Two findings. (a) **Chat photos are uploaded but never displayed.** `chat_screen.dart:391-404`: when `isImage && imageUrl != null`, the widget renders a fixed 180×140 `Container` containing a static `Icon(Icons.image)` — the source comment reads `// Image thumbnail placeholder`. The `imageUrl` variable is read at `:268`, passed at `:275`, stored at `:357`, and **never used to fetch anything**. (b) `_openDocument` (`document_repository_screen.dart:493-523`) passes a stored URL to `launchUrl(uri, mode: LaunchMode.externalApplication)` after only `Uri.tryParse` — **no scheme allowlist**, so any scheme the OS honours would be launched. | (a) is a textbook half-wire — the full privacy cost of the upload (GPS EXIF, permanent token, unrevocable URL) is paid, and the feature it buys does not exist. The sender sees a grey box; only the coordinator's separate app can see the photo. (b) is not currently reachable (every seeded document has `fileUrl == null`), but it is an unvalidated sink awaiting the first backend that populates the field. **Owner: OWNER-TBD.** |
| FILE-5.02 | **Warning** | Mixed. Evidence photos are labelled per-item — `'Evidence photo ${index + 1} of ${_evidencePhotos.length}'` (`raise_concern_screen.dart:225`) — which is good practice. `ProductImage` uses a single generic `semanticLabel: 'Product photo'` for every product (`common_widgets.dart:131`), so a screen-reader user hears the same string for all ~100 bundled photos. The chat image placeholder (`chat_screen.dart:392`) carries no semantics at all. | Screen-reader users cannot distinguish products by image, and cannot perceive that a chat message contains a photo. **Owner: OWNER-TBD.** |
| FILE-5.03 | **N/A** | No audio or video file is imported, previewed, or played anywhere in the app. `RECORD_AUDIO` (`AndroidManifest.xml:5`) and `NSMicrophoneUsageDescription` (`Info.plist:69`) serve the voice assistant's live speech input, which is not a file-media surface. No playback control, captioning, or autoplay behaviour exists to assess. | Written rationale recorded. |
| FILE-5.04 | **Warning** | `ProductImage` degrades correctly on failure (`errorWidget`/`placeholder` → `icon()`, `common_widgets.dart:137-138`). Beyond that, the file/media flows were **not** verified for large text, keyboard, focus order, zoom, orientation, or RTL — that needs a device. The known-open round-3 Dynamic Type clamp at 1.4× applies to these screens too. | Stated plainly as **unverified**, not N/A. Requires device testing. **Owner: OWNER-TBD.** |

### 6. Export and portability

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-6.01 | **Warning** | No export documentation exists. The invoice PDF (`invoice_pdf_service.dart:150-158`) emits order id, date, status, an items table, and GST at 18% — but carries **no bill-to party, no seller GSTIN, no seller address, and no invoice number distinct from the order id**. It is not a compliant Indian tax invoice, though it is presented as "INVOICE" (`:131`). | A patient who submits this for insurance or tax reimbursement may have it rejected. **Owner: OWNER-TBD.** |
| FILE-6.02 | **Warning** | The two exporters differ sharply. **Invoice: correctly scoped.** It renders only the `order` map passed in, and orders are per-patient keyed (`housepital_orders_<patientId>`), so no cross-patient content can enter it; it also contains no patient identity at all, so there is nothing to misattribute. **Handover: misattributed by construction.** `handover_report_service.dart:107-114` reads `DemoData.patient`, `DemoData.medicalHistory`, `DemoData.medications`, `DemoData.vitalsHistory` — it **never reads `AppProvider.currentPatient`**. The filename is likewise built from `DemoData.patient.name` (`:308-314`). | It cannot leak a *real* other patient, because it never reads real patient data. But `AppProvider.addPatient()` lets a user add a genuine patient; the handover for that patient will name a fictional person and carry a fabricated medical history. Mitigation is real and on the artifact's face: a `SAMPLE DATA - NOT A CLINICAL RECORD` band (`:133`) plus `DemoMode.markServingDemoData` (`:105`). The band does not travel into the **filename**, which is what gets filed in a clinic. **Owner: OWNER-TBD.** |
| FILE-6.03 | **Pass** | Exports are small, synchronous, on-device PDF byte arrays handed straight to the platform share sheet (`Printing.sharePdf`). No server-side export package, no download link, no notification — so there is no link to expose on a lock screen and nothing to expire or rate-limit. The asynchrony requirement does not bite at this size. | — |
| FILE-6.04 | **Warning** | `Printing.sharePdf` writes a temp file for the share sheet; the app does not manage its lifecycle. Cancellation mid-share leaves it to OS cleanup. No orphaned-package concept exists because exports are not server-side. | Low impact, but unmanaged. **Owner: OWNER-TBD.** |
| FILE-6.05 | **Warning** | Independent validation is uneven. `invoice_pdf_service_test.dart` is genuinely good — it extracts and asserts **PDF text content**, including "quote-pending: PRO FORMA title, item listed, ZERO amounts" (`:93`) and "priced order: full invoice WITH amounts and GST" (`:114`), plus byte-level determinism (`:142`). `handover_report_service_test.dart` asserts only the `%PDF` magic bytes and equal lengths (`:15,16,24`) — it never inspects a single field of the 329-line report. No import path exists for either format, so no round-trip is possible. | The flagship clinical export is the one with no content assertions. **Owner: OWNER-TBD.** |

### 7. Sharing and external providers

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-7.01 | **Warning** | The document repository's Share button sends **only text metadata** — name, category, description, upload date (`document_repository_screen.dart:442-449`) — never the file. Yet the failure copy for Open reads "Tap Share to send it to yourself" (`:501,519`), directing the user to a control that cannot send the document. | The user is told a workaround exists that does not. Not a leak — under-sharing, not over-sharing — but a broken promise on the recovery path. **Owner: OWNER-TBD.** |
| FILE-7.02 | **Fail** | **4 of 6 picker call sites have no error handling.** Unprotected: `settings_screen.dart:70`, `patient_profile_screen.dart:205`, `chat_screen.dart:121`, `return_screen.dart:316`. Protected: `raise_concern_screen.dart:95-113` and `document_repository_screen.dart:612-626,630-644`, both of which catch and show "Camera not available" / "Gallery not available". | `image_picker` throws `PlatformException('camera_access_denied')` when the user denies the camera permission. At the four unprotected sites that exception is unhandled: the `await` never completes normally, no snackbar appears, and the button appears simply dead. The iOS usage strings are present and well-written (`Info.plist:73-76`), so the *prompt* is correct — it is the **denial path** that dead-ends, exactly as suspected. **Owner: OWNER-TBD. Fix: wrap all four in the `try`/`catch` pattern already used in `raise_concern_screen.dart`.** |
| FILE-7.03 | **Fail** | Firebase download tokens have good entropy but **no expiry, no revocation path, no audience scoping, no download control, and no access logging** — and they are persisted into Firestore chat documents (`chat_screen.dart:87`). See FILE-4.02 for the full mechanism. | A shared link that cannot be revoked is not a shared link, it is a permanent publication. **Owner: OWNER-TBD.** |
| FILE-7.04 | **Fail** | No surface anywhere tells the user that a photo they attach carries embedded metadata, that its location is preserved, that the resulting link is permanent and unrevocable, or that the object can never be deleted (`storage.rules:76,84`). No consent copy, no privacy note, no settings toggle. | Users cannot reason about a risk they are never shown, and the risk here is their home address. Directly compounds FILE-3.03. **Owner: OWNER-TBD.** |

### 8. Testing and operations

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| FILE-8.01 | **Fail** | No file corpus exists. Only three test files touch this module at all (`my_care_screen_test.dart`, `handover_report_service_test.dart`, `invoice_pdf_service_test.dart`), and all three exercise **PDF generation only**. Zero tests cover `uploadFile`, any `pickImage` call site, permission denial, oversize input, malformed images, or `storage.rules`. | The entire import half of "import & export" ships untested. **Owner: OWNER-TBD.** |
| FILE-8.02 | **Warning** | No fuzzing or adversarial testing. Graded Warning rather than Fail on the checklist's own "proportional to risk" wording: the app runs no parser of its own over untrusted bytes — images go device→storage without in-app decode, and the only decoders are Flutter's and the OS's. | Proportionality is the mitigation, and it holds only while no server-side processing is added. Revisit the moment a thumbnailer or OCR step lands. **Owner: OWNER-TBD.** |
| FILE-8.03 | **Fail** | Monitoring is `Log.warn`/`Log.error` to the local logger (`firebase_service.dart:129,140`). Round 3's still-open `logger.dart:63` unwired TODO means these do not reach a backend. No metric for upload failure rate, malware detection, resource limits, backlog, provider error, orphan count, or unauthorized-access attempts. | Upload failures are invisible to the operator. Given FILE-2.02 (rules undeployed → no size ceiling), an abuse spike would surface first as a storage bill. **Owner: OWNER-TBD.** |
| FILE-8.04 | **Fail** | No incident playbook for malicious upload, parser vulnerability, public-link exposure, cross-tenant file leak, corrupted export, or provider compromise — `docs/` contains none. The public-link case is the pressing one: with FILE-4.02 there is currently **no procedure that could revoke an exposed photo URL**, because the capability does not exist. | An exposure incident today has no containment step. **Owner: OWNER-TBD.** |

---

## Scorecard

**Pass 2 · Warning 15 · Fail 17 · N/A 2** (+ BLOCKED-OWNER 3)

Total controls: 36.

---

## Release blockers (every Fail)

The 17 Fails reduce to **seven root causes**. Fixing these closes all of them.

1. **EXIF/GPS is preserved on both platforms** (FILE-3.03, and the user-disclosure half of FILE-7.04). Patient home coordinates ship with every prescription and evidence photo. Smallest viable fix: `requestFullMetadata: false` at all six picker sites closes iOS; Android additionally needs a re-encode, because `ExifDataCopier` re-attaches GPS after any resize.
2. **Download tokens are permanent and unrevocable, and are persisted into Firestore** (FILE-4.02, FILE-7.03). A rules change cannot claw them back. Store the storage path, resolve to a short-lived signed URL at render.
3. **No content validation; type is client-asserted** (FILE-1.02, FILE-2.01, FILE-1.01). `contentType: 'image/jpeg'` is hardcoded at both upload sites, which makes the `storage.rules` type test decorative.
4. **No size ceiling in force** (FILE-2.02). No client-side check, and the only server-side cap lives in an **undeployed** rules file. Deploy `storage.rules`, and check length before `putFile`.
5. **Objects are immutable and permanent with no deletion path** (FILE-1.04, FILE-4.05). No patient, operator, or backend can delete an uploaded photo. This is a DPDP erasure gap, and it is what makes cause 1 irreversible.
6. **Profile photo is globally keyed and outlives its session** (FILE-4.01, FILE-3.02). Patient A's face photo shows on patient B's profile after a switch; the stored path also points into OS temp, which iOS purges, and the `FileImage` has no `errorBuilder`.
7. **Import round-trip and denial paths are unwritten** (FILE-5.01, FILE-7.02, FILE-8.01, FILE-8.03, FILE-8.04). Chat photos upload but render as a grey placeholder; 4 of 6 pickers dead-end on permission denial; no test, monitoring, or playbook covers any of it.

---

## Warnings requiring risk acceptance

All 15 carry impact, mitigation, and `OWNER-TBD` in the tables above. The four I would not accept silently:

- **FILE-6.02** — the doctor handover always names `DemoData.patient`, never the selected patient, and the misattribution reaches the **filename**, which is what a clinic files. The on-face `SAMPLE DATA` band is a genuine mitigation and is why this is a Warning and not a Fail.
- **FILE-6.05** — the flagship clinical export is asserted only on its `%PDF` magic bytes; the invoice, a lesser artifact, has far stronger content tests.
- **FILE-2.03** — object keys are guessable and `allow read: if isSignedIn()` grants any authenticated user read across patients. `storage.rules:11-49` documents this honestly and explains why the naive `uid == patientId` rule would break every upload.
- **FILE-3.04** — evidence-photo retry orphans the previous batch permanently, since delete is denied.

---

## BLOCKED-OWNER — needs access I do not have

1. **Is `storage.rules` actually deployed?** `docs/KNOWN_ISSUES.md:19` says no, and `storage.rules:6-11` warns that editing the file changes nothing live. Every size and type verdict in section 2 turns on this. Needs the Firebase console (`housepital-patient` → Storage → Rules).
2. **Bucket location, retention policy, and encryption posture** (FILE-4.04). Data residency is a DPDP question and is not declarable from source.
3. **Firebase App Check status.** Without it, the client assertion in FILE-1.02/2.01 can be replayed by any HTTP client holding an auth token. Console-side.

---

## Limitations of this audit

- **MASTER-4.04: this is a SOURCE review.** No release artifact was built and no production-like environment was exercised. I did not run `flutter test`, `flutter build`, or `pod install`, per the brief.
- **No photo was uploaded and no EXIF was read off a real artifact.** The EXIF verdict rests on the resolved plugin source in `~/.pub-cache` cross-checked against `pubspec.lock` (`image_picker_android 0.8.13+14`, `image_picker_ios 0.8.13+6`, `image_picker 1.2.1`), not on a hex dump of an uploaded object. The evidence chain is cited line-by-line above so it can be re-walked. Confirming it end-to-end needs a device and a bucket — that step is worth taking before the fix ships, to verify the fix.
- **The staff/coordinator app was not audited.** These photos are consumed there. What that app does with a `image/jpeg`-asserted object of arbitrary content is outside this repo and unassessed (bears on FILE-1.03, FILE-3.01).
- **FILE-5.04 is unverified, not N/A** — accessibility of the file/media flows under large text, keyboard, focus, zoom, orientation, and RTL requires a device.
- **No round-3 baseline exists for this module,** so no prior-round regression table is possible. Round-3 items that bear on these findings (`logger.dart:63` unwired, `storage.rules` undeployed, Dynamic Type clamp) were re-checked against HEAD and remain open.
- `ANTHROPIC_API_KEY` re-verified absent from this module's surface; no secret is embedded in any upload, filename, or PDF.
