import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../utils/helpers.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final String serviceName;
  final DateTime scheduledDate;
  final String scheduledSlot;
  final int totalAmount;

  const BookingConfirmationScreen({
    super.key,
    required this.serviceName,
    required this.scheduledDate,
    required this.scheduledSlot,
    required this.totalAmount,
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

  @override
  void initState() {
    super.initState();

    // Generate booking number
    final rand = Random();
    _bookingNumber =
        'HPL-BOOK-${rand.nextInt(90000) + 10000}';

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

  String get _slotLabel {
    switch (widget.scheduledSlot) {
      case 'morning':
        return 'Morning (9 AM - 12 PM)';
      case 'afternoon':
        return 'Afternoon (12 - 4 PM)';
      case 'evening':
        return 'Evening (4 - 7 PM)';
      default:
        return widget.scheduledSlot;
    }
  }

  void _shareBooking() {
    final text = 'Housepital Booking Confirmation\n'
        'Booking: $_bookingNumber\n'
        'Service: ${widget.serviceName}\n'
        'Date: ${DateHelper.formatDate(widget.scheduledDate)}\n'
        'Slot: $_slotLabel\n'
        'Amount: ${DateHelper.formatCurrency(widget.totalAmount)}';
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
                    'Booking Confirmed!',
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

                  // Booking details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HousepitalColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HousepitalColors.divider),
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                            Icons.medical_services_outlined,
                            'Service',
                            widget.serviceName),
                        const SizedBox(height: 14),
                        _detailRow(
                            Icons.calendar_today_outlined,
                            'Date',
                            DateHelper.formatDate(widget.scheduledDate)),
                        const SizedBox(height: 14),
                        _detailRow(
                            Icons.access_time_outlined,
                            'Slot',
                            _slotLabel),
                        const SizedBox(height: 14),
                        _detailRow(
                            Icons.payment_outlined,
                            'Amount',
                            DateHelper.formatCurrency(widget.totalAmount)),
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
                        _nextStepItem(
                          '3',
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
                      label: const Text('View My Bookings'),
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
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Book Another Service'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      onPressed: _shareBooking,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share Booking Details'),
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
