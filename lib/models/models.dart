// Patient Model
class Patient {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final List<String>? conditions;
  final List<Medication>? medications;
  final List<String>? allergies;
  final String? dietaryRestrictions;
  final String? mobilityStatus;
  final String? doctorName;
  final String? doctorPhone;
  final String? doctorHospital;
  final List<EmergencyContact>? emergencyContacts;
  final String? address;
  final String? city;
  final DateTime? createdAt;
  // Clinical fields
  final String? height;
  final String? weight;
  final String? diagnosis;
  final String? ivCentralLine;
  final bool? dischargeSummaryAvailable;
  final String? feedingType;
  final String? mentalCondition;
  final String? motionStatus;
  final String? bpSugarInsulin;
  final String? requirement;

  Patient({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.conditions,
    this.medications,
    this.allergies,
    this.dietaryRestrictions,
    this.mobilityStatus,
    this.doctorName,
    this.doctorPhone,
    this.doctorHospital,
    this.emergencyContacts,
    this.address,
    this.city,
    this.createdAt,
    this.height,
    this.weight,
    this.diagnosis,
    this.ivCentralLine,
    this.dischargeSummaryAvailable,
    this.feedingType,
    this.mentalCondition,
    this.motionStatus,
    this.bpSugarInsulin,
    this.requirement,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'],
      conditions: json['conditions'] != null
          ? List<String>.from(json['conditions'])
          : null,
      medications: json['medications'] != null
          ? (json['medications'] as List)
              .map((m) => Medication.fromJson(m))
              .toList()
          : null,
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'])
          : null,
      dietaryRestrictions: json['dietary_restrictions'],
      mobilityStatus: json['mobility_status'],
      doctorName: json['doctor_name'],
      doctorPhone: json['doctor_phone'],
      doctorHospital: json['doctor_hospital'],
      emergencyContacts: json['emergency_contacts'] != null
          ? (json['emergency_contacts'] as List)
              .map((e) => EmergencyContact.fromJson(e))
              .toList()
          : null,
      address: json['address'],
      city: json['city'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      height: json['height'],
      weight: json['weight'],
      diagnosis: json['diagnosis'],
      ivCentralLine: json['iv_central_line'],
      dischargeSummaryAvailable: json['discharge_summary_available'],
      feedingType: json['feeding_type'],
      mentalCondition: json['mental_condition'],
      motionStatus: json['motion_status'],
      bpSugarInsulin: json['bp_sugar_insulin'],
      requirement: json['requirement'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'conditions': conditions,
        'medications': medications?.map((m) => m.toJson()).toList(),
        'allergies': allergies,
        'dietary_restrictions': dietaryRestrictions,
        'mobility_status': mobilityStatus,
        'doctor_name': doctorName,
        'doctor_phone': doctorPhone,
        'doctor_hospital': doctorHospital,
        'emergency_contacts':
            emergencyContacts?.map((e) => e.toJson()).toList(),
        'address': address,
        'city': city,
        'height': height,
        'weight': weight,
        'diagnosis': diagnosis,
        'iv_central_line': ivCentralLine,
        'discharge_summary_available': dischargeSummaryAvailable,
        'feeding_type': feedingType,
        'mental_condition': mentalCondition,
        'motion_status': motionStatus,
        'bp_sugar_insulin': bpSugarInsulin,
        'requirement': requirement,
      };
}

class Medication {
  final String name;
  final String? dosage;
  final String? schedule;

  Medication({required this.name, this.dosage, this.schedule});

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        name: json['name'],
        dosage: json['dosage'],
        schedule: json['schedule'],
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'dosage': dosage, 'schedule': schedule};
}

class EmergencyContact {
  final String name;
  final String phone;
  final String? relation;

  EmergencyContact({required this.name, required this.phone, this.relation});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'],
        phone: json['phone'],
        relation: json['relation'],
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'phone': phone, 'relation': relation};
}

// Family Member Model
class FamilyMember {
  final String id;
  final String userId;
  final String patientId;
  final String name;
  final String phone;
  final String? email;
  final String relationship;
  final String role; // PRIMARY_CONTACT, FAMILY_MEMBER, PATIENT_SELF
  final String preferredLanguage;
  final Map<String, bool>? notificationPreferences;
  final DateTime? createdAt;

