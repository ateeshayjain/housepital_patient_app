import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../models/models.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class BookingConfirmationScreen extends StatefulWidget {
  /// When coming from cart checkout, cartItems will be non-null.
  final List<CartItem>? cartItems;
  final int totalAmount;

  /// Legacy single-service fields (kept for backward compat).
  final String? serviceName;
  final DateTime? scheduledDate;
  final String? scheduledSlot;

  /// audit M-2: booking number must come from cart (propagated from
  /// OrdersProvider.generateUniqueBookingNumber), not regenerated here.
  /// Optional for backwards compat with legacy callers; falls back to a
  /// deprecated random suffix only when null.
  final String? bookingNumber;

  /// Quote-pending orders (manpower services / price-on-request equipment)
  /// have NO amount yet — render "Quote pending / Price will be confirmed on
  /// call" instead of any ₹ figure.
  final bool quotePending;

  const BookingConfirmationScreen({
    super.key,
    this.cartItems,
    required this.totalAmount,
    this.serviceName,
    this.scheduledDate,
    this.scheduledSlot,
    this.bookingNumber,
    this.quotePending = false,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  late final String _bookingNumber;

  /// Resolved list of items to display.
  List<CartItem> get _items {
    if (widget.cartItems != null && widget.cartItems!.isNotEmpty) {
      return widget.cartItems!;
    }
    // Legacy: single service fallback
    if (widget.serviceName != null) {
      return [
        CartItem(
          equipmentId: '',
          name: widget.serviceName!,
          brand: '',
          unitPrice: widget.totalAmount,
          isService: true,
          scheduledDate: widget.scheduledDate,
          scheduledSlot: widget.scheduledSlot,
        ),
      ];
    }
    return [];
  }

  bool get _hasServices => _items.any((i) => i.isService);
  bool get _hasEquipment => _items.any((i) => !i.isService);

  @override
  void initState() {
    super.initState();

    // audit M-2: booking number must come from cart, not regenerated. Fall
    // back to the deprecated random suffix ONLY when no booking number was
    // passed in (legacy callers / single-service confirmations).
    _bookingNumber = widget.bookingNumber ?? _generateLegacyFallback();

    // Apple P8: celebrations stay under the 500ms ceiling — 450ms easeOutBack
    // (was 700ms elasticOut, which both overshot the budget and wobbled).
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutBack,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start is deferred to didChangeDependencies: MediaQuery (and therefore
    // the Reduce Motion flag) is not available in initState.

    HapticFeedback.mediumImpact();
  }

  bool _animationsStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationsStarted) return;
    _animationsStarted = true;
    // WCAG 2.3.3 / Apple P8: with Reduce Motion on, present the final frame
    // immediately instead of playing the celebration.
    if (MediaQuery.of(context).disableAnimations) {
      _checkController.value = 1.0;
      _fadeController.value = 1.0;
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _checkController.forward();
        _fadeController.forward();
      });
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// audit M-2: DEPRECATED — random 5-digit booking number, prone to
  /// collisions. Retained ONLY as a fallback for legacy callers that did not
  /// pass `bookingNumber` to this screen. New callers MUST propagate the
  /// booking number from `OrdersProvider.generateUniqueBookingNumber()`.
  @Deprecated('Pass bookingNumber from OrdersProvider.generateUniqueBookingNumber() instead.')
  static String _generateLegacyFallback() {
    final rand = Random();
    return 'HPL-BOOK-${rand.nextInt(90000) + 10000}';
  }

  String _slotLabel(String? slot) {
    switch (slot) {
      case 'morning':
        return 'Morning (9 AM - 12 PM)';
      case 'afternoon':
        return 'Afternoon (12 - 4 PM)';
      case 'evening':
        return 'Evening (4 - 7 PM)';
      default:
        return slot ?? '';
    }
  }

  void _shareBooking() {
    // Quote-pending orders carry no amounts — never share a ₹0.
    final itemLines = _items
        .map((i) => widget.quotePending
            ? '- ${i.name}'
            : '- ${i.name}: ${DateHelper.formatCurrency(i.lineTotal)}')
        .join('\n');
    final totalLine = widget.quotePending
        ? 'Quote pending — price will be confirmed on call'
        : 'Total: ${DateHelper.formatCurrency(widget.totalAmount)}';
    final text = 'Housepital Order Confirmation\n'
        'Order: $_bookingNumber\n'
        'Items:\n$itemLines\n'
        '$totalLine';
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Green checkmark animation
                  ScaleTransition(
                    scale: _checkScale,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: context.hc.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: context.hc.success,
                        size: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Order Confirmed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.hc.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bookingNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.hc.black,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Items list card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.hc.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.hc.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Items',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        for (final item in _items) ...[
                          _buildItemRow(item),
                          if (item != _items.last)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        // Total — quote-pending orders never show a ₹ figure.
                        if (widget.quotePending) ...[
                          Row(
                            children: [
                              StatusBadge(
                                text: 'Quote pending',
                                color: context.hc.warning,
                                icon: Icons.schedule,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Price will be confirmed on call',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.hc.warning,
                            ),
                          ),
                        ] else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                DateHelper.formatCurrency(widget.totalAmount),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: context.hc.orangeText,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // What happens next section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.hc.infoLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: context.hc.info, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'What happens next?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.hc.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (widget.quotePending) ...[
                          // Quote-first orders: the price call comes first —
                          // nothing is charged before the user confirms.
                          _nextStepItem(
                            '1',
                            'Price Confirmation Call',
                            'Our team will call you to confirm the price before any payment.',
                          ),
                          const SizedBox(height: 10),
                          _nextStepItem(
                            '2',
                            _hasServices
                                ? 'Staff Assignment'
                                : 'Equipment Delivery',
                            _hasServices
                                ? 'Once you approve the quote, a qualified professional is assigned.'
                                : 'Once you approve the quote, your equipment is dispatched.',
                          ),
                          const SizedBox(height: 10),
                          _nextStepItem(
                            '3',
                            'Preparation Tips',
                            'Keep prescription and medical records handy.',
                          ),
                        ] else ...[
                          if (_hasServices) ...[
                            _nextStepItem(
                              '1',
                              'Staff Assignment',
                              'A qualified professional will be assigned within 2 hours.',
                            ),
                            const SizedBox(height: 10),
                            _nextStepItem(
                              '2',
                              'Confirmation Call',
                              'You will receive a confirmation call with staff details.',
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_hasEquipment) ...[
                            _nextStepItem(
                              _hasServices ? '3' : '1',
                              'Equipment Delivery',
                              'Your equipment will be delivered within 24 hours.',
                            ),
                            const SizedBox(height: 10),
                          ],
                          _nextStepItem(
                            _hasServices && _hasEquipment
                                ? '4'
                                : _hasServices
                                    ? '3'
                                    : '2',
                            'Preparation Tips',
                            'Keep prescription and medical records handy for the visit.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/booking-history',
                          (route) => route.isFirst,
                        );
                      },
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View My Orders'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      onPressed: _shareBooking,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share Order Details'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.isService
                ? context.hc.infoLight
                : context.hc.orangeLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.isService
                ? Icons.calendar_today_outlined
                : Icons.medical_services_outlined,
            size: 18,
            color: item.isService
                ? context.hc.info
                : HousepitalColors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (item.isService && item.scheduledDate != null)
                Text(
                  'Scheduled: ${DateHelper.formatDate(item.scheduledDate!)}${item.scheduledSlot != null ? ', ${_slotLabel(item.scheduledSlot)}' : ''}',
                  style: TextStyle(
                      fontSize: 12, color: context.hc.info),
                ),
              if (!item.isService && item.brand.isNotEmpty)
                Text(
                  item.brand,
                  style: TextStyle(
                      fontSize: 12, color: context.hc.greyLight),
                ),
              if (item.isService)
                Text(
                  'Staff assignment in progress',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.hc.warning,
                      fontStyle: FontStyle.italic),
                ),
              if (!item.isService)
                Text(
                  'Delivery in 24 hours',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.hc.success,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        // Quote-pending orders never render a ₹ line amount.
        if (widget.quotePending)
          Text(
            'On call',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.hc.warning,
            ),
          )
        else
          Text(
            DateHelper.formatCurrency(item.lineTotal),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.hc.orangeText,
            ),
          ),
      ],
    );
  }

  Widget _nextStepItem(String number, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: context.hc.info.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.hc.info,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.hc.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13,
                  color: context.hc.greyLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
