# Housepital Database Schema

## Table Index

| #  | Table                | Owner        | Read By          | Write By         |
|----|----------------------|-------------|------------------|------------------|
| 1  | patients             | Patient App | Patient App      | Admin, Family    |
| 2  | family_members       | Patient App | Patient App      | Admin, Family    |
| 3  | fcm_tokens           | System      | System           | System           |
| 4  | staff                | Staff App   | Both Apps        | Admin            |
| 5  | service_catalog      | Admin       | Patient App      | Admin            |
| 6  | equipment_catalog    | Admin       | Patient App      | Admin            |
| 7  | deployments          | Admin       | Both Apps        | Admin            |
| 8  | attendance           | Staff App   | Both Apps        | Staff            |
| 9  | vitals               | Staff App   | Both Apps        | Staff            |
| 10 | daily_reports        | Staff App   | Both Apps        | Staff            |
| 11 | bookings             | Patient App | Patient App      | Family, System   |
| 12 | assessment_requests  | Patient App | Patient App      | Family, Admin    |
| 13 | payments             | System      | Patient App      | System           |
| 14 | invoices             | System      | Patient App      | System           |
| 15 | family_concerns      | Patient App | Both Apps        | Family           |
| 16 | daily_ratings        | Patient App | Both Apps        | Family           |
| 17 | notification_log     | System      | Both Apps        | System           |
| 18 | medications          | Patient App | Patient App      | Family (PRIMARY) |
| 19 | medication_logs      | Staff App   | Patient App      | Staff            |
| 20 | coupons              | Admin       | Patient App      | Admin            |
| 21 | coupon_usage         | System      | System           | System           |

---

## Full Schema (MySQL -- Cloud SQL asia-south1)

### 1. `patients`

Primary patient records.

| Column                        | Type          | Constraints                          |
|-------------------------------|---------------|--------------------------------------|
| id                            | VARCHAR(36)   | PRIMARY KEY                          |
| name                          | VARCHAR(255)  | NOT NULL                             |
| age                           | INT           |                                      |
| gender                        | ENUM          | 'male', 'female', 'other'           |
| conditions                    | JSON          | DEFAULT '[]'                         |
| medications                   | JSON          | DEFAULT '[]'                         |
| allergies                     | JSON          | DEFAULT '[]'                         |
| dietary_restrictions          | TEXT          |                                      |
| mobility_status               | ENUM          | 'ambulatory', 'needs_support', 'wheelchair', 'bedridden' |
| doctor_name                   | VARCHAR(255)  |                                      |
| doctor_phone                  | VARCHAR(20)   |                                      |
| doctor_hospital               | VARCHAR(255)  |                                      |
| emergency_contacts            | JSON          | DEFAULT '[]'                         |
| address                       | TEXT          |                                      |
| city                          | ENUM          | 'delhi', 'faridabad', 'gurgaon', 'noida', 'ghaziabad' -- NOT NULL |
| height                        | VARCHAR(20)   |                                      |
| weight                        | VARCHAR(20)   |                                      |
| diagnosis                     | TEXT          |                                      |
| iv_central_line               | VARCHAR(100)  |                                      |
| feeding_type                  | VARCHAR(100)  |                                      |
| mental_condition              | VARCHAR(100)  |                                      |
| motion_status                 | VARCHAR(100)  |                                      |
| bp_sugar_insulin              | TEXT          |                                      |
| discharge_summary_available   | BOOLEAN       | DEFAULT FALSE                        |
| requirement                   | TEXT          |                                      |
| created_at                    | DATETIME      | DEFAULT CURRENT_TIMESTAMP            |
| updated_at                    | DATETIME      | DEFAULT CURRENT_TIMESTAMP ON UPDATE  |

**Indexes:** `idx_city (city)`

---

### 2. `family_members`

Links Firebase Auth users to patients. Defines access roles.

| Column                    | Type          | Constraints                         |
|---------------------------|---------------|-------------------------------------|
| id                        | VARCHAR(36)   | PRIMARY KEY                         |
| user_id                   | VARCHAR(128)  | NOT NULL, UNIQUE -- Firebase Auth UID|
| patient_id                | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE|
| name                      | VARCHAR(255)  | NOT NULL                            |
| phone                     | VARCHAR(20)   | NOT NULL                            |
| email                     | VARCHAR(255)  |                                     |
| relationship              | VARCHAR(30)   | NOT NULL                            |
| role                      | ENUM          | 'PRIMARY_CONTACT', 'FAMILY_MEMBER', 'PATIENT_SELF' DEFAULT 'FAMILY_MEMBER' |
| preferred_language         | ENUM          | 'en', 'hi' DEFAULT 'en'            |
| notification_preferences   | JSON          | DEFAULT '{}'                        |
| created_at                | DATETIME      | DEFAULT CURRENT_TIMESTAMP           |

