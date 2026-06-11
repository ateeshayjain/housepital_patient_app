// lib/screens/my_care/staff_otp_verification_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_colors.dart';
import '../../config/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/glass.dart';

/// OTP verification screen shown to patient when staff arrives.
///
/// Flow:
///   1. A 4-digit OTP is generated and displayed to the patient
///   2. Staff enters this OTP on their app
///   3. Patient screen listens to Firestore `active_sessions/{deploymentId}`
///      for the `verified` field becoming `true`
///   4. On verification: green checkmark animation + auto-dismiss after 3s
class StaffOtpVerificationScreen extends StatefulWidget {
  final String deploymentId;
  final String staffName;
  final String staffRole;
  final String? staffPhotoUrl;

  const StaffOtpVerificationScreen({
    super.key,
    required this.deploymentId,
    required this.staffName,
    required this.staffRole,
    this.staffPhotoUrl,
  });

  @override
  State<StaffOtpVerificationScreen> createState() =>
      _StaffOtpVerificationScreenState();
}

class _StaffOtpVerificationScreenState
    extends State<StaffOtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final String _otp;
  bool _verified = false;
  StreamSubscription? _subscription;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Generate 4-digit OTP
    _otp = (1000 + Random().nextInt(9000)).toString();

    // Store the OTP in Firestore so staff app can validate
    _storeOtp();

    // Listen for verification
    _listenForVerification();

    // Animation for verified checkmark.
    // Apple P8: celebrations stay under the 500ms ceiling — 450ms easeOutBack
    // (was 600ms elasticOut).
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _storeOtp() async {
    await FirebaseFirestore.instance
        .collection('active_sessions')
        .doc(widget.deploymentId)
        .set({
      'otp': _otp,
      'verified': false,
      'generated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _listenForVerification() {
    _subscription = FirebaseFirestore.instance
        .collection('active_sessions')
        .doc(widget.deploymentId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data != null && data['verified'] == true && !_verified) {
        setState(() => _verified = true);
        // WCAG 2.3.3 / Apple P8: with Reduce Motion on, show the verified
        // checkmark at its final frame instead of animating it in. (Safe to
        // read MediaQuery here — this stream callback only fires post-build.)
        if (MediaQuery.of(context).disableAnimations) {
          _animController.value = 1.0;
        } else {
          _animController.forward();
        }

        // Auto-dismiss after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Verify Staff'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Staff info card
            _buildStaffCard(),

            const SizedBox(height: 32),

            // OTP section or verified state
            _verified ? _buildVerified() : _buildOtpDisplay(),

            const SizedBox(height: 40),

            // Fallback support
            if (!_verified) _buildFallback(),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: HousepitalColors.orange,
              backgroundImage: widget.staffPhotoUrl != null
                  ? NetworkImage(widget.staffPhotoUrl!)
                  : null,
              child: widget.staffPhotoUrl == null
                  ? Text(
                      widget.staffName
                          .split(' ')
                          .map((n) => n[0])
                          .take(2)
                          .join(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.staffName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.hc.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.staffRole,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.hc.orangeText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpDisplay() {
    return Column(
      children: [
        const Text(
          'Verify Staff Identity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share this OTP with the staff member.\nThey will enter it on their app to confirm arrival.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.hc.grey,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // OTP digits
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: context.hc.orangeLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HousepitalColors.orange, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: _otp.split('').map((digit) {
              return Container(
                width: 48,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: HousepitalColors.orange.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: HousepitalColors.orange,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Waiting indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: HousepitalColors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Waiting for staff to enter OTP...',
              style: TextStyle(fontSize: 13, color: context.hc.greyLight),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerified() {
    return Column(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.hc.successLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: context.hc.success,
              size: 64,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Staff Verified!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.hc.success,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.staffName} has been verified.\nThis screen will close automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.hc.grey,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return Column(
      children: [
        const Divider(height: 40),
        Text(
          "Can't verify?",
          style: TextStyle(fontSize: 14, color: context.hc.grey),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            // NOTE: Support number to be updated with production contact details.
            final uri = Uri.parse('tel:+918888888888');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          icon: const Icon(Icons.phone),
          label: const Text('Call Support'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.hc.error,
            side: BorderSide(color: context.hc.error),
          ),
        ),
      ],
    );
  }
}
