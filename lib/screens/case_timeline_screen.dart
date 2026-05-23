import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import 'report_incident_screen.dart';

class CaseTimelineScreen extends StatefulWidget {
  final String caseId;
  const CaseTimelineScreen({super.key, required this.caseId});

  @override
  State<CaseTimelineScreen> createState() => _CaseTimelineScreenState();
}

class _CaseTimelineScreenState extends State<CaseTimelineScreen> {
  Map<String, dynamic>? _timeline;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient().getTimeline(widget.caseId);
      setState(() => _timeline = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_timeline?['title'] ?? 'Case Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add incident',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportIncidentScreen(
                existingCaseId: widget.caseId,
              )),
            ).then((_) => _loadTimeline()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timeline == null
              ? const Center(child: Text('Could not load timeline.'))
              : RefreshIndicator(
                  onRefresh: _loadTimeline,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Case summary card
                      _CaseSummaryCard(timeline: _timeline!),
                      const SizedBox(height: 20),

                      // Timeline header
                      const Text(
                        'INCIDENT TIMELINE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Incidents
                      if ((_timeline!['timeline'] as List).isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No incidents yet. Tap + to add one.',
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ),
                        )
                      else
                        ...(_timeline!['timeline'] as List).asMap().entries.map(
                          (entry) => _TimelineItem(
                            incident: entry.value,
                            isFirst: entry.key == 0,
                            isLast: entry.key == (_timeline!['timeline'] as List).length - 1,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _CaseSummaryCard extends StatelessWidget {
  final Map<String, dynamic> timeline;
  const _CaseSummaryCard({required this.timeline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                timeline['case_id'],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeline['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip(
                label: '${timeline['total_incidents']} incidents',
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: '${timeline['total_evidence']} files',
                icon: Icons.attach_file,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: (timeline['category'] as String).toUpperCase(),
                icon: Icons.label_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SummaryChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> incident;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.incident,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(incident['incident_time'] ?? '');
    final evidenceCount = incident['evidence_count'] ?? 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visual
          Column(
            children: [
              if (!isFirst)
                Container(width: 2, height: 12, color: AppColors.divider),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.alert,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(
                    color: AppColors.alert.withOpacity(0.3),
                    blurRadius: 4,
                  )],
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.divider)),
            ],
          ),

          const SizedBox(width: 12),

          // Incident card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                )],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (time != null)
                    Text(
                      DateFormat('MMMM dd, yyyy — hh:mm a').format(time),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    incident['description'] ?? '',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  if (incident['location'] != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          incident['location'],
                          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ],
                  if (evidenceCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.attach_file, size: 13, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          '$evidenceCount file${evidenceCount != 1 ? 's' : ''} attached',
                          style: const TextStyle(fontSize: 12, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