  FamilyMember({
    required this.id,
    required this.userId,
    required this.patientId,
    required this.name,
    required this.phone,
    this.email,
    required this.relationship,
    this.role = 'FAMILY_MEMBER',
    this.preferredLanguage = 'en',
    this.notificationPreferences,
    this.createdAt,
  });

  bool get isPrimaryContact => role == 'PRIMARY_CONTACT';
  bool get canMakePayments => role == 'PRIMARY_CONTACT';
  bool get canBookServices =>
      role == 'PRIMARY_CONTACT' || role == 'FAMILY_MEMBER';

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'],
        userId: json['user_id'],
        patientId: json['patient_id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email'],
        relationship: json['relationship'],
        role: json['role'] ?? 'FAMILY_MEMBER',
        preferredLanguage: json['preferred_language'] ?? 'en',
        notificationPreferences: json['notification_preferences'] != null
            ? Map<String, bool>.from(json['notification_preferences'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
      );
}

// Deployment Model
class Deployment {
  final String id;
  final String patientId;
  final String staffId;
  final String? staffName;
  final String? staffPhoto;
  final String? staffRole;
  final double? staffRating;
  final String shiftType; // 12hr_day, 12hr_night, 24hr
  final DateTime startDate;
  final DateTime? endDate;
  final int? totalDays;
  final String status;
  final bool autoRenew;
  final String billingCycle; // monthly, quarterly
  final DateTime? nextBillingDate;

  Deployment({
    required this.id,
    required this.patientId,
    required this.staffId,
    this.staffName,
    this.staffPhoto,
    this.staffRole,
    this.staffRating,
    required this.shiftType,
    required this.startDate,
    this.endDate,
    this.totalDays,
    this.status = 'active',
    this.autoRenew = false,
    this.billingCycle = 'monthly',
    this.nextBillingDate,
  });

  int get daysSinceStart => DateTime.now().difference(startDate).inDays + 1;

  factory Deployment.fromJson(Map<String, dynamic> json) => Deployment(
        id: json['id'],
        patientId: json['patient_id'],
        staffId: json['staff_id'],
        staffName: json['staff_name'],
        staffPhoto: json['staff_photo'],
        staffRole: json['staff_role'],
        staffRating: json['staff_rating']?.toDouble(),
        shiftType: json['shift_type'],
        startDate: DateTime.parse(json['start_date']),
        endDate:
            json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
        totalDays: json['total_days'],
        status: json['status'] ?? 'active',
        autoRenew: json['auto_renew'] ?? false,
        billingCycle: json['billing_cycle'] ?? 'monthly',
        nextBillingDate: json['next_billing_date'] != null
            ? DateTime.parse(json['next_billing_date'])
            : null,
      );
}

// Attendance Model
class Attendance {
  final String id;
  final String deploymentId;
  final String staffId;
  final DateTime date;
  final String status; // checked_in, waiting, late, absent, on_leave, checked_out
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInSelfie;
  final String? replacementName;

  Attendance({
    required this.id,
    required this.deploymentId,
    required this.staffId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.checkInSelfie,
    this.replacementName,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
        id: json['id'],
        deploymentId: json['deployment_id'],
        staffId: json['staff_id'],
        date: DateTime.parse(json['date']),
        status: json['status'],
        checkInTime: json['check_in_time'] != null
            ? DateTime.parse(json['check_in_time'])
            : null,
        checkOutTime: json['check_out_time'] != null
            ? DateTime.parse(json['check_out_time'])
            : null,
        checkInSelfie: json['check_in_selfie'],
        replacementName: json['replacement_name'],
      );
}

// Vitals Model
class VitalReading {
  final String id;
  final String patientId;
  final String? staffId;
  final String? staffName;
  final DateTime recordedAt;
  final double? systolic;
  final double? diastolic;
  final double? pulse;
  final double? spo2;
  final double? temperature;
  final double? sugar;
  final String? sugarType; // fasting, post_meal, random
  final String? notes;

  VitalReading({
    required this.id,
    required this.patientId,
    this.staffId,
    this.staffName,
    required this.recordedAt,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.spo2,
    this.temperature,
    this.sugar,
    this.sugarType,
    this.notes,
  });

