import 'package:flutter/foundation.dart';
import '../data/demo_data.dart';
import '../data/demo_mode.dart';
import '../services/i_api_service.dart';
import '../utils/logger.dart';

/// Handles billing-related state, extracted from AppProvider
/// to maintain Single Responsibility.
class BillingProvider extends ChangeNotifier {
  // audit batch 4 (Agent J): depend on IApiService (DIP).
  final IApiService _apiService;

  int _amountDue = 0;
  DateTime? _dueDate;
  bool _isLoading = false;
  String? _error;

  BillingProvider(IApiService api) : _apiService = api;

  int get amountDue => _amountDue;
  DateTime? get dueDate => _dueDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads billing summary for the given patient.
  Future<void> loadBillingSummary(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final billing = await _apiService.getBillingSummary(patientId);
      _amountDue = billing['amount_due'] ?? 0;
      _dueDate = billing['due_date'] != null
          ? DateTime.parse(billing['due_date'])
          : null;
      _error = null;
    } catch (e) {
      Log.warn('loadBillingSummary error', error: e, tag: 'BillingProvider');
      // Fallback to demo billing data
      if (_amountDue == 0) {
        final demoBilling = DemoData.billingSummary;
        DemoMode.markServingDemoData(DemoMode.sourceBilling);
        _amountDue = demoBilling['amount_due'] ?? 0;
        _dueDate = demoBilling['due_date'] != null
            ? DateTime.parse(demoBilling['due_date'])
            : null;
        _error = null;
      } else {
        _error = 'Failed to load billing data';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Updates billing state from a sync payload.
  void updateFromSync(Map<String, dynamic> billingSummary) {
    _amountDue = billingSummary['amount_due'] ?? 0;
    _dueDate = billingSummary['due_date'] != null
        ? DateTime.parse(billingSummary['due_date'])
        : null;
    notifyListeners();
  }
  /// Clears every field that belongs to ONE patient — an amount due is the
  /// most misleading thing to show under the wrong name.
  void clearPatientScopedData() {
    _amountDue = 0;
    _dueDate = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

}
