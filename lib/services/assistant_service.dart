import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/assistant_models.dart';

/// Client for the assistant "brain".
///
/// In production it POSTs the user's request to the backend `/assistant`
/// endpoint, which calls the LLM and returns a structured
/// `{action, params, reply_text}`.
///
/// The backend endpoint does NOT exist yet, so [useStub] defaults to `true`:
/// a lightweight Hinglish keyword matcher drives the four known intents
/// (billing, duty-days, call, navigate) so the feature works end-to-end today.
/// Flip [useStub] to `false` (or env-flag it) once the endpoint ships.
///
/// This service NEVER throws to the caller — any network/parse failure
/// degrades to a safe [AssistantAction.none] response with a Hinglish message.
class AssistantService {
  final bool useStub;
  final http.Client _client;
  final String baseUrl;

  AssistantService({
    this.useStub = true,
    http.Client? client,
    this.baseUrl = AppConstants.apiBaseUrl,
  }) : _client = client ?? http.Client();

  static const String _degradedMessage =
      'Connection issue — abhi jawab nahi mil paya. Thodi der baad try karein.';
  static const String _unmatchedMessage =
      'Main yeh abhi nahi samajh paya — menu se try karein.';

  Future<AssistantResponse> ask(AssistantRequest req) async {
    if (useStub) {
      return _stubResponse(req.text);
    }
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/assistant'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(req.toJson()),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('AssistantService: /assistant returned ${res.statusCode}');
        return AssistantResponse.degraded(_degradedMessage);
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('AssistantService: unexpected response shape');
        return AssistantResponse.degraded(_degradedMessage);
      }
      return AssistantResponse.fromJson(decoded);
    } catch (e) {
      debugPrint('AssistantService: ask failed: $e');
      return AssistantResponse.degraded(_degradedMessage);
    }
  }

  /// Hinglish keyword matcher for the four known intents.
  AssistantResponse _stubResponse(String text) {
    final t = text.toLowerCase();

    // Order matters: call/navigate before billing/duty so phrases like
    // "billing kholo" route to navigate only when no bill-amount intent.
    if (RegExp(r'call|phone|baat|dial').hasMatch(t)) {
      final target = RegExp(r'nurse|nars').hasMatch(t)
          ? 'nurse'
          : RegExp(r'sos|emergency|ambulance').hasMatch(t)
              ? 'sos'
              : 'health_manager';
      return AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': target},
        replyText: 'Theek hai, call lagaane se pehle confirm karein.',
      );
    }

    // Duty-days is checked before billing because phrases like
    // "staff kitne din aaya iss mahine" contain the generic "mahine"
    // (month) keyword too — the more specific duty intent should win.
    if (RegExp(r'duty|din|aaya|attendance|haazri').hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.getDutyDays,
        params: {},
        replyText: 'Staff ki duty check kar raha hoon…',
      );
    }

    if (RegExp(r'bill|mahine|paisa|payment|due|outstanding').hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.getBilling,
        params: {},
        replyText: 'Ek second, aapka bill check kar raha hoon…',
      );
    }

    if (RegExp(r'report|cart|services|kholo|dikhao|khol').hasMatch(t)) {
      final route = RegExp(r'cart').hasMatch(t)
          ? '/cart'
          : RegExp(r'services|service').hasMatch(t)
              ? '/services'
              : RegExp(r'vital').hasMatch(t)
                  ? '/vitals'
                  : '/report-history';
      return AssistantResponse(
        action: AssistantAction.navigate,
        params: {'route': route},
        replyText: 'Khol raha hoon…',
      );
    }

    return AssistantResponse.degraded(_unmatchedMessage);
  }
}
