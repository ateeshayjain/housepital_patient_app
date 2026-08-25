import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/payment_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../utils/pricing.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

class PaymentScreen extends StatefulWidget {
  /// Amount to charge, in **whole rupees**.
  ///
  /// MONEY UNITS — the one rule this screen has to keep straight.
  /// Everything inside this screen is rupees: [amount], `_discountAmount`,
  /// `_gstAmount`, `_totalAmount`, and every `formatCurrency` call. The ONLY
  /// place paise exist is [_totalAmountPaise], handed to the gateway.
  ///
  /// It did not used to be. `_totalAmount` was rendered with
  /// `formatCurrency` (rupees) and passed unchanged to `openCheckout`, whose
  /// contract is paise — the same integer read as two different units four
  /// lines apart. A ₹5,000 cart checkout displayed ₹5,000 and charged ₹50.
  /// Billing compensated at ITS end by passing `totalDue * 100`, so the same
  /// bill displayed ₹5,00,000 and charged the right ₹5,000. Two entry points,
  /// wrong in opposite directions, each looking correct from where it was
  /// written.
  ///
  /// So: callers pass rupees. Never pre-multiply. If you add a caller and it
  /// looks a hundred times off, you have found this comment for a reason.
  final int amount;
  final String description;
  final String? invoiceId;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.description,
    this.invoiceId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  String _selectedMethod = kIsWeb ? 'web_sim' : 'upi';
  final _couponController = TextEditingController();
  bool _isApplyingCoupon = false;
  Coupon? _appliedCoupon;
  int _discountAmount = 0;
  String? _couponError;
  bool _isProcessing = false;

  // Payment result state
  bool _showResult = false;
  bool _paymentSuccess = true;

  /// True when Razorpay reported success but we could not verify it.
  ///
  /// This is NOT a failure and must never be rendered as one: the charge has
  /// probably already happened. Showing "Payment Failed" with a Retry button
  /// here invites a second debit for the same bill.
  bool _pendingVerification = false;
  String? _transactionId;
  String? _failureMessage;

  // Animation controllers
  late AnimationController _checkAnimController;
  late Animation<double> _checkScaleAnimation;
  late AnimationController _fadeAnimController;
  late Animation<double> _fadeAnimation;

  // Mock coupon for demo
  static final _mockCoupon = Coupon.fromJson({
    'id': 'c1',
    'code': 'WELCOME20',
    'type': 'percentage',
    'value': 20,
    'max_discount': 500000, // Rs 5,000 cap
    'min_order_value': 100000, // Rs 1,000 min
    'description': '20% off on your first payment',
    'valid_from': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
    'valid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    'is_active': true,
    'used_count': 0,
  });

  int get _subtotal => widget.amount;

  /// audit M-14: GST is now computed per line item, not as a flat 18% on the
  /// whole subtotal. Each [CartItem] exposes a [gstRate] getter that returns:
  ///   - 0.00 for healthcare manpower (exempt under Notification 12/2017)
  ///   - 0.05 for diagnostic lab tests
  ///   - 0.18 for durable medical equipment
  ///
  /// When this screen is opened from the cart, the live cart drives the
  /// computation. When it's opened from an invoice (no cart context), we fall
  /// back to GST = 0 — the invoice's `grandTotal` already bakes GST in, so
  /// applying it again would double-tax the patient.
  ///
  /// We prorate the discount across line items so a coupon doesn't change the
  /// effective per-line rate.
  List<CartItem> get _cartItems {
    try {
      return context.read<CartProvider>().items.toList();
    } catch (_) {
      return const <CartItem>[];
    }
  }

  int get _gstAmount =>
      computeCartGst(_cartItems, discount: _discountAmount);

  int get _totalAmount => _subtotal - _discountAmount + _gstAmount;

  /// The gateway boundary — the single conversion in this file. Razorpay and
  /// the backend's `/payments/create-order` both take paise.
  int get _totalAmountPaise => _totalAmount * 100;

