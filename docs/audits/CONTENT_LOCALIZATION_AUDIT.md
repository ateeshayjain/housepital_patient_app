# Content & Localization Checklist (App-Agnostic) — Audit vs commit 803124d

**Date:** 2026-08-03 · **Auditor:** Content & Localization agent
**Scope:** read-only. No files changed. All verdicts carry `path:LINE` or a command + output.
**Method:** `rg`/`grep`/`python3` static scans over `lib/`, `assets/i18n/`, `ios/`, `android/`.
`flutter test` / `flutter build` deliberately NOT run (central suite in flight); `flutter analyze` reported clean by brief.

---

## Headline metrics (measured, not estimated)

| Metric | Value | How measured |
|---|---|---|
| Dart files in `lib/screens` + `lib/widgets` | **98** (42,090 LOC) | `find … -name '*.dart' \| wc -l`, `xargs wc -l` |
| Localized call sites (`l.t(…)` / `AppLocalizations.of(…).t(…)`) | **199** | regex scan, comments stripped |
| Hardcoded user-facing string literals | **1,246** | `Text('…')` + user-facing named params (`title:`, `label:`, `hintText:`, `tooltip:`, `message:`, `content:`, …), filtered to exclude routes, asset paths, snake_case ids, hex |
| **Localized : hardcoded ratio** | **199 : 1,246 → 13.8 % localized / 86.2 % hardcoded** | derived |
| Files that use `AppLocalizations` at all | **33 / 98 (34 %)** | scan |
| Files with **zero** `l.t()` but ≥1 hardcoded user-facing literal | **57**, holding **742** literals | scan |
| Keys in `en.json` / `hi.json` | **321 / 321**, key sets identical | `python3` set diff |
| Keys actually referenced in code | **161** (50 %) — **160 unused** | `grep -rho ".t('…'"` vs json keys |
| Unused keys whose **English value is hardcoded in a screen anyway** | **85** | value→key reverse map against the hardcoded-literal corpus |
| `hi.json` values containing real Devanagari | **315 / 321** | `[ऀ-ॿ]` regex |
| `hi.json` values identical to English | **6** — `app_name`, `bp`, `gst`, `sos`, `spo2`, `spo2_percent` (all legitimate acronyms) | set compare |

**Verdict on the "synced but untranslated" risk the brief flagged:** *not* the failure mode here.
`hi.json` is a genuine, good-quality Hindi translation — natural phrasing, correct Delhi-register
transliteration for clinical terms (`ब्लड प्रेशर`, `खुराक दर्ज करें`), Latin retained only where correct
(OTP, EMI, PDF, GST, mmHg, bpm). The real failure is the **other direction**: the translations exist
and are never called. 86 % of user-facing copy never reaches the i18n layer, so switching the app to
Hindi still leaves the user reading English on almost every screen.

---

## Scorecard

| Section | ✅ | ⚠️ | ❌ | N/A |
|---|---|---|---|---|
| 1. Voice & tone | 0 | 2 | 1 | 0 |
| 2. Microcopy | 0 | 2 | 1 | 0 |
| 3. State copy | 0 | 3 | 1 | 0 |
| 4. Terminology consistency | 0 | 1 | 1 | 0 |
| 5. Numbers, dates, currency | 0 | 2 | 2 | 0 |
| 6. Localization / i18n | 1 | 2 | 2 | 1 |
| 7. Accessibility copy | 1 | 1 | 1 | 0 |
| 8. Store / site / legal copy | 0 | 1 | 1 | 1 |
| 9. Proofreading | 1 | 2 | 1 | 0 |
| **Total (27 items)** | **3** | **16** | **11** | **2** |

*(§8 has one BLOCKED-OWNER item counted in the N/A column; see BLOCKED-OWNER section.)*

---

## Findings

### §1 Voice & tone

