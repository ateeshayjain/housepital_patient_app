# Visual Consistency Audit — Housepital Patient App

**Date:** 2026-06-08
**Method:** 4 parallel agents read **every** screen in `lib/screens/` (85 files) and
measured each widget against the canonical design system *and against each other*
(not isolated spec checks). Plus deterministic scans for missing i18n keys,
card-radius spread, icon-size spread, and hardcoded colors.

## Verdict

The app has a **complete shared design kit** (`HousepitalCard`, `SectionHeader`,
`StatusBadge`, `LoadingWidget`, `ErrorRetryWidget`, `DetailRow`, `VitalCard`) and a
**full token set** (`HousepitalColors.*`) — but **most screens bypass them and
hand-roll their own versions.** That single root cause produces every visible
inconsistency below.

Totals: **~49 HIGH, ~106 MEDIUM, ~75 LOW** across the app — but they collapse into
**6 systemic patterns**. Fix the 6 patterns (ideally via shared components) and the
long tail disappears.

Good news from the deterministic scans: **0 missing localization keys** app-wide
(the `today_report` raw-key bug was the only one, now fixed); EN/HI in sync.

## The 6 systemic patterns (root causes)

### 1. Multiple card systems (radii 8 / 10 / 12 / 14 / 16, shadow-vs-border mixed)
Three coexisting card languages: (A) Container radius 12 + divider border [home,
my_care], (B) raw `Card()` radius 16 + shadow [my_care/widgets/*, service_detail,
video, reports], (C) radius 14 + border [articles, all services/cards/*, cart,
referral, sos, payment_methods explainer, emi hero]. Adjacent cards in one scroll
have different corners and shadow-vs-border. **`circular(14)` appears ~34× and is
always wrong.**
→ **Fix:** one card primitive — radius 12 + 1px `divider` border (16 for true heroes).

### 2. Leading icon-tile rendered 6+ ways
Same "colored icon next to a row title" appears as: CircleAvatar (health mgr,
service_detail, staff_otp, video, family), bare icon (settings rows, attendance,
medications, billing summary), and rounded-square tiles at sizes 40/42/44/48/56/64
with icons 18/20/22/24/28/32 and tint alpha 0.08/0.1/0.12/0.15.
→ **Fix:** one `AppIconTile` — rounded square, radius 10, padding 8, icon 22, bg
`color.withValues(alpha: 0.12)`. (People-as-avatar is acceptable IF applied
consistently; recommend tiles everywhere for icons.)

### 3. Hardcoded colors instead of tokens (21 files)
- **Tailwind palette in My Care** (`0xFFF0FDF4`, `0xFF16A34A`, `0xFFBBF7D0`,
  `0xFFFEF2F2`, `0xFFCA8A04`, `0xFFE5E7EB`…) → `successLight/success`,
  `errorLight/error`, `warningLight/warning`, `divider`.
- **`Colors.grey.shade*`** (cart, equipment_detail, package_detail, sheets,
  payment_methods, staff_profile, video…) → `greyLighter/divider/greyLight`.
- **`Colors.red/blue/green/orange/teal/purple/redAccent`** (help_faq, raise_concern,
  staff_profile Half-Day, add_edit_medication, video, search results,
  service_catalog cart badge) → `error/info/success/warning/serviceColor()`.
- **Three different greens** mean "good/given" (`0xFF16A34A`, `Colors.green[800]`,
  `success`); **two reds** mean "alert" (`0xFFE53935` chart vs `error` stats).
- **Hero gradients** hardcoded per tab (4 styles) → tokenize.
→ **Fix:** replace all with exact token equivalents (mappings in the per-file lists).

### 4. Section headers at 4 sizes (14 / 15 / 16 / 18)
`SectionHeader` (16/w600 + 14 action) exists but home uses 15/w700, my_care uses
18/w700, service_detail uses 14/16, billing uses 18.
→ **Fix:** route all through `SectionHeader`.

### 5. Badge/pill rendered at radii 3 / 4 / 6 / 8 / 16 / 20
`StatusBadge` (pill, radius 20) exists but most badges are hand-rolled squares
(radius 4/6/8). Even the same data (service category) renders as a chip in one
screen and bare text in another (articles list vs detail).
→ **Fix:** `StatusBadge` for status; one small-badge radius (8) for type/labels.

### 6. Divergent states + one-off control styles
- Loading: `LoadingWidget` vs bare `CircularProgressIndicator` vs Shimmer skeleton.
- Error: `ErrorRetryWidget` vs hand-rolled `Center(Text)`.
- Empty states: ~5 visual languages (icon size 56/64/80, color greyLight/greyLighter/grey.shade300).
- Filter chips: solid-orange (vitals) vs orangeLight+border ChoiceChip (transactions).
- Search bars: shared `CatalogSearchBar` vs hand-rolled (lab/equipment tabs).
- Bottom-sheet dismiss: drag-handle vs custom "X".
- Primary CTA: orange vs blue (cart Request-Booking); button height 50 vs 52.
- Quantity steppers: 3 different implementations.
→ **Fix:** route to the shared widgets; one chip, one CTA color (orange), one height (52).

## Fix plan (waves)

1. **Wave 1 — Tokenize colors.** Mechanical, high-visibility, low-risk. Kills the
   "different greens/reds/greys per screen." (~21 files)
2. **Wave 2 — Shared `AppIconTile` + migrate all leading icons.** Kills pattern #2.
3. **Wave 3 — One card primitive.** Migrate hand-rolled cards → radius 12 + divider
   (or HousepitalCard). Kills pattern #1.
4. **Wave 4 — Headers, badges, states.** `SectionHeader` / `StatusBadge` /
   `LoadingWidget` / `ErrorRetryWidget` everywhere; one chip; one CTA; one height.

Each wave: analyze + full test + visual rebuild before claiming done.

## Per-agent full inventories
See git history / the audit run for the complete file:line lists (4 agents covered:
home+my_care+daimaa+assistant+articles · services+cart+packages+rental+orders ·
billing+reports+consultation+meds · settings+auth+support+sos+notifications+docs+search).
