import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/logger.dart';
import '../../utils/session_scope.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass.dart';

/// In-app account deletion.
///
/// Required by App Store Review Guideline 5.1.1(v) — an app that lets a user
/// create an account must let them delete it from inside the app, not by
/// emailing support — and by India's DPDP Act 2023 §12 (right to erasure).
/// Neither is satisfied by a Logout button, which is all this app had.
///
/// HONESTY ABOUT WHAT THIS DOES TODAY
/// The patient backend is not reachable yet. The FIRST version of this screen
/// claimed records were "scheduled for deletion within 30 days" while
/// `_submitDeletionRequest` was a 600 ms `Future.delayed` — nothing was sent,
/// queued, or recorded, and the user was logged out immediately so they could
/// not check. That is a false statement to a patient about their medical
/// records, and it was a worse defect than the missing feature.
///
/// What it does now, in order:
///   1. Writes a DURABLE local deletion request that survives the wipe, so a
///      request exists with no backend and can be replayed when one arrives.
///   2. Deletes the Firebase credential where one exists, rather than only
///      signing out — 5.1.1(v) is about the ACCOUNT, not the session.
///   3. Wipes all local data via SessionScope, then signs out.
///   4. States exactly what is DONE and what is REQUESTED, separately, with a
///      reference number and a phone number.
///
/// When the backend lands, replace [_recordDeletionRequest]'s local write with
/// the real endpoint and keep step 4's wording aligned with what that endpoint
/// actually guarantees.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _understood = false;
  bool _isSubmitting = false;

  /// Key for the durable request record. Deliberately NOT cleared by the wipe
  /// or by logout: it is the only evidence the request was made, and it is
  /// what a future backend replays. Holds no PHI — a timestamp, the patient
  /// id, and a locally generated reference.
  static const String pendingDeletionKey = 'housepital_pending_deletion';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  /// The word the user must type. Localized, so a Hindi-preferring user is not
  /// asked to type a Latin word they may not read.
  String _confirmWord(AppLocalizations l) => l.t('delete_account_confirm_word');

  bool _canSubmit(AppLocalizations l) =>
      _understood &&
      _confirmController.text.trim().toUpperCase() ==
          _confirmWord(l).toUpperCase() &&
      !_isSubmitting;

  Future<String> _recordDeletionRequest(String? patientId) async {
    final requestedAt = DateTime.now();
    final reference =
        'DEL-${requestedAt.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      pendingDeletionKey,
      jsonEncode(<String, dynamic>{
        'reference': reference,
        'requestedAt': requestedAt.toIso8601String(),
        'patientId': patientId,
        'deliveredToServer': false,
      }),
    );
    return reference;
  }

  Future<void> _submitDeletionRequest() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _isSubmitting = true);

    final patientId = context.read<AppProvider>().currentPatient?.id;

    // 1. Record durably FIRST: if anything below fails, a request still exists.
    String reference;
    try {
      reference = await _recordDeletionRequest(patientId);
    } catch (e) {
      Log.error('Could not record deletion request',
          error: e, tag: 'DeleteAccount');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.t('delete_account_failed_title')),
          content: Text(l.t('delete_account_failed_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l.t('ok')),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Delete the credential itself where one exists.
    var credentialDeleted = false;
    try {
      final user = FirebaseService().currentUser;
      if (user != null) {
        await user.delete();
        credentialDeleted = true;
      }
    } catch (e) {
      // Usually needs a recent login. The local record above still stands.
      Log.warn('Firebase account delete failed (may need recent re-auth)',
          error: e, tag: 'DeleteAccount');
    }

    if (!mounted) return;

    // 3. Wipe local data, then sign out.
    await SessionScope.clearSession(context);
    if (!mounted) return;
    await context.read<AuthProvider>().logout();

    if (!mounted) return;
    // 4. Say what is DONE and what is REQUESTED — never conflate the two.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.t('delete_account_done_title')),
        content: Text(
          '${l.t('delete_account_done_device')}\n\n'
          '${credentialDeleted ? l.t('delete_account_done_login') : l.t('delete_account_done_login_pending')}\n\n'
          '${l.t('delete_account_done_server')}\n\n'
          '${l.t('delete_account_reference')}: $reference',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).popUntil((route) => route.isFirst),
            child: Text(l.t('ok')),
          ),
        ],
      ),
    );
  }

  void _confirm(AppLocalizations l) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.t('delete_account_confirm_title')),
        content: Text(l.t('delete_account_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.t('delete_account_keep')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.hc.error,
              // Paired foreground: white on the DARK-mode error red measures
              // 3.49:1 and fails AA. onError flips with appearance.
              foregroundColor: context.hc.onError,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _submitDeletionRequest();
            },
            child: Text(l.t('delete_account_delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;
    final canSubmit = _canSubmit(l);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(l.t('delete_account_title')),
        // Purchase-funnel logic applies here too: a cart icon on a deletion
        // screen is noise at best.
        showCart: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 32),
        children: [
          Text(
            l.t('delete_account_intro'),
            style: TextStyle(fontSize: 16, color: context.hc.black),
          ),
          const SizedBox(height: 20),
          HousepitalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('delete_account_removed_title'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.hc.black)),
                const SizedBox(height: 10),
                _bullet(context, l.t('delete_account_removed_1')),
                _bullet(context, l.t('delete_account_removed_2')),
                _bullet(context, l.t('delete_account_removed_3')),
                _bullet(context, l.t('delete_account_removed_4')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HousepitalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('delete_account_kept_title'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.hc.black)),
                const SizedBox(height: 10),
                _bullet(context, l.t('delete_account_kept_1')),
                _bullet(context, l.t('delete_account_kept_2')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.t('delete_account_active_service_note'),
            style: TextStyle(fontSize: 13, color: context.hc.grey),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l.t('delete_account_understand'),
              style: TextStyle(fontSize: 14, color: context.hc.black),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              // labelText, not hintText: a hint alone leaves the field with no
              // accessible name, so VoiceOver announced only "DELETE, text
              // field" with no idea what it was for.
              labelText: l
                  .t('delete_account_type_to_confirm')
                  .replaceFirst('{word}', _confirmWord(l)),
              hintText: _confirmWord(l),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit ? context.hc.error : context.hc.grey,
                foregroundColor: context.hc.onError,
              ),
              onPressed: canSubmit ? () => _confirm(l) : null,
              child: _isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.hc.onError),
                    )
                  : Text(l.t('delete_account_cta')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: TextStyle(color: context.hc.grey)),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: context.hc.grey)),
            ),
          ],
        ),
      );
}
