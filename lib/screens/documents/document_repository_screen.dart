import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class MedicalDocument {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String? fileUrl;
  final String fileType; // pdf, image, scan
  final int? fileSizeBytes;
  final DateTime uploadedAt;
  final String? uploadedBy;

  MedicalDocument({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.fileUrl,
    this.fileType = 'image',
    this.fileSizeBytes,
    required this.uploadedAt,
    this.uploadedBy,
  });
}

class DocumentRepositoryScreen extends StatefulWidget {
  const DocumentRepositoryScreen({super.key});

  @override
  State<DocumentRepositoryScreen> createState() =>
      _DocumentRepositoryScreenState();
}

class _DocumentRepositoryScreenState extends State<DocumentRepositoryScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  static final _categories = [
    'all',
    'prescriptions',
    'lab_reports',
    'discharge_summary',
    'imaging',
    'insurance',
    'other',
  ];

  static final _categoryLabels = {
    'all': 'All',
    'prescriptions': 'Prescriptions',
    'lab_reports': 'Lab Reports',
    'discharge_summary': 'Discharge Summary',
    'imaging': 'X-Ray / Scans',
    'insurance': 'Insurance',
    'other': 'Other',
  };

  static final _categoryIcons = {
    'prescriptions': Icons.medication,
    'lab_reports': Icons.biotech,
    'discharge_summary': Icons.assignment,
    'imaging': Icons.image_search,
    'insurance': Icons.health_and_safety,
    'other': Icons.folder,
  };

  // Mock documents
  final List<MedicalDocument> _documents = [
    MedicalDocument(
      id: 'doc1',
      name: 'Dr. Sharma Prescription — March 2026',
      category: 'prescriptions',
      description: 'Blood pressure medication updated',
      fileType: 'image',
      fileSizeBytes: 245000,
      uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
      uploadedBy: 'Suresh Kumar',
    ),
    MedicalDocument(
      id: 'doc2',
      name: 'CBC & Thyroid Panel',
      category: 'lab_reports',
      description: 'Routine blood work — all normal',
      fileType: 'pdf',
      fileSizeBytes: 520000,
      uploadedAt: DateTime.now().subtract(const Duration(days: 10)),
      uploadedBy: 'Priya Mehra (Nurse)',
    ),
    MedicalDocument(
      id: 'doc3',
      name: 'Chest X-Ray',
      category: 'imaging',
      description: 'Annual checkup — no abnormalities',
      fileType: 'image',
      fileSizeBytes: 1200000,
      uploadedAt: DateTime.now().subtract(const Duration(days: 30)),
      uploadedBy: 'Lab Technician',
    ),
    MedicalDocument(
      id: 'doc4',
      name: 'CGHS Health Card',
      category: 'insurance',
      fileType: 'image',
      fileSizeBytes: 180000,
      uploadedAt: DateTime.now().subtract(const Duration(days: 90)),
      uploadedBy: 'Suresh Kumar',
    ),
    MedicalDocument(
      id: 'doc5',
      name: 'Hospital Discharge Summary — Jan 2026',
      category: 'discharge_summary',
      description: 'Post hip replacement surgery discharge notes',
      fileType: 'pdf',
      fileSizeBytes: 340000,
      uploadedAt: DateTime.now().subtract(const Duration(days: 60)),
      uploadedBy: 'Suresh Kumar',
    ),
  ];

  List<MedicalDocument> get _filteredDocs {
    var docs = _documents.toList();
    if (_selectedCategory != 'all') {
      docs = docs.where((d) => d.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      docs = docs
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              (d.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Medical Documents'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(
                    _categoryLabels[cat]!,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : HousepitalColors.grey,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedColor: HousepitalColors.orange,
                  backgroundColor: HousepitalColors.greyLighter,
                  checkmarkColor: Colors.white,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Document count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredDocs.length} document${_filteredDocs.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 13, color: HousepitalColors.greyLight),
                ),
                const Spacer(),
                Text(
                  'Total: ${_formatFileSize(_documents.fold(0, (sum, d) => sum + (d.fileSizeBytes ?? 0)))}',
                  style: const TextStyle(
                      fontSize: 12, color: HousepitalColors.greyLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Document list
          Expanded(
            child: _filteredDocs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open,
                            size: 48, color: HousepitalColors.greyLight),
                        const SizedBox(height: 12),
                        const Text('No documents in this category',
                            style: TextStyle(color: HousepitalColors.greyLight)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredDocs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) =>
                        _buildDocCard(_filteredDocs[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadOptions(context),
        backgroundColor: HousepitalColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
    );
  }

  Widget _buildDocCard(MedicalDocument doc) {
    final icon = _categoryIcons[doc.category] ?? Icons.insert_drive_file;
    final isImage = doc.fileType == 'image' || doc.fileType == 'scan';

    return HousepitalCard(
      onTap: () => _showDocDetail(doc),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isImage
                  ? HousepitalColors.orangeLight
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isImage ? HousepitalColors.orange : Colors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HousepitalColors.black),
                ),
                if (doc.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    doc.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: HousepitalColors.greyLight),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateHelper.formatDateShort(doc.uploadedAt),
                      style: const TextStyle(
                          fontSize: 11, color: HousepitalColors.greyLight),
                    ),
                    if (doc.fileSizeBytes != null) ...[
                      const Text(' · ',
                          style: TextStyle(color: HousepitalColors.greyLight)),
                      Text(
                        _formatFileSize(doc.fileSizeBytes!),
                        style: const TextStyle(
                            fontSize: 11, color: HousepitalColors.greyLight),
                      ),
                    ],
                    if (doc.uploadedBy != null) ...[
                      const Text(' · ',
                          style: TextStyle(color: HousepitalColors.greyLight)),
                      Flexible(
                        child: Text(
                          doc.uploadedBy!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: HousepitalColors.greyLight),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: HousepitalColors.greyLighter,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              doc.fileType.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: HousepitalColors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showDocDetail(MedicalDocument doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(doc.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (doc.description != null)
              Text(doc.description!,
                  style: const TextStyle(
                      fontSize: 14, color: HousepitalColors.grey)),
            const SizedBox(height: 16),
            // audit batch 4 (Agent I): _detailRow → shared DetailRow widget
            // (labelWidth/fontSize tuned to match the document-detail look).
            DetailRow(
              label: 'Category',
              value: _categoryLabels[doc.category] ?? doc.category,
              labelWidth: 100,
              valueFontSize: 13,
            ),
            DetailRow(
              label: 'Type',
              value: doc.fileType.toUpperCase(),
              labelWidth: 100,
              valueFontSize: 13,
            ),
            DetailRow(
              label: 'Size',
              value: _formatFileSize(doc.fileSizeBytes ?? 0),
              labelWidth: 100,
              valueFontSize: 13,
            ),
            DetailRow(
              label: 'Uploaded',
              value: DateHelper.formatDate(doc.uploadedAt),
              labelWidth: 100,
              valueFontSize: 13,
            ),
            if (doc.uploadedBy != null)
              DetailRow(
                label: 'Uploaded by',
                value: doc.uploadedBy!,
                labelWidth: 100,
                valueFontSize: 13,
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(
                          text: '${doc.name}\nCategory: ${_categoryLabels[doc.category] ?? doc.category}'
                              '${doc.description != null ? '\n${doc.description}' : ''}'
                              '\nUploaded: ${DateHelper.formatDate(doc.uploadedAt)}',
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // audit M-16: actually launch the document URL via
                  // url_launcher instead of a "coming soon" stub. Falls back
                  // to a SnackBar pointing the user at Share if the URL is
                  // missing/invalid or the launch fails.
                  child: ElevatedButton.icon(
                    onPressed: () => _openDocument(doc),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(doc);
                },
                child: const Text('Delete Document',
                    style: TextStyle(color: HousepitalColors.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // audit batch 4 (Agent I): private _detailRow removed — replaced by the
  // shared DetailRow widget in widgets/common_widgets.dart.

  // audit M-16: attempt to launch the stored document URL in an external
  // viewer (browser, PDF reader, etc). Closes the detail sheet first so the
  // SnackBar fallback is visible. If fileUrl is null/empty/invalid or the
  // launch fails, the user is pointed at Share as a workaround.
  Future<void> _openDocument(MedicalDocument doc) async {
    Navigator.pop(context); // close detail sheet
    final url = doc.fileUrl;
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't open this document. Tap Share to send it to yourself."),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    bool launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't open this document. Tap Share to send it to yourself."),
        ),
      );
    }
  }

  // audit M-13: migrated to shared confirmDestructiveAction helper for
  // consistent red CTA, haptic, and copy across destructive flows.
  Future<void> _confirmDelete(MedicalDocument doc) async {
    final ok = await confirmDestructiveAction(
      context,
      title: 'Delete document?',
      message: 'Are you sure you want to delete "${doc.name}"?',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _documents.removeWhere((d) => d.id == doc.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document deleted')),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Add Medical Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HousepitalColors.orangeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.camera_alt, color: HousepitalColors.orange),
            ),
            title: const Text('Scan Document'),
            subtitle: const Text('Use camera to scan a document'),
            onTap: () {
              Navigator.pop(context);
              _scanDocument();
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library, color: Colors.blue),
            ),
            title: const Text('Upload from Gallery'),
            subtitle: const Text('Choose from photos or files'),
            onTap: () {
              Navigator.pop(context);
              _uploadFromGallery();
            },
          ),
          // audit M-16: file_picker is not in pubspec.yaml, so a real
          // PDF-selection flow isn't available. On web we hide the button
          // entirely (no native dialer/email fallback that helps here);
          // on mobile we replace the misleading "coming soon" toast with an
          // honest pointer to the wecare@ inbox.
          if (!kIsWeb)
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.green),
              ),
              title: const Text('Upload PDF'),
              subtitle: const Text(
                  'Email PDFs to wecare@housepital.in for now'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'PDF upload coming soon. Email your documents to wecare@housepital.in for now.'),
                    backgroundColor: HousepitalColors.info,
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _scanDocument() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        _showCategorizeDialog(image.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not available')),
        );
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        _showCategorizeDialog(image.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery not available')),
        );
      }
    }
  }

  void _showCategorizeDialog(String fileName) {
    final nameController = TextEditingController(text: fileName);
    String category = 'prescriptions';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Document Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .where((c) => c != 'all')
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(_categoryLabels[c]!)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _documents.insert(
                    0,
                    MedicalDocument(
                      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameController.text,
                      category: category,
                      fileType: 'scan',
                      fileSizeBytes: 350000,
                      uploadedAt: DateTime.now(),
                      uploadedBy: 'You',
                    ),
                  );
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document saved successfully')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
