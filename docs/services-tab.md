# Services Tab — Developer Documentation

## Overview

The **Services** tab is the third tab in the Housepital patient app's bottom navigation. It provides the full service catalog — manpower staffing, medical equipment, doctor consultations, nursing visits, diagnostics, lab tests, and care packages. Users browse, configure, and book services through three distinct flows: instant booking, scheduled booking, and assessment request.

## Architecture

```
ServiceCatalogScreen (tab root, 7 sub-tabs via TabController)
├── ManpowerTab           — nurses, caretakers, japa, nanny, physio
├── EquipmentTab          — loads from assets/equipment_catalog.json
├── ConsultationsTab      — doctor visit, psychiatrist, grief, sleep therapy
├── VisitsTab             — IV, IM, dressing, catheter, RT, tracheostomy
├── DiagnosticsTab        — ECG, X-Ray, Holter
├── LabTestsTab           — fever/wellness/immunity/bone/metabolic panels + sample collection
└── PackagesTab           — care packages from data/care_packages.dart

Routing (based on ServiceItem.bookingType):
├── bookingType != 'assessment' → ServiceBookingScreen  (/service-booking)
├── bookingType == 'assessment' → AssessmentRequestScreen (/assessment-request)
└── Equipment items             → EquipmentDetailScreen  (/equipment-detail)
```

### Routing

All routes are registered in `lib/main.dart` via `onGenerateRoute`. Each route receives a `ServiceItem` as its argument:

| Route | Arguments | Screen |
|---|---|---|
| `/service-booking` | `ServiceItem` | `ServiceBookingScreen` |
| `/equipment-detail` | `ServiceItem` | `EquipmentDetailScreen` |
| `/assessment-request` | `ServiceItem` | `AssessmentRequestScreen` |

Navigation logic lives in `_navigateToService()` on the catalog screen:
- `service.isInstant` (i.e. `bookingType != 'assessment'`) routes to `ServiceBookingScreen`
- Otherwise routes to `AssessmentRequestScreen`
- Equipment items use a separate `_navigateToEquipmentDetail()` method

### The 3 Booking Types

| Type | `bookingType` value | Screen | Flow |
|---|---|---|---|
| Instant | `'instant'` | `ServiceBookingScreen` | Select slot, review, pay |
| Scheduled | `'scheduled'` | `ServiceBookingScreen` | Concern/config, select slot, review, pay |
| Assessment | `'assessment'` | `AssessmentRequestScreen` | Fill care needs form, attach docs, submit for coordinator callback |

## Service Catalog (`ServiceCatalogScreen`)

File: `lib/screens/services/service_catalog_screen.dart`

### Sub-Tabs (index 0-6)

| Index | Tab | Data source | Content |
|---|---|---|---|
| 0 | Manpower | `_manpowerServices` static list | Nurses, caretakers, japa, nanny, physio |
| 1 | Equipment | `assets/equipment_catalog.json` | Hospital bed, O2 concentrator, wheelchair, BP monitor, consumables |
| 2 | Consultations | `_consultationServices` | Doctor visit, psychiatrist, grief counselling, sleep therapy |
| 3 | Visits | `_visitServices` | IV, IM injection, dressing (3 levels), catheter, RT tube, tracheostomy |
| 4 | Diagnostics | `_diagnosticServices` | ECG, X-Ray, Holter monitoring |
| 5 | Lab Tests | `_labServices` | Fever/wellness/immunity/bone/metabolic/adolescent/anemia panels + sample collection |
| 6 | Packages | `_PackagesTab` widget | Care packages from `data/care_packages.dart` |

### Global Key for External Navigation

`ServiceCatalogScreen.catalogKey` is a `GlobalKey` that allows switching sub-tabs from anywhere (e.g. home screen shortcuts):

```dart
ServiceCatalogScreen.switchToSubTab(1); // jump to Equipment tab
```

### Key Service IDs

**Manpower** (rate-card prices ARE shown and directly bookable — the old "no prices shown" rule was reversed by the owner on 2026-06-11):
- `mp-nurse-basic-12`, `mp-nurse-basic-24`, `mp-nurse-adv-12`, `mp-nurse-adv-24`, `mp-nurse-crit-12`, `mp-nurse-crit-24`
- `mp-caretaker-basic-12` through `mp-caretaker-crit-24` (6 variants)
- `mp-japa-24`, `mp-nanny-12`
- `mp-physio-basic`, `mp-physio-advance`, `mp-physio-critical` (prices shown: 900/1200/1500)

