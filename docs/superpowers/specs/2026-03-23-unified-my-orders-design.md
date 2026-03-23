# Unified My Orders Screen — Design Spec

**Date:** 2026-03-23
**Status:** Approved
**Route:** `/booking-history` (replaces existing `BookingHistoryScreen`)

## Problem

The app has three order types with disconnected tracking:

1. **Service Bookings** (3-step wizard → Razorpay) — tracked in `BookingHistoryScreen`
2. **Equipment Orders** (Cart → Checkout → Razorpay) — no tracking screen
3. **Assessment Requests** (questionnaire → coordinator calls) — no tracking screen

Users have no single place to see everything they've ordered or requested.

## Solution

Replace `BookingHistoryScreen` with `MyOrdersScreen` — a two-tab screen that unifies all order types.

## Screen Structure

### Tab 1: Orders

Shows everything the user has **paid for** or that has been **accepted and activated**.

**Data sources:**
- `ApiService().getBookings(patientId)` — service bookings
- `ApiService().getEquipmentOrders(patientId)` — equipment orders (NEW endpoint)
- Assessments with status `accepted`, `staff_matched`, or `deployed` (filtered from assessments API)

**Card layout:**
```
┌─────────────────────────────────────┐
│ [Icon] Doctor Visit        BOOKING  │
│ ● Confirmed                        │
│ 24 Mar 2026 · Morning              │
│ ₹4,130                             │
│                    [Cancel] [Rate]  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ [Icon] Hospital Bed      EQUIPMENT  │
│ ● Dispatched                        │
│ Ordered 21 Mar · ETA 22 Mar        │
│ ₹2,500/month                       │
│                          [Track]    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ [Icon] Nurse (Advanced)   SERVICE   │
│ ● Active                            │
│ Started 15 Mar · 24hr shift        │
│ ₹18,000/month                      │
│                    [View in My Care] │
└─────────────────────────────────────┘
```

**Status flow for bookings:**
`pending → confirmed → assigned → in_progress → completed`
`pending → cancelled` / `confirmed → cancelled`
`in_progress → no_show`

**Status flow for equipment:**
`placed → confirmed → dispatched → delivered`
`placed → cancelled`

**Status flow for accepted assessments:**
`accepted → staff_matched → deployed`

**Cancellation rule:** Cancel button shown if `scheduledDate` is >2 hours from now. Backend rejects with user-friendly error if too late.

**Actions per status:**
| Status | Actions |
|--------|---------|
| pending/placed | Cancel |
| confirmed/assigned | Cancel (if >2hr before scheduled time) |
| dispatched | Track (placeholder) |
| in_progress/deployed | View in My Care |
| completed/delivered | Rate, Re-book |
| cancelled/no_show | Re-book |

**Re-book targets:**
- Booking → navigates to `/service-booking` with same `ServiceItem`
- Equipment → navigates to `/equipment-detail` with same `equipmentId`
- Assessment → navigates to `/assessment-request` with same `ServiceItem`

**Filters:** All, Active, Completed, Cancelled

### Loading & Error States

**Initial load:** Shimmer skeleton cards (3 placeholders) shown per tab while API calls resolve. Both tabs' data fetched in parallel on screen init.

**Partial failure:** If one API call fails (e.g., `getEquipmentOrders` errors but `getBookings` succeeds), show available data with an inline error banner: "Some orders couldn't be loaded. Pull down to retry."

**Pull-to-refresh:** Both tabs support pull-to-refresh via `RefreshIndicator`.

### Tab 2: Assessment Requests

Shows **pending** assessment requests that haven't been accepted yet.

**Data source:**
- `ApiService().getAssessments(patientId)` — filtered to only show: `submitted`, `in_review`, `callback_scheduled`, `quote_sent` (i.e., NOT `accepted`/`staff_matched`/`deployed`/`declined`/`expired`)

**Card layout:**
```
┌─────────────────────────────────────┐
│ [Icon] Nurse (Basic) – 12hr        │
│ ● Submitted                         │
│ 22 Mar 2026                         │
│ Coordinator will call within 2 hrs  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ [Icon] Post-Surgery Package         │
│ ● Quote Sent                        │
│ 20 Mar 2026                         │
│ Quoted: ₹45,000/month              │
│          [Accept & Pay] [Decline]   │
└─────────────────────────────────────┘
```

**Status flow for assessments:**
`submitted → in_review → callback_scheduled → quote_sent → accepted` (moves to Orders tab)
`submitted → declined` / `quote_sent → expired`

**Actions per status:**
| Status | Actions |
|--------|---------|
| submitted | — (waiting, show "Coordinator will call within 2 hrs") |
| in_review | — (waiting, show "Being reviewed by our care team") |
| callback_scheduled | — (waiting, show "Callback scheduled") |
| quote_sent | Accept & Pay, Decline |
| declined/expired | Re-request |

**Quote display:** The quoted amount is read from `assessment.quote['commission_monthly']` (in paise). Display as `₹{amount/100}/month`.

### Empty States

**Orders tab empty:** "No orders yet. Book a service or add equipment to your cart to get started." + [Book a Service] button

**Assessment Requests tab empty:** "No pending requests. Request an assessment for nursing, caretaker, or other manpower services." + [Request Assessment] button

## Navigation Entry Points

