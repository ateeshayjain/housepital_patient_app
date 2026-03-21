-- =====================================================
-- Housepital Patient App — MySQL Database Schema
-- Version 1.0 | March 2026
-- =====================================================

CREATE DATABASE IF NOT EXISTS housepital;
USE housepital;

-- -------------------------------------------------
-- SHARED TABLES (also used by Staff App)
-- -------------------------------------------------

CREATE TABLE patients (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name VARCHAR(255) NOT NULL,
  age INT,
  gender ENUM('male', 'female', 'other'),
  conditions JSON COMMENT 'Array of condition strings',
  medications JSON COMMENT 'Array of {name, dosage, schedule}',
  allergies JSON COMMENT 'Array of allergy strings',
  dietary_restrictions TEXT,
  mobility_status ENUM('ambulatory', 'needs_support', 'wheelchair', 'bedridden'),
  doctor_name VARCHAR(255),
  doctor_phone VARCHAR(20),
  doctor_hospital VARCHAR(255),
  emergency_contacts JSON COMMENT 'Array of {name, phone, relation}',
  address TEXT,
  address_lat DECIMAL(10, 8),
  address_lng DECIMAL(11, 8),
  city ENUM('faridabad', 'delhi', 'noida', 'ghaziabad', 'gurgaon'),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE staff (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20) NOT NULL UNIQUE,
  photo_url VARCHAR(500),
  role VARCHAR(50) NOT NULL COMMENT 'basic_caretaker, trained_caretaker, gnm_nurse, bsc_nurse, icu_nurse, physio, etc.',
  rating DECIMAL(3,2) DEFAULT 0.00,
  id_verified BOOLEAN DEFAULT FALSE,
  training_complete BOOLEAN DEFAULT FALSE,
  languages JSON COMMENT 'Array of language strings',
  experience VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE deployments (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  patient_id CHAR(36) NOT NULL,
  staff_id CHAR(36) NOT NULL,
  shift_type ENUM('12hr_day', '12hr_night', '24hr') NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  total_days INT,
  status ENUM('active', 'completed', 'cancelled', 'on_hold') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (staff_id) REFERENCES staff(id),
  INDEX idx_deployments_patient (patient_id),
  INDEX idx_deployments_staff (staff_id),
  INDEX idx_deployments_status (status)
);

CREATE TABLE attendance (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  deployment_id CHAR(36) NOT NULL,
  staff_id CHAR(36) NOT NULL,
  date DATE NOT NULL,
  status ENUM('checked_in', 'waiting', 'late', 'absent', 'on_leave', 'checked_out') DEFAULT 'waiting',
  check_in_time DATETIME,
  check_out_time DATETIME,
  check_in_selfie VARCHAR(500),
  check_in_lat DECIMAL(10, 8),
  check_in_lng DECIMAL(11, 8),
  replacement_name VARCHAR(255),
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (deployment_id) REFERENCES deployments(id),
  FOREIGN KEY (staff_id) REFERENCES staff(id),
  UNIQUE KEY uk_attendance_deployment_date (deployment_id, date),
  INDEX idx_attendance_date (date),
  INDEX idx_attendance_status (status)
);

CREATE TABLE vitals (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  patient_id CHAR(36) NOT NULL,
  deployment_id CHAR(36),
  staff_id CHAR(36),
  recorded_at DATETIME NOT NULL,
  systolic DECIMAL(5,1),
  diastolic DECIMAL(5,1),
  pulse DECIMAL(5,1),
  spo2 DECIMAL(5,1),
  temperature DECIMAL(4,1),
  sugar DECIMAL(5,1),
  sugar_type ENUM('fasting', 'post_meal', 'random'),
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  INDEX idx_vitals_patient (patient_id),
  INDEX idx_vitals_recorded (recorded_at)
);

CREATE TABLE daily_reports (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  deployment_id CHAR(36) NOT NULL,
  staff_id CHAR(36) NOT NULL,
  date DATE NOT NULL,
  submitted_at DATETIME,
  sections JSON NOT NULL COMMENT 'Array of {name, status, tasks: [{name, completed, completed_at, notes, skipped}]}',
  staff_notes TEXT,
  photo_urls JSON COMMENT 'Array of photo URL strings',
  completed_tasks INT DEFAULT 0,
  total_tasks INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (deployment_id) REFERENCES deployments(id),
  UNIQUE KEY uk_report_deployment_date (deployment_id, date),
  INDEX idx_reports_date (date)
);

-- -------------------------------------------------
-- PATIENT APP SPECIFIC TABLES
-- -------------------------------------------------

CREATE TABLE family_members (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  firebase_uid VARCHAR(128) NOT NULL UNIQUE COMMENT 'Firebase Auth UID',
  patient_id CHAR(36) NOT NULL,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  relationship ENUM('spouse', 'son', 'daughter', 'son_in_law', 'daughter_in_law', 'sibling', 'other') NOT NULL,
  role ENUM('PRIMARY_CONTACT', 'FAMILY_MEMBER', 'PATIENT_SELF') DEFAULT 'FAMILY_MEMBER',
  preferred_language ENUM('en', 'hi') DEFAULT 'en',
  notification_preferences JSON DEFAULT (JSON_OBJECT()),
  fcm_token VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  INDEX idx_family_patient (patient_id),
  INDEX idx_family_firebase (firebase_uid),
  INDEX idx_family_phone (phone)
);

CREATE TABLE service_catalog (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name VARCHAR(255) NOT NULL,
  name_hi VARCHAR(255),
  category ENUM('nursing_visit', 'physio_visit', 'sleep_therapy', 'lab_test', 'caretaker', 'nursing_deployment', 'icu_setup', 'japa', 'nanny', 'equipment', 'consumable') NOT NULL,
  booking_type ENUM('instant', 'assessment') NOT NULL,
  description TEXT,
  description_hi TEXT,
  base_price_min INT COMMENT 'Amount in paise',
  base_price_max INT COMMENT 'Amount in paise',
  duration_minutes INT,
  preparation_notes TEXT,
  preparation_notes_hi TEXT,
  lead_time_hours INT DEFAULT 24,
  is_active BOOLEAN DEFAULT TRUE,
  display_order INT DEFAULT 0,
  icon_name VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bookings (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  booking_number VARCHAR(30) NOT NULL UNIQUE,
  patient_id CHAR(36) NOT NULL,
  booked_by CHAR(36) NOT NULL,
  service_id CHAR(36) NOT NULL,
  booking_type ENUM('instant', 'assessment') NOT NULL,
  status ENUM('pending', 'confirmed', 'assigned', 'in_progress', 'completed', 'cancelled', 'no_show') DEFAULT 'pending',
  scheduled_date DATE NOT NULL,
  scheduled_slot VARCHAR(20) COMMENT 'morning, afternoon, evening or specific time',
  assigned_staff_id CHAR(36),
  address TEXT,
  price_amount INT NOT NULL COMMENT 'Amount in paise',
  gst_amount INT NOT NULL COMMENT 'Amount in paise',
  total_amount INT NOT NULL COMMENT 'Amount in paise',
  promo_code VARCHAR(50),
  discount_amount INT DEFAULT 0,
  payment_status ENUM('pending', 'paid', 'refunded', 'partial_refund') DEFAULT 'pending',
  payment_id VARCHAR(100) COMMENT 'Razorpay payment ID',
  cancellation_reason TEXT,
  cancelled_at DATETIME,
  completed_at DATETIME,
  notes TEXT,
  rating TINYINT CHECK (rating >= 1 AND rating <= 5),
  rating_comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (booked_by) REFERENCES family_members(id),
  FOREIGN KEY (service_id) REFERENCES service_catalog(id),
  INDEX idx_bookings_patient (patient_id),
  INDEX idx_bookings_status (status),
  INDEX idx_bookings_date (scheduled_date)
);

CREATE TABLE assessment_requests (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  request_number VARCHAR(30) NOT NULL UNIQUE,
  patient_id CHAR(36) NOT NULL,
  requested_by CHAR(36) NOT NULL,
  service_category VARCHAR(50) NOT NULL COMMENT 'caretaker_12hr, caretaker_24hr, nursing_12hr, etc.',
  status ENUM('submitted', 'in_review', 'callback_scheduled', 'quote_sent', 'accepted', 'staff_matched', 'deployed', 'declined', 'expired') DEFAULT 'submitted',
  questionnaire_responses JSON NOT NULL,
  assigned_coordinator VARCHAR(255),
  callback_scheduled_at DATETIME,
  callback_notes TEXT,
  quote JSON COMMENT '{staff_salary, commission_monthly, commission_3month, plan_options, inclusions, valid_until}',
  quote_sent_at DATETIME,
  quote_expires_at DATETIME,
  selected_plan ENUM('monthly', '3_month'),
  accepted_at DATETIME,
  declined_at DATETIME,
  decline_reason TEXT,
  deployment_id CHAR(36),
  payment_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (requested_by) REFERENCES family_members(id),
  INDEX idx_assessments_patient (patient_id),
  INDEX idx_assessments_status (status)
);

CREATE TABLE payments (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  payment_number VARCHAR(30) NOT NULL UNIQUE,
  patient_id CHAR(36) NOT NULL,
  paid_by CHAR(36) NOT NULL,
  payment_type ENUM('commission', 'salary', 'booking', 'emi_installment') NOT NULL,
  reference_type VARCHAR(50) COMMENT 'booking, assessment_request, deployment',
  reference_id CHAR(36),
  amount INT NOT NULL COMMENT 'Amount in paise',
  gst_amount INT DEFAULT 0,
  total_amount INT NOT NULL,
  currency VARCHAR(3) DEFAULT 'INR',
  razorpay_payment_id VARCHAR(100),
  razorpay_order_id VARCHAR(100),
  razorpay_signature VARCHAR(255),
  status ENUM('pending', 'processing', 'completed', 'failed', 'refunded', 'partial_refund') DEFAULT 'pending',
  payment_method VARCHAR(20) COMMENT 'upi, card, netbanking, wallet, emi',
  refund_amount INT DEFAULT 0,
  refund_reason TEXT,
  refunded_at DATETIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (paid_by) REFERENCES family_members(id),
  INDEX idx_payments_patient (patient_id),
  INDEX idx_payments_status (status)
);

CREATE TABLE invoices (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  invoice_number VARCHAR(30) NOT NULL UNIQUE,
  patient_id CHAR(36) NOT NULL,
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,
  line_items JSON NOT NULL COMMENT 'Array of {description, amount, gst, total, type}',
  subtotal INT NOT NULL,
  gst_total INT NOT NULL,
  grand_total INT NOT NULL,
  due_date DATE NOT NULL,
  status ENUM('pending', 'paid', 'overdue', 'partially_paid') DEFAULT 'pending',
  pdf_url VARCHAR(500),
  sent_via JSON DEFAULT (JSON_ARRAY()),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  INDEX idx_invoices_patient (patient_id),
  INDEX idx_invoices_status (status),
  INDEX idx_invoices_due (due_date)
);

CREATE TABLE family_concerns (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  patient_id CHAR(36) NOT NULL,
  raised_by CHAR(36) NOT NULL,
  deployment_id CHAR(36),
  category VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  evidence_urls JSON COMMENT 'Array of URL strings',
  urgency ENUM('low', 'medium', 'high', 'emergency') NOT NULL,
  preferred_resolution TEXT,
  status ENUM('received', 'acknowledged', 'in_progress', 'resolved', 'escalated') DEFAULT 'received',
  assigned_to VARCHAR(255),
  resolution_notes TEXT,
  resolution_satisfaction TINYINT CHECK (resolution_satisfaction >= 1 AND resolution_satisfaction <= 5),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (raised_by) REFERENCES family_members(id),
  INDEX idx_concerns_patient (patient_id),
  INDEX idx_concerns_status (status)
);

CREATE TABLE daily_ratings (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  patient_id CHAR(36) NOT NULL,
  deployment_id CHAR(36),
  rated_by CHAR(36) NOT NULL,
  date DATE NOT NULL,
  rating TINYINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (rated_by) REFERENCES family_members(id),
  UNIQUE KEY uk_rating_deployment_user_date (deployment_id, rated_by, date)
);

CREATE TABLE notification_log (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id CHAR(36) NOT NULL,
  type VARCHAR(50) NOT NULL COMMENT 'attendance, vitals_alert, report_ready, payment_reminder, booking_update, etc.',
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  data JSON,
  channel ENUM('push', 'whatsapp', 'sms', 'email') NOT NULL,
  status ENUM('sent', 'delivered', 'read', 'failed') DEFAULT 'sent',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_notifications_user (user_id),
  INDEX idx_notifications_status (status),
  INDEX idx_notifications_created (created_at)
);

-- -------------------------------------------------
-- SEED DATA: Service Catalog
-- -------------------------------------------------

INSERT INTO service_catalog (id, name, name_hi, category, booking_type, description, description_hi, base_price_min, base_price_max, duration_minutes, lead_time_hours, display_order, icon_name) VALUES
(UUID(), 'Nursing Visit', 'नर्सिंग विज़िट', 'nursing_visit', 'instant', 'BSc/GNM nurse visit for wound dressing, injection, catheter, vitals check', 'BSc/GNM नर्स विज़िट — ड्रेसिंग, इंजेक्शन, कैथेटर, विटल्स चेक', 50000, 150000, 60, 24, 1, 'medical_services'),
(UUID(), 'Physiotherapy Session', 'फिजियोथेरेपी सेशन', 'physio_visit', 'instant', 'Physio session at home — mobility, stroke rehab, post-surgery', 'घर पर फिजियो सेशन — मोबिलिटी, स्ट्रोक रिहैब, सर्जरी के बाद', 60000, 120000, 45, 24, 2, 'fitness_center'),
(UUID(), 'Sleep Therapy', 'स्लीप थेरेपी', 'sleep_therapy', 'instant', 'Sleep consultant visit for assessment + therapy plan', 'स्लीप कंसल्टेंट विज़िट — आकलन + थेरेपी प्लान', 100000, 200000, 90, 72, 3, 'bedtime'),
(UUID(), 'Lab Test', 'लैब टेस्ट', 'lab_test', 'instant', 'Diagnostic sample collection at home', 'घर पर सैंपल कलेक्शन', 30000, 300000, 15, 24, 4, 'science'),
(UUID(), 'Caretaker (12hr)', 'केयरटेकर (12 घंटे)', 'caretaker', 'assessment', 'Daytime caretaker for daily care support', 'दिन का केयरटेकर — दैनिक देखभाल सहायता', NULL, NULL, NULL, 0, 5, 'person'),
(UUID(), 'Caretaker (24hr)', 'केयरटेकर (24 घंटे)', 'caretaker', 'assessment', 'Full-time live-in caretaker', 'पूर्णकालिक लिव-इन केयरटेकर', NULL, NULL, NULL, 0, 6, 'person'),
(UUID(), 'Nursing (12hr)', 'नर्सिंग (12 घंटे)', 'nursing_deployment', 'assessment', 'Part-time nurse deployment', 'पार्ट-टाइम नर्स तैनाती', NULL, NULL, NULL, 0, 7, 'local_hospital'),
(UUID(), 'Nursing (24hr)', 'नर्सिंग (24 घंटे)', 'nursing_deployment', 'assessment', 'Full-time nurse deployment', 'फुल-टाइम नर्स तैनाती', NULL, NULL, NULL, 0, 8, 'local_hospital'),
(UUID(), 'ICU Setup at Home', 'घर पर ICU सेटअप', 'icu_setup', 'assessment', 'Home ICU setup with equipment + nurse', 'घर पर ICU सेटअप — उपकरण + नर्स', NULL, NULL, NULL, 0, 9, 'monitor_heart'),
(UUID(), 'Japa (Mother & Baby Care)', 'जापा (माँ और शिशु देखभाल)', 'japa', 'assessment', 'Postpartum mother + newborn care specialist', 'प्रसवोत्तर माँ + नवजात देखभाल विशेषज्ञ', NULL, NULL, NULL, 0, 10, 'child_friendly'),
(UUID(), 'Nanny (Child Care)', 'नैनी (बच्चे की देखभाल)', 'nanny', 'assessment', 'Child care specialist', 'बच्चों की देखभाल विशेषज्ञ', NULL, NULL, NULL, 0, 11, 'child_care');
