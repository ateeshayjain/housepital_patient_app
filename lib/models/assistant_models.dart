/// Models for the voice + text Hinglish AI assistant.
///
/// Safety note: parsing is deliberately tolerant. The backend (or stub) may
/// return an action the client does not know about, malformed params, or a
/// missing reply. None of these should ever throw to the UI — instead they
/// degrade to a safe [AssistantAction.none] / empty params / empty reply, and
/// the tool executor (the safety-critical layer) decides what is safe to do.
library;

/// The set of actions the assistant can map a response to.
enum AssistantAction {
  getBilling,
  getDutyDays,
  placeCall,
  navigate,

  /// Returns the name and role of the currently-assigned staff member from
  /// the active deployment. Read-only — no side effects, no confirmation.
  getStaffInfo,

  // ── State-changing actions (each hard-confirmed before it runs) ──────────
  /// File a concern / complaint with the care team. params: {description}.
  raiseConcern,

  /// Request a new service (assessment request — care team calls back).
  /// params: {service_category}.
  bookService,

  /// Request renewal / extension of the current service.
  /// params: {service_category?}.
  renewService,

  /// Request a replacement for the currently-assigned staff member.
  /// params: {reason?}.
  replaceStaff,

  /// Safe fallback — unknown or unparseable action. The executor must do
  /// nothing side-effectful for this.
  none;

  /// Map a backend action string to an [AssistantAction].
  /// Unknown / null / empty strings degrade to [AssistantAction.none].
  static AssistantAction fromString(String? raw) {
    switch (raw) {
      case 'get_billing':
        return AssistantAction.getBilling;
      case 'get_duty_days':
        return AssistantAction.getDutyDays;
      case 'place_call':
        return AssistantAction.placeCall;
      case 'navigate':
        return AssistantAction.navigate;
      case 'get_staff_info':
        return AssistantAction.getStaffInfo;
      case 'raise_concern':
        return AssistantAction.raiseConcern;
      case 'book_service':
        return AssistantAction.bookService;
      case 'renew_service':
        return AssistantAction.renewService;
      case 'replace_staff':
        return AssistantAction.replaceStaff;
      default:
        return AssistantAction.none;
    }
  }
}

/// A structured response from the assistant brain (backend LLM or stub).
class AssistantResponse {
  final AssistantAction action;
  final Map<String, dynamic> params;
  final String replyText;

  const AssistantResponse({
    required this.action,
    required this.params,
    required this.replyText,
  });

  /// Tolerant deserializer — never throws on malformed input.
  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    final rawParams = json['params'];
    final params = rawParams is Map
        ? Map<String, dynamic>.from(rawParams)
        : <String, dynamic>{};
    final reply = json['reply_text'];
    return AssistantResponse(
      action: AssistantAction.fromString(json['action'] as String?),
      params: params,
      replyText: reply is String ? reply : '',
    );
  }

  /// A safe degraded response that takes no action.
  factory AssistantResponse.degraded(String message) => AssistantResponse(
        action: AssistantAction.none,
        params: const {},
        replyText: message,
      );
}

/// A request sent to the assistant brain.
class AssistantRequest {
  final String text;
  final String patientId;
  final String role;
  final String locale;

  const AssistantRequest({
    required this.text,
    required this.patientId,
    required this.role,
    required this.locale,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'patient_id': patientId,
        'role': role,
        'locale': locale,
      };
}

/// A single chat bubble in the assistant conversation.
class AssistantMessage {
  final bool isUser;
  final String text;

  /// When non-null, this assistant message is awaiting user confirmation
  /// before a side-effectful action runs (e.g. place_call / navigate).
  final AssistantResponse? pendingAction;

  const AssistantMessage({
    required this.isUser,
    required this.text,
    this.pendingAction,
  });

  factory AssistantMessage.user(String text) =>
      AssistantMessage(isUser: true, text: text);

  factory AssistantMessage.assistant(String text,
          {AssistantResponse? pendingAction}) =>
      AssistantMessage(isUser: false, text: text, pendingAction: pendingAction);
}
