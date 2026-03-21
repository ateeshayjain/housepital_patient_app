import 'package:flutter/material.dart';
import '../models/my_care_models.dart';
import '../services/api_service.dart';

class MyCareProvider extends ChangeNotifier {
  final ApiService _apiService;

  // State
  List<ActiveService> _activeServices = [];
  HealthManager? _healthManager;
  ServiceDetail? _selectedServiceDetail;
  bool _isLoading = false;
  bool _isDetailLoading = false;
  String? _error;
  String? _detailError;
  DateTime? _lastFetchedAt;

  MyCareProvider(this._apiService);

  // Getters
  List<ActiveService> get activeServices => _activeServices;
  HealthManager? get healthManager => _healthManager;
  ServiceDetail? get selectedServiceDetail => _selectedServiceDetail;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  String? get error => _error;
  String? get detailError => _detailError;
  bool get hasActiveServices => _activeServices.isNotEmpty;
  bool get isStale =>
      _lastFetchedAt == null ||
      DateTime.now().difference(_lastFetchedAt!) > const Duration(seconds: 60);

  /// Load top-level My Care data: active services + health manager.
  Future<void> loadMyCareData(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getActiveServices(patientId),
        _apiService.getHealthManager(patientId),
      ]);

      _activeServices = results[0] as List<ActiveService>;
      _healthManager = results[1] as HealthManager?;
      _lastFetchedAt = DateTime.now();
    } on ApiException {
      // Fallback to mock data for UI demo
      _loadMockData();
    } catch (e) {
      // Fallback to mock data for UI demo
      _loadMockData();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mock data for UI demonstration when API is unavailable.
  void _loadMockData() {
    _healthManager = HealthManager(
      id: 'hm-1',
      staffId: 'staff-101',
      name: 'Priya Sharma',
      phone: '+91 98765 43210',
      availableFrom: '08:00',
      availableTo: '20:00',
    );

    _activeServices = [
      ActiveService(
        id: 'svc-1',
        name: 'ICU at Home — Care Package',
        serviceCategory: 'care_package',
        status: 'active',
        startDate: DateTime.now().subtract(const Duration(days: 18)),
        totalDays: 30,
        consumedDays: 18,
        totalStaff: 3,
        checkedInStaff: 2,
        latestVitalLabel: 'BP 128/82 · SpO2 97%',
        latestVitalStatus: 'normal',
        dailyRate: 4500,
        totalPaid: 135000,
        totalConsumed: 81000,
        remaining: 54000,
        renewalDate: DateTime.now().add(const Duration(days: 12)),
        deploymentIds: ['dep-1'],
      ),
      ActiveService(
        id: 'svc-2',
        name: 'Night Caretaker',
        serviceCategory: 'caretaker',
        status: 'active',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        totalDays: 30,
        consumedDays: 10,
        totalStaff: 1,
        checkedInStaff: 1,
        dailyRate: 1200,
        totalPaid: 36000,
        totalConsumed: 12000,
        remaining: 24000,
        renewalDate: DateTime.now().add(const Duration(days: 20)),
        deploymentIds: ['dep-2'],
      ),
      ActiveService(
        id: 'svc-3',
        name: 'Physiotherapy — Knee Rehab',
        serviceCategory: 'physiotherapy',
        status: 'active',
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        totalDays: 15,
        consumedDays: 5,
        isSessionBased: true,
        totalStaff: 1,
        checkedInStaff: 0,
        deploymentIds: ['dep-3'],
      ),
      ActiveService(
        id: 'svc-4',
        name: 'Oxygen Concentrator',
        serviceCategory: 'equipment_rental',
        status: 'active',
        startDate: DateTime.now().subtract(const Duration(days: 25)),
        totalDays: 30,
        consumedDays: 25,
        dailyRate: 500,
        totalPaid: 15000,
        totalConsumed: 12500,
        remaining: 2500,
        renewalDate: DateTime.now().add(const Duration(days: 5)),
        deploymentIds: ['dep-4'],
      ),
    ];

    _lastFetchedAt = DateTime.now();
  }

  /// Load full detail for a single service/deployment.
  Future<void> loadServiceDetail(String deploymentId) async {
    _isDetailLoading = true;
    _detailError = null;
    _selectedServiceDetail = null;
    notifyListeners();

    try {
      _selectedServiceDetail =
          await _apiService.getDeploymentServiceDetail(deploymentId);
    } on ApiException catch (e) {
      _detailError = e.message;
    } catch (e) {
      _detailError = 'Failed to load service detail';
    }

    _isDetailLoading = false;
    notifyListeners();
  }

  /// Called by FCM handler or pull-to-refresh.
  Future<void> refresh(String patientId) => loadMyCareData(patientId);
}
