import 'package:flutter/foundation.dart';

import '../../models/assistant_models.dart';
import '../../services/i_api_service.dart';
import '../../utils/permissions.dart';
import 'assistant_local_actions.dart';

/// A phone contact the assistant can offer to call.
@immutable
class AssistantContact {
  final String name;
  final String phone;
  const AssistantContact({required this.name, required this.phone});
}

/// Kinds of state-changing submission the assistant can perform on confirm.
enum ConfirmedKind { raiseConcern, bookService, renewService, replaceStaff }

/// A side-effectful action the executor has prepared but NOT yet performed.
/// The provider executes it only after the user confirms (confirm-before-act).
@immutable
sealed class PendingAction {
  const PendingAction();

  /// One-line summary rendered on the confirm card.
  String get label;
}

/// A phone call to place on confirm.
@immutable
class CallAction extends PendingAction {
  final String name;
  final String phone;
  const CallAction({required this.name, required this.phone});

  @override
  String get label => 'Call $name · $phone';
}

/// An API submission to perform on confirm (concern, booking, renewal,
/// replacement). [data] carries the params the handler needs.
@immutable
class SubmitAction extends PendingAction {
  final ConfirmedKind kind;
  @override
  final String label;
  final Map<String, String> data;
  const SubmitAction({
    required this.kind,
    required this.label,
    this.data = const {},
  });
}