**Equipment** (`bookingType: 'instant'`):
- `eq-hospital-bed`, `eq-oxygen-concentrator`, `eq-wheelchair`, `eq-bp-monitor`, `eq-consumables`

**Consultations** (`bookingType: 'scheduled'`):
- `con-doctor`, `con-psychiatrist`, `con-grief`, `th-sleep`

**Visits** (`bookingType: 'scheduled'`):
- `visit-iv`, `visit-im`, `visit-dressing-basic`, `visit-dressing-adv`, `visit-dressing-crit`, `visit-catheter`, `visit-rt-change`, `visit-tracheostomy`

**Diagnostics** (`bookingType: 'instant'`):
- `dx-ecg`, `dx-xray`, `dx-holter`

**Lab Tests** (`bookingType: 'instant'`):
- `lab-fever`, `lab-wellness`, `lab-immunity`, `lab-bone`, `lab-metabolic`, `lab-adolescent`, `lab-anemia`
- `dx-sample-5km`, `dx-sample-10km`, `dx-sample-15km` (sample collection by distance)

### Equipment Catalog Loading

The Equipment tab loads product data from `assets/equipment_catalog.json` at runtime via `rootBundle.loadString()`. Each entry is parsed into an `EquipmentItem` model. The catalog JSON provides rich detail (brand, price, rental price, breakeven days, key features, ideal-for, how-to-use, FAQs) that supplements the static `ServiceItem` definitions.

### Search

A shared `_SearchBar` widget filters services by `name`, `nameHi`, `description`, and `descriptionHi` (case-insensitive substring match).

## Booking Flow (`ServiceBookingScreen`)

File: `lib/screens/services/service_booking_screen.dart`

### 3-Step Wizard

The screen uses `_step` (0/1/2) to show one section at a time:

```
Step 0: Details     — service info, concern/config (if applicable), prescriptions
Step 1: Select Slot — date picker + time slot (Morning/Afternoon/Evening)
Step 2: Review & Pay — summary, address, promo code, payment button
```

A step indicator (`_stepDot` + `_stepLine`) shows progress at the top.

### Doctor Visit Concern Flow (`con-doctor`)

When `_isDoctorVisit` is true, the Detail step shows a concern category picker:

1. User selects a concern from `_concernCategories` (12 options)
2. Each concern maps to a doctor `type`: `'gp'` (General Physician) or `'icu'` (ICU Specialist)
3. `_recommendedDoctor` is set, influencing the recommended doctor and pricing (3500-5000)

GP concerns: fever, BP/sugar, stomach, skin, pain, elderly check-up, medication review, other.
ICU concerns: post-surgery follow-up, ventilator/tracheostomy, ICU-at-home review, critical care.

### IV Visit Infusion Type Flow (`visit-iv`)

When `_isIvVisit` is true, the Detail step shows infusion type selection:

1. User picks from 6 `_ivInfusionTypes`
2. Each type maps to a nurse `level` (`basic`/`advanced`/`critical`) and `price` (900/1200/1500)
3. Inclusions list updates dynamically based on selected nurse level
4. Additional fields: medication name, allergies, referring doctor, IV access type (`fresh`/`picc`/`port`), session count

Nurse level colors: `basic` = success (green), `advanced` = warning (amber), `critical` = error (red).

### Prescription/Notes Section

Shown for visit, consultation, and therapy services (IDs starting with `con-`, `visit-`, or `th-`). Uses shared `AttachedFilesList` and `showAttachOptionsSheet` from `document_attach_widgets.dart`.

### Address Selection