- ⚠️ **Copy matches the brand voice consistently across surfaces.**
  The best copy in the app is genuinely excellent and on-brand. `lib/widgets/empty_state.dart:4-5`
  encodes an explicit voice rule ("what this space will hold + who's behind it — warm, factual, no
  database language, no exclamation marks"), and the 28 patient-education articles in
  `lib/data/demo_articles.dart` are model work: plain sentences, India-context (chulha smoke, Delhi
  AQI, bidi/hookah, achaar and papad for BP), red-flag lists, and a consistent closing disclaimer
  ("*This is general guidance. For your specific situation, talk to your doctor or your Housepital
  Health Manager.*").
  Against that, three surfaces are off-brand:
  1. `lib/services/invoice_pdf_service.dart:250` ships a **second tagline** on every invoice —
     `'Housepital - ICU-grade care at home.'` — not "Hospital-like expertise. Home-like care."
     (`assets/i18n/en.json:3`, `lib/screens/splash_screen.dart:46`, `about_screen.dart:54`).
  2. `lib/services/payment_reminder_service.dart:126` is commented **"Airtel-style"** and reads like
     telecom dunning — see the ❌ in Blockers.
  3. `lib/screens/settings/referral_screen.dart:119` — `'Get hospital-like care at home with
     Housepital! '` — the exclamation mark the empty-state voice rule bans.
  **Fix:** make `assets/i18n/en.json:3` (`tagline`) the single source; replace the invoice footer
  string with it; drop the referral exclamation mark.

- ❌ **No unexplained jargon or internal/dev terms in user-facing text.**
  Clinical acronyms ship unexpanded to a family audience:
  - `lib/data/care_packages.dart:19,28,66,75` — "ventilator/BiPAP", "**ACLS** ambulance on call
    (20 km)", "centralised vital monitoring" — inside the description of a ₹90,000/mo package.
  - `lib/screens/search/universal_search_screen.dart:92` — `'RT (Ryles Tube) Change'`;
    `:93` `'Tracheostomy Change'`.
  - `lib/data/demo_data.dart:530` — medication instruction `'Subcutaneous injection at bedtime'`
    for a self-administered insulin dose.
  - `lib/data/demo_data.dart:221` — daily report note `'SpO2 maintained at 96% on 2L O2'`.
  **Dev-term leak:** `lib/models/medication_models.dart:78` — `frequencyLabel`'s `default:` branch
  returns the raw enum, so an unmapped value renders the snake_case token (e.g. `every_other_day`)
  straight onto the medication row at `lib/screens/my_care/medications_screen.dart:487`.
  **Impact:** a caregiver cannot judge whether "ACLS" is worth the price, and a snake_case token on a
  dosage line reads as a broken app on the most safety-sensitive screen.
  **Fix:** add a one-line plain gloss after each acronym ("ACLS ambulance — advanced life-support,
  doctor-grade equipment on board"); change `medication_models.dart:78` to return a humanised
  fallback (`frequency.replaceAll('_',' ')` title-cased) rather than the raw token.

- ⚠️ **Reading level fits the audience.**
  Articles and empty states: short, plain, second-person — excellent. But the rental contract
  (`lib/screens/rental/rental_agreement_screen.dart:74-85`) and the catalog service names
  (`universal_search_screen.dart:81-93`) sit at a much higher reading level, and both are
  English-only (see §6). The rental terms themselves are well written ("Partial month rent is not
  refundable") — the problem is language access, not density.

---

### §2 Microcopy

- ⚠️ **Buttons/CTAs are action verbs, not vague.**
  The dominant pattern is good — `'Confirm & Add to Cart'`
  (`rental_agreement_screen.dart:112`), `'Call coordinator'` (`payment_methods_screen.dart:380`),
  `'Schedule Return Pickup'`, `'Book Housepital Ambulance'`. But **24 vague labels** remain:
  `Text('OK')` ×5, `Text('Yes')` ×2, `Text('No')` ×2, `Text('Submit')`, `Text('Done')`,
  `Text('Confirm')` — e.g. `lib/screens/cart/cart_screen.dart:663` uses a bare `'OK'` to dismiss the
  "Booking request sent to your primary contact" dialog where `'Got it'` or `'Back to cart'` would
  carry meaning.
  **Fix:** replace the 5 `'OK'` and 1 `'Submit'` with outcome verbs; leave Yes/No only where the
  dialog title is itself a question.

- ❌ **Labels and field names are clear and consistent across screens.** See §4 — the same concept
  carries three different names (escalation contact, red-vital status, support phone number).

- ⚠️ **Confirmations state the consequence.**
  A shared, correctly-styled destructive dialog exists — `confirmDestructiveAction`
  (`lib/widgets/common_widgets.dart:501-525`, error-coloured confirm button) — and is used at 7 call
  sites. But **only 1 of 7 states irreversibility**:
  - ✅ `lib/screens/orders/order_tracking_screen.dart:588` — "…This action cannot be undone."
  - ⚠️ `lib/screens/documents/document_repository_screen.dart:531` — `'Are you sure you want to
    delete "${doc.name}"?'` — deleting a discharge summary or prescription is unrecoverable and the
    copy does not say so.
  - ⚠️ `lib/screens/settings/family_members_screen.dart:60`, `patient_profile_screen.dart:233`,
    `cart_screen.dart:609,870`, `checkout/address_selection_screen.dart:171` — all "Are you sure…".
  **Fix:** append the consequence clause to each message; `document_repository_screen.dart:531` is
  the one that matters ("This permanently deletes the file from this device. It can't be undone.").

---

### §3 State copy (empty / loading / error)

- ⚠️ **Empty states explain what goes here + how to add the first item.**
  `lib/widgets/empty_state.dart` is a well-designed shared component (icon + title + body + optional
  CTA) and the copy routed through it is strong — e.g. `billing_empty_title` / `billing_empty_body`
  ("No bills yet" / "When your services begin, every invoice and payment will appear here").
  Four surfaces bypass it with bare database language:
  - `lib/screens/reports/vitals_screen.dart:216` — `Text('No data available')`
  - `lib/screens/reports/vitals_screen.dart:262` — `Text('No data')`
  - `lib/widgets/paginated_list.dart:126` and `:154` — `'No items found'`
  - `lib/widgets/paginated_list.dart:233` — `'No more items'`
  Note `no_data_available` already exists in both JSONs and is simply not called.
  **Fix:** swap the four sites to `HousepitalEmptyState` with a "how to add the first reading" CTA
  pointing at the Add-reading sheet.

- ⚠️ **Loading copy is honest and brief; long waits show progress.**
  24 bare `CircularProgressIndicator` sites vs **1** with copy —
  `lib/screens/billing/payment_screen.dart:311` `LoadingWidget(message: 'Processing payment...')`.
  `LoadingWidget` is used 11× but only that one passes a message. A `loading` key exists in both
  JSONs (`'Loading...'` / `'लोड हो रहा है...'`) and is never used. PDF generation
  (`invoice_pdf_service`, `handover_report_service`) is on-device and can take seconds with no copy.

- ⚠️ **Error messages are non-technical and actionable.**
  The tone is mostly right and several messages give a real next step —
  `lib/screens/support/staff_replacement_screen.dart:227` ("…Please try again or call our
  coordinator at …"), `lib/screens/rental/return_screen.dart:367`,
  `lib/screens/chat/chat_screen.dart:144`. Three leaks:
  - `lib/screens/support/raise_concern_screen.dart:410` — `Text('Failed to submit: ${e.message}')`
  - `lib/screens/settings/patient_profile_screen.dart:297` — `Text('Failed to save: ${e.message}')`
  - `lib/main.dart:768` — `Text('$e', …)` renders the raw exception in the route-error fallback.
  **Fix:** keep `e.message` in the logger, show the already-present generic + action copy to the user.

- ❌ **Disabled actions tell the user *why*.**
  5 disabled-CTA sites, **none** carry a reason string:
  `lib/screens/reports/vitals_screen.dart:781` (`onPressed: _isValid ? _save : null`),
  `lib/screens/settings/add_patient_screen.dart`, `lib/screens/services/equipment_detail_screen.dart`
  (×2), `lib/screens/billing/payment_screen.dart`,
  `lib/screens/my_care/widgets/doctor_advice_card.dart`.
  `lib/screens/rental/rental_agreement_screen.dart:110` is the clearest miss: "Confirm & Add to Cart"
  is dead until the T&C checkbox is ticked, with no text saying so.
  Positive counter-example worth copying: `lib/screens/auth/login_screen.dart:60` scrolls to the
  consent row *and* shows `'Please accept the Terms to continue'`.
  **Fix:** apply the login_screen pattern (helper line under the disabled button) to the other five.

---

### §4 Terminology consistency

- ❌ **One term per concept.** Three concrete collisions, all user-visible:

  **(a) The escalation contact has three names.**
  - "Housepital **Health Manager**" — every one of the 28 articles' closing line
    (`lib/data/demo_articles.dart`), `lib/data/demo_data.dart:390`,
    `lib/screens/my_care/widgets/health_manager_banner.dart`
  - "**coordinator**" — `lib/screens/billing/payment_methods_screen.dart:355,380`,
    `lib/screens/support/staff_replacement_screen.dart:227`,
    `lib/screens/services/assessment_request_screen.dart:443,1435`,
    `lib/screens/rental/return_screen.dart:367`, `lib/screens/my_care/my_care_screen.dart:660,680`
  - "**Care Team**" — `lib/screens/care_team/care_team_screen.dart:95,126`,
    `lib/screens/home/home_screen.dart:781,846`

  **(b) The red-vital status has three words.**
  - `lib/widgets/common_widgets.dart:281` → `'Alert'` (hardcoded, on the VitalCard)
  - `assets/i18n/en.json` `vital_status_alert` → `'Needs attention'` (used at
    `lib/screens/reports/vitals_screen.dart:851`)
  - `lib/utils/helpers.dart:21` → `'alert'` (internal token, also compared as a string at
    `vitals_screen.dart:548`)
  The same reading therefore reads "Alert" on Home and "Needs attention" in the entry sheet.

  **(c) Three support phone numbers.** See Blockers — `9990911911` (constants), `9050200183`
  (the **Dai Maa** number, `lib/config/daimaa_theme.dart:23`), and two placeholders.

  **(d) Hindi-side duplicates.** Two English strings have two keys each with *divergent* Hindi:
  `todays_vitals`/`today_vitals` → `आज के विटल्स` vs `आज के वाइटल्स`;
  `borderline`/`vital_status_borderline` → `सीमा रेखा` vs `सीमा पर`.
  (`no_data`/`no_data_available`, `todays_report`/`today_report`, `tab_billing`/`billing_title`,
  `normal`/`vital_status_normal` are duplicated but consistent.)
  **Fix:** pick "Health Manager" and "Needs attention"; delete the duplicate keys; add a 15-line
  glossary to `CLAUDE.md` under the design-system contract.

- ⚠️ **Capitalization style consistent.**
  AppBar titles are uniformly Title Case — `About`, `Care Guides`, `Care Team`, `EMI Options`,
  `Help & FAQ`, `Notification Preferences`, `Order Tracking`, `Payment & Auto-pay`, `Refer & Earn`,
  `Rental Agreement`, `Request Replacement`, `Return Equipment`, `Sahayak` — ✅.
  Discount chips are not: `'% off'` at `cart_screen.dart:813`,
  `equipment_item_card.dart:151`, `equipment_detail_screen.dart:753`,
  `service_booking_screen.dart:282,2371` vs `'% OFF'` at `packages_tab.dart:83`,
  `package_detail_screen.dart:313`, `universal_search_screen.dart:247,496`.

---

### §5 Numbers, dates, currency

- ⚠️ **Currency formatted per locale; never hand-format money.**
  The helper is correct and dominant: `lib/utils/helpers.dart:51-54`
  `NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)` — **Indian lakh grouping
  is handled** (₹1,00,000), and it is called **114 times**. Eight sites bypass it:
  - `lib/services/invoice_pdf_service.dart:69` — `String _fmtAmount(num amount) => 'Rs ${amount.round()}';`
    This is the **tax invoice**: subtotal, "GST (18%)" and "Grand total" all render as
    `Rs 106200` instead of `₹1,06,200` (`:230,233,236`).
  - `lib/services/payment_reminder_service.dart:135,141,147,153` — `'₹${reminder.amount.toInt()}'`.
  - `lib/screens/services/tabs/packages_tab.dart:99` — `'₹${pkg.pricePerDay!.toStringAsFixed(0)}/day'`.
  - `lib/screens/assistant/assistant_executor.dart:308,439` — `'₹$price'`, `'₹$amount'`.
  - `lib/screens/cart/cart_screen.dart:404` — `'Free delivery on orders above Rs.999'` (`Rs.` vs `₹`
    used everywhere else on the same screen).
  **Fix:** `_fmtAmount` → `DateHelper.formatCurrency(amount.round())`; same for the other seven.

- ❌ **Dates/times use the correct locale/zone; relative dates read naturally.**
  - **`Intl.defaultLocale` is never set and `initializeDateFormatting` is never called** anywhere in
    `lib/` (verified: `rg -n "Intl.defaultLocale|initializeDateFormatting" lib` → no matches, exit 1).
    Every `DateFormat` therefore emits `en_US` regardless of the app locale. In Hindi mode the Care
    Calendar still shows "Monday, 3 August" — 12 raw `DateFormat(…)` calls in
    `lib/screens/calendar/care_calendar_screen.dart:224,399,400,561,655,759,851,865,933,1199,1327,1727`,
    plus `DateHelper.formatDate/formatTime/formatDateShort`.
  - **Four hand-rolled month-name arrays** bypass intl entirely and can never localize:
    `lib/services/handover_report_service.dart:37-38`,
    `lib/services/invoice_pdf_service.dart:61-66`,
    `lib/services/payment_reminder_service.dart:160-165`,
    `lib/screens/support/staff_profile_screen.dart:498`.
  - **Three different time formats coexist:** `DateHelper.formatTime` → `'3:05 PM'`
    (`helpers.dart:29`); `lib/screens/home/home_screen.dart:1722-1727` re-implements the same 12-hour
    format by hand; `lib/screens/chat/chat_screen.dart:448-451` renders **24-hour** `'15:05'`.
  - **Relative dates:** `DateHelper.formatRelative` (`helpers.dart:40-49`) has no "Yesterday" — it
    jumps `1h ago → 1d ago`. `lib/screens/support/staff_profile_screen.dart:1190-1195` implements a
    *second*, different relative formatter that does have Today/Yesterday. Both English-only.
  **Fix:** set `Intl.defaultLocale = appProvider.locale.languageCode` in the `MaterialApp.builder`
  (`lib/main.dart:413`) and call `initializeDateFormatting('hi')`; delete the four month arrays and
  the two duplicate time formatters in favour of `DateHelper`.

- ❌ **Pluralization correct via plural rules, not "item(s)".**
  Both failure modes present.
  *"(s)" hacks — 5 user-facing sites:*
  `lib/services/invoice_pdf_service.dart:212` `'$months month(s)'`;
  `lib/screens/rental/rental_agreement_screen.dart:54` `'${widget.durationMonths} month(s)'`;
  `lib/screens/services/service_booking_screen.dart:952` `'Please enter medication name(s)'`,
  `:1460` same, `:2175` `'${_attachedFiles.length} file(s)'`.
  *Genuine "1 <plural>" bugs:*
  - `lib/screens/support/staff_profile_screen.dart:1193-1195` — `'${(diff.inDays/7).floor()} weeks
    ago'`, `'… months ago'`, `'… years ago'` all render **"1 weeks ago" / "1 months ago" /
    "1 years ago"**.
  - `lib/services/payment_reminder_service.dart:48` — `'Overdue by ${-days} days'` → **"Overdue by
    1 days"**, rendered live at `lib/screens/billing/payment_methods_screen.dart:305`.
  *Counter-examples done right:* `lib/screens/reports/vitals_screen.dart:552`
  `'occasion${alertCount > 1 ? "s" : ""}'` and `lib/screens/services/tabs/packages_tab.dart:118`
  `'${…length == 1 ? "service" : "services"}'`. `AppLocalizations.translate`
  (`lib/utils/app_localizations.dart:29-37`) is plain `{param}` substitution with **no plural
  support at all** — so this cannot be fixed inside the i18n layer as it stands.
  **Fix:** add a `plural(count, one, other)` helper to `AppLocalizations` (or adopt ICU via
  `intl`'s `Intl.plural`), then migrate the 5 "(s)" sites and the 4 "1 <plural>" sites.

- ⚠️ **Numeric precision correct for money (no float artifacts).**
  Core money fields are integers — `lib/models/models.dart:755` `final int amount;`, `:1215` same —
  and `DateHelper.formatCurrencyPaise` (`helpers.dart:57-61`) divides paise by 100 with
  `decimalDigits: 0`, so no float display artifacts. ✅ in the main path.
  However ~10 display sites **truncate** rather than round doubles into the int formatter:
  `lib/screens/packages/package_detail_screen.dart:391,504,521,540`,
  `lib/screens/services/cards/equipment_item_card.dart:134,167,186`,
  `lib/screens/services/equipment_detail_screen.dart:1467`,
  `lib/screens/billing/payment_methods_screen.dart:310`,
  `lib/screens/search/universal_search_screen.dart:174` — all `formatCurrency(x.toInt())`.
  A computed discount of ₹1,499.9 displays as ₹1,499. `payment_reminder_service.dart:29` also stores
  `final double amount`.
  **Fix:** `.round()` not `.toInt()` at those 10 sites; make `PaymentReminder.amount` an `int`.

---

### §6 Localization / i18n

- ❌ **No hardcoded user-facing strings — all go through the platform i18n system.**
  **199 localized vs 1,246 hardcoded (13.8 % coverage).** 65 of 98 screen/widget files never touch
  `AppLocalizations`; 57 of those hold 742 hardcoded literals.
  **Worst files (hardcoded / localized):**

  | Hardcoded | Localized | File |
  |---:|---:|---|
  | 125 | 2 | `lib/screens/services/assessment_request_screen.dart` |
  | 85 | 0 | `lib/screens/services/service_booking_screen.dart` |
  | 62 | 2 | `lib/screens/settings/patient_profile_screen.dart` |
  | 57 | 1 | `lib/screens/home/home_screen.dart` |
  | 46 | 0 | `lib/screens/services/data/catalog_seeds.dart` |
  | 45 | 0 | `lib/screens/services/equipment_detail_screen.dart` |
  | 41 | 0 | `lib/screens/documents/document_repository_screen.dart` |
  | 40 | 0 | `lib/screens/calendar/care_calendar_screen.dart` |
  | 33 | 0 | `lib/screens/cart/cart_screen.dart` |
  | 29 | 1 | `lib/screens/settings/family_members_screen.dart` |
  | 25 | 0 | `lib/screens/billing/payment_methods_screen.dart` |
  | 25 | 8 | `lib/screens/settings/settings_screen.dart` |
  | 24 | 0 | `lib/screens/checkout/address_selection_screen.dart` |
  | 23 | 0 | `lib/screens/settings/notification_preferences_screen.dart` |
  | 21 | 5 | `lib/screens/support/staff_profile_screen.dart` |

  **The cheapest 85 fixes:** 85 of the 160 "unused" keys are not unused at all — the screen hardcodes
  the exact English string the key already holds, in both languages. Each is a one-line swap.
  Highest-value examples:
  - `agree_terms` — key exists (`'I agree to the rental terms and conditions'` /
    `'मैं किराये के नियम और शर्तों से सहमत हूं'`) yet
    `lib/screens/rental/rental_agreement_screen.dart:96` hardcodes the English. A Hindi-preferring
    family ticks a **legal consent box in English**.
  - `error_occurred` → hardcoded at `lib/widgets/paginated_list.dart:174`
  - `no_data_available` → hardcoded at `lib/screens/reports/vitals_screen.dart:216`
  - `tagline` → hardcoded at `about_screen.dart:54` and `splash_screen.dart:46`
  - plus `cancel` (6 files), `other` (5), `share` (5), `total` (5), `male`/`female` (3 each),
    `my_orders` (3), `tab_home` (3), `app_name` (3), `sos` (2), `retry` (2), `medications` (2)…

  **Whole surfaces with zero localization:**
  - **Patient-education library** — `lib/data/demo_articles.dart`, 28 articles, 236 lines, **zero
    Devanagari characters** (`rg -c "[ऀ-ॿ]"` → 0). The single warmest, most valuable content in the
    product is English-only.
  - **Sahayak assistant** — `lib/services/assistant_service.dart` and
    `lib/screens/assistant/assistant_executor.dart` reply in **romanized Hinglish regardless of app
    locale** ("Iss waqt aapka outstanding bill ₹$amount hai." `assistant_executor.dart:439`;
    "Confirm karein." `assistant_service.dart:95`). No locale is read anywhere in either file.
    An English-only user gets Hinglish; a Devanagari-Hindi user gets Latin-script Hinglish.
    Worse, the assistant's navigation breadcrumbs cite **English UI labels** — "Services > Equipment
    se add karein" (`assistant_executor.dart:292`), "Settings > Raise a Concern se bhej sakte hain"
    (`:343`) — labels that are translated in Hindi mode, so the instructions point at menu items the
    user cannot see.
  - **Login/consent** — `lib/screens/auth/login_screen.dart:209-240` builds "I agree to the Terms &
    Privacy Policy" entirely from hardcoded `TextSpan`s.
  - **Rental contract terms** — `rental_agreement_screen.dart:74-85`, six clauses, hardcoded English.

- ✅ **Target languages/scripts render correctly (incl. non-Latin scripts).**
  Measured directly against the font binaries with a `cmap` parser:
  `assets/fonts/Archivo.ttf` has **no** coverage for U+0905 अ, U+0928 न, U+093F ि (format-4 cmap,
  all `False`); `assets/fonts/NotoSansDevanagari.ttf` covers all three (format-12 cmap, all `True`).
  Both fonts are bundled (`pubspec.yaml:94-100`) and the fallback is wired correctly at the
  `ThemeData` level — `lib/config/theme.dart:146-148,156` `fontFamilyFallback:
  _devanagariFallback` — which Flutter applies across the whole `textTheme`, so the per-style
  `TextStyle(fontFamily: 'Archivo')` overrides in `:170-215` still inherit it. Mixed-script strings
  (`'OTP सत्यापित करें'`, `'सिस्टोलिक (mmHg)'`) resolve per-glyph. ₹ (U+20B9) is in **both** fonts.

- ⚠️ **Layouts tolerate text expansion/contraction without clipping.**
  Mean Hindi/English character ratio across 276 non-trivial strings is **0.99** — Hindi is not longer
  on average. But the expansion is concentrated exactly where it hurts: **short button labels**.
  Worst measured: `re_book` 2.14× (`Re-book` → `दोबारा बुक करें`), `pay_now` 2.14×
  (`Pay Now` → `अभी भुगतान करें`), `upgrading` 2.00×, `try_again` 1.89×, `log_dose` 1.88×
  (`Log dose` → `खुराक दर्ज करें`, on the medication pill), `verify_otp` 1.70×, `resend_otp` 1.60×.
  Devanagari also needs a taller line box (shirorekha + matras).
  **The overflow guard never sees any of this:** `test/screens/overflow_smoke_test.dart:231` pins
  `locale: 'en'`, and `rg -c "Locale('hi')" test/` returns **zero matches across the entire test
  tree**. 37 screens × 3 widths are guarded in English only.
  **Fix:** parameterize `overflow_smoke_test.dart` over `['en','hi']` — the 320 px × Hindi × Ahem
  combination is where clipping will surface.

- N/A **RTL handled if a target locale needs it.**
  `lib/main.dart:398-401` declares `supportedLocales: [Locale('en'), Locale('hi')]` — both LTR, so
  no RTL requirement today. Noting for the future: `rg -n "TextDirection|EdgeInsetsDirectional|
  AlignmentDirectional" lib` returns **0 matches**, while 12 sites use non-directional
  `EdgeInsets.only(left:/right:)`. Adding Urdu (a plausible Delhi NCR target) would require touching
  those first.

- ⚠️ **Text fits at largest accessibility text size / zoom.**
  `lib/main.dart:413-424` clamps `textScaler` to `min 0.85 / max 1.4`, with a comment citing
  WCAG 1.4.4. WCAG 1.4.4 asks for **200 %**; 1.4× is 140 %, so users on iOS Larger Text above that
  setting are silently capped. The clamp is a deliberate, defensible trade — but it is a cap, and it
  is untested: the overflow suite runs at scaler 1.0 only (`overflow_smoke_test.dart:102-105` varies
  width, never scale).
  **Fix:** add a 1.4× pass to the overflow suite before considering raising the cap.

- ❌ **Date/number/currency formatters are locale-aware, not string-built.** Covered in §5 — no
  `Intl.defaultLocale`, four hand-built month arrays, three hand-built time formatters, eight
  hand-built currency strings.

---

### §7 Accessibility copy

- ⚠️ **Screen-reader labels are meaningful; icon-only controls are labeled.**
  72 `Semantics(` wrappers and 18 `semanticLabel`s exist, and the best of them are exemplary —
  `lib/widgets/common_widgets.dart:319` `label: '$label: $value ${unit ?? ''}, $status'` reads a
  vital as "Blood Pressure: 128/84 mmHg, Normal"; `lib/screens/billing/billing_screen.dart:262`
  reads "Total outstanding balance: ₹12,400, 2 orders overdue".
  But **28 of 54 `IconButton`s carry no `tooltip:` within 500 chars** of the constructor —
  `home_screen.dart` ×7, `patient_profile_screen.dart` ×3, `service_booking_screen.dart` ×3,
  `chat_screen.dart` ×2, `health_manager_banner.dart` ×2, `document_repository_screen.dart` ×2,
  `care_team_screen.dart` ×2, and 7 others ×1. Good counter-example:
  `lib/screens/sos/sos_screen.dart:145` `tooltip: 'Copy address'`.

- ❌ **Images/charts have alt text / accessibility descriptions.**
  Images are largely handled — `ProductImage` sets `semanticLabel: 'Product photo'`
  (`common_widgets.dart:131`) and callers override it with the item name
  (`equipment_item_card.dart:221`, `equipment_detail_screen.dart:451,1898`).
  **Charts are not.** The primary 240 px vitals trend `LineChart`
  (`lib/screens/reports/vitals_screen.dart:345`) has **no** `Semantics` wrapper and no textual
  alternative — `rg -n "Semantics" lib/screens/reports/vitals_screen.dart` returns nothing. A
  screen-reader user gets silence from the main vitals chart. The "Insights" block below it
  (`:536-567`) partially compensates but is not attached to the chart and is itself hardcoded
  English. The sparkline variant does it right —
  `lib/screens/my_care/widgets/vitals_trend_grid.dart:63-65` wraps in
  `Semantics(button: true, label: '$title, ${card.status}')`.
  **Fix:** wrap `vitals_screen.dart:345` in `Semantics(label: '<vital> trend over <period>: low <x>,
  high <y>, average <z>, <n> readings outside range')`.

- ✅ **Status conveyed by text/icon, not colour alone.**
  `VitalCard` (`lib/widgets/common_widgets.dart:360-376`) renders an icon **plus** a text label next
  to the coloured value, with the explicit comment "Accessible status: icon + text label instead of
  color-only dot". `_statusIcon` (`:286-297`) maps green→`check_circle`,
  amber→`warning_amber_rounded`, red→`error`. The order-status and attendance surfaces follow the
  same pattern (`lib/utils/helpers.dart:84-101` pairs every status colour with a distinct icon).

---

### §8 Store / site / legal copy

- ❌ **Store listing / marketing-site copy accurate and current.**
  The Android launcher label is the raw package slug:
  `android/app/src/main/AndroidManifest.xml:7` — `android:label="housepital_patient"`.
  The app appears on the Android home screen as **"housepital_patient"**, lowercase with an
  underscore. iOS is correct — `ios/Runner/Info.plist:9-10` `CFBundleDisplayName` =
  `Housepital Patient`.
  Separately, **`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are absent** from
  `ios/Runner/Info.plist` (only `NSMicrophoneUsageDescription:69` and
  `NSSpeechRecognitionUsageDescription:71` are present), while `image_picker` camera/gallery is
  invoked from five screens — `document_repository_screen.dart:614,632`,
  `raise_concern_screen.dart:77,85`, `return_screen.dart:316`, `chat_screen.dart:122`,
  `patient_profile_screen.dart:190,195`. Missing purpose strings are both an iOS crash and an App
  Store rejection. See Blockers.
  **Fix:** `android:label="Housepital"`; add both `NS*UsageDescription` keys in the voice of the two
  that already exist ("Housepital uses your camera so you can photograph prescriptions and reports
  for your care team.").

- ⚠️ **"What's New" / release notes written.**
  `docs/CHANGELOG.md` exists and is thorough (944 lines) but is an **engineering** changelog —
  commit SHAs, file paths, `_priceMultiplier`, `check_design_consistency.sh`. There is no
  user-facing release-note text anywhere in the repo, and no `fastlane/metadata` directory under
  `ios/` or `android/`.

- ⚠️ **Privacy policy / terms / in-app legal text reads clearly and matches behaviour.**
  In-app legal text is thin and slightly mislabelled:
  - `lib/screens/settings/about_screen.dart:97-105` links out to
    `https://housepital.in/terms` and `https://housepital.in/privacy` — no in-app copy.
  - `lib/screens/auth/login_screen.dart:216,236` — the "Terms" and "Privacy Policy" links both
    `Navigator.pushNamed(context, '/about')`. Tapping "Privacy Policy" opens the About screen, not
    the policy; the user must then find and tap a second link. Copy and behaviour don't match.
  - The consent row itself is well-implemented otherwise (`login_screen.dart:23-28,48-60,272-277`):
    explicit checkbox, CTA disabled until ticked, scroll-to-and-explain on bounce.
  - `handover_report_service.dart:275-277` closes the doctor handover PDF with "Compiled by the
    Housepital patient app from supervisor-synced records. This is a computer-generated document." —
    **no clinical disclaimer**, unlike every article. See High.
  - `invoice_pdf_service.dart:244-246` handles the quote case well: "Amounts are intentionally
    omitted. Our coordinator will confirm pricing with you on call before any payment." ✅
  - The rental contract (`rental_agreement_screen.dart:74-85`) is clear and consequence-stating —
    but English-only (§6).

---

### §9 Proofreading (final pass)

- ✅ **Spelling and grammar checked across all surfaces.**
  A targeted misspelling sweep (`recieve|occured|seperate|acheiv|definately|succesful|mantain|
  priviledge|calender|enviorn`) over all of `lib` returns **zero hits**. Spelling convention is
  consistently **British/Indian English** — `behaviour` (7), `colour` (16), `cancelled` (28, zero
  `canceled`), `centralised`, `recognise`, `organis*` (4, zero `organiz*`), `personalis*` (2, zero
  `personaliz*`). The 3 `behavior` hits are all in code comments, not copy.

- ⚠️ **No placeholder copy shipped (Lorem ipsum, "TODO", "test", "asdf").**
  No Lorem ipsum; all 6 `TODO(` markers are in comments (`lib/main.dart:192`,
  `billing_screen.dart:1`, `app_provider.dart:171`, `logger.dart:63`, `staff_role_card.dart:300`) —
  none render. But **three placeholders are user-visible**:
  - `lib/screens/settings/help_faq_screen.dart:352` — Call button dials `tel:+919999999999`
  - `lib/screens/settings/help_faq_screen.dart:365` — WhatsApp button opens `wa.me/919999999999`
  - `lib/screens/my_care/staff_otp_verification_screen.dart:352` — "Call Support" dials
    `tel:+918888888888`, with the comment on `:351` admitting "Support number to be updated with
    production contact details."
  - `lib/screens/documents/document_repository_screen.dart:599` ships a stub message —
    `'PDF upload coming soon. Email your documents to wecare@housepital.in for now.'` — at least it
    gives a real alternative.
  See Blockers.

- ⚠️ **No truncated/overflowing strings on the smallest supported viewport.**
  `test/screens/overflow_smoke_test.dart` is a real, valuable guard — 37 screens × 320/375/414 with
  Ahem (worst-case wide glyphs), `devicePixelRatio` pinned to 1.0. That is genuinely better than
  most apps. Its blind spots are the two called out above: **English only** (`:231`) and **scaler
  1.0 only**, i.e. neither the 2.14× Hindi button labels nor the app's own 1.4× cap is exercised.

- ✅ **Brand/product name spelled and cased consistently everywhere.**
  In-app: 740 `Housepital`, 7 `HOUSEPITAL` (all deliberate wordmark/letterhead —
  `splash_screen.dart:36`, `invoice_pdf_service.dart:49`, `handover_report_service.dart:135`, plus
  document-ID references in `staff_roles_seed.dart`), 37 lowercase — **all** of which are technical
  identifiers (`housepital_cache_`, `housepital-patient` Firebase project, PDF filename slug), none
  user-facing. One email address app-wide: `wecare@housepital.in` (4 uses). Tagline is consistent
  across `splash_screen.dart:46`, `home_screen.dart:543`, `about_screen.dart:54`, `en.json:3`.
  *(The Android launcher-label defect is filed under §8 as a store-metadata issue, not an in-app
  brand-casing one.)*

---

## Blockers (must fix before release)

**B-1 — Placeholder phone numbers are dialable from Help and from staff verification.**
`lib/screens/settings/help_faq_screen.dart:352` (`tel:+919999999999`), `:365`
(`wa.me/919999999999`), `lib/screens/my_care/staff_otp_verification_screen.dart:352`
(`tel:+918888888888`). A family that taps "Call" from Help & FAQ, or "Call Support" when they cannot
verify the nurse standing at their door, reaches a dead number.
**Fix:** replace all three with `AppConstants.supportPhone`; add a grep guard to
`scripts/check_design_consistency.sh` for `9{7,}|8{7,}` inside `tel:`/`wa.me` literals.

**B-2 — SOS "Book Housepital Ambulance" does not book an ambulance.**
`lib/screens/sos/sos_screen.dart:89-91` renders title `'Book Housepital Ambulance'` / subtitle
`'Request ACLS ambulance dispatch'`, but `_bookAmbulance` (`:192-194`) navigates to
`/raise-concern` — a general support-ticket form. The code comment (`:186-191`) documents the
fallback honestly, but the **user-facing copy does not**. On an emergency screen, copy that promises
dispatch and delivers a ticket form is the worst possible failure mode.
**Fix (copy-only, ships today):** retitle to `'Request ambulance callback'` / subtitle `'We'll call
you back to arrange dispatch — for an immediate ambulance, call 112 above.'`

**B-3 — "Medical Emergency — Call Ambulance" and "Staff Emergency" dial the same number.**
`lib/config/constants.dart:17,19` — `emergencyPhone` and `supportPhone` are both `'9990911911'`.
The SOS screen presents them as two distinct escalation paths
(`sos_screen.dart:51-67`: `sos_medical` → "Medical Emergency — Call Ambulance" vs `sos_staff` →
"Alert Housepital Ops"). Either the copy is wrong or the routing is.
**Fix:** if one line genuinely serves both, merge the two options into one and say so; otherwise set
a real ambulance number on `emergencyPhone`.

**B-4 — Two contradictory vital-safety classifiers run on the same screen.**
`lib/utils/helpers.dart:7-24` (`VitalHelper`, thresholds from `AppConstants.vitalRanges`,
`constants.dart:32-39`) and `lib/utils/vital_classifier.dart:24-76` (`classifyVital`) disagree:
- SpO₂ **91 %** → `VitalHelper` = *borderline* (low = 90); `classifyVital` = **red** (< 92)
- Blood sugar **190** → `VitalHelper` = *alert* (high = 180); `classifyVital` = **yellow** (140–200)

Both are live in `lib/screens/reports/vitals_screen.dart` — `:548` uses `VitalHelper` to print
"Outside safe range on N occasions", `:696` uses `classifyVital` for the entry-sheet status row —
and `lib/screens/my_care/my_care_screen.dart:381` uses `classifyVital`. A family can enter an SpO₂ of
91, see "Needs attention" in the sheet, then read on the same screen that the reading was never
outside safe range.
**Fix:** delete `VitalHelper.getVitalColor/getVitalStatus` and `AppConstants.vitalRanges`; route
`vitals_screen.dart:548` through `classifyVital`. `test/utils/vital_ranges_test.dart` and
`vital_classification_test.dart` already exist to catch regressions.

**B-5 — iOS camera/photo-library purpose strings are missing.**
`ios/Runner/Info.plist` has no `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`, yet
`image_picker` is invoked from five screens (`document_repository_screen.dart:614,632`,
`raise_concern_screen.dart:77,85`, `return_screen.dart:316`, `chat_screen.dart:122`,
`patient_profile_screen.dart:190,195`). Hard crash on tap + guaranteed App Store rejection.

---

## High

**H-1 — Payment-reminder copy threatens care interruption, and contradicts the in-app card.**
`lib/services/payment_reminder_service.dart:126` is commented **"Airtel-style"** and reads as telecom
dunning to a family whose relative may be ventilated at home:
`:139` "Pay now to avoid service interruption." · `:143` title "Payment due tomorrow**!**" ·
`:149` "Pay now to continue uninterrupted service." · `:154` "Late charges may apply. Pay now."
This directly contradicts the in-app overdue card, which gets it exactly right —
`lib/screens/home/home_screen.dart:1578-1580` renders "**Your care continues uninterrupted.**" with
the comment "firm ask, calm tone: lateness never reads as a threat to the patient's care."
The exclamation mark also violates the app's own voice rule (`lib/widgets/empty_state.dart:5`).
*Mitigating:* `getReminderMessages` is currently **unwired** (`rg -n "getReminderMessages" lib` finds
only the definition) — this copy is latent, not live. `PaymentReminder.urgencyLabel` (`:46-52`) **is**
live at `payment_methods_screen.dart:305`.
**Fix:** rewrite the four bodies in the home-card voice before wiring notifications — e.g. "₹X for
{service} is due on {date}. Your care continues either way — pay when you can."

**H-2 — Legal consent is presented only in English.**
`agree_terms` is fully translated in both JSONs, yet `lib/screens/rental/rental_agreement_screen.dart:96`
hardcodes the English, and the six contract clauses at `:74-85` have no keys at all. Same at
`lib/screens/auth/login_screen.dart:209-240`. A Hindi-preferring family agrees to a rental contract
and to the app's Terms in a language the app knows they didn't choose.

**H-3 — The doctor handover PDF carries no clinical disclaimer.**
`lib/services/handover_report_service.dart:275-277` closes with only "Compiled by the Housepital
patient app from supervisor-synced records. This is a computer-generated document." Every article
carries a proper disclaimer; the one document that goes to a treating clinician does not.
**Fix:** append the article disclaimer's sibling — "Compiled from caregiver-logged and
supervisor-synced records; it is not a clinical record and has not been verified by a physician.
Confirm all values before acting on them."

**H-4 — A red vital says "Needs attention" and stops there.**
`lib/screens/reports/vitals_screen.dart:846-858` — a `'red'` classification renders only
`vital_status_alert` ("Needs attention" / "ध्यान देने की ज़रूरत"). A family entering an SpO₂ of 85 or a
temperature of 103 °F gets a two-word label and a "Save reading" button, with no next step and no
route to the SOS screen or the Health Manager. The articles model the right pattern ("Get urgent help
if: lips or nails turn blue…").
**Fix:** on `'red'`, append a per-vital action line and a "Call your Health Manager" / "Open SOS"
affordance.

**H-5 — Dates and times are locale-blind, and the Hindi locale is untested end to end.**
No `Intl.defaultLocale` / `initializeDateFormatting` anywhere; 12 raw `DateFormat` calls in the Care
Calendar; four hand-rolled month arrays; three competing time formats (one of them 24-hour, in chat).
Zero tests instantiate `Locale('hi')`.

**H-6 — Three support phone numbers, one of them another company's.**
`AppConstants.supportPhone = 9990911911` (`constants.dart:19`) vs `+91-90502-00183` presented as
"our coordinator" at `lib/screens/billing/payment_methods_screen.dart:355,364,374` and
`lib/screens/support/staff_replacement_screen.dart:227`. That second number is **Dai Maa's**
(`lib/config/daimaa_theme.dart:16,23,24`) — a business CLAUDE.md defines as separate.

**H-7 — The Android app is named `housepital_patient` on the home screen.**
`android/app/src/main/AndroidManifest.xml:7`.

---

## Medium / Low

**M-1 — 85 one-line localization wins are already paid for.** 85 keys exist, translated, in both
JSONs, while the screen hardcodes the identical English. Highest-value: `agree_terms`,
`error_occurred`, `no_data_available`, `tagline`, `cancel` (6 files), `retry`, `medications`, `sos`.

**M-2 — Sahayak is a third language that follows neither locale.** Romanized Hinglish regardless of
`locale`, and its breadcrumbs cite English menu labels that don't exist in Hindi mode
(`assistant_executor.dart:292,343,411`, `assistant_service.dart:95-181`).

**M-3 — Invoice money is hand-formatted with no Indian grouping.**
`lib/services/invoice_pdf_service.dart:69` → `Rs 106200` instead of `₹1,06,200`, on the line items,
subtotal, "GST (18%)" and grand total (`:217,230,233,236`).

**M-4 — PDFs cannot render Devanagari.** Neither `invoice_pdf_service.dart` nor
`handover_report_service.dart` loads a font (`rg -n "Font\.|loadFont|theme:"` → no matches), so both
fall back to Helvetica. Any Hindi patient name or caregiver note in a PDF renders as tofu. The
`_ascii()` helpers (`handover_report_service.dart:45-51`, `invoice_pdf_service.dart:73`) normalise
smart quotes and dashes only — they do not catch Devanagari.

**M-5 — Pluralization.** 5 `(s)` sites + 4 "1 weeks/months/years/days" bugs; `AppLocalizations` has
no plural facility. Details in §5.

**M-6 — Duplicate i18n keys with divergent Hindi.** `todays_vitals` vs `today_vitals`
(`आज के विटल्स` / `आज के वाइटल्स`); `borderline` vs `vital_status_borderline`
(`सीमा रेखा` / `सीमा पर`). Plus four consistent-but-redundant pairs.

**M-7 — Raw exception text reaches the user** at `raise_concern_screen.dart:410`,
`patient_profile_screen.dart:297`, `main.dart:768`.

**M-8 — The main vitals chart is silent to screen readers.** `vitals_screen.dart:345`, no
`Semantics`. Compare `vitals_trend_grid.dart:63`.

**M-9 — Disabled CTAs give no reason.** 5 sites; `login_screen.dart:48-60` shows the right pattern.

**M-10 — `frequencyLabel` leaks snake_case onto medication rows.**
`lib/models/medication_models.dart:78`.

**L-1 — 28 of 54 IconButtons have no tooltip.**

**L-2 — `'% off'` vs `'% OFF'`** across 9 sites.

**L-3 — 24 bare spinners, 1 with copy;** the `loading` key is unused.

**L-4 — Money truncated not rounded** at ~10 `formatCurrency(x.toInt())` sites.

**L-5 — Stale contradictory comment.** `lib/config/theme.dart:157` still reads "Dark ink on orange —
white on orange is only ~2.3:1 (fails AA)" directly above `onPrimary: HousepitalColors.onOrange`,
which is **white** per the owner decision recorded in CLAUDE.md. Not user-facing, but it will send
the next auditor down the wrong path.

**L-6 — `'PDF upload coming soon'`** ships at `document_repository_screen.dart:599` (with a workable
email alternative).

**L-7 — 160 unused i18n keys** (85 of them recoverable per M-1; the remaining 75 are dead weight).

---

## BLOCKED-OWNER

1. **App Store / Play Store listing copy accuracy (§8.1).** No `fastlane/metadata`, no listing text
   in the repo. *Need:* the current App Store Connect and Play Console listing text (description,
   subtitle, keywords, screenshot captions) to check it against shipped behaviour — particularly
   whether it claims ambulance booking (B-2) or Hindi language support (which is 13.8 % real).

2. **Privacy policy / Terms body text (§8.3).** Both live only at `https://housepital.in/privacy`
   and `/terms` (`about_screen.dart:100,104`); no in-app copy to audit. *Need:* the published text,
   to verify it matches actual behaviour — specifically camera/photo access (B-5), the medical
   documents stored on-device (`document_repository_screen.dart`), and the Firebase/Razorpay
   third-party data flows.

3. **"What's New" release notes (§8.2).** `docs/CHANGELOG.md` is engineering-facing.
   *Need:* owner sign-off on whether user-facing release notes are drafted outside the repo.

4. **Hindi copy sign-off.** `hi.json` reads as competent, natural Hindi to this auditor's analysis,
   but *Need:* a native Delhi-NCR reviewer to confirm register — particularly the clinical terms
   (`वाइटल्स`, `सीमा रेखा`, `खुराक`) and whether `आप`-form is right for a caregiver addressing a
   parent's care.
