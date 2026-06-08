import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/models.dart';
import '../models/my_care_models.dart';
import '../models/medication_models.dart';
import '../models/equipment_order.dart';
import '../models/article.dart';
import '../utils/logger.dart';
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

  /// audit batch 4 (Agent J): callback invoked on a 401, allowing the
  /// auth layer (typically [AuthProvider]) to refresh the Firebase ID token
  /// and tell us whether to retry the original request once. Returns true
  /// to retry, false to surface the 401 as an [ApiException]. Kept as an
  /// injectable callback rather than a hard dependency on AuthProvider so
  /// we don't create a circular dependency between providers and services.
  Future<bool> Function()? onUnauthorized;

  ApiService({
    this.baseUrl = AppConstants.apiBaseUrl,
    http.Client? client,
    this.onUnauthorized,
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
          Log.debug(
              'Retrying request (attempt $attempt/$_maxRetries) after ${response.statusCode}',
              tag: 'ApiService');
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
        return response;
      } on SocketException {
        if (attempt >= _maxRetries) rethrow;
        attempt++;
        Log.debug('Network error, retrying (attempt $attempt/$_maxRetries)',
            tag: 'ApiService');
        await Future.delayed(_retryDelay * attempt);
      } on TimeoutException {
        if (attempt >= _maxRetries) rethrow;
        attempt++;
        Log.debug('Timeout, retrying (attempt $attempt/$_maxRetries)',
            tag: 'ApiService');
        await Future.delayed(_retryDelay * attempt);
      }
    }
  }

  /// audit batch 4 (Agent J): wraps a request closure with one-shot 401
  /// recovery — if the first response is 401 and we have an [onUnauthorized]
  /// callback, ask the auth layer to refresh and retry the request ONCE.
  /// This is intentionally separate from the 5xx/network [_withRetry] loop
  /// so a permanent 401 doesn't fan out into N retries.
  Future<http.Response> _withAuthRecovery(
      Future<http.Response> Function() request) async {
    final response = await _withRetry(request);
    if (response.statusCode != 401 || onUnauthorized == null) return response;
    final retry = await onUnauthorized!();
    if (!retry) return response;
    // Fresh request with the refreshed Authorization header.
    return await _withRetry(request);
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response =
        await _withAuthRecovery(() => _client.get(uri, headers: _headers));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _withAuthRecovery(() => _client.post(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _put(String path,
      {Map<String, dynamic>? body}) async {
    final response = await _withAuthRecovery(() => _client.put(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final response = await _withAuthRecovery(() => _client.delete(
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
  @override
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams}) =>
      _get(path, queryParams: queryParams);

  // ==================== AUTH ====================

  @override
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    return _post('/auth/verify-otp', body: {'phone': phone, 'otp': otp});
  }

  @override
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

  @override
  Future<Map<String, dynamic>> getDashboard(String patientId) async {
    return _get('/patients/$patientId/dashboard');
  }

  // ==================== PATIENTS ====================

  @override
  Future<List<Patient>> getPatients() async {
    final data = await _get('/patients');
    return (data['patients'] as List)
        .map((p) => Patient.fromJson(p))
        .toList();
  }

  @override
  Future<Patient> getPatient(String patientId) async {
    final data = await _get('/patients/$patientId');
    return Patient.fromJson(data['patient']);
  }

  @override
  Future<Patient> updatePatient(String patientId, Map<String, dynamic> updates) async {
    final data = await _put('/patients/$patientId', body: updates);
    return Patient.fromJson(data['patient']);
  }

  // ==================== ATTENDANCE ====================

  @override
  Future<Attendance?> getTodayAttendance(String patientId) async {
    final data = await _get('/patients/$patientId/attendance/today');
    if (data['attendance'] == null) return null;
    return Attendance.fromJson(data['attendance']);
  }

  @override
  Future<List<Attendance>> getAttendanceHistory(String patientId,
      {int page = 1}) async {
    final data = await _get('/patients/$patientId/attendance',
        queryParams: {'page': page.toString()});
    return (data['attendance'] as List)
        .map((a) => Attendance.fromJson(a))
        .toList();
  }

  // ==================== VITALS ====================

  @override
  Future<VitalReading?> getLatestVitals(String patientId) async {
    final data = await _get('/patients/$patientId/vitals/latest');
    if (data['vitals'] == null) return null;
    return VitalReading.fromJson(data['vitals']);
  }

  @override
  Future<List<VitalReading>> getVitalsHistory(String patientId,
      {String period = '7d'}) async {
    final data = await _get('/patients/$patientId/vitals',
        queryParams: {'period': period});
    return (data['vitals'] as List)
        .map((v) => VitalReading.fromJson(v))
        .toList();
  }

  // ==================== DAILY REPORTS ====================

  @override
  Future<DailyReport?> getTodayReport(String patientId) async {
    final data = await _get('/patients/$patientId/reports/today');
    if (data['report'] == null) return null;
    return DailyReport.fromJson(data['report']);
  }

  @override
  Future<List<DailyReport>> getReportHistory(String patientId,
      {int page = 1}) async {
    final data = await _get('/patients/$patientId/reports',
        queryParams: {'page': page.toString()});
    return (data['reports'] as List)
        .map((r) => DailyReport.fromJson(r))
        .toList();
  }

  /// Paginated report history.
  @override
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

  @override
  Future<DailyReport> getReportDetail(String reportId) async {
    final data = await _get('/reports/$reportId');
    return DailyReport.fromJson(data['report']);
  }

  // ==================== DEPLOYMENTS ====================

  @override
  Future<Deployment?> getActiveDeployment(String patientId) async {
    final data = await _get('/patients/$patientId/deployment');
    if (data['deployment'] == null) return null;
    return Deployment.fromJson(data['deployment']);
  }

  // ==================== STAFF ====================

  @override
  Future<StaffProfile> getStaffProfile(String staffId) async {
    final data = await _get('/staff/$staffId/profile');
    return StaffProfile.fromJson(data['staff']);
  }

  // ==================== SERVICES ====================

  @override
  Future<List<ServiceItem>> getServiceCatalog() async {
    final data = await _get('/services');
    return (data['services'] as List)
        .map((s) => ServiceItem.fromJson(s))
        .toList();
  }

  @override
  Future<ServiceItem> getServiceDetail(String serviceId) async {
    final data = await _get('/services/$serviceId');
    return ServiceItem.fromJson(data['service']);
  }

  // ==================== SLOT AVAILABILITY ====================

  /// Fetches available slot hours for a service on a given date.
  /// Returns a list of maps with 'hour' (int) and 'available' (bool).
  @override
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

  @override
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
      'promo_code': ?promoCode,
    });
    return Booking.fromJson(data['booking']);
  }

  @override
  Future<List<Booking>> getBookings(String patientId, {int page = 1}) async {
    final data = await _get('/patients/$patientId/bookings',
        queryParams: {'page': page.toString()});
    return (data['bookings'] as List)
        .map((b) => Booking.fromJson(b))
        .toList();
  }

  @override
  Future<void> cancelBooking(String bookingId, String reason) async {
    await _post('/bookings/$bookingId/cancel', body: {'reason': reason});
  }

  @override
  Future<void> submitRating({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await _post('/bookings/$bookingId/rate', body: {
      'rating': rating,
      'comment': ?comment,
    });
  }

  // ==================== ASSESSMENTS ====================

  @override
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

  @override
  Future<List<AssessmentRequest>> getAssessments(String patientId) async {
    final data = await _get('/patients/$patientId/assessments');
    return (data['assessments'] as List)
        .map((a) => AssessmentRequest.fromJson(a))
        .toList();
  }

  // ==================== BILLING ====================

  @override
  Future<Map<String, dynamic>> getBillingSummary(String patientId) async {
    return _get('/patients/$patientId/billing');
  }

  @override
  Future<List<Invoice>> getInvoices(String patientId) async {
    final data = await _get('/patients/$patientId/invoices');
    return (data['invoices'] as List)
        .map((i) => Invoice.fromJson(i))
        .toList();
  }

  @override
  Future<Invoice> getInvoiceDetail(String invoiceId) async {
    final data = await _get('/invoices/$invoiceId');
    return Invoice.fromJson(data['invoice']);
  }

  // ==================== PAYMENTS ====================

  @override
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
      'reference_type': ?referenceType,
      'reference_id': ?referenceId,
    });
  }

  @override
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

  @override
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
      'preferred_resolution': ?preferredResolution,
      'evidence_urls': ?evidenceUrls,
    });
    return FamilyConcern.fromJson(data['concern']);
  }

  @override
  Future<List<FamilyConcern>> getConcerns(String patientId) async {
    final data = await _get('/patients/$patientId/concerns');
    return (data['concerns'] as List)
        .map((c) => FamilyConcern.fromJson(c))
        .toList();
  }

  // ==================== RATINGS ====================

  @override
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
      'comment': ?comment,
    });
  }

  // ==================== NOTIFICATIONS ====================

  @override
  Future<List<AppNotification>> getNotifications({int page = 1}) async {
    final data =
        await _get('/notifications', queryParams: {'page': page.toString()});
    return (data['notifications'] as List)
        .map((n) => AppNotification.fromJson(n))
        .toList();
  }

  /// Paginated notifications.
  @override
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

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _put('/notifications/$notificationId/read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _put('/notifications/read-all');
  }

  // ==================== FAMILY MEMBERS ====================

  @override
  Future<List<FamilyMember>> getFamilyMembers(String patientId) async {
    final data = await _get('/patients/$patientId/family');
    return (data['family_members'] as List)
        .map((f) => FamilyMember.fromJson(f))
        .toList();
  }

  @override
  Future<void> inviteFamilyMember(String patientId, String phone) async {
    await _post('/patients/$patientId/family/invite', body: {'phone': phone});
  }

  @override
  Future<void> removeFamilyMemberLegacy(String memberId) async {
    await _put('/family/$memberId/remove');
  }

  // ==================== FCM TOKEN ====================

  @override
  Future<void> updateFcmToken(String token) async {
    await _post('/auth/fcm-token', body: {'token': token});
  }

  // ==================== COUPONS ====================

  @override
  Future<Coupon> validateCoupon(String code, String serviceCategory, int orderAmount) async {
    final data = await _post('/coupons/validate', body: {
      'code': code,
      'category': serviceCategory,
      'order_amount': orderAmount,
    });
    return Coupon.fromJson(data);
  }

  @override
  Future<List<Coupon>> getAvailableCoupons(String? category) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    final data =
        await _get('/coupons', queryParams: params.isNotEmpty ? params : null);
    return (data as List).map((c) => Coupon.fromJson(c)).toList();
  }

  // ==================== TRANSACTIONS ====================

  @override
  Future<List<PaymentTransaction>> getTransactions(String patientId, {String? status, int? limit}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (limit != null) params['limit'] = '$limit';
    final data = await _get('/patients/$patientId/transactions',
        queryParams: params.isNotEmpty ? params : null);
    return (data as List).map((t) => PaymentTransaction.fromJson(t)).toList();
  }

  /// Paginated transaction list.
  @override
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

  @override
  Future<PaymentTransaction> getTransactionDetail(String transactionId) async {
    final data = await _get('/transactions/$transactionId');
    return PaymentTransaction.fromJson(data);
  }

  // ==================== ENHANCED BILLING ====================

  @override
  Future<BillingSummary> getBillingSummaryFull(String patientId) async {
    final data = await _get('/patients/$patientId/billing/summary');
    return BillingSummary.fromJson(data);
  }

  // ==================== SYNC ====================

  @override
  Future<Map<String, dynamic>> syncDashboardData(String patientId, DateTime? lastSyncAt) async {
    String url = '/patients/$patientId/sync';
    if (lastSyncAt != null) url += '?since=${lastSyncAt.toIso8601String()}';
    final data = await _get(url);
    return data;
  }

  // ==================== PROFILE ====================

  @override
  Future<Patient> updatePatientProfile(String patientId, Map<String, dynamic> data) async {
    final result = await _put('/patients/$patientId', body: data);
    return Patient.fromJson(result);
  }

  @override
  Future<FamilyMember> addFamilyMember(String patientId, Map<String, dynamic> data) async {
    final result = await _post('/patients/$patientId/family', body: data);
    return FamilyMember.fromJson(result);
  }

  @override
  Future<void> removeFamilyMember(String patientId, String memberId) async {
    await _post('/patients/$patientId/family/$memberId/remove', body: {});
  }

  @override
  Future<FamilyMember> updateFamilyMember(String patientId, String memberId, Map<String, dynamic> data) async {
    final result = await _put('/patients/$patientId/family/$memberId', body: data);
    return FamilyMember.fromJson(result);
  }

  // ── Equipment Catalog (backend-driven) ──────────────────────
  @override
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

  @override
  Future<List<ActiveService>> getActiveServices(String patientId) async {
    final data = await _get('/patients/$patientId/active-services');
    return (data['services'] as List)
        .map((s) => ActiveService.fromJson(s))
        .toList();
  }

  @override
  Future<HealthManager?> getHealthManager(String patientId) async {
    try {
      final data = await _get('/patients/$patientId/health-manager');
      return HealthManager.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ServiceDetail> getDeploymentServiceDetail(String deploymentId) async {
    final data = await _get('/deployments/$deploymentId/service-detail');
    return ServiceDetail.fromJson(data);
  }

  @override
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

  @override
  Future<List<MedicationFull>> getMedications(String patientId) async {
    final data = await _get('/patients/$patientId/medications');
    return (data['medications'] as List)
        .map((m) => MedicationFull.fromJson(m))
        .toList();
  }

  @override
  Future<MedicationFull> addMedication(
      String patientId, Map<String, dynamic> body) async {
    final data =
        await _post('/patients/$patientId/medications', body: body);
    return MedicationFull.fromJson(data);
  }

  @override
  Future<MedicationFull> updateMedication(
      String patientId, String medicationId, Map<String, dynamic> body) async {
    final data = await _put(
        '/patients/$patientId/medications/$medicationId',
        body: body);
    return MedicationFull.fromJson(data);
  }

  @override
  Future<void> deleteMedication(
      String patientId, String medicationId) async {
    await _delete('/patients/$patientId/medications/$medicationId');
  }

  @override
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
  @override
  Future<void> updateMedicationStock(
      String patientId, String medicationId, int stockCount) async {
    await _put('/patients/$patientId/medications/$medicationId/stock',
        body: {'stock_count': stockCount});
  }

  // ── Equipment Orders ────────────────────────────────────────

  @override
  Future<List<EquipmentOrder>> getEquipmentOrders(String patientId) async {
    final data = await _get('/patients/$patientId/equipment-orders');
    return (data['equipment_orders'] as List)
        .map((o) => EquipmentOrder.fromJson(o))
        .toList();
  }

  // ── Assessment Actions ──────────────────────────────────────

  @override
  Future<void> acceptAssessment(String assessmentId) async {
    await _put('/assessments/$assessmentId/accept', body: {});
  }

  @override
  Future<void> declineAssessment(String assessmentId) async {
    await _put('/assessments/$assessmentId/decline', body: {});
  }

  // ── Equipment Reviews ──────────────────────────────────────

  @override
  Future<List<EquipmentReview>> getEquipmentReviews(String itemId) async {
    final data = await _get('/equipment/$itemId/reviews');
    return (data['reviews'] as List)
        .map((r) => EquipmentReview.fromJson(r))
        .toList();
  }

  @override
  Future<void> submitEquipmentReview(String itemId, int rating, String text) async {
    await _post('/equipment/$itemId/reviews', body: {
      'rating': rating,
      'text': text,
    });
  }

  // ── Staff Replacement ─────────────────────────────────────

  @override
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

  @override
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
      'photo_url': ?photoUrl,
    });
  }

  // ── Articles (Care Guides) ────────────────────────────────
  @override
  Future<List<Article>> getArticles({String? category}) async {
    final qp = <String, String>{};
    if (category != null) qp['category'] = category;
    final data = await _get('/articles', queryParams: qp.isEmpty ? null : qp);
    return (data['articles'] as List)
        .map((a) => Article.fromJson(a))
        .toList();
  }

  @override
  Future<Article> getArticle(String id) async {
    final data = await _get('/articles/$id');
    return Article.fromJson(data['article'] ?? data);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