/// Backward-compatible alias for the call variant.
typedef ConfirmableCall = CallAction;

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
  final PendingAction action;
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

  /// Active deployment id — needed to request a staff replacement.
  final String? deploymentId;

  /// Local (offline / demo-mode) action sink. When non-null, add-to-cart is
  /// performed against the real local cart, and confirmed service requests
  /// fall back to a local quote-pending order when the backend is
  /// unreachable — the app is demo-first, so demoed actions must WORK
  /// offline, never end in a fake "try again later".
  final AssistantLocalActions? local;

  const AssistantExecutor({
    required this.api,
    required this.role,
    required this.patientId,
    required this.contacts,
    this.deploymentId,
    this.local,
  });

  /// How long to wait for the backend before falling back to the local
  /// demo path. Keeps the thinking spinner short when offline.
  static const Duration _apiTimeout = Duration(seconds: 4);

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
      case AssistantAction.getStaffInfo:
        return _staffInfo();
      case AssistantAction.raiseConcern:
        return _prepareRaiseConcern(r.params, r.replyText);
      case AssistantAction.bookService:
        return _prepareBookService(r.params, r.replyText);
      case AssistantAction.renewService:
        return _prepareRenewService(r.params, r.replyText);
      case AssistantAction.replaceStaff:
        return _prepareReplaceStaff(r.params, r.replyText);
      case AssistantAction.addToCart:
        return _addToCart(r.params);
      case AssistantAction.none:
        final msg = r.replyText.isNotEmpty ? r.replyText : _genericDegrade;
        return Degraded(msg);
    }
  }

  // ── State-changing actions: prepare (confirm-first), then perform ─────────
  // Each "prepare" returns RequiresConfirmation(SubmitAction). Nothing hits the
  // API until the provider calls [performConfirmed] after the user taps Confirm.

  static const String _permDenied =
      'Is action ki permission sirf primary contact ke paas hai.';

  ExecutorResult _prepareRaiseConcern(
      Map<String, dynamic> params, String reply) {
    if (!canUserPerform(role, UserAction.raiseConcern)) {
      return const Blocked(_permDenied);
    }
    final desc = (params['description'] as String?)?.trim() ?? '';
    if (desc.isEmpty) {
      return const Degraded(
          'Concern kis baare mein hai, thoda bata dijiye?');
    }
    return RequiresConfirmation(
      reply.isNotEmpty ? reply : 'Care team ko yeh concern bhej dun?',
      SubmitAction(
        kind: ConfirmedKind.raiseConcern,
        label: '📝 Concern bhejein: "$desc"',
        data: {'description': desc},
      ),
    );
  }

  ExecutorResult _prepareBookService(
      Map<String, dynamic> params, String reply) {
    if (!canUserPerform(role, UserAction.book) &&
        !canUserPerform(role, UserAction.requestBooking)) {
      return const Blocked(_permDenied);
    }
    final category = (params['service_category'] as String?)?.trim() ?? '';
    if (category.isEmpty) {
      return const Degraded('Kaunsi service chahiye — nurse, caretaker, physio?');
    }
    return RequiresConfirmation(
      reply.isNotEmpty
          ? reply
          : 'Care team ko $category ke liye request bhej dun?',
      SubmitAction(
        kind: ConfirmedKind.bookService,
        label: '🩺 $category ke liye service request bhejein',
        data: {'service_category': category},
      ),
    );
  }

  ExecutorResult _prepareRenewService(
      Map<String, dynamic> params, String reply) {
    if (!canUserPerform(role, UserAction.book) &&
        !canUserPerform(role, UserAction.requestBooking)) {
      return const Blocked(_permDenied);
    }
    final category = (params['service_category'] as String?)?.trim() ??
        'current service';
    return RequiresConfirmation(
      reply.isNotEmpty
          ? reply
          : 'Service renew/extend karne ki request bhej dun?',
      SubmitAction(
        kind: ConfirmedKind.renewService,
        label: '🔁 $category renew/extend karne ki request bhejein',
        data: {'service_category': category},
      ),
    );
  }

  ExecutorResult _prepareReplaceStaff(
      Map<String, dynamic> params, String reply) {
    if (!canUserPerform(role, UserAction.raiseConcern)) {
      return const Blocked(_permDenied);
    }
    if (deploymentId == null || deploymentId!.isEmpty) {
      return const Degraded(
          'Abhi koi active staff nahi hai jiske liye replacement maang sakein.');
    }
    final reason = (params['reason'] as String?)?.trim() ?? 'Not specified';
    return RequiresConfirmation(
      reply.isNotEmpty ? reply : 'Staff replacement ki request bhej dun?',
      SubmitAction(
        kind: ConfirmedKind.replaceStaff,
        label: '🔄 Staff replacement request bhejein',
        data: {'reason': reason},
      ),
    );
  }

  // ── add_to_cart: a real local cart add (reversible → no hard confirm) ─────

  /// Searches the equipment catalog for the user's item keywords and adds the
  /// best match to the local cart — the SAME add the catalog ADD button does.
  /// Honesty rules:
  ///   - price-on-request items are NOT added with a fabricated price; the
  ///     user is pointed at the Reserve flow.
  ///   - no match → say so plainly, never pretend.
  Future<ExecutorResult> _addToCart(Map<String, dynamic> params) async {
    if (!canUserPerform(role, UserAction.book) &&
        !canUserPerform(role, UserAction.requestBooking)) {
      return const Blocked(_permDenied);
    }
    final query = (params['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const Degraded(
          'Kaunsa item cart mein daalna hai? Jaise: "nebulizer cart mein daal do".');
    }
    final sink = local;
    if (sink == null) {
      // No local cart wired (shouldn't happen in the app) — be plain about it.
      return const Degraded(
          'Cart mein add yahan se nahi ho paa raha — Services > Equipment se add karein.');
    }
    try {
      final item = await sink.findEquipment(query);
      if (item == null) {
        return Degraded(
            '"$query" equipment catalog mein nahi mila — Services > Equipment mein dekh sakte hain.');
      }
      final price = item.price?.toInt();
      if (price == null || price <= 0) {
        // Price-on-request → Reserve flow; never fabricate a price.
        return Answer(
            '${item.name} ka price request par confirm hota hai — Services > Equipment se Reserve karein, team price bata degi.');
      }
      sink.addEquipmentToCart(item);
      return Answer(
          '${item.name} cart mein add kar diya — ₹$price. Checkout Services > Cart se karein.');
    } catch (e) {
      debugPrint('AssistantExecutor: addToCart failed: $e');
      return const Degraded(
          'Cart mein add nahi ho paya — Services > Equipment se try karein.');
    }
  }

  /// Performs a previously-confirmed [SubmitAction]. Called by the provider
  /// only after the user taps Confirm (or types haan/yes). Never throws.
  ///
  /// Demo-first contract: bookings/renewals MUST succeed offline — when the
  /// backend call fails, the same local quote-pending request the normal
  /// booking flow creates is recorded via [AssistantLocalActions]. Actions
  /// with no local equivalent (concern, replacement) reply with an honest
  /// capability message that points at a working alternative — never a
  /// fake "try again later".
  Future<ExecutorResult> performConfirmed(SubmitAction action) async {
    switch (action.kind) {
      case ConfirmedKind.raiseConcern:
        try {
          await api
              .raiseConcern(
                patientId: patientId,
                category: 'general',
                description: action.data['description'] ?? '',
                urgency: 'medium',
              )
              .timeout(_apiTimeout);
          return const Answer(
              'Aapka concern care team ko bhej diya gaya hai — woh jaldi sampark karenge.');
        } catch (e) {
          debugPrint('AssistantExecutor: raiseConcern failed: $e');
          // No local concern store exists — be honest, point to what works.
          return const Degraded(
              'Concern abhi yahan se record nahi ho paya. Settings > Raise a Concern se bhej sakte hain, ya health manager ko call karne ke liye "call karo" boliye.');
        }
      case ConfirmedKind.bookService:
        return _submitServiceRequest(
          category: action.data['service_category'] ?? '',
          renewal: false,
        );
      case ConfirmedKind.renewService:
        return _submitServiceRequest(
          category: action.data['service_category'] ?? '',
          renewal: true,
        );
      case ConfirmedKind.replaceStaff:
        try {
          await api
              .requestReplacement(
                deploymentId!,
                action.data['reason'] ?? 'Not specified',
                const {'source': 'assistant'},
              )
              .timeout(_apiTimeout);
          return const Answer(
              'Replacement request bhej di gayi hai — care team jaldi arrange karegi.');
        } catch (e) {
          debugPrint('AssistantExecutor: replaceStaff failed: $e');
          // No local replacement store — honest capability message.
          return const Degraded(
              'Replacement request abhi yahan se nahi ja paayi. Health manager ko call karke turant arrange kar sakte hain — "call karo" boliye.');
        }
    }
  }

  /// Books / renews a service: backend first (short timeout), then the local
  /// demo path — a quote-pending OrdersProvider order, the same shape the
  /// quote-first booking flow creates.
  ///
  /// NOTE: this used to say "no price is ever shown (manpower rule)". That
  /// rule is DEAD — manpower prices ARE shown and directly bookable (owner,
  /// re-confirmed 2026-06-11). Quote-pending applies only to items that
  /// genuinely lack a price (`price == null || price == 0`), never by
  /// category.
  Future<ExecutorResult> _submitServiceRequest({
    required String category,
    required bool renewal,
  }) async {
    try {
      await api
          .createAssessmentRequest(
            patientId: patientId,
            serviceCategory: category,
            responses: {
              'source': 'assistant',
              if (renewal) 'type': 'renewal',
            },
          )
          .timeout(_apiTimeout);
      return Answer(renewal
          ? 'Renewal request bhej di gayi hai — care team confirm karegi.'
          : 'Service request bhej di gayi hai — care team aapko call karegi.');
    } catch (e) {
      debugPrint('AssistantExecutor: createAssessmentRequest failed: $e');
      final sink = local;
      if (sink != null) {
        try {
          final bookingNumber =
              sink.createServiceRequest(category: category, renewal: renewal);
          return Answer(renewal
              ? 'Renewal request record ho gayi hai ($bookingNumber) — care team call karke price aur schedule confirm karegi. My Orders mein dekh sakte hain.'
              : 'Request bhej di gayi hai ($bookingNumber) — care team call karke price aur schedule confirm karegi. My Orders mein dekh sakte hain.');
        } catch (e2) {
          debugPrint('AssistantExecutor: local booking fallback failed: $e2');
        }
      }
      return const Degraded(
          'Request abhi nahi ja paayi — Services tab se book kar sakte hain, ya health manager ko call karein.');
    }
  }

  ExecutorResult _staffInfo() {
    // Build a readable list of the assigned contacts (nurse, health manager).
    final parts = <String>[];
    final nurse = contacts['nurse'];
    if (nurse != null && nurse.name.isNotEmpty) {
      parts.add('Nurse: ${nurse.name}');
    }
    final hm = contacts['health_manager'];
    if (hm != null && hm.name.isNotEmpty) {
      parts.add('Health Manager: ${hm.name}');
    }
    if (parts.isEmpty) {
      return const Degraded('Staff ki jaankari abhi available nahi hai.');
    }
    return Answer(parts.join('\n'));
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
      // NOTE: reads page 1 of attendance only. A full month fits one page in
      // practice (≤31 rows), but if the backend page size ever drops below a
      // month this would undercount — switch to a paginated fetch then. This
      // is a conversational convenience, not the billing source of truth.
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
    final target = params['target'];
    if (target is! String || target.isEmpty) {
      return const Degraded(
          'Kisko call karna hai yeh samajh nahi aaya — menu se try karein.');
    }

    // Placing a call is not a managed/destructive action — any role with app
    // access may call the care team, and an SOS/emergency call is NEVER gated.
    // (Confirm-before-dial below is the safety control.) Only block if the role
    // somehow lacks even view access, and never for sos.
    if (target != 'sos' && !canUserPerform(role, UserAction.view)) {
      return const Blocked(
          'Is action ki permission abhi available nahi hai.');
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
