# Payments & Subscriptions — Audit round 4 · Suite v2.0 · commit 9127713

**Date:** 2026-08-03 · **Auditor:** Payments & Subscriptions · **Scope:** source review (see Limitations)
**Checklist:** Payments & Subscriptions (App-Agnostic), control family PAY, Suite v2.0

## Applicability

MASTER-3.02 activates this family. The app takes real money for real-world services:
Razorpay checkout (`razorpay_flutter: ^1.3.7`, `pubspec.yaml:51`), a cart, coupons, GST
computation, invoice/receipt PDFs, an EMI screen, an auto-pay screen, and a refund path.
There is **no** `in_app_purchase` dependency and no digital-only entitlement, so the IAP
sections of the checklist apply only through Apple Guideline 3.1.5(a) (see PAY-1.01).

**No round-3 report exists for this module** (`docs/audits/round3/` contains twelve reports,
none for payments). This is the first dedicated look. The brief lists prior-round payment
fixes to re-verify cold; those are reported in the next section.

## Re-verification of prior-round payment fixes (asked for explicitly in the brief)

| Question from the brief | Answer | Evidence |
|---|---|---|
| Exactly ONE path to `openCheckout`? | **Yes.** | `openCheckout` has one non-test call site: `lib/screens/billing/payment_screen.dart:263`. `billing_screen.dart:303-317` was converted to route through `/payment` and its comment documents the removed second path. Verified by `grep -rn "openCheckout" lib`. |
| Does that path always carry a backend `order_id` with a real key? | **Yes in intent, but the order can never be obtained — see PAY-3.01.** | `payment_screen.dart:233-260` calls `createOrder` whenever `!isDemoPayments` and fails closed if it returns null. The fail-closed guard is real. But `createOrder` reads `result['order_id']` (`payment_service.dart:85`) while the backend returns `razorpay_order_id` (`payments.ts:74`), so it returns null on every success. |
| Does an unverifiable-but-charged outcome ever confirm an order or clear the cart? | **No. Holds.** | `payment_service.dart:172-184` fails closed to `PaymentFailure.unverified` when a real key is configured. `payment_screen.dart:288-296` sets `_paymentSuccess=false`, and the unverified branch's only exits are `/help-faq` and `Navigator.pop(context, false)` (`payment_screen.dart:620-635`). `cart_screen.dart:571` creates the order and clears the cart only on `result == true`. |
| Is the retry affordance suppressed on the charged-but-unverified path? | **Yes. Holds.** | `payment_screen.dart:604-635`: the `_pendingVerification` branch renders "contact us" + "Go Back" only; `Retry Payment` lives in the `else` branch (declined/notStarted) at `:638-643`. The typed `PaymentFailure` enum replaced the string match as documented. |
| `createPaymentOrder` / `verifyPayment` on the backend: exist, authenticated, signature verified server-side? | **All three yes.** | `payments.ts:22-26` (`verifyAuth` + `requirePrimary` + patient-ownership check at `:32-37`); `payments.ts:89-92` (`verifyAuth`); HMAC-SHA256 signature recomputed and compared server-side at `payments.ts:99-109`. This is genuinely correct. |

**Verdict on the round-3 pattern:** the payment *failure-handling* work is neither a surface
nor a half-wire — it is correct and it holds under cold re-reading. The defects found below
are in ground **no prior round examined**: unit handling, tax computation, invoice
integrity, refunds, auto-pay, and the client/backend field contract.

## Control results

