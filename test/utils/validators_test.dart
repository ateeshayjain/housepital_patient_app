// test/utils/validators_test.dart
//
// Unit suite for the centralized form validators — the single source of
// truth for every form in the app (login, family members, add patient,
// address, raise concern, profile). Contract: null = valid, string = error.
// Boundary cases matter here: these rules encode TRAI mobile numbering,
// Indian pincode structure, and the raise-concern DoS cap.

import 'package:flutter_test/flutter_test.dart';

import 'package:housepital_patient/utils/validators.dart';

void main() {
  group('indianMobile', () {
    test('accepts valid 10-digit numbers starting 6-9', () {
      for (final v in ['6000000000', '7123456789', '8999999999', '9876543210']) {
        expect(Validators.indianMobile(v), isNull, reason: v);
      }
    });

    test('rejects wrong leading digit, length, and non-digits', () {
      expect(Validators.indianMobile('5876543210'), isNotNull); // leads 5
      expect(Validators.indianMobile('0987654321'), isNotNull); // 0-prefix
      expect(Validators.indianMobile('987654321'), isNotNull); // 9 digits
      expect(Validators.indianMobile('98765432100'), isNotNull); // 11 digits
      expect(Validators.indianMobile('98765abc10'), isNotNull); // letters
      expect(Validators.indianMobile('+919876543210'), isNotNull); // +91
      expect(Validators.indianMobile('98765 43210'), isNotNull); // space
    });

    test('required vs optional empty handling', () {
      expect(Validators.indianMobile(''), isNotNull);
      expect(Validators.indianMobile(null), isNotNull);
      expect(Validators.indianMobile('', required: false), isNull);
      expect(Validators.indianMobile(null, required: false), isNull);
      // Optional does NOT mean lax: non-empty invalid still rejected.
      expect(Validators.indianMobile('123', required: false), isNotNull);
    });
  });

  group('email', () {
    test('accepts common shapes', () {
      for (final v in [
        'a@b.co',
        'first.last@example.com',
        'user+tag@sub.domain.org',
        'USER_99%x@host-name.in',
      ]) {
        expect(Validators.email(v), isNull, reason: v);
      }
    });

    test('rejects obvious typos', () {
      for (final v in ['foo', 'foo@', 'foo@bar', '@bar.com', 'a b@c.com']) {
        expect(Validators.email(v), isNotNull, reason: v);
      }
    });

    test('required vs optional', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('', required: false), isNull);
      expect(Validators.email('foo@', required: false), isNotNull);
    });
  });

  group('pincode', () {
    test('accepts 6 digits with leading 1-9', () {
      expect(Validators.pincode('110001'), isNull); // Delhi
      expect(Validators.pincode('999999'), isNull);
    });

    test('rejects 0-prefix, wrong length, non-digits', () {
      expect(Validators.pincode('010001'), isNotNull);
      expect(Validators.pincode('11000'), isNotNull);
      expect(Validators.pincode('1100011'), isNotNull);
      expect(Validators.pincode('11000a'), isNotNull);
    });

    test('required vs optional', () {
      expect(Validators.pincode(null), isNotNull);
      expect(Validators.pincode(null, required: false), isNull);
    });
  });

  group('name', () {
    test('accepts Indian name shapes', () {
      for (final v in [
        'Rajesh Kumar',
        'A. P. J. Abdul Kalam',
        "D'Souza",
        'Mary-Jane',
        'Om',
      ]) {
        expect(Validators.name(v), isNull, reason: v);
      }
    });

    test('trims before validating and enforces 2..max', () {
      expect(Validators.name('  Raj  '), isNull);
      expect(Validators.name('R'), isNotNull); // too short
      expect(Validators.name('   '), isNotNull); // whitespace-only = empty
      expect(Validators.name('a' * 61), isNotNull); // default max 60
      expect(Validators.name('a' * 61, max: 80), isNull);
      expect(Validators.name('a' * 60), isNull); // boundary
    });

    test('rejects digits and symbols', () {
      expect(Validators.name('Raj3sh'), isNotNull);
      expect(Validators.name('Raj@home'), isNotNull);
      // Devanagari is currently rejected by the ASCII letter class — this is
      // the documented contract today; loosening it is a product decision.
      expect(Validators.name('राजेश'), isNotNull);
    });
  });

  group('age', () {
    test('accepts integer 0..150 inclusive', () {
      expect(Validators.age('0'), isNull);
      expect(Validators.age('85'), isNull);
      expect(Validators.age('150'), isNull);
    });

    test('rejects out-of-range and non-numeric', () {
      expect(Validators.age('-1'), isNotNull);
      expect(Validators.age('151'), isNotNull);
      expect(Validators.age('12.5'), isNotNull); // int contract
      expect(Validators.age('abc'), isNotNull);
    });

    test('required vs optional', () {
      expect(Validators.age(''), isNotNull);
      expect(Validators.age('', required: false), isNull);
    });
  });

  group('description', () {
    test('enforces the raise-concern DoS cap (default 1000)', () {
      expect(Validators.description('a' * 1000), isNull); // boundary
      expect(Validators.description('a' * 1001), isNotNull);
      expect(Validators.description('a' * 50, max: 40), isNotNull);
    });

    test('whitespace-only counts as empty; optional allows empty', () {
      expect(Validators.description('   '), isNotNull);
      expect(Validators.description('', required: false), isNull);
      expect(Validators.description('ok'), isNull);
    });
  });
}
