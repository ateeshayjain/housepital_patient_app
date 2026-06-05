// test/screens/settings/add_patient_screen_test.dart
//
// Tests AddPatientScreen (PR #10):
//   - all required form fields render
//   - empty form → field-level errors shown on submit
//   - valid form → app.addPatient() called with correct args, primary-contact SnackBar shown
//   - condition chips: tapping a suggestion adds it; tapping the delete icon removes it
//   - relationship dropdown has all 7 options
//   - city dropdown has all 5 NCR cities

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/providers/app_provider.dart';
import 'package:housepital_patient/screens/settings/add_patient_screen.dart';
import 'package:housepital_patient/services/api_service.dart';

// ── Recording test provider that captures the last added patient ────────────

class _RecordingAppProvider extends AppProvider {
  _RecordingAppProvider() : super(ApiService());

  Patient? lastAdded;
  int addCalls = 0;

  @override
  Future<void> addPatient(Patient patient) async {
    addCalls++;
    lastAdded = patient;
    notifyListeners();
  }
}

Widget _host(AppProvider app) {
  return MaterialApp(
    home: ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: const AddPatientScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAppProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = _RecordingAppProvider();
    await Future<void>.delayed(Duration.zero);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Form rendering
  // ───────────────────────────────────────────────────────────────────────────
  group('AddPatientScreen — form rendering', () {
    testWidgets('renders all required form fields', (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Section headings
      expect(find.text('Basic Info'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Conditions'), findsOneWidget);

      // Field labels
      expect(find.text('Patient Name'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Relationship to you'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Add condition'), findsOneWidget);

      // Action buttons (Save in app bar + bottom "Add Patient")
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Add Patient'), findsNWidgets(2)); // AppBar title + button label
    });

    testWidgets('renders intro card explaining primary-contact behaviour',
        (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('primary contact'),
        findsOneWidget,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Validation
  // ───────────────────────────────────────────────────────────────────────────
  group('AddPatientScreen — validation', () {
    testWidgets('empty form submit shows field-level errors', (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Tap the bottom "Add Patient" submit button.
      final addBtn = find.widgetWithText(ElevatedButton, 'Add Patient');
      await tester.scrollUntilVisible(
        addBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Both name and age errors must surface.
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Age is required'), findsOneWidget);

      // addPatient should NOT have been called.
      expect(provider.addCalls, 0);
    });

    testWidgets('non-numeric age shows "Must be a number" error', (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Patient Name'),
          'Test Patient');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Age'), 'abc');

      final addBtn = find.widgetWithText(ElevatedButton, 'Add Patient');
      await tester.scrollUntilVisible(
        addBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Must be a number'), findsOneWidget);
      expect(provider.addCalls, 0);
    });

    testWidgets('age > 150 shows "Invalid age" error', (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Patient Name'),
          'Old Patient');
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '200');

      final addBtn = find.widgetWithText(ElevatedButton, 'Add Patient');
      await tester.scrollUntilVisible(
        addBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Invalid age'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Successful submit
  // ───────────────────────────────────────────────────────────────────────────
  group('AddPatientScreen — successful submit', () {
    testWidgets('valid form submission calls addPatient with correct args',
        (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Patient Name'), 'Ramesh Kumar');
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '72');

      final addBtn = find.widgetWithText(ElevatedButton, 'Add Patient');
      await tester.scrollUntilVisible(
        addBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(provider.addCalls, 1);
      final p = provider.lastAdded!;
      expect(p.name, 'Ramesh Kumar');
      expect(p.age, 72);
      // Defaults from the form
      expect(p.gender, 'male');
      expect(p.city, 'Delhi');
      // Relationship is stashed in `requirement` per the screen's comment.
      expect(p.requirement, 'Relationship: Parent');
      // ID starts with the expected prefix.
      expect(p.id.startsWith('p_'), isTrue);
    });

    testWidgets(
        'shows SnackBar with primary-contact copy after successful save',
        (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Patient Name'), 'Mum');
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '65');

      final addBtn = find.widgetWithText(ElevatedButton, 'Add Patient');
      await tester.scrollUntilVisible(
        addBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addBtn);
      // First pump to fire the save → second pump to surface the SnackBar.
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('primary contact'),
        findsWidgets,
        reason:
            'SnackBar after successful save must mention primary contact role.',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Condition chips
  // ───────────────────────────────────────────────────────────────────────────
  group('AddPatientScreen — condition chips', () {
    testWidgets(
        'tapping a suggestion ActionChip adds it as a deletable Chip',
        (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Find the "Diabetes" suggestion chip.
      final diabetesSuggestion = find.widgetWithText(ActionChip, 'Diabetes');
      await tester.scrollUntilVisible(
        diabetesSuggestion,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(diabetesSuggestion);
      await tester.pumpAndSettle();

      // After tap, "Diabetes" should now appear as a deletable Chip,
      // and disappear from the suggestion list (filter excludes already-added).
      expect(find.widgetWithText(Chip, 'Diabetes'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Diabetes'), findsNothing);
    });

    testWidgets('tapping the delete icon on a selected chip removes it',
        (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Add a suggestion to the selected list.
      final hyper = find.widgetWithText(ActionChip, 'Hypertension');
      await tester.scrollUntilVisible(
        hyper,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(hyper);
      await tester.pumpAndSettle();

      // Confirm it was added.
      expect(find.widgetWithText(Chip, 'Hypertension'), findsOneWidget);

      // Tap its delete icon (Icons.close inside the Chip).
      final deleteIcon = find.descendant(
        of: find.widgetWithText(Chip, 'Hypertension'),
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // It must be gone from selected list and reappear in suggestions.
      expect(find.widgetWithText(Chip, 'Hypertension'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Hypertension'), findsOneWidget);
    });

    testWidgets('selected conditions land in the submitted Patient.conditions',
        (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Patient Name'), 'Conds Patient');
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '40');

      final diabetes = find.widgetWithText(ActionChip, 'Diabetes');
      await tester.scrollUntilVisible(
        diabetes,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(diabetes);
      await tester.pumpAndSettle();

      final addBtn = find.widgetWithText(ElevatedButton, 'Add Patient');
      await tester.scrollUntilVisible(
        addBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(provider.lastAdded?.conditions, contains('Diabetes'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Dropdown contents — must match the locked option lists in the screen.
  // ───────────────────────────────────────────────────────────────────────────
  group('AddPatientScreen — dropdown contents', () {
    testWidgets('Relationship dropdown has all 7 options', (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Dropdown order on the screen: Gender (idx 0), Relationship (idx 1),
      // City (idx 2). Tap the relationship dropdown by index.
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();

      // All 7 relationship labels must appear in the dropdown menu.
      const expected = [
        'Parent',
        'Spouse',
        'Child',
        'Sibling',
        'Grandparent',
        'In-law',
        'Other',
      ];
      for (final r in expected) {
        expect(find.text(r), findsWidgets,
            reason: 'Expected dropdown to contain "$r".');
      }
    });

    testWidgets('City dropdown has all 5 NCR cities', (tester) async {
      await tester.pumpWidget(_host(provider));
      await tester.pumpAndSettle();

      // Scroll the City dropdown into view first.
      final cityDropdown = find.byType(DropdownButtonFormField<String>).at(2);
      await tester.scrollUntilVisible(
        cityDropdown,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(cityDropdown);
      await tester.pumpAndSettle();

      const expected = ['Delhi', 'Faridabad', 'Gurgaon', 'Noida', 'Ghaziabad'];
      for (final c in expected) {
        expect(find.text(c), findsWidgets,
            reason: 'Expected dropdown to contain "$c".');
      }
    });
  });
}