### 1. Commercial model and policy

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-1.01 | **Warning** | Item classes exist implicitly: manpower services, diagnostics, and equipment sale/rental, discriminated by `CartItem.isService` + `brand` string (`models.dart:1439-1451`). No document classifies items by permitted payment method or territory. Apple 3.1.5(a) itself is satisfied — see "Apple Guideline 3.1.5(a)" below. | Impact: tax and store-policy decisions rest on an undocumented, string-matched inference. Mitigation: promote `gstRate` to a stored, seeded field per catalog item. Owner: OWNER-TBD. Due: pre-launch. |
| PAY-1.02 | **Fail** | No refund policy, tax-registration, or consumer-law review exists in the repo. The only refund rule is an inline comment calling itself "operational default until backend ships proper logic" (`orders_provider.dart:161-164`). The GST implementation is demonstrably wrong in the invoice path (PAY-1.03/2.01). India CGST Rules 46 tax-invoice fields are entirely absent: `grep -rni "gstin\|hsn\|sac code\|place of supply\|cgst\|sgst" lib` returns **zero hits**. | Blocks release: the app issues documents titled "INVOICE" that are not valid tax invoices and mis-state tax on GST-exempt healthcare. |
| PAY-1.03 | **Warning** | Product ids and prices are seeded (`lib/screens/services/data/catalog_seeds.dart`); tax category is inferred at runtime from `brand.toLowerCase().contains('lab'\|'diagnostic'\|'test')` (`models.dart:1441-1450`). No accounting mapping. | Impact: a service whose `brand` string is reworded silently changes its GST rate. Mitigation as PAY-1.01. Owner: OWNER-TBD. |
| PAY-1.04 | **Fail** | Two dark-pattern instances. (a) **Drip pricing**: the cart's CTA reads `Checkout (${formatCurrency(adjustedTotal)})` where `adjustedTotal = cart.subtotal - _discountAmount + cart.deliveryCharge` (`cart_screen.dart:353,445`) — GST is *not* included; GST is first added one screen later in `_totalAmount` (`payment_screen.dart:104`). (b) **False financial representation**: `_showAddUpiDialog` tells the user "UPI mandate created. Approve in your UPI app to enable auto-pay." and inserts a `SavedPaymentMethod(autoPayEnabled: true)` into local state only (`payment_methods_screen.dart:410-432`). No mandate is created and no request leaves the device. | Blocks release. (b) is the same defect audit M-15 fixed for cards (`payment_methods_screen.dart:326-328` documents that fix) left unfixed for UPI — and it is worse, because it asserts a mandate exists. |

### 2. Offer and pre-purchase disclosure

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-2.01 | **Fail** | A price breakdown with a conditional GST row exists (`payment_screen.dart:866-872`), and quote-pending items correctly never render ₹0. But the amount shown to the user is wrong by 100× on two of three entry paths (PAY-2.04), and no refund or cancellation terms are shown anywhere in the purchase funnel — the 24h/50% rule lives only in `orders_provider.dart:161-164`. | Blocks release: the user commits without seeing the cancellation terms that will govern their money, and on the invoice/billing paths without seeing the correct amount. |
| PAY-2.02 | **N/A** | Rationale: there are no subscription products, trials, or renewals. `grep -rni "subscription\|premium\|free trial" lib` returns only `StreamSubscription` identifiers and two `Icons.workspace_premium` glyphs. Recurring auto-pay is presented in the UI but is non-functional; it is graded under PAY-5.01/5.02 rather than excused here. | — |
| PAY-2.03 | **N/A** | Rationale: the app has no paywall and no premium-gated content. Every clinical, account, privacy, and support route is reachable without purchase. | — |
| PAY-2.04 | **Fail** | **The money-unit chain is inconsistent and the error is a factor of 100.** `DateHelper.formatCurrency` (`helpers.dart:51-54`) formats its argument as **rupees**; a separate `formatCurrencyPaise` (`:57-61`) exists for paise. `PaymentService.openCheckout` documents `amount` as **paise** (`payment_service.dart:94`). `PaymentScreen` declares no unit and its three callers disagree — full trace in "Currency and unit trace" below. Additionally the PDF hand-formats money as `'Rs ${amount.round()}'` with no locale separators (`invoice_pdf_service.dart:69`), which the control explicitly forbids. | Blocks release. See the dedicated trace section — this is the highest-value finding in this report. |
| PAY-2.05 | **Warning** | Purchase-flow semantics are present: `Semantics(label: 'Amount to pay: …')` (`payment_screen.dart:663`) and `'Transaction ID: …'` (`:551`). Not verified on device or at largest text; Dynamic Type is clamped at 1.4× (carried open item from round 3). | Impact: unverified at accessibility extremes. Mitigation: run the purchase matrix at 1.4× with VoiceOver. Owner: OWNER-TBD. |

