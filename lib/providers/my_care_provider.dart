import 'package:flutter/material.dart';
import '../data/demo_data.dart';
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

    // Seed demo data immediately so UI is never empty
    if (_activeServices.isEmpty) {
      _activeServices = DemoData.activeServices;
      _healthManager = DemoData.healthManager;
      _lastFetchedAt = DateTime.now();
    }

    _isLoading = false;
    notifyListeners();

    // Then try API in background (overwrites demo if successful)
    try {
      final results = await Future.wait([
        _apiService.getActiveServices(patientId),
        _apiService.getHealthManager(patientId),
      ]).timeout(const Duration(seconds: 5));

      _activeServices = results[0] as List<ActiveService>;
      _healthManager = results[1] as HealthManager?;
      _lastFetchedAt = DateTime.now();
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('MyCare API unavailable, using demo data: $e');
      // NOTE: Demo data already loaded — no action needed
    }
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
      // Fallback to demo ICU service detail
      if (deploymentId == 'dep_icu_001' ||
          deploymentId == 'svc_icu_001') {
        _selectedServiceDetail = DemoData.icuServiceDetail;
        _detailError = null;
      } else {
        _detailError = 'Failed to load service detail';
      }
    }

    _isDetailLoading = false;
    notifyListeners();
  }

  /// Called by FCM handler or pull-to-refresh.
  Future<void> refresh(String patientId) => loadMyCareData(patientId);
}
