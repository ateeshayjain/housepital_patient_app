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
/// Receives warn/error records for out-of-process reporting.
///
/// Deliberately a function type rather than a Crashlytics import: [Log] is
/// imported by almost every file in the app, and pulling Firebase in here
/// would drag it into every unit test too. `main.dart` installs the real sink.
typedef LogSink = void Function(
  LogLevel level,
  String message, {
  Object? error,
  StackTrace? stack,
  String? tag,
});

class Log {
  /// Out-of-process destination for warn/error. Null in tests and until
  /// `main.dart` installs one.
  ///
  /// PII RULE — read before logging anything.
  /// Whatever reaches this sink leaves the device and lands in a third-party
  /// console. Log messages must describe WHAT failed, never WHO it happened
  /// to: no patient name, phone, address, diagnosis, drug name, or invoice
  /// amount. "Failed to load dashboard" is a good message; "Failed to load
  /// dashboard for Kamala Devi (9876543210)" is a PHI disclosure with a log
  /// level in front of it.
  static LogSink? sink;

  /// Test-only: removes the sink so one test cannot leak records into another.
  @visibleForTesting
  static void resetSink() => sink = null;

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
    // Forward the levels that matter. `debugPrint` is a no-op in release, so
    // before this existed every HANDLED failure in the app — the demo
    // fallbacks, a failed store quarantine, a payment order that could not be
    // created, a photo whose metadata could not be stripped — was invisible
    // in production. Crashlytics only ever saw uncaught crashes, which is the
    // one category this app is careful to avoid, so the reporting looked
    // healthy precisely because the failures were being handled.
    if (level == LogLevel.warn || level == LogLevel.error) {
      final s = sink;
      if (s != null) {
        try {
          s(level, message, error: error, stack: stack, tag: tag);
        } catch (_) {
          // A reporting failure must never become an app failure. Swallowed
          // deliberately, and not re-logged — that recurses.
        }
      }
    }
  }
}
