import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/payment_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class PaymentScreen extends StatefulWidget {
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
  int get _gstAmount => ((_subtotal - _discountAmount) * 0.18).round();
  int get _totalAmount => _subtotal - _discountAmount + _gstAmount;

  @override
  void initState() {
    super.initState();
    _initPaymentService();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.elasticOut,
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

    _paymentService!.openCheckout(
      amount: _totalAmount,
      description: widget.description,
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
        _fadeAnimController.forward();
        _checkAnimController.forward();
      },
      onFailure: (message) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _showResult = true;
          _paymentSuccess = false;
          _transactionId = null;
          _failureMessage = message;
        });
        HapticFeedback.heavyImpact();
        _fadeAnimController.forward();
        _checkAnimController.forward();
      },
    );
  }

  /// Web payment simulation — simulates a successful payment after a brief delay.
  Future<void> _processWebPayment() async {
    setState(() => _isProcessing = true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final txnId = 'web_pay_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _isProcessing = false;
      _showResult = true;
      _paymentSuccess = true;
      _transactionId = txnId;
      _failureMessage = null;
    });
    _fadeAnimController.forward();
    _checkAnimController.forward();
  }

  void _retryPayment() {
    setState(() {
      _showResult = false;
      _paymentSuccess = true;
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
      appBar: AppBar(title: Text(l.t('payment'))),
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
                  height: 48,
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
                          ? HousepitalColors.successLight
                          : HousepitalColors.errorLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.cancel,
                      color: isSuccess
                          ? HousepitalColors.success
                          : HousepitalColors.error,
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  isSuccess
                      ? l.t('payment_successful')
                      : 'Payment Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isSuccess
                        ? HousepitalColors.success
                        : HousepitalColors.error,
                  ),
                ),
                const SizedBox(height: 12),

                // Amount
                Text(
                  DateHelper.formatCurrency(_totalAmount),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                const SizedBox(height: 24),

                // Transaction ID or failure message
                if (isSuccess && _transactionId != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HousepitalColors.greyLighter,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l.t('transaction_id'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: HousepitalColors.greyLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Semantics(
                          label: 'Transaction ID: $_transactionId',
                          child: SelectableText(
                            _transactionId!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HousepitalColors.black,
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
                      color: HousepitalColors.errorLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _failureMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: HousepitalColors.error,
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.t('opening_receipt'))),
                              );
                            },
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
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
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
          gradient: const LinearGradient(
            colors: [HousepitalColors.orange, HousepitalColors.orangeDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              l.t('amount_to_pay'),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
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
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
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
                    ? HousepitalColors.orangeLight
                    : HousepitalColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? HousepitalColors.orange
                      : HousepitalColors.divider,
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
                        : HousepitalColors.grey,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? HousepitalColors.orangeText
                            : HousepitalColors.black,
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
                  color: HousepitalColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_offer,
                    color: HousepitalColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appliedCoupon!.code,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: HousepitalColors.success,
                      ),
                    ),
                    Text(
                      '${l.t('you_save')} ${DateHelper.formatCurrency(_discountAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.grey,
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
                  icon: const Icon(Icons.close, color: HousepitalColors.greyLight),
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
                  prefixIcon: const Icon(Icons.local_offer_outlined,
                      color: HousepitalColors.greyLight),
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
    return HousepitalCard(
      child: Column(
        children: [
          _buildPriceRow(l.t('subtotal'), _subtotal),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              '${l.t('discount')} (${_appliedCoupon?.code ?? ''})',
              -_discountAmount,
              valueColor: HousepitalColors.success,
            ),
          ],
          const SizedBox(height: 8),
          _buildPriceRow('GST (18%)', _gstAmount),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _buildPriceRow(l.t('total'), _totalAmount, isBold: true),
        ],
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
            color: isBold ? HousepitalColors.black : HousepitalColors.grey,
          ),
        ),
        Text(
          '${isNegative ? '- ' : ''}${DateHelper.formatCurrency(displayAmount)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? HousepitalColors.black,
          ),
        ),
      ],
    );
  }
}