### 3. Purchase execution

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-3.01 | **Fail** | Outcome handling is genuinely good — `PaymentFailure {notStarted, declined, unverified}` (`payment_service.dart:246-256`) with correct fail-closed branches. **But the real-key path cannot complete at all.** `PaymentService.createOrder` returns `result['order_id']` (`payment_service.dart:85`); `POST /payments/create-order` responds `{payment_id, razorpay_order_id, amount, currency}` (`payments.ts:72-77`). The key `order_id` is never present, so `createOrder` always returns null, so `payment_screen.dart:245-260` always takes the fail-closed branch. With a real Razorpay key **every** payment shows "We couldn't start a secure payment just now." Pending/deferred/offline outcomes are not modelled at all. | Blocks release: real payments are impossible end-to-end. It is masked because `isDemoPayments` is true in the shipped build, so `openCheckout` simulates success and never calls the backend. |
| PAY-3.02 | **Warning** | Server-side verification is real and correct: HMAC-SHA256 over `order_id\|payment_id` recomputed with the server secret and compared before any state change (`payments.ts:99-109`), behind `verifyAuth`. Client fails closed on non-verification. **Gaps:** `/payments/verify` does not check that the payment record belongs to the authenticated caller (contrast `/create-order`, which does, at `payments.ts:32-37`), and it does not validate the captured **amount** against the stored order. | Impact: the signature is a strong gate, so exploitation requires the secret; but amount is never reconciled server-side, which is what PAY-3.04 depends on. Mitigation: add patient binding and an amount equality check in `/payments/verify`. Owner: OWNER-TBD. |
| PAY-3.03 | **Warning** | `/payments/verify` and the `payment.captured` webhook are naturally idempotent (both are `update … set status='captured'` keyed on `razorpay_order_id`). `/payments/create-order` has **no** idempotency key — every tap inserts a fresh `payments` row with a new `uuidv4()` and creates a new Razorpay order (`payments.ts:43-70`). | Impact: retried checkouts leave orphan `pending` rows that pollute reconciliation. Mitigation: accept a client idempotency key or dedupe on `(patient_id, reference_id, amount, pending)`. Owner: OWNER-TBD. |
| PAY-3.04 | **Fail** | **Untrusted amounts and discounts are never validated at an authoritative layer.** The backend accepts the client's amount verbatim: `amount: z.number().positive()` (`validators.ts:17`) → `razorpay.orders.create({amount: data.amount})` (`payments.ts:43-44`). Nothing recomputes the cart. Worse, `PaymentScreen._applyCoupon` (`payment_screen.dart:169-201`) does **not** call the backend at all — it compares against a hardcoded `_mockCoupon` (`WELCOME20`, 20%, `payment_screen.dart:64-76`) after a `Future.delayed`, and the resulting `_discountAmount` reduces `_totalAmount`, which is what gets sent to `createOrder`. A server-side validator exists (`POST /coupons/validate`, `coupons.ts:11`) and the cart screen does use it (`cart_screen.dart:64`), but the payment screen bypasses it. | Blocks release: a modified client sets any price. Even unmodified, the payment screen grants a 20% discount the server never authorised, and it stacks on top of the cart's server-validated coupon because `PaymentScreen._discountAmount` starts at 0 independently of the cart's. |
| PAY-3.05 | **Fail** | The order is created **only** in the `.then()` continuation after `PaymentScreen` pops `true` (`cart_screen.dart:569-596`). If the process is killed after Razorpay captures but before that callback runs, the patient is charged and **no order exists** — locally or, because `/create-order` only ever wrote a `pending` row, as anything actionable. No launch-time reconciliation exists: `grep -rn "reconcil" lib` returns nothing, and `OrdersProvider._loadFromStorage` (`orders_provider.dart:214`) only rehydrates local JSON. | Blocks release: this is precisely the "user loses money because the app terminated" case the control names. |

### 4. Entitlements and restoration

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-4.01 | **Fail** | There is no defined source of truth. Orders are local only: `_persistAndNotify` writes `jsonEncode(_orders)` to SharedPreferences under `housepital_orders_<patientId>` (`orders_provider.dart:201-211`). Nothing reads orders back from the backend, and `billing.ts` exposes only `GET` routes that the order flow never calls. | Blocks release: the paid-service record the business must honour exists on one device, in one app's preferences. |
| PAY-4.02 | **Fail** | No restore or reconciliation path. Uninstalling the app, or switching device, destroys all order and payment history; a payment captured by Razorpay leaves the patient with no in-app evidence. `grep -rn "restore" lib` finds no purchase-restoration code. | Blocks release. |
| PAY-4.03 | **Fail** | **The money side of refunds is not real.** `cancelOrder` computes `refundAmount` (full minus ₹100 inside 24h, else 50%) and writes `refundStatus: 'pending'` and a 7-day `refundEta` into the local order map (`orders_provider.dart:165-197`). There is **no** refund API call — `grep -rn "refund" lib/services/` returns **zero hits** — and **no** backend refund endpoint: `payments.ts` exposes only `/create-order`, `/verify`, `/webhook`. The webhook can record a `refund.processed` event (`payments.ts:218-228`), but nothing in this system can ever *initiate* one, and that webhook is itself broken (PAY-5.03). | Blocks release: the app promises a specific refund amount with a 7-day ETA, and no money will move. The 24h grace window is real as a *calculation* and fictional as a *transaction*. |
| PAY-4.04 | **Warning** | Rentals carry `rentalMonths` and are priced `unitPrice * rentalMonths * quantity` (`models.dart:1423-1424`), but no rental expiry, renewal, or return lifecycle is modelled. No credits, gifts, or consumables exist. | Impact: an equipment rental has a paid duration and no end-of-term behaviour. Mitigation: model rental end date and renewal. Owner: OWNER-TBD. |
| PAY-4.05 | **Warning** | The app never handles card data (Razorpay SDK owns the sheet; the card-add flow is a phone call, `payment_methods_screen.dart:326-380`). The backend `payments` table stores only Razorpay ids, amount, and status. **Unverified:** no support/admin console exists in either repo, so I cannot confirm support can diagnose transaction state without ad-hoc DB access. | Impact: support likely resorts to direct SQL, which is untracked access. Mitigation: a read-only payment lookup for support. Owner: OWNER-TBD. |

