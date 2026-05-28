import '../models/models.dart';
import '../models/my_care_models.dart';
import '../models/medication_models.dart';
import '../models/equipment_order.dart';

/// Abstract interface for the API service layer.
/// All consumers should depend on this interface rather than the
/// concrete [ApiService] class, enabling testability and
/// adherence to Dependency Inversion (SOLID).
abstract class IApiService {
  void setAuthToken(String token);

  /// Generic GET (used by services that build their own API paths).
  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? queryParams});

  // ── Auth ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp);
  Future<Map<String, dynamic>> completeOnboarding({
    required String name,
    required String relationship,
    required String preferredLanguage,
  });
  Future<void> updateFcmToken(String token);

  // ── Patients ──────────────────────────────────────────────
  Future<List<Patient>> getPatients();
  Future<Patient> getPatient(String patientId);
  Future<Patient> updatePatient(
      String patientId, Map<String, dynamic> updates);

  // ── Dashboard ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard(String patientId);
  Future<Map<String, dynamic>> syncDashboardData(
      String patientId, DateTime? lastSyncAt);

  // ── Attendance ────────────────────────────────────────────
  Future<Attendance?> getTodayAttendance(String patientId);
  Future<List<Attendance>> getAttendanceHistory(String patientId, {int page});

  // ── Vitals ────────────────────────────────────────────────
  Future<VitalReading?> getLatestVitals(String patientId);
  Future<List<VitalReading>> getVitalsHistory(String patientId,
      {String period});

  // ── Reports ───────────────────────────────────────────────
  Future<DailyReport?> getTodayReport(String patientId);
  Future<List<DailyReport>> getReportHistory(String patientId, {int page});
  // audit batch 4 (Agent J): paginated report fetch (used by report history screen).
  Future<List<DailyReport>> getReportHistoryPaginated(
    String patientId, {
    int page,
    int pageSize,
  });
  Future<DailyReport> getReportDetail(String reportId);

  // audit batch 4 (Agent J): paginated attendance fetch (used by attendance
  // history screen) — keyed by deploymentId, not patientId.
  Future<List<Attendance>> getAttendanceHistoryPaginated(
    String deploymentId, {
    int page,
    int pageSize,
  });

  // ── Deployments ───────────────────────────────────────────
  Future<Deployment?> getActiveDeployment(String patientId);

  // ── Staff ─────────────────────────────────────────────────
  Future<StaffProfile> getStaffProfile(String staffId);

  // ── Services ──────────────────────────────────────────────
  Future<List<ServiceItem>> getServiceCatalog();
  Future<ServiceItem> getServiceDetail(String serviceId);
  Future<List<Map<String, dynamic>>> getAvailableSlots(
      String serviceId, DateTime date);

  // ── Bookings ──────────────────────────────────────────────
  Future<Booking> createBooking({
    required String patientId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledSlot,
    String? promoCode,
  });
  Future<List<Booking>> getBookings(String patientId, {int page});
  Future<void> cancelBooking(String bookingId, String reason);

  // ── Billing ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getBillingSummary(String patientId);
  Future<List<Invoice>> getInvoices(String patientId);
  Future<Invoice> getInvoiceDetail(String invoiceId);

  // ── Payments ──────────────────────────────────────────────
  Future<Map<String, dynamic>> createPaymentOrder({
    required String patientId,
    required int amount,
    required String paymentType,
    String? referenceType,
    String? referenceId,
  });
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  });

  // ── Concerns ──────────────────────────────────────────────
  Future<FamilyConcern> raiseConcern({
    required String patientId,
    required String category,
    required String description,
    required String urgency,
    String? preferredResolution,
    List<String>? evidenceUrls,
  });
  Future<List<FamilyConcern>> getConcerns(String patientId);

  // ── Notifications ─────────────────────────────────────────
  Future<List<AppNotification>> getNotifications({int page});
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();

  // ── Family Members ────────────────────────────────────────
  Future<List<FamilyMember>> getFamilyMembers(String patientId);
  Future<void> inviteFamilyMember(String patientId, String phone);
  Future<void> removeFamilyMember(String patientId, String memberId);

  // ── Medications ───────────────────────────────────────────
  Future<List<MedicationFull>> getMedications(String patientId);
  Future<MedicationFull> addMedication(
      String patientId, Map<String, dynamic> body);
  Future<MedicationFull> updateMedication(
      String patientId, String medicationId, Map<String, dynamic> body);
  Future<void> deleteMedication(String patientId, String medicationId);
  // audit batch 4 (Agent J): logs + stock — used by MedicationProvider.
  Future<List<MedicationLog>> getMedicationLogs(
    String patientId, {
    String? date,
  });
  Future<void> updateMedicationStock(
      String patientId, String medicationId, int stockCount);

  // ── My Care ──────────────────────────────────────────────
  // audit batch 4 (Agent J): MyCareProvider depends on these methods.
  Future<List<ActiveService>> getActiveServices(String patientId);
  Future<HealthManager?> getHealthManager(String patientId);
  Future<ServiceDetail> getDeploymentServiceDetail(String deploymentId);

  // ── Equipment ─────────────────────────────────────────────
  Future<List<EquipmentItem>> getEquipmentCatalog({
    String? category,
    String? type,
    String? search,
  });
  Future<List<EquipmentOrder>> getEquipmentOrders(String patientId);
}
