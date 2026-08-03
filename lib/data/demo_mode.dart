import 'package:flutter/foundation.dart';

/// Tracks whether the app is currently showing BUNDLED SAMPLE DATA instead of
/// this patient's real records.
///
/// The app deliberately falls back to [DemoData] whenever the backend is
/// unreachable, so screens are never blank. That is a good demo property and a
/// dangerous clinical one: without a signal, a family member checking whether
/// insulin was given reads the sample patient's chart with full confidence.
///
/// Every provider that serves a demo fallback calls [markServingDemoData].
/// The shell renders a persistent banner while this is true. Nothing here
/// decides *whether* to fall back — only whether the patient is told.
abstract final class DemoMode {
  /// True once any provider has served sample data for the current session.
  static final ValueNotifier<bool> isServingDemoData =
      ValueNotifier<bool>(false);

  /// Called from a provider's demo-fallback branch.
  static void markServingDemoData() {
    if (!isServingDemoData.value) isServingDemoData.value = true;
  }

  /// Called when live data has been successfully loaded, and by tests.
  static void reset() {
    if (isServingDemoData.value) isServingDemoData.value = false;
  }
}
