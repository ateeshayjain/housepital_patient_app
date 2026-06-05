# Home Layout B Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorder the Home screen so the condensed Health Team (Health Manager + on-duty staff) appears first and the hero banner is demoted to the bottom, eliminating wasted top space.

**Architecture:** Pure reordering + light restructuring inside the single existing file `lib/screens/home/home_screen.dart`. No new files, no new dependencies, no data-layer changes. The greeting collapses to one line; the existing `_buildHealthTeamCard` moves above the hero; `_buildHeroBanner` moves to the bottom of the scroll column.

**Tech Stack:** Flutter/Dart, Provider (`AppProvider`), existing `home_screen.dart` widgets.

**Base branch:** new feature branch `feat/home-layout-b` off the current working branch.

---

## File Structure

- **Modify:** `lib/screens/home/home_screen.dart`
  - `build()` scroll column (lines ~141-201): new child order
  - `_buildGreeting` (lines ~630-665): collapse badge + name to one row, drop the standalone subtitle line
- **Modify (if needed):** `test/screens/home/` widget tests that assert section order
- **Test:** `test/screens/home/home_layout_test.dart` (new — asserts the new order)

---

## Task 1: Pin current behavior with a characterization test

**Files:**
- Test: `test/screens/home/home_layout_test.dart` (create)

- [ ] **Step 1: Write a widget test that pumps HomeScreen with demo data and asserts the Health Team card renders ABOVE the hero banner.**

Use the existing test harness pattern (see other `test/screens/home/*` tests for provider setup with `MockApiService`/demo data). Assert via `tester.getTopLeft()` Y-coordinate: the "Your Health Team" text appears at a smaller `dy` than the hero banner's first slide title.

```dart
testWidgets('Health Team card renders above the hero banner', (tester) async {
  await _pumpHome(tester); // helper that wires AppProvider with demo data + sized surface
  final teamY = tester.getTopLeft(find.text('Your Health Team')).dy;
  final heroFinder = find.textContaining('ICU Setup'); // hero slide copy
  expect(heroFinder, findsWidgets);
  final heroY = tester.getTopLeft(heroFinder.first).dy;
  expect(teamY, lessThan(heroY), reason: 'Layout B: team must be above hero');
});
```

- [ ] **Step 2: Run it — expect FAIL** (current order has hero above team).

Run: `flutter test test/screens/home/home_layout_test.dart -v`
Expected: FAIL (`teamY` is greater than `heroY` today).

- [ ] **Step 3: Commit the failing test.**

```bash
git add test/screens/home/home_layout_test.dart
git commit -m "test: characterize Home Layout B order (failing)"
```

---

## Task 2: Collapse the greeting to one line

**Files:**
- Modify: `lib/screens/home/home_screen.dart` (`_buildGreeting`, ~630-665)

