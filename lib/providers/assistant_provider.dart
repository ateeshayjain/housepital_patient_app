import 'package:flutter/foundation.dart';

import '../models/assistant_models.dart';
import '../services/assistant_service.dart';
import '../services/voice_service.dart';
import '../screens/assistant/assistant_executor.dart';

/// Orchestrates the assistant conversation: takes user text, asks the brain
/// ([AssistantService]), runs the result through the safety-critical
/// [AssistantExecutor], and updates the chat UI state.
///
/// Side effects (dialing a number, navigating) are NOT performed here — the
/// provider exposes [onPlaceCall] / [onNavigate] callbacks the UI wires up, so
/// the provider stays unit-testable and the confirm-before-act contract holds:
/// a `place_call` becomes a [pendingConfirmation] and only fires [onPlaceCall]
/// after [confirmPending].
class AssistantProvider extends ChangeNotifier {
  final AssistantService _service;
  final AssistantExecutor _executor;
  final VoiceService _voice;
  final String _patientId;
  final String _role;
  final String _locale;

  AssistantProvider({
    required AssistantService service,
    required AssistantExecutor executor,
    required VoiceService voice,
    required String patientId,
    required String role,
    required String locale,
  })  : _service = service,
        _executor = executor,
        _voice = voice,
        _patientId = patientId,
        _role = role,
        _locale = locale;

  // ── Callbacks wired by the UI (side effects live in the widget layer) ──
  void Function(String phone)? onPlaceCall;
  void Function(String route)? onNavigate;

  // ── State ──────────────────────────────────────────────────────────────
  final List<AssistantMessage> _messages = [];
  List<AssistantMessage> get messages => List.unmodifiable(_messages);

  PendingAction? _pendingConfirmation;
  PendingAction? get pendingConfirmation => _pendingConfirmation;

  bool _isThinking = false;
  bool get isThinking => _isThinking;

  bool _isListening = false;
  bool get isListening => _isListening;

  // Typed confirmation: when an action is pending, a short "haan / yes /
  // confirm" must execute it (the Confirm button is not the only path), and
  // a "nahi / cancel" must cancel it. Matched only against the WHOLE short
  // message so a fresh request ("nahi, doctor bulao") is not swallowed.
  static final RegExp _yesWords = RegExp(
      r'^(haa?n?|hanji|ji|ji haan|yes|yep|yeah|y|ok|okay|theek(\s+hai)?|thik(\s+hai)?|confirm(\s+karo)?|kar\s+do|karo|bhej\s+do|bhejo|done|sure|pakka)[.!]*$');
  static final RegExp _noWords = RegExp(
      r'^(nahi+n?|na|no|nope|cancel|mat\s+(karo|bhejo)|rehne\s+do|rahne\s+do|ruko|stop)[.!]*$');

  /// Handle a typed (or transcribed) user message end-to-end.
  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // A pending confirm answered in words — execute or cancel, don't re-parse.
    if (_pendingConfirmation != null) {
      final lower = trimmed.toLowerCase();
      if (_yesWords.hasMatch(lower)) {
        _messages.add(AssistantMessage.user(trimmed));
        notifyListeners();
        await confirmPending();
        return;
      }
      if (_noWords.hasMatch(lower)) {
        _messages.add(AssistantMessage.user(trimmed));
        _pendingConfirmation = null;
        const msg = 'Theek hai — cancel kar diya.';
        _messages.add(AssistantMessage.assistant(msg));
        notifyListeners();
        await _voice.speak(msg);
        return;
      }
    }

    _messages.add(AssistantMessage.user(trimmed));
    _pendingConfirmation = null;
    _isThinking = true;
    notifyListeners();

    final response = await _service.ask(AssistantRequest(
      text: trimmed,
      patientId: _patientId,
      role: _role,
      locale: _locale,
    ));

    final result = await _executor.execute(response);
    _isThinking = false;

    switch (result) {
      case Answer(:final text):
        _messages.add(AssistantMessage.assistant(text));
        await _voice.speak(text);
      case RequiresConfirmation(:final text, :final action):
        _pendingConfirmation = action;
        _messages.add(AssistantMessage.assistant(text, pendingAction: response));
        await _voice.speak(text);
      case Navigate(:final route, :final text):
        _messages.add(AssistantMessage.assistant(text));
        await _voice.speak(text);
        onNavigate?.call(route);
      case Blocked(:final text):
        _messages.add(AssistantMessage.assistant(text));
        await _voice.speak(text);
      case Degraded(:final text):
        _messages.add(AssistantMessage.assistant(text));
        await _voice.speak(text);
    }

    notifyListeners();
  }

  /// User confirmed a pending side-effectful action. Dispatches by type:
  /// a [CallAction] dials via the UI callback; a [SubmitAction] is performed
  /// against the API by the executor and its result is shown in the chat.
  Future<void> confirmPending() async {
    final pending = _pendingConfirmation;
    if (pending == null) return;
    _pendingConfirmation = null;

    switch (pending) {
      case CallAction(:final phone):
        onPlaceCall?.call(phone);
        notifyListeners();
      case SubmitAction():
        _isThinking = true;
        notifyListeners();
        final result = await _executor.performConfirmed(pending);
        _isThinking = false;
        final text = switch (result) {
          Answer(:final text) => text,
          Degraded(:final text) => text,
          Blocked(:final text) => text,
          _ => 'Done.',
        };
        _messages.add(AssistantMessage.assistant(text));
        await _voice.speak(text);
        notifyListeners();
    }
  }

  void cancelPending() {
    if (_pendingConfirmation == null) return;
    _pendingConfirmation = null;
    notifyListeners();
  }

  // ── Voice ────────────────────────────────────────────────────────────────
  Future<void> startVoice() async {
    final ok = await _voice.initSpeech();
    if (!ok) return;
    _isListening = true;
    notifyListeners();
    await _voice.listen((text) {
      if (text.isNotEmpty) {
        sendText(text);
      }
    });
  }

  Future<void> stopVoice() async {
    await _voice.stopListening();
    _isListening = false;
    notifyListeners();
  }
  /// Clears the conversation. The assistant transcript is a symptom log — the
  /// patient describes what is wrong with them in it — so it is PHI and must
  /// not survive a patient switch or a logout.
  void clearPatientScopedData() {
    _messages.clear();
    _pendingConfirmation = null;
    _isThinking = false;
    notifyListeners();
  }

}