**Indexes:** `idx_user_id (user_id)`, `idx_patient_id (patient_id)`, `idx_role (role)`
**Foreign Keys:** `patient_id -> patients(id) ON DELETE CASCADE`

---

### 3. `fcm_tokens`

Push notification device tokens.

| Column       | Type          | Constraints                |
|-------------|---------------|----------------------------|
| id          | VARCHAR(36)   | PRIMARY KEY                |
| user_id     | VARCHAR(128)  | NOT NULL -- Firebase UID   |
| token       | TEXT          | NOT NULL                   |
| device_type | VARCHAR(20)   | DEFAULT 'unknown'          |
| created_at  | DATETIME      | DEFAULT CURRENT_TIMESTAMP  |
| updated_at  | DATETIME      | AUTO-UPDATE                |

**Indexes:** `idx_user_id (user_id)`

---

### 4. `staff`

Staff profiles (read-only from patient app).

| Column            | Type          | Constraints               |
|-------------------|---------------|---------------------------|
| id                | VARCHAR(36)   | PRIMARY KEY               |
| name              | VARCHAR(255)  | NOT NULL                  |
| phone             | VARCHAR(20)   |                           |
| role              | VARCHAR(50)   | NOT NULL                  |
| photo_url         | TEXT          |                           |
| rating            | DECIMAL(3,2)  | DEFAULT 0.00              |
| total_reviews     | INT           | DEFAULT 0                 |
| id_verified       | BOOLEAN       | DEFAULT FALSE             |
| training_complete | BOOLEAN       | DEFAULT FALSE             |
| police_verified   | BOOLEAN       | DEFAULT FALSE             |
| languages         | JSON          | DEFAULT '[]'              |
| experience        | VARCHAR(100)  |                           |
| created_at        | DATETIME      | DEFAULT CURRENT_TIMESTAMP |

**Indexes:** `idx_role (role)`

---

### 5. `service_catalog`

Available services for booking.

| Column              | Type          | Constraints                                       |
|---------------------|---------------|----------------------------------------------------|
| id                  | VARCHAR(36)   | PRIMARY KEY                                        |
| name                | VARCHAR(255)  | NOT NULL                                           |
| name_hi             | VARCHAR(255)  |                                                    |
| category            | VARCHAR(50)   | NOT NULL                                           |
| booking_type        | ENUM          | 'instant', 'scheduled', 'assessment' -- NOT NULL   |
| description         | TEXT          |                                                    |
| description_hi      | TEXT          |                                                    |
| base_price_min      | INT           | In paise. NULL = no price yet -> quote-pending      |
| base_price_max      | INT           | In paise                                           |
| duration_minutes    | INT           |                                                    |
| preparation_notes   | TEXT          |                                                    |
| preparation_notes_hi| TEXT          |                                                    |
| lead_time_hours     | INT           | DEFAULT 24                                         |
| is_active           | BOOLEAN       | DEFAULT TRUE                                       |
| hide_price          | BOOLEAN       | DEAD COLUMN -- ignored by the client since 2026-06 |
| icon_name           | VARCHAR(50)   |                                                    |
| display_order       | INT           | DEFAULT 0                                          |
| created_at          | DATETIME      | DEFAULT CURRENT_TIMESTAMP                          |

**Indexes:** `idx_category (category)`, `idx_active (is_active)`, `idx_booking_type (booking_type)`

**Business rule (current):** manpower prices **ARE shown and directly bookable** — caretaker, nurse and physio all carry rate-card prices and go through the normal cart/payment path. `hide_price` is a dead column: the client ignores it entirely and decides quote-pending purely from whether a price exists (`price == null || price == 0`). The pre-2026-06 rule that this table used to describe (hide prices for manpower) was reversed by the owner on 2026-06-11 and must not be reintroduced.

---

### 6. `equipment_catalog`

Medical equipment available for rent/sale.

