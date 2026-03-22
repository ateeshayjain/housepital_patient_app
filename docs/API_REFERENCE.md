# API Reference

## Overview

All endpoints are served via a single Firebase Cloud Function (`api`) deployed to `asia-south1`. The Express app is mounted at the function root, so the full URL pattern is:

```
https://asia-south1-<project-id>.cloudfunctions.net/api/<route>
```

Runtime: Node.js + Express.js + TypeScript
Memory: 256MB | Timeout: 60s | Min instances: 0

## Authentication

All endpoints (except `/payments/webhook` and `/health`) require a Firebase Auth ID token in the `Authorization` header:

```
Authorization: Bearer <firebase-id-token>
```

### Middleware Stack

| Middleware             | Applied To                    | Effect                                           |
|------------------------|-------------------------------|--------------------------------------------------|
| `verifyAuth`           | All protected routes          | Verifies token, attaches uid/userId/patientId/role|
| `verifyPatientAccess`  | Patient-scoped routes         | Ensures URL patientId matches user's patient      |
| `requirePrimary`       | Write operations              | Blocks non-PRIMARY_CONTACT users (403)            |

---

## Health Check

### `GET /health`

No auth required.

**Response:**
```json
{ "status": "ok", "version": "1.0.0", "timestamp": "2026-03-22T..." }
```

---

## Auth

### `POST /auth/verify-otp`

Called after Firebase Auth phone verification succeeds on the client. Looks up or creates the user record.

**Auth:** Bearer token (verifyAuth)

**Response (existing user):**
```json
{
  "user_id": "uuid",
  "patient_id": "uuid",
  "name": "string",
  "phone": "string",
  "role": "PRIMARY_CONTACT | FAMILY_MEMBER | PATIENT_SELF",
  "preferred_language": "en | hi",
  "has_onboarded": true,
  "patient": { ... }
}
```

**Response (new user):**
```json
{ "user_id": null, "patient_id": null, "has_onboarded": false, "phone": "string" }
```

**Errors:** `500` -- Failed to verify user

---

### `POST /auth/onboarding`

Creates patient + family_member records for a new user. Called once during first-time setup.

**Auth:** Bearer token (verifyAuth)

**Input:**
```json
{
  "name": "string (required)",
  "relationship": "string",
  "preferred_language": "en | hi",
  "patient_name": "string (required)",
  "patient_age": "number",
  "patient_gender": "male | female | other",
  "patient_city": "string (required -- delhi/faridabad/gurgaon/noida/ghaziabad)",
  "patient_conditions": ["string"],
  "patient_address": "string"
}
```

**Response:** `201` -- Same shape as verify-otp (existing user)

**Errors:**
- `400` -- Missing required fields
- `400` -- Invalid city
- `409` -- User already onboarded

**Side effects:** Creates Firestore `user_patients` mapping doc

---

### `POST /auth/fcm-token`

Register or update FCM token for push notifications.

**Auth:** Bearer token (verifyAuth)

**Input:**
```json
{ "token": "string (required)", "device_type": "string" }
```

**Response:** `{ "success": true }`

**Errors:** `400` -- Missing token

---

## Patients

### `GET /patients`

Returns all patients the authenticated user has access to.

**Auth:** Bearer token

**Response:**
```json
{ "patients": [{ ...patient }] }
```

---

### `GET /patients/:id`

Get single patient detail.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "patient": { ...patient } }`

**Errors:** `404` -- Patient not found, `403` -- Access denied

---

### `PUT /patients/:id`

Update patient profile.

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Allowed fields:** name, age, gender, dietary_restrictions, mobility_status, doctor_name, doctor_phone, doctor_hospital, address, city, height, weight, diagnosis, iv_central_line, discharge_summary_available, feeding_type, mental_condition, motion_status, bp_sugar_insulin, requirement, conditions (JSON), medications (JSON), allergies (JSON), emergency_contacts (JSON)

**Response:** Updated patient object

---

### `GET /patients/:id/dashboard`

Aggregated dashboard data for the home screen.

**Auth:** Bearer token + verifyPatientAccess

**Response:**
```json
{
  "deployment": { ... } | null,
  "attendance_today": { ... } | null,
  "latest_vitals": { ... } | null,
  "report_summary": { "id": "...", "completed_tasks": 5, "total_tasks": 8, "submitted_at": "..." } | null,
  "billing_summary": { "pending_amount": 0 },
  "active_services_count": 2
}
```

---

### `GET /patients/:id/deployment`

Get active deployment for patient.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "deployment": { ... } | null }`

