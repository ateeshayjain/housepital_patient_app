# Business Rules -- Code-Relevant

## Pricing and Commission

### Manpower Services (Caretaker, Nursing Deployment, Japa, Nanny)

**CRITICAL RULE: Never show prices for manpower services to users.** Users reject when they see prices without first speaking to a coordinator. The `hide_price` flag on `service_catalog` ensures the API returns `null` for `base_price_min` and `base_price_max`.

- Staff salary + Commission to Housepital
- Monthly plan: Rs 12,000 commission (Rs 5,000 non-refundable minimum)
- 3-Month plan: Rs 30,000 one-time (Rs 10,000 non-refundable minimum, EMI available)

### Nursing (Direct Salary Model)

- Direct salary model -- NO commission layer
- Pricing handled through assessment + quote flow

### Equipment Rental

- Monthly rental only (no sale model currently -- `available_for_sale` exists in schema but not used)
- 30% discount for 3-month plan customers
- Rental prices stored in paise in `equipment_catalog.rental_price`

### Instant/Scheduled Services

- Lab Tests: Per-test pricing from service_catalog
- Nursing/Physio Visits: Per-visit pricing from service_catalog
- GST rate: 18% (hardcoded as `GST_RATE = 0.18` in bookings.ts)
- All amounts stored in **paise** (Rs 100 = 10000 paise)

### Booking Types

| Type        | Flow                                    | Price Display | Examples                               |
|-------------|----------------------------------------|---------------|----------------------------------------|
| `instant`   | Select slot -> Pay -> Confirmed        | Shown         | Nursing visit, Physio, Lab test        |
| `scheduled` | Select date -> Pay -> Confirmed        | Shown         | Sleep therapy                          |
| `assessment`| Fill questionnaire -> Callback -> Quote| Hidden        | Caretaker, Nursing deploy, Japa, Nanny, ICU |

---

## GST Rules

- GST Rate: 18% applied on (base_amount - discount)
- Calculation: `gst_amount = Math.round(subtotal * 0.18)`
- `total_amount = subtotal + gst_amount`
- All in paise

---

## Refund Rules

### Commission Non-Refundable Conditions

Commission is non-refundable WHEN ALL THREE conditions are met:
1. Right staff deployed as per requirement
2. Replacement offered when requested
3. 7+ days of service completed

### Housepital At Fault

- Minimum retention: Rs 2,000 (monthly plan) / Rs 5,000 (3-month plan)
- Balance refunded

### Staff Salary

- ALWAYS charged regardless of cancellation reason

### Booking Cancellation

- More than 24hr before scheduled date: full refund
- Less than 24hr before scheduled date: 50% refund (needs confirmation)

---

## 3-Month Plan Benefits

- Up to 5 free staff replacements (24-48hr SLA)
- 3 free nursing supervision visits
- 3 free physiotherapy sessions
- 1 complimentary full body diagnostic test
- 50% ambulance discount (within 50km of partner locations)
- 30% equipment rental discount
- Benefits non-transferable, expire with plan, not exchangeable for cash

---

## Permission Matrix

| Action                      | PRIMARY_CONTACT | FAMILY_MEMBER | PATIENT_SELF |
|-----------------------------|:---:|:---:|:---:|
| View dashboard              | Yes | Yes | Yes |
| View vitals/reports         | Yes | Yes | Yes |
| View service catalog        | Yes | Yes | Yes |
| Book services               | Yes | No  | No  |
| Make payments               | Yes | No  | No  |
| Add/remove family members   | Yes | No  | No  |
| Edit patient profile        | Yes | No  | No  |
| Add/edit medications        | Yes | No  | No  |
| Update medication stock     | Yes | No  | No  |
| Raise concern               | Yes | Yes | Yes |
| Rate daily care             | Yes | Yes | Yes |
| Request replacement         | Yes | No  | No  |
| View documents              | Yes | Yes | Yes |
| Upload documents            | Yes | No  | No  |
| Change notification prefs   | Yes | Yes (own) | Yes (own) |
| Submit assessment request   | Yes | No  | No  |
| Apply promo codes           | Yes | No  | No  |
| Remove family member        | Yes | No  | No  |

**Enforcement:** Backend uses `requirePrimary` middleware. Frontend should disable/hide actions for non-primary users.

**Special rule:** Cannot remove a PRIMARY_CONTACT member (backend returns 400).

---

## Notification Rules

| Notification         | Can User Disable? | Channels           | Trigger                        |
|----------------------|:-----------------:|---------------------|--------------------------------|
| Late check-in        | No                | Push + In-app       | Staff not checked in by grace period |
| No-show              | No                | Push + SMS + WA     | Staff absent after threshold   |
| Vitals RED alert     | No                | Push + SMS + WA     | Any vital in RED range         |
| Payment reminder     | No                | Push + WA           | 3 days before due date         |
| Booking confirmation | No                | Push + WA           | Booking status -> confirmed    |
| Staff check-in       | Yes               | Push                | Staff checks in                |
| Daily report ready   | Yes               | Push                | Staff submits daily report     |
| Weekly summary       | Yes               | Push                | Generated weekly               |
| Promotional          | Yes (off default) | Push                | Marketing campaigns            |

