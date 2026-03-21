import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService;

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

  AppProvider(this._apiService) {
    _loadLanguage();
    _loadMockData(); // TODO: Remove after backend is ready
  }

  void _loadMockData() {
    _currentPatient = Patient.fromJson({
      'id': 'p1',
      'name': 'Ramesh Kumar',
      'age': 72,
      'gender': 'male',
      'mobility_status': 'needs_support',
      'allergies': ['Penicillin', 'Dust'],
      'dietary_restrictions': 'Low sodium diet',
      'doctor_name': 'Dr. Anita Sharma',
      'doctor_phone': '+919876543210',
    });
    _patients = [_currentPatient!];

    _activeDeployment = Deployment.fromJson({
      'id': 'd1',
      'patient_id': 'p1',
      'staff_id': 's1',
      'staff_name': 'Priya Mehra',
      'staff_role': 'Nurse',
      'staff_rating': 4.8,
      'start_date': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      'shift_start': '08:00',
      'shift_end': '20:00',
      'total_days': 90,
    });

    _todayAttendance = Attendance.fromJson({
      'id': 'a1',
      'deployment_id': 'd1',
      'date': DateTime.now().toIso8601String(),
      'status': 'checked_in',
      'check_in_time': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'staff_name': 'Priya Mehra',
    });

    _latestVitals = VitalReading.fromJson({
      'id': 'v1',
      'patient_id': 'p1',
      'recorded_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'systolic': 128.0,
      'diastolic': 82.0,
      'pulse': 74.0,
      'spo2': 97.0,
      'temperature': 98.4,
      'sugar': 110.0,
    });

    _todayReport = DailyReport.fromJson({
      'id': 'r1',
      'deployment_id': 'd1',
      'staff_id': 's1',
      'patient_id': 'p1',
      'date': DateTime.now().toIso8601String(),
      'staff_name': 'Priya Mehra',
      'status': 'in_progress',
      'completed_tasks': 5,
      'total_tasks': 8,
      'sections': [
        {
          'name': 'Morning Routine',
          'status': 'done',
          'tasks': [
            {'name': 'Bath & Hygiene', 'completed': true},
            {'name': 'Breakfast', 'completed': true},
            {'name': 'Morning Medication', 'completed': true},
          ]
        },
        {
          'name': 'Afternoon Care',
          'status': 'partial',
          'tasks': [
            {'name': 'Lunch', 'completed': true},
            {'name': 'Physiotherapy', 'completed': false},
            {'name': 'Afternoon Vitals', 'completed': true},
          ]
        },
        {
          'name': 'Evening Routine',
          'status': 'pending',
          'tasks': [
            {'name': 'Dinner', 'completed': false},
            {'name': 'Night Medication', 'completed': false},
          ]
        },
      ],
    });

    _amountDue = 24500;
    _dueDate = DateTime.now().add(const Duration(days: 5));
  }

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
    }
  }

  // Switch patient context
  void switchPatient(Patient patient) {
    _currentPatient = patient;
    notifyListeners();
    loadDashboard();
  }

  // Load dashboard data
  Future<void> loadDashboard() async {
    if (_currentPatient == null) return;

    _isDashboardLoading = true;
    notifyListeners();

    try {
      final patientId = _currentPatient!.id;

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
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
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