---

### `GET /patients/:id/attendance/today`

Today's attendance for the active deployment.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "attendance": { ... } | null }`

---

### `GET /patients/:id/attendance`

Paginated attendance history.

**Auth:** Bearer token + verifyPatientAccess

**Query:** `page` (default 1), `page_size` (default 20)

**Response:** `{ "attendance": [...], "total": 45 }`

---

### `GET /patients/:id/vitals/latest`

Most recent vital reading.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "vitals": { ... } | null }`

---

### `GET /patients/:id/vitals`

Vital readings history.

**Auth:** Bearer token + verifyPatientAccess

**Query:** `period` -- `7d` (default), `30d`, `90d`

**Response:** `{ "vitals": [...] }`

---

### `GET /patients/:id/reports/today`

Today's daily report.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "report": { ...sections parsed } | null }`

---

### `GET /patients/:id/reports`

Paginated report history.

**Auth:** Bearer token + verifyPatientAccess

**Query:** `page`, `page_size`

**Response:** `{ "reports": [...] }`

---

### `GET /patients/:id/active-services`

Active deployments formatted as service cards for My Care tab.

**Auth:** Bearer token + verifyPatientAccess

**Response:**
```json
{
  "services": [{
    "id": "deployment_id",
    "name": "string",
    "service_category": "string",
    "status": "active",
    "start_date": "...",
    "total_days": 30,
    "consumed_days": 15,
    "total_staff": 1,
    "checked_in_staff": 1,
    "latest_vital_label": "128/82",
    "latest_vital_status": "normal | warning | critical",
    "renewal_date": "...",
    "deployment_ids": ["..."]
  }]
}
```

---

### `GET /patients/:id/health-manager`

Health manager assignment for the patient.

**Auth:** Bearer token + verifyPatientAccess

**Response:**
```json
{ "id": "...", "staff_id": "...", "name": "...", "phone": "...", "photo_url": "...", "available_from": "08:00", "available_to": "20:00" }
```

**Errors:** `404` -- No health manager assigned

---

## Deployments

### `GET /deployments/:id/service-detail`

Comprehensive service detail for the My Care service detail screen.

**Auth:** Bearer token

**Response:**
```json
{
  "service": { ...active service shape },
  "staff_on_duty": [{ "id": "...", "name": "...", "role": "...", "check_in_time": "...", "rating": 4.8, "is_replacement": false }],
  "attendance_days": [{ "date": "...", "status": "checked_in", "staff_name": "..." }],
  "vitals_summary": {
    "bp": { "label": "128/82", "status": "normal", "sparkline": [120, 125, 128] },
    "spo2": { "label": "97%", "status": "normal", "sparkline": [...] },
    "pulse": { ... },
    "temperature": { ... }
  },
  "today_report": { "total_tasks": 8, "completed_tasks": 5, "tasks": [...], "staff_notes": "..." },
  "equipment": [{ "name": "...", "monthly_rate": 0, "start_date": "...", "status": "active" }]
}
```

---

### `GET /deployments/:id/attendance`

Paginated attendance for a specific deployment.

**Auth:** Bearer token

**Query:** `page` (default 1), `page_size` (default 30)

**Response:** `{ "records": [...], "total": 90 }`

---

## Staff

### `GET /staff/:id/profile`

Public staff profile (limited -- no salary, address, Aadhaar, PAN).

