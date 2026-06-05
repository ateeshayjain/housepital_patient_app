import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import 'api_service.dart';

class SyncService {
  final ApiService _apiService;
  final AppProvider _appProvider;

  DateTime? lastSyncAt;

  /// In-flight sync, if any. Concurrent callers share this future
  /// so we never run two `syncAll` operations against the same patient
  /// in parallel (which used to race because `isSyncing` was a plain bool
  /// flipped between `await` boundaries).
  Completer<void>? _inFlightSync;

  /// Backwards-compatible accessor — true while a sync is running.
  bool get isSyncing => _inFlightSync != null && !_inFlightSync!.isCompleted;

  Timer? _periodicTimer;

  SyncService({
    required ApiService apiService,
    required AppProvider appProvider,
  })  : _apiService = apiService,
        _appProvider = appProvider;

  /// Performs a full sync of all patient-related data from the staff app.
  /// Fetches dashboard data (attendance, vitals, reports, deployment, billing)
  /// and updates the AppProvider state.
  ///
  /// If a sync is already in flight, returns the existing future so all
  /// callers wait for the same result instead of triggering a duplicate fetch.
  Future<void> syncAll(String patientId) {
    final existing = _inFlightSync;
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }

    final completer = Completer<void>();
    _inFlightSync = completer;

    () async {
      try {
        // Fetch all data in parallel
        final results = await Future.wait([
          _apiService.getActiveDeployment(patientId),
          _apiService.getTodayAttendance(patientId),
          _apiService.getLatestVitals(patientId),
          _apiService.getTodayReport(patientId),
          _apiService.getPatient(patientId),
          _apiService.getBillingSummary(patientId),
        ]);

        // Update the provider with fresh data
        _appProvider.updateFromSync(
          deployment: results[0] as dynamic,
          attendance: results[1] as dynamic,
          vitals: results[2] as dynamic,
          report: results[3] as dynamic,
          patient: results[4] as dynamic,
          billingSummary: results[5] as Map<String, dynamic>,
        );

        lastSyncAt = DateTime.now();
        debugPrint('SyncService: sync completed at $lastSyncAt');
        completer.complete();
      } catch (e, st) {
        debugPrint('SyncService: sync failed - $e');
        completer.completeError(e, st);
      } finally {
        // Clear only if this completer is still the current in-flight sync.
        if (identical(_inFlightSync, completer)) {
          _inFlightSync = null;
        }
      }
    }();

    return completer.future;
  }

  /// Starts a periodic sync that runs at the given interval.
  /// Defaults to every 5 minutes.
  void startPeriodicSync(
    String patientId, {
    Duration interval = const Duration(minutes: 5),
  }) {
    stopPeriodicSync();

    // Run an immediate sync first
    syncAll(patientId).catchError((e) {
      debugPrint('SyncService: initial periodic sync failed - $e');
    });

    _periodicTimer = Timer.periodic(interval, (_) {
      syncAll(patientId).catchError((e) {
        debugPrint('SyncService: periodic sync failed - $e');
      });
    });

    debugPrint(
      'SyncService: periodic sync started for patient $patientId '
      'with interval ${interval.inSeconds}s',
    );
  }

  /// Stops the periodic sync timer.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('SyncService: periodic sync stopped');
  }

  /// Disposes the service and cancels any active timers.
  void dispose() {
    stopPeriodicSync();
  }
}
