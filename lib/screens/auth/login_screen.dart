import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // Logo area
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: HousepitalColors.orangeLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          size: 40,
                          color: HousepitalColors.orange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.t('app_name'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: HousepitalColors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.t('tagline'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                Text(
                  l.t('login_title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: HousepitalColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.t('login_subtitle'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: HousepitalColors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Phone input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l.t('phone_label'),
                    hintText: l.t('phone_hint'),
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(
                      fontSize: 16,
                      color: HousepitalColors.black,
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.length != 10) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(
                        color: HousepitalColors.error,
                        fontSize: 14,
                      ),
                    ),
                  ),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.state == AuthState.loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              auth.sendOtp(_phoneController.text);
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
                        : Text(l.t('send_otp')),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
