import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/demo_data.dart';
import '../data/demo_mode.dart';
import '../models/models.dart';
import '../services/cache_service.dart';
import '../services/i_api_service.dart';
import '../utils/logger.dart';

class AppProvider extends ChangeNotifier {
  // audit batch 4 (Agent J): depend on the IApiService interface, not the
  // concrete ApiService, to satisfy Dependency Inversion (SOLID) and let
  // tests inject lightweight fakes without subclassing the real client.
  final IApiService _apiService;
  IApiService get apiService => _apiService;

  // Current user role for permission gating.
  // Defaults to PRIMARY_CONTACT so the demo retains full access; a future
  // sign-in flow will set this from the authenticated user's profile.
  String _currentUserRole = 'PRIMARY_CONTACT';
  String get currentUserRole => _currentUserRole;
  void setUserRole(String role) {
    _currentUserRole = role;
    notifyListeners();
  }

  // Current patient context
  Patient? _currentPatient;
  List<Patient> _patients = [];
  Deployment? _activeDeployment;

  // Dashboard data
  Attendance? _todayAttendance;
  VitalReading? _latestVitals;
  DailyReport? _todayReport;
  bool _isDashboardLoading = false;

  // Manually entered vital readings (owner request: "Add option to add
  // vitals" on Today's Vitals). In-memory only — demo mode tolerates a
  // failed API post and keeps the reading locally; never written to storage.
  final List<VitalReading> _vitalsHistory = [];

  // Language
  Locale _locale = const Locale('en');

  // Profile photo
  String? _profilePhotoPath;

  // Billing
  int _amountDue = 0;
  DateTime? _dueDate;

  String? _dashboardError;
  String? _lastUpdatedText;

  AppProvider(IApiService api) : _apiService = api {
    _loadLanguage();
    _loadProfilePhoto();
  }

  String? get lastUpdatedText => _lastUpdatedText;

  /// Error message if dashboard failed to load.
  String? get dashboardError => _dashboardError;

  // Getters
  Patient? get currentPatient => _currentPatient;
  List<Patient> get patients => _patients;
  Deployment? get activeDeployment => _activeDeployment;
  Attendance? get todayAttendance => _todayAttendance;
  VitalReading? get latestVitals => _latestVitals;
  DailyReport? get todayReport => _todayReport;

  /// Manually entered vital readings, oldest first (in-memory).
  List<VitalReading> get vitalsHistory => List.unmodifiable(_vitalsHistory);
  bool get isDashboardLoading => _isDashboardLoading;
  Locale get locale => _locale;
  String? get profilePhotoPath => _profilePhotoPath;
  int get amountDue => _amountDue;
  DateTime? get dueDate => _dueDate;

