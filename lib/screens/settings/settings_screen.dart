import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/permissions.dart';
import '../../utils/session_scope.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';
import '../../utils/image_privacy.dart';

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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    final image = await ImagePrivacy.pickSanitizedImage(picker,
        source: source, maxWidth: 512, maxHeight: 512);
    if (image == null) return;

    if (!mounted) return;
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
      appBar: GlassAppBar(
        // Root tab: bottom nav already provides Home.
        showHome: true, // owner: home button on every screen (only the Home tab omits it)
        title: Text(l.t('settings_title')),
      ),
      body: ListView(
        children: [
          // User profile section with photo. The whole row opens the patient
          // profile (field bug: 'View & Edit Profile' did nothing — there was
          // no tap handler); the avatar keeps its own photo-picker tap.
          Material(
            color: Theme.of(context).cardTheme.color ??
                Theme.of(context).colorScheme.surface,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/patient-profile'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
              children: [
                GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: context.hc.orangeLight,
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
                                color: context.hc.white, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: context.hc.white,
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
                Icon(Icons.chevron_right,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          _settingsTile(
            context,
            icon: Icons.receipt_long,
            title: 'My Orders',
            onTap: () => Navigator.pushNamed(context, '/my-orders'),
          ),
          _settingsTile(
            context,
            icon: Icons.person_outline,
            title: l.t('patient_profile'),
            onTap: () => Navigator.pushNamed(context, '/patient-profile'),
          ),
          // Add Patient — primary contacts only (they own the patient record).
          if (canUserPerform(app.currentUserRole, UserAction.editPatient))
            _settingsTile(
              context,
              icon: Icons.person_add,
              title: 'Add Patient',
              subtitle: 'Care for another family member',
              onTap: () => Navigator.pushNamed(context, '/add-patient'),
            ),
          // Family Members — only primary contacts can manage who can see what.
          if (canUserPerform(app.currentUserRole, UserAction.manageFamily))
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
            icon: Icons.brightness_6_outlined,
            title: 'Appearance',
            subtitle: _appearanceLabel(context.watch<ThemeProvider>().mode),
            onTap: () => _showAppearancePicker(context),
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
            textColor: context.hc.error,
            onTap: () => _confirmLogout(context),
          ),
          const Divider(height: 1),
          // App Store Guideline 5.1.1(v) + DPDP 2023 §12: account deletion
          // must be reachable IN the app. A Logout button does not satisfy
          // either, and "email support to delete" is an automatic rejection.
          _settingsTile(
            context,
            icon: Icons.person_remove_outlined,
            title: 'Delete account',
            textColor: context.hc.error,
            onTap: () => Navigator.pushNamed(context, '/delete-account'),
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
    // Theme-aware fallback colours so the tile reads in both light and dark.
    final theme = Theme.of(context);
    final defaultTitleColor = theme.colorScheme.onSurface;
    final defaultSubtitleColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return ListTile(
      leading: AppIconTile(
        icon: icon,
        color: textColor ?? HousepitalColors.orange,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: textColor ?? defaultTitleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(fontSize: 12, color: defaultSubtitleColor))
          : null,
      trailing:
          Icon(Icons.chevron_right, color: defaultSubtitleColor, size: 20),
      onTap: onTap,
    );
  }

  String _appearanceLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  void _showAppearancePicker(BuildContext context) {
    final theme = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        // Watch inside the sheet so the radio selection updates live as the
        // user taps — even though tap also closes the sheet, the visual
        // confirmation feels responsive.
        return Consumer<ThemeProvider>(
          builder: (_, watched, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Appearance',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              RadioGroup<ThemeMode>(
                groupValue: watched.mode,
                onChanged: (m) {
                  if (m == null) return;
                  theme.setMode(m);
                  Navigator.pop(sheetCtx);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _appearanceOption(
                      sheetCtx,
                      title: 'System default',
                      subtitle: 'Match your device setting',
                      value: ThemeMode.system,
                    ),
                    _appearanceOption(
                      sheetCtx,
                      title: 'Light',
                      value: ThemeMode.light,
                    ),
                    _appearanceOption(
                      sheetCtx,
                      title: 'Dark',
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _appearanceOption(
    BuildContext context, {
    required String title,
    String? subtitle,
    required ThemeMode value,
  }) {
    return RadioListTile<ThemeMode>(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      activeColor: HousepitalColors.orange,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            onPressed: () async {
              // Wipe patient data from memory AND disk BEFORE signing out —
              // on a shared phone the next person must not see the previous
              // patient's clinical data. Awaited so logout's prefs.clear()
              // cannot race the wipe.
              final nav = Navigator.of(context);
              final auth = context.read<AuthProvider>();
              await SessionScope.clearSession(context);
              await auth.logout();
              nav.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.hc.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
