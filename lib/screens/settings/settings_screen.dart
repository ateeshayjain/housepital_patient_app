import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profilePhotoPath;

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    final path = context.read<AppProvider>().profilePhotoPath;
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _profilePhotoPath = path);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Change Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: HousepitalColors.orange),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: HousepitalColors.orange),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (image == null) return;

    await context.read<AppProvider>().setProfilePhotoPath(image.path);
    if (mounted) {
      setState(() => _profilePhotoPath = image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final app = context.watch<AppProvider>();
    final patientName = app.currentPatient?.name ?? 'Patient';
    final initials = patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings_title'))),
      body: ListView(
        children: [
          // User profile section with photo
          Container(
            padding: const EdgeInsets.all(20),
            color: HousepitalColors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: HousepitalColors.orangeLight,
                        backgroundImage: _profilePhotoPath != null
                            ? FileImage(File(_profilePhotoPath!))
                            : null,
                        child: _profilePhotoPath == null
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: HousepitalColors.orange,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: HousepitalColors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: HousepitalColors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: HousepitalColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'View & Edit Profile',
                        style: const TextStyle(
                          fontSize: 13,
                          color: HousepitalColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: HousepitalColors.greyLight),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _settingsTile(
            context,
            icon: Icons.receipt_long,
            title: 'My Orders',
            onTap: () => Navigator.pushNamed(context, '/booking-history'),
          ),
          _settingsTile(
            context,
            icon: Icons.person_outline,
            title: l.t('patient_profile'),
            onTap: () => Navigator.pushNamed(context, '/patient-profile'),
          ),
          _settingsTile(
            context,
            icon: Icons.people_outline,
            title: l.t('family_members'),
            onTap: () => Navigator.pushNamed(context, '/family-members'),
          ),
          _settingsTile(
            context,
            icon: Icons.folder_outlined,
            title: 'Medical Documents',
            subtitle: 'Prescriptions, reports & records',
            onTap: () => Navigator.pushNamed(context, '/documents'),
          ),
          const Divider(height: 1),
          _settingsTile(
            context,
            icon: Icons.notifications_outlined,
            title: l.t('notification_settings'),
            onTap: () => Navigator.pushNamed(context, '/notification-preferences'),
          ),
          _settingsTile(
            context,
            icon: Icons.language,
            title: l.t('language_settings'),
            subtitle: app.locale.languageCode == 'en' ? 'English' : 'हिंदी',
            onTap: () => _showLanguagePicker(context, app),
          ),
          _settingsTile(
            context,
            icon: Icons.card_giftcard,
            title: 'Refer & Earn',
            subtitle: 'Earn \u20B9500 per referral',
            onTap: () => Navigator.pushNamed(context, '/referrals'),
          ),
          const Divider(height: 1),
          _settingsTile(
            context,
            icon: Icons.help_outline,
            title: l.t('help_faq'),
            onTap: () => Navigator.pushNamed(context, '/help-faq'),
          ),
          _settingsTile(
            context,
            icon: Icons.info_outline,
            title: l.t('about'),
            subtitle: 'Housepital v1.0.0',
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          const Divider(height: 1),
          _settingsTile(
            context,
            icon: Icons.logout,
            title: l.t('logout'),
            textColor: HousepitalColors.error,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? HousepitalColors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: textColor ?? HousepitalColors.black,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: HousepitalColors.greyLight))
          : null,
      trailing: const Icon(Icons.chevron_right,
          color: HousepitalColors.greyLight, size: 20),
      onTap: onTap,
    );
  }

  void _showLanguagePicker(BuildContext context, AppProvider app) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            title: const Text('English'),
            trailing: app.locale.languageCode == 'en'
                ? const Icon(Icons.check, color: HousepitalColors.orange)
                : null,
            onTap: () {
              app.setLanguage('en');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('\u0939\u093f\u0902\u0926\u0940 (Hindi)'),
            trailing: app.locale.languageCode == 'hi'
                ? const Icon(Icons.check, color: HousepitalColors.orange)
                : null,
            onTap: () {
              app.setLanguage('hi');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HousepitalColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