  factory VitalReading.fromJson(Map<String, dynamic> json) => VitalReading(
        id: json['id'],
        patientId: json['patient_id'],
        staffId: json['staff_id'],
        staffName: json['staff_name'],
        recordedAt: DateTime.parse(json['recorded_at']),
        systolic: json['systolic']?.toDouble(),
        diastolic: json['diastolic']?.toDouble(),
        pulse: json['pulse']?.toDouble(),
        spo2: json['spo2']?.toDouble(),
        temperature: json['temperature']?.toDouble(),
        sugar: json['sugar']?.toDouble(),
        sugarType: json['sugar_type'],
        notes: json['notes'],
      );
}

// Daily Report Model
class DailyReport {
  final String id;
  final String deploymentId;
  final String staffId;
  final String? staffName;
  final DateTime date;
  final DateTime? submittedAt;
  final List<ReportSection> sections;
  final String? staffNotes;
  final List<String>? photoUrls;
  final List<MedicationEntry>? medications;
  final int completedTasks;
  final int totalTasks;

  DailyReport({
    required this.id,
    required this.deploymentId,
    required this.staffId,
    this.staffName,
    required this.date,
    this.submittedAt,
    required this.sections,
    this.staffNotes,
    this.photoUrls,
    this.medications,
    required this.completedTasks,
    required this.totalTasks,
  });

  double get completionPercent =>
      totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

  factory DailyReport.fromJson(Map<String, dynamic> json) => DailyReport(
        id: json['id'],
        deploymentId: json['deployment_id'],
        staffId: json['staff_id'],
        staffName: json['staff_name'],
        date: DateTime.parse(json['date']),
        submittedAt: json['submitted_at'] != null
            ? DateTime.parse(json['submitted_at'])
            : null,
        sections: (json['sections'] as List)
            .map((s) => ReportSection.fromJson(s))
            .toList(),
        staffNotes: json['staff_notes'],
        photoUrls: json['photo_urls'] != null
            ? List<String>.from(json['photo_urls'])
            : null,
        medications: json['medications'] != null
            ? (json['medications'] as List)
                .map((m) => MedicationEntry.fromJson(m))
                .toList()
            : null,
        completedTasks: json['completed_tasks'] ?? 0,
        totalTasks: json['total_tasks'] ?? 0,
      );
}

class ReportSection {
  final String name;
  final String status; // done, partial, pending
  final List<ReportTask> tasks;

  ReportSection({
    required this.name,
    required this.status,
    required this.tasks,
  });

  factory ReportSection.fromJson(Map<String, dynamic> json) => ReportSection(
        name: json['name'],
        status: json['status'],
        tasks: (json['tasks'] as List)
            .map((t) => ReportTask.fromJson(t))
            .toList(),
      );
}

class ReportTask {
  final String name;
  final bool completed;
  final String? completedAt;
  final String? notes;
  final bool skipped;

  ReportTask({
    required this.name,
    required this.completed,
    this.completedAt,
    this.notes,
    this.skipped = false,
  });

  factory ReportTask.fromJson(Map<String, dynamic> json) => ReportTask(
        name: json['name'],
        completed: json['completed'] ?? false,
        completedAt: json['completed_at'],
        notes: json['notes'],
        skipped: json['skipped'] ?? false,
      );
}

// Medication Adherence Model
class MedicationEntry {
  final String id;
  final String name;
  final String dosage;
  final String timing; // morning, afternoon, evening, night
  final bool taken;
  final String? takenAt;
  final String? takenBy; // 'staff' or 'patient'
  final String? notes;

  MedicationEntry({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timing,
    this.taken = false,
    this.takenAt,
    this.takenBy,
    this.notes,
  });

  factory MedicationEntry.fromJson(Map<String, dynamic> json) =>
      MedicationEntry(
        id: json['id'],
        name: json['name'],
        dosage: json['dosage'],
        timing: json['timing'],
        taken: json['taken'] ?? false,
        takenAt: json['taken_at'],
        takenBy: json['taken_by'],
        notes: json['notes'],
      );
}

// Service Catalog Model
class ServiceItem {
  final String id;
  final String name;
  final String? nameHi;
  final String category;
  final String bookingType; // instant, assessment
  final String? description;
  final String? descriptionHi;
  final int? basePriceMin;
  final int? basePriceMax;
  final int? durationMinutes;
  final String? preparationNotes;
  final String? preparationNotesHi;
  final int leadTimeHours;
  final bool isActive;
  final String? iconName;

