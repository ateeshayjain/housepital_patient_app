import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/medication_provider.dart';
import '../providers/my_care_provider.dart';
import '../providers/orders_provider.dart';

/// One place that knows which providers hold data belonging to a single
/// patient, and clears all of them together.
///
/// Why this exists: the app is shared. One patient is watched by the patient
/// themselves, a primary contact, and family members, and a single phone may
/// switch between patients or be handed to someone else after a logout.
/// Before this helper, `switchPatient` reset nothing and `logout` cleared
/// SharedPreferences but left every provider's in-memory state intact — so
/// patient A's deployment, vitals, medications, orders and amount due
/// rendered under patient B's name.
///
/// When a provider gains patient-scoped state, add it here. A provider that
/// holds only device- or account-level state (theme, language, auth) must NOT
/// be cleared here.
abstract final class SessionScope {
  /// Clears patient-scoped state while keeping the user signed in.
  /// Use when the ACTIVE PATIENT changes.
  static void clearPatientData(BuildContext context) {
    context.read<MyCareProvider>().clearPatientScopedData();
    context.read<MedicationProvider>().clearPatientScopedData();
    context.read<BillingProvider>().clearPatientScopedData();
    context.read<OrdersProvider>().clearPatientScopedData();
    // A cart is built for one patient's care plan; carrying it across a
    // patient switch would bill the wrong person.
    context.read<CartProvider>().clear();
  }

  /// Clears everything patient-related INCLUDING who the patient was.
  /// Use on logout, before the auth state changes.
  static void clearSession(BuildContext context) {
    clearPatientData(context);
    context.read<AppProvider>().clearSession();
  }
}
