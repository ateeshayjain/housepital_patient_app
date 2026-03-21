import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _relationship = 'son';
  String _language = 'en';
  bool _enableNotifications = true;

  final Map<String, String> _relationshipLabels = {
    'spouse': 'Spouse / पति-पत्नी',
    'son': 'Son / बेटा',
    'daughter': 'Daughter / बेटी',
    'son_in_law': 'Son-in-law / दामाद',
    'daughter_in_law': 'Daughter-in-law / बहू',
    'sibling': 'Sibling / भाई-बहन',
    'other': 'Other / अन्य',
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l.t('onboarding_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l.t('name_label')),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Relationship
                DropdownButtonFormField<String>(
                  value: _relationship,
                  decoration: InputDecoration(
                      labelText: l.t('relationship_label')),
                  items: AppConstants.relationships.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(_relationshipLabels[r] ?? r),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _relationship = value);
                  },
                ),
                const SizedBox(height: 20),

                // Language
                DropdownButtonFormField<String>(
                  value: _language,
                  decoration:
                      InputDecoration(labelText: l.t('language_label')),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _language = value);
                  },
                ),
                const SizedBox(height: 24),

                // Notifications toggle
                Card(
                  child: SwitchListTile(
                    title: Text(l.t('enable_notifications')),
                    subtitle: Text(
                      l.t('notifications_benefit'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HousepitalColors.greyLight,
                      ),
                    ),
                    value: _enableNotifications,
                    activeColor: HousepitalColors.orange,
                    onChanged: (value) {
                      setState(() => _enableNotifications = value);
                    },
                  ),
                ),
                const SizedBox(height: 32),

                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: HousepitalColors.error),
                    ),
                  ),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.state == AuthState.loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              auth.completeOnboarding(
                                name: _nameController.text.trim(),
                                relationship: _relationship,
                                preferredLanguage: _language,
                              );
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
                        : Text(l.t('complete_setup')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
