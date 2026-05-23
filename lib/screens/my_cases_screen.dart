import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import 'report_incident_screen.dart';
import 'case_timeline_screen.dart';

class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({super.key});

  @override
  State<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  List<dynamic> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    try {
      final cases = await ApiClient().getCases();
      setState(() => _cases = cases);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cases: $e')),
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
        title: const Text('My Cases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCases,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ReportIncidentScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Incident'),
        backgroundColor: AppColors.alert,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cases.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCases,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CaseCard(
                      caseData: _cases[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CaseTimelineScreen(
                            caseId: _cases[i]['case_id'],
                          ),
                        ),
                      ).then((_) => _loadCases()),
                    ),
                  ),
                ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final VoidCallback onTap;

  const _CaseCard({required this.caseData, required this.onTap});

  Color _categoryColor(String cat) {
    return switch (cat) {
      'workplace' => AppColors.warning,
      'public' => AppColors.alert,
      'online' => AppColors.primaryLight,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final category = caseData['category'] ?? 'unknown';
    final status = caseData['status'] ?? 'active';
    final incidentCount = caseData['incident_count'] ?? 0;
    final createdAt = DateTime.tryParse(caseData['created_at'] ?? '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    caseData['title'] ?? 'Unnamed Case',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _categoryColor(category).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _categoryColor(category),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Case ID: ${caseData['case_id']}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  icon: Icons.warning_amber_outlined,
                  label: '$incidentCount incident${incidentCount != 1 ? 's' : ''}',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.circle,
                  label: status,
                  color: status == 'active' ? AppColors.success : AppColors.textSecondary,
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    DateFormat('MMM dd, yyyy').format(createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No Cases Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'When you log an incident, your cases appear here.',
            style: TextStyle(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