| Column              | Type          | Constraints                              |
|---------------------|---------------|------------------------------------------|
| id                  | VARCHAR(100)  | PRIMARY KEY                              |
| name                | VARCHAR(255)  | NOT NULL                                 |
| brand               | VARCHAR(255)  | DEFAULT ''                               |
| category            | ENUM          | 'Equipment', 'Consumable' DEFAULT 'Equipment' |
| available_for_sale  | BOOLEAN       | DEFAULT FALSE                            |
| available_for_rent  | BOOLEAN       | DEFAULT FALSE                            |
| price               | INT           | Sale price in paise                      |
| rental_price        | INT           | Monthly rental in paise                  |
| status              | ENUM          | 'Active', 'Inactive' DEFAULT 'Active'   |
| image_url           | TEXT          |                                          |
| description         | TEXT          |                                          |
| how_to_use          | TEXT          |                                          |
| key_features        | TEXT          |                                          |
| ideal_for           | TEXT          |                                          |
| youtube_url         | TEXT          |                                          |
| faqs                | TEXT          |                                          |
| parent_product_id   | VARCHAR(100)  |                                          |
| variant_type        | VARCHAR(100)  |                                          |
| variant_value       | VARCHAR(100)  |                                          |
| created_at          | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_category (category)`, `idx_status (status)`

**UI note (2026-03-24):** The frontend displays equipment in Sale/Rental tabs (based on `available_for_sale` and `available_for_rent` flags) rather than by the Equipment/Consumable category enum. The DB category column is still used for filtering but the primary tab organization is Sale vs Rental.

---

### 7. `deployments`

Active staff-to-patient assignments.

| Column            | Type          | Constraints                                       |
|-------------------|---------------|----------------------------------------------------|
| id                | VARCHAR(36)   | PRIMARY KEY                                        |
| patient_id        | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE               |
| staff_id          | VARCHAR(36)   | FK -> staff(id) SET NULL                           |
| booking_id        | VARCHAR(36)   |                                                    |
| shift_type        | ENUM          | '12hr_day', '12hr_night', '24hr' DEFAULT '24hr'   |
| start_date        | DATE          | NOT NULL                                           |
| end_date          | DATE          |                                                    |
| total_days        | INT           |                                                    |
| status            | ENUM          | 'active', 'paused', 'completed', 'cancelled' DEFAULT 'active' |
| auto_renew        | BOOLEAN       | DEFAULT FALSE                                      |
| billing_cycle     | ENUM          | 'monthly', 'quarterly' DEFAULT 'monthly'           |
| next_billing_date | DATE          |                                                    |
| created_at        | DATETIME      | DEFAULT CURRENT_TIMESTAMP                          |

**Indexes:** `idx_patient (patient_id)`, `idx_status (status)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`, `staff_id -> staff(id) SET NULL`

---

### 8. `attendance`

Daily check-in/check-out records.

| Column            | Type          | Constraints                              |
|-------------------|---------------|------------------------------------------|
| id                | VARCHAR(36)   | PRIMARY KEY                              |
| deployment_id     | VARCHAR(36)   | NOT NULL, FK -> deployments(id) CASCADE  |
| staff_id          | VARCHAR(36)   |                                          |
| date              | DATE          | NOT NULL                                 |
| status            | ENUM          | 'checked_in', 'waiting', 'late', 'absent', 'on_leave', 'checked_out' DEFAULT 'waiting' |
| check_in_time     | DATETIME      |                                          |
| check_out_time    | DATETIME      |                                          |
| check_in_selfie   | TEXT          |                                          |
| replacement_name  | VARCHAR(255)  |                                          |
| created_at        | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `uk_deployment_date (deployment_id, date) UNIQUE`, `idx_date (date)`
**Foreign Keys:** `deployment_id -> deployments(id) CASCADE`

---

### 9. `vitals`

Patient vital sign readings.

| Column       | Type          | Constraints                              |
|-------------|---------------|------------------------------------------|
| id          | VARCHAR(36)   | PRIMARY KEY                              |
| patient_id  | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| staff_id    | VARCHAR(36)   |                                          |
| staff_name  | VARCHAR(255)  |                                          |
| recorded_at | DATETIME      | NOT NULL                                 |
| systolic    | DECIMAL(5,1)  |                                          |
| diastolic   | DECIMAL(5,1)  |                                          |
| pulse       | DECIMAL(5,1)  |                                          |
| spo2        | DECIMAL(5,1)  |                                          |
| temperature | DECIMAL(5,2)  |                                          |
| sugar       | DECIMAL(5,1)  |                                          |
| sugar_type  | ENUM          | 'fasting', 'post_meal', 'random'         |
| notes       | TEXT          |                                          |
| created_at  | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_patient (patient_id)`, `idx_recorded (recorded_at)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`

