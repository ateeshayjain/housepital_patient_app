import 'package:flutter/foundation.dart';

import '../../models/assistant_models.dart';
import '../../services/i_api_service.dart';
import '../../utils/permissions.dart';

/// A phone contact the assistant can offer to call.
@immutable
class AssistantContact {
  final String name;
  final String phone;
  const AssistantContact({required this.name, required this.phone});
}

/// A side-effectful call the executor has prepared but NOT yet performed.
/// The caller dials only after the user confirms (confirm-before-act).
@immutable
class ConfirmableCall {
  final String name;
  final String phone;
  const ConfirmableCall({required this.name, required this.phone});
}

/// The outcome of executing an assistant response.
///
/// The executor is pure-ish: it reads via [IApiService] but performs NO
/// `Navigator`/`launchUrl` itself — those are the caller's job, gated on
/// the result type. This keeps the safety-critical logic fully unit-testable.
@immutable
sealed class ExecutorResult {
  const ExecutorResult();
}

/// A read-only answer to render (and optionally speak). No confirmation needed.
@immutable
class Answer extends ExecutorResult {
  final String text;
  const Answer(this.text);
}

/// A side-effectful action that must be hard-confirmed before it runs.
@immutable
class RequiresConfirmation extends ExecutorResult {
  final String text;
  final ConfirmableCall action;
  const RequiresConfirmation(this.text, this.action);
}

/// A navigation request (light confirm at the UI layer). The caller pushes
/// [route] only after a light inline confirm.
@immutable
class Navigate extends ExecutorResult {
  final String route;
  final String text;
  const Navigate(this.route, this.text);
}

/// The user's role is not permitted to take this action.
@immutable
class Blocked extends ExecutorResult {
  final String text;
  const Blocked(this.text);
}

/// Safe fallback — unknown action, malformed params, missing data, or an
/// upstream failure. No side effects.
@immutable
class Degraded extends ExecutorResult {
  final String text;
  const Degraded(this.text);
}

/// Maps an [AssistantResponse] to an [ExecutorResult].
///
/// Safety guarantees:
///   - side-effectful actions (place_call) are NEVER performed here; they
///     return [RequiresConfirmation] so the UI hard-confirms first.
///   - permission is gated via [canUserPerform] before any action is offered.
///   - malformed params / unknown actions / missing contacts degrade safely.
class AssistantExecutor {
  final IApiService api;
  final String role;
  final String patientId;
  final Map<String, AssistantContact> contacts;

  const AssistantExecutor({
    required this.api,
    required this.role,
    required this.patientId,
    required this.contacts,
  });

  /// Attendance statuses that count as the staff member being present.
  static const Set<String> _presentStatuses = {
    'checked_in',
    'checked_out',
    'late',
  };

  static const String _genericDegrade =
      'Main yeh abhi nahi kar paya — menu se try karein.';

  Future<ExecutorResult> execute(AssistantResponse r) async {
    switch (r.action) {
      case AssistantAction.getBilling:
        return _billing();
      case AssistantAction.getDutyDays:
        return _dutyDays();
      case AssistantAction.placeCall:
        return _placeCall(r.params);
      case AssistantAction.navigate:
        return _navigate(r.params, r.replyText);
      case AssistantAction.none:
        final msg = r.replyText.isNotEmpty ? r.replyText : _genericDegrade;
        return Degraded(msg);
    }
  }

  Future<ExecutorResult> _billing() async {
    try {
      final summary = await api.getBillingSummary(patientId);
      final amount = summary['amount_due'];
      if (amount == null) {
        return const Degraded('Bill ki jaankari abhi available nahi hai.');
      }
      return Answer('Iss waqt aapka outstanding bill ₹$amount hai.');
    } catch (e) {
      debugPrint('AssistantExecutor: billing failed: $e');
      return const Degraded(
          'Bill abhi load nahi ho paya — thodi der baad try karein.');
    }
  }

  Future<ExecutorResult> _dutyDays() async {
    try {
      final history = await api.getAttendanceHistory(patientId);
      final now = DateTime.now();
      final present = history
          .where((a) =>
              a.date.year == now.year &&
              a.date.month == now.month &&
              _presentStatuses.contains(a.status))
          .length;
      return Answer('Iss mahine staff $present din duty par aaya hai.');
    } catch (e) {
      debugPrint('AssistantExecutor: duty days failed: $e');
      return const Degraded(
          'Duty ki jaankari abhi load nahi ho paayi.');
    }
  }

  ExecutorResult _placeCall(Map<String, dynamic> params) {
    // Permission gate first — calling/managing staff is a managed action.
    if (!canUserPerform(role, UserAction.editPatient)) {
      return const Blocked(
          'Is action ki permission sirf primary contact ke paas hai.');
    }

    final target = params['target'];
    if (target is! String || target.isEmpty) {
      return const Degraded(
          'Kisko call karna hai yeh samajh nahi aaya — menu se try karein.');
    }

    final contact = contacts[target];
    if (contact == null || contact.phone.isEmpty) {
      // No phone on file → never dial, never crash.
      return const Degraded(
          'Iska phone number abhi available nahi hai.');
    }

    return RequiresConfirmation(
      '📞 ${contact.name} (${contact.phone}) ko call karein?',
      ConfirmableCall(name: contact.name, phone: contact.phone),
    );
  }

  ExecutorResult _navigate(Map<String, dynamic> params, String replyText) {
    final route = params['route'];
    if (route is! String || route.isEmpty || !route.startsWith('/')) {
      return const Degraded(
          'Kahan jaana hai yeh samajh nahi aaya — menu se try karein.');
    }
    final text = replyText.isNotEmpty ? replyText : 'Khol raha hoon…';
    return Navigate(route, text);
  }
}
