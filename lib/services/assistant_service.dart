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
    // Clinical guard runs BEFORE any routing — stub or cloud. See
    // [_clinicalGuard]. A medical emergency must never be handed to an intent
    // matcher, and must never wait on a network round-trip to an LLM.
    final urgent = _clinicalGuard(req.text);
    if (urgent != null) return urgent;

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

  // ── Clinical guard ────────────────────────────────────────────────────
  //
  // Unmistakable emergencies. Deliberately narrow: every term here should be
  // one a person only types when something is genuinely wrong, because the
  // cost of a false positive is an offered SOS call the user declines, while
  // the cost of a false negative is this app answering a medical emergency
  // with a task.
  static final RegExp _emergencyPattern = RegExp(
    r'\b('
    r'bleed|bleeding|khoon|blood loss|'
    r'chest pain|seene? \w* ?dard|chhati me\w* dard|heart attack|'
    r'saans nahi|saans nhi|not breathing|cant breathe|can.?t breathe|'
    r'breathless|dam ghut|'
    r'unconscious|behosh|behoshi|'
    r'seizure|fits|convulsion|jhatke|'
    r'stroke|paralysis|lakwa|'
    r'collapsed?|gir gay|gir gai|girr gay|had a fall|'
    r'emergency|ambulance|sos'
    r')\b',
  );

  // Softer clinical complaints. These are NOT emergencies and must not
  // escalate, but they are equally not tasks this app can perform — and an
  // assistant that answers "bukhar hai" with medical advice is practising
  // medicine.
  static final RegExp _symptomPattern = RegExp(
    r'\b('
    r'fever|bukhar|temperature|'
    r'vomit|ulti|nausea|'
    r'dizzy|chakkar|'
    r'pain|dard|'
    r'infection|swelling|sujan|'
    r'\bbp\b|sugar high|sugar low|'
    r'rash|wound|ghaav|'
    r'medicine (badl|change)|dose (badh|kam|change)'
    r')\b',
  );

  /// Intercepts anything that reads as a medical situation.
  ///
  /// WHY THIS COMES FIRST, AND WHY IT IS NOT PART OF THE MATCHER
  /// The intent matcher below is a list of unanchored `RegExp`s evaluated in
  /// order, and a short alternative captures every longer word containing it.
  /// The duty-days branch matched `din`, and "blee-din-g" contains "din" — so
  /// "bleeding ho raha hai" was answered with "Staff ki duty check kar raha
  /// hoon…". The word boundaries added below fix that specific collision, but
  /// they cannot fix the class of it: the next short token added to any branch
  /// will do the same thing to some other phrase.
  ///
  /// So the guard does not compete with the matcher — it pre-empts it. It also
  /// sits in [ask], not in [_stubResponse], so it applies on the cloud path
  /// too: an emergency must not depend on a network round-trip, and an LLM
  /// prompt is not a safety control.
  ///
  /// This app is not a clinical service and must not answer as one. The
  /// emergency branch offers the SOS call (confirmed, per the executor's
  /// contract — the SOS BUTTON itself stays unblocked and is unaffected by
  /// this file); the symptom branch hands the person to a human.
  AssistantResponse? _clinicalGuard(String text) {
    final t = text.toLowerCase();

    if (_emergencyPattern.hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.placeCall,
        params: {'target': 'sos'},
        replyText: 'Yeh emergency lag rahi hai. Main abhi emergency help ke '
            'liye call laga raha hoon — confirm karein. Agar turant madad '
            'chahiye, screen par laal SOS button dabayein ya 112 par call '
            'karein.',
      );
    }

    if (_symptomPattern.hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.none,
        params: {},
        replyText: 'Main medical salah nahi de sakta. Yeh apni nurse ya '
            'health manager ko turant batayein — "nurse ko call karo" boliye, '
            'ya emergency ho to SOS button dabayein.',
      );
    }

    return null;
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
    // Word boundaries are load-bearing: bare `din` matched "bleeding",
    // "reading" and "ordering". Never add an unanchored short alternative
    // to this list.
    if (RegExp(r'\bduty\b|\bdin\b|\bdino\b|\bdinon\b|\baaya\b|\battendance\b|\bhaazri\b')
        .hasMatch(t)) {
      return const AssistantResponse(
        action: AssistantAction.getDutyDays,
        params: {},
        replyText: 'Staff ki duty check kar raha hoon…',
      );
    }

    if (RegExp(r'\bbill|\bmahine\b|\bpaisa\b|\bpayment\b|\bdue\b|\boutstanding\b')
        .hasMatch(t)) {
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