### 5. Subscription lifecycle

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-5.01 | **Fail** | Not N/A: the app **advertises** recurring billing — "Auto-pay … automatically pay for recurring services", badged "RBI compliant" (`payment_methods_screen.dart:70-89`) — and claims to create mandates. None of it exists. `PaymentReminderService` calls `/payments/saved-methods` and `/payments/upcoming-reminders` (`payment_reminder_service.dart:82,102`); **neither endpoint exists** — `grep -rn "saved-methods\|upcoming-reminders" ../housepital-backend/functions/src/` returns zero hits — so both calls 404 into the `catch` and return `[]`. Razorpay Subscriptions is listed as a "future enhancement" in the class doc (`:70`). No lifecycle state is tested. | Blocks release: per "not tested is not N/A", an advertised recurring-billing feature with zero implementation is a Fail, not an absent product. |
| PAY-5.02 | **Fail** | There is no way to cancel auto-pay or remove a saved method. The fabricated UPI method (PAY-1.04b) renders an "Auto-pay ON" badge (`payment_methods_screen.dart:259-271`) with no delete, disable, or manage affordance anywhere in `payment_methods_screen.dart`. | Blocks release: a user shown "Auto-pay ON" has no route to turn it off — the archetypal obstruction pattern, even though no debit will actually occur. |
| PAY-5.03 | **Fail** | The webhook is authenticated in shape but **cannot succeed in practice**, for two independent reasons. (a) **Wrong secret**: the HMAC uses `getRazorpayKeySecret()` = `RAZORPAY_KEY_SECRET` (`payments.ts:165`, `config/razorpay.ts:30-32`), the API key secret. Razorpay signs webhooks with a *separate* webhook secret configured in the dashboard. (b) **Wrong bytes**: `index.ts:81` installs `express.json({limit:"1mb"})` globally, so `req.body` is already a parsed object by the time the handler runs, and the code re-serialises it — `typeof req.body === "string" ? req.body : JSON.stringify(req.body)` (`payments.ts:166-167`). Re-serialisation does not reproduce Razorpay's raw payload bytes, so the digest cannot match. Both paths end at `res.status(400) "Invalid webhook signature"`. No monitoring, no retry/lag handling, no ordering. | Blocks release: every asynchronous reconciliation — `payment.captured`, `payment.failed`, `refund.processed` — is dead. Combined with PAY-3.01 and PAY-4.03 there is no working server-side payment state machine at all. |
| PAY-5.04 | **N/A** | Rationale: no premium tier exists, so no entitlement can end and no read-only/export downgrade behaviour is reachable. Clinical data access is governed by the role layer, not by payment. | — |
| PAY-5.05 | **Warning** | Prices are compiled into the app (`catalog_seeds.dart`) and change only with a release; there is no price-change notice or consent mechanism, and no mandate-amount change flow. | Impact: latent, since no recurring billing works today. Mitigation: required before auto-pay ships. Owner: OWNER-TBD. |

