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
  _item('r3', 'CPAP Machine', 'Respiratory'),
  // Deliberately mislabelled in use_case — the name-keyword override must
  // re-file it under 'Cardiac & Vascular'.
  _item('c2', 'Pulse Oximeter', 'Respiratory'),
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
  Future<void> pumpTab(WidgetTester tester, {double width = 320}) async {
    tester.view.physicalSize = Size(width, 568);
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

      // Cardiac: BP Monitor (use_case) + Pulse Oximeter (keyword override).
      await tester.tap(find.descendant(
        of: find.byType(EquipmentCategoryRail),
        matching: find.text('Cardiac'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentItemCard, skipOffstage: false),
          findsNWidgets(2));
      expect(find.text('BP Monitor'), findsOneWidget);
      expect(find.text('Pulse Oximeter'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('rail layout & alignment', () {
    for (final width in const [320.0, 375.0]) {
      testWidgets(
          'at ${width.toInt()}px: labels never wrap mid-word and the first '
          'tile top-aligns with the Sale/Rental chips', (tester) async {
        await pumpTab(tester, width: width);

        final rail = find.byType(EquipmentCategoryRail);
        expect(tester.getSize(rail).width, kEquipmentRailWidth);

        // Single-word labels ('Respiratory') stay on ONE line inside a
        // scale-down FittedBox — never 'Respirator / y'. (Tests render Ahem
        // worst-case glyphs, so we assert structure rather than font px; on
        // device, Archivo 'Respiratory' fits the 80px rail unscaled.)
        final respText = tester.widget<Text>(find.descendant(
            of: rail, matching: find.text('Respiratory')));
        expect(respText.maxLines, 1);
        expect(respText.softWrap, isFalse);
        expect(
          find.ancestor(
              of: find.descendant(
                  of: rail, matching: find.text('Respiratory')),
              matching: find.byType(FittedBox)),
          findsWidgets,
        );

        // Multi-word labels wrap naturally onto two lines at full size.
        final orthoText = tester.widget<Text>(find.descendant(
            of: rail, matching: find.text('Ortho Support')));
        expect(orthoText.maxLines, 2);
        expect(
          find.descendant(
              of: rail,
              matching: find.ancestor(
                  of: find.text('Ortho Support'),
                  matching: find.byType(FittedBox))),
          findsNothing,
        );

        // Vertical rhythm: the first rail icon tile (44×44) shares its top
        // edge with the All/Sale/Rental chip pills (32px tall, centred in
        // their 44pt hit row).
        final firstTileTop = tester
            .getRect(find
                .descendant(
                    of: rail,
                    matching: find.byWidgetPredicate((w) =>
                        w is Container &&
                        w.constraints ==
                            const BoxConstraints.tightFor(
                                width: 44, height: 44)))
                .first)
            .top;
        final chipPillTop = tester
            .getRect(find
                .ancestor(
                    of: find.text('All (${_fakeCatalog.length})'),
                    matching: find.byType(Container))
                .first)
            .top;
        expect(firstTileTop, chipPillTop,
            reason: 'rail tiles must top-align with the chip pills');

        expect(tester.takeException(), isNull);
      });
    }
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

    test('name-keyword override beats a wrong useCase', () {
      // The shipped catalog tags wheelchairs/walkers 'Orthopaedic' — the
      // product name must win.
      expect(railCategoryForItem(_item('m1', 'Wheelchair', 'Orthopaedic')),
          'Mobility & Patient Comfort');
      expect(railCategoryForItem(_item('m2', 'Walker', 'Orthopaedic')),
          'Mobility & Patient Comfort');
      expect(railCategoryForItem(_item('m3', 'Commode Chair', 'Hygiene & Sanitation')),
          'Mobility & Patient Comfort');
      expect(railCategoryForItem(_item('r9', 'BiPAP Machine', 'General Care')),
          'Respiratory');
      expect(railCategoryForItem(_item('c9', 'Pulse Oximeter', 'Respiratory')),
          'Cardiac & Vascular');
      // …but an ortho walker *boot* is not a mobility walker.
      expect(
          railCategoryForItem(
              _item('o9', 'Walker Boot Air Short Large', 'Orthopaedic')),
          'Orthopaedic');
    });

    test('buildRailCategories: All first, by count desc, Other last', () {
      final cats = buildRailCategories(_fakeCatalog);
      expect(cats.first, 'All');
      expect(cats.last, kEquipmentRailOther);
      expect(cats[1], 'Respiratory'); // largest group (3 items)
      // 2-item tie broken alphabetically.
      expect(cats[2], 'Cardiac & Vascular');
      expect(cats[3], 'Orthopaedic');
    });
  });
}