The Review step provides `_savedAddresses` (mock data: Home, Parent's Home, Office). In production, these come from the user profile. `_selectedAddressIndex` tracks the choice.

### Pricing Display Rules

- `basePriceMin` is nullable — if null the item has NO PRICE YET and renders as quote-pending. This is never decided by category: manpower carries rate-card prices.
- If `basePriceMax` differs from `basePriceMin`, a range is displayed (e.g. "3,500 - 5,000")
- **Manpower prices ARE shown** (caretaker, nurse, physio) and are directly bookable through the normal cart/payment path. Prices come from the official Delhi NCR rate card. Housepital calls back after purchase to confirm requirements and assign staff. Japa/nanny are Dai Maa, a separate business, not Housepital offerings.
- Equipment pricing is monthly (minimum 15 days = 1 month)
- Formatted via `DateHelper.formatCurrency()`

### Additional Booking Fields

- `_autoRenew` (default `true` for manpower)
- `_billingCycle` (`'monthly'` or `'quarterly'`)
- `_requestOnlineAssessment` toggle
- `_promoController` for promo codes

## Assessment Flow (`AssessmentRequestScreen`)

File: `lib/screens/services/assessment_request_screen.dart`

### Service Type Resolution

`_resolveServiceType()` maps service IDs to a `_ServiceType` enum:

| ID prefix | `_ServiceType` |
|---|---|
| `mp-nurse-` | `nurse` |
| `mp-caretaker-` | `caretaker` |
| `mp-japa-` | `japa` |
| `mp-nanny-` | `nanny` |
| `mp-physio-` | `physio` |
| `con-grief` | `griefCounselling` |
| `con-psychiatrist` | `psychiatry` |
| other | `generic` |

### Section Card Layout

All form sections use `_sectionCard()` — a reusable container with an icon, title, optional subtitle, and child widgets. Styled with `HousepitalColors.white` background, rounded corners, and a `divider` border.

### Contextual Forms

`_buildContextualForm()` dispatches to the appropriate form builder:

| Service Type | Form Builder | Key Fields |
|---|---|---|
| Nurse / Caretaker / Generic | `_buildNurseCaretakerForm()` | Condition, mobility, shift type, staff gender, care needs (3-tier chips) |
| Japa | `_buildJapaForm()` | Baby age, mother condition, feeding type, japa care needs |
| Nanny | `_buildNannyForm()` | Child age, number of children, schedule, nanny activities |
| Physio | `_buildPhysioForm()` | Condition type, affected area, issue duration, mobility level, preferred time |
| Grief Counselling | `_buildGriefCounsellingForm()` | Loss type, session format, timing, previous counselling |
| Psychiatry | `_buildPsychiatryForm()` | Primary concern, symptom duration, current medication, session format |

### Nurse Care Needs and Level Recommendation

Care needs are grouped into three tiers, displayed as `FilterChip` groups with color-coded badges:

| Level | Badge Color | Example Needs |
|---|---|---|
| Basic | Green (`success`) | Bathing, feeding, medication reminders, walking support, diaper changing, companionship |
| Advanced | Amber (`warning`) | Wound dressing, injection (IV/IM), catheter care, RT feeding, sugar & BP monitoring, oxygen support |
| Critical | Red (`error`) | Tracheostomy care, ventilator management, suctioning, bed sore care, post-ICU monitoring, central line care |

`_recommendedNurseLevel` is computed from the highest-tier need selected. If any critical need is checked, the recommendation is `'critical'`; any advanced need yields `'advanced'`; otherwise `'basic'`.

### Downgrade Warnings

`_cannotDoWarnings` lists what a lower-level nurse cannot do, shown when the user selects a service tier below the recommended level:
- A Basic nurse cannot do: IV/IM injections, catheter care, wound dressing, RT feeding, tracheostomy care, ventilator management
- An Advanced nurse cannot do: tracheostomy care, ventilator management, suctioning, central line care, post-ICU monitoring

### Auto-Population from Patient Profile

`_autoPopulateFromPatient()` pre-fills mobility and condition fields from `AppProvider.currentPatient` data (e.g. if the patient's conditions include "stroke", the condition dropdown defaults to `paralysis_stroke`).

### Online Assessment Toggle

Uses the shared `OnlineAssessmentToggle` widget from `document_attach_widgets.dart`. Subtitle text is contextual: "Get a video consultation instead of in-person visit".

### Document Attach

Shared section using `AttachedFilesList` + `showAttachOptionsSheet`. Options: saved documents, camera, gallery, file upload. The `kSavedDocuments` constant provides mock saved records.

### Submission

On submit, a coordinator callback is promised: "Our care coordinator will call you within 2 hours to discuss details and pricing."

## Equipment Detail (`EquipmentDetailScreen`)

File: `lib/screens/services/equipment_detail_screen.dart`

### Layout

Full-screen `Scaffold` with `CustomScrollView`:
- `SliverAppBar` (expandedHeight: 260) with orange gradient background and circular equipment icon
- Body sections separated by `_SectionDivider` (8px grey spacer)
- `bottomNavigationBar` with "Add to Cart" (outlined) and "Rent Now"/"Buy Now" (filled) buttons

### Sections (in order)

1. **Product Info** — name, brand, availability badges (Rent/Buy/Assessment Required), pricing
2. **Description** — collapsible text, "Read more/less" toggle at 200 characters
3. **Key Features** — checklist with green check icons
4. **Ideal For** — bullet list with check-circle icons
5. **Delivery Promise** — 3-column row: Free Delivery, 24hr Delivery, 7-day Returns
6. **Specifications** — alternating-row table (grey/white stripes)
7. **How to Use** — numbered steps with orange circle indicators
8. **FAQs** — Q&A pairs parsed from catalog text

### Catalog Data Loading

`_loadCatalogItem()` loads `assets/equipment_catalog.json` via `rootBundle`, parses it into `EquipmentItem` objects, and matches by name (exact then partial). Falls back to `_fallbackFeatures` and `_fallbackSpecs` static maps keyed by service ID.

### Pipe Delimiter Parsing

`_splitCatalogText(String text)` splits by `|` if present, otherwise by `\n`. Used for features, ideal-for, and how-to-use fields from the JSON catalog.

### FAQ Inline Parser

FAQ text uses `Q:` / `A:` (or `Q.` / `A.`) prefixes, separated by `|` or `\n`. The parser builds `_FaqEntry` objects with `question` and `answer` fields. Entries without a matching A: line are dropped.

### Pricing Display

- Buy price from `EquipmentItem.price` or `ServiceItem.basePriceMin`
- Rental price from `EquipmentItem.rentalPrice` (shown as `/mo`)
- If neither is available, shows "Contact for pricing" chip
- Breakeven calculation: "Buying saves after N days rental"

### Equipment Icon Mapping

`_equipmentIcon` maps service IDs and name keywords to Material icons (e.g. `eq-hospital-bed` -> `Icons.hotel`, `eq-oxygen-concentrator` -> `Icons.air`). Default: `Icons.inventory_2_outlined`.

## Shared Components

### `lib/widgets/document_attach_widgets.dart`

| Export | Type | Purpose |
|---|---|---|
| `kSavedDocuments` | `List<Map<String, String>>` | Mock saved medical documents (prescriptions, lab reports, imaging, discharge summary) |
| `AttachedFilesList` | Widget | Displays attached file chips with remove (X) buttons |
| `OnlineAssessmentToggle` | Widget | Blue toggle card for requesting video consultation |
| `showAttachOptionsSheet()` | Function | Bottom sheet with 4 attach options: saved docs, camera, gallery, file upload |
| `RatingStarsWidget` | Widget | Star rating display (1-5, supports half stars) |

`showAttachOptionsSheet` opens a secondary `_showSavedDocumentsPicker` sheet when "Choose from Saved Documents" is tapped. Already-attached files are shown with a green check and disabled.

### Theme Colors

All screens use `HousepitalColors` from `lib/config/theme.dart`. Key constants:

| Constant | Usage |
|---|---|
| `orange` / `orangeLight` / `orangeText` | Primary brand color, backgrounds, text |
| `success` / `successLight` | Basic nurse level, feature checks, availability badges |
| `warning` / `warningLight` | Advanced nurse level, assessment-required badge |
| `error` | Critical nurse level |
| `info` / `infoLight` | Online assessment toggle, rental badge |
| `divider` / `greyLighter` | Borders, alternating table rows |
| `background` | Section dividers, scaffold background |

## Data Models

### `ServiceItem` (`lib/models/models.dart`, line ~511)

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Unique ID (e.g. `mp-nurse-basic-12`, `eq-hospital-bed`) |
| `name` / `nameHi` | `String` / `String?` | English and Hindi names |
| `category` | `String` | `manpower`, `equipment`, `consultation`, `visit`, `diagnostics`, `lab`, `therapy` |
| `bookingType` | `String` | `'instant'`, `'scheduled'`, or `'assessment'` |
| `description` / `descriptionHi` | `String?` | English and Hindi descriptions |
| `basePriceMin` / `basePriceMax` | `int?` | Price range in INR (nullable for manpower) |
| `durationMinutes` | `int?` | Estimated service duration |
| `preparationNotes` / `preparationNotesHi` | `String?` | Patient preparation instructions |
| `leadTimeHours` | `int` | Minimum advance booking time (default: 24) |
| `isActive` | `bool` | Whether the service is bookable |
| `iconName` | `String?` | Maps to `_iconMap` for Material icon lookup |

Computed: `isInstant` returns `bookingType != 'assessment'`.

### `EquipmentItem`

Loaded from `assets/equipment_catalog.json`. Fields include: `name`, `brand`, `category`, `description`, `price`, `rentalPrice`, `breakevenDays`, `availableForRent`, `availableForSale`, `needsAssessment`, `keyFeatures`, `idealFor`, `howToUse`, `faqs`, `variantType`, `variantValue`.

## State Management

### Provider-Based

- **`AppProvider`** — holds `currentPatient` (used by `AssessmentRequestScreen` for auto-population)
- **`CartProvider`** — manages shopping cart (imported in `ServiceCatalogScreen` for equipment "Add to Cart")

### Local Screen State

Both `ServiceBookingScreen` and `AssessmentRequestScreen` use `StatefulWidget` with local state rather than separate providers. Form data (`_careNeeds`, `_step`, `_selectedIvType`, etc.) lives on the screen state and is submitted as a single payload.

## Security

### Payment Key

`PaymentService` (`lib/services/payment_service.dart`) wraps Razorpay. The test key is sourced from `AppConstants.razorpayKey` in `lib/config/constants.dart` — a single location for key management. Amount is in paise (100 = 1 INR). The `orderId` should be generated server-side via the Razorpay Orders API before calling `openCheckout()`.

### Debug Logging

All `debugPrint` calls in `PaymentService` are guarded with `kDebugMode` to prevent sensitive payment data leaking in release builds.

## File Structure

```
lib/
├── models/
│   └── models.dart                     # ServiceItem (~line 511), EquipmentItem, Booking
├── screens/services/
│   ├── service_catalog_screen.dart      # Tab root with 7 sub-tabs
│   ├── service_booking_screen.dart      # 3-step booking wizard
│   ├── assessment_request_screen.dart   # Assessment request form
│   └── equipment_detail_screen.dart     # Equipment product detail page
├── widgets/
│   └── document_attach_widgets.dart     # AttachedFilesList, OnlineAssessmentToggle, showAttachOptionsSheet
├── services/
│   └── payment_service.dart            # Razorpay integration
├── providers/
│   ├── app_provider.dart               # Current patient state
│   └── cart_provider.dart              # Shopping cart state
├── config/
│   ├── theme.dart                      # HousepitalColors
│   └── constants.dart                  # AppConstants.razorpayKey
├── data/
│   └── care_packages.dart              # Care package definitions
└── utils/
    ├── helpers.dart                     # DateHelper.formatCurrency()
    └── app_localizations.dart           # i18n support

assets/
└── equipment_catalog.json              # Rich equipment product data
```

## Business Rules

- **Manpower prices ARE shown and directly bookable** (caretaker ₹800–1,500/day, nurse ₹1,600–3,000/day, monthly packages ₹18,000–₹90,000/mo, physio 900/1200/1500). Prices were hidden Mar–Jun 2026 on a stale premise; the owner reversed that on 2026-06-11 (commit `e41224c`). Quote-pending applies ONLY to items that genuinely lack a price (`price == null || price == 0`), never to a category.
- **Equipment pricing is monthly** (minimum 15 days = 1 month), never per-day.
- **Assessment services** require a coordinator callback within 2 hours — no instant booking.
- **Doctor visit** recommends GP or ICU specialist based on patient concern category.
- **IV visit** dynamically selects nurse level and price based on infusion type.
- **Care need selection drives nurse level** — selecting any critical need upgrades recommendation to critical.
- **Bilingual support** — `nameHi`, `descriptionHi`, `preparationNotesHi` fields exist for Hindi; search includes both languages.