### 6. Security, fraud, and privacy

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-6.01 | **Warning** | Card data never touches app code: Razorpay's SDK owns the sheet, and the card-add path is deliberately a coordinator phone call (`payment_methods_screen.dart:326-380`, documenting the M-15 fix). No payment credential is logged — `payment_service.dart` logs only `response.code` (`:222`) and generic messages. **Gap:** `_showAddUpiDialog` collects a UPI VPA into a `TextEditingController` and stores it in local widget state (`payment_methods_screen.dart:395-425`) with no backend, no encryption, and no disclosure. | Impact: a financial identifier is captured for a flow that does nothing. Mitigation: delete the UPI dialog until a real mandate flow exists (same remediation as PAY-1.04b). Owner: OWNER-TBD. |
| PAY-6.02 | **Fail** | The payment-screen coupon has no abuse controls: `_mockCoupon` is matched client-side with no per-user limit, no `used_count` increment, and no server call (`payment_screen.dart:169-201`). The `Coupon` model carries `used_count` (`payment_screen.dart:75`) and the backend enforces validity windows, category, and minimum order (`coupons.ts:29-60`) — all bypassed on this path. `WELCOME20` is described as "20% off on your first payment" and is reusable without limit. | Blocks release: unlimited 20% self-service discount, applied after the cart's server-validated discount. |
| PAY-6.03 | **Fail** | No administrative refund, grant, revocation, or adjustment path exists, authorised or otherwise. The only refund actor is the patient's own `cancelOrder` call, which self-assigns a refund amount into local storage with no approval, no dual control, and no audit trail (`orders_provider.dart:165-197`). | Blocks release (compounds PAY-4.03). |
| PAY-6.04 | **Warning** | Razorpay is correctly identified as a data-transmitting dependency in the round-2/3 security audits (`docs/audits/SECURITY_PRIVACY_AUDIT.md:175`). **Unverified:** no billing-data retention schedule, no processor list covering the `payments` table, and no export/deletion behaviour for payment records is documented in either repo; the App Store privacy disclosure cannot be checked from source. | Impact: DPDP obligations on financial records unevidenced. Mitigation: extend the data inventory to `payments`. Owner: OWNER-TBD. |

### 7. Store and release readiness

| Control | Outcome | Evidence | Impact / mitigation |
|---|---|---|---|
| PAY-7.01 | **Fail** | The build ships a placeholder Razorpay key, so `isDemoPayments` is true and no real provider configuration is exercised (`payment_service.dart:46-52`). This is by design per the brief — but it means no store/provider readiness evidence exists for the *release* configuration, and the two blocking integration defects (PAY-3.01 field mismatch, PAY-5.03 webhook) are invisible in exactly the configuration that ships. | Blocks release: the release-candidate provider path has never executed. |
| PAY-7.02 | **Fail** | With the shipped placeholder key, `openCheckout` returns a **simulated success after an 800 ms delay** with no gateway involvement (`payment_service.dart:113-122`), and the UI then renders the full "Payment Successful" screen with a fabricated transaction id `pay_<millis>` (`payment_screen.dart:269-277`). Nothing on that screen discloses that no payment occurred. No reviewer notes covering this exist in the repo. | Blocks release: an App Review reviewer — or any user of this build — is shown a successful payment and a confirmed order for money that was never taken. |
| PAY-7.03 | **Fail** | Test transactions do create value. The demo-simulated success pops `true`, which causes `cart_screen.dart:580-596` to call `ordersProvider.addOrder(...)` with `'status': 'confirmed'` (`orders_provider.dart:108`) and clear the cart. A confirmed, persisted order exists for a payment that never happened; `DemoMode` is not consulted anywhere in this path. | Blocks release: simulated and real states are not segregated at the order layer. |
| PAY-7.04 | **BLOCKED-OWNER** | Requires a signed production candidate and real Razorpay credentials. The brief forbids running `flutter build`, and I have no Razorpay dashboard access. Not tested — explicitly not N/A. | Needs: Razorpay live/test dashboard, signed build, App Store Connect. |
| PAY-7.05 | **Fail** | No payment monitoring of any kind. `grep -rn "analytics\|logEvent\|recordError\|Crashlytics" lib/services/payment_service.dart lib/screens/billing/payment_screen.dart` returns **zero hits**. Failures reach only `Log.warn`/`Log.error`. Nothing measures success rate, verification-error rate, pending duration, webhook lag, refund volume, or entitlement mismatch. | Blocks release: with PAY-3.01 in place, a 100% payment failure rate in production would produce no signal other than user complaints. |

## Currency, rounding, and paise/rupee trace (brief item — traced end to end)

`DateHelper.formatCurrency(int)` formats its argument as **rupees** (`helpers.dart:51-54`);
`formatCurrencyPaise(int)` divides by 100 first (`:57-61`). `openCheckout(amount:)` is
**paise** (`payment_service.dart:94`). `PaymentScreen.amount` declares **no unit**, and its
three callers disagree:

| Entry point | Unit passed | Proof of unit | Displayed via `formatCurrency` | Sent to Razorpay as paise |
|---|---|---|---|---|
| Cart (`cart_screen.dart:564-566`) | **Rupees** | `adjustedTotal = cart.subtotal - discount + deliveryCharge` built from `CartItem.unitPrice`, seeded as `basePriceMin: 800` for a ₹800/day caretaker (`catalog_seeds.dart:80`) | **Correct** | **100× UNDERCHARGE** |
| Invoice (`invoice_detail_screen.dart:136-141`) | **Paise** | `grandTotal: 2507500` with `gstTotal: 382500` (`invoice_detail_screen.dart:54-55`); 382500/(2507500−382500) = exactly 18%, so ₹25,075 in paise, not ₹25 lakh | **100× OVERSTATED** (also at `:146` and `:85`) | Correct |
| Billing (`billing_screen.dart:315-320`) | **Paise** | passes `totalDue * 100`, where `totalDue` is rendered as rupees at `:277` | **100× OVERSTATED** | Correct |