### Notification Channels

| Channel    | Enum Value  | Provider     |
|------------|-------------|--------------|
| FCM Push   | `fcm`       | Firebase     |
| SMS        | `sms`       | MSG91        |
| WhatsApp   | `whatsapp`  | MSG91        |
| Email      | `email`     | (TBD)        |
| In-app     | `in_app`    | Firestore    |

---

## Vitals Alert Thresholds

Defined in `constants.dart` as `AppConstants.vitalRanges`. Units vary by vital type.

### Blood Pressure (mmHg)

| Vital       | GREEN (Normal) | YELLOW (Borderline) | RED (Alert)       |
|-------------|----------------|---------------------|-------------------|
| Systolic    | 90-130         | 130-140 or 80-90    | >140 or <80       |
| Diastolic   | 60-85          | 85-90 or 55-60      | >90 or <55        |

### Other Vitals

| Vital         | GREEN           | YELLOW            | RED               | Unit      |
|---------------|-----------------|-------------------|-------------------|-----------|
| Pulse         | 60-100          | 100-110 or 50-60  | >110 or <50       | bpm       |
| SpO2          | 95-100          | 92-95             | <92               | %         |
| Temperature   | 97.0-99.0       | 99.0-100.4        | >100.4 or <96.0   | F         |
| Blood Sugar   | 70-140          | 140-180 or 60-70  | >180 or <60       | mg/dL     |

### Backend Vital Status Calculation (deployments.ts)

The backend uses simplified thresholds for the service-detail endpoint:
- BP: normal (<= 140/90), warning (> 140/90), critical (> 180/120)
- SpO2: normal (>= 95), warning (>= 90), critical (< 90)
- Pulse: normal (60-100), warning (outside 60-100), critical (> 120 or < 50)
- Temperature: normal (<= 100), warning (> 100), critical (> 103)

---

## Concern SLA (Response Time)

Defined in `constants.dart`:

| Urgency    | Response SLA |
|------------|-------------|
| Emergency  | 2 hours     |
| High       | 12 hours    |
| Medium     | 24 hours    |
| Low        | 72 hours    |

---

## Attendance Rules

From `constants.dart`:

| Rule                    | Value      |
|-------------------------|------------|
| Grace period            | 30 minutes |
| Absent threshold        | 60 minutes |

---

## City/Service Area

Active cities (stored as lowercase ENUM in all tables):

```
delhi, faridabad, gurgaon, noida, ghaziabad
```

- City is required for patient registration
- Service availability may vary by city (check `service_catalog`)
- Validated during onboarding (backend rejects invalid cities)

---

## Service Categories

### Instant Services (no assessment required)

```
nursing_visit, physio_visit, sleep_therapy, lab_test
```

### Assessment Services (questionnaire -> callback -> quote)

```
caretaker, nursing_deployment, icu_setup, japa, nanny
```

---

## Status State Machines

### Assessment Request

```
submitted -> reviewing -> callback_scheduled -> quote_sent -> accepted -> staff_matched -> deployed
                                                          |-> declined
                                                          |-> expired
```

### Booking

```
pending -> confirmed -> assigned -> in_progress -> completed
       |                                       |-> cancelled
       |                                       |-> no_show
       |-> cancelled
```

### Family Concern

```
received -> acknowledged -> investigating -> in_progress -> resolved -> closed
                                         |-> escalated -> closed
```

### Payment

```
initiated -> processing -> completed
                        |-> failed
                        |-> refunded
                        |-> partial_refund
```

### Invoice

```
draft -> pending -> paid
                 |-> overdue -> paid
                 |-> cancelled
```

### Deployment

```
active -> paused -> active
       |-> completed
       |-> cancelled
```

---

## Coupon/Promo Code Rules

- Coupons have `valid_from` and `valid_until` date bounds
- Can be restricted to specific service categories via `applicable_categories`
- `min_order_amount` threshold in paise
- Discount types: `percentage` (with optional `max_discount` cap) or `fixed`
- Usage tracked per patient via `coupon_usage` table (one use per patient)
- Global `usage_limit` across all users
- Validation endpoint: `POST /coupons/validate`

---

## Relationships (Family Member to Patient)

Defined in `constants.dart`:

```
spouse, son, daughter, son_in_law, daughter_in_law, sibling, other
```

---

## Booking Number Format

- Bookings: `HPL-BOOK-XXXX` (4 random digits)
- Assessments: `HPL-ASR-XXXXXX` (6 random digits)

---

**Update rule:** Any business rule change from the founder = update this FIRST, then code.
