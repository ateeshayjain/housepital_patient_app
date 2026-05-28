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
  final _scrollController = ScrollController();

  // audit M-7: T&C consent must be explicit — empty regulators flag implicit
  // consent. Hold it in widget state so we can disable the CTA off it.
  bool _agreedToTerms = false;
  // audit M-7: GlobalKey so we can scroll the checkbox into view when the
  // user taps Send without agreeing.
  final _termsKey = GlobalKey();

  @override
  void dispose() {
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // audit M-7: Indian mobile prefix validation (TRAI uses 6–9 leading digit).
  bool _isValidIndianMobile(String value) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(value);
  }

  Future<void> _onSendOtp() async {
    final auth = context.read<AuthProvider>();
    final formValid = _formKey.currentState?.validate() ?? false;

    // audit M-7: bounce on missing consent before touching the API.
    if (!_agreedToTerms) {
      final ctx = _termsKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms to continue')),
      );
      return;
    }

    if (formValid) {
      auth.sendOtp(_phoneController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  48,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

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

                  const SizedBox(height: 48),

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
                    // audit M-7: Indian mobile prefix check — was a length-only
                    // check, which let 0XXXXXXXXX / landlines through.
                    validator: (value) {
                      if (value == null || !_isValidIndianMobile(value)) {
                        return 'Enter a valid 10-digit Indian mobile (starts with 6-9)';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // audit M-7: explicit T&C consent. Tapping the row toggles
                  // the checkbox; the link words route to /about which holds
                  // the policy copy today.
                  Padding(
                    key: _termsKey,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () =>
                          setState(() => _agreedToTerms = !_agreedToTerms),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              activeColor: HousepitalColors.orange,
                              onChanged: (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: HousepitalColors.grey,
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: GestureDetector(
                                          onTap: () => Navigator.pushNamed(
                                              context, '/about'),
                                          child: const Text(
                                            'Terms',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: HousepitalColors.orange,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' & '),
                                      WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: GestureDetector(
                                          onTap: () => Navigator.pushNamed(
                                              context, '/about'),
                                          child: const Text(
                                            'Privacy Policy',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: HousepitalColors.orange,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

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

                  // audit M-7: button is disabled until consent + valid phone.
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (auth.state == AuthState.loading ||
                              !_agreedToTerms ||
                              !_isValidIndianMobile(_phoneController.text))
                          ? null
                          : _onSendOtp,
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

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