Concretely, with a real Razorpay key: **a ₹5,000 cart checkout charges ₹50**, while an
outstanding balance of ₹5,000 displays a "Pay ₹5,00,000" button on the payment screen
(`payment_screen.dart:437`), on the amount header (`:684`), and on the result screen (`:509`).
`PaymentScreen` cannot be correct for all three callers under any single convention.

**A second, independent defect in the same chain.** `_gstAmount` is
`computeCartGst(_cartItems, discount: _discountAmount)` and `_cartItems` reads
`CartProvider` unconditionally (`payment_screen.dart:93-102`), with **no** check on
`widget.invoiceId`. `_totalAmount = _subtotal - _discountAmount + _gstAmount`
(`payment_screen.dart:104`). So paying an **invoice** while unrelated items sit in the cart
adds *those items'* GST to the invoice amount. The doc comment at `payment_screen.dart:86-89`
asserts "When it's opened from an invoice (no cart context), we fall back to GST = 0" — no
such fallback is implemented; the sum is zero only when the cart happens to be empty. The
comment is false, which is how this survived.

Rounding itself is sound where it is applied: `computeCartGst` rounds per line
(`pricing.dart:139`) and `calculateGst`/`calculateEquipmentDiscount`/`calculateRefund` round
to 2dp via `toStringAsFixed(2)` (`pricing.dart:77,92,116`). Integer paise are never divided.
The failure is unit *convention*, not arithmetic.

## GST correctness per line item (brief item)

`computeCartGst` is **correct as written**: it prorates the cart discount by each line's share
of subtotal, so a coupon does not change any line's effective rate, and it sums
`round(discountedLine * gstRate)` per item (`pricing.dart:131-141`). `CartItem.gstRate`
returns 0.00 for manpower, 0.05 for lab/diagnostic/test, 0.18 for equipment
(`models.dart:1439-1451`). Verified: a discount changes the taxable base proportionally, not
the rate. **Pass on the checkout path.**

**But two other code paths contradict it, and one of them is the tax document.**

1. **`InvoicePdfService` applies a flat 18% to everything**: `final gst = (subtotal * 0.18).round()` (`invoice_pdf_service.dart:114`), rendered as `GST (18%)` (`:233`). A manpower-only order — GST-**exempt** under Notification 12/2017, per the app's own comment at `models.dart:1430` — receives an invoice charging 18% GST. A lab order is billed 18% instead of 5%. The PDF's grand total therefore also differs from the amount actually charged: for a manpower-only cart, checkout takes `subtotal + 0` while the receipt states `subtotal × 1.18`. **The receipt overstates what the patient paid, and mis-states tax on an exempt supply.**
2. **`calculateGst` in `pricing.dart:73-78` is a flat 18% helper** that survives alongside the per-line model. It is not called by the checkout path, but it is live API and tested (`test/utils/pricing_test.dart`).

## Invoice and receipt integrity (brief item)

- **Numbering: Fail.** The PDF has no invoice number — it prints `Order: $orderId` (`invoice_pdf_service.dart:152`) where `orderId` is `HPL-BOOK-<7-digit millis>` plus optional random salt (`orders_provider.dart:72-88`). That is neither sequential nor gap-free, which CGST Rules 46(b) requires. The only `invoiceNumber` in the codebase is a hardcoded demo string `'INV-2026-001'` (`invoice_detail_screen.dart:19`); nothing generates one.
- **Tax fields: Fail.** No GSTIN (supplier or recipient), no HSN/SAC, no CGST/SGST/IGST split, no place of supply, no taxable-value column. Verified by repo-wide grep returning zero hits.
- **Quote-pending → priced invoice: Pass, with a caveat.** `buildInvoicePdf` gates on `OrdersProvider.isQuotePending(order)` (`invoice_pdf_service.dart:107`), drops the amount column entirely, titles the document `PRO FORMA INVOICE`, and prints an explicit no-amounts note (`:131-146`, `:224-246`). A quote-pending order cannot emit prices. Caveat: `isQuotePending` is `order['quoteStatus'] == 'pending'` (`orders_provider.dart:65-66`), and `cart_screen.dart:580-584` calls `addOrder(...)` **without** the `quotePending` argument, so it defaults to false (`orders_provider.dart:102`). The guard is only as good as the flag, and the cart never sets it. Per the CLAUDE.md contract, price-less items route through the booking/Reserve flow rather than the cart, so this is currently latent — but it is a single missing argument away from a priced invoice for a quoted item. Recorded as a **Warning** under PAY-1.03's remediation.
- **Receipt built from the wrong data: Fail.** `PaymentScreen._shareReceipt` constructs the receipt order from `_cartItems` (`payment_screen.dart:115-124`), i.e. the live cart — not from what was paid. Tapping "View Receipt" after paying an **invoice** produces a receipt listing whatever is in the cart, or, if the cart is empty, a receipt totalling `Rs 0` with `status: 'paid'`.

