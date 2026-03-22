import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  List<Booking>? _bookings;
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all';

  static const _statusFilters = [
    'all',
    'pending',
    'confirmed',
    'in_progress',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final appProvider = context.read<AppProvider>();
      final patientId = appProvider.currentPatient?.id;
      if (patientId == null) {
        setState(() {
          _error = 'No patient selected';
          _isLoading = false;
        });
        return;
      }
      final bookings = await ApiService().getBookings(patientId);
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load bookings';
        _isLoading = false;
      });
    }
  }

  List<Booking> get _filteredBookings {
    if (_bookings == null) return [];
    if (_filterStatus == 'all') return _bookings!;
    return _bookings!.where((b) => b.status == _filterStatus).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return HousepitalColors.warning;
      case 'confirmed':
        return HousepitalColors.info;
      case 'in_progress':
        return HousepitalColors.orange;
      case 'completed':
        return HousepitalColors.success;
      case 'cancelled':
        return HousepitalColors.error;
      default:
        return HousepitalColors.greyLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Future<void> _showCancellationFlow(Booking booking) async {
    String? selectedReason;
    final reasons = [
      'Schedule conflict',
      'Found alternative',
      'No longer needed',
      'Other',
    ];

    final now = DateTime.now();
    final hoursUntil =
        booking.scheduledDate.difference(now).inHours;
    final refundPercent = hoursUntil > 24 ? 100 : 50;
    final refundAmount =
        (booking.totalAmount * refundPercent / 100).round();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancel Booking',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // Cancellation policy
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: refundPercent == 100
                        ? HousepitalColors.successLight
                        : HousepitalColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancellation Policy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: refundPercent == 100
                              ? HousepitalColors.success
                              : HousepitalColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        refundPercent == 100
                            ? 'More than 24 hours before service — full refund of ${DateHelper.formatCurrency(refundAmount)}.'
                            : 'Less than 24 hours before service — 50% refund of ${DateHelper.formatCurrency(refundAmount)}.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Reason for cancellation',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 10),
                ...reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason,
                          style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: HousepitalColors.orange,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (v) {
                        setModalState(() => selectedReason = v);
                      },
                    )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Keep Booking'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HousepitalColors.error,
                          ),
                          onPressed: selectedReason == null
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: const Text('Cancel Booking'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );

    if (confirmed == true && selectedReason != null && mounted) {
      try {
        await ApiService().cancelBooking(booking.id, selectedReason!);
        _loadBookings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: HousepitalColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking'),
            backgroundColor: HousepitalColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRatingSheet(Booking booking) async {
    int rating = 0;
    final commentController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rate this Service',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  booking.serviceName ?? 'Service',
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                const SizedBox(height: 20),

                // 5-star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => rating = index + 1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 40,
                          color: index < rating
                              ? HousepitalColors.orange
                              : HousepitalColors.divider,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Optional text feedback
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Share your experience (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: rating == 0
                              ? null
                              : () async {
                                  try {
                                    await ApiService().submitRating(
                                      bookingId: booking.id,
                                      rating: rating,
                                      comment: commentController
                                              .text.isNotEmpty
                                          ? commentController.text
                                          : null,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadBookings();
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Failed to submit rating'),
                                          backgroundColor:
                                              HousepitalColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: const Text('Rate'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
    commentController.dispose();
  }

  void _rebookService(Booking booking) {
    // Navigate to service booking pre-filled
    // We create a minimal ServiceItem from booking data
    final service = ServiceItem(
      id: booking.serviceId,
      name: booking.serviceName ?? 'Service',
      category: 'general',
      bookingType: booking.bookingType,
    );
    Navigator.pushNamed(context, '/service-booking', arguments: service);
  }

  void _showBookingDetail(Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.serviceName ?? 'Service',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: HousepitalColors.black,
                      ),
                    ),
                  ),
                  StatusBadge(
                    text: _statusLabel(booking.status),
                    color: _statusColor(booking.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('Booking #', booking.bookingNumber),
              _infoRow('Date', DateHelper.formatDate(booking.scheduledDate)),
              if (booking.scheduledSlot != null)
                _infoRow('Slot', booking.scheduledSlot!),
              _infoRow(
                  'Amount', DateHelper.formatCurrency(booking.totalAmount)),
              if (booking.assignedStaffName != null)
                _infoRow('Assigned Staff', booking.assignedStaffName!),
              if (booking.address != null)
                _infoRow('Address', booking.address!),
              if (booking.rating != null)
                _infoRow('Rating', '${'★' * booking.rating!}${'☆' * (5 - booking.rating!)}'),
              if (booking.cancellationReason != null)
                _infoRow('Cancel Reason', booking.cancellationReason!),
              const SizedBox(height: 20),

              // Action buttons based on status
              if (booking.status == 'pending' ||
                  booking.status == 'confirmed') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HousepitalColors.error,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCancellationFlow(booking);
                    },
                    child: const Text('Cancel Booking'),
                  ),
                ),
              ],

              if (booking.status == 'completed' &&
                  booking.rating == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRatingSheet(booking);
                    },
                    child: const Text('Rate Service'),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (booking.status == 'completed') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _rebookService(booking);
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Book Again'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: HousepitalColors.greyLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: HousepitalColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading bookings...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style:
                              const TextStyle(color: HousepitalColors.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadBookings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Status filter chips
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _statusFilters.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final filter = _statusFilters[i];
                          final selected = _filterStatus == filter;
                          return FilterChip(
                            label: Text(
                              filter == 'all'
                                  ? 'All'
                                  : _statusLabel(filter),
                            ),
                            selected: selected,
                            selectedColor: HousepitalColors.orangeLight,
                            checkmarkColor: HousepitalColors.orange,
                            onSelected: (_) {
                              setState(() => _filterStatus = filter);
                            },
                          );
                        },
                      ),
                    ),

                    // Booking list
                    Expanded(
                      child: _filteredBookings.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadBookings,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredBookings.length,
                                itemBuilder: (_, i) {
                                  return _buildBookingCard(
                                      _filteredBookings[i]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: HousepitalColors.divider,
          ),
          const SizedBox(height: 16),
          Text(
            _filterStatus == 'all'
                ? 'No bookings yet'
                : 'No ${_statusLabel(_filterStatus).toLowerCase()} bookings',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your bookings will appear here',
            style: TextStyle(
              fontSize: 14,
              color: HousepitalColors.greyLight,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.add),
            label: const Text('Book a Service'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HousepitalCard(
        onTap: () => _showBookingDetail(booking),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.serviceName ?? 'Service',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black,
                    ),
                  ),
                ),
                StatusBadge(
                  text: _statusLabel(booking.status),
                  color: _statusColor(booking.status),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: HousepitalColors.greyLight),
                const SizedBox(width: 6),
                Text(
                  DateHelper.formatDate(booking.scheduledDate),
                  style: const TextStyle(
                    fontSize: 13,
                    color: HousepitalColors.greyLight,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.payment_outlined,
                    size: 14, color: HousepitalColors.greyLight),
                const SizedBox(width: 6),
                Text(
                  DateHelper.formatCurrency(booking.totalAmount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
              ],
            ),
            // Show rate prompt for completed unrated bookings
            if (booking.status == 'completed' &&
                booking.rating == null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: () => _showRatingSheet(booking),
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Rate this service',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
            // Show re-book for completed bookings
            if (booking.status == 'completed') ...[
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: () => _rebookService(booking),
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Book Again',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
