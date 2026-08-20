// test/screens/staff_profile_no_fabrication_test.dart
//
// The staff-profile fallback fabricated `police_verified: true`, a 4.8 rating
// and four named patient reviews. Because api.housepital.in does not resolve
// in any shipped build, that branch is the ONLY one that has ever run: every
// person who opened a staff profile was told their caregiver passed a police
// check that Housepital never performed and this app never saw.
//
// A background-verification claim is a safety claim about a stranger who
// enters a patient's home. This test exists so it cannot come back — including
// via a DemoData fixture, which would be the same claim with a longer paper
// trail.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/models/models.dart';

void main() {
  final source =
      File('lib/screens/support/staff_profile_screen.dart').readAsStringSync();

  group('the fallback asserts nothing it cannot source', () {
    test('no verification flag is ever set true in this file', () {
      for (final claim in const [
        "'police_verified': true",
        "'id_verified': true",
        "'training_complete': true",
        'policeVerified: true',
        'idVerified: true',
        'trainingComplete: true',
      ]) {
        expect(source, isNot(contains(claim)),
            reason: 'this app cannot know $claim');
      }
    });

    test('no verification row is hard-coded to verified', () {
      // 'Medical Fitness' was passed a literal `true`, so it read "Verified"
      // even against live data — no field anywhere backed it.
      expect(source, isNot(contains("'Medical Fitness',\n                true")));
      expect(RegExp(r"_verificationRow\(\s*[\w.]+,\s*'[^']+',\s*true\s*,")
          .hasMatch(source), isFalse);
    });

    test('no invented reviews or rating', () {
      expect(source, isNot(contains("'reviews':")));
      expect(source, isNot(contains("'rating': 4.8")));
      expect(source, isNot(contains("'total_reviews':")));
    });

    test('the failure is distinguished from a negative finding', () {
      // "not verified" is a fact about the person; "could not load" is a fact
      // about us. Rendering the first when we only know the second is the
      // same error in the other direction.
      expect(source, contains('_loadFailed'));
      expect(source, contains('could not be loaded'));
    });

    test('the fallback is announced as demo data', () {
      expect(source, contains('DemoMode.markServingDemoData'));
      expect(source, contains('DemoMode.sourceStaffProfile'));
    });

    test('fabricated attendance is labelled as sample', () {
      // Every cell of the attendance grid is generated in this file with no
      // feed behind it. Attendance is the record a family is most likely to
      // act on, so an unlabelled invented grid is a fabricated evidentiary
      // record.
      expect(source, contains('Sample attendance'));
    });
  });

  group('the model itself defaults to unverified', () {
    test('a bare StaffProfile claims nothing', () {
      final s = StaffProfile(id: 'x', name: 'Someone', role: 'nurse');
      expect(s.policeVerified, isFalse);
      expect(s.idVerified, isFalse);
      expect(s.trainingComplete, isFalse);
      expect(s.rating, isNull);
      expect(s.reviews, isNull);
      expect(s.documents, isNull);
    });

    test('a JSON payload missing the flags does not invent them', () {
      final s = StaffProfile.fromJson(const {
        'id': 'x',
        'name': 'Someone',
        'role': 'nurse',
      });
      expect(s.policeVerified, isFalse);
      expect(s.idVerified, isFalse);
      expect(s.trainingComplete, isFalse);
    });
  });
}
