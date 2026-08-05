import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_provider.dart';
import '../providers/assistant_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/medication_provider.dart';
import '../providers/my_care_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/reminders_provider.dart';
import '../services/cache_service.dart';
import '../services/medication_reminder_service.dart';
import '../utils/logger.dart';

/// One place that knows which state belongs to a single patient, and clears
/// all of it together.
///
/// WHY THIS EXISTS
/// The app is shared. One patient is watched by the patient themselves, a
/// primary contact, and family members, and a single phone may switch between
/// patients or be handed to someone else after a logout. Before this helper,
/// `switchPatient` reset nothing and `logout` cleared SharedPreferences but
/// left every provider's in-memory state intact — so patient A's deployment,
/// vitals, medications, orders and amount due rendered under patient B's name.
///
/// LESSON FROM THE FIRST ATTEMPT (read before editing)
/// The first version of this file was written from a list of REPORTED
/// SYMPTOMS and cleared only what those symptoms named. It missed
/// `AppProvider._vitalsHistory`, left the cart's saved-items list persisted
/// under the new patient, cleared orders in memory but not on disk, and did
/// not know about reminders, the assistant transcript, or the on-disk
/// dashboard cache. A partial wipe that reads as complete is more dangerous
/// than no wipe, because nobody looks again.
///
/// So the rule is: **enumerate stores, not symptoms.** When anything gains
/// patient-scoped state — a provider field, a SharedPreferences key, a cache
/// entry — add it here in the same edit, and add an assertion to
/// test/providers/patient_scope_isolation_test.dart. State that belongs to
/// the DEVICE or the ACCOUNT (theme, language, auth) must NOT be cleared here.
abstract final class SessionScope {
  /// SharedPreferences keys holding one patient's data that no provider owns.
  ///
  /// `CacheService` entries are handled separately via [CacheService.clear];
  /// these are the loose ones.
  static const List<String> _patientScopedPrefsKeys = <String>[
    'housepital_saved_addresses', // where a nurse gets dispatched
  ];

  /// Prefix for the per-day rating keys written by my_care_screen.
  static const String _dailyRatingPrefix = 'daily_rating_';

  /// Wires [AppProvider] so EVERY patient-switch path fans out here.
  ///
  /// There are two: the switch sheet, and `loadPatients()` adopting a
  /// different patient from the API — the latter runs on every Home mount and
  /// round 3 found it cleared `AppProvider` only. Call once, high in the tree.
  static void install(BuildContext context) {
    final app = context.read<AppProvider>();
    if (app.onPatientChanged != null) return;
    app.onPatientChanged = (patientId) {
      if (!context.mounted) return;
      // Re-point per-patient stores at the incoming patient. Orders are keyed
      // per patient, so this is a READ of a different key — it destroys
      // nothing belonging to either patient.
      unawaited(_adopt(context, patientId));
    };
  }

  static Future<void> _adopt(BuildContext context, String? patientId) async {
    await clearPatientData(context);
    if (!context.mounted) return;
    await context.read<OrdersProvider>().setPatient(patientId);
  }

  /// Clears patient-scoped state while keeping the user signed in.
  /// Use when the ACTIVE PATIENT changes.
  static Future<void> clearPatientData(BuildContext context) async {
    context.read<MyCareProvider>().clearPatientScopedData();
    context.read<MedicationProvider>().clearPatientScopedData();
    context.read<BillingProvider>().clearPatientScopedData();
    context.read<OrdersProvider>().clearPatientScopedData();
    context.read<AssistantProvider>().clearPatientScopedData();
    // A cart and a saved-for-later list are built for one patient's care
    // plan; carrying either across a switch would bill the wrong person.
    context.read<CartProvider>().clearPatientScopedData();

    // Async stores. Awaited so a caller that immediately loads the next
    // patient cannot race the wipe.
    await context.read<RemindersProvider>().clearPatientScopedData();

    // Scheduled OS notifications outlive the app. Without this, patient A's
    // drug name and dose fires on the lock screen after the phone has been
    // handed to someone else — the only PHI leak here that escapes the app
    // entirely. cancelAllReminders() already existed; nothing called it.
    try {
      await MedicationReminderService().cancelAllReminders();
    } catch (e) {
      Log.warn('Failed to cancel scheduled medication reminders',
          error: e, tag: 'SessionScope');
    }

    await _clearPatientScopedStorage();
  }

  /// Clears everything patient-related INCLUDING who the patient was.
  /// Use on logout, before the auth state changes.
  static Future<void> clearSession(BuildContext context) async {
    await clearPatientData(context);
    if (!context.mounted) return;
    context.read<AppProvider>().clearSession();
  }

  /// Removes on-disk patient data that lives outside any provider: the
  /// dashboard cache blobs and the loose keys above.
  static Future<void> _clearPatientScopedStorage() async {
    try {
      // dashboard_{patientId} blobs — CacheService.clear() had zero callers.
      await CacheService.instance.clear();

      final prefs = await SharedPreferences.getInstance();
      for (final key in _patientScopedPrefsKeys) {
        await prefs.remove(key);
      }
      // Per-day satisfaction ratings are keyed by date, not patient.
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_dailyRatingPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      Log.warn('Failed to clear patient-scoped storage',
          error: e, tag: 'SessionScope');
    }
  }
}