  // Language
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('preferred_language') ?? 'en';
    _locale = Locale(lang);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_language', languageCode);
    notifyListeners();
  }

  // Profile photo
  Future<void> _loadProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    _profilePhotoPath = prefs.getString('profile_photo_path');
    notifyListeners();
  }

  Future<void> setProfilePhotoPath(String path) async {
    _profilePhotoPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo_path', path);
    notifyListeners();
  }

  // Notification preferences
  Future<Map<String, bool>> getNotificationPreferences(
    List<Map<String, dynamic>> toggleablePrefs,
    List<Map<String, dynamic>> forcedPrefs,
  ) async {
    final sp = await SharedPreferences.getInstance();
    final prefs = <String, bool>{};
    for (final pref in toggleablePrefs) {
      prefs[pref['key'] as String] =
          sp.getBool(pref['key'] as String) ?? (pref['defaultValue'] as bool);
    }
    for (final pref in forcedPrefs) {
      prefs[pref['key'] as String] = true;
    }
    return prefs;
  }

  Future<void> setNotificationPreference(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  // Load patients list
  Future<void> loadPatients() async {
    // Seed demo patient immediately so UI is never empty
    if (_patients.isEmpty) {
      _currentPatient = DemoData.patient;
      _patients = [DemoData.patient];
      notifyListeners();
    }

    // Then try API in background
    try {
      final apiPatients = await _apiService.getPatients()
          .timeout(const Duration(seconds: 5));
      if (apiPatients.isNotEmpty) {
        _patients = apiPatients;
        _currentPatient = apiPatients.first;
        notifyListeners();
      }
    } catch (e) {
      Log.warn('Patients API unavailable, using demo data',
          error: e, tag: 'AppProvider');
    }
  }

  // Switch patient context
  void switchPatient(Patient patient) {
    // Drop the outgoing patient's data BEFORE the new one is current,
    // otherwise their deployment, attendance, vitals, report and amount due
    // keep rendering under the new patient's name until the dashboard call
    // returns — and forever if it fails. See clearPatientScopedData.
    clearPatientScopedData(notify: false);
    _currentPatient = patient;
    notifyListeners();
    loadDashboard();
  }

  /// Clears every field that belongs to ONE patient.
  ///
  /// Call on patient switch and on logout. Several family members share this
  /// app, and on a shared phone the previous patient's clinical data
  /// surviving into the next session is a PHI leak, not a caching nicety.
  ///
  /// Pass [notify] false when the caller will notify immediately afterwards.
  void clearPatientScopedData({bool notify = true}) {
    _activeDeployment = null;
    _todayAttendance = null;
    _latestVitals = null;
    _todayReport = null;
    _amountDue = 0;
    _dueDate = null;
    _dashboardError = null;
    _lastUpdatedText = null;
    if (notify) notifyListeners();
  }

  /// Full teardown for logout: also forgets who the patient was.
  void clearSession() {
    clearPatientScopedData(notify: false);
    _currentPatient = null;
    _patients = [];
    notifyListeners();
  }

  /// Add a new patient to the current user's care list.
  ///
  /// The creator becomes the primary contact for the new patient. This is an
  /// in-memory append for now; future iterations will persist to
  /// SharedPreferences and/or the backend.
  Future<void> addPatient(Patient patient) async {
    _patients = [..._patients, patient];
    notifyListeners();
    // TODO(persistence): persist to SharedPreferences / backend.
  }

  // Load dashboard data from API with offline caching
  Future<void> loadDashboard() async {
    if (_currentPatient == null) return;

    _isDashboardLoading = true;
    notifyListeners();

    // Load demo data immediately so the UI is never blank
    _seedDemoDataIfEmpty();

    _isDashboardLoading = false;
    notifyListeners();

    // Then try API in background (will overwrite demo data if successful)
    final patientId = _currentPatient!.id;
    final cacheKey = 'dashboard_$patientId';
    final cache = CacheService.instance;

    try {
      final results = await Future.wait([
        _apiService.getActiveDeployment(patientId),
        _apiService.getTodayAttendance(patientId),
        _apiService.getLatestVitals(patientId),
        _apiService.getTodayReport(patientId),
        _apiService.getBillingSummary(patientId),
      ]).timeout(const Duration(seconds: 5));

      _activeDeployment = results[0] as Deployment?;
      _todayAttendance = results[1] as Attendance?;
      _latestVitals = results[2] as VitalReading?;
      _todayReport = results[3] as DailyReport?;

      final billing = (results[4] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      _amountDue = (billing['amount_due'] as num?)?.toInt() ?? 0;
      final dueDateRaw = billing['due_date'];
      _dueDate = dueDateRaw is String ? DateTime.tryParse(dueDateRaw) : null;

      _dashboardError = null;
      _lastUpdatedText = 'Last updated: just now';
      // Live data arrived — take the sample-data banner down.
      DemoMode.reset();
      await cache.cache(cacheKey, billing);
      notifyListeners();
    } catch (e) {
      Log.warn('Dashboard API unavailable, using demo/cache data',
          error: e, tag: 'AppProvider');
      // Demo data already loaded — no action needed
    }
  }

  void _seedDemoDataIfEmpty() {
    if (_activeDeployment == null) {
      _activeDeployment = DemoData.icuDeployment;
      DemoMode.markServingDemoData();
      _todayAttendance = DemoData.todayAttendance;
      _latestVitals = DemoData.vitalsHistory.last;
      _todayReport = DemoData.todayReport;
      final demoBilling = DemoData.billingSummary;
      _amountDue = (demoBilling['amount_due'] as num?)?.toInt() ?? 0;
      final demoDueRaw = demoBilling['due_date'];
      _dueDate = demoDueRaw is String ? DateTime.tryParse(demoDueRaw) : null;
      _lastUpdatedText = 'Demo data';
    }
  }

  /// Appends a manually entered vital reading to the in-memory history,
  /// promotes it to [latestVitals] when it is the newest entry (today's
  /// reading extends the history — the model stores one row per reading),
  /// and notifies listeners immediately so the chart/stat cards update.
  ///
  /// The API post is attempted afterwards with tolerated failure (demo
  /// mode): on error the reading stays local and a warning is logged.
  Future<void> addVitalReading(VitalReading reading) async {
    _vitalsHistory.add(reading);
    _vitalsHistory.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final latest = _latestVitals;
    if (latest == null || !reading.recordedAt.isBefore(latest.recordedAt)) {
      _latestVitals = reading;
    }
    notifyListeners();

    try {
      await _apiService.submitVitalReading(reading.patientId, reading);
    } catch (e) {
      Log.warn('Vitals API unavailable — reading kept locally (demo mode)',
          error: e, tag: 'AppProvider');
    }
  }

  // Called by SyncService to update provider state with fresh data
  void updateFromSync({
    Deployment? deployment,
    Attendance? attendance,
    VitalReading? vitals,
    DailyReport? report,
    Patient? patient,
    Map<String, dynamic>? billingSummary,
  }) {
    if (deployment != null) _activeDeployment = deployment;
    if (attendance != null) _todayAttendance = attendance;
    if (vitals != null) _latestVitals = vitals;
    if (report != null) _todayReport = report;
    if (patient != null) {
      _currentPatient = patient;
      final idx = _patients.indexWhere((p) => p.id == patient.id);
      if (idx >= 0) {
        _patients[idx] = patient;
      }
    }
    if (billingSummary != null) {
      _amountDue = (billingSummary['amount_due'] as num?)?.toInt() ?? 0;
      final dueRaw = billingSummary['due_date'];
      _dueDate = dueRaw is String ? DateTime.tryParse(dueRaw) : null;
    }
    notifyListeners();
  }
}
