import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Mock saved documents — in production, fetched from a DocumentProvider.
/// Single source of truth for all screens that need document selection.
const List<Map<String, String>> kSavedDocuments = [
  {'id': 'doc1', 'name': 'Dr. Sharma Prescription — March 2026', 'category': 'prescriptions'},
  {'id': 'doc2', 'name': 'CBC & Thyroid Panel', 'category': 'lab_reports'},
  {'id': 'doc3', 'name': 'Chest X-Ray', 'category': 'imaging'},
  {'id': 'doc5', 'name': 'Hospital Discharge Summary — Jan 2026', 'category': 'discharge_summary'},
];

/// Displays a list of attached file chips with remove buttons.
class AttachedFilesList extends StatelessWidget {
  final List<String> files;
  final void Function(int index) onRemove;

  const AttachedFilesList({
    super.key,
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        ...files.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 18, color: HousepitalColors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry.value,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: const Icon(Icons.close,
                          size: 18, color: HousepitalColors.greyLight),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Toggle widget for requesting an online video assessment.
class OnlineAssessmentToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String subtitle;

  const OnlineAssessmentToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.subtitle = 'Get a video consultation before the visit',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HousepitalColors.infoLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_outlined,
              size: 22, color: HousepitalColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Request Online Assessment',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: HousepitalColors.info)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: HousepitalColors.info,
          ),
        ],
      ),
    );
  }
}

/// Shows a bottom sheet with options to attach documents:
/// - Choose from saved documents
/// - Take photo
/// - Choose from gallery
/// - Upload document
void showAttachOptionsSheet(
  BuildContext context, {
  required String title,
  required List<String> attachedFiles,
  required void Function(String fileName) onFileAdded,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HousepitalColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_outlined,
                    color: HousepitalColors.info),
              ),
              title: const Text('Choose from Saved Documents'),
              subtitle: const Text('Select from your medical records'),
              onTap: () {
                Navigator.pop(ctx);
                _showSavedDocumentsPicker(
                    context, attachedFiles, onFileAdded);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: HousepitalColors.orange),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture prescription with camera'),
              onTap: () {
                Navigator.pop(ctx);
                onFileAdded(
                    'Prescription_${DateTime.now().millisecondsSinceEpoch}.jpg');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: HousepitalColors.orange),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select existing photo'),
              onTap: () {
                Navigator.pop(ctx);
                onFileAdded(
                    'Photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HousepitalColors.orangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.file_present_outlined,
                    color: HousepitalColors.orange),
              ),
              title: const Text('Upload Document'),
              subtitle: const Text('PDF, JPEG, or PNG'),
              onTap: () {
                Navigator.pop(ctx);
                onFileAdded(
                    'Document_${DateTime.now().millisecondsSinceEpoch}.pdf');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showSavedDocumentsPicker(
  BuildContext context,
  List<String> attachedFiles,
  void Function(String fileName) onFileAdded,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select Document',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('From your saved medical documents',
                style: TextStyle(
                    fontSize: 13, color: HousepitalColors.greyLight)),
            const SizedBox(height: 16),
            ...kSavedDocuments.map((doc) {
              final alreadyAttached =
                  attachedFiles.contains(doc['name']);
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: alreadyAttached
                        ? HousepitalColors.success
                            .withValues(alpha: 0.1)
                        : HousepitalColors.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    alreadyAttached
                        ? Icons.check_circle
                        : Icons.description_outlined,
                    color: alreadyAttached
                        ? HousepitalColors.success
                        : HousepitalColors.orange,
                    size: 20,
                  ),
                ),
                title: Text(doc['name']!,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                    doc['category']!
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 11)),
                enabled: !alreadyAttached,
                onTap: () {
                  Navigator.pop(ctx);
                  onFileAdded(doc['name']!);
                },
              );
            }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/documents');
              },
              child: const Text('View All Documents'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Reusable star rating widget.
class RatingStarsWidget extends StatelessWidget {
  final double rating;
  final double size;

  const RatingStarsWidget({
    super.key,
    required this.rating,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star, size: size, color: Colors.amber);
        } else if (i < rating) {
          return Icon(Icons.star_half, size: size, color: Colors.amber);
        }
        return Icon(Icons.star_border,
            size: size, color: HousepitalColors.greyLight);
      }),
    );
  }
}
