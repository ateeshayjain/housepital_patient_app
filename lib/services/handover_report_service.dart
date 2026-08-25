// lib/services/handover_report_service.dart
//
// Doctor Handover Report — the flagship "share with any doctor" PDF: one
// comprehensive A4 multipage document covering the patient's medical history,
// current medications (+ weekly adherence), the last 7 days of vitals,
// today's care report, active services & staff on duty, and upcoming
// visits/tests.
//
// buildHandoverPdf() only assembles bytes (unit-testable, no platform
// channels beyond rootBundle, which has a text fallback); shareHandover()
// wraps Printing.sharePdf for the share sheet.
//
// NOTE: no prices appear anywhere in this report — it is a clinical
// document, and manpower prices are never displayed in any case.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/demo_data.dart';
import '../data/demo_mode.dart';
import '../models/care_event.dart';
import '../models/medical_history.dart';

class HandoverReportService {
  static const _orange = PdfColor.fromInt(0xFFFF6B00);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _greyLighter = PdfColor.fromInt(0xFFF3F4F6);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _yesNo(bool v) => v ? 'Yes' : 'No';

  /// The built-in Helvetica fonts have no em/en-dash or curly-quote glyphs —
  /// swap them for ASCII so dynamic strings (diagnosis, staff notes, titles)
  /// always render.
  static String _ascii(String s) => s
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"');

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/housepital_logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _sectionTitle(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _orange)),
      );

  pw.Widget _kv(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 150,
              child: pw.Text(_ascii(label),
                  style: const pw.TextStyle(fontSize: 10, color: _grey))),
          pw.Expanded(
              child: pw.Text(_ascii(value),
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  pw.Widget _cell(String text, {bool header = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(_ascii(text),
            style: header
                ? pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _grey)
                : const pw.TextStyle(fontSize: 9)),
      );

  /// Assembles the full handover report. All data comes from the demo layer
  /// today (the future backend swap only changes the sources, not the PDF).
  Future<Uint8List> buildHandoverPdf({DateTime? now}) async {
    final logo = await _loadLogo();
    final generated = now ?? DateTime.now();

    // Every field below is SAMPLE data. This document is shared with a real
    // clinician (Printing.sharePdf), so it must say so on its own face — an
    // in-app banner cannot travel with a PDF. See the header band below.
    DemoMode.markServingDemoData(DemoMode.sourceHandover);

    final patient = DemoData.patient;
    final MedicalHistory mh = DemoData.medicalHistory;
    final medications = DemoData.medications.where((m) => m.isActive).toList();
    final vitals = DemoData.vitalsHistory;
    final report = DemoData.todayReport;
    final services = DemoData.activeServices;
    final staffOnDuty = DemoData.icuServiceDetail.staffOnDuty;
    final appointments = DemoData.upcomingAppointments;

    // Deterministic weekly adherence — same shared pure helpers used by the
    // medications screen header and the Care Calendar.
    final pct = weeklyAdherencePercent(now: generated);
    final weekTotal = dosesPerDay() * 7;
    final weekTaken = (weekTotal * pct / 100).round();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.red50),
          child: pw.Text(
            'SAMPLE DATA - NOT A CLINICAL RECORD. This report was generated '
            'while the Housepital service was unreachable and contains '
            'placeholder information. Do not use it for clinical decisions.',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900),
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
              'Housepital Doctor Handover Report - page '
              '${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ),
        build: (ctx) => [
          // ── Brand header ────────────────────────────────────────────────
          pw.Row(children: [
            if (logo != null)
              pw.Image(logo, height: 36)
            else
              pw.Text('HOUSEPITAL',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _orange)),
            pw.Spacer(),
            pw.Text('Generated ${_fmtDate(generated)}',
                style: const pw.TextStyle(fontSize: 10, color: _grey)),
          ]),
          pw.SizedBox(height: 10),
          pw.Text('Doctor Handover Report',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(
              'Complete care summary for sharing with any treating doctor.',
              style: const pw.TextStyle(fontSize: 10, color: _grey)),

          // ── 1. Patient & Medical History ────────────────────────────────
          _sectionTitle('Patient & Medical History'),
          _kv(
              'Patient',
              '${patient.name}'
              '${patient.age != null ? ' - ${patient.age} yrs' : ''}'
              '${patient.gender != null ? ', ${patient.gender}' : ''}'),
          _kv('Conditions', mh.conditions.join(', ')),
          _kv('Diagnosis', mh.diagnosis),
          if (mh.heightCm != null || mh.weightKg != null)
            _kv('Height / Weight',
                '${mh.heightCm ?? '-'} cm / ${mh.weightKg ?? '-'} kg'),
          _kv('Lines', mh.lines.isEmpty ? 'None' : mh.lines.join(', ')),
          _kv('Discharge summary', _yesNo(mh.dischargeSummaryAvailable)),
          _kv('RT/PEG feeding', _yesNo(mh.rtPegFeeding)),
          _kv('Mental condition', _yesNo(mh.mentalCondition)),
          _kv('Motion status', mh.motionStatus),
          _kv('Mobility', mh.mobilityStatus),
          _kv('BP/Sugar/Insulin monitoring', _yesNo(mh.bpSugarInsulin)),
          if (mh.allergies != null) _kv('Allergies', mh.allergies!),
          if (mh.dietaryRestrictions.isNotEmpty)
            _kv('Dietary restrictions', mh.dietaryRestrictions.join(', ')),
          if (mh.restrictions != null) _kv('Restrictions', mh.restrictions!),
          if (mh.specialInstructions != null)
            _kv('Special instructions', mh.specialInstructions!),
          if (mh.preferredHospital != null)
            _kv('Preferred hospital', mh.preferredHospital!),

          // ── 2. Current Medications ──────────────────────────────────────
          _sectionTitle('Current Medications'),
          pw.Text(
              'This week adherence: $pct% ($weekTaken/$weekTotal doses)',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: _greyLighter, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(4),
              4: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _greyLighter),
                children: [
                  _cell('Medicine', header: true),
                  _cell('Dosage', header: true),
                  _cell('Times', header: true),
                  _cell('Instructions', header: true),
                  _cell('Prescribed by', header: true),
                ],
              ),
              ...medications.map((m) => pw.TableRow(children: [
                    _cell(m.name),
                    _cell('${m.dosage} - ${m.frequencyLabel}'),
                    _cell(m.timeSlots.join(', ')),
                    _cell(m.instructions ?? '-'),
                    _cell(m.prescribedBy ?? '-'),
                  ])),
            ],
          ),

          // ── 3. Vitals — last 7 days ─────────────────────────────────────
          _sectionTitle('Vitals - Last 7 Days'),
          pw.Table(
            border: pw.TableBorder.all(color: _greyLighter, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _greyLighter),
                children: [
                  _cell('Date', header: true),
                  _cell('BP (mmHg)', header: true),
                  _cell('SpO2 (%)', header: true),
                  _cell('Pulse (bpm)', header: true),
                  _cell('Temp (F)', header: true),
                  _cell('Sugar (mg/dl)', header: true),
                ],
              ),
              ...vitals.map((v) => pw.TableRow(children: [
                    _cell(_fmtDate(v.recordedAt)),
                    _cell('${v.systolic?.toInt() ?? '-'}/'
                        '${v.diastolic?.toInt() ?? '-'}'),
                    _cell('${v.spo2?.toInt() ?? '-'}'),
                    _cell('${v.pulse?.toInt() ?? '-'}'),
                    _cell('${v.temperature ?? '-'}'),
                    _cell('${v.sugar?.toInt() ?? '-'}'),
                  ])),
            ],
          ),

          // ── 4. Today's care report ──────────────────────────────────────
          _sectionTitle("Today's Care Report"),
          _kv('Tasks completed',
              '${report.completedTasks} of ${report.totalTasks}'),
          if (report.staffNotes != null)
            _kv('Staff notes', report.staffNotes!),

          // ── 5. Active services & staff on duty ──────────────────────────
          _sectionTitle('Active Services & Staff on Duty'),
          ...services.map((s) => pw.Bullet(
                text: _ascii('${s.name} (since ${_fmtDate(s.startDate)})'),
                style: const pw.TextStyle(fontSize: 10),
              )),
          pw.SizedBox(height: 4),
          ...staffOnDuty.map((s) => pw.Bullet(
                text: _ascii('${s.name} - ${s.role}'),
                style: const pw.TextStyle(fontSize: 10),
              )),

          // ── 6. Upcoming visits & tests ──────────────────────────────────
          _sectionTitle('Upcoming Visits & Tests'),
          ...appointments.map((a) => pw.Bullet(
                text: _ascii('${a.title} - ${_fmtDate(a.date)}'),
                style: const pw.TextStyle(fontSize: 10),
              )),

          pw.SizedBox(height: 14),
          pw.Divider(color: _greyLighter),
          pw.Text(
              'Compiled by the Housepital patient app from supervisor-synced '
              'records. This is a computer-generated document.',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.SizedBox(height: 4),
          // This document is handed to a doctor and reads like a clinical
          // summary. It is not one: it is a transcription of what was entered
          // in an app, it can be incomplete, and no clinician has reviewed it
          // before it prints. The reader is the one person who most needs to
          // know that, so it goes on the page rather than in the app.
          pw.Text(
              'NOT A CLINICAL ASSESSMENT. Records are entered by caregivers '
              'and family through the Housepital app and are not verified by '
              'a clinician. Readings, doses and timings may be incomplete or '
              'delayed. Please confirm anything you intend to act on directly '
              'with the patient and the care team.',
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
    );
    return doc.save();
  }

  /// Deterministic share-sheet filename for a given generation date — pure,
  /// so tests can pin the date without touching the platform channel.
  String handoverFilename(DateTime now) {
    final patientSlug = DemoData.patient.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final ymd = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'housepital-handover-$patientSlug-$ymd.pdf';
  }

  /// Builds the report and hands it to the platform share sheet.
  ///
  /// [now] is injected for determinism (tests pin it); the SAME value drives
  /// both the PDF content (header date, adherence week) and the filename, so
  /// a share started at 23:59:59 can't end up with a filename dated a day
  /// after the report it contains.
  Future<void> shareHandover({DateTime? now}) async {
    final generated = now ?? DateTime.now();
    final bytes = await buildHandoverPdf(now: generated);
    await Printing.sharePdf(
        bytes: bytes, filename: handoverFilename(generated));
  }
}
