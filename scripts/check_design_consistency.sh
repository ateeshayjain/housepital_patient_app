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

# 5. CircleAvatar holding an Icon — use AppIconTile. (Avatars for real people /
#    initials / images are fine, so we only flag CircleAvatar with a child:Icon
#    on the same or next line.)
circle=$(grep -rnA2 'CircleAvatar(' "$SCAN_DIR" $EXCLUDE --include='*.dart' \
          | grep -B2 'child: Icon' | grep 'CircleAvatar(')
report "CircleAvatar wrapping an Icon is banned — use AppIconTile" \
  "$circle"

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