**Auth:** Bearer token

**Response:**
```json
{
  "staff": {
    "id": "...", "name": "...", "photo_url": "...", "role": "...",
    "rating": 4.8, "total_reviews": 12,
    "id_verified": true, "training_complete": true, "police_verified": true,
    "languages": ["Hindi", "English"], "experience": "3 years",
    "documents": [{ "type": "...", "label": "...", "status": "verified", "document_url": null }],
    "reviews": [{ "id": "...", "patient_name": "...", "rating": 5, "comment": "...", "date": "..." }]
  }
}
```

---

## Reports

### `GET /reports/:id`

Single report detail.

**Auth:** Bearer token

**Response:** `{ "report": { ...with parsed JSON sections, photo_urls, medications } }`

**Errors:** `404` -- Report not found

---

## Services

### `GET /services`

Active service catalog. Prices are hidden (null) for manpower services where `hide_price = true`.

**Auth:** Bearer token

**Response:** `{ "services": [...] }`

---

### `GET /services/:id`

Single service detail.

**Auth:** Bearer token

**Response:** `{ "service": { ... } }`

**Errors:** `404` -- Service not found

---

## Bookings

### `POST /bookings`

Create a new service booking.

**Auth:** Bearer token + requirePrimary

**Input:**
```json
{
  "patient_id": "uuid (required)",
  "service_id": "uuid (required)",
  "scheduled_date": "YYYY-MM-DD (required)",
  "scheduled_slot": "string (required)",
  "promo_code": "string (optional)"
}
```

**Response:** `201` -- `{ "booking": { ... } }`

**Pricing logic:** base_price_min - discount + 18% GST = total_amount (all in paise)

**Errors:**
- `400` -- Missing required fields
- `403` -- Not PRIMARY_CONTACT / wrong patient
- `404` -- Service not found

---

### `GET /patients/:patientId/bookings`

Paginated booking history.

**Auth:** Bearer token + verifyPatientAccess

**Query:** `page`, `page_size`, `status` (optional filter)

**Response:** `{ "bookings": [...], "total": 12, "page": 1, "page_size": 20 }`

---

### `PUT /bookings/:id/cancel`

Cancel a booking. Refund policy depends on time before scheduled date.

**Auth:** Bearer token + verifyPatientAccess

**Input:**
```json
{
  "reason": "string (optional)"
}
```

**Response:** `{ "success": true, "booking": { ...updated booking with status "cancelled" } }`

**Refund rules:**
- More than 24hr before scheduled date: full refund
- Less than 24hr before scheduled date: 50% refund

**Errors:**
- `400` -- Booking already cancelled or completed
- `403` -- Access denied
- `404` -- Booking not found

---

### `POST /bookings/:id/rate`

Submit a rating for a completed booking.

**Auth:** Bearer token + verifyPatientAccess

**Input:**
```json
{
  "rating": "1-5 (required)",
  "comment": "string (optional)"
}
```

**Response:** `{ "success": true, "id": "uuid" }`

**Errors:**
- `400` -- Invalid rating (must be 1-5), or booking not completed
- `403` -- Access denied
- `404` -- Booking not found
- `409` -- Already rated

---

## Assessments

### `POST /assessments`

Create an assessment request (for caretaker, nursing, japa, nanny, ICU services).

**Auth:** Bearer token + requirePrimary

**Input:**
```json
{
  "patient_id": "uuid (required)",
  "service_category": "string (required)",
  "questionnaire_responses": { ... }
}
```

**Response:** `201` -- `{ "assessment": { ... } }`

**Errors:** `400` -- Missing fields, `403` -- Access denied

---

### `GET /patients/:patientId/assessments`

List all assessment requests for a patient.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "assessments": [...] }`

---

## Billing

### `GET /patients/:patientId/billing`

Quick billing overview.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "amount_due": 2450000, "due_date": "2026-04-01" }`

---

### `GET /patients/:patientId/billing/summary`

Full billing summary.

