// test/providers/mock_api_service.dart
//
// Manual mock of ApiService for unit-testing My Care and Medication providers.
// No mockito / mocktail — plain Dart override pattern.

import 'package:housepital_patient/services/api_service.dart';
import 'package:housepital_patient/models/my_care_models.dart';
import 'package:housepital_patient/models/medication_models.dart';

class MockApiService extends ApiService {
  // ── Return-value stubs ───────────────────────────────────────────────────

  List<ActiveService> activeServicesResult = [];
  HealthManager? healthManagerResult;
  ServiceDetail? serviceDetailResult;

  List<MedicationFull> medicationsResult = [];
  List<MedicationLog> medicationLogsResult = [];
  MedicationFull? addMedicationResult;
  MedicationFull? updateMedicationResult;

  // ── Error-injection flags ────────────────────────────────────────────────

  bool shouldThrowApiException = false;
  String apiExceptionMessage = 'Test error';
  int apiExceptionStatusCode = 500;
  bool shouldThrowGenericError = false;

  // ── Call counters ────────────────────────────────────────────────────────

  int getActiveServicesCalls = 0;
  int getHealthManagerCalls = 0;
  int getDeploymentServiceDetailCalls = 0;
  int getMedicationsCalls = 0;
  int getMedicationLogsCalls = 0;
  int addMedicationCalls = 0;
  int updateMedicationCalls = 0;
  int deleteMedicationCalls = 0;
  int updateMedicationStockCalls = 0;

  // Recorded arguments (last call)
  String? lastPatientId;
  String? lastMedicationId;
  String? lastDeploymentId;
  Map<String, dynamic>? lastBody;

  // ── Helper ───────────────────────────────────────────────────────────────

  void _maybeThrow() {
    if (shouldThrowApiException) {
      throw ApiException(
          statusCode: apiExceptionStatusCode, message: apiExceptionMessage);
    }
    if (shouldThrowGenericError) {
      throw Exception('generic error');
    }
  }

  void reset() {
    activeServicesResult = [];
    healthManagerResult = null;
    serviceDetailResult = null;
    medicationsResult = [];
    medicationLogsResult = [];
    addMedicationResult = null;
    updateMedicationResult = null;
    shouldThrowApiException = false;
    apiExceptionMessage = 'Test error';
    apiExceptionStatusCode = 500;
    shouldThrowGenericError = false;
    getActiveServicesCalls = 0;
    getHealthManagerCalls = 0;
    getDeploymentServiceDetailCalls = 0;
    getMedicationsCalls = 0;
    getMedicationLogsCalls = 0;
    addMedicationCalls = 0;
    updateMedicationCalls = 0;
    deleteMedicationCalls = 0;
    updateMedicationStockCalls = 0;
    lastPatientId = null;
    lastMedicationId = null;
    lastDeploymentId = null;
    lastBody = null;
  }

  // ── My Care overrides ─────────────────────────────────────────────────────

  @override
  Future<List<ActiveService>> getActiveServices(String patientId) async {
    getActiveServicesCalls++;
    lastPatientId = patientId;
    _maybeThrow();
    return activeServicesResult;
  }

  @override
  Future<HealthManager?> getHealthManager(String patientId) async {
    getHealthManagerCalls++;
    lastPatientId = patientId;
    _maybeThrow();
    return healthManagerResult;
  }

  @override
  Future<ServiceDetail> getDeploymentServiceDetail(
      String deploymentId) async {
    getDeploymentServiceDetailCalls++;
    lastDeploymentId = deploymentId;
    _maybeThrow();
    if (serviceDetailResult == null) {
      throw StateError('serviceDetailResult not configured in mock');
    }
    return serviceDetailResult!;
  }

  // ── Medication overrides ──────────────────────────────────────────────────

  @override
  Future<List<MedicationFull>> getMedications(String patientId) async {
    getMedicationsCalls++;
    lastPatientId = patientId;
    _maybeThrow();
    return medicationsResult;
  }

  @override
  Future<List<MedicationLog>> getMedicationLogs(String patientId,
      {String? date}) async {
    getMedicationLogsCalls++;
    lastPatientId = patientId;
    _maybeThrow();
    return medicationLogsResult;
  }

  @override
  Future<MedicationFull> addMedication(
      String patientId, Map<String, dynamic> body) async {
    addMedicationCalls++;
    lastPatientId = patientId;
    lastBody = body;
    _maybeThrow();
    if (addMedicationResult == null) {
      throw StateError('addMedicationResult not configured in mock');
    }
    return addMedicationResult!;
  }

  @override
  Future<MedicationFull> updateMedication(
      String patientId, String medicationId, Map<String, dynamic> body) async {
    updateMedicationCalls++;
    lastPatientId = patientId;
    lastMedicationId = medicationId;
    lastBody = body;
    _maybeThrow();
    if (updateMedicationResult == null) {
      throw StateError('updateMedicationResult not configured in mock');
    }
    return updateMedicationResult!;
  }

  @override
  Future<void> deleteMedication(
      String patientId, String medicationId) async {
    deleteMedicationCalls++;
    lastPatientId = patientId;
    lastMedicationId = medicationId;
    _maybeThrow();
  }

  @override
  Future<void> updateMedicationStock(
      String patientId, String medicationId, int stockCount) async {
    updateMedicationStockCalls++;
    lastPatientId = patientId;
    lastMedicationId = medicationId;
    _maybeThrow();
  }
}
