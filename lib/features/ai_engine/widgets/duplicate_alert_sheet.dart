import 'package:flutter/material.dart';
import '../../../core/theme/evora_colors.dart';
import '../models/civic_ai_models.dart';

/// Action chosen by citizen when an active duplicate is detected within 500m.
enum DuplicateAlertResolution {
  /// Citizen supported/upvoted an existing nearby post or case and aborted duplicate filing.
  supportedExisting,

  /// Citizen confirmed this is a distinct issue and wants to proceed with submission.
  proceedAnyway,

  /// Dismissed sheet without action.
  cancelled,
}

class DuplicateAlertResult {
  final DuplicateAlertResolution resolution;
  final DuplicateCandidate? selectedCandidate;

  const DuplicateAlertResult({
    required this.resolution,
    this.selectedCandidate,
  });
}

/// Modal bottom sheet prompting citizens when EVORA's 500m geospatial + AI
/// embedding detector finds an existing similar grievance or observation nearby.
class DuplicateAlertSheet extends StatelessWidget {
  final List<DuplicateCandidate> candidates;
  final Future<void> Function(DuplicateCandidate candidate) onSupportCandidate;

  const DuplicateAlertSheet({
    super.key,
    required this.candidates,
    required this.onSupportCandidate,
  });

  static Future<DuplicateAlertResult> show(
    BuildContext context, {
    required List<DuplicateCandidate> candidates,
    required Future<void> Function(DuplicateCandidate candidate) onSupportCandidate,
  }) async {
    final result = await showModalBottomSheet<DuplicateAlertResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DuplicateAlertSheet(
        candidates: candidates,
        onSupportCandidate: onSupportCandidate,
      ),
    );
    return result ??
        const DuplicateAlertResult(resolution: DuplicateAlertResolution.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rawBottom = [
      media.padding.bottom,
      media.viewPadding.bottom,
      media.viewInsets.bottom,
    ].reduce((a, b) => a > b ? a : b);

    // Guaranteed clearance above navigation bar (whether 3-button nav or gesture pill).
    // On devices where the system reports 0 insets (e.g. Xiaomi MIUI / HyperOS 3-button nav),
    // default to 56.0dp so the button is completely above the ~48dp navigation icons.
    final bottomNavInset = rawBottom > 0 ? (rawBottom + 16.0) : 56.0;
    final maxHeight = media.size.height * 0.86;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomNavInset),
      decoration: const BoxDecoration(
        color: EvoraColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: EvoraColors.outlineVariant,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.layers_outlined, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Similar Issue Already Nearby',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Another resident already flagged a closely matching issue within 500 m. Upvote or follow it instead of splitting municipal priority.',
                      style: TextStyle(
                        fontSize: 12,
                        color: EvoraColors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length.clamp(0, 3),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final item = candidates[index];
                final isCase = item.sourceType == 'civic_flow_case';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: EvoraColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: EvoraColors.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCase
                                  ? EvoraColors.primary.withValues(alpha: 0.12)
                                  : Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              item.referenceLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isCase ? EvoraColors.primary : Colors.teal.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${item.matchPercent}% match • ${item.distanceMeters.round()} m',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.status,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: EvoraColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: EvoraColors.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.matchReason,
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: EvoraColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isCase ? Icons.add_alert_outlined : Icons.thumb_up_alt_outlined,
                            size: 16,
                          ),
                          label: Text(
                            isCase
                                ? 'Follow & Support Case (+1)'
                                : 'Upvote Existing Post Instead',
                          ),
                          onPressed: () async {
                            await onSupportCandidate(item);
                            if (ctx.mounted) {
                              Navigator.pop(
                                ctx,
                                DuplicateAlertResult(
                                  resolution: DuplicateAlertResolution.supportedExisting,
                                  selectedCandidate: item,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  const DuplicateAlertResult(
                    resolution: DuplicateAlertResolution.proceedAnyway,
                  ),
                );
              },
              child: const Text(
                'Submit Anyway — This Is a Separate Issue',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
