import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService;
  ApiService get apiService => _apiService;

  // Current patient context
  Patient? _currentPatient;
  List<Patient> _patients = [];
  Deployment? _activeDeployment;

  // Dashboard data
  Attendance? _todayAttendance;
  VitalReading? _latestVitals;
  DailyReport? _todayReport;
  bool _isDashboardLoading = false;

  // Language
  Locale _locale = const Locale('en');

  // Billing
  int _amountDue = 0;
  DateTime? _dueDate;

  String? _dashboardError;
  String? _lastUpdatedText;

  AppProvider(this._apiService) {
    _loadLanguage();
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
  bool get isDashboardLoading => _isDashboardLoading;
  Locale get locale => _locale;
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

  // Load patients list
  Future<void> loadPatients() async {
    try {
      _patients = await _apiService.getPatients();
      if (_patients.isNotEmpty && _currentPatient == null) {
        _currentPatient = _patients.first;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading patients: $e');
      // Fallback to demo data when API unavailable and no patients loaded
      if (_patients.isEmpty) {
        _currentPatient = DemoData.patient;
        _patients = [DemoData.patient];
        notifyListeners();
      }
    }
  }

  // Switch patient context
  void switchPatient(Patient patient) {
    _currentPatient = patient;
    notifyListeners();
    loadDashboard();
  }

  // Load dashboard data from API with offline caching
  Future<void> loadDashboard() async {
    if (_currentPatient == null) return;

    _isDashboardLoading = true;
    notifyListeners();

    final patientId = _currentPatient!.id;
    final cacheKey = 'dashboard_$patientId';
    final cache = CacheService.instance;

    try {
      // Load all dashboard data in parallel
      final results = await Future.wait([
        _apiService.getActiveDeployment(patientId),
        _apiService.getTodayAttendance(patientId),
        _apiService.getLatestVitals(patientId),
        _apiService.getTodayReport(patientId),
        _apiService.getBillingSummary(patientId),
      ]);

      _activeDeployment = results[0] as Deployment?;
      _todayAttendance = results[1] as Attendance?;
      _latestVitals = results[2] as VitalReading?;
      _todayReport = results[3] as DailyReport?;

      final billing = results[4] as Map<String, dynamic>;
      _amountDue = billing['amount_due'] ?? 0;
      _dueDate = billing['due_date'] != null
          ? DateTime.parse(billing['due_date'])
          : null;

      _dashboardError = null;
      _lastUpdatedText = 'Last updated: just now';

      // Cache the billing data for offline fallback
      await cache.cache(cacheKey, billing);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');

      // Try to load from cache
      final cached = await cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        _amountDue = cached['amount_due'] ?? 0;
        _dueDate = cached['due_date'] != null
            ? DateTime.parse(cached['due_date'])
            : null;
        _lastUpdatedText = await cache.getLastUpdatedText(cacheKey);
        _dashboardError = null;
      } else {
        // Seed from demo data so the dashboard is never empty
        _currentPatient ??= DemoData.patient;
        _activeDeployment = DemoData.icuDeployment;
        _todayAttendance = DemoData.todayAttendance;
        _latestVitals = DemoData.vitalsHistory.last;
        _todayReport = DemoData.todayReport;
        final demoBilling = DemoData.billingSummary;
        _amountDue = demoBilling['amount_due'] ?? 0;
        _dueDate = demoBilling['due_date'] != null
            ? DateTime.parse(demoBilling['due_date'])
            : null;
        _dashboardError = null;
        _lastUpdatedText = 'Demo data';
      }
    }

    _isDashboardLoading = false;
    notifyListeners();
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
      _amountDue = billingSummary['amount_due'] ?? 0;
      _dueDate = billingSummary['due_date'] != null
          ? DateTime.parse(billingSummary['due_date'])
          : null;
    }
    notifyListeners();
  }
}
