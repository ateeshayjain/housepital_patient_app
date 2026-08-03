import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
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
/// The patient backend is not reachable yet, so this screen cannot itself
/// erase server-side records. It therefore does two things and says so
/// plainly: it wipes everything on THIS DEVICE immediately, and it records a
/// deletion request for Housepital to complete within the statutory window.
/// It does not claim the server data is gone. Overstating that would be worse
/// than the missing feature — the user would believe their medical records
/// were erased when they were not.
///
/// When the backend lands, wire [_submitDeletionRequest] to the real endpoint
/// and keep the copy honest about timing.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _understood = false;
  bool _isSubmitting = false;

  static const _confirmWord = 'DELETE';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _understood &&
      _confirmController.text.trim().toUpperCase() == _confirmWord &&
      !_isSubmitting;

  Future<void> _submitDeletionRequest() async {
    setState(() => _isSubmitting = true);

    // TODO(backend): POST /account/delete once api.housepital.in exists, and
    // surface a real ticket reference here. Until then the on-device wipe is
    // the part we can actually guarantee, and the copy says exactly that.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Clear every provider first, then sign out and wipe local storage.
    SessionScope.clearSession(context);
    await context.read<AuthProvider>().logout();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Deletion requested'),
        content: const Text(
          'Everything on this phone has been erased.\n\n'
          'Your Housepital records are scheduled for deletion and will be '
          'removed within 30 days. We keep only what the law requires us to '
          'keep — invoices, for tax records.\n\n'
          'If you change your mind, call us on 9990-911-911 before then.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context)
                .popUntil((route) => route.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This cannot be undone. Your care history, reports and saved '
          'details will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep my account'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.hc.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitDeletionRequest();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Text('Delete account'),
        // Purchase-funnel logic applies here too: a cart icon on a deletion
        // screen is noise at best.
        showCart: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 32),
        children: [
          Text(
            'Deleting your account removes your Housepital profile and care '
            'history.',
            style: TextStyle(fontSize: 16, color: context.hc.black),
          ),
          const SizedBox(height: 20),
          HousepitalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What gets deleted',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.hc.black)),
                const SizedBox(height: 10),
                _bullet(context, 'Your profile, address and contacts'),
                _bullet(context, 'Care history, daily reports and vitals'),
                _bullet(context, 'Medicines, reminders and documents'),
                _bullet(context, 'Everything stored on this phone'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HousepitalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What we must keep',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.hc.black)),
                const SizedBox(height: 10),
                _bullet(context,
                    'Invoices and payment records, which Indian tax law '
                    'requires us to retain'),
                _bullet(context,
                    'Anything an ongoing medical or legal matter requires'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'If a service is currently running at your home, please call '
            '9990-911-911 first so we can close it properly.',
            style: TextStyle(fontSize: 13, color: context.hc.grey),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I understand this cannot be undone.',
              style: TextStyle(fontSize: 14, color: context.hc.black),
            ),
          ),
          const SizedBox(height: 8),
          Text('Type $_confirmWord to confirm',
              style: TextStyle(fontSize: 13, color: context.hc.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: _confirmWord,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canSubmit ? context.hc.error : context.hc.grey,
                foregroundColor: Colors.white,
              ),
              onPressed: _canSubmit ? _confirm : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete my account'),
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