**Auth:** Bearer token + verifyPatientAccess

**Response:**
```json
{
  "total_outstanding": 2450000,
  "total_paid": 5000000,
  "overdue_amount": 0,
  "next_due_date": "2026-04-01",
  "next_due_amount": 2450000,
  "recent_invoices": [{ ... }]
}
```

---

### `GET /patients/:patientId/invoices`

Paginated invoice list.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "invoices": [...] }`

---

### `GET /invoices/:id`

Single invoice detail.

**Auth:** Bearer token

**Response:** `{ "invoice": { ...with parsed line_items } }`

**Errors:** `404` -- Invoice not found

---

### `GET /patients/:patientId/transactions`

Payment transaction history.

**Auth:** Bearer token + verifyPatientAccess

**Query:** `status` (optional filter), `limit` (default 20)

**Response:** Array of payment objects

---

### `GET /transactions/:id`

Single transaction detail.

**Auth:** Bearer token

**Response:** Payment object

**Errors:** `404` -- Transaction not found

---

## Payments

### `POST /payments/create-order`

Create a Razorpay payment order.

**Auth:** Bearer token + requirePrimary

**Input:**
```json
{
  "patient_id": "uuid (required)",
  "amount": "number in paise (required)",
  "payment_type": "commission | salary | booking | equipment | emi_installment (required)",
  "reference_type": "string (optional)",
  "reference_id": "string (optional)"
}
```

**Response:** `201`
```json
{
  "payment_id": "uuid",
  "razorpay_order_id": "order_...",
  "amount": 250000,
  "currency": "INR"
}
```

**Errors:** `400` -- Missing fields, `403` -- Access denied

---

### `POST /payments/verify`

Verify Razorpay payment after client-side checkout.

**Auth:** Bearer token

**Input:**
```json
{
  "razorpay_payment_id": "string (required)",
  "razorpay_order_id": "string (required)",
  "razorpay_signature": "string (required)"
}
```

**Response:** `{ "success": true, "payment_id": "uuid", "status": "captured" }`

**Errors:**
- `400` -- Missing fields or invalid signature
- `404` -- Payment record not found

**Side effects:** Updates linked booking payment_status to "paid" if reference_type = "booking"

---

### `POST /payments/webhook`

Razorpay webhook handler. No auth middleware -- uses signature verification.

**Auth:** `x-razorpay-signature` header (HMAC SHA256)

**Events handled:**

| Event               | Action                                           |
|---------------------|--------------------------------------------------|
| `payment.captured`  | Update payment status, update linked booking     |
| `payment.failed`    | Update payment status to "failed"                |
| `refund.processed`  | Update payment status to "refunded", set refund_amount |

**Response:** `{ "status": "ok" }`

---

## Concerns

### `POST /concerns`

Raise a family concern.

**Auth:** Bearer token + requirePrimary

**Input:**
```json
{
  "patient_id": "uuid (required)",
  "category": "string (required)",
  "description": "string (required)",
  "urgency": "low | medium | high | emergency (required)",
  "preferred_resolution": "string",
  "evidence_urls": ["string"]
}
```

**Response:** `201` -- `{ "concern": { ... } }`

---

### `GET /patients/:patientId/concerns`

List concerns for a patient.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "concerns": [...] }`

---

## Ratings

### `POST /ratings`

Submit daily care rating.

**Auth:** Bearer token + requirePrimary

**Input:**
```json
{
  "patient_id": "uuid (required)",
  "deployment_id": "uuid (required)",
  "rating": "1-5 (required)",
  "comment": "string"
}
```

**Response:** `201` -- `{ "success": true, "id": "uuid" }`

**Errors:** `400` -- Invalid rating, `409` -- Already rated today

---

## Notifications

### `GET /notifications`

Paginated notification list for authenticated user.

**Auth:** Bearer token

**Query:** `page`, `page_size`

**Response:** `{ "notifications": [...], "total": 50, "page": 1, "page_size": 20 }`

