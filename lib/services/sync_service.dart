import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import 'api_service.dart';

class SyncService {
  final ApiService _apiService;
  final AppProvider _appProvider;

  DateTime? lastSyncAt;
  bool isSyncing = false;

  Timer? _periodicTimer;

  SyncService({
    required ApiService apiService,
    required AppProvider appProvider,
  })  : _apiService = apiService,
        _appProvider = appProvider;

  /// Performs a full sync of all patient-related data from the staff app.
  /// Fetches dashboard data (attendance, vitals, reports, deployment, billing)
  /// and updates the AppProvider state.
  Future<void> syncAll(String patientId) async {
    if (isSyncing) return;

    isSyncing = true;

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
    } catch (e) {
      debugPrint('SyncService: sync failed - $e');
      rethrow;
    } finally {
      isSyncing = false;
    }
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