## EMI screen: functional or decorative? (brief item)

**Decorative, and it does not reach the payment path at all.** `EmiScreen` is routed at
`main.dart:726` and pops a result map `{isEmi, emiMonths, emiAmount}`
(`emi_screen.dart:208-212`). `grep -rn "EmiScreen\|'/emi'" lib` finds **no caller other than
the route registration** — nothing pushes it and nothing consumes its result. It divides the
total by 3/6/9 with `.ceil()` (`:24`), so the schedule rows sum to *more* than the total while
the "Total" row shows the original figure (an unreconciled remainder on any non-divisible
amount). It asserts "No-cost EMI - Zero processing fee" and "Processing Fee: FREE"
(`:117`, `:194`) with no lender, no tenure agreement, and no interest disclosure. It also
inherits the unit ambiguity, formatting `totalAmount` with `formatCurrency`. It is not wired
into `PaymentService`, which has no EMI concept. Folded into PAY-5.01.

## Apple Guideline 3.1.5(a) (brief item)

**Correctly outside IAP — Pass.** Everything sold is a real-world good or service consumed
outside the app: home nursing and caretaker deployments, physiotherapy visits, diagnostic lab
collection, and medical-equipment sale/rental (`catalog_seeds.dart`). 3.1.5(a) permits — and
for physical goods and services requires — a payment method other than IAP. Razorpay is the
right choice, and there is no `in_app_purchase` dependency to create ambiguity
(`pubspec.yaml:51` is the only payment SDK).

**What would drag this into IAP territory, flagged as requested:**
1. Any digital-only entitlement gated behind payment — a "premium" tier over the Sahayak assistant, ad-free content, unlockable care plans, or paid report exports. None exists today (`grep -rni "subscription\|premium\|free trial" lib` is clean of product concepts), and it must stay that way or move to StoreKit.
2. Selling **credits or wallet value** redeemable in-app. `Coupon` and discount plumbing exist; a stored-value balance would cross the line.
3. Charging for the teleconsult/chat feature as a standalone digital service rather than as a scheduled clinical service — a defensible grey area Apple has enforced inconsistently.
4. Separately, and more urgently than any 3.1.5(a) risk: **PAY-7.02**. A build that simulates a successful payment and prints a fake transaction id is a Guideline 2.3 (accurate metadata) and 2.1 (app completeness) exposure regardless of which payment rail is used.

## Scorecard

**Pass 0 · Warning 10 · Fail 19 · N/A 3 · BLOCKED-OWNER 1**  (33 controls)

Fails: PAY-1.02, 1.04, 2.01, 2.04, 3.01, 3.04, 3.05, 4.01, 4.02, 4.03, 5.01, 5.02, 5.03, 6.02, 6.03, 7.01, 7.02, 7.03, 7.05
Warnings: PAY-1.01, 1.03, 2.05, 3.02, 3.03, 4.04, 4.05, 5.05, 6.01, 6.04
N/A: PAY-2.02, 2.03, 5.04 · BLOCKED-OWNER: PAY-7.04

Note that several sub-findings verified as **correct** (the single `openCheckout` path, the
fail-closed unverified handling, suppressed retry, server-side signature verification,
per-line GST in `computeCartGst`, pro-forma suppression, 3.1.5(a) posture) do not produce a
Pass row because each sits inside a control that fails on another requirement. The
prior-round work is genuinely sound; it is surrounded by unaudited ground that is not.

## Release blockers (every Fail)