---

### 10. `daily_reports`

Staff-submitted daily care reports.

| Column          | Type          | Constraints                              |
|-----------------|---------------|------------------------------------------|
| id              | VARCHAR(36)   | PRIMARY KEY                              |
| deployment_id   | VARCHAR(36)   | NOT NULL, FK -> deployments(id) CASCADE  |
| staff_id        | VARCHAR(36)   |                                          |
| staff_name      | VARCHAR(255)  |                                          |
| patient_id      | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| date            | DATE          | NOT NULL                                 |
| submitted_at    | DATETIME      |                                          |
| sections        | JSON          | Array of ReportSection objects            |
| staff_notes     | TEXT          |                                          |
| photo_urls      | JSON          | DEFAULT '[]'                             |
| medications     | JSON          | Array of MedicationEntry objects          |
| completed_tasks | INT           | DEFAULT 0                                |
| total_tasks     | INT           | DEFAULT 0                                |
| created_at      | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `uk_deployment_date (deployment_id, date) UNIQUE`, `idx_patient (patient_id)`, `idx_date (date)`
**Foreign Keys:** `deployment_id -> deployments(id) CASCADE`, `patient_id -> patients(id) CASCADE`

---

### 11. `bookings`

Service bookings (instant/scheduled).

| Column               | Type          | Constraints                              |
|----------------------|---------------|------------------------------------------|
| id                   | VARCHAR(36)   | PRIMARY KEY                              |
| booking_number       | VARCHAR(20)   | UNIQUE, NOT NULL (format: HPL-BOOK-XXXX) |
| patient_id           | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| booked_by            | VARCHAR(36)   | NOT NULL, FK -> family_members(id) CASCADE|
| service_id           | VARCHAR(36)   | NOT NULL                                 |
| service_name         | VARCHAR(255)  |                                          |
| booking_type         | ENUM          | 'instant', 'scheduled', 'assessment' NOT NULL |
| status               | ENUM          | 'pending', 'confirmed', 'assigned', 'in_progress', 'completed', 'cancelled', 'no_show' DEFAULT 'pending' |
| scheduled_date       | DATE          |                                          |
| scheduled_slot       | VARCHAR(20)   |                                          |
| assigned_staff_id    | VARCHAR(36)   |                                          |
| assigned_staff_name  | VARCHAR(255)  |                                          |
| assigned_staff_photo | TEXT          |                                          |
| address              | TEXT          |                                          |
| price_amount         | INT           | NOT NULL, in paise                       |
| gst_amount           | INT           | NOT NULL, in paise                       |
| total_amount         | INT           | NOT NULL, in paise                       |
| promo_code           | VARCHAR(30)   |                                          |
| discount_amount      | INT           | DEFAULT 0                                |
| payment_status       | ENUM          | 'pending', 'paid', 'refunded', 'partial_refund' DEFAULT 'pending' |
| payment_id           | VARCHAR(100)  |                                          |
| cancellation_reason  | TEXT          |                                          |
| cancelled_at         | DATETIME      |                                          |
| completed_at         | DATETIME      |                                          |
| notes                | TEXT          |                                          |
| rating               | INT           | CHECK (1-5)                              |
| rating_comment       | TEXT          |                                          |
| created_at           | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |
| updated_at           | DATETIME      | AUTO-UPDATE                              |

**Indexes:** `idx_patient (patient_id)`, `idx_status (status)`, `idx_date (scheduled_date)`, `idx_payment (payment_status)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`, `booked_by -> family_members(id) CASCADE`

---

### 12. `assessment_requests`

Assessment-based service requests (caretaker, nursing deployment, japa, nanny, ICU).

