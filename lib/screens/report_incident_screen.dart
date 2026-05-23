import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/api_client.dart';

class ReportIncidentScreen extends StatefulWidget {
  final String? existingCaseId;
  const ReportIncidentScreen({super.key, this.existingCaseId});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _caseTitleController = TextEditingController();

  DateTime _incidentTime = DateTime.now();
  String _category = 'unknown';
  String? _caseId;
  bool _isNewCase = true;
  bool _isLoading = false;

  final List<File> _attachments = [];
  final List<String> _attachmentTypes = [];

  final List<Map<String, String>> _categories = [
    {'value': 'workplace', 'label': 'Workplace', 'emoji': '🏢'},
    {'value': 'public', 'label': 'Public Space', 'emoji': '🏙️'},
    {'value': 'online', 'label': 'Online', 'emoji': '💻'},
    {'value': 'unknown', 'label': 'Unsure', 'emoji': '❓'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingCaseId != null) {
      _caseId = widget.existingCaseId;
      _isNewCase = false;
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_incidentTime),
    );
    if (time == null) return;
    setState(() {
      _incidentTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      setState(() {
        _attachments.add(File(xfile.path));
        _attachmentTypes.add('image/jpeg');
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _attachments.add(file);
        _attachmentTypes.add(result.files.single.extension == 'pdf'
            ? 'application/pdf'
            : 'text/plain');
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Step 1: Create case if new
      if (_isNewCase) {
        final caseResult = await ApiClient().createCase(
          title: _caseTitleController.text.trim().isNotEmpty
              ? _caseTitleController.text.trim()
              : 'Case ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
          category: _category,
        );
        _caseId = caseResult['case_id'];
      }

      // Step 2: Add incident
      final incidentResult = await ApiClient().addIncident(
        caseId: _caseId!,
        description: _descController.text.trim(),
        incidentTime: _incidentTime,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
      );

      final incidentId = incidentResult['incident_id'];

      // Step 3: Upload evidence
      for (int i = 0; i < _attachments.length; i++) {
        await ApiClient().uploadEvidence(
          incidentId: incidentId,
          file: _attachments[i],
          mimeType: _attachmentTypes[i],
        );
      }

      if (!mounted) return;

      // Show success
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Incident Logged'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Case ID: $_caseId',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 8),
              Text('Evidence files uploaded: ${_attachments.length}'),
              const SizedBox(height: 12),
              const Text(
                'Your incident has been stored securely. Nothing has been shared with anyone.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.alert),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // New or existing case
            if (_isNewCase) ...[
              _SectionLabel('Case Information'),
              TextFormField(
                controller: _caseTitleController,
                decoration: const InputDecoration(
                  labelText: 'Case Title (optional)',
                  hintText: 'e.g. "Workplace harassment by manager"',
                  prefixIcon: Icon(Icons.folder_open),
                ),
              ),
              const SizedBox(height: 16),

              // Category
              _SectionLabel('Category'),
              Wrap(
                spacing: 8,
                children: _categories.map((cat) => ChoiceChip(
                  label: Text('${cat['emoji']} ${cat['label']}'),
                  selected: _category == cat['value'],
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  onSelected: (_) => setState(() => _category = cat['value']!),
                )).toList(),
              ),

              const SizedBox(height: 20),
            ],

            // Incident details
            _SectionLabel('Incident Details'),

            // Date/Time
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date & Time of Incident',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          DateFormat('MMMM dd, yyyy — hh:mm a').format(_incidentTime),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Description
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'Describe the incident in your own words...',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  v == null || v.trim().length < 10 ? 'Please describe the incident (min 10 chars)' : null,
            ),

            const SizedBox(height: 14),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g. Office, City, Online platform...',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),

            const SizedBox(height: 24),

            // Evidence
            _SectionLabel('Evidence (optional)'),
            const Text(
              'All files are encrypted before upload. Only you can access them.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _EvidenceButton(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onTap: _pickImage,
                ),
                const SizedBox(width: 10),
                _EvidenceButton(
                  icon: Icons.attach_file,
                  label: 'File',
                  onTap: _pickFile,
                ),
              ],
            ),

            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._attachments.asMap().entries.map((entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file, color: AppColors.accent),
                title: Text(
                  entry.value.path.split('/').last,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.alert, size: 18),
                  onPressed: () {
                    setState(() {
                      _attachments.removeAt(entry.key);
                      _attachmentTypes.removeAt(entry.key);
                    });
                  },
                ),
              )),
            ],

            const SizedBox(height: 32),

            // Privacy reminder
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.success, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This report is private. Nothing is shared with authorities unless you choose to act.',
                      style: TextStyle(fontSize: 12, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log Incident Securely'),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _EvidenceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _EvidenceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
