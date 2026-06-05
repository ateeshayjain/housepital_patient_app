import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../utils/helpers.dart';

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

  const BookingConfirmationScreen({
    super.key,
    this.cartItems,
    required this.totalAmount,
    this.serviceName,
    this.scheduledDate,
    this.scheduledSlot,
    this.bookingNumber,
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

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkController.forward();
      _fadeController.forward();
    });

    HapticFeedback.mediumImpact();
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
    final itemLines = _items
        .map((i) => '- ${i.name}: ${DateHelper.formatCurrency(i.lineTotal)}')
        .join('\n');
    final text = 'Housepital Order Confirmation\n'
        'Order: $_bookingNumber\n'
        'Items:\n$itemLines\n'
        'Total: ${DateHelper.formatCurrency(widget.totalAmount)}';
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
                      decoration: const BoxDecoration(
                        color: HousepitalColors.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: HousepitalColors.success,
                        size: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Order Confirmed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: HousepitalColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _bookingNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Items list card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HousepitalColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HousepitalColors.divider),
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
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              DateHelper.formatCurrency(widget.totalAmount),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: HousepitalColors.orangeText,
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
                      color: HousepitalColors.infoLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: HousepitalColors.info, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'What happens next?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HousepitalColors.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
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
                ? HousepitalColors.infoLight
                : HousepitalColors.orangeLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.isService
                ? Icons.calendar_today_outlined
                : Icons.medical_services_outlined,
            size: 18,
            color: item.isService
                ? HousepitalColors.info
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
                  style: const TextStyle(
                      fontSize: 12, color: HousepitalColors.info),
                ),
              if (!item.isService && item.brand.isNotEmpty)
                Text(
                  item.brand,
                  style: const TextStyle(
                      fontSize: 12, color: HousepitalColors.greyLight),
                ),
              if (item.isService)
                const Text(
                  'Staff assignment in progress',
                  style: TextStyle(
                      fontSize: 11,
                      color: HousepitalColors.warning,
                      fontStyle: FontStyle.italic),
                ),
              if (!item.isService)
                const Text(
                  'Delivery in 24 hours',
                  style: TextStyle(
                      fontSize: 11,
                      color: HousepitalColors.success,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        Text(
          DateHelper.formatCurrency(item.lineTotal),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: HousepitalColors.orangeText,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HousepitalColors.greyLight),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: HousepitalColors.greyLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HousepitalColors.black,
              ),
            ),
          ],
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
            color: HousepitalColors.info.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HousepitalColors.info,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13,
                  color: HousepitalColors.greyLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
