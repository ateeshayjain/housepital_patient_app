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

    test('can request booking', () {
      expect(canUserPerform('PRIMARY_CONTACT', 'request_booking'), isTrue);
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

    test('can request booking (pending primary contact approval)', () {
      expect(canUserPerform('FAMILY_MEMBER', 'request_booking'), isTrue);
    });

    test('CANNOT book directly', () {
      expect(canUserPerform('FAMILY_MEMBER', 'book'), isFalse);
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

    test('CANNOT request booking', () {
      expect(canUserPerform('PATIENT_SELF', 'request_booking'), isFalse);
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
  // CARETAKER — view + raise concern only (audit M-5)
  // ═══════════════════════════════════════════════════════════════════════════
  group('CARETAKER permissions', () {
    test('can view', () {
      expect(canUserPerform('CARETAKER', 'view'), isTrue);
    });

    test('can raise concern', () {
      expect(canUserPerform('CARETAKER', 'raise_concern'), isTrue);
    });

    test('CANNOT book', () {
      expect(canUserPerform('CARETAKER', 'book'), isFalse);
    });

    test('CANNOT request booking (narrower than FAMILY_MEMBER)', () {
      expect(canUserPerform('CARETAKER', 'request_booking'), isFalse);
    });

    test('CANNOT pay', () {
      expect(canUserPerform('CARETAKER', 'pay'), isFalse);
    });

    test('CANNOT edit patient', () {
      expect(canUserPerform('CARETAKER', 'edit_patient'), isFalse);
    });

    test('CANNOT manage family', () {
      expect(canUserPerform('CARETAKER', 'manage_family'), isFalse);
    });

    test('CANNOT rate', () {
      expect(canUserPerform('CARETAKER', 'rate'), isFalse);
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
    test('PRIMARY_CONTACT has 8 actions', () {
      final actions = getAllowedActions('PRIMARY_CONTACT');
      expect(actions.length, 8);
      expect(actions, containsAll([
        'book', 'request_booking', 'pay', 'edit_patient', 'manage_family',
        'view', 'rate', 'raise_concern',
      ]));
    });

    test('FAMILY_MEMBER has 4 actions', () {
      final actions = getAllowedActions('FAMILY_MEMBER');
      expect(actions.length, 4);
      expect(actions,
          containsAll(['view', 'request_booking', 'rate', 'raise_concern']));
      expect(actions, isNot(contains('book')));
      expect(actions, isNot(contains('pay')));
    });

    test('PATIENT_SELF has 1 action', () {
      final actions = getAllowedActions('PATIENT_SELF');
      expect(actions.length, 1);
      expect(actions, contains('view'));
    });

    test('CARETAKER has 2 actions (view + raise_concern)', () {
      final actions = getAllowedActions('CARETAKER');
      expect(actions.length, 2);
      expect(actions, containsAll(['view', 'raise_concern']));
      expect(actions, isNot(contains('book')));
      expect(actions, isNot(contains('request_booking')));
      expect(actions, isNot(contains('pay')));
      expect(actions, isNot(contains('rate')));
    });

    test('unknown role returns empty set', () {
      expect(getAllowedActions('RANDOM'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Scenario coverage — added in batch 3 to extend the CARETAKER tests above.
  // ═══════════════════════════════════════════════════════════════════════════
  group('CARETAKER scenarios — UI gates', () {
    // My Orders screen gates the cancel button on `canUserPerform(role, 'pay')`
    // because cancelling triggers a refund — only the payer can authorise it.
    // Confirm the gate reads false for a CARETAKER so the cancel button stays hidden.
    test('cannot cancel an order — pay permission is the gate', () {
      expect(canUserPerform('CARETAKER', 'pay'), isFalse,
          reason:
              'my_orders_screen.dart gates cancel on `pay` permission; CARETAKER must not be able to refund.');
    });
  });

  group('Runtime role switch', () {
    // When a user changes role (e.g. demoted from primary contact to caretaker
    // because someone else took over billing), the action set must shrink.
    test('PRIMARY_CONTACT → CARETAKER returns a smaller action set', () {
      final primaryActions = getAllowedActions('PRIMARY_CONTACT');
      final caretakerActions = getAllowedActions('CARETAKER');

      expect(caretakerActions.length, lessThan(primaryActions.length));
      // Every caretaker action must be a subset of the broader primary set —
      // CARETAKER should not be granted any action a PRIMARY_CONTACT lacks.
      expect(primaryActions.containsAll(caretakerActions), isTrue,
          reason: 'CARETAKER actions must be a strict subset of PRIMARY_CONTACT.');
    });

    test('PRIMARY_CONTACT → FAMILY_MEMBER → CARETAKER narrows progressively',
        () {
      final p = getAllowedActions('PRIMARY_CONTACT').length;
      final f = getAllowedActions('FAMILY_MEMBER').length;
      final c = getAllowedActions('CARETAKER').length;
      expect(p, greaterThan(f));
      expect(f, greaterThan(c));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Defensive default — unknown role strings must NEVER be granted any action.
  // This is security-adjacent: a typo or upstream bug must fail closed.
  // ═══════════════════════════════════════════════════════════════════════════
  group('Unknown role defensive default', () {
    test('INTRUDER role returns false for every known action', () {
      // Iterate every defined action — none should be permitted for an unknown role.
      const allActions = [
        'book',
        'request_booking',
        'pay',
        'edit_patient',
        'manage_family',
        'view',
        'rate',
        'raise_concern',
      ];
      for (final action in allActions) {
        expect(canUserPerform('INTRUDER', action), isFalse,
            reason:
                'Unknown role "INTRUDER" must NOT be allowed to perform "$action".');
      }
    });

    test('null-ish & whitespace roles all return false', () {
      const sketchyRoles = ['', ' ', 'primary_contact', 'Primary_Contact', '\n'];
      for (final role in sketchyRoles) {
        expect(canUserPerform(role, 'view'), isFalse,
            reason: 'Role "$role" must be rejected (case-sensitive match).');
      }
    });

    test('getAllowedActions("INTRUDER") is empty', () {
      expect(getAllowedActions('INTRUDER'), isEmpty);
    });
  });
}