| Column                    | Type          | Constraints                              |
|---------------------------|---------------|------------------------------------------|
| id                        | VARCHAR(36)   | PRIMARY KEY                              |
| request_number            | VARCHAR(20)   | UNIQUE, NOT NULL (format: HPL-ASR-XXXXXX)|
| patient_id                | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| requested_by              | VARCHAR(36)   | NOT NULL, FK -> family_members(id) CASCADE|
| service_category          | VARCHAR(50)   | NOT NULL                                 |
| status                    | ENUM          | 'submitted', 'reviewing', 'callback_scheduled', 'quote_sent', 'accepted', 'staff_matched', 'deployed', 'declined', 'expired' DEFAULT 'submitted' |
| questionnaire_responses   | JSON          | NOT NULL                                 |
| assigned_coordinator      | VARCHAR(255)  |                                          |
| callback_scheduled_at     | DATETIME      |                                          |
| callback_notes            | TEXT          |                                          |
| quote                     | JSON          | Pricing quote with plan options          |
| quote_sent_at             | DATETIME      |                                          |
| quote_expires_at          | DATETIME      |                                          |
| selected_plan             | VARCHAR(50)   |                                          |
| accepted_at               | DATETIME      |                                          |
| declined_at               | DATETIME      |                                          |
| decline_reason            | TEXT          |                                          |
| deployment_id             | VARCHAR(36)   |                                          |
| payment_id                | VARCHAR(100)  |                                          |
| created_at                | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |
| updated_at                | DATETIME      | AUTO-UPDATE                              |

**Indexes:** `idx_patient (patient_id)`, `idx_status (status)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`, `requested_by -> family_members(id) CASCADE`

---

### 13. `payments`

All payment transactions (Razorpay).

| Column               | Type          | Constraints                              |
|----------------------|---------------|------------------------------------------|
| id                   | VARCHAR(36)   | PRIMARY KEY                              |
| payment_number       | VARCHAR(20)   | UNIQUE, NOT NULL                         |
| patient_id           | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| paid_by              | VARCHAR(36)   | family_members.id                        |
| payment_type         | ENUM          | 'commission', 'salary', 'booking', 'equipment', 'emi_installment' NOT NULL |
| reference_type       | VARCHAR(30)   | 'booking', 'assessment_request', 'deployment', 'equipment' |
| reference_id         | VARCHAR(36)   |                                          |
| amount               | INT           | NOT NULL, in paise                       |
| gst_amount           | INT           | DEFAULT 0                                |
| total_amount         | INT           | NOT NULL                                 |
| currency             | CHAR(3)       | DEFAULT 'INR'                            |
| razorpay_payment_id  | VARCHAR(100)  |                                          |
| razorpay_order_id    | VARCHAR(100)  |                                          |
| razorpay_signature   | TEXT          |                                          |
| status               | ENUM          | 'initiated', 'processing', 'completed', 'failed', 'refunded', 'partial_refund' DEFAULT 'initiated' |
| payment_method       | VARCHAR(20)   |                                          |
| failure_reason       | TEXT          |                                          |
| refund_amount        | INT           | DEFAULT 0                                |
| refund_id            | VARCHAR(100)  |                                          |
| receipt_url          | TEXT          |                                          |
| description          | TEXT          |                                          |
| created_at           | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |
| completed_at         | DATETIME      |                                          |

**Indexes:** `idx_patient (patient_id)`, `idx_status (status)`, `idx_razorpay (razorpay_payment_id)`, `idx_order (razorpay_order_id)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`

---

### 14. `invoices`

Billing invoices.