  ServiceItem({
    required this.id,
    required this.name,
    this.nameHi,
    required this.category,
    required this.bookingType,
    this.description,
    this.descriptionHi,
    this.basePriceMin,
    this.basePriceMax,
    this.durationMinutes,
    this.preparationNotes,
    this.preparationNotesHi,
    this.leadTimeHours = 24,
    this.isActive = true,
    this.iconName,
  });

  bool get isInstant => bookingType != 'assessment';

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: json['id'],
        name: json['name'],
        nameHi: json['name_hi'],
        category: json['category'],
        bookingType: json['booking_type'],
        description: json['description'],
        descriptionHi: json['description_hi'],
        basePriceMin: json['base_price_min'],
        basePriceMax: json['base_price_max'],
        durationMinutes: json['duration_minutes'],
        preparationNotes: json['preparation_notes'],
        preparationNotesHi: json['preparation_notes_hi'],
        leadTimeHours: json['lead_time_hours'] ?? 24,
        isActive: json['is_active'] ?? true,
        iconName: json['icon_name'],
      );
}

// Booking Model
class Booking {
  final String id;
  final String bookingNumber;
  final String patientId;
  final String? bookedBy;
  final String serviceId;
  final String? serviceName;
  final String bookingType;
  final String status;
  final DateTime scheduledDate;
  final String? scheduledSlot;
  final String? assignedStaffName;
  final String? assignedStaffPhoto;
  final String? address;
  final int priceAmount;
  final int gstAmount;
  final int totalAmount;
  final String? promoCode;
  final int discountAmount;
  final String paymentStatus;
  final String? cancellationReason;
  final int? rating;
  final String? ratingComment;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.bookingNumber,
    required this.patientId,
    this.bookedBy,
    required this.serviceId,
    this.serviceName,
    required this.bookingType,
    this.status = 'pending',
    required this.scheduledDate,
    this.scheduledSlot,
    this.assignedStaffName,
    this.assignedStaffPhoto,
    this.address,
    required this.priceAmount,
    required this.gstAmount,
    required this.totalAmount,
    this.promoCode,
    this.discountAmount = 0,
    this.paymentStatus = 'pending',
    this.cancellationReason,
    this.rating,
    this.ratingComment,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'],
        bookingNumber: json['booking_number'],
        patientId: json['patient_id'],
        bookedBy: json['booked_by'],
        serviceId: json['service_id'],
        serviceName: json['service_name'],
        bookingType: json['booking_type'],
        status: json['status'] ?? 'pending',
        scheduledDate: DateTime.parse(json['scheduled_date']),
        scheduledSlot: json['scheduled_slot'],
        assignedStaffName: json['assigned_staff_name'],
        assignedStaffPhoto: json['assigned_staff_photo'],
        address: json['address'],
        priceAmount: json['price_amount'],
        gstAmount: json['gst_amount'],
        totalAmount: json['total_amount'],
        promoCode: json['promo_code'],
        discountAmount: json['discount_amount'] ?? 0,
        paymentStatus: json['payment_status'] ?? 'pending',
        cancellationReason: json['cancellation_reason'],
        rating: json['rating'],
        ratingComment: json['rating_comment'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

// Assessment Request Model
class AssessmentRequest {
  final String id;
  final String requestNumber;
  final String patientId;
  final String? requestedBy;
  final String serviceCategory;
  final String status;
  final Map<String, dynamic> questionnaireResponses;
  final String? assignedCoordinator;
  final DateTime? callbackScheduledAt;
  final Map<String, dynamic>? quote;
  final DateTime? quoteSentAt;
  final DateTime? quoteExpiresAt;
  final String? selectedPlan;
  final DateTime createdAt;

  AssessmentRequest({
    required this.id,
    required this.requestNumber,
    required this.patientId,
    this.requestedBy,
    required this.serviceCategory,
    this.status = 'submitted',
    required this.questionnaireResponses,
    this.assignedCoordinator,
    this.callbackScheduledAt,
    this.quote,
    this.quoteSentAt,
    this.quoteExpiresAt,
    this.selectedPlan,
    required this.createdAt,
  });

  factory AssessmentRequest.fromJson(Map<String, dynamic> json) =>
      AssessmentRequest(
        id: json['id'],
        requestNumber: json['request_number'],
        patientId: json['patient_id'],
        requestedBy: json['requested_by'],
        serviceCategory: json['service_category'],
        status: json['status'] ?? 'submitted',
        questionnaireResponses: json['questionnaire_responses'] ?? {},
        assignedCoordinator: json['assigned_coordinator'],
        callbackScheduledAt: json['callback_scheduled_at'] != null
            ? DateTime.parse(json['callback_scheduled_at'])
            : null,
        quote: json['quote'],
        quoteSentAt: json['quote_sent_at'] != null
            ? DateTime.parse(json['quote_sent_at'])
            : null,
        quoteExpiresAt: json['quote_expires_at'] != null
            ? DateTime.parse(json['quote_expires_at'])
            : null,
        selectedPlan: json['selected_plan'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

// Invoice Model
class Invoice {
  final String id;
  final String invoiceNumber;
  final String patientId;
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final List<InvoiceLineItem> lineItems;
  final int subtotal;
  final int gstTotal;
  final int grandTotal;
  final DateTime dueDate;
  final String status;
  final String? pdfUrl;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.patientId,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.lineItems,
    required this.subtotal,
    required this.gstTotal,
    required this.grandTotal,
    required this.dueDate,
    this.status = 'pending',
    this.pdfUrl,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'],
        invoiceNumber: json['invoice_number'],
        patientId: json['patient_id'],
        billingPeriodStart: DateTime.parse(json['billing_period_start']),
        billingPeriodEnd: DateTime.parse(json['billing_period_end']),
        lineItems: (json['line_items'] as List)
            .map((l) => InvoiceLineItem.fromJson(l))
            .toList(),
        subtotal: json['subtotal'],
        gstTotal: json['gst_total'],
        grandTotal: json['grand_total'],
        dueDate: DateTime.parse(json['due_date']),
        status: json['status'] ?? 'pending',
        pdfUrl: json['pdf_url'],
      );
}

class InvoiceLineItem {
  final String description;
  final int amount;
  final int gst;
  final int total;
  final String? type;

  InvoiceLineItem({
    required this.description,
    required this.amount,
    required this.gst,
    required this.total,
    this.type,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      InvoiceLineItem(
        description: json['description'],
        amount: json['amount'],
        gst: json['gst'],
        total: json['total'],
        type: json['type'],
      );
}

// Family Concern Model
class FamilyConcern {
  final String id;
  final String patientId;
  final String? raisedBy;
  final String category;
  final String description;
  final List<String>? evidenceUrls;
  final String urgency;
  final String? preferredResolution;
  final String status;
  final String? assignedTo;
  final String? resolutionNotes;
  final int? resolutionSatisfaction;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  FamilyConcern({
    required this.id,
    required this.patientId,
    this.raisedBy,
    required this.category,
    required this.description,
    this.evidenceUrls,
    required this.urgency,
    this.preferredResolution,
    this.status = 'received',
    this.assignedTo,
    this.resolutionNotes,
    this.resolutionSatisfaction,
    required this.createdAt,
    this.resolvedAt,
  });

  factory FamilyConcern.fromJson(Map<String, dynamic> json) => FamilyConcern(
        id: json['id'],
        patientId: json['patient_id'],
        raisedBy: json['raised_by'],
        category: json['category'],
        description: json['description'],
        evidenceUrls: json['evidence_urls'] != null
            ? List<String>.from(json['evidence_urls'])
            : null,
        urgency: json['urgency'],
        preferredResolution: json['preferred_resolution'],
        status: json['status'] ?? 'received',
        assignedTo: json['assigned_to'],
        resolutionNotes: json['resolution_notes'],
        resolutionSatisfaction: json['resolution_satisfaction'],
        createdAt: DateTime.parse(json['created_at']),
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'])
            : null,
      );
}

// Notification Model
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String channel;
  final String status;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.channel,
    this.status = 'sent',
    required this.createdAt,
  });

  bool get isRead => status == 'read';

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        type: json['type'],
        title: json['title'],
        body: json['body'],
        data: json['data'],
        channel: json['channel'],
        status: json['status'] ?? 'sent',
        createdAt: DateTime.parse(json['created_at']),
      );
}

// Staff Profile (limited view for families)
class StaffProfile {
  final String id;
  final String name;
  final String? photoUrl;
  final String role;
  final double? rating;
  final int? totalReviews;
  final bool idVerified;
  final bool trainingComplete;
  final bool policeVerified;
  final List<String>? languages;
  final String? experience;
  final DateTime? assignedSince;
  final List<StaffDocument>? documents;
  final List<StaffReview>? reviews;

  StaffProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.role,
    this.rating,
    this.totalReviews,
    this.idVerified = false,
    this.trainingComplete = false,
    this.policeVerified = false,
    this.languages,
    this.experience,
    this.assignedSince,
    this.documents,
    this.reviews,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) => StaffProfile(
        id: json['id'],
        name: json['name'],
        photoUrl: json['photo_url'],
        role: json['role'],
        rating: json['rating']?.toDouble(),
        totalReviews: json['total_reviews'],
        idVerified: json['id_verified'] ?? false,
        trainingComplete: json['training_complete'] ?? false,
        policeVerified: json['police_verified'] ?? false,
        languages: json['languages'] != null
            ? List<String>.from(json['languages'])
            : null,
        experience: json['experience'],
        assignedSince: json['assigned_since'] != null
            ? DateTime.parse(json['assigned_since'])
            : null,
        documents: json['documents'] != null
            ? (json['documents'] as List)
                .map((d) => StaffDocument.fromJson(d))
                .toList()
            : null,
        reviews: json['reviews'] != null
            ? (json['reviews'] as List)
                .map((r) => StaffReview.fromJson(r))
                .toList()
            : null,
      );
}

class StaffDocument {
  final String type; // aadhaar, police_verification, training_certificate, medical_certificate
  final String label;
  final String status; // verified, pending, expired
  final DateTime? verifiedAt;
  final String? documentUrl;

