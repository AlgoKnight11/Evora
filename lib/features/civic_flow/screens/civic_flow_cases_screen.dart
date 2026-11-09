import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/evora_colors.dart';
import '../models/civic_flow_model.dart';
import '../services/civic_flow_service.dart';

class CivicFlowCasesScreen extends ConsumerStatefulWidget {
  const CivicFlowCasesScreen({super.key});

  @override
  ConsumerState<CivicFlowCasesScreen> createState() => _CivicFlowCasesScreenState();
}

class _CivicFlowCasesScreenState extends ConsumerState<CivicFlowCasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(civicFlowProvider);
    final notifier = ref.read(civicFlowProvider.notifier);

    final allCases = state.citizenCases;
    final activeCases = allCases.where((c) =>
        c.status != CivicFlowStatus.resolved && c.status != CivicFlowStatus.closed).toList();
    final resolvedCases = allCases.where((c) =>
        c.status == CivicFlowStatus.resolved || c.status == CivicFlowStatus.closed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: EvoraColors.primary, size: 22),
            SizedBox(width: 8),
            Text('CivicFlow Grievances'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Cases',
            onPressed: () => notifier.fetchCitizenCases(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: EvoraColors.primary,
          unselectedLabelColor: EvoraColors.onSurfaceVariant,
          indicatorColor: EvoraColors.primary,
          tabs: [
            Tab(text: 'All (${allCases.length})'),
            Tab(text: 'Active (${activeCases.length})'),
            Tab(text: 'Resolved (${resolvedCases.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildCaseList(context, allCases),
                  _buildCaseList(context, activeCases),
                  _buildCaseList(context, resolvedCases),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EvoraColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('File Grievance'),
        onPressed: () => context.push('/civic-flow/wizard'),
      ),
    );
  }

  Widget _buildCaseList(BuildContext context, List<CivicFlowCase> cases) {
    if (cases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 64, color: EvoraColors.outline),
              const SizedBox(height: 16),
              const Text(
                'No cases found in this view',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track and follow up on official municipal grievances filed across your ward.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('File First Case'),
                onPressed: () => context.push('/civic-flow/wizard'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: cases.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final c = cases[index];
        return _buildCaseCard(context, c);
      },
    );
  }

  Widget _buildCaseCard(BuildContext context, CivicFlowCase c) {
    final statusColor = _getStatusColor(c.status);
    final statusLabel = CivicFlowStatus.getLabel(c.status);

    return Container(
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/civic-flow/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Case ID & Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: EvoraColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      c.caseNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: EvoraColors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category & Subcategory
              Text(
                '${c.category} • ${c.subcategory}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),

              // Description snippet
              Text(
                c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 12),

              // Location & Assigned Department
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: EvoraColors.outline),
                  const SizedBox(width: 4),
                  Text(
                    c.locality,
                    style: const TextStyle(fontSize: 12, color: EvoraColors.outline),
                  ),
                  if (c.assignedDepartment != null) ...[
                    const Spacer(),
                    const Icon(Icons.business_outlined, size: 14, color: EvoraColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Assigned',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EvoraColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case CivicFlowStatus.submitted:
        return Colors.blueGrey;
      case CivicFlowStatus.underTriage:
        return Colors.blue;
      case CivicFlowStatus.needsInfo:
        return Colors.orange;
      case CivicFlowStatus.verified:
        return Colors.teal;
      case CivicFlowStatus.assigned:
      case CivicFlowStatus.inProgress:
        return EvoraColors.tertiary; // Himalayan Terracotta
      case CivicFlowStatus.resolvedPending:
      case CivicFlowStatus.resolved:
      case CivicFlowStatus.closed:
        return EvoraColors.primary; // Mountain Emerald
      default:
        return Colors.grey;
    }
  }
}
