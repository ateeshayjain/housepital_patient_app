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
- get_billing — user asks about their bill / dues / payment / "iss mahine ka kitna hua". params: {}
- get_duty_days — user asks how many days the staff came / attendance / "staff kitne din aaya". params: {}
- get_staff_info — user asks who their staff / nurse / health manager is, or their name. params: {}
- place_call — user wants to call someone. params: { "target": "nurse" | "health_manager" | "sos" }. Use "sos" for emergencies/ambulance, "health_manager" for the coordinator/supervisor, "nurse" otherwise.
- navigate — user wants to open a screen. params: { "route": "/cart" | "/services" | "/vitals" | "/report-history" | "/articles" | "/my-orders" }. Use "/articles" for care guides/education, "/vitals" for vitals, "/report-history" for daily reports, "/services" to book/browse services, "/my-orders" for orders, "/cart" for the cart.
- none — anything else (greetings, general questions, unclear requests). params: {}

reply_text rules:
- Always Hinglish, warm and concise (1-2 sentences).
- For place_call, say you'll connect them and that they'll confirm first.
- For data actions (billing/duty/staff), say you're fetching it (the app fills in the real numbers).
- For none, answer helpfully if it's a general question, or gently guide them to use the menu.
- Never invent specific numbers, amounts, names, or dates — the app supplies those.`;

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
          ],
        },
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