  StaffDocument({
    required this.type,
    required this.label,
    required this.status,
    this.verifiedAt,
    this.documentUrl,
  });

  factory StaffDocument.fromJson(Map<String, dynamic> json) => StaffDocument(
        type: json['type'],
        label: json['label'],
        status: json['status'] ?? 'pending',
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'])
            : null,
        documentUrl: json['document_url'],
      );
}

class StaffReview {
  final String id;
  final String patientName;
  final double rating;
  final String? comment;
  final DateTime date;

  StaffReview({
    required this.id,
    required this.patientName,
    required this.rating,
    this.comment,
    required this.date,
  });

  factory StaffReview.fromJson(Map<String, dynamic> json) => StaffReview(
        id: json['id'],
        patientName: json['patient_name'],
        rating: json['rating']?.toDouble() ?? 0,
        comment: json['comment'],
        date: DateTime.parse(json['date']),
      );
}

// Equipment / Consumable Item — backend-driven catalog
class EquipmentItem {
  final String id;
  final String name;
  final String brand;
  final String category; // Equipment, Consumable
  final bool availableForSale;
  final bool availableForRent;
  final double? price;
  final double? rentalPrice; // Monthly rental price
  final String status; // Active, Inactive
  final String? imageUrl;
  final String? description;
  final String? howToUse;
  final String? keyFeatures;
  final String? idealFor;
  final String? youtubeUrl;
  final String? faqs;
  final String? parentProductId;
  final String? variantType;
  final String? variantValue;

  EquipmentItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    this.availableForSale = true,
    this.availableForRent = false,
    this.price,
    this.rentalPrice,
    this.status = 'Active',
    this.imageUrl,
    this.description,
    this.howToUse,
    this.keyFeatures,
    this.idealFor,
    this.youtubeUrl,
    this.faqs,
    this.parentProductId,
    this.variantType,
    this.variantValue,
  });

  /// Legacy getter — derives type from availability flags.
  String get type => availableForRent ? 'Rental' : 'Sale';

  /// Days of rental after which buying becomes cheaper
  int? get breakevenDays {
    if (price == null || rentalPrice == null || rentalPrice! <= 0) return null;
    return (price! / rentalPrice!).ceil();
  }

  /// Equipment that requires a complementary clinical assessment before ordering.
  /// Ventilators, BiPAP, and CPAP machines need pressure settings, mask fitting, etc.
  bool get needsAssessment {
    final n = name.toLowerCase();
    return n.contains('ventilator') ||
        n.contains('bipap') ||
        n.contains('bi-pap') ||
        n.contains('cpap') ||
        n.contains('c-pap');
  }

  bool get isVariant => parentProductId != null;

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        brand: json['brand'] ?? 'Generic',
        category: json['category'] ?? 'Equipment',
        availableForSale: json['available_for_sale'] ?? true,
        availableForRent: json['available_for_rent'] ?? false,
        price: json['price']?.toDouble(),
        rentalPrice: json['rental_price']?.toDouble(),
        status: json['status'] ?? 'Active',
        imageUrl: json['image_url'],
        description: json['description'],
        howToUse: json['how_to_use'],
        keyFeatures: json['key_features'],
        idealFor: json['ideal_for'],
        youtubeUrl: json['youtube_url'],
        faqs: json['faqs'],
        parentProductId: json['parent_product_id'],
        variantType: json['variant_type'],
        variantValue: json['variant_value'],
      );
}