| From | Link | Target |
|------|------|--------|
| Home dashboard | "My Orders" card | `/booking-history` |
| Booking confirmation | "View My Orders" button | `/booking-history` (Orders tab) |
| Assessment submission | "Track in My Orders" button | `/booking-history` (Assessment Requests tab, index 1) |
| More/Settings menu | "My Orders" list tile | `/booking-history` |
| Cart checkout success | "View My Orders" button | `/booking-history` (Orders tab) |

## Data Models

### Existing (no changes)
- `Booking` — from `models.dart`, used for service bookings
- `AssessmentRequest` — from `models.dart`, used for assessment requests

### New
```dart
class EquipmentOrder {
  final String id;
  final String equipmentName;
  final String? equipmentBrand;
  final String orderType; // 'purchase' or 'rental'
  final int? rentalMonths;
  final int amount; // paise — consistent with all other monetary fields
  final String status; // placed, confirmed, dispatched, delivered, cancelled
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String? trackingInfo;

  // fromJson, toJson
}
```

### Unified Order Item (for merged list rendering)
```dart
class OrderItem {
  final String id;
  final String name;
  final String type; // 'booking', 'equipment', 'assessment'
  final String status;
  final DateTime date;
  final int? amount; // paise
  final Map<String, dynamic> metadata; // type-specific fields (see below)

  // Factory constructors:
  // OrderItem.fromBooking(Booking b)
  // OrderItem.fromEquipmentOrder(EquipmentOrder o)
  // OrderItem.fromAssessment(AssessmentRequest a)
}

// Expected metadata keys per type:
// 'booking':   { scheduled_date, scheduled_slot, doctor_type, concern, service_id }
// 'equipment': { order_type, rental_months, tracking_info, delivery_date, equipment_id }
// 'assessment':{ service_category, shift_type, care_needs, quote }

```

## API Changes

### New endpoint needed
- `GET /patients/:patientId/equipment-orders` — returns `{ equipment_orders: [...] }`

### Method signature for ApiService:
```dart
Future<List<EquipmentOrder>> getEquipmentOrders(String patientId) async {
  final data = await _get('/patients/$patientId/equipment-orders');
  return (data['equipment_orders'] as List)
      .map((o) => EquipmentOrder.fromJson(o))
      .toList();
}
```

### Existing endpoints used
- `GET /patients/:patientId/bookings` — already exists
- `GET /patients/:patientId/assessments` — already exists

### New actions needed
- `PUT /assessments/:id/accept` — accept a quote (triggers payment flow)
- `PUT /assessments/:id/decline` — decline a quote

## Files to Create/Modify

### Create
- `lib/screens/services/my_orders_screen.dart` — replaces `booking_history_screen.dart`
- `lib/models/equipment_order.dart` — new model (or add to `models.dart`)

### Modify
- `lib/main.dart` — update route `/booking-history` to use `MyOrdersScreen`
- `lib/services/api_service.dart` — add `getEquipmentOrders()`, `acceptAssessment()`, `declineAssessment()`
- `lib/screens/services/booking_confirmation_screen.dart` — "View My Orders" button text
- `lib/screens/services/assessment_request_screen.dart` — after submit, navigate to My Orders (Assessment tab)
- `lib/screens/home/home_screen.dart` — add "My Orders" card
- `lib/screens/settings/settings_screen.dart` — add "My Orders" tile in More tab
- `lib/screens/cart/cart_screen.dart` — after checkout success, navigate to My Orders

### Delete
- `lib/screens/services/booking_history_screen.dart` — replaced by `my_orders_screen.dart`

## Backend Changes

### New route: `equipment-orders.ts`
- `GET /patients/:patientId/equipment-orders` — query `equipment_orders` table
- `POST /equipment-orders` — create order after cart checkout

### New route additions: `assessments.ts`
- `PUT /assessments/:id/accept` — set status to `accepted`, trigger payment
- `PUT /assessments/:id/decline` — set status to `declined`

### New MySQL table: `equipment_orders`
```sql
CREATE TABLE equipment_orders (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  patient_id CHAR(36) NOT NULL,
  equipment_id CHAR(36) NOT NULL,
  equipment_name VARCHAR(255) NOT NULL,
  equipment_brand VARCHAR(100),
  order_type ENUM('purchase', 'rental') NOT NULL,
  rental_months INT,
  quantity INT DEFAULT 1,
  amount INT NOT NULL, -- paise
  status ENUM('placed','confirmed','dispatched','delivered','cancelled') DEFAULT 'placed',
  order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  delivery_date DATE,
  tracking_info TEXT,
  payment_id VARCHAR(100),
  address_id CHAR(36),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  INDEX idx_equipment_orders_patient (patient_id),
  INDEX idx_equipment_orders_status (status)
);
```

## Testing

### Unit tests
- `OrderItem.fromBooking()` correctly maps all fields
- `OrderItem.fromEquipmentOrder()` correctly maps all fields
- `OrderItem.fromAssessment()` correctly maps all fields
- Assessment with status `accepted` filtered to Orders tab, not Assessments tab
- Filter logic for each tab

### Widget tests
- Two tabs render correctly
- Empty states show for each tab
- Status badge colors match status
- "Accept & Pay" only shows on `quote_sent` assessments
- "Cancel" only shows on cancellable statuses
