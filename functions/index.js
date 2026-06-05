// Housepital Patient App — AI Assistant Cloud Function (Sahayak brain)
//
// POST /assistant  { text, patient_id, role, locale }
//   → 200 { action, params, reply_text }
//
// This is the server-side "brain" the Flutter app calls. It runs Claude with
// the ANTHROPIC_API_KEY held as a Firebase secret — the key NEVER ships in the
// app binary. The model does natural-language understanding + intent routing +
// a Hinglish reply; the APP's executor then fetches data / performs the action
// (billing lookup, duty-day count, placing a call, navigation). So this
// function only needs the user's text + role to decide WHAT to do.
//
// Returns the exact shape the app's AssistantResponse.fromJson already parses,
// and NEVER throws to the caller — any failure degrades to a safe
// {action:"none"} response with a Hinglish message.

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Anthropic = require("@anthropic-ai/sdk");

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// Model is overridable via env so you can trade cost/latency without a code
// change. Default is the most capable model; Haiku/Sonnet are cheaper if you
// decide the routing task doesn't need Opus.
const MODEL = process.env.ANTHROPIC_MODEL || "claude-opus-4-8";

const DEGRADED = {
  action: "none",
  params: {},
  reply_text:
    "Connection issue — abhi jawab nahi mil paya. Thodi der baad try karein.",
};

// System prompt defines every action the app's executor can run, when to pick
// each, and the Hinglish reply style. Kept static so prompt caching can kick in
// once it crosses the cache minimum.
const SYSTEM_PROMPT = `You are "Sahayak", the in-app assistant for Housepital — a home-healthcare service in Delhi NCR. The user is a patient or their family member. They speak Hinglish (Hindi written in Roman script, mixed with English). Their on-duty staff and health manager are managed by the app.

Your job: read the user's message and decide ONE action for the app to perform, plus a short, warm Hinglish reply. You do NOT have the actual data — the app fetches it after you choose the action.

ACTIONS (pick exactly one):
- get_billing — user asks about their bill / dues / "iss mahine ka kitna hua". params: {}
- get_duty_days — how many days the staff came / attendance / "staff kitne din aaya". params: {}
- get_staff_info — who their staff / nurse / health manager is, or their name. params: {}
- place_call — user wants to call someone. params: { "target": "nurse" | "health_manager" | "sos" }. "sos" for emergencies/ambulance, "health_manager" for coordinator/supervisor, "nurse" otherwise.
- navigate — user wants to open a screen, OR wants to PAY a bill. params: { "route": "/cart" | "/services" | "/vitals" | "/report-history" | "/articles" | "/my-orders" | "/billing" }. Use "/billing" when the user wants to PAY / "bill bharna hai" / "payment karna hai" (the app opens the payment screen — you never charge anything yourself). "/articles" for care guides, "/vitals" for vitals, "/report-history" for reports, "/services" to browse, "/my-orders" for orders, "/cart" for cart.
- raise_concern — user reports a problem / complaint / "shikayat hai" / "staff theek se kaam nahi kar raha". params: { "description": "<short summary of the problem in the user's words>" }.
- book_service — user wants a NEW service / "nurse chahiye" / "caretaker book karo". params: { "service_category": "nursing" | "caretaker" | "physiotherapy" | "doctor" }.
- renew_service — user wants to renew/extend the current service / "service aage badhao" / "renew karo". params: { "service_category": "<category>" } (optional).
- replace_staff — user wants a different staff member / "nurse badlo" / "doosra caretaker chahiye". params: { "reason": "<why, in the user's words>" }.
- none — anything else (greetings, general questions, unclear). params: {}

IMPORTANT — for raise_concern, book_service, renew_service, replace_staff, and place_call: the app shows a CONFIRM card and does nothing until the user taps Confirm. So your reply_text should say you'll send/do it AFTER they confirm (e.g. "Confirm karein, phir bhej deta hoon").

reply_text rules:
- Always Hinglish, warm and concise (1-2 sentences).
- For data actions (billing/duty/staff), say you're fetching it (the app fills in real numbers).
- Never invent specific numbers, amounts, names, or dates — the app supplies those.
- For paying a bill, route to /billing via navigate; never imply you charged anything.`;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    action: {
      type: "string",
      enum: [
        "get_billing",
        "get_duty_days",
        "get_staff_info",
        "place_call",
        "navigate",
        "raise_concern",
        "book_service",
        "renew_service",
        "replace_staff",
        "none",
      ],
    },
    params: {
      type: "object",
      additionalProperties: false,
      properties: {
        target: { type: "string", enum: ["nurse", "health_manager", "sos"] },
        route: {
          type: "string",
          enum: [
            "/cart",
            "/services",
            "/vitals",
            "/report-history",
            "/articles",
            "/my-orders",
            "/billing",
          ],
        },
        service_category: {
          type: "string",
          enum: ["nursing", "caretaker", "physiotherapy", "doctor"],
        },
        description: { type: "string" },
        reason: { type: "string" },
      },
      required: [],
    },
    reply_text: { type: "string" },
  },
  required: ["action", "params", "reply_text"],
};

exports.assistant = onRequest(
  {
    secrets: [ANTHROPIC_API_KEY],
    region: "asia-south1",
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json(DEGRADED);
      return;
    }

    const body = req.body || {};
    const text = typeof body.text === "string" ? body.text.trim() : "";
    if (!text) {
      res.status(200).json({
        action: "none",
        params: {},
        reply_text: "Kuch likhiye ya mic dabaiye — main madad karunga.",
      });
      return;
    }

    const role = typeof body.role === "string" ? body.role : "primary_contact";
    const locale = typeof body.locale === "string" ? body.locale : "hi";

    try {
      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 512,
        thinking: { type: "disabled" },
        system: [
          {
            type: "text",
            text: SYSTEM_PROMPT,
            cache_control: { type: "ephemeral" },
          },
        ],
        output_config: {
          effort: "low",
          format: { type: "json_schema", schema: SCHEMA },
        },
        messages: [
          {
            role: "user",
            content: `User role: ${role}. Locale: ${locale}.\nUser said: ${text}`,
          },
        ],
      });

      // output_config.format guarantees the first text block is valid JSON.
      const block = response.content.find((b) => b.type === "text");
      if (!block) {
        res.status(200).json(DEGRADED);
        return;
      }
      const parsed = JSON.parse(block.text);

      res.status(200).json({
        action: parsed.action || "none",
        params: parsed.params || {},
        reply_text: parsed.reply_text || DEGRADED.reply_text,
      });
    } catch (err) {
      console.error("assistant error:", err);
      // Degrade gracefully — the app shows the Hinglish message, never crashes.
      res.status(200).json(DEGRADED);
    }
  }
);
