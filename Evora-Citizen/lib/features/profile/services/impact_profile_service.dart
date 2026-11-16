import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../civic_flow/services/civic_flow_service.dart';
import '../../ledger/services/eco_ledger_service.dart';
import '../../missions/models/mission_model.dart';
import '../../missions/services/missions_service.dart';
import '../models/impact_profile_model.dart';

/// Provider deriving real cumulative environmental impact metrics for the active citizen
final citizenImpactProvider = Provider<CitizenImpactSummary>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) {
    return CitizenImpactSummary.empty('guest');
  }

  // 1. Eco Coin ledger state
  final ledgerState = ref.watch(ecoLedgerProvider);
  final totalCoins = ledgerState.currentBalance;

  // 2. Missions state
  final missionsState = ref.watch(missionsProvider);
  final allMissions = missionsState.missions;
  final participations = missionsState.userParticipations;

  // 3. CivicFlow state
  final civicFlowState = ref.watch(civicFlowProvider);
  final myCases = civicFlowState.citizenCases.where((c) => c.citizenId == user.uid).toList();
  final resolvedCases = myCases.where((c) => c.status.toLowerCase() == 'resolved').length;

  int completedMissionsCount = 0;
  double co2AvoidedTotal = 0.0;
  double wasteDivertedTotal = 0.0;
  double waterSavedTotal = 0.0;
  int treesSupportedTotal = 0;

  final sdgMetrics = <int, double>{
    6: 0.0, // Water
    11: resolvedCases.toDouble(), // Cities & Hazards
    12: 0.0, // Consumption & Waste
    13: 0.0, // Climate Action CO2e
    15: 0.0, // Life on Land & Trees
  };

  final earnedBadges = <String>{'Citizen Onboarded'};

  // Calculate contributions from verified completed missions
  for (final mission in allMissions) {
    final p = participations[mission.id];
    if (p != null && p.status == MissionParticipationStatus.verified) {
      completedMissionsCount++;
      co2AvoidedTotal += mission.co2AvoidedKg;
      wasteDivertedTotal += mission.wasteDivertedKg;
      waterSavedTotal += mission.waterSavedLiters;
      treesSupportedTotal += mission.treesSupported;

      earnedBadges.add(mission.badgeName);

      // Attribute to respective SDGs
      for (final sdg in mission.sdgs) {
        if (sdg == 6) sdgMetrics[6] = (sdgMetrics[6] ?? 0.0) + mission.waterSavedLiters;
        if (sdg == 11) sdgMetrics[11] = (sdgMetrics[11] ?? 0.0) + 1.0;
        if (sdg == 12) sdgMetrics[12] = (sdgMetrics[12] ?? 0.0) + mission.wasteDivertedKg;
        if (sdg == 13) sdgMetrics[13] = (sdgMetrics[13] ?? 0.0) + mission.co2AvoidedKg;
        if (sdg == 15) sdgMetrics[15] = (sdgMetrics[15] ?? 0.0) + mission.treesSupported.toDouble();
      }
    }
  }

  // Civic badges
  if (myCases.isNotEmpty) earnedBadges.add('Civic Reporter');
  if (resolvedCases >= 2) earnedBadges.add('Valley Custodian');
  if (totalCoins >= 100) earnedBadges.add('Eco Contributor');
  if (totalCoins >= 300) earnedBadges.add('Himalayan Steward');

  return CitizenImpactSummary(
    userId: user.uid,
    totalEcoCoins: totalCoins,
    missionsCompleted: completedMissionsCount,
    civicCasesResolved: resolvedCases,
    observationsPosted: myCases.length,
    co2AvoidedKg: co2AvoidedTotal,
    wasteDivertedKg: wasteDivertedTotal,
    waterSavedLiters: waterSavedTotal,
    treesSupported: treesSupportedTotal,
    sdgMetrics: sdgMetrics,
    earnedBadgeNames: earnedBadges.toList(),
  );
});