// Staff Attendance Model
class StaffAttendance {
  final DateTime date;
  final String status; // present, absent, half_day, leave
  final String? checkIn;
  final String? checkOut;
  final double? hoursWorked;

  StaffAttendance({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.hoursWorked,
  });

  factory StaffAttendance.fromJson(Map<String, dynamic> json) =>
      StaffAttendance(
        date: DateTime.parse(json['date']),
        status: json['status'] ?? 'present',
        checkIn: json['check_in'],
        checkOut: json['check_out'],
        hoursWorked: json['hours_worked']?.toDouble(),
      );
}

// Payment Transaction Model
class PaymentTransaction {
  final String id;
  final String patientId;
  final String? invoiceId;
  final String? bookingId;
  final int amount;
  final String currency;
  final String method; // upi, card, netbanking, wallet, emi
  final String status; // initiated, processing, completed, failed, refunded
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? razorpaySignature;
  final String? failureReason;
  final int? refundAmount;
  final String? refundId;
  final String? receiptUrl;
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;

  PaymentTransaction({
    required this.id,
    required this.patientId,
    this.invoiceId,
    this.bookingId,
    required this.amount,
    this.currency = 'INR',
    required this.method,
    required this.status,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpaySignature,
    this.failureReason,
    this.refundAmount,
    this.refundId,
    this.receiptUrl,
    required this.description,
    required this.createdAt,
    this.completedAt,
  });

  bool get isSuccess => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded';

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      PaymentTransaction(
        id: json['id'],
        patientId: json['patient_id'],
        invoiceId: json['invoice_id'],
        bookingId: json['booking_id'],
        amount: json['amount'],
        currency: json['currency'] ?? 'INR',
        method: json['method'],
        status: json['status'],
        razorpayPaymentId: json['razorpay_payment_id'],
        razorpayOrderId: json['razorpay_order_id'],
        razorpaySignature: json['razorpay_signature'],
        failureReason: json['failure_reason'],
        refundAmount: json['refund_amount'],
        refundId: json['refund_id'],
        receiptUrl: json['receipt_url'],
        description: json['description'],
        createdAt: DateTime.parse(json['created_at']),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
      );
}

// Coupon Model
class Coupon {
  final String id;
  final String code;
  final String type; // percentage, flat
  final int value; // percentage value or flat amount in paise
  final int? maxDiscount; // max discount cap for percentage coupons
  final int? minOrderValue;
  final String? description;
  final List<String>? applicableCategories; // service categories
  final DateTime validFrom;
  final DateTime validUntil;
  final int? usageLimit;
  final int usedCount;
  final bool isActive;

  Coupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minOrderValue,
    this.description,
    this.applicableCategories,
    required this.validFrom,
    required this.validUntil,
    this.usageLimit,
    this.usedCount = 0,
    this.isActive = true,
  });

  bool get isValid =>
      isActive &&
      DateTime.now().isAfter(validFrom) &&
      DateTime.now().isBefore(validUntil) &&
      (usageLimit == null || usedCount < usageLimit!);

  int calculateDiscount(int orderAmount) {
    if (!isValid) return 0;
    if (minOrderValue != null && orderAmount < minOrderValue!) return 0;

    int discount;
    if (type == 'percentage') {
      discount = (orderAmount * value / 100).round();
      if (maxDiscount != null && discount > maxDiscount!) {
        discount = maxDiscount!;
      }
    } else {
      discount = value;
    }
    return discount > orderAmount ? orderAmount : discount;
  }

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'],
        code: json['code'],
        type: json['type'],
        value: json['value'],
        maxDiscount: json['max_discount'],
        minOrderValue: json['min_order_value'],
        description: json['description'],
        applicableCategories: json['applicable_categories'] != null
            ? List<String>.from(json['applicable_categories'])
            : null,
        validFrom: DateTime.parse(json['valid_from']),
        validUntil: DateTime.parse(json['valid_until']),
        usageLimit: json['usage_limit'],
        usedCount: json['used_count'] ?? 0,
        isActive: json['is_active'] ?? true,
      );
}

