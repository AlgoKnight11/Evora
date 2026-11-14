import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../services/device_permission_service.dart';
import '../../profile/models/impact_profile_model.dart';
import '../models/mission_model.dart';
import '../services/missions_service.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  final String missionId;

  const MissionDetailScreen({super.key, required this.missionId});

  @override
  ConsumerState<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  bool _isProcessing = false;

  void _showProofSubmissionSheet(EcoMission mission) {
    File? selectedProofFile;
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final media = MediaQuery.of(sheetCtx);
            final rawBottom = [
              media.padding.bottom,
              media.viewPadding.bottom,
              media.viewInsets.bottom,
            ].reduce((a, b) => a > b ? a : b);
            final bottomInset = rawBottom > 0 ? (rawBottom + 16.0) : 56.0;

            Future<void> pickImage(ImageSource source) async {
              final granted = source == ImageSource.camera
                  ? await DevicePermissionService.ensureCameraPermission()
                  : await DevicePermissionService.ensureGalleryPermission();

              if (!granted) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${source == ImageSource.camera ? "Camera" : "Gallery"} access is required to attach proof.'),
                      backgroundColor: EvoraColors.error,
                    ),
                  );
                }
                return;
              }

              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1280,
                  maxHeight: 1280,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setSheetState(() => selectedProofFile = File(picked.path));
                }
              } catch (e) {
                debugPrint('Image picker error: $e');
              }
            }

            return Container(
              padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset),
              decoration: const BoxDecoration(
                color: EvoraColors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 18),
                    const Text(
                      'Submit Verification Proof',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.requiredProofDescription,
                      style: const TextStyle(fontSize: 12.5, color: EvoraColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),

                    // Proof preview or Pick buttons
                    if (selectedProofFile != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              selectedProofFile!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                onPressed: () => setSheetState(() => selectedProofFile = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Take Photo'),
                              onPressed: () => pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('From Gallery'),
                              onPressed: () => pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Citizen Notes / Location Details (Optional)',
                        hintText: 'e.g. Cleared 2 bags near Rispana Pul, handed over to tipper #04',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EvoraColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                setState(() => _isProcessing = true);
                                try {
                                  await ref
                                      .read(missionsProvider.notifier)
                                      .submitMissionProof(
                                        missionId: mission.id,
                                        proofImageFile: selectedProofFile,
                                        proofNotes: notesController.text.trim(),
                                      );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Proof submitted successfully! It is now under verification.'),
                                        backgroundColor: EvoraColors.primary,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Submission failed: $e'),
                                        backgroundColor: EvoraColors.error,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isProcessing = false);
                                }
                              },
                        child: const Text(
                          'Upload Proof & Submit',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final missionsState = ref.watch(missionsProvider);
    final mission = missionsState.missions.firstWhere(
      (m) => m.id == widget.missionId,
      orElse: () => MissionsNotifier.seedMissions.first,
    );
    final participation = missionsState.userParticipations[mission.id];
    final status = participation?.status ?? MissionParticipationStatus.available;
    final isCompleted = status == MissionParticipationStatus.verified;
    final isSubmitted = status == MissionParticipationStatus.submitted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          mission.badgeName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Mission',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Shared mission: ${mission.title}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Mission Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: mission.category.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(mission.category.icon, size: 14, color: mission.category.color),
                              const SizedBox(width: 5),
                              Text(
                                mission.category.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: mission.category.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: status.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mission.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mission.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: EvoraColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Quick metadata row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetaItem(Icons.location_on_outlined, 'Location', mission.locality),
                        _buildMetaItem(Icons.timer_outlined, 'Commitment', mission.timeCommitment),
                        _buildMetaItem(Icons.people_outline, 'Participants',
                            '${mission.participantsCount}/${mission.maxParticipants}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. EcoCoins Reward Banner & Non-Monetary Disclaimer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EvoraColors.primary.withValues(alpha: 0.14),
                      Colors.teal.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EvoraColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: EvoraColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${mission.ecoCoinsReward} EcoCoins Reward',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: EvoraColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Civic recognition points credited upon proof verification. Strict non-monetary compliance.',
                            style: TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Environmental Impact & UN SDG Alignment
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Environmental Impact',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (mission.co2AvoidedKg > 0)
                          Expanded(
                            child: _buildImpactMetric(
                              Icons.cloud_outlined,
                              '${mission.co2AvoidedKg.toStringAsFixed(0)} kg',
                              'CO₂e Avoided',
                            ),
                          ),
                        if (mission.wasteDivertedKg > 0)
                          Expanded(
                            child: _buildImpactMetric(
                              Icons.delete_sweep_outlined,
                              '${mission.wasteDivertedKg.toStringAsFixed(0)} kg',
                              'Waste Diverted',
                            ),
                          ),
                        if (mission.waterSavedLiters > 0)
                          Expanded(
                            child: _buildImpactMetric(
                              Icons.water_drop_outlined,
                              '${mission.waterSavedLiters.toStringAsFixed(0)} L',
                              'Water Protected',
                            ),
                          ),
                        if (mission.treesSupported > 0)
                          Expanded(
                            child: _buildImpactMetric(
                              Icons.park_outlined,
                              '${mission.treesSupported}',
                              'Trees Adopted',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'UN Sustainable Development Goals:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mission.sdgs.map((sdgNum) {
                        final sdg = SdgInfo.registry[sdgNum];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (sdg?.color ?? Colors.blueGrey).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: (sdg?.color ?? Colors.blueGrey).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sdg?.icon ?? Icons.eco,
                                  size: 14, color: sdg?.color ?? Colors.blueGrey),
                              const SizedBox(width: 5),
                              Text(
                                'SDG $sdgNum • ${sdg?.title ?? ""}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sdg?.color ?? Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Instructions Card
              _buildSectionCard(
                title: 'Instructions for Citizens',
                icon: Icons.format_list_numbered_outlined,
                items: mission.instructions,
              ),
              const SizedBox(height: 14),

              // 5. Safety Guidelines Card
              _buildSectionCard(
                title: 'Safety Guidelines & Protocols',
                icon: Icons.shield_outlined,
                items: mission.safetyGuidelines,
              ),
              const SizedBox(height: 14),

              // 6. Verification Status Card if Completed or Under Review
              if (isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mission Completed & Verified!',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${participation?.coinsCredited ?? mission.ecoCoinsReward} EcoCoins credited to your immutable ledger.',
                              style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/ledger'),
                        child: const Text('View Ledger'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (isSubmitted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hourglass_top, color: Colors.orange, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Proof Under Community Verification',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your submission proof is being verified. Once approved, EcoCoins are credited automatically.',
                        style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      // Test helper for instant automated verification during testing
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text('Simulate Community Verification (Test Mode)'),
                          onPressed: () async {
                            setState(() => _isProcessing = true);
                            final scaffold = ScaffoldMessenger.of(context);
                            try {
                              await ref
                                  .read(missionsProvider.notifier)
                                  .verifyAndRewardMission(missionId: mission.id);
                              if (!mounted) return;
                              scaffold.showSnackBar(
                                const SnackBar(
                                  content: Text('Mission approved! +Coins credited to your ledger.'),
                                  backgroundColor: EvoraColors.primary,
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _isProcessing = false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),

      // Bottom Floating Action Button
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EvoraColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: EvoraColors.outlineVariant.withValues(alpha: 0.4))),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: _buildActionButton(mission, participation),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(EcoMission mission, MissionParticipation? participation) {
    if (participation == null) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: EvoraColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isProcessing
            ? null
            : () async {
                final allowed = await AuthGuard.requireLogin(
                  context,
                  ref,
                  actionDescription: 'Sign in to join community eco missions.',
                );
                if (!allowed) return;

                setState(() => _isProcessing = true);
                try {
                  await ref.read(missionsProvider.notifier).joinMission(mission.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Joined mission: ${mission.title}!'),
                        backgroundColor: EvoraColors.primary,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
        child: const Text('Join This Campaign Mission', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );
    }

    if (participation.status == MissionParticipationStatus.joined ||
        participation.status == MissionParticipationStatus.inProgress) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Submit Verification Proof', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _showProofSubmissionSheet(mission),
      );
    }

    if (participation.status == MissionParticipationStatus.submitted) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.schedule),
        label: const Text('Under Review — Awaiting Audit'),
        onPressed: null,
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.check_circle, color: EvoraColors.primary),
      label: const Text('Mission Completed (+EcoCoins Credited)'),
      onPressed: () => context.push('/ledger'),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: EvoraColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildImpactMetric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: EvoraColors.primary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: EvoraColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: EvoraColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: EvoraColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$idx',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: EvoraColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EvoraColors.onSurface,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
