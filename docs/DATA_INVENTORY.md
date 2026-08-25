# Data Inventory — what this app stores, and where it goes on deletion

**Purpose:** closes round-4 `DATA-1.01` (every category mapped
collection→deletion), `DATA-1.03` (consistent classification) and the
inventory half of `DATA-1.02`. Those were graded Fail because the
classification existed "in three code comments and nowhere else".

**Scope:** on-device stores only, plus the two files the app writes off-device.
Server-side stores are in `DATABASE_SCHEMA.md`; their retention is **not
defined anywhere**, which is `DATA-4.01`, still open.

**Update rule:** anything that gains a persisted key is added here in the same
edit, alongside its entry in `SessionScope` and its assertion in
`test/providers/patient_scope_isolation_test.dart`. A store missing from this
table is a store nobody has decided how to delete.

---

## Classification

| Class | Meaning |
|---|---|
| **Health** | Reveals a diagnosis, treatment, symptom or clinical measurement |
| **Personal** | Identifies a person or their home |
| **Financial** | Payment or billing record |
| **Account** | Belongs to the sign-in, not the patient |
| **Device** | Belongs to this phone, not to any person |

Health and Personal are patient-scoped: they must be cleared on a patient
switch as well as on logout. Account and Device must **not** be — clearing a
theme preference on a patient switch is a bug, not caution.

---

## On-device stores

| Key | Contents | Class | Scope | Cleared by |
|---|---|---|---|---|
| `housepital_patient` | Active patient identity | Personal | Patient | `AppProvider.clearSession` |
| `housepital_orders_<patientId>` | Order and booking history | Financial + Health | Patient | Per-patient key — a switch READS a different key; never overwritten |
| `housepital_assessments_<patientId>` | Clinical assessment requests | Health | Patient | As above |
| `housepital_cart_items` | Current cart | Health (implies need) | Patient | `CartProvider.clearPatientScopedData` |
| `housepital_saved_items` | Saved-for-later | Health (implies need) | Patient | `CartProvider.clearPatientScopedData` |
| `housepital_reminders` | Medication reminder schedule | **Health** | Patient | `RemindersProvider.clearPatientScopedData` |
| `housepital_saved_addresses` | Where a nurse is dispatched | **Personal** | Patient | `SessionScope._patientScopedPrefsKeys` |
| `daily_rating_<date>` | Daily satisfaction rating | Personal | Patient | `SessionScope` prefix sweep |
| `housepital_cache_*` | Dashboard blobs (30-min TTL) | Health | Patient | `CacheService.clear` |
| `housepital_schema_version` | Migration stamp | Device | Device | Never — it describes the store, not a person |
| `theme_mode` | Light/dark preference | Device | Device | Never |
| `housepital_pending_deletion` | Deletion reference + timestamp | Personal (identifier) | Account | **Preserved by design** — it is the user's only receipt |
| `__quarantine_v*_*` | Pre-migration blobs | Whatever the original was | Patient | **Preserved by design** — sole copy of pre-v2 order history |
| OS notification queue | Drug name + dose on the lock screen | **Health** | Patient | `MedicationReminderService.cancelAllReminders` |
| `hpl_img_*` temp dirs | Re-encoded photos from the home | **Health + Personal** | Patient | `ImagePrivacy.purgeAll` (switch/logout) and `purgeStale` (1 h) |

### Two deliberate exceptions

`housepital_pending_deletion` and `__quarantine_v*_*` survive logout on
purpose, and both are listed in `AuthProvider`'s preserve set.

The quarantine entries are the only surviving copy of any order history
written before schema v2 — destroying them on logout would silently complete
the data loss the migration exists to prevent. The pending-deletion record is
the user's reference number for a request the server has not yet confirmed;
deleting it on the logout that immediately follows would leave them with no
evidence they asked.

Both are **Personal data retained past a deletion request**, which is exactly
the kind of exception `DATA-4.04` requires to be disclosed rather than
discovered. They are disclosed here and in the deletion screen's copy.

---

## Off-device writes

| Artefact | Contents | Class | Delivery | Retention |
|---|---|---|---|---|
| Invoice PDF | Line items, amounts, patient name | Financial + Personal | Share sheet | Leaves the app entirely — **outside our control once shared** |
| Doctor handover PDF | Vitals, medications, care summary | **Health** | Share sheet | As above |
| Chat photo uploads | Photographs from the home | **Health + Personal** | Firebase Storage | **Indefinite. No erasure path.** `DATA-4.03`, still open |

---

## What this document does NOT establish

Naming an inventory is not the same as governing it. These remain open:

- **`DATA-4.01`** — no retention period is defined for any server-side
  category. The FAQ states deletion is "processed within 7 working days";
  nothing in either repo implements or measures that.
- **`DATA-4.03`** — deletion propagates to nothing outside this device.
  Firebase Storage photo URLs are permanent and unauthenticated.
- **`DATA-4.05`** — `housepital_pending_deletion` is a soft delete with no
  enforced hard-delete schedule behind it.
- **`DATA-5.01`** — only deletion has a UI. There is no access, correction,
  export or objection workflow.
- **`DATA-6.*` / `DATA-7.*`** — no backups exist, so no RPO, RTO, restore
  drill or playbook can.

Every one of those needs a backend that is running and a decision about how
long Housepital keeps things. Neither exists yet.
