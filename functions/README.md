# Housepital Cloud Functions — AI Assistant (Sahayak)

This directory holds the **server-side AI brain** for the in-app assistant.
The Flutter app POSTs the user's message here; this function calls Claude with
a secret API key and returns a structured `{action, params, reply_text}` that
the app's executor acts on.

**Why server-side?** The LLM API key must never ship inside the app binary —
anyone could extract it and run up your bill. Holding it as a Firebase secret
here keeps it safe.

---

## What's already done (in code)

- `index.js` — the `assistant` HTTPS function: validates the request, calls
  Claude (`claude-opus-4-8` by default) with structured output + prompt
  caching, and degrades gracefully on any error.
- `firebase.json` — registers the `functions/` source.
- App wiring — `AssistantService` calls this endpoint when the app is built
  with `--dart-define=ASSISTANT_API_URL=<function-url>`; otherwise it uses the
  offline Hinglish stub.

## What you need to do (2 steps + build flag)

These need YOUR credentials, so they can't be done for you.

### 1. Get an Anthropic API key

Sign in at <https://console.anthropic.com> → API Keys → create one
(`sk-ant-...`). Note: this is a paid API; set a budget/spend limit in the
console.

### 2. Set the key as a secret and deploy

From the project root (`housepital_patient_app/`):

```bash
# one-time: install function deps
cd functions && npm install && cd ..

# point the CLI at the project (one-time)
firebase use housepital-patient

# store the API key as a secret (it is NOT committed anywhere)
firebase functions:secrets:set ANTHROPIC_API_KEY
#   → paste your sk-ant-... key when prompted

# deploy the function (needs the Blaze pay-as-you-go plan)
firebase deploy --only functions
```

`firebase deploy` prints the function URL, e.g.:

```
Function URL (assistant): https://asia-south1-housepital-patient.cloudfunctions.net/assistant
```

### 3. Build the app pointing at that URL

```bash
flutter run -d <device> \
  --dart-define=ASSISTANT_API_URL=https://asia-south1-housepital-patient.cloudfunctions.net/assistant \
  --dart-define=RAZORPAY_KEY=rzp_test_XXXXXXXXXX
```

With the flag set, the assistant is **AI-powered**. Without it, it falls back to
the offline keyword stub — so day-to-day local builds still work with no key.

---

## Optional: switch model for cost

The function defaults to `claude-opus-4-8`. To use a cheaper model, set an env
var on the function (e.g. in the Firebase console or via `firebase functions:config`):

```
ANTHROPIC_MODEL=claude-haiku-4-5    # cheapest
ANTHROPIC_MODEL=claude-sonnet-4-6   # mid
```

## Local testing (optional)

```bash
cd functions
# put your key in a local .env (gitignored) for the emulator
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env
firebase emulators:start --only functions
# → test the local URL it prints, then point the app at it
```

## Cost notes

- Cloud Functions: free tier covers ~2M invocations/month; beyond that, pennies.
- Claude API: billed per token. The assistant prompt is small (~a few hundred
  tokens in, ~100 out per turn). Opus is the priciest; Haiku is ~5× cheaper.
  Prompt caching on the system prompt reduces repeat-call cost once warm.
