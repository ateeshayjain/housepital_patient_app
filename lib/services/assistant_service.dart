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

  /// Full URL of the assistant endpoint (the Firebase Cloud Function). When
  /// non-null it is used directly; otherwise the service POSTs to
  /// `$baseUrl/assistant`. Lets the app point at the deployed function without
  /// assuming a path layout.
  final String? assistantUrl;

  AssistantService({
    this.useStub = true,
    http.Client? client,
    this.baseUrl = AppConstants.apiBaseUrl,
    this.assistantUrl,
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
      final endpoint = assistantUrl ?? '$baseUrl/assistant';
      final res = await _client.post(
        Uri.parse(endpoint),
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

    // Staff-info queries: "staff ka naam kya hai", "nurse kaun hai",
    // "mera doctor kaun hai", "staff ka naan" etc.
    // Checked first because some phrases also contain other keywords.
    if (RegExp(r'naam|naan|name|kaun|kon|staff.*kya|kya.*staff|nurse.*kaun|doctor.*kaun')
        .hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.getStaffInfo,
        params: {},
        replyText: 'Aapke staff ki jaankari nikal raha hoon…',
      );
    }

    // ── State-changing actions (checked before call/billing) ──────────────
    // Replace staff: "nurse badlo", "doosra caretaker", "change staff".
    if (RegExp(r'badl|replace|change.*(staff|nurse|caretaker)|doosr|different (nurse|caretaker|staff)')
        .hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.replaceStaff,
        params: {'reason': 'Requested via assistant'},
        replyText: 'Staff replacement request bhej dun? Confirm karein.',
      );
    }

    // Raise a concern / complaint.
    if (RegExp(r'concern|complaint|shikayat|problem|issue|kharab|galat')
        .hasMatch(t)) {
      return AssistantResponse(
        action: AssistantAction.raiseConcern,
        params: {'description': text.trim()},
        replyText: 'Yeh concern care team ko bhej dun? Confirm karein.',
      );
    }

    // Renew / extend the current service.
    if (RegExp(r'renew|extend|badha|aage badha|continue').hasMatch(t)) {
      final cat = _serviceCategory(t);
      return AssistantResponse(
        action: AssistantAction.renewService,
        params: cat == null ? const {} : {'service_category': cat},
        replyText: 'Service renew karne ki request bhej dun? Confirm karein.',
      );
    }

    // Add an equipment item to the cart: "add a nebulizer to my cart",
    // "wheelchair cart mein daal do". Requires BOTH a cart mention and an
    // add-verb so "cart kholo / cart dikhao" still routes to navigate below.
    if (RegExp(r'cart').hasMatch(t) &&
        RegExp(r'\badd\b|daal|\bdaal\b|\bdal\b|dalo|rakho|rakh do|kharid|\bbuy\b|le lo|lelo')
            .hasMatch(t)) {
      final query = _extractItemQuery(t);
      if (query.isNotEmpty) {
        return AssistantResponse(
          action: AssistantAction.addToCart,
          params: {'query': query},
          replyText: 'Cart mein add kar raha hoon…',
        );
      }
      // "cart mein daal do" with no item named — ask, don't guess.
      return AssistantResponse.degraded(
          'Kaunsa item cart mein daalna hai? Jaise: "nebulizer cart mein daal do".');
    }

    // Book / request a new service.
    if (RegExp(r'book|chahiye|naya|new (nurse|caretaker|physio)|service')
        .hasMatch(t)) {
      final cat = _serviceCategory(t);
      if (cat != null) {
        return AssistantResponse(
          action: AssistantAction.bookService,
          params: {'service_category': cat},
          replyText: '$cat ke liye request bhej dun? Confirm karein.',
        );
      }
    }

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

  /// Strips add-to-cart filler words (English + Hinglish) so only the item
  /// keywords remain: "add a nebulizer to my cart" → "nebulizer".
  String _extractItemQuery(String t) {
    const stop = {
      'add', 'a', 'an', 'the', 'to', 'my', 'in', 'into', 'cart', 'mein',
      'me', 'please', 'plz', 'daal', 'dal', 'dalo', 'do', 'kar', 'karo',
      'rakho', 'rakh', 'de', 'ek', 'one', 'buy', 'kharid', 'kharido', 'lo',
      'le', 'lelo', 'aur', 'and', 'order', 'bhai', 'ji', 'mere', 'liye',
    };
    final words = t
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty && !stop.contains(w));
    return words.join(' ');
  }

  /// Extracts a service category from Hinglish text, or null if none found.
  String? _serviceCategory(String t) {
    if (RegExp(r'nurse|nars|nursing').hasMatch(t)) return 'nursing';
    if (RegExp(r'caretaker|attendant|caregiver').hasMatch(t)) return 'caretaker';
    if (RegExp(r'physio|physiotherap').hasMatch(t)) return 'physiotherapy';
    if (RegExp(r'doctor|consult').hasMatch(t)) return 'doctor';
    return null;
  }
}