| Column               | Type          | Constraints                              |
|----------------------|---------------|------------------------------------------|
| id                   | VARCHAR(36)   | PRIMARY KEY                              |
| invoice_number       | VARCHAR(30)   | UNIQUE, NOT NULL                         |
| patient_id           | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| billing_period_start | DATE          | NOT NULL                                 |
| billing_period_end   | DATE          | NOT NULL                                 |
| line_items           | JSON          | NOT NULL                                 |
| subtotal             | INT           | NOT NULL, in paise                       |
| gst_total            | INT           | NOT NULL                                 |
| grand_total          | INT           | NOT NULL                                 |
| due_date             | DATE          | NOT NULL                                 |
| status               | ENUM          | 'draft', 'pending', 'paid', 'overdue', 'cancelled' DEFAULT 'pending' |
| pdf_url              | TEXT          |                                          |
| sent_via             | JSON          | DEFAULT '[]'                             |
| created_at           | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_patient (patient_id)`, `idx_due (due_date)`, `idx_status (status)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`

---

### 15. `family_concerns`

Issues raised by family members.

| Column                    | Type          | Constraints                              |
|---------------------------|---------------|------------------------------------------|
| id                        | VARCHAR(36)   | PRIMARY KEY                              |
| patient_id                | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| raised_by                 | VARCHAR(36)   | NOT NULL, FK -> family_members(id) CASCADE|
| deployment_id             | VARCHAR(36)   |                                          |
| category                  | VARCHAR(50)   | NOT NULL                                 |
| description               | TEXT          | NOT NULL                                 |
| evidence_urls             | JSON          | DEFAULT '[]'                             |
| urgency                   | ENUM          | 'low', 'medium', 'high', 'emergency' DEFAULT 'medium' |
| preferred_resolution      | TEXT          |                                          |
| status                    | ENUM          | 'received', 'acknowledged', 'investigating', 'in_progress', 'resolved', 'escalated', 'closed' DEFAULT 'received' |
| assigned_to               | VARCHAR(255)  |                                          |
| resolution_notes          | TEXT          |                                          |
| resolution_satisfaction   | INT           | CHECK (1-5)                              |
| created_at                | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |
| resolved_at               | DATETIME      |                                          |

**Indexes:** `idx_patient (patient_id)`, `idx_status (status)`, `idx_urgency (urgency)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`, `raised_by -> family_members(id) CASCADE`

---

### 16. `daily_ratings`

Daily care quality ratings from family.

| Column          | Type          | Constraints                              |
|-----------------|---------------|------------------------------------------|
| id              | VARCHAR(36)   | PRIMARY KEY                              |
| patient_id      | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| deployment_id   | VARCHAR(36)   | NOT NULL, FK -> deployments(id) CASCADE  |
| rated_by        | VARCHAR(36)   | NOT NULL, FK -> family_members(id) CASCADE|
| date            | DATE          | NOT NULL                                 |
| rating          | INT           | NOT NULL, CHECK (1-5)                    |
| comment         | TEXT          |                                          |
| created_at      | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `uk_deployment_rater_date (deployment_id, rated_by, date) UNIQUE`, `idx_patient (patient_id)`, `idx_deployment (deployment_id)`
**Foreign Keys:** All three FK -> CASCADE

---

### 17. `notification_log`

All notifications sent to users.

| Column      | Type          | Constraints                              |
|-------------|---------------|------------------------------------------|
| id          | VARCHAR(36)   | PRIMARY KEY                              |
| user_id     | VARCHAR(128)  | NOT NULL -- Firebase UID                 |
| type        | VARCHAR(50)   | NOT NULL                                 |
| title       | VARCHAR(255)  | NOT NULL                                 |
| body        | TEXT          | NOT NULL                                 |
| data        | JSON          |                                          |
| channel     | ENUM          | 'fcm', 'sms', 'whatsapp', 'email', 'in_app' NOT NULL |
| status      | ENUM          | 'sent', 'delivered', 'read', 'failed' DEFAULT 'sent' |
| created_at  | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_user (user_id)`, `idx_type (type)`, `idx_status (status)`

---

### 18. `medications`

Patient medication tracker.

| Column                | Type          | Constraints                              |
|-----------------------|---------------|------------------------------------------|
| id                    | VARCHAR(36)   | PRIMARY KEY                              |
| patient_id            | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| name                  | VARCHAR(255)  | NOT NULL                                 |
| dosage                | VARCHAR(100)  |                                          |
| form                  | ENUM          | 'tablet', 'capsule', 'injection', 'syrup', 'inhaler', 'drops', 'cream', 'other' DEFAULT 'tablet' |
| frequency             | ENUM          | 'once_daily' .. 'as_needed' DEFAULT 'once_daily' |
| time_slots            | JSON          | e.g. '["08:00", "14:00", "21:00"]'       |
| instructions          | TEXT          |                                          |
| prescribed_by         | VARCHAR(255)  |                                          |
| prescribed_date       | DATE          |                                          |
| end_date              | DATE          |                                          |
| stock_count           | INT           | DEFAULT 0                                |
| stock_unit            | VARCHAR(20)   | DEFAULT 'tablets'                        |
| prescription_photo_url| TEXT          |                                          |
| is_active             | BOOLEAN       | DEFAULT TRUE                             |
| created_at            | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_patient (patient_id)`, `idx_active (is_active)`
**Foreign Keys:** `patient_id -> patients(id) CASCADE`

---

### 19. `medication_logs`

Medication administration records.

| Column          | Type          | Constraints                              |
|-----------------|---------------|------------------------------------------|
| id              | VARCHAR(36)   | PRIMARY KEY                              |
| medication_id   | VARCHAR(36)   | NOT NULL, FK -> medications(id) CASCADE  |
| staff_id        | VARCHAR(36)   |                                          |
| staff_name      | VARCHAR(255)  |                                          |
| scheduled_time  | DATETIME      | NOT NULL                                 |
| actual_time     | DATETIME      |                                          |
| status          | ENUM          | 'administered', 'skipped', 'missed' DEFAULT 'administered' |
| skip_reason     | TEXT          |                                          |
| notes           | TEXT          |                                          |
| created_at      | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_medication (medication_id)`, `idx_scheduled (scheduled_time)`
**Foreign Keys:** `medication_id -> medications(id) CASCADE`

