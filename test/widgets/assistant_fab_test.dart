// test/widgets/assistant_fab_test.dart
//
// Unit / widget tests for AssistantFab — the floating ✨ button that opens
// the AI assistant from every screen. Tests verify:
//   - renders with the expected icon
//   - meets the 44pt WCAG 2.5.5 minimum touch target
//   - taps navigate to the /assistant route

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:housepital_patient/providers/assistant_provider.dart';
import 'package:housepital_patient/services/assistant_service.dart';
import 'package:housepital_patient/screens/assistant/assistant_executor.dart';
import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/services/voice_service.dart';
import 'package:housepital_patient/utils/permissions.dart';
import 'package:housepital_patient/data/demo_data.dart';
import 'package:housepital_patient/widgets/assistant_fab.dart';

Widget _host({required Widget child}) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      return MaterialPageRoute(
        builder: (_) => Scaffold(body: Text(settings.name ?? 'target')),
        settings: settings,
      );
    },
    home: Scaffold(
      floatingActionButton: ChangeNotifierProvider<AssistantProvider>(
        create: (_) => AssistantProvider(
          service: AssistantService(),
          executor: AssistantExecutor(
            api: ApiService(),
            role: UserRole.primaryContact,
            patientId: DemoData.patient.id,
            contacts: {},
          ),
          voice: NoopVoiceService(),
          patientId: DemoData.patient.id,
          role: UserRole.primaryContact,
          locale: 'hi',
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AssistantFab renders with the sparkle icon', (tester) async {
    await tester.pumpWidget(_host(child: const AssistantFab()));
    // The FAB uses the auto_awesome (sparkle) icon.
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('AssistantFab meets 44pt minimum touch-target', (tester) async {
    await tester.pumpWidget(_host(child: const AssistantFab()));
    // AssistantFab is a custom glass control (Material + InkWell), not a
    // stock FloatingActionButton — measure the tappable surface itself.
    final fab = find.descendant(
      of: find.byType(AssistantFab),
      matching: find.byType(InkWell),
    );
    expect(fab, findsOneWidget);
    final size = tester.getSize(fab);
    // WCAG 2.5.5: interactive elements must be at least 44×44 logical pixels.
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('AssistantFab tap navigates to /assistant', (tester) async {
    String? pushedRoute;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('assistant')),
          );
        },
        home: Scaffold(
          floatingActionButton: ChangeNotifierProvider<AssistantProvider>(
            create: (_) => AssistantProvider(
              service: AssistantService(),
              executor: AssistantExecutor(
                api: ApiService(),
                role: UserRole.primaryContact,
                patientId: DemoData.patient.id,
                contacts: {},
              ),
              voice: NoopVoiceService(),
              patientId: DemoData.patient.id,
              role: UserRole.primaryContact,
              locale: 'hi',
            ),
            child: const AssistantFab(),
          ),
          body: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.byType(AssistantFab));
    await tester.pumpAndSettle();
    expect(pushedRoute, '/assistant');
  });

  testWidgets('AssistantFab has accessible Semantics label', (tester) async {
    await tester.pumpWidget(_host(child: const AssistantFab()));
    // The Semantics wrapper is on the outer widget, not the FAB itself.
    // Find a Semantics node with the expected label in the tree.
    final semanticsHandle = tester.ensureSemantics();
    final allSemantics = tester.getSemantics(find.byType(AssistantFab));
    // The 'Open assistant' label is set on the Semantics wrapper.
    expect(allSemantics.label, isNotEmpty);
    semanticsHandle.dispose();
  });
}
