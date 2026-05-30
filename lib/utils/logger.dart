import 'package:flutter/foundation.dart';

/// Severity levels for [Log], ordered from least to most severe.
///
/// * [debug] — verbose diagnostic output useful only while developing.
/// * [info]  — meaningful lifecycle events (startup, cache hits, etc.).
/// * [warn]  — recoverable problems (e.g. fell back to demo/cached data).
/// * [error] — genuine failures that break a user-facing flow.
enum LogLevel { debug, info, warn, error }

/// Lightweight structured logger. Replaces scattered `debugPrint(e)` calls.
///
/// In release builds, [debug] and [info] are dropped; [warn] and [error] are
/// kept and are the natural hook point for `Crashlytics.recordError` (wired
/// separately). Every message is prefixed with its level and an optional
/// `tag` (typically the originating class name) so logs are greppable.
///
/// Usage:
/// ```dart
/// try {
///   await api.fetch();
/// } catch (e, st) {
///   Log.warn('Failed to load dashboard; using cache',
///       error: e, stack: st, tag: 'AppProvider');
/// }
/// ```
class Log {
  /// Logs a verbose diagnostic [message]. Dropped in release builds.
  static void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);

  /// Logs a meaningful lifecycle [message]. Dropped in release builds.
  static void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);

  /// Logs a recoverable problem. Kept in release builds.
  ///
  /// Pass [error] (and optionally [stack]) from a `catch` block to capture the
  /// underlying cause; use this for "fell back to demo data" style cases.
  static void warn(String message,
          {Object? error, StackTrace? stack, String? tag}) =>
      _log(LogLevel.warn, message, error: error, stack: stack, tag: tag);

  /// Logs a genuine failure that breaks a user flow. Kept in release builds.
  ///
  /// Pass [error] (and optionally [stack]) from a `catch` block to capture the
  /// underlying cause.
  static void error(String message,
          {Object? error, StackTrace? stack, String? tag}) =>
      _log(LogLevel.error, message, error: error, stack: stack, tag: tag);

  static void _log(LogLevel level, String message,
      {Object? error, StackTrace? stack, String? tag}) {
    // In release, suppress debug/info noise; keep warn/error.
    if (kReleaseMode && (level == LogLevel.debug || level == LogLevel.info)) {
      return;
    }
    final prefix = '[${level.name.toUpperCase()}]${tag != null ? '[$tag]' : ''}';
    debugPrint('$prefix $message${error != null ? ' — $error' : ''}');
    if (stack != null && (level == LogLevel.warn || level == LogLevel.error)) {
      debugPrint(stack.toString());
    }
    // TODO(observability): forward warn/error to FirebaseCrashlytics.recordError
    // here once a non-fatal reporting policy is decided. Kept as a single
    // chokepoint so that wiring is a one-line change.
  }
}
