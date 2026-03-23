# Unified My Orders Screen — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `BookingHistoryScreen` with `MyOrdersScreen` — a two-tab screen unifying bookings, equipment orders, and assessment requests.

**Architecture:** Two-tab `TabBarView`. Tab 1 (Orders) merges three API responses into a single `OrderItem` list sorted by date. Tab 2 (Assessment Requests) shows pending assessments with Accept & Pay / Decline actions. Both tabs support pull-to-refresh and graceful partial failures.

**Tech Stack:** Flutter/Dart, Provider, Razorpay (for Accept & Pay), SharedPreferences (for address), existing ApiService pattern.

**Spec:** `docs/superpowers/specs/2026-03-23-unified-my-orders-design.md`

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `lib/models/equipment_order.dart` | `EquipmentOrder` model + `OrderItem` unified wrapper | Create |
| `lib/screens/services/my_orders_screen.dart` | Two-tab My Orders screen | Create |
| `test/models/equipment_order_test.dart` | Unit tests for models | Create |
| `test/screens/services/my_orders_test.dart` | Unit tests for filter/status logic | Create |
| `lib/services/api_service.dart` | Add 3 new methods | Modify |
| `lib/main.dart` | Update route + import | Modify |
| `lib/screens/services/assessment_request_screen.dart` | Post-submit navigation | Modify |
| `lib/screens/services/booking_confirmation_screen.dart` | Button text | Modify |
| `lib/screens/home/home_screen.dart` | Add My Orders card | Modify |
| `lib/screens/settings/settings_screen.dart` | Add My Orders tile | Modify |
| `lib/screens/services/booking_history_screen.dart` | — | Delete |
| `functions/src/routes/equipment-orders.ts` | Backend: GET + POST | Create |
| `functions/src/index.ts` | Register new route | Modify |
| `functions/src/routes/assessments.ts` | Add accept/decline | Modify |
| `sql/005_equipment_orders.sql` | New table migration | Create |

---

## Chunk 1: Data Models + Tests

### Task 1: Create EquipmentOrder model

**Files:**
- Create: `lib/models/equipment_order.dart`
- Test: `test/models/equipment_order_test.dart`

- [ ] **Step 1: Write failing tests for EquipmentOrder**

Create `test/models/equipment_order_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/equipment_order.dart';

void main() {
  group('EquipmentOrder', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'eo-001',
        'equipment_name': 'Hospital Bed',
        'equipment_brand': 'Medline',
        'order_type': 'rental',
        'rental_months': 3,
        'amount': 250000,
        'status': 'dispatched',
        'order_date': '2026-03-20T10:00:00Z',
        'delivery_date': '2026-03-21',
        'tracking_info': 'Shipped via BlueDart',
      };
      final order = EquipmentOrder.fromJson(json);
      expect(order.id, 'eo-001');
      expect(order.equipmentName, 'Hospital Bed');
      expect(order.equipmentBrand, 'Medline');
      expect(order.orderType, 'rental');
      expect(order.rentalMonths, 3);
      expect(order.amount, 250000);
      expect(order.status, 'dispatched');
      expect(order.trackingInfo, 'Shipped via BlueDart');
    });

    test('fromJson handles minimal fields', () {
      final json = {
        'id': 'eo-002',
        'equipment_name': '3 Ply Mask',
        'order_type': 'purchase',
        'amount': 5000,
        'status': 'placed',
        'order_date': '2026-03-22T10:00:00Z',
      };
      final order = EquipmentOrder.fromJson(json);
      expect(order.equipmentBrand, isNull);
      expect(order.rentalMonths, isNull);
      expect(order.deliveryDate, isNull);
      expect(order.trackingInfo, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = EquipmentOrder(
        id: 'eo-003',
        equipmentName: 'CPAP',
        orderType: 'rental',
        amount: 500000,
        status: 'confirmed',
        orderDate: DateTime.parse('2026-03-20T10:00:00Z'),
      );
      final json = original.toJson();
      final restored = EquipmentOrder.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.equipmentName, original.equipmentName);
      expect(restored.amount, original.amount);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/equipment_order_test.dart`