---

### 20. `coupons`

Promotional discount codes.

| Column                | Type          | Constraints                              |
|-----------------------|---------------|------------------------------------------|
| id                    | VARCHAR(36)   | PRIMARY KEY                              |
| code                  | VARCHAR(30)   | UNIQUE, NOT NULL                         |
| description           | TEXT          |                                          |
| discount_type         | ENUM          | 'percentage', 'fixed' NOT NULL           |
| discount_value        | INT           | NOT NULL (% 1-100 or paise amount)       |
| min_order_amount      | INT           | DEFAULT 0                                |
| max_discount          | INT           | Max in paise (for percentage type)       |
| applicable_categories | JSON          | e.g. '["nursing_visit", "lab_test"]'     |
| valid_from            | DATE          |                                          |
| valid_until           | DATE          |                                          |
| usage_limit           | INT           | DEFAULT 1                                |
| used_count            | INT           | DEFAULT 0                                |
| is_active             | BOOLEAN       | DEFAULT TRUE                             |
| created_at            | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Indexes:** `idx_code (code)`, `idx_active (is_active)`

---

### 21. `coupon_usage`

Prevents coupon reuse per patient.

| Column      | Type          | Constraints                              |
|-------------|---------------|------------------------------------------|
| id          | VARCHAR(36)   | PRIMARY KEY                              |
| coupon_id   | VARCHAR(36)   | NOT NULL, FK -> coupons(id) CASCADE      |
| patient_id  | VARCHAR(36)   | NOT NULL, FK -> patients(id) CASCADE     |
| booking_id  | VARCHAR(36)   |                                          |
| used_at     | DATETIME      | DEFAULT CURRENT_TIMESTAMP                |

**Unique Key:** `uk_coupon_patient (coupon_id, patient_id)`

---

## Firestore Collections

### `user_patients/{userId}/patients/{patientId}`

Maps Firebase Auth UIDs to patient records for security rule lookups.

| Field      | Type      | Notes                     |
|------------|-----------|---------------------------|
| role       | string    | PRIMARY_CONTACT, etc.     |
| created_at | timestamp |                           |

**Read:** Authenticated user where `userId == auth.uid`
**Write:** Cloud Functions only

### `active_sessions/{patientId}`

Real-time attendance/session status for live dashboard updates.

**Read:** Authenticated user with matching `user_patients` entry
**Write:** Cloud Functions only

### `vitals_live/{patientId}`

Real-time vital signs stream.

**Read:** Authenticated user with matching `user_patients` entry
**Write:** Cloud Functions only

### `chat_messages/{patientId}/messages/{messageId}`

Coordinator chat messages.

**Read/Write:** Authenticated user with matching `user_patients` entry

### `notifications/{userId}/items/{notificationId}`

In-app notification feed.

**Read:** Authenticated user where `userId == auth.uid`
**Update:** Authenticated user where `userId == auth.uid` (mark as read)
**Create:** Cloud Functions only

---

## Firestore Security Rules Summary

```
- user_patients: read = own UID only, write = Cloud Functions only
- active_sessions: read = linked patient family, write = Cloud Functions only
- vitals_live: read = linked patient family, write = Cloud Functions only
- chat_messages: read/write = linked patient family
- notifications: read/update = own UID, create = Cloud Functions only
- Default: deny all
```

---

## Migration History

| #   | File                         | Date       | Description                                         |
|-----|------------------------------|------------|-----------------------------------------------------|
| 001 | 001_initial_schema.sql       | 2026-03    | All 21 tables: patients, family, staff, services,   |
|     |                              |            | bookings, payments, vitals, reports, medications,   |
|     |                              |            | concerns, ratings, notifications, coupons, equipment|

---

**Update rule:** Every migration = update this file. No exceptions.