  /// Generate + share the paid invoice as a PDF (field bug: 'View Receipt'
  /// only showed a toast — no receipt was produced). Builds an order from the
  /// paid cart items and hands it to InvoicePdfService.
  Future<void> _shareReceipt() async {
    final messenger = ScaffoldMessenger.of(context);
    final order = <String, dynamic>{
      'id': _transactionId ?? 'HPL-RECEIPT',
      'status': 'paid',
      'createdAt': DateTime.now().toIso8601String(),
      'items': _cartItems
          .map((c) => {
                'name': c.name,
                'quantity': c.quantity,
                'unitPrice': c.unitPrice,
                'isRental': c.isRental,
                'rentalMonths': c.rentalMonths,
                'isService': c.isService,
              })
          .toList(),
    };
    try {
      await InvoicePdfService().shareInvoice(order);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the receipt. Please retry.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initPaymentService();
    // Apple P8: celebrations stay under the 500ms ceiling — 450ms easeOutBack
    // (was 600ms elasticOut).
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _couponController.dispose();
    _checkAnimController.dispose();
    _fadeAnimController.dispose();
    _paymentService?.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    if (code == _mockCoupon.code) {
      final discount = _mockCoupon.calculateDiscount(_subtotal);
      if (discount > 0) {
        setState(() {
          _appliedCoupon = _mockCoupon;
          _discountAmount = discount;
          _isApplyingCoupon = false;
        });
      } else {
        setState(() {
          _couponError = 'Minimum order value not met';
          _isApplyingCoupon = false;
        });
      }
    } else {
      setState(() {
        _couponError = 'Invalid coupon code';
        _isApplyingCoupon = false;
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discountAmount = 0;
      _couponController.clear();
      _couponError = null;
    });
  }

  PaymentService? _paymentService;

  void _initPaymentService() {
    if (!kIsWeb) {
      _paymentService = PaymentService();
    }
  }

  Future<void> _processPayment() async {
    if (kIsWeb) {
      _processWebPayment();
      return;
    }

    setState(() => _isProcessing = true);

    // Real payments must carry a backend-created order_id, because that is
    // what makes the signature verifiable afterwards. Without it the success
    // handler can only reach the unverifiable "skipped" state. Demo builds
    // skip this: openCheckout simulates locally and no money moves.
    String? orderId;
    if (!PaymentService.isDemoPayments) {
      final patientId = context.read<AppProvider>().currentPatient?.id;
      orderId = patientId == null
          ? null
          : await _paymentService!.createOrder(
              patientId: patientId,
              amount: _totalAmountPaise,
              paymentType: widget.invoiceId != null ? 'invoice' : 'order',
              referenceType: widget.invoiceId != null ? 'invoice' : null,
              referenceId: widget.invoiceId,
            );
      if (!mounted) return;
      if (orderId == null) {
        // Fail closed: opening checkout now would take money we could never
        // verify. Better a retryable error than an unverifiable payment.
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _paymentSuccess = false;
          _transactionId = null;
          _failureMessage =
              "We couldn't start a secure payment just now. Nothing has been "
              'charged — please try again in a moment.';
        });
        HapticFeedback.heavyImpact();
        _playResultAnimations();
        return;
      }
    }

    _paymentService!.openCheckout(
      amount: _totalAmountPaise,
      description: widget.description,
      orderId: orderId,
      onSuccess: () {
        if (!mounted) return;
        final txnId =
            'pay_${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _paymentSuccess = true;
          _transactionId = txnId;
          _failureMessage = null;
        });
        HapticFeedback.mediumImpact();
        _playResultAnimations();
      },
      onFailure: (message, kind) {
        if (!mounted) return;
        // Typed, not string-matched. This branch decides whether a Retry
        // button appears; deciding it by `message.contains('under
        // verification')` meant translating that message — which the i18n
        // rule requires — would silently restore a double-debit path on a
        // paid invoice.
        final unverified = kind == PaymentFailure.unverified;
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _paymentSuccess = false;
          _pendingVerification = unverified;
          _transactionId = unverified ? _transactionId : null;
          _failureMessage = message;
        });
        HapticFeedback.heavyImpact();
        _playResultAnimations();
      },
    );
  }

  /// WCAG 2.3.3 / Apple P8: the payment-result reveal honors Reduce Motion —
  /// with the OS flag on, the result renders at its final frame immediately.
  /// (Safe to read MediaQuery here: this only runs from post-build callbacks.)
  void _playResultAnimations() {
    if (MediaQuery.of(context).disableAnimations) {
      _fadeAnimController.value = 1.0;
      _checkAnimController.value = 1.0;
    } else {
      _fadeAnimController.forward();
      _checkAnimController.forward();
    }
  }

  /// Web payment — simulated ONLY in demo builds.
  ///
  /// This used to report success unconditionally because it was gated on
  /// `kIsWeb` rather than on whether payments are simulated at all. With a
  /// real Razorpay key that meant a web user saw "payment successful" and a
  /// confirmed order without any payment being taken. The correct axis is
  /// [PaymentService.isDemoPayments]: web checkout is not wired up, so with a
  /// real key we must fail closed rather than invent a success.
  Future<void> _processWebPayment() async {
    setState(() => _isProcessing = true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (!PaymentService.isDemoPayments) {
      setState(() {
        _isProcessing = false;
        _showResult = true;
        _paymentSuccess = false;
        _transactionId = null;
        _failureMessage =
            'Online payment is not available in the web app yet — please pay '
            'from the Housepital mobile app, or call us and we will take it '
            'over the phone.';
      });
      HapticFeedback.heavyImpact();
      _playResultAnimations();
      return;
    }

    final txnId = 'web_pay_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _isProcessing = false;
      _showResult = true;
      _paymentSuccess = true;
      _transactionId = txnId;
      _failureMessage = null;
    });
    _playResultAnimations();
  }

  void _retryPayment() {
    setState(() {
      _showResult = false;
      _paymentSuccess = true;
      _pendingVerification = false;
      _transactionId = null;
      _failureMessage = null;
    });
    _checkAnimController.reset();
    _fadeAnimController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_showResult) {
      return _buildResultScreen(l);
    }

    return Scaffold(
      appBar: GlassAppBar(
        // Purchase funnel — cart icon would loop into itself.
        showCart: false,
        title: Text(l.t('payment')),
      ),
      body: _isProcessing
          ? const LoadingWidget(message: 'Processing payment...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount display
                  _buildAmountHeader(l),
                  const SizedBox(height: 24),

                  // Payment methods
                  SectionHeader(title: l.t('payment_method')),
                  const SizedBox(height: 8),
                  if (kIsWeb) ...[
                    _buildMethodOption('web_sim', l.t('payment_simulation'),
                        Icons.computer, l),
                  ] else ...[
                    _buildMethodOption('upi', 'UPI', Icons.account_balance, l),
                    _buildMethodOption(
                        'card', l.t('credit_debit_card'), Icons.credit_card, l),
                    _buildMethodOption(
                        'netbanking', l.t('net_banking'), Icons.language, l),
                    _buildMethodOption('wallet', l.t('wallet'),
                        Icons.account_balance_wallet, l),
                  ],
                  const SizedBox(height: 24),

                  // Coupon code
                  SectionHeader(title: l.t('coupon_code')),
                  const SizedBox(height: 8),
                  _buildCouponInput(l),
                  const SizedBox(height: 24),

                  // Price breakdown
                  SectionHeader(title: l.t('price_breakdown')),
                  const SizedBox(height: 8),
                  _buildPriceBreakdown(l),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: _isProcessing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _processPayment,
                    child: Text(
                      '${l.t('pay')} ${DateHelper.formatCurrency(_totalAmount)}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildResultScreen(AppLocalizations l) {
    final isSuccess = _paymentSuccess;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated icon
                ScaleTransition(
                  scale: _checkScaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? context.hc.successLight
                          : context.hc.errorLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.check_circle
                          : _pendingVerification
                              ? Icons.schedule
                              : Icons.cancel,
                      color: isSuccess
                          ? context.hc.success
                          : _pendingVerification
                              ? context.hc.warning
                              : context.hc.error,
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  isSuccess
                      ? l.t('payment_successful')
                      : _pendingVerification
                          ? l.t('payment_pending_verification_title')
                          : l.t('payment_failed'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isSuccess
                        ? context.hc.success
                        : _pendingVerification
                            // 24pt w700 is "large text", so the 3:1 floor
                            // applies: warning measures 3.79:1 on the light
                            // surface and far more on true black.
                            ? context.hc.warning
                            : context.hc.error,
                  ),
                ),
                const SizedBox(height: 12),

                // Amount
                Text(
                  DateHelper.formatCurrency(_totalAmount),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: context.hc.black,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.hc.greyLight,
                  ),
                ),
                const SizedBox(height: 24),

                // Transaction ID or failure message
                if (isSuccess && _transactionId != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.hc.greyLighter,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l.t('transaction_id'),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.hc.greyLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Semantics(
                          label: 'Transaction ID: $_transactionId',
                          child: SelectableText(
                            _transactionId!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.hc.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isSuccess && _failureMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.hc.errorLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _failureMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.hc.error,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Action buttons
                if (isSuccess) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _shareReceipt,
                            child: Text(l.t('view_receipt')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l.t('done')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_pendingVerification) ...[
                  // Deliberately NO retry: paying again would debit twice for
                  // the same bill. The only useful action is to reach a human.
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      // '/support' does not exist; help-faq carries the real
                      // contact numbers.
                      onPressed: () =>
                          Navigator.pushNamed(context, '/help-faq'),
                      child: Text(l.t('payment_pending_contact_us')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Go Back'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _retryPayment,
                      child: const Text('Retry Payment'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Go Back'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountHeader(AppLocalizations l) {
    return Semantics(
      label: 'Amount to pay: ${DateHelper.formatCurrency(_totalAmount)}, ${widget.description}',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [HousepitalColors.orange, context.hc.orangeDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              l.t('amount_to_pay'),
              style: TextStyle(
                fontSize: 14,
                // MEASURED: Colors.white70 over this orange gradient is
                // 1.82:1 — the worst text contrast in the app, on the label
                // for the single most consequential number in it.
                //
                // onOrange (pure white) is 2.33:1. Still below AA, and still
                // the owner's explicit, documented decision for text on an
                // orange FILL. The point of this change is that a dimmed
                // white was never that decision: it silently degraded an
                // already-accepted risk by a further 22%, on the amount
                // someone is about to be charged.
                color: context.hc.onOrange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateHelper.formatCurrency(_totalAmount),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                // Same gradient, same reason as the label above.
                fontSize: 13,
                color: context.hc.onOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodOption(
      String value, String label, IconData icon, AppLocalizations l) {
    final isSelected = _selectedMethod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: '$label payment method${isSelected ? ', selected' : ''}',
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _selectedMethod = value),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.hc.orangeLight
                    : context.hc.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? HousepitalColors.orange
                      : context.hc.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? HousepitalColors.orange
                        : context.hc.grey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? context.hc.orangeText
                            : context.hc.black,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: HousepitalColors.orange, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCouponInput(AppLocalizations l) {
    if (_appliedCoupon != null) {
      return Semantics(
        label: 'Coupon ${_appliedCoupon!.code} applied, you save ${DateHelper.formatCurrency(_discountAmount)}',
        child: HousepitalCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.hc.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_offer,
                    color: context.hc.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appliedCoupon!.code,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.hc.success,
                      ),
                    ),
                    Text(
                      '${l.t('you_save')} ${DateHelper.formatCurrency(_discountAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.hc.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Remove coupon',
                button: true,
                child: IconButton(
                  onPressed: _removeCoupon,
                  icon: Icon(Icons.close, color: context.hc.greyLight),
                  iconSize: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: l.t('enter_coupon_code'),
                  prefixIcon: Icon(Icons.local_offer_outlined,
                      color: context.hc.greyLight),
                  errorText: _couponError,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isApplyingCoupon ? null : _applyCoupon,
                child: _isApplyingCoupon
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l.t('apply')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown(AppLocalizations l) {
    // audit M-14: hide the GST row entirely when total GST is 0 (e.g. cart
    // contains only nursing/manpower line items which are GST-exempt).
    // Rendering "GST: ₹0" was confusing patients into thinking we charge GST
    // on services that are actually exempt.
    final gst = _gstAmount;
    return HousepitalCard(
      child: Column(
        children: [
          _buildPriceRow(l.t('subtotal'), _subtotal),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              '${l.t('discount')} (${_appliedCoupon?.code ?? ''})',
              -_discountAmount,
              valueColor: context.hc.success,
            ),
          ],
          if (gst > 0) ...[
            const SizedBox(height: 8),
            _buildGstRow(gst),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _buildPriceRow(l.t('total'), _totalAmount, isBold: true),
        ],
      ),
    );
  }

  // audit M-14: GST row with an info icon that opens a bottom sheet
  // explaining the per-category breakdown. We label the row "GST" (no flat
  // percentage) because the effective rate is a blend now.
  Widget _buildGstRow(int gst) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'GST',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.hc.grey,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showGstExplainer,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: context.hc.greyLight,
                ),
              ),
            ),
          ],
        ),
        Text(
          DateHelper.formatCurrency(gst),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.hc.black,
          ),
        ),
      ],
    );
  }

  void _showGstExplainer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How GST is calculated',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Healthcare nursing is GST-exempt under Notification 12/2017. '
                'Equipment carries 18% GST. Lab tests carry 5%. '
                'Your total GST is the sum of each line item taxed at its own rate.',
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: context.hc.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount,
      {bool isBold = false, Color? valueColor}) {
    final isNegative = amount < 0;
    final displayAmount = isNegative ? amount.abs() : amount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? context.hc.black : context.hc.grey,
          ),
        ),
        Text(
          '${isNegative ? '- ' : ''}${DateHelper.formatCurrency(displayAmount)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? context.hc.black,
          ),
        ),
      ],
    );
  }
}
