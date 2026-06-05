import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preferred [ThemeMode] (system / light / dark) across
/// app launches and exposes it as a [ChangeNotifier] so the root
/// [MaterialApp] can rebuild when it changes.
///
/// Storage key: `theme_mode`. Stored as one of:
///   - `system` (default — follow OS dark/light)
///   - `light`
///   - `dark`
///
/// The constructor kicks off an async load from [SharedPreferences];
/// until that completes the provider returns [ThemeMode.system], which is
/// a safe default that matches the OS.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeProvider() {
    _load();
  }

  ThemeMode get mode => _mode;

  /// Whether the preference has been loaded from disk yet. Useful if a UI
  /// wants to show a loading state on first paint (most don't bother — the
  /// system default looks fine).
  bool get isLoaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      _mode = _parse(raw);
    } catch (_) {
      // Storage failures shouldn't crash the app — fall back to system.
      _mode = ThemeMode.system;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Update the user's choice and persist it. Notifies listeners
  /// immediately so the UI flips before the disk write completes.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _serialize(mode));
    } catch (_) {
      // Non-fatal — the in-memory value still drives the UI this session.
    }
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
