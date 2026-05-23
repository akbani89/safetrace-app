import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../core/theme.dart';
import '../core/api_client.dart';

class TakeActionScreen extends StatefulWidget {
  const TakeActionScreen({super.key});

  @override
  State<TakeActionScreen> createState() => _TakeActionScreenState();
}

class _TakeActionScreenState extends State<TakeActionScreen> {
  // Step 1: case list
  List<dynamic> _cases = [];
  bool _isLoadingCases = true;

  // Step flow
  int _step = 0; // 0=select case, 1=select action, 2=review, 3=consent, 4=output

  String? _selectedCaseId;
  Map<String, dynamic>? _actionOptions;
  Map<String, dynamic>? _selectedAction;
  Map<String, dynamic>? _timeline;
  bool _consentChecked = false;
  bool _includeIdentity = false;
  bool _isGenerating = false;
  Map<String, dynamic>? _generatedDoc;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final cases = await ApiClient().getCases();
      setState(() {
        _cases = cases;
        _isLoadingCases = false;
      });
    } catch (_) {
      setState(() => _isLoadingCases = false);
    }
  }

  Future<void> _selectCase(String caseId) async {
    setState(() { _selectedCaseId = caseId; _isLoadingCases = true; });
    try {
      final options = await ApiClient().getActionOptions(caseId);
      final timeline = await ApiClient().getTimeline(caseId);
      setState(() {
        _actionOptions = options;
        _timeline = timeline;
        _step = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.alert),
      );
    } finally {
      setState(() => _isLoadingCases = false);
    }
  }

  Future<void> _generateDocument() async {
    if (!_consentChecked || _selectedAction == null) return;
    setState(() => _isGenerating = true);
    try {
      final doc = await ApiClient().generateDocument(
        caseId: _selectedCaseId!,
        destination: _selectedAction!['destination'],
        consentConfirmed: true,
        includeIdentity: _includeIdentity,
      );
      setState(() {
        _generatedDoc = doc;
        _step = 4;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating document: $e'), backgroundColor: AppColors.alert),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_generatedDoc?['pdf_base64'] == null) return;
    try {
      final bytes = base64Decode(_generatedDoc!['pdf_base64']);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'SafeTrace_${_selectedCaseId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e')),
      );
    }
  }

  void _reset() {
    setState(() {
      _step = 0;
      _selectedCaseId = null;
      _actionOptions = null;
      _selectedAction = null;
      _timeline = null;
      _consentChecked = false;
      _includeIdentity = false;
      _generatedDoc = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Action'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _step > 0 ? _step - 1 : 0),
              )
            : null,
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(currentStep: _step),

          Expanded(
            child: _isLoadingCases
                ? const Center(child: CircularProgressIndicator())
                : _buildStepContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _Step1SelectCase(cases: _cases, onSelect: _selectCase),
      1 => _Step2SelectAction(
          options: _actionOptions!,
          timeline: _timeline!,
          onSelect: (action) => setState(() {
            _selectedAction = action;
            _step = 2;
          }),
        ),
      2 => _Step3Review(
          timeline: _timeline!,
          selectedAction: _selectedAction!,
          onContinue: () => setState(() => _step = 3),
        ),
      3 => _Step4Consent(
          selectedAction: _selectedAction!,
          consentChecked: _consentChecked,
          includeIdentity: _includeIdentity,
          isGenerating: _isGenerating,
          onConsentChanged: (v) => setState(() => _consentChecked = v),
          onIdentityChanged: (v) => setState(() => _includeIdentity = v),
          onGenerate: _generateDocument,
        ),
      4 => _Step5Output(
          doc: _generatedDoc!,
          onDownload: _downloadPdf,
          onReset: _reset,
        ),
      _ => const SizedBox(),
    };
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = ['Select Case', 'Action', 'Review', 'Consent', 'Done'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.success
                              : isActive
                                  ? AppColors.primary
                                  : AppColors.divider,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : AppColors.textHint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 9,
                          color: isActive ? AppColors.primary : AppColors.textHint,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (i < _labels.length - 1)
                  Container(
                    width: 16, height: 1,
                    color: isDone ? AppColors.success : AppColors.divider,
                    margin: const EdgeInsets.only(bottom: 14),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step 1: Select Case ──────────────────────────────────────────────────────

class _Step1SelectCase extends StatelessWidget {
  final List<dynamic> cases;
  final Function(String) onSelect;

  const _Step1SelectCase({required this.cases, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 56, color: AppColors.textHint),
            SizedBox(height: 16),
            Text('No cases found.\nLog an incident first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Which case do you want to act on?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Select a case to begin the action flow.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        ...cases.map((c) => GestureDetector(
          onTap: () => onSelect(c['case_id']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['title'] ?? 'Unnamed Case',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${c['incident_count']} incident${c['incident_count'] != 1 ? 's' : ''} • ${c['category']?.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

// ─── Step 2: Select Action ────────────────────────────────────────────────────

class _Step2SelectAction extends StatelessWidget {
  final Map<String, dynamic> options;
  final Map<String, dynamic> timeline;
  final Function(Map<String, dynamic>) onSelect;

  const _Step2SelectAction({
    required this.options,
    required this.timeline,
    required this.onSelect,
  });

  IconData _iconFor(String dest) => switch (dest) {
    'police' => Icons.local_police_outlined,
    'ombudsman' => Icons.business_outlined,
    'legal_support' => Icons.balance_outlined,
    _ => Icons.send_outlined,
  };

  Color _colorFor(String dest) => switch (dest) {
    'police' => AppColors.alert,
    'ombudsman' => AppColors.warning,
    'legal_support' => AppColors.primary,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final actions = (options['available_actions'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('What do you want to do?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(options['consent_reminder'] ?? '',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ...actions.map((action) {
          final dest = action['destination'] as String;
          return GestureDetector(
            onTap: () => onSelect(action),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _colorFor(dest).withOpacity(0.3)),
                boxShadow: [BoxShadow(
                  color: _colorFor(dest).withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _colorFor(dest).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconFor(dest), color: _colorFor(dest), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action['label'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(action['description'],
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.share_outlined, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Shares: ${action['data_shared']}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textHint),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Step 3: Review ───────────────────────────────────────────────────────────

class _Step3Review extends StatelessWidget {
  final Map<String, dynamic> timeline;
  final Map<String, dynamic> selectedAction;
  final VoidCallback onContinue;

  const _Step3Review({
    required this.timeline,
    required this.selectedAction,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Review Your Case',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const Text('This is what will be included in your document.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),

        _ReviewCard(
          title: 'Case',
          items: [
            ['Title', timeline['title']],
            ['Category', (timeline['category'] as String).toUpperCase()],
            ['Total Incidents', '${timeline['total_incidents']}'],
            ['Total Evidence Files', '${timeline['total_evidence']}'],
          ],
        ),

        const SizedBox(height: 12),

        _ReviewCard(
          title: 'Destination',
          items: [
            ['Sending To', selectedAction['label']],
            ['Document Type', selectedAction['description']],
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nothing has been submitted yet. You will confirm on the next screen.',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onContinue,
            child: const Text('Continue to Consent'),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<List<String>> items;

  const _ReviewCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                    letterSpacing: 0.5)),
          ),
          const Divider(height: 1),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(item[0],
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: Text(item[1],
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Step 4: Consent ──────────────────────────────────────────────────────────

class _Step4Consent extends StatelessWidget {
  final Map<String, dynamic> selectedAction;
  final bool consentChecked;
  final bool includeIdentity;
  final bool isGenerating;
  final Function(bool) onConsentChanged;
  final Function(bool) onIdentityChanged;
  final VoidCallback onGenerate;

  const _Step4Consent({
    required this.selectedAction,
    required this.consentChecked,
    required this.includeIdentity,
    required this.isGenerating,
    required this.onConsentChanged,
    required this.onIdentityChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.alert.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.alert.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, color: AppColors.alert),
                  SizedBox(width: 8),
                  Text('Consent Required',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.alert)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Before generating this document, please confirm you understand:',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              ...[
                'Your case data will be formatted into a document.',
                'The document will NOT be submitted automatically.',
                'You will download the document and decide what to do with it.',
                'SafeTrace does not send anything to any authority on your behalf.',
              ].map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Identity option
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Identity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Do you want to include your identity in this document?',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: includeIdentity,
                    onChanged: onIdentityChanged,
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    includeIdentity
                        ? 'Include my identity (if attached)'
                        : 'Stay anonymous in document',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Final consent checkbox
        GestureDetector(
          onTap: () => onConsentChanged(!consentChecked),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: consentChecked
                  ? AppColors.success.withOpacity(0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: consentChecked ? AppColors.success : AppColors.divider,
                width: consentChecked ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  consentChecked
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: consentChecked ? AppColors.success : AppColors.textHint,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'I understand and consent to generating this document. '
                    'I know it will not be submitted automatically.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (consentChecked && !isGenerating) ? onGenerate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: consentChecked ? AppColors.primary : AppColors.divider,
            ),
            child: isGenerating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Generating Document...'),
                    ],
                  )
                : const Text('Generate Document'),
          ),
        ),
      ],
    );
  }
}

// ─── Step 5: Output ───────────────────────────────────────────────────────────

class _Step5Output extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDownload;
  final VoidCallback onReset;

  const _Step5Output({
    required this.doc,
    required this.onDownload,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Success header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 56),
              const SizedBox(height: 12),
              const Text('Document Generated',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
              const SizedBox(height: 6),
              Text(
                doc['document_type'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // What's next
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What Happens Next',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              ...[
                '✅ The document is on your device only.',
                '✅ Nothing has been sent to any authority.',
                '✅ You decide when and how to submit it.',
                '✅ You can show it to a lawyer before submitting.',
              ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t, style: const TextStyle(fontSize: 13, height: 1.4)),
              )),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Actions
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Open / Download PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate Another Document'),
          ),
        ),
      ],
    );
  }
}