**Tier 1 — the app cannot take money correctly.**
1. **PAY-2.04 — the 100× unit defect.** `PaymentScreen` has no declared money unit; cart passes rupees, invoice and billing pass paise. A ₹5,000 cart charges ₹50; a ₹5,000 balance displays ₹5,00,000. Fix: make `PaymentScreen.amount` paise everywhere, convert at `cart_screen.dart:565`, and use `formatCurrencyPaise` for every display in `payment_screen.dart` and `invoice_detail_screen.dart:85,146`.
2. **PAY-3.01 — client/backend field mismatch.** `payment_service.dart:85` reads `order_id`; `payments.ts:74` returns `razorpay_order_id`. Every real payment fails closed. One-line fix, but it means the integration has never run.
3. **PAY-3.04 — client-authoritative pricing.** Backend trusts the client amount (`validators.ts:17`); `PaymentScreen`'s coupon is a hardcoded 20% never sent to `/coupons/validate`. Recompute the cart server-side.
4. **PAY-5.03 — webhooks can never validate.** Wrong secret (`RAZORPAY_KEY_SECRET` instead of the dashboard webhook secret) *and* re-serialised body after global `express.json()`. All async reconciliation is dead.

**Tier 2 — the app misrepresents money to the user.**
5. **PAY-1.04b / 6.01 — the UPI dialog claims "UPI mandate created" and shows "Auto-pay ON" for a purely local object.** Delete it, exactly as M-15 did for cards.
6. **PAY-7.02 / 7.03 — the shipped demo build renders "Payment Successful" with a fabricated transaction id and persists a `confirmed` order for money never taken.** Gate the simulated path behind a visible demo affordance and stop it writing `confirmed`.
7. **PAY-4.03 / 6.03 — refunds are local-only.** `cancelOrder` promises an amount and a 7-day ETA; no refund API exists in the app or the backend.
8. **PAY-1.02 / 2.01 — invoices are not valid Indian tax invoices** (no serial number, GSTIN, HSN/SAC, CGST/SGST split, place of supply) and **`invoice_pdf_service.dart:114` charges a flat 18% GST on GST-exempt manpower**, contradicting the app's own per-line model and overstating what the patient paid.

**Tier 3 — durability and observability.**
9. **PAY-3.05** no reconciliation if the app dies mid-payment. **PAY-4.01/4.02** orders live only in one device's SharedPreferences with no restore. **PAY-7.05** zero payment monitoring — a 100% failure rate would be silent.

## Warnings requiring risk acceptance

PAY-1.01, 1.03 (tax category inferred from a mutable `brand` string — promote to a seeded
field); PAY-2.05 (purchase flow untested at 1.4× / VoiceOver); PAY-3.02 (`/payments/verify`
lacks patient binding and amount check); PAY-3.03 (no idempotency on `/create-order`);
PAY-4.04 (no rental end-of-term); PAY-4.05 (no support diagnosis tooling — unverified);
PAY-5.05 (no price-change consent); PAY-6.01 (UPI VPA captured with no backend); PAY-6.04
(billing-data retention and processor inventory undocumented). Also the latent
quote-pending-flag gap noted under Invoice integrity. All owners: **OWNER-TBD**; all due
pre-launch except PAY-4.04/5.05, which are due before auto-pay ships.

## BLOCKED-OWNER — needs access I do not have

- **PAY-7.04** — release smoke test on a signed production candidate against real Razorpay configuration. Needs App Store Connect, the Razorpay dashboard, and a signed build. The brief forbids running builds, and no credentials are available.
- Supporting the above: confirming whether a Razorpay webhook secret is configured in the dashboard at all (PAY-5.03), and whether App Store privacy disclosures cover billing data (PAY-6.04).

## Limitations of this audit

- **Source-only, per MASTER-4.04.** No release artifact, no production-like environment, no live Razorpay traffic. Every runtime claim here is derived from reading code and tracing call graphs; the 100× unit defect and the `order_id` mismatch are stated from field-name and literal-value evidence cited inline, not from an observed transaction.
- **No commands were run against the build.** Per the brief I did not run `flutter test`, `flutter build`, or `pod install`. I read test sources; I did not execute them. Cited central results (analyze clean, 1,819 tests pass) are the brief's, not mine.
- **The shipped configuration hides the integration defects.** With `isDemoPayments` true, `openCheckout` never contacts Razorpay or the backend, so PAY-3.01, 3.04, and 5.03 are unreachable in any test the suite can currently run. This is the structural reason a module with 1,819 passing tests carries nineteen Fails: the tests exercise the client's *decision logic* faithfully (`test/services/payment_service_test.dart` is a genuinely good file) and never the client/server *contract*.
- **Backend deployment state unverified.** I read `../housepital-backend/functions/src/` at its working-tree state. Whether it is deployed, at what version, and against which Razorpay account is unknown; `api.housepital.in` does not resolve.
- **No round-3 payments report exists**, so no prior-finding regression table could be produced beyond the five re-verifications the brief named explicitly.
