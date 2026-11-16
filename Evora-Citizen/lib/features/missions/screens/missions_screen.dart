import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/evora_colors.dart';
import '../models/mission_model.dart';
import '../services/missions_service.dart';

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  String _statusFilter = 'all'; // 'all', 'joined', 'completed'

  @override
  Widget build(BuildContext context) {
    final missionsState = ref.watch(missionsProvider);
    final missions = missionsState.filteredMissions;
    final participations = missionsState.userParticipations;

    final displayedMissions = missions.where((m) {
      final p = participations[m.id];
      if (_statusFilter == 'joined') {
        return p != null && p.status != MissionParticipationStatus.verified;
      }
      if (_statusFilter == 'completed') {
        return p != null && p.status == MissionParticipationStatus.verified;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Eco Missions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Impact Profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Category Filter Chips (Horizontal Scroll)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('All Categories'),
                    selected: missionsState.selectedCategory == null,
                    onSelected: (_) =>
                        ref.read(missionsProvider.notifier).setCategoryFilter(null),
                  ),
                  const SizedBox(width: 8),
                  ...MissionCategory.values.map((cat) {
                    final isSelected = missionsState.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                        label: Text(cat.label),
                        selected: isSelected,
                        selectedColor: cat.color,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : EvoraColors.onSurface,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        onSelected: (_) =>
                            ref.read(missionsProvider.notifier).setCategoryFilter(cat),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 2. Status Segment Tabs (All, My Active, Completed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'all',
                    label: Text('Explore All'),
                    icon: Icon(Icons.explore_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'joined',
                    label: Text('In Progress'),
                    icon: Icon(Icons.pending_actions_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'completed',
                    label: Text('Completed'),
                    icon: Icon(Icons.check_circle_outline, size: 16),
                  ),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (val) {
                  setState(() => _statusFilter = val.first);
                },
              ),
            ),

            // 3. Missions List
            Expanded(
              child: displayedMissions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.nature_people_outlined, size: 56, color: EvoraColors.outline),
                            const SizedBox(height: 16),
                            const Text(
                              'No missions found in this filter',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try selecting another category or explore active community campaigns in Dehradun.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EvoraColors.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        math.max(
                          MediaQuery.of(context).padding.bottom,
                          MediaQuery.of(context).viewPadding.bottom,
                        ) + 24,
                      ),
                      itemCount: displayedMissions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final mission = displayedMissions[index];
                        final participation = participations[mission.id];
                        return _buildMissionCard(context, mission, participation);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(
    BuildContext context,
    EcoMission mission,
    MissionParticipation? participation,
  ) {
    final status = participation?.status ?? MissionParticipationStatus.available;
    final isCompleted = status == MissionParticipationStatus.verified;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCompleted
              ? EvoraColors.primary.withValues(alpha: 0.5)
              : EvoraColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: EvoraColors.surfaceContainerLowest,
      child: InkWell(
        onTap: () => context.push('/missions/${mission.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Category Chip & Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: mission.category.color.withValues(alpha: 0.12),
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
                            fontSize: 11,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                mission.title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),

              // Locality & Time Commitment
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: EvoraColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mission.locality,
                      style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time, size: 14, color: EvoraColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    mission.timeCommitment,
                    style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reward Banner & SDG Chips
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: EvoraColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco, size: 14, color: EvoraColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '+${mission.ecoCoinsReward} EcoCoins',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: EvoraColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...mission.sdgs.map((sdg) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SDG $sdg',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      )),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: EvoraColors.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