Expected: Compilation error — `equipment_order.dart` does not exist.

- [ ] **Step 3: Implement EquipmentOrder model**

Create `lib/models/equipment_order.dart`:

```dart
class EquipmentOrder {
  final String id;
  final String equipmentName;
  final String? equipmentBrand;
  final String orderType; // 'purchase' or 'rental'
  final int? rentalMonths;
  final int amount; // paise
  final String status; // placed, confirmed, dispatched, delivered, cancelled
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String? trackingInfo;

  EquipmentOrder({
    required this.id,
    required this.equipmentName,
    this.equipmentBrand,
    required this.orderType,
    this.rentalMonths,
    required this.amount,
    required this.status,
    required this.orderDate,
    this.deliveryDate,
    this.trackingInfo,
  });

  factory EquipmentOrder.fromJson(Map<String, dynamic> json) => EquipmentOrder(
    id: json['id'],
    equipmentName: json['equipment_name'],
    equipmentBrand: json['equipment_brand'],
    orderType: json['order_type'],
    rentalMonths: json['rental_months'],
    amount: json['amount'],
    status: json['status'] ?? 'placed',
    orderDate: DateTime.parse(json['order_date']),
    deliveryDate: json['delivery_date'] != null
        ? DateTime.parse(json['delivery_date'])
        : null,
    trackingInfo: json['tracking_info'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'equipment_name': equipmentName,
    'equipment_brand': equipmentBrand,
    'order_type': orderType,
    'rental_months': rentalMonths,
    'amount': amount,
    'status': status,
    'order_date': orderDate.toIso8601String(),
    'delivery_date': deliveryDate?.toIso8601String(),
    'tracking_info': trackingInfo,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/equipment_order_test.dart`
Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/equipment_order.dart test/models/equipment_order_test.dart
git commit -m "feat: add EquipmentOrder model with fromJson/toJson"
```

### Task 2: Create OrderItem unified wrapper

**Files:**
- Modify: `lib/models/equipment_order.dart` (add OrderItem class)
- Modify: `test/models/equipment_order_test.dart` (add OrderItem tests)

- [ ] **Step 1: Write failing tests for OrderItem**

Add to `test/models/equipment_order_test.dart`:

```dart
import 'package:housepital_patient/models/models.dart';

// ... existing tests ...

