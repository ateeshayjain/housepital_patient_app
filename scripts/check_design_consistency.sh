#!/usr/bin/env bash
# scripts/check_design_consistency.sh
#
# Static design-consistency gate. Fails (exit 1) if banned patterns reappear in
# lib/screens/ after the app-wide consistency pass, so the inconsistencies we
# just removed can't silently creep back in via future hand-rolled widgets.
#
# Scope: lib/screens/ only. theme.dart and daimaa_theme.dart legitimately define
# raw colors (they're the token source / sub-brand), so they are NOT scanned.
#
# Run locally:  bash scripts/check_design_consistency.sh
# CI runs it as a build step (see .github/workflows/ci.yml).

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

SCAN_DIR="lib/screens"
# Dai Maa is an intentional sub-brand with its own theme (lavender, radius 14/16)
# — it owns its visual language, so it's excluded from the Housepital-canon gate.
EXCLUDE="--exclude-dir=daimaa"
fail=0

report() { # <title> <grep-output>
  if [ -n "$2" ]; then
    fail=1
    echo ""
    echo "✗ $1"
    echo "$2" | sed 's/^/    /'
  fi
}

# 1. circular(14) — the off-spec card radius (canon is 12, or 16 for heroes).
report "BorderRadius.circular(14) is banned — use 12 (cards) or 16 (heroes)" \
  "$(grep -rn 'circular(14)' "$SCAN_DIR" $EXCLUDE --include='*.dart')"

# 2. Material grey shades — use HousepitalColors.greyLighter/divider/greyLight.
report "Colors.grey.shade* / Colors.grey[N] is banned — use grey tokens" \
  "$(grep -rnE 'Colors\.grey(\.shade[0-9]+|\[[0-9]+\])' "$SCAN_DIR" $EXCLUDE --include='*.dart')"

# 3. Raw Material status colors — use HousepitalColors.error/info/success/warning.
report "Raw Colors.red/blue/green/teal/purple/redAccent is banned — use tokens" \
  "$(grep -rnE 'Colors\.(red|blue|green|teal|purple|redAccent|greenAccent|blueAccent)\b' "$SCAN_DIR" $EXCLUDE --include='*.dart')"

# 4. Hardcoded hex colors. theme files are the only allowed source. A short
#    allowlist covers genuine brand colors with no token (e.g. WhatsApp green).
# Allowlist: colors with NO flat-token equivalent —
#  0xFF25D366  WhatsApp brand green
#  decorative gradient end-stops (lighter pair of a hero gradient):
#  0xFFFF8C00 0xFFFF6B35 0xFF42A5F5 0xFF66BB6A 0xFF34D399 0xFFFFE0B2
#  semantic hues with no token: 0xFF9C27B0 (wallet) 0xFF7B1FA2 (sugar chart)
ALLOW='0xFF25D366|0xFFFF8C00|0xFFFF6B35|0xFF42A5F5|0xFF66BB6A|0xFF34D399|0xFFFFE0B2|0xFF9C27B0|0xFF7B1FA2'
hex=$(grep -rnE 'Color\(0x[A-Fa-f0-9]{8}\)' "$SCAN_DIR" $EXCLUDE --include='*.dart' \
        | grep -viE "$ALLOW")
report "Hardcoded Color(0xFF…) is banned in screens — use HousepitalColors.* (allowlist: $ALLOW)" \
  "$hex"

# 5. Raw brand orange (#F39314) as TEXT color — fails WCAG AA on white (~2.3:1)
#    and on orangeLight tints (2.13:1). Text must use orangeText (MEASURED
#    3.99:1 on white — AA-large only, NOT the 4.6:1 this comment used to
#    claim; use orangeStrong at 5.38:1 for anything under 18px) — or
#    onOrange when the text sits ON an orange fill. Pragmatic single-line grep:
#    flags TextStyle + a plain `.orange` token on the same line (orangeText /
#    orangeDark / orangeLight / onOrange don't match because the char after
#    "orange" must be a non-letter). Fills/borders/icons are not flagged.
# Allowlist (file:line or unique snippet regex) for genuine false positives,
# e.g. orange text deliberately placed on a dark surface. Keep '__none__' as
# the first alternative so an otherwise-empty list matches nothing.
ORANGE_TEXT_ALLOW='__none__'
orange_text=$(grep -rnE 'TextStyle' "$SCAN_DIR" $EXCLUDE --include='*.dart' \
                | grep -E '(HousepitalColors|context\.hc)\.orange[^A-Za-z]' \
                | grep -viE "$ORANGE_TEXT_ALLOW")