---

### `PUT /notifications/:id/read`

Mark single notification as read.

**Auth:** Bearer token

**Response:** `{ "success": true }`

---

### `PUT /notifications/read-all`

Mark all unread notifications as read.

**Auth:** Bearer token

**Response:** `{ "success": true }`

---

## Equipment

### `GET /equipment`

Paginated equipment catalog.

**Auth:** Bearer token

**Query:** `category`, `type`, `search`, `page`, `page_size`

**Response:** `{ "items": [...], "total": 25, "page": 1, "page_size": 20 }`

---

## Family Members

### `GET /patients/:patientId/family`

List family members for a patient.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "family_members": [...] }`

---

### `POST /patients/:patientId/family`

Add a new family member.

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Input:**
```json
{
  "name": "string (required)",
  "phone": "string (required)",
  "relationship": "string (required)",
  "email": "string",
  "role": "FAMILY_MEMBER (default)",
  "preferred_language": "en | hi"
}
```

**Response:** `201` -- Family member object

---

### `POST /patients/:patientId/family/invite`

Send an invite to a phone number (stub -- records intention).

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Input:** `{ "phone": "string (required)" }`

**Response:** `{ "success": true }`

---

### `PUT /patients/:patientId/family/:memberId`

Update a family member's profile.

**Auth:** Bearer token + verifyPatientAccess

**Allowed fields:** name, phone, email, relationship, preferred_language, notification_preferences (JSON)

**Response:** Updated family member object

---

### `POST /patients/:patientId/family/:memberId/remove`

Remove a family member. Cannot remove PRIMARY_CONTACT.

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Response:** `{ "success": true }`

**Errors:** `400` -- Cannot remove primary contact, `404` -- Not found

---

### `PUT /family/:memberId/remove` (Legacy)

Legacy endpoint for removing family members.

**Auth:** Bearer token

---

## Medications

### `GET /patients/:patientId/medications`

List active medications.

**Auth:** Bearer token + verifyPatientAccess

**Response:** `{ "medications": [...] }`

---

### `POST /patients/:patientId/medications`

Add a medication.

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Input:**
```json
{
  "name": "string (required)",
  "dosage": "string",
  "frequency": "string",
  "schedule_times": ["08:00", "21:00"],
  "instructions": "string",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "stock_count": 30,
  "low_stock_threshold": 5
}
```

**Response:** `201` -- Medication object

---

### `PUT /patients/:patientId/medications/:id`

Update a medication.

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Response:** Updated medication object

---

### `DELETE /patients/:patientId/medications/:id`

Soft-delete a medication (sets is_active = false).

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Response:** `{ "success": true }`

---

### `GET /patients/:patientId/medication-logs`

Medication administration logs.

**Auth:** Bearer token + verifyPatientAccess

**Query:** `date` (YYYY-MM-DD, defaults to today)

**Response:** `{ "logs": [...] }`

---

### `PUT /patients/:patientId/medications/:id/stock`

Update medication stock count.

**Auth:** Bearer token + verifyPatientAccess + requirePrimary

**Input:** `{ "stock_count": 25 }`

**Response:** `{ "success": true }`

---

## Coupons

### `POST /coupons/validate`

Validate a coupon code and calculate discount.

**Auth:** Bearer token

**Input:**
```json
{
  "code": "string (required)",
  "category": "string (required)",
  "order_amount": "number in paise (required)"
}
```

**Response:**
```json
{
  "id": "uuid", "code": "SAVE20", "discount_type": "percentage",
  "discount_value": 20, "max_discount": 50000,
  "discount_amount": 40000, "valid": true
}
```

**Errors:** `404` -- Invalid code, `400` -- Expired/category mismatch/below minimum/usage limit

---

### `GET /coupons`

List active coupons, optionally filtered by category.

**Auth:** Bearer token

**Query:** `category` (optional)

**Response:** Array of coupon objects

---

**Update rule:** Every new Cloud Function or endpoint = update this file.