group('OrderItem', () {
  test('fromBooking maps all fields', () {
    final booking = Booking.fromJson({
      'id': 'b-001',
      'booking_number': 'HPL-BOOK-12345',
      'patient_id': 'p-001',
      'service_id': 'con-doctor',
      'service_name': 'Doctor Visit',
      'status': 'confirmed',
      'scheduled_date': '2026-03-24',
      'scheduled_slot': 'morning',
      'price_amount': 350000,
      'gst_amount': 63000,
      'total_amount': 413000,
      'created_at': '2026-03-22T10:00:00Z',
    });
    final item = OrderItem.fromBooking(booking);
    expect(item.id, 'b-001');
    expect(item.name, 'Doctor Visit');
    expect(item.type, 'booking');
    expect(item.status, 'confirmed');
    expect(item.amount, 413000);
    expect(item.metadata['scheduled_slot'], 'morning');
  });

  test('fromEquipmentOrder maps all fields', () {
    final order = EquipmentOrder(
      id: 'eo-001',
      equipmentName: 'Hospital Bed',
      equipmentBrand: 'Medline',
      orderType: 'rental',
      rentalMonths: 3,
      amount: 250000,
      status: 'dispatched',
      orderDate: DateTime.parse('2026-03-20T10:00:00Z'),
    );
    final item = OrderItem.fromEquipmentOrder(order);
    expect(item.type, 'equipment');
    expect(item.name, 'Hospital Bed');
    expect(item.metadata['order_type'], 'rental');
    expect(item.metadata['rental_months'], 3);
  });

  test('fromAssessment maps all fields', () {
    final assessment = AssessmentRequest.fromJson({
      'id': 'asr-001',
      'request_number': 'HPL-ASR-123456',
      'patient_id': 'p-001',
      'service_category': 'nursing',
      'status': 'quote_sent',
      'questionnaire_responses': {},
      'quote': {'commission_monthly': 1200000},
      'created_at': '2026-03-20T10:00:00Z',
    });
    final item = OrderItem.fromAssessment(assessment);
    expect(item.type, 'assessment');
    expect(item.status, 'quote_sent');
    expect(item.metadata['service_category'], 'nursing');
    expect(item.metadata['quote'], isNotNull);
  });

  test('isInOrdersTab returns true for accepted/staff_matched/deployed assessments', () {
    for (final status in ['accepted', 'staff_matched', 'deployed']) {
      expect(OrderItem.isOrdersTabAssessment(status), isTrue,
          reason: '$status should be in Orders tab');
    }
  });

  test('isInOrdersTab returns false for pending assessments', () {
    for (final status in ['submitted', 'in_review', 'callback_scheduled', 'quote_sent']) {
      expect(OrderItem.isOrdersTabAssessment(status), isFalse,
          reason: '$status should be in Assessment Requests tab');
    }
  });

  test('isPendingAssessment returns true for tab 2 statuses', () {
    for (final status in ['submitted', 'in_review', 'callback_scheduled', 'quote_sent']) {
      expect(OrderItem.isPendingAssessment(status), isTrue);
    }
  });

  test('isPendingAssessment returns false for terminal/accepted statuses', () {
    for (final status in ['accepted', 'declined', 'expired', 'staff_matched', 'deployed']) {
      expect(OrderItem.isPendingAssessment(status), isFalse);
    }
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/equipment_order_test.dart`
Expected: Compilation error — `OrderItem` not defined.

- [ ] **Step 3: Implement OrderItem**

Add to `lib/models/equipment_order.dart`:

```dart
import 'models.dart';

class OrderItem {
  final String id;
  final String name;
  final String type; // 'booking', 'equipment', 'assessment'
  final String status;
  final DateTime date;
  final int? amount; // paise
  final Map<String, dynamic> metadata;

  OrderItem({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.date,
    this.amount,
    this.metadata = const {},
  });

  factory OrderItem.fromBooking(Booking b) => OrderItem(
    id: b.id,
    name: b.serviceName ?? 'Service Booking',
    type: 'booking',
    status: b.status,
    date: b.createdAt,
    amount: b.totalAmount,
    metadata: {
      'scheduled_date': b.scheduledDate,
      'scheduled_slot': b.scheduledSlot,
      'service_id': b.serviceId,
      'booking_number': b.bookingNumber,
    },
  );

  factory OrderItem.fromEquipmentOrder(EquipmentOrder o) => OrderItem(
    id: o.id,
    name: o.equipmentName,
    type: 'equipment',
    status: o.status,
    date: o.orderDate,
    amount: o.amount,
    metadata: {
      'order_type': o.orderType,
      'rental_months': o.rentalMonths,
      'tracking_info': o.trackingInfo,
      'delivery_date': o.deliveryDate?.toIso8601String(),
      'equipment_brand': o.equipmentBrand,
    },
  );

  factory OrderItem.fromAssessment(AssessmentRequest a) => OrderItem(
    id: a.id,
    name: _assessmentName(a.serviceCategory),
    type: 'assessment',
    status: a.status,
    date: a.createdAt,
    amount: _extractQuoteAmount(a.quote),
    metadata: {
      'service_category': a.serviceCategory,
      'request_number': a.requestNumber,
      'quote': a.quote,
    },
  );

  static String _assessmentName(String category) {
    switch (category) {
      case 'nursing': return 'Nurse';
      case 'caretaker': return 'Caretaker';
      case 'japa': return 'Japa Maid';
      case 'nanny': return 'Nanny';
      case 'physiotherapy': return 'Physiotherapy';
      case 'grief_counselling': return 'Grief Counselling';
      case 'psychiatry': return 'Psychiatrist';
      default: return category;
    }
  }

  static int? _extractQuoteAmount(Map<String, dynamic>? quote) {
    if (quote == null) return null;
    return quote['commission_monthly'] as int?;
  }

  /// Assessments in these statuses appear in Orders tab (Tab 1)
  static bool isOrdersTabAssessment(String status) =>
      const {'accepted', 'staff_matched', 'deployed'}.contains(status);

  /// Assessments in these statuses appear in Assessment Requests tab (Tab 2)
  static bool isPendingAssessment(String status) =>
      const {'submitted', 'in_review', 'callback_scheduled', 'quote_sent'}.contains(status);
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/equipment_order_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/equipment_order.dart test/models/equipment_order_test.dart
git commit -m "feat: add OrderItem unified wrapper with tab filtering logic"
```

---

## Chunk 2: API Service + Backend

### Task 3: Add API methods

**Files:**
- Modify: `lib/services/api_service.dart`

- [ ] **Step 1: Add getEquipmentOrders, acceptAssessment, declineAssessment to ApiService**

Add these methods to `lib/services/api_service.dart`:

```dart
// --- Equipment Orders ---

Future<List<EquipmentOrder>> getEquipmentOrders(String patientId) async {
  final data = await _get('/patients/$patientId/equipment-orders');
  return (data['equipment_orders'] as List)
      .map((o) => EquipmentOrder.fromJson(o))
      .toList();
}

// --- Assessment Actions ---

Future<void> acceptAssessment(String assessmentId) async {
  await _put('/assessments/$assessmentId/accept', body: {});
}

Future<void> declineAssessment(String assessmentId) async {
  await _put('/assessments/$assessmentId/decline', body: {});
}
```

Also add `import '../models/equipment_order.dart';` at the top.

- [ ] **Step 2: Verify compilation**

Run: `flutter build web --release 2>&1 | tail -3`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat: add equipment order and assessment action API methods"
```

### Task 4: Backend — equipment orders route + assessment actions

**Files:**
- Create: `functions/src/routes/equipment-orders.ts`
- Create: `sql/005_equipment_orders.sql`
- Modify: `functions/src/routes/assessments.ts`
- Modify: `functions/src/index.ts`

- [ ] **Step 1: Create SQL migration**

Create `sql/005_equipment_orders.sql` with the table definition from the spec.

- [ ] **Step 2: Create equipment-orders route**

Create `functions/src/routes/equipment-orders.ts`:
- `GET /:patientId` — list equipment orders for patient
- `POST /` — create new equipment order (called after cart checkout)

- [ ] **Step 3: Add accept/decline to assessments route**

Add to `functions/src/routes/assessments.ts`:
- `PUT /:id/accept` — set status to `accepted`
- `PUT /:id/decline` — set status to `declined`

- [ ] **Step 4: Register route in index.ts**

Add `import equipmentOrderRoutes from './routes/equipment-orders';` and `app.use('/patients', equipmentOrderRoutes);`

- [ ] **Step 5: Verify TypeScript compiles**

Run: `cd functions && npx tsc --noEmit`
Expected: Zero errors.

- [ ] **Step 6: Commit**

```bash
git add sql/005_equipment_orders.sql functions/src/routes/equipment-orders.ts functions/src/routes/assessments.ts functions/src/index.ts
git commit -m "feat: backend equipment orders route + assessment accept/decline"
```

---

## Chunk 3: MyOrdersScreen UI

### Task 5: Create MyOrdersScreen

**Files:**
- Create: `lib/screens/services/my_orders_screen.dart`
- Delete: `lib/screens/services/booking_history_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create MyOrdersScreen**

Create `lib/screens/services/my_orders_screen.dart` with:
- `TabBar` with "Orders" and "Assessment Requests" tabs
- Orders tab: fetches bookings + equipment orders + accepted assessments, merges into `OrderItem` list, shows filter chips (All/Active/Completed/Cancelled), renders order cards with status badges and action buttons
- Assessment Requests tab: fetches pending assessments, shows status-specific cards with Accept & Pay / Decline buttons for `quote_sent`
- Shimmer loading placeholders (3 skeleton cards per tab)
- Pull-to-refresh on both tabs
- Partial failure: inline error banner with retry
- Empty states for both tabs
- Status badge colors: pending=warning, confirmed=info, in_progress/deployed=success, completed/delivered=success, cancelled=error, no_show=error, dispatched=info, submitted=warning, in_review=warning, quote_sent=orange
- Cancel: confirmation dialog + reason selection + API call
- Rate: 5-star bottom sheet + API call
- Re-book: navigates to appropriate screen based on order type
- Accept & Pay: opens Razorpay → on success calls acceptAssessment
- View in My Care: navigates to `/service-detail`

- [ ] **Step 2: Delete old BookingHistoryScreen**

```bash
rm lib/screens/services/booking_history_screen.dart
```

- [ ] **Step 3: Update main.dart route**

In `lib/main.dart`:
- Replace `import 'screens/services/booking_history_screen.dart'` with `import 'screens/services/my_orders_screen.dart'`
- In `onGenerateRoute`, change `/booking-history` case to return `MyOrdersScreen`
- Support optional `initialTab` argument: `final tab = settings.arguments as int? ?? 0;`

- [ ] **Step 4: Verify compilation**

Run: `flutter build web --release 2>&1 | tail -3`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/services/my_orders_screen.dart lib/main.dart
git rm lib/screens/services/booking_history_screen.dart
git commit -m "feat: replace BookingHistoryScreen with unified MyOrdersScreen"
```

---

## Chunk 4: Navigation Wiring + Tests

### Task 6: Wire navigation entry points

**Files:**
- Modify: `lib/screens/services/assessment_request_screen.dart`
- Modify: `lib/screens/services/booking_confirmation_screen.dart`
- Modify: `lib/screens/home/home_screen.dart`
- Modify: `lib/screens/settings/settings_screen.dart`

- [ ] **Step 1: Assessment form → My Orders (tab 1)**

In `assessment_request_screen.dart`, after submit success dialog, change navigation:

```dart
Navigator.pushReplacementNamed(context, '/booking-history', arguments: 1); // tab index 1 = Assessment Requests
```

- [ ] **Step 2: Booking confirmation → My Orders**

In `booking_confirmation_screen.dart`, change "View My Bookings" button to:

```dart
Text('View My Orders')
// ...
Navigator.pushReplacementNamed(context, '/booking-history');
```

- [ ] **Step 3: Home → My Orders card**

In `home_screen.dart`, add a "My Orders" quick-access card below "Book Services":

```dart
// My Orders card
ListTile(
  leading: Icon(Icons.receipt_long, color: HousepitalColors.orange),
  title: Text('My Orders'),
  subtitle: Text('Track bookings, equipment & assessments'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => Navigator.pushNamed(context, '/booking-history'),
)
```

- [ ] **Step 4: Settings → My Orders tile**

In `settings_screen.dart`, add "My Orders" tile:

```dart
ListTile(
  leading: Icon(Icons.receipt_long),
  title: Text(l.t('my_orders')),
  onTap: () => Navigator.pushNamed(context, '/booking-history'),
)
```

- [ ] **Step 5: Build and verify**

Run: `flutter build web --release 2>&1 | tail -3`
Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/services/assessment_request_screen.dart lib/screens/services/booking_confirmation_screen.dart lib/screens/home/home_screen.dart lib/screens/settings/settings_screen.dart
git commit -m "feat: wire My Orders navigation from home, settings, confirmation, assessment"
```

### Task 7: Write unit tests for My Orders logic

**Files:**
- Create: `test/screens/services/my_orders_test.dart`

- [ ] **Step 1: Write tests**

```dart
// Test OrderItem tab filtering
// Test status badge color mapping
// Test filter logic (All/Active/Completed/Cancelled)
// Test cancellation eligibility (>2hr rule)
// Test assessment pending vs orders tab separation
```

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass (including new + existing 870).

- [ ] **Step 3: Commit**

```bash
git add test/screens/services/my_orders_test.dart
git commit -m "test: add My Orders screen unit tests"
```

---

## Chunk 5: Final verification

### Task 8: Full build + push + PR

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Build release**

Run: `flutter build web --release`
Expected: Build succeeds.

- [ ] **Step 3: Push and create PR**

```bash
git push -u origin feat/unified-my-orders
gh pr create --title "feat: unified My Orders screen" --body "..."
```
