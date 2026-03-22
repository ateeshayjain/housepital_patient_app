// test/utils/permission_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/utils/permissions.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY_CONTACT — full access
  // ═══════════════════════════════════════════════════════════════════════════
  group('PRIMARY_CONTACT permissions', () {
    test('can book', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'book'), isTrue);
    });

    test('can pay', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'pay'), isTrue);
    });

    test('can edit patient', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'edit_patient'), isTrue);
    });

    test('can manage family', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'manage_family'), isTrue);
    });

    test('can view', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'view'), isTrue);
    });

    test('can rate', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'rate'), isTrue);
    });

    test('can raise concern', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'raise_concern'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FAMILY_MEMBER — limited access
  // ═══════════════════════════════════════════════════════════════════════════
  group('FAMILY_MEMBER permissions', () {
    test('can view', () {
      expect(canUserPerform('FAMILY_MEMBER', 'view'), isTrue);
    });

    test('can rate', () {
      expect(canUserPerform('FAMILY_MEMBER', 'rate'), isTrue);
    });

    test('can raise concern', () {
      expect(canUserPerform('FAMILY_MEMBER', 'raise_concern'), isTrue);
    });

    test('can book', () {
      expect(canUserPerform('FAMILY_MEMBER', 'book'), isTrue);
    });

    test('CANNOT pay', () {
      expect(canUserPerform('FAMILY_MEMBER', 'pay'), isFalse);
    });

    test('CANNOT edit patient', () {
      expect(canUserPerform('FAMILY_MEMBER', 'edit_patient'), isFalse);
    });

    test('CANNOT manage family', () {
      expect(canUserPerform('FAMILY_MEMBER', 'manage_family'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PATIENT_SELF — view only
  // ═══════════════════════════════════════════════════════════════════════════
  group('PATIENT_SELF permissions', () {
    test('can view', () {
      expect(canUserPerform('PATIENT_SELF', 'view'), isTrue);
    });

    test('CANNOT book', () {
      expect(canUserPerform('PATIENT_SELF', 'book'), isFalse);
    });

    test('CANNOT pay', () {
      expect(canUserPerform('PATIENT_SELF', 'pay'), isFalse);
    });

    test('CANNOT edit patient', () {
      expect(canUserPerform('PATIENT_SELF', 'edit_patient'), isFalse);
    });

    test('CANNOT manage family', () {
      expect(canUserPerform('PATIENT_SELF', 'manage_family'), isFalse);
    });

    test('CANNOT rate', () {
      expect(canUserPerform('PATIENT_SELF', 'rate'), isFalse);
    });

    test('CANNOT raise concern', () {
      expect(canUserPerform('PATIENT_SELF', 'raise_concern'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Edge cases
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('unknown role returns false for all actions', () {
      expect(canUserPerform('ADMIN', 'view'), isFalse);
      expect(canUserPerform('GUEST', 'book'), isFalse);
      expect(canUserPerform('', 'view'), isFalse);
    });

    test('unknown action returns false', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'delete_account'), isFalse);
      expect(canUserPerform('FAMILY_MEMBER', 'unknown'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getAllowedActions
  // ═══════════════════════════════════════════════════════════════════════════
  group('getAllowedActions', () {
    test('PRIMARY_CONTACT has 7 actions', () {
      final actions = getAllowedActions('PRIMARY_CONTACT');
      expect(actions.length, 7);
      expect(actions, containsAll([
        'book', 'pay', 'edit_patient', 'manage_family',
        'view', 'rate', 'raise_concern',
      ]));
    });

    test('FAMILY_MEMBER has 4 actions', () {
      final actions = getAllowedActions('FAMILY_MEMBER');
      expect(actions.length, 4);
      expect(actions, containsAll(['view', 'book', 'rate', 'raise_concern']));
    });

    test('PATIENT_SELF has 1 action', () {
      final actions = getAllowedActions('PATIENT_SELF');
      expect(actions.length, 1);
      expect(actions, contains('view'));
    });

    test('unknown role returns empty set', () {
      expect(getAllowedActions('RANDOM'), isEmpty);
    });
  });
}
