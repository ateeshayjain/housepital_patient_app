import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/models.dart';

/// Handles billing-related state, extracted from AppProvider
/// to maintain Single Responsibility.
class BillingProvider extends ChangeNotifier {
  final ApiService _apiService;

  int _amountDue = 0;
  DateTime? _dueDate;
  bool _isLoading = false;
  String? _error;

  BillingProvider(this._apiService);

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
      if (kDebugMode) {
        debugPrint('BillingProvider.loadBillingSummary error: $e');
      }
      _error = 'Failed to load billing data';
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
}