- [ ] **Step 1: Rewrite `_buildGreeting`** so the name + role badge sit on ONE `Row` (badge trailing the name), and remove the standalone "Here's your care summary" subtitle line (it's the main space-waster). Keep the role badge widget (`_buildRoleBadge`) — just move it inline.

```dart
Widget _buildGreeting(BuildContext context, AppProvider app) {
  final firstName = (app.currentPatient?.name ?? 'there').split(' ').first;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Flexible(
          child: Text(
            'Hi $firstName!',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HousepitalColors.orangeText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildRoleBadge(app.currentUserRole),
      ],
    ),
  );
}
```

- [ ] **Step 2: Run `flutter analyze lib/screens/home/home_screen.dart`** — expect 0 errors.

Run: `flutter analyze lib/screens/home/home_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit.**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(home): collapse greeting + role badge to one line"
```

---

## Task 3: Reorder the scroll column (team first, hero last)

**Files:**
- Modify: `lib/screens/home/home_screen.dart` (`build()` column, ~141-201)

- [ ] **Step 1: Reorder the `Column` children** to this exact sequence. Remove `_buildHeroBanner(context)` from its current position (line ~142) and add it at the very bottom (after Payments, before the trailing `SizedBox(height: 24)`).

```dart
children: [
  _buildHeader(context, l, app),
  _buildGreeting(context, app),
  if (app.isDashboardLoading)
    const Padding(padding: EdgeInsets.all(48), child: LoadingWidget())
  else ...[
    // PATIENT_SELF keeps its call-caregiver card on top (per design).
    if (isPatientSelf) _buildCallCaregiverCard(context, app),

    // 1. Health Team — now FIRST.
    _sectionLabel('Your Health Team', onSeeAll: () => MainShell.switchToTab(1)),
    _buildHealthTeamCard(context, l, app),
    const SizedBox(height: 8),

    // 2. Current Services
    if (app.activeDeployment != null) ...[
      _sectionLabel('Current Services', onSeeAll: () => MainShell.switchToTab(1)),
      _buildActiveServicesQuickView(context, l, app),
      const SizedBox(height: 8),
    ],

    // 3. Today's Vitals
    if (app.latestVitals != null) ...[
      _sectionLabel("Today's Vitals", onSeeAll: () => Navigator.pushNamed(context, '/vitals')),
      _buildVitalsStrip(app),
      const SizedBox(height: 8),
    ],

    _buildMedicationsSnippet(context),
    const SizedBox(height: 8),

    if (canBook) ...[
      _sectionLabel('Book Services', onSeeAll: () => MainShell.switchToTab(2)),
      _buildQuickActionsGrid(context, l),
      const SizedBox(height: 8),
      _buildDaiMaaEntry(context),
      const SizedBox(height: 8),
    ],

    if (app.todayReport != null) ...[
      _sectionLabel("Today's Report", onSeeAll: () => Navigator.pushNamed(context, '/report-detail', arguments: app.todayReport)),
      _buildReportSnippet(app),
      const SizedBox(height: 8),
    ],

    if (canUserPerform(role, UserAction.pay))
      _buildPaymentCards(context, app),

    const SizedBox(height: 12),

    // Hero banner — DEMOTED to the bottom as a promo surface.
    _buildHeroBanner(context),

    const SizedBox(height: 24),
  ],
],
```

- [ ] **Step 2: Run the layout test from Task 1 — expect PASS now.**

Run: `flutter test test/screens/home/home_layout_test.dart -v`
Expected: PASS (`teamY < heroY`).

- [ ] **Step 3: Run analyze.**

Run: `flutter analyze lib/screens/home/home_screen.dart`
Expected: No issues.

- [ ] **Step 4: Commit.**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(home): Layout B — health team first, hero demoted to bottom"
```

---

## Task 4: Condense the Health Team card to manager + on-duty staff

**Files:**
- Modify: `lib/screens/home/home_screen.dart` (`_buildHealthTeamCard`, ~670+)

- [ ] **Step 1: Write a test** asserting that with an active deployment, the card shows the Health Manager row and the on-duty staff row, and that the header reads "Your Health Team". (The doctor row stays only if `doctorName` is present — keep existing conditional.) This largely already holds; the test guards against regression.

```dart
testWidgets('Health Team card shows manager + on-duty staff', (tester) async {
  await _pumpHome(tester);
  expect(find.text('Your Health Team'), findsOneWidget);
  expect(find.text('Health Manager'), findsOneWidget);   // role label
  expect(find.textContaining('Nurse'), findsWidgets);    // on-duty staff role
});
```

- [ ] **Step 2: Run it.** If it already passes, no code change needed — the existing `_buildHealthTeamCard` already renders this shape. If it fails, trim any extra rows beyond manager + on-duty staff (+ optional doctor) so the card stays compact.

Run: `flutter test test/screens/home/home_layout_test.dart -v`
Expected: PASS.

- [ ] **Step 3: Commit (only if code changed).**

```bash
git add lib/screens/home/home_screen.dart test/screens/home/home_layout_test.dart
git commit -m "test(home): guard condensed health team card content"
```

---

## Task 5: Full verification + integration

- [ ] **Step 1: Run the whole home test folder.**

Run: `flutter test test/screens/home/`
Expected: all pass. If a pre-existing test asserted the OLD order (hero above team), update it to the new order and note why in the commit.

- [ ] **Step 2: Run the full suite.**

Run: `flutter test`
Expected: 1336+ passing (the new layout test added), 0 failing.

- [ ] **Step 3: Analyze whole project.**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Web smoke (fast visual check).**

Run: `flutter run -d chrome --dart-define=RAZORPAY_KEY=rzp_test_XXXXXXXXXX`
Expected: Home opens with greeting+badge one line, Health Team card first, hero at the bottom. (iOS sim also valid now that Firebase is wired.)

- [ ] **Step 5: Final commit if any test updates were needed.**

```bash
git add -A
git commit -m "test(home): update existing home tests for Layout B order"
```

---

## Done criteria
- `flutter analyze` = 0 issues
- `flutter test` green, includes new layout-order test
- Home renders Layout B (greeting one line → team first → … → hero last)
- PATIENT_SELF still gets the call-caregiver card on top
