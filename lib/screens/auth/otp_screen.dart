import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_localizations.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  int _resendTimer = 30;
  Timer? _timer;

  // audit M-6: OTP must expire so a stale code can't sit on the screen
  // forever — matches what real SMS gateways do.
  Timer? _expiryTimer;
  int _expirySeconds = 300;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startExpiryTimer();
  }

  void _startResendTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  // audit M-6: 5-minute countdown. When it hits 0, lock the input and force
  // a resend.
  void _startExpiryTimer() {
    _expirySeconds = 300;
    _isExpired = false;
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_expirySeconds > 0) {
        setState(() => _expirySeconds--);
      } else {
        setState(() => _isExpired = true);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  String _formatExpiry(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                l.t('otp_title'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l.t("otp_subtitle")} +91 ${auth.phone ?? ""}',
                style: const TextStyle(
                  fontSize: 14,
                  color: HousepitalColors.grey,
                ),
              ),
              const SizedBox(height: 32),

              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                // audit M-6: lock the input once the code has expired.
                enabled: !_isExpired,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 52,
                  fieldWidth: 48,
                  activeFillColor: HousepitalColors.white,
                  inactiveFillColor: HousepitalColors.greyLighter,
                  selectedFillColor: HousepitalColors.orangeLight,
                  activeColor: HousepitalColors.orange,
                  inactiveColor: HousepitalColors.divider,
                  selectedColor: HousepitalColors.orange,
                ),
                enableActiveFill: true,
                onCompleted: (code) {
                  if (_isExpired) return;
                  auth.verifyOtp(code);
                },
                onChanged: (_) {},
              ),

              const SizedBox(height: 8),

              // audit M-6: countdown / expired helper text.
              if (_isExpired)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'OTP expired — tap Resend.',
                    style: TextStyle(
                      color: HousepitalColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'OTP expires in ${_formatExpiry(_expirySeconds)}',
                    style: const TextStyle(
                      color: HousepitalColors.greyLight,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 8),

              if (auth.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    auth.errorMessage!,
                    style: const TextStyle(
                      color: HousepitalColors.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (auth.state == AuthState.loading || _isExpired)
                      ? null
                      : () {
                          if (_otpController.text.length == 6) {
                            auth.verifyOtp(_otpController.text);
                          }
                        },
                  child: auth.state == AuthState.loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.t('verify_otp')),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: (_resendTimer > 0 && !_isExpired)
                    ? Text(
                        l.t('resend_in',
                            {'seconds': _resendTimer.toString()}),
                        style: const TextStyle(
                          color: HousepitalColors.greyLight,
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          auth.sendOtp(auth.phone!);
                          _otpController.clear();
                          _startResendTimer();
                          // audit M-6: resetting expiry on resend.
                          _startExpiryTimer();
                        },
                        child: Text(
                          l.t('resend_otp'),
                          style: const TextStyle(
                            color: HousepitalColors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
