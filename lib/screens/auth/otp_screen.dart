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

  @override
  void initState() {
    super.initState();
    _startResendTimer();
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

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
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
                  auth.verifyOtp(code);
                },
                onChanged: (_) {},
              ),

              const SizedBox(height: 16),

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
                  onPressed: auth.state == AuthState.loading
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
                child: _resendTimer > 0
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
                          _startResendTimer();
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
