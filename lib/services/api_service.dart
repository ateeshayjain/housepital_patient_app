import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/models.dart';
import '../models/my_care_models.dart';
import '../models/medication_models.dart';
import '../models/equipment_order.dart';
import 'i_api_service.dart';

class ApiService implements IApiService {
  final String baseUrl;
  String? _authToken;

  /// Maximum number of automatic retries for transient failures.
  static const int _maxRetries = 2;

  /// Base delay between retries (doubles on each attempt).
  static const Duration _retryDelay = Duration(seconds: 1);

  /// Underlying HTTP client. Defaults to a real [http.Client]; tests can
  /// inject a [MockClient] from `package:http/testing.dart` to stub responses.
  /// Added for BUG-10 test coverage — backward compatible (optional named arg).
  final http.Client _client;

  ApiService({
    this.baseUrl = AppConstants.apiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Wraps an HTTP call with retry logic for transient failures
  /// (SocketException, TimeoutException, 5xx status codes).
  Future<http.Response> _withRetry(
      Future<http.Response> Function() request) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await request();
        // Retry on 5xx server errors
        if (response.statusCode >= 500 && attempt < _maxRetries) {
          attempt++;
          if (kDebugMode) {
            debugPrint(
                'Retrying request (attempt $attempt/$_maxRetries) after ${response.statusCode}');
          }
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
        return response;
      } on SocketException {
        if (attempt >= _maxRetries) rethrow;
        attempt++;
        if (kDebugMode) {
          debugPrint(
              'Network error, retrying (attempt $attempt/$_maxRetries)');
        }
        await Future.delayed(_retryDelay * attempt);
      } on TimeoutException {
        if (attempt >= _maxRetries) rethrow;
        attempt++;
        if (kDebugMode) {
          debugPrint(
              'Timeout, retrying (attempt $attempt/$_maxRetries)');
        }
        await Future.delayed(_retryDelay * attempt);
      }
    }
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _withRetry(() => _client.get(uri, headers: _headers));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _withRetry(() => _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _put(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _withRetry(() => _client.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final response = await _withRetry(() => _client.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    ));
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

  /// Paginated report history.
  Future<List<DailyReport>> getReportHistoryPaginated(
    String patientId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _get('/patients/$patientId/reports',
        queryParams: {'page': '$page', 'page_size': '$pageSize'});
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

  // ==================== SLOT AVAILABILITY ====================

  /// Fetches available slot hours for a service on a given date.
  /// Returns a list of maps with 'hour' (int) and 'available' (bool).
  Future<List<Map<String, dynamic>>> getAvailableSlots(
      String serviceId, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _get('/services/$serviceId/slots', queryParams: {
      'date': dateStr,
    });
    return (data['slots'] as List).cast<Map<String, dynamic>>();
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

  /// Paginated notifications.
  Future<List<AppNotification>> getNotificationsPaginated({
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _get('/notifications',
        queryParams: {'page': '$page', 'page_size': '$pageSize'});
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

  /// Paginated transaction list.
  Future<List<PaymentTransaction>> getTransactionsPaginated(
    String patientId, {
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (status != null && status != 'all') params['status'] = status;
    final data = await _get('/patients/$patientId/transactions',
        queryParams: params);
    return ((data['transactions'] ?? data) as List)
        .map((t) => PaymentTransaction.fromJson(t))
        .toList();
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

  // ── Equipment Orders ────────────────────────────────────────

  Future<List<EquipmentOrder>> getEquipmentOrders(String patientId) async {
    final data = await _get('/patients/$patientId/equipment-orders');
    return (data['equipment_orders'] as List)
        .map((o) => EquipmentOrder.fromJson(o))
        .toList();
  }

  // ── Assessment Actions ──────────────────────────────────────

  Future<void> acceptAssessment(String assessmentId) async {
    await _put('/assessments/$assessmentId/accept', body: {});
  }

  Future<void> declineAssessment(String assessmentId) async {
    await _put('/assessments/$assessmentId/decline', body: {});
  }

  // ── Equipment Reviews ──────────────────────────────────────

  Future<List<EquipmentReview>> getEquipmentReviews(String itemId) async {
    final data = await _get('/equipment/$itemId/reviews');
    return (data['reviews'] as List)
        .map((r) => EquipmentReview.fromJson(r))
        .toList();
  }

  Future<void> submitEquipmentReview(String itemId, int rating, String text) async {
    await _post('/equipment/$itemId/reviews', body: {
      'rating': rating,
      'text': text,
    });
  }

  // ── Staff Replacement ─────────────────────────────────────

  Future<Map<String, dynamic>> requestReplacement(
    String deploymentId,
    String reason,
    Map<String, dynamic> preferences,
  ) async {
    return _post('/deployments/$deploymentId/replacement', body: {
      'reason': reason,
      ...preferences,
    });
  }

  // ── Equipment Returns ─────────────────────────────────────

  Future<Map<String, dynamic>> scheduleReturn({
    required String orderId,
    required String reason,
    required String pickupDate,
    required String timeSlot,
    required String condition,
    String? photoUrl,
  }) async {
    return _post('/equipment-orders/$orderId/return', body: {
      'reason': reason,
      'pickup_date': pickupDate,
      'time_slot': timeSlot,
      'condition': condition,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
