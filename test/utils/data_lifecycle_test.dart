// test/utils/data_lifecycle_test.dart
//
// Round-4 DATA_LIFECYCLE findings that are code-shaped. The module has 30
// Fails; most need a backend and a retention decision. These are the ones
// that do not.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/image_privacy.dart';

String code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('sanitised photo copies do not accumulate forever', () {
    // stripMetadata re-encodes every picked image to a temp directory and
    // returns its path. Nothing deleted it — so the fix that strips GPS out
    // of a wound photo also left a full-resolution copy of that photo in the
    // OS temp area, once per pick, indefinitely. The metadata was gone and
    // the image was not.
    final src = code('lib/utils/image_privacy.dart');

    test('a purge runs before each new copy is written', () {
      expect(src, contains('await purgeStale()'));
    });

    test('both a staleness purge and a full purge exist', () {
      expect(src, contains('static Future<void> purgeStale()'));
      expect(src, contains('static Future<void> purgeAll()'));
    });

    test('purging only ever touches directories this class created', () {
      expect(src, contains("_tempPrefix = 'hpl_img_'"));
      expect(src, contains('if (!name.startsWith(_tempPrefix)) continue;'),
          reason: 'a purge that can reach outside its own prefix is a delete '
              'loop over the OS temp directory');
    });

    test('a purge failure is never fatal', () {
      // Housekeeping must not break a photo attachment.
      expect(src, contains('} catch (_) {'));
      expect(src, contains('Log.warn('));
    });

    // Plain `test`, not `testWidgets`: these do real filesystem I/O, and the
    // widget binding's fake clock never advances for it — the first version
    // hung here rather than failing.
    test('purgeAll removes only hpl_img_ directories', () async {
      final mine = await Directory.systemTemp.createTemp('hpl_img_');
      await File('${mine.path}/photo.jpg').writeAsBytes([1, 2, 3]);
      final notMine = await Directory.systemTemp.createTemp('unrelated_');
      await File('${notMine.path}/keep.txt').writeAsString('keep');
      addTearDown(() {
        if (notMine.existsSync()) notMine.deleteSync(recursive: true);
        if (mine.existsSync()) mine.deleteSync(recursive: true);
      });

      await ImagePrivacy.purgeAll();

      expect(mine.existsSync(), isFalse, reason: 'our copy must be gone');
      expect(notMine.existsSync(), isTrue,
          reason: 'anything we did not create must be untouched');
    });

    test('purgeStale spares a copy that is still fresh', () async {
      final fresh = await Directory.systemTemp.createTemp('hpl_img_');
      addTearDown(() {
        if (fresh.existsSync()) fresh.deleteSync(recursive: true);
      });

      await ImagePrivacy.purgeStale();

      expect(fresh.existsSync(), isTrue,
          reason: 'deleting a copy the caller is still holding would break '
              'the upload that just asked for it');
    });
  });

  group('the photos are patient-scoped and wiped like everything else', () {
    test('SessionScope purges them', () {
      // Photographs taken inside one patient's home. They belong in the same
      // wipe as vitals and medications, and were in no wipe at all.
      final src = code('lib/utils/session_scope.dart');
      expect(src, contains('ImagePrivacy.purgeAll()'));
    });
  });

  group('the deletion notice describes stores that exist', () {
    test('it no longer promises to delete documents', () {
      // No document is ever stored — document_repository_screen.dart says
      // "PDF upload coming soon. Email your documents to wecare@..." So the
      // notice described a store the app does not have, which is a promise
      // that cannot be kept and cannot be audited.
      for (final f in const ['assets/i18n/en.json', 'assets/i18n/hi.json']) {
        final m = jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>;
        final line = m['delete_account_removed_3'] as String;
        expect(line.toLowerCase(), isNot(contains('document')), reason: f);
        expect(line.trim(), isNotEmpty);
      }
    });

    test('the retained-data exceptions are still disclosed', () {
      // Narrowing the promise must not quietly drop the disclosures.
      final m = jsonDecode(File('assets/i18n/en.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(m['delete_account_kept_1'], contains('tax'));
      expect(m['delete_account_kept_2'], isNotNull);
    });
  });

  group('the data inventory exists and matches the code', () {
    final doc = File('docs/DATA_INVENTORY.md').readAsStringSync();

    test('every persisted key the app writes appears in the inventory', () {
      // DATA-1.01 was graded Fail because the classification lived "in three
      // code comments and nowhere else". A map that omits a store is worse
      // than none: it reads complete.
      const keys = [
        'housepital_patient',
        'housepital_orders_',
        'housepital_assessments_',
        'housepital_cart_items',
        'housepital_saved_items',
        'housepital_reminders',
        'housepital_saved_addresses',
        'daily_rating_',
        'housepital_cache_',
        'housepital_schema_version',
        'theme_mode',
        'housepital_pending_deletion',
        '__quarantine_v',
        'hpl_img_',
      ];
      for (final k in keys) {
        expect(doc, contains(k), reason: '$k is not in DATA_INVENTORY.md');
      }
    });

    test('it states what it does NOT establish', () {
      // Naming an inventory is not governing one.
      expect(doc, contains('What this document does NOT establish'));
      for (final open in const [
        'DATA-4.01',
        'DATA-4.03',
        'DATA-4.05',
        'DATA-5.01'
      ]) {
        expect(doc, contains(open));
      }
    });

    test('the two deliberate retention exceptions are disclosed', () {
      expect(doc, contains('housepital_pending_deletion'));
      expect(doc, contains('Preserved by design'));
    });
  });
}
