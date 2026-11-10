import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/evora_colors.dart';
import '../models/civic_flow_model.dart';
import '../services/civic_flow_service.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  final _infoResponseController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _isActionLoading = false;

  @override
  void dispose() {
    _infoResponseController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(civicFlowProvider);
    final caseIndex = state.citizenCases.indexWhere((c) => c.id == widget.caseId);

    if (caseIndex == -1) {
      if (state.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Grievance Details')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Grievance Details')),
        body: const Center(child: Text('Case record not found.')),
      );
    }

    final c = state.citizenCases[caseIndex];
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(c.caseNumber),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.caseNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: EvoraColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: EvoraColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            CivicFlowStatus.getLabel(c.status),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: EvoraColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${c.category} — ${c.subcategory}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.description,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: EvoraColors.outline),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.landmark != null ? '${c.locality} (${c.landmark})' : c.locality,
                            style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (c.assignedDepartment != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_outlined, size: 16, color: EvoraColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              c.assignedDepartment!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EvoraColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (c.assignedOfficer != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_outlined, size: 16, color: EvoraColors.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Officer: ${c.assignedOfficer}',
                              style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Attached Photo if exists
              if (c.imageUrl != null) ...[
                const SizedBox(height: 20),
                const Text('Ground Evidence Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    c.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              // Interactive Action: Needs Information Response
              if (c.status == CivicFlowStatus.needsInfo) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Action Required: Clarification Needed',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.officerNotes ?? 'The assigned officer has requested additional details regarding the exact landmark.',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _infoResponseController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your response...',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isActionLoading
                            ? null
                            : () async {
                                final text = _infoResponseController.text.trim();
                                if (text.isEmpty) return;
                                setState(() => _isActionLoading = true);
                                final ok = await ref
                                    .read(civicFlowProvider.notifier)
                                    .respondToNeedsInfo(c.id, text);
                                if (!mounted) return;
                                setState(() => _isActionLoading = false);
                                if (ok) {
                                  _infoResponseController.clear();
                                  if (context.mounted) {
                                    FocusScope.of(context).unfocus();
                                  }
                                }
                              },
                        child: _isActionLoading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Response to Officer'),
                      ),
                    ],
                  ),
                ),
              ],

              // Interactive Action: Verify Resolution (Pending Review)
              if (c.status == CivicFlowStatus.resolvedPending) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: EvoraColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EvoraColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Officer Marked Work Completed',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: EvoraColors.primary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please verify if the issue was satisfactorily resolved on the ground.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Confirm Resolved'),
                              onPressed: () async {
                                await ref.read(civicFlowProvider.notifier).verifyResolution(c.id, isSatisfied: true);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            child: const Text('Reopen Case'),
                            onPressed: () async {
                              await ref.read(civicFlowProvider.notifier).verifyResolution(c.id, isSatisfied: false, feedback: 'Issue persists on site.');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Official 10-Stage Status Stepper Timeline
              const Text(
                'Official Action Timeline',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: c.timeline.length,
                itemBuilder: (context, index) {
                  final event = c.timeline[index];
                  final isLast = index == c.timeline.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline track indicator
                        Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isLast ? EvoraColors.primary : EvoraColors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: EvoraColors.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Timeline Details
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      event.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isLast ? EvoraColors.primary : EvoraColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      event.actor,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: EvoraColors.outline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateFormat.format(event.timestamp),
                                  style: const TextStyle(fontSize: 11, color: EvoraColors.outline),
                                ),
                                if (event.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    event.description,
                                    style: const TextStyle(fontSize: 13, height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
