import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';
// audit batch 4 (Agent I): centralized validator caps description length
// (audit F finding — was unbounded, 10MB DoS risk).
import '../../utils/validators.dart';

class RaiseConcernScreen extends StatefulWidget {
  const RaiseConcernScreen({super.key});

  @override
  State<RaiseConcernScreen> createState() => _RaiseConcernScreenState();
}

class _RaiseConcernScreenState extends State<RaiseConcernScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  String? _category;
  String _urgency = 'medium';
  String? _resolution;
  bool _isSubmitting = false;

  final List<XFile> _evidencePhotos = [];
  static const int _maxPhotos = 3;

  final List<Map<String, String>> _categories = [
    {'value': 'staff_behaviour', 'label': 'Staff behaviour / व्यवहार की समस्या'},
    {'value': 'staff_not_following', 'label': 'Staff not following routine / काम ठीक से नहीं हो रहा'},
    {'value': 'staff_absent', 'label': 'Staff absent / कर्मचारी नहीं आया'},
    {'value': 'need_replacement', 'label': 'Need replacement / बदलाव चाहिए'},
    {'value': 'medical_concern', 'label': 'Medical concern / मरीज़ की तबियत'},
    {'value': 'payment_issue', 'label': 'Payment or billing issue / भुगतान की समस्या'},
    {'value': 'service_quality', 'label': 'Service quality / सेवा की गुणवत्ता'},
    {'value': 'other', 'label': 'Other / कुछ और'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    if (_evidencePhotos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Add Photo Evidence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: HousepitalColors.orange),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _capturePhoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: HousepitalColors.orange),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _capturePhoto(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (image != null && mounted) {
        setState(() => _evidencePhotos.add(image));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(source == ImageSource.camera
              ? 'Camera not available'
              : 'Gallery not available')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _evidencePhotos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('raise_concern'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // audit batch 4 (Agent I): onUserInteraction so the user sees the
          // 1000-char cap warning before they finish typing 10MB.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                decoration: InputDecoration(labelText: l.t('concern_category')),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c['value'],
                  child: Text(c['label']!, style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l.t('concern_description'),
                  hintText: 'Describe the issue in detail...',
                ),
                maxLines: 4,
                // audit batch 4 (Agent I): audit F — cap at 1000 chars
                // to block oversized bodies. `maxLength` shows the counter.
                maxLength: 1000,
                validator: (v) =>
                    Validators.description(v, max: 1000),
              ),
              const SizedBox(height: 16),

              // Urgency
              Text(l.t('concern_urgency'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _urgencyChip('low', 'Low', context.hc.info),
                  const SizedBox(width: 8),
                  _urgencyChip('medium', 'Medium', context.hc.warning),
                  const SizedBox(width: 8),
                  _urgencyChip('high', 'High', HousepitalColors.orange),
                  const SizedBox(width: 8),
                  _urgencyChip('emergency', 'Emergency', context.hc.error),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _resolution,
                decoration: InputDecoration(labelText: l.t('concern_resolution')),
                items: const [
                  DropdownMenuItem(value: 'counseling', child: Text('Counseling of staff')),
                  DropdownMenuItem(value: 'replacement', child: Text('Replacement')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _resolution = v),
              ),
              const SizedBox(height: 16),

              // Photo upload button
              OutlinedButton.icon(
                onPressed: _evidencePhotos.length >= _maxPhotos ? null : _pickEvidence,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _evidencePhotos.isEmpty
                      ? 'Add Photo Evidence (optional)'
                      : 'Add More Photos (${_evidencePhotos.length}/$_maxPhotos)',
                ),
              ),

              // Photo thumbnails
              if (_evidencePhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _evidencePhotos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_evidencePhotos[index].path),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Evidence photo ${index + 1} of ${_evidencePhotos.length}',
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.hc.error,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _submitConcern(context, l);
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l.t('submit_concern')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urgencyChip(String value, String label, Color color) {
    final isSelected = _urgency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgency = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : context.hc.greyLighter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : context.hc.greyLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// audit M-9: upload photos in batches of up to 3 in parallel.
  /// Returns a list of successfully-uploaded download URLs (skipping failures).
  /// We don't have a ticket id yet (it's assigned server-side on submit), so
  /// scope by patientId + a single timestamp prefix per submission attempt.
  Future<List<String>> _uploadEvidence(String patientId) async {
    if (_evidencePhotos.isEmpty) return const [];

    final firebaseService = context.read<AuthProvider>().firebaseService;
    final batchTs = DateTime.now().millisecondsSinceEpoch;
    const concurrencyCap = 3;

    final urls = <String>[];
    for (var start = 0; start < _evidencePhotos.length; start += concurrencyCap) {
      final end = (start + concurrencyCap < _evidencePhotos.length)
          ? start + concurrencyCap
          : _evidencePhotos.length;
      final futures = <Future<String?>>[];
      for (var i = start; i < end; i++) {
        final photo = _evidencePhotos[i];
        final filename = p.basename(photo.path);
        futures.add(firebaseService.uploadFile(
          localPath: photo.path,
          storagePath: 'concerns/${patientId}_$batchTs/${i}_$filename',
          contentType: 'image/jpeg',
        ));
      }
      final results = await Future.wait(futures);
      for (final r in results) {
        if (r != null) urls.add(r);
      }
    }
    return urls;
  }

  Future<void> _submitConcern(BuildContext context, AppLocalizations l) async {
    final patient = context.read<AppProvider>().currentPatient;
    if (patient == null) return;

    setState(() => _isSubmitting = true);

    try {
      // audit M-9: upload evidence photos to Firebase Storage before submitting.
      // Previously local device paths were sent as URLs and coordinators
      // couldn't open them.
      final evidenceUrls = await _uploadEvidence(patient.id);
      final failedCount = _evidencePhotos.length - evidenceUrls.length;
      if (failedCount > 0) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              "$failedCount photo${failedCount == 1 ? '' : 's'} couldn't be uploaded. "
              'Your concern was submitted without them — reply to the '
              "coordinator's message in chat to add photos.",
            ),
            backgroundColor: context.hc.warning,
          ),
        );
      }

      if (!context.mounted) return;
      await context.read<AppProvider>().apiService.raiseConcern(
        patientId: patient.id,
        category: _category!,
        description: _descriptionController.text.trim(),
        urgency: _urgency,
        preferredResolution: _resolution,
        evidenceUrls: evidenceUrls.isNotEmpty ? evidenceUrls : null,
      );

      if (!context.mounted) return;

      final slaText = _urgency == 'emergency'
          ? 'We will respond within 2 hours.'
          : _urgency == 'high'
              ? 'We will respond within 12 hours.'
              : 'We will respond within 24-72 hours.';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.check_circle,
              color: context.hc.success, size: 48),
          title: Text(l.t('concern_submitted')),
          content: Text(slaText),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: ${e.message}'),
          backgroundColor: context.hc.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: context.hc.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
