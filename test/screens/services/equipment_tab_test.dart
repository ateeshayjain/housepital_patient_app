// test/screens/services/equipment_tab_test.dart
//
// Widget tests for the Blinkit-style Equipment tab browse layout:
// left category rail (derived from `useCase`) + dense 2-column grid.
//
// Items are seeded via EquipmentTab(initialItems: …) so the test never
// touches the network or the bundled JSON asset, and the tab is pumped at
// 320px width (iPhone SE) so the rail + grid combination is also guarded
// against narrow-screen overflow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/config/theme.dart';
import 'package:housepital_patient/models/models.dart';
import 'package:housepital_patient/screens/services/cards/equipment_item_card.dart';
import 'package:housepital_patient/screens/services/tabs/equipment_tab.dart';
import 'package:housepital_patient/screens/services/widgets/equipment_category_rail.dart';

EquipmentItem _item(
  String id,
  String name,
  String useCase, {
  double price = 500,
  double? mrp,
}) =>
    EquipmentItem(
      id: id,
      name: name,
      brand: 'TestBrand',
      category: 'Equipment',
      availableForSale: true,
      price: price,
      mrp: mrp,
      useCase: useCase,
    );

final List<EquipmentItem> _fakeCatalog = [
  _item('r1', 'Oxygen Concentrator', 'Respiratory', mrp: 600),
  _item('r2', 'Nebulizer', 'Respiratory'),
  _item('r3', 'Pulse Oximeter', 'Respiratory'),
  _item('o1', 'Knee Brace', 'Orthopaedic'),
  _item('o2', 'Cervical Collar', 'Orthopaedic'),
  _item('c1', 'BP Monitor', 'Cardiac & Vascular'),
  _item('h1', 'Hand Sanitizer', 'Hygiene & Sanitation'),
  _item('g1', 'Tissue Box', 'Housekeeping & Pantry'), // folds into 'Other'
];

Widget _harness() => MaterialApp(
      theme: HousepitalTheme.lightTheme,
      home: Scaffold(body: EquipmentTab(initialItems: _fakeCatalog)),
    );

void main() {
  // Real narrow-phone surface (iPhone SE) — also acts as an overflow guard.
  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
  }

  group('EquipmentTab Blinkit-style rail', () {
    testWidgets('rail renders All + at least 3 categories', (tester) async {
      await pumpTab(tester);

      expect(find.byType(EquipmentCategoryRail), findsOneWidget);
      final rail = find.descendant(
        of: find.byType(EquipmentCategoryRail),
        matching: find.byType(Text),
      );
      final labels =
          rail.evaluate().map((e) => (e.widget as Text).data).toList();

      expect(labels, contains('All'));
      expect(labels, contains('Respiratory'));
      expect(labels, contains('Ortho Support'));
      expect(labels, contains('Cardiac'));
      expect(labels, contains('Other'));
      // 'All' + at least 3 real categories
      expect(labels.length, greaterThanOrEqualTo(4));

      // No RenderFlex overflow at 320px width.
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a rail category filters the grid', (tester) async {
      await pumpTab(tester);

      // All items visible initially (grid may virtualise, so allow >=).
      expect(
          find.byType(EquipmentItemCard, skipOffstage: false), findsWidgets);

      await tester.tap(find.descendant(
        of: find.byType(EquipmentCategoryRail),
        matching: find.text('Respiratory'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentItemCard, skipOffstage: false),
          findsNWidgets(3));
      expect(find.text('Oxygen Concentrator'), findsOneWidget);
      expect(find.text('Knee Brace'), findsNothing);

      // Narrower group: single item.
      await tester.tap(find.descendant(
        of: find.byType(EquipmentCategoryRail),
        matching: find.text('Cardiac'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentItemCard, skipOffstage: false),
          findsNWidgets(1));
      expect(find.text('BP Monitor'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('rail grouping pure functions', () {
    test('railCategoryForItem uses useCase and folds generic buckets', () {
      expect(railCategoryForItem(_item('a', 'X', 'Respiratory')),
          'Respiratory');
      expect(railCategoryForItem(_item('b', 'Y', 'Housekeeping & Pantry')),
          kEquipmentRailOther);
      expect(
          railCategoryForItem(EquipmentItem(
              id: 'c', name: 'Z', brand: 'B', category: 'Equipment')),
          kEquipmentRailOther);
    });

    test('buildRailCategories: All first, by count desc, Other last', () {
      final cats = buildRailCategories(_fakeCatalog);
      expect(cats.first, 'All');
      expect(cats.last, kEquipmentRailOther);
      expect(cats[1], 'Respiratory'); // largest group (3 items)
      expect(cats[2], 'Orthopaedic'); // 2 items
    });
  });
}
