// test/screens/services/equipment_tab_test.dart
//
// Widget tests for the Blinkit-style Equipment tab browse layout:
// left category rail (derived from `useCase`) + dense 2-column grid.
//
// Items are seeded via EquipmentTab(initialItems: …) so the test never
// touches the network or the bundled JSON asset, and the tab is pumped at
// 320px width (iPhone SE) so the rail + grid combination is also guarded
// against narrow-screen overflow.

import 'dart:math' as math;

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

  // Round-2 owner field report ("the left menu is still not fixed"):
  // the rail read as floating disconnected blobs because (a) the Stack's
  // default topStart alignment left-aligned short-label tiles ('All' centre
  // x=28 vs 39.5 for wide-label entries — per-item horizontal jitter) and
  // (b) the spacing was airy/irregular. These tests pin the Blinkit-style
  // geometry to exact numbers so it can't regress: 44px tile, 4px tile→label
  // gap, 14px between items, one shared vertical axis, accent bar spanning
  // exactly the tile, and the last entry fully clear of the floating orange
  // pill nav after scrolling to the end (real iPhone bottom inset simulated).
  group('rail density, axis & pill-nav clearance (375x667, inset 34)', () {
    // 9 distinct rail groups so the rail is guaranteed to scroll at 667px.
    final tallCatalog = <EquipmentItem>[
      ..._fakeCatalog,
      _item('m1', 'Manual Hospital Bed', 'Mobility & Patient Comfort'),
      _item('w1', 'Dressing Kit', 'Post-Surgical & Wound Care'),
      _item('d1', 'Thermometer', 'Diagnostics & Monitoring'),
      _item('n1', 'TENS Unit', 'Neurological & Physiotherapy'),
    ];

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      // iPhone home-indicator inset — the floating pill nav floats above it.
      tester.view.padding = FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      // Mirrors the real shell: MainShell Scaffold (extendBody + floating
      // pill in the bottomNavigationBar slot) hosting the inner catalog
      // Scaffold (app bar, no bottom nav) whose body is the Equipment tab.
      await tester.pumpWidget(MaterialApp(
        theme: HousepitalTheme.lightTheme,
        home: Builder(builder: (context) {
          return Scaffold(
            extendBody: true,
            body: Scaffold(
              appBar: AppBar(title: const Text('Services')),
              body: EquipmentTab(initialItems: tallCatalog),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16,
                  math.max(MediaQuery.of(context).padding.bottom, 8.0)),
              child: const SizedBox(key: Key('nav-pill'), height: 64),
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();
    }

    Finder railTiles(Finder rail) => find.descendant(
          of: rail,
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.constraints ==
                  BoxConstraints.tightFor(
                      width: kEquipmentRailTileSize,
                      height: kEquipmentRailTileSize)),
        );

    testWidgets('tiles share one vertical axis with tight, even spacing',
        (tester) async {
      await pumpShell(tester);

      final rail = find.byType(EquipmentCategoryRail);
      final tiles = railTiles(rail);
      final labels = find.descendant(of: rail, matching: find.byType(Text));
      final tileCount = tiles.evaluate().length;
      expect(tileCount, greaterThanOrEqualTo(5));
      expect(labels.evaluate().length, tileCount,
          reason: 'every tile pairs with exactly one label');

      final railCenterX = tester.getRect(rail).center.dx;
      for (var i = 0; i < tileCount; i++) {
        final tile = tester.getRect(tiles.at(i));
        final label = tester.getRect(labels.at(i));

        // AXIS: every tile + label optically centred on the rail column —
        // the selected accent bar overlays and must never push tiles off.
        expect(tile.center.dx, moreOrLessEquals(railCenterX, epsilon: 1.0),
            reason: 'tile $i off the rail axis');
        expect(label.center.dx, moreOrLessEquals(railCenterX, epsilon: 1.0),
            reason: 'label $i off the rail axis');

        // DENSITY: 44px tile, label directly beneath with a 4px gap.
        expect(tile.height,
            moreOrLessEquals(kEquipmentRailTileSize, epsilon: 0.01));
        expect(label.top - tile.bottom,
            moreOrLessEquals(kEquipmentRailTileLabelGap, epsilon: 0.01),
            reason: 'label $i must sit directly beneath its tile');

        // RHYTHM: exactly 14px between items (label bottom → next tile top).
        if (i + 1 < tileCount) {
          final nextTile = tester.getRect(tiles.at(i + 1));
          expect(nextTile.top - label.bottom,
              moreOrLessEquals(2 * kEquipmentRailEntryVPad, epsilon: 0.01),
              reason: 'gap between item $i and ${i + 1} must be 14px');
        }
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('selected accent bar spans exactly the tile extent',
        (tester) async {
      await pumpShell(tester);

      final rail = find.byType(EquipmentCategoryRail);
      final bar = find.descendant(
        of: rail,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints ==
                BoxConstraints.tightFor(
                    width: 3, height: kEquipmentRailTileSize)),
      );
      expect(bar, findsOneWidget, reason: 'one accent bar on the selection');

      // 'All' is selected on first build — its tile is the first one.
      final barRect = tester.getRect(bar);
      final tileRect = tester.getRect(railTiles(rail).first);
      expect(barRect.top, moreOrLessEquals(tileRect.top, epsilon: 0.01),
          reason: 'accent bar top must align with the tile top');
      expect(barRect.bottom, moreOrLessEquals(tileRect.bottom, epsilon: 0.01),
          reason: 'accent bar bottom must align with the tile bottom');
      expect(barRect.left, moreOrLessEquals(tester.getRect(rail).left, epsilon: 1.0),
          reason: 'accent bar hugs the rail left edge');
    });

    testWidgets(
        'rail divider runs full content height and the last entry scrolls '
        'fully clear of the floating pill nav', (tester) async {
      await pumpShell(tester);

      final rail = find.byType(EquipmentCategoryRail);
      final railRect = tester.getRect(rail);
      final pillRect = tester.getRect(find.byKey(const Key('nav-pill')));

      // AXIS: the rail (and its right divider border) stretches to the very
      // bottom of the body — no gap where the divider stops short.
      expect(railRect.bottom, 667,
          reason: 'rail must stretch under the extendBody pill nav');

      // CLIPPING: the rail must actually need to scroll at this size…
      final scrollable =
          find.descendant(of: rail, matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0),
          reason: 'tall catalog must overflow a 667px viewport');

      // …and once scrolled to the end, the last entry ('Other') must sit
      // fully ABOVE the floating pill, not hidden underneath it.
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final lastLabel = tester.getRect(
          find.descendant(of: rail, matching: find.text('Other')));
      expect(lastLabel.bottom, lessThan(pillRect.top),
          reason: "the last rail entry must clear the pill nav "
              "(owner report: 'Hygiene hides under the bottom nav')");

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
