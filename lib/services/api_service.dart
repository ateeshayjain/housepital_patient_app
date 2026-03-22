import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/models.dart';
import '../models/my_care_models.dart';
import '../models/medication_models.dart';

class ApiService {
  final String baseUrl;
  String? _authToken;

  ApiService({this.baseUrl = AppConstants.apiBaseUrl});

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(String path,
      {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _put(String path,
      {Map<String, dynamic>? body}) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body.isNotEmpty
            ? jsonDecode(response.body)['message'] ?? 'Unknown error'
            : 'Request failed with status ${response.statusCode}',
      );
    }
  }

  /// Public GET — used by services that build their own API paths.
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams}) =>
      _get(path, queryParams: queryParams);

  // ==================== AUTH ====================

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    return _post('/auth/verify-otp', body: {'phone': phone, 'otp': otp});
  }

  Future<Map<String, dynamic>> completeOnboarding({
    required String name,
    required String relationship,
    required String preferredLanguage,
  }) async {
    return _post('/auth/onboarding', body: {
      'name': name,
      'relationship': relationship,
      'preferred_language': preferredLanguage,
    });
  }

  // ==================== DASHBOARD ====================

  Future<Map<String, dynamic>> getDashboard(String patientId) async {
    return _get('/patients/$patientId/dashboard');
  }

  // ==================== PATIENTS ====================

  Future<List<Patient>> getPatients() async {
    final data = await _get('/patients');
    return (data['patients'] as List)
        .map((p) => Patient.fromJson(p))
        .toList();
  }

  Future<Patient> getPatient(String patientId) async {
    final data = await _get('/patients/$patientId');
    return Patient.fromJson(data['patient']);
  }

  Future<Patient> updatePatient(String patientId, Map<String, dynamic> updates) async {
    final data = await _put('/patients/$patientId', body: updates);
    return Patient.fromJson(data['patient']);
  }

  // ==================== ATTENDANCE ====================

  Future<Attendance?> getTodayAttendance(String patientId) async {
    final data = await _get('/patients/$patientId/attendance/today');
    if (data['attendance'] == null) return null;
    return Attendance.fromJson(data['attendance']);
  }

  Future<List<Attendance>> getAttendanceHistory(String patientId,
      {int page = 1}) async {
    final data = await _get('/patients/$patientId/attendance',
        queryParams: {'page': page.toString()});
    return (data['attendance'] as List)
        .map((a) => Attendance.fromJson(a))
        .toList();
  }

  // ==================== VITALS ====================

  Future<VitalReading?> getLatestVitals(String patientId) async {
    final data = await _get('/patients/$patientId/vitals/latest');
    if (data['vitals'] == null) return null;
    return VitalReading.fromJson(data['vitals']);
  }

  Future<List<VitalReading>> getVitalsHistory(String patientId,
      {String period = '7d'}) async {
    final data = await _get('/patients/$patientId/vitals',
        queryParams: {'period': period});
    return (data['vitals'] as List)
        .map((v) => VitalReading.fromJson(v))
        .toList();
  }

  // ==================== DAILY REPORTS ====================

  Future<DailyReport?> getTodayReport(String patientId) async {
    final data = await _get('/patients/$patientId/reports/today');
    if (data['report'] == null) return null;
    return DailyReport.fromJson(data['report']);
  }

  Future<List<DailyReport>> getReportHistory(String patientId,
      {int page = 1}) async {
    final data = await _get('/patients/$patientId/reports',
        queryParams: {'page': page.toString()});
    return (data['reports'] as List)
        .map((r) => DailyReport.fromJson(r))
        .toList();
  }

  Future<DailyReport> getReportDetail(String reportId) async {
    final data = await _get('/reports/$reportId');
    return DailyReport.fromJson(data['report']);
  }

  // ==================== DEPLOYMENTS ====================

  Future<Deployment?> getActiveDeployment(String patientId) async {
    final data = await _get('/patients/$patientId/deployment');
    if (data['deployment'] == null) return null;
    return Deployment.fromJson(data['deployment']);
  }

  // ==================== STAFF ====================

  Future<StaffProfile> getStaffProfile(String staffId) async {
    final data = await _get('/staff/$staffId/profile');
    return StaffProfile.fromJson(data['staff']);
  }

  // ==================== SERVICES ====================

  Future<List<ServiceItem>> getServiceCatalog() async {
    final data = await _get('/services');
    return (data['services'] as List)
        .map((s) => ServiceItem.fromJson(s))
        .toList();
  }

  Future<ServiceItem> getServiceDetail(String serviceId) async {
    final data = await _get('/services/$serviceId');
    return ServiceItem.fromJson(data['service']);
  }

  // ==================== BOOKINGS ====================

  Future<Booking> createBooking({
    required String patientId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledSlot,
    String? promoCode,
  }) async {
    final data = await _post('/bookings', body: {
      'patient_id': patientId,
      'service_id': serviceId,
      'scheduled_date': scheduledDate,
      'scheduled_slot': scheduledSlot,
      if (promoCode != null) 'promo_code': promoCode,
    });
    return Booking.fromJson(data['booking']);
  }

  Future<List<Booking>> getBookings(String patientId, {int page = 1}) async {
    final data = await _get('/patients/$patientId/bookings',
        queryParams: {'page': page.toString()});
    return (data['bookings'] as List)
        .map((b) => Booking.fromJson(b))
        .toList();
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    await _post('/bookings/$bookingId/cancel', body: {'reason': reason});
  }

  Future<void> submitRating({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await _post('/bookings/$bookingId/rate', body: {
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  // ==================== ASSESSMENTS ====================

  Future<AssessmentRequest> createAssessmentRequest({
    required String patientId,
    required String serviceCategory,
    required Map<String, dynamic> responses,
  }) async {
    final data = await _post('/assessments', body: {
      'patient_id': patientId,
      'service_category': serviceCategory,
      'questionnaire_responses': responses,
    });
    return AssessmentRequest.fromJson(data['assessment']);
  }

  Future<List<AssessmentRequest>> getAssessments(String patientId) async {
    final data = await _get('/patients/$patientId/assessments');
    return (data['assessments'] as List)
        .map((a) => AssessmentRequest.fromJson(a))
        .toList();
  }

  // ==================== BILLING ====================

  Future<Map<String, dynamic>> getBillingSummary(String patientId) async {
    return _get('/patients/$patientId/billing');
  }

  Future<List<Invoice>> getInvoices(String patientId) async {
    final data = await _get('/patients/$patientId/invoices');
    return (data['invoices'] as List)
        .map((i) => Invoice.fromJson(i))
        .toList();
  }

  Future<Invoice> getInvoiceDetail(String invoiceId) async {
    final data = await _get('/invoices/$invoiceId');
    return Invoice.fromJson(data['invoice']);
  }

  // ==================== PAYMENTS ====================

  Future<Map<String, dynamic>> createPaymentOrder({
    required String patientId,
    required int amount,
    required String paymentType,
    String? referenceType,
    String? referenceId,
  }) async {
    return _post('/payments/create-order', body: {
      'patient_id': patientId,
      'amount': amount,
      'payment_type': paymentType,
      if (referenceType != null) 'reference_type': referenceType,
      if (referenceId != null) 'reference_id': referenceId,
    });
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    return _post('/payments/verify', body: {
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_signature': razorpaySignature,
    });
  }

  // ==================== CONCERNS ====================

  Future<FamilyConcern> raiseConcern({
    required String patientId,
    required String category,
    required String description,
    required String urgency,
    String? preferredResolution,
    List<String>? evidenceUrls,
  }) async {
    final data = await _post('/concerns', body: {
      'patient_id': patientId,
      'category': category,
      'description': description,
      'urgency': urgency,
      if (preferredResolution != null)
        'preferred_resolution': preferredResolution,
      if (evidenceUrls != null) 'evidence_urls': evidenceUrls,
    });
    return FamilyConcern.fromJson(data['concern']);
  }

  Future<List<FamilyConcern>> getConcerns(String patientId) async {
    final data = await _get('/patients/$patientId/concerns');
    return (data['concerns'] as List)
        .map((c) => FamilyConcern.fromJson(c))
        .toList();
  }

  // ==================== RATINGS ====================

  Future<void> submitDailyRating({
    required String patientId,
    required String deploymentId,
    required int rating,
    String? comment,
  }) async {
    await _post('/ratings', body: {
      'patient_id': patientId,
      'deployment_id': deploymentId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<AppNotification>> getNotifications({int page = 1}) async {
    final data =
        await _get('/notifications', queryParams: {'page': page.toString()});
    return (data['notifications'] as List)
        .map((n) => AppNotification.fromJson(n))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _put('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _put('/notifications/read-all');
  }

  // ==================== FAMILY MEMBERS ====================

  Future<List<FamilyMember>> getFamilyMembers(String patientId) async {
    final data = await _get('/patients/$patientId/family');
    return (data['family_members'] as List)
        .map((f) => FamilyMember.fromJson(f))
        .toList();
  }

  Future<void> inviteFamilyMember(String patientId, String phone) async {
    await _post('/patients/$patientId/family/invite', body: {'phone': phone});
  }

  Future<void> removeFamilyMemberLegacy(String memberId) async {
    await _put('/family/$memberId/remove');
  }

  // ==================== FCM TOKEN ====================

  Future<void> updateFcmToken(String token) async {
    await _post('/auth/fcm-token', body: {'token': token});
  }

  // ==================== COUPONS ====================

  Future<Coupon> validateCoupon(String code, String serviceCategory, int orderAmount) async {
    final data = await _post('/coupons/validate', body: {
      'code': code,
      'category': serviceCategory,
      'order_amount': orderAmount,
    });
    return Coupon.fromJson(data);
  }

  Future<List<Coupon>> getAvailableCoupons(String? category) async {
    final data = await _get('/coupons${category != null ? '?category=$category' : ''}');
    return (data as List).map((c) => Coupon.fromJson(c)).toList();
  }

  // ==================== TRANSACTIONS ====================

  Future<List<PaymentTransaction>> getTransactions(String patientId, {String? status, int? limit}) async {
    String url = '/patients/$patientId/transactions?';
    if (status != null) url += 'status=$status&';
    if (limit != null) url += 'limit=$limit';
    final data = await _get(url);
    return (data as List).map((t) => PaymentTransaction.fromJson(t)).toList();
  }

  Future<PaymentTransaction> getTransactionDetail(String transactionId) async {
    final data = await _get('/transactions/$transactionId');
    return PaymentTransaction.fromJson(data);
  }

  // ==================== ENHANCED BILLING ====================

  Future<BillingSummary> getBillingSummaryFull(String patientId) async {
    final data = await _get('/patients/$patientId/billing/summary');
    return BillingSummary.fromJson(data);
  }

  // ==================== SYNC ====================

  Future<Map<String, dynamic>> syncDashboardData(String patientId, DateTime? lastSyncAt) async {
    String url = '/patients/$patientId/sync';
    if (lastSyncAt != null) url += '?since=${lastSyncAt.toIso8601String()}';
    final data = await _get(url);
    return data;
  }

  // ==================== PROFILE ====================

  Future<Patient> updatePatientProfile(String patientId, Map<String, dynamic> data) async {
    final result = await _put('/patients/$patientId', body: data);
    return Patient.fromJson(result);
  }

  Future<FamilyMember> addFamilyMember(String patientId, Map<String, dynamic> data) async {
    final result = await _post('/patients/$patientId/family', body: data);
    return FamilyMember.fromJson(result);
  }

  Future<void> removeFamilyMember(String patientId, String memberId) async {
    await _post('/patients/$patientId/family/$memberId/remove', body: {});
  }

  Future<FamilyMember> updateFamilyMember(String patientId, String memberId, Map<String, dynamic> data) async {
    final result = await _put('/patients/$patientId/family/$memberId', body: data);
    return FamilyMember.fromJson(result);
  }

  // ── Equipment Catalog (backend-driven) ──────────────────────
  Future<List<EquipmentItem>> getEquipmentCatalog({
    String? category,
    String? type,
    String? search,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (type != null) params['type'] = type;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final data = await _get('/equipment', queryParams: params);
    return (data['items'] as List)
        .map((e) => EquipmentItem.fromJson(e))
        .toList();
  }

  // ==================== MY CARE ====================

  Future<List<ActiveService>> getActiveServices(String patientId) async {
    final data = await _get('/patients/$patientId/active-services');
    return (data['services'] as List)
        .map((s) => ActiveService.fromJson(s))
        .toList();
  }

  Future<HealthManager?> getHealthManager(String patientId) async {
    try {
      final data = await _get('/patients/$patientId/health-manager');
      return HealthManager.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ServiceDetail> getDeploymentServiceDetail(String deploymentId) async {
    final data = await _get('/deployments/$deploymentId/service-detail');
    return ServiceDetail.fromJson(data);
  }

  Future<List<Attendance>> getAttendanceHistoryPaginated(
    String deploymentId, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final data = await _get(
      '/deployments/$deploymentId/attendance',
      queryParams: {'page': '$page', 'page_size': '$pageSize'},
    );
    return (data['records'] as List)
        .map((a) => Attendance.fromJson(a))
        .toList();
  }

  // ==================== MEDICATIONS ====================

  Future<List<MedicationFull>> getMedications(String patientId) async {
    final data = await _get('/patients/$patientId/medications');
    return (data['medications'] as List)
        .map((m) => MedicationFull.fromJson(m))
        .toList();
  }

  Future<MedicationFull> addMedication(
      String patientId, Map<String, dynamic> body) async {
    final data =
        await _post('/patients/$patientId/medications', body: body);
    return MedicationFull.fromJson(data);
  }

  Future<MedicationFull> updateMedication(
      String patientId, String medicationId, Map<String, dynamic> body) async {
    final data = await _put(
        '/patients/$patientId/medications/$medicationId',
        body: body);
    return MedicationFull.fromJson(data);
  }

  Future<void> deleteMedication(
      String patientId, String medicationId) async {
    await _delete('/patients/$patientId/medications/$medicationId');
  }

  Future<List<MedicationLog>> getMedicationLogs(
    String patientId, {
    String? date, // YYYY-MM-DD, defaults to today on backend
  }) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    final data = await _get('/patients/$patientId/medication-logs',
        queryParams: params.isNotEmpty ? params : null);
    return (data['logs'] as List)
        .map((l) => MedicationLog.fromJson(l))
        .toList();
  }

  /// Note: Spec says /medication-logs/{id}/stock but stock belongs on the medication
  /// entity, not on a log entry. Using /medications/{id}/stock instead.
  Future<void> updateMedicationStock(
      String patientId, String medicationId, int stockCount) async {
    await _put('/patients/$patientId/medications/$medicationId/stock',
        body: {'stock_count': stockCount});
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