// Billing Summary Model
class BillingSummary {
  final int totalDue;
  final int totalPaid;
  final int overdueAmount;
  final DateTime? nextDueDate;
  final int invoiceCount;
  final int overdueCount;

  BillingSummary({
    required this.totalDue,
    required this.totalPaid,
    required this.overdueAmount,
    this.nextDueDate,
    required this.invoiceCount,
    required this.overdueCount,
  });

  factory BillingSummary.fromJson(Map<String, dynamic> json) => BillingSummary(
        totalDue: json['total_due'] ?? 0,
        totalPaid: json['total_paid'] ?? 0,
        overdueAmount: json['overdue_amount'] ?? 0,
        nextDueDate: json['next_due_date'] != null
            ? DateTime.parse(json['next_due_date'])
            : null,
        invoiceCount: json['invoice_count'] ?? 0,
        overdueCount: json['overdue_count'] ?? 0,
      );
}

// Cart Item Model — wraps an EquipmentItem with quantity and purchase mode
class CartItem {
  final EquipmentItem item;
  final bool isRental; // true = rent, false = buy
  int quantity;
  int rentalMonths; // only relevant when isRental == true (min 1 month)

  CartItem({
    required this.item,
    this.isRental = false,
    this.quantity = 1,
    this.rentalMonths = 1,
  });

  /// Unique key combining item id + mode so same item can be in cart as both rental and purchase
  String get cartKey => '${item.id}_${isRental ? "rent" : "buy"}';

  double get unitPrice =>
      isRental ? (item.rentalPrice ?? 0) : (item.price ?? 0);

  /// rentalPrice is monthly rate — lineTotal = monthly × months × qty
  double get lineTotal =>
      isRental ? unitPrice * quantity * rentalMonths : unitPrice * quantity;
}

// Care Package Model — condition-based bundles of equipment + services
class PackageItem {
  final String equipmentId; // references EquipmentItem.id
  final String name;
  final bool isRental; // true = rent, false = buy
  final int quantity;
  final int rentalMonths; // rental duration in months (min 15 days = 1 month)

  const PackageItem({
    required this.equipmentId,
    required this.name,
    this.isRental = false,
    this.quantity = 1,
    this.rentalMonths = 1,
  });
}

class PackageService {
  final String name;
  final String type; // nurse, physiotherapist, caretaker, etc.
  final String shift; // 12hr_day, 12hr_night, 24hr
  final int durationDays;
  final int pricePerDay;

  const PackageService({
    required this.name,
    required this.type,
    required this.shift,
    required this.durationDays,
    required this.pricePerDay,
  });

  int get totalPrice => pricePerDay * durationDays;
}

class CarePackage {
  final String id;
  final String name;
  final String condition; // TKR, Sleep Apnea, Baby Care, etc.
  final String description;
  final String icon; // icon name key
  final List<PackageItem> items;
  final List<PackageService> services;
  final double discountPercent; // e.g. 10 = 10% off
  final String? imageUrl;
  final List<String> highlights; // key selling points
  final int? pricePerDay; // for daily rate packages (Critical, Advance, Basic)
  final int? minDays; // minimum billing period

  /// Whether this is a per-day bundled package (vs condition-based equipment kit)
  bool get isDailyPackage => pricePerDay != null;

  const CarePackage({
    required this.id,
    required this.name,
    required this.condition,
    required this.description,
    required this.icon,
    required this.items,
    required this.services,
    this.discountPercent = 10,
    this.imageUrl,
    this.highlights = const [],
    this.pricePerDay,
    this.minDays,
  });
}
