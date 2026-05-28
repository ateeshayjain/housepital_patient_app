import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_localizations.dart';

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
            leading: const Icon(Icons.photo_library, color: Colors.blue),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _category,
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
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe the issue'
                    : null,
              ),
              const SizedBox(height: 16),

              // Urgency
              Text(l.t('concern_urgency'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _urgencyChip('low', 'Low', HousepitalColors.info),
                  const SizedBox(width: 8),
                  _urgencyChip('medium', 'Medium', HousepitalColors.warning),
                  const SizedBox(width: 8),
                  _urgencyChip('high', 'High', HousepitalColors.orange),
                  const SizedBox(width: 8),
                  _urgencyChip('emergency', 'Emergency', HousepitalColors.error),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _resolution,
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
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                decoration: const BoxDecoration(
                                  color: HousepitalColors.error,
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
            color: isSelected ? color.withValues(alpha: 0.15) : HousepitalColors.greyLighter,
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
                color: isSelected ? color : HousepitalColors.greyLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitConcern(BuildContext context, AppLocalizations l) async {
    final patient = context.read<AppProvider>().currentPatient;
    if (patient == null) return;

    setState(() => _isSubmitting = true);

    try {
      final evidencePaths = _evidencePhotos.map((p) => p.path).toList();

      await context.read<AppProvider>().apiService.raiseConcern(
        patientId: patient.id,
        category: _category!,
        description: _descriptionController.text.trim(),
        urgency: _urgency,
        preferredResolution: _resolution,
        evidenceUrls: evidencePaths.isNotEmpty ? evidencePaths : null,
      );

      if (!mounted) return;

      final slaText = _urgency == 'emergency'
          ? 'We will respond within 2 hours.'
          : _urgency == 'high'
              ? 'We will respond within 12 hours.'
              : 'We will respond within 24-72 hours.';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              color: HousepitalColors.success, size: 48),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: ${e.message}'),
          backgroundColor: HousepitalColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: HousepitalColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
