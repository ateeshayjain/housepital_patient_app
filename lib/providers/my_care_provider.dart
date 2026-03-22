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
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Unable to load services. Pull down to retry.';
    }

    _isLoading = false;
    notifyListeners();
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