report "Raw orange as text color is banned (2.3:1 on white) — use context.hc.orangeText, or onOrange on orange fills" \
  "$orange_text"

# 6. CircleAvatar holding an Icon — use AppIconTile. (Avatars for real people /
#    initials / images are fine, so we only flag CircleAvatar with a child:Icon
#    on the same or next line.)
circle=$(grep -rnA2 'CircleAvatar(' "$SCAN_DIR" $EXCLUDE --include='*.dart' \
          | grep -B2 'child: Icon' | grep 'CircleAvatar(')
report "CircleAvatar wrapping an Icon is banned — use AppIconTile" \
  "$circle"

# 7. Service-type identity colors (calm pass, owner-approved): the per-service
#    rainbow (serviceNursing teal/orange, servicePhysio blue, …) was DECORATIVE
#    identity color and is retired from screens. Screens stay near-monochrome
#    with ONE orange accent; color is reserved for meaning (green = good
#    status, red = SOS/error, amber = warning, blue = info). Genuinely
#    CATEGORICAL uses (legend dots, category icon maps where the hue encodes a
#    category the user actively distinguishes) may be allowlisted by file with
#    a comment explaining why.
# Allowlist:
#  article_category_style.dart  — article-category legend map (categorical:
#                                 hue distinguishes content categories)
#  universal_search_screen.dart — search result-type icon map (categorical:
#                                 hue distinguishes result types in one list)
#  staff_role_card.dart         — catalog seed role-card icon map (categorical
#                                 catalog tiles, pending its own calm review)
#  doctor_advice_card.dart      — advice-type icon map (categorical, pending
#                                 its own calm review)
SERVICE_COLOR_ALLOW='article_category_style\.dart|universal_search_screen\.dart|staff_role_card\.dart|doctor_advice_card\.dart'
svc=$(grep -rnE 'HousepitalColors\.(serviceColor|serviceCarePackage|serviceNursing|serviceCaretaker|serviceJapaNanny|servicePhysio|serviceEquipment)' \
        "$SCAN_DIR" $EXCLUDE --include='*.dart' \
        | grep -viE "$SERVICE_COLOR_ALLOW")
report "Service-type colors are retired in screens (calm pass) — use the one orange accent (HousepitalColors.orange / context.hc.orange); genuinely categorical uses go on the allowlist with a comment" \
  "$svc"

# ── Informational: fontSize histogram (echo-only, NEVER fails) ──────────────
# Surfaces typography drift in CI logs without gating the build. The canonical
# scale (see the typography audit): 28/w800 display • 16/w600 SectionHeader •
# 15/w700 card title • 14/w600 list-row • 13.5–14 body • 12 meta • 11–12
# caption/chip • 11 floor (sole sub-11 exception: calendar year-view mini
# digits). Sizes outside the scale (13, 17, 18, 19, 20, 21, 10) are smells to
# review — they are reported here but do NOT change the pass/fail result.
echo ""
echo "ⓘ fontSize histogram (informational — does not affect pass/fail)"
echo "   scope: lib/screens + lib/widgets (excluding $EXCLUDE)"
hist=$(grep -rhoE 'fontSize:[[:space:]]*[0-9]+(\.[0-9]+)?' lib/screens lib/widgets \
         $EXCLUDE --include='*.dart' 2>/dev/null \
       | grep -oE '[0-9]+(\.[0-9]+)?' | sort -n | uniq -c)
if [ -n "$hist" ]; then
  echo "$hist" | sed 's/^/    /'
else
  echo "    (no fontSize literals found)"
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "════════════════════════════════════════════════════════════"
  echo "Design-consistency check FAILED. Fix the items above, or — if a"
  echo "value is genuinely intentional — add it to the allowlist in this"
  echo "script with a comment explaining why."
  echo "════════════════════════════════════════════════════════════"
  exit 1
fi
echo "✓ Design-consistency check passed — no banned patterns in $SCAN_DIR."
