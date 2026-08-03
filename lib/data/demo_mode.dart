import 'package:flutter/foundation.dart';

/// Tracks whether the app is currently showing BUNDLED SAMPLE DATA instead of
/// this patient's real records.
///
/// The app deliberately falls back to [DemoData] whenever the backend is
/// unreachable, so screens are never blank. That is a good demo property and a
/// dangerous clinical one: without a signal, a family member checking whether
/// insulin was given reads the sample patient's chart with full confidence.
///
/// WHY THIS IS A SET, NOT A BOOL
/// The first version was a single global bool: any provider could raise it and
/// any provider could lower it. `AppProvider` lowered it the moment the
/// DASHBOARD recovered, taking the warning down while medications, billing and
/// orders were still serving samples — an affirmative all-clear, which is
/// worse than no banner. Conversely `MyCareProvider` raised it and never
/// lowered it, so a healthy backend showed a permanent false alarm.
///
/// So each source owns its own flag. The banner shows while ANY source is
/// serving demo data, and a source may only speak for itself.
abstract final class DemoMode {
  /// Stable identifiers for everything that can serve a demo fallback.
  /// Add a constant here in the same edit that adds a fallback.
  static const String sourceDashboard = 'dashboard';
  static const String sourcePatientIdentity = 'patient-identity';
  static const String sourceMedications = 'medications';
  static const String sourceMyCare = 'my-care';
  static const String sourceBilling = 'billing';
  static const String sourceOrders = 'orders';
  static const String sourceArticles = 'articles';
  static const String sourceCareTeam = 'care-team';
  static const String sourceCareCalendar = 'care-calendar';
  static const String sourceProfile = 'profile';
  static const String sourceHandover = 'handover-report';

  static final Set<String> _activeSources = <String>{};

  /// True while at least one source is serving sample data.
  static final ValueNotifier<bool> isServingDemoData =
      ValueNotifier<bool>(false);

  /// Read-only view, for diagnostics and tests.
  static Set<String> get activeSources => Set.unmodifiable(_activeSources);

  /// Called from a provider's demo-fallback branch.
  static void markServingDemoData(String source) {
    if (_activeSources.add(source)) _sync();
  }

  /// Called when a source has successfully loaded LIVE data. A source may
  /// only clear itself — clearing globally is how the first version lied.
  static void markServingLiveData(String source) {
    if (_activeSources.remove(source)) _sync();
  }

  /// Test-only full reset.
  @visibleForTesting
  static void reset() {
    if (_activeSources.isEmpty) return;
    _activeSources.clear();
    _sync();
  }

  static void _sync() {
    isServingDemoData.value = _activeSources.isNotEmpty;
  }
}
