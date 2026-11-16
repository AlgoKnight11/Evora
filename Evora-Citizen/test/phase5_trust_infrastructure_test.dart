import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evora/features/auth/models/user_model.dart';
import 'package:evora/features/auth/services/auth_service.dart';
import 'package:evora/features/ledger/models/eco_ledger_model.dart';
import 'package:evora/features/ledger/services/eco_ledger_service.dart';
import 'package:evora/features/missions/models/mission_model.dart';
import 'package:evora/features/missions/services/missions_service.dart';
import 'package:evora/features/profile/models/impact_profile_model.dart';
import 'package:evora/features/profile/services/impact_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5: Trust Infrastructure — Eco Missions Lifecycle Tests', () {
    test('Test 5.1: Complete mission lifecycle (Browse -> Join -> Submit Proof -> Verified Reward)', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(
                EvoraUser(
                  uid: 'test_citizen_001',
                  displayName: 'Aarav Sharma',
                  email: 'aarav@evora.org',
                  tenantId: 'tenant_dehradun_01',
                  selectedLocality: 'Dalanwala',
                  createdAt: DateTime(2026, 11, 1),
                ),
              )),
        ],
      );

      final notifier = container.read(missionsProvider.notifier);

      // 1. Initial State: Seed missions available
      final initialMissions = container.read(missionsProvider).missions;
      expect(initialMissions.length, greaterThanOrEqualTo(6));
      final rispanaMission = initialMissions.firstWhere((m) => m.id == 'mission_rispana_cleanup');
      expect(rispanaMission.ecoCoinsReward, 120);

      // 2. Citizen Joins Mission
      final joinedParticipation = await notifier.joinMission('mission_rispana_cleanup');
      expect(joinedParticipation.status, MissionParticipationStatus.joined);
      expect(joinedParticipation.missionId, 'mission_rispana_cleanup');
      expect(joinedParticipation.userId, 'test_citizen_001');

      // 3. Citizen Submits Verification Proof
      // Create a temporary dummy proof file
      final tempDir = Directory.systemTemp.createTempSync('proof_test');
      final dummyProof = File('${tempDir.path}/proof.jpg')..writeAsBytesSync([1, 2, 3, 4]);

      final submittedParticipation = await notifier.submitMissionProof(
        missionId: 'mission_rispana_cleanup',
        proofImageFile: dummyProof,
        proofNotes: 'Cleared 2 sacks of plastic near Rispana Pul, handed to NNND tipper.',
      );
      expect(submittedParticipation.status, MissionParticipationStatus.submitted);
      expect(submittedParticipation.isUnderReview, isTrue);
      expect(submittedParticipation.proofNotes, contains('Rispana Pul'));

      // 4. Audit Verification & EcoCoins Reward Issuance
      final verifiedParticipation = await notifier.verifyAndRewardMission(
        missionId: 'mission_rispana_cleanup',
        approved: true,
        feedback: 'Verified by Dehradun Municipal Auditor. Valid photo proof.',
      );

      expect(verifiedParticipation.status, MissionParticipationStatus.verified);
      expect(verifiedParticipation.isCompleted, isTrue);
      expect(verifiedParticipation.coinsCredited, 120);

      // 5. Confirm EcoLedger reflects the appended credit
      final ledgerState = container.read(ecoLedgerProvider);
      expect(ledgerState.currentBalance, 120);
      expect(ledgerState.transactions.length, 1);
      final tx = ledgerState.transactions.first;
      expect(tx.amount, 120);
      expect(tx.referenceId, 'mission_rispana_cleanup');
      expect(tx.type, EcoLedgerTransactionType.creditMission);
      expect(tx.verifyIntegrity(), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('Rejected mission updates status without crediting coins to the ledger', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(
                EvoraUser(
                  uid: 'test_citizen_002',
                  displayName: 'Priya Joshi',
                  email: 'priya@evora.org',
                  tenantId: 'tenant_dehradun_01',
                  selectedLocality: 'Patel Nagar',
                  createdAt: DateTime(2026, 11, 1),
                ),
              )),
        ],
      );

      final notifier = container.read(missionsProvider.notifier);
      await notifier.joinMission('mission_patel_ewaste');

      final rejected = await notifier.verifyAndRewardMission(
        missionId: 'mission_patel_ewaste',
        approved: false,
        feedback: 'Voucher blurry and unreadable. Please re-upload.',
      );

      expect(rejected.status, MissionParticipationStatus.rejected);
      expect(rejected.isCompleted, isFalse);
      expect(rejected.coinsCredited, 0);

      // Ledger must remain untouched at 0
      final ledgerState = container.read(ecoLedgerProvider);
      expect(ledgerState.currentBalance, 0);
      expect(ledgerState.transactions.isEmpty, isTrue);
    });
  });

  group('Phase 5: Append-Only Eco Coins Ledger & Cryptographic Tamper-Proofing Tests', () {
    test('Test 5.2: Cryptographic SHA-256 hash chaining guarantees ledger immutability', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(
                EvoraUser(
                  uid: 'test_citizen_003',
                  displayName: 'Deepak Rawat',
                  tenantId: 'tenant_dehradun_01',
                  selectedLocality: 'Jakhan',
                  createdAt: DateTime(2026, 11, 1),
                ),
              )),
        ],
      );

      final ledger = container.read(ecoLedgerProvider.notifier);

      // Append 3 sequential transactions
      final tx1 = await ledger.appendTransaction(
        userId: 'test_citizen_003',
        type: EcoLedgerTransactionType.creditDailyHabit,
        amount: 10,
        referenceId: 'daily_2026_11_14',
        title: 'Daily Waste Segregation',
        description: 'Segregated wet and dry bins at home',
      );

      final tx2 = await ledger.appendTransaction(
        userId: 'test_citizen_003',
        type: EcoLedgerTransactionType.creditMission,
        amount: 80,
        referenceId: 'mission_patel_ewaste',
        title: 'Completed Patel Road E-Waste Drop',
        description: 'CPCB authorized electronic recycling',
      );

      final tx3 = await ledger.appendTransaction(
        userId: 'test_citizen_003',
        type: EcoLedgerTransactionType.creditMission,
        amount: 150,
        referenceId: 'mission_rajpur_afforestation',
        title: 'Old Rajpur 10-Tree Native Sapling Drive',
        description: 'Planted native Banj Oak trees',
      );

      // Check balance and transactions
      final state = container.read(ecoLedgerProvider);
      expect(state.currentBalance, 240); // 10 + 80 + 150
      expect(state.transactions.length, 3);

      // Verify hash chaining: tx3 links to tx2, tx2 links to tx1
      expect(tx2.previousHash, tx1.hash);
      expect(tx3.previousHash, tx2.hash);

      // Full ledger chain verification passes
      expect(ledger.verifyLedgerIntegrity(), isTrue);

      // TAMPER SIMULATION: A malicious actor attempts to edit an entry in memory
      final tamperedEntry = EcoLedgerEntry(
        id: tx2.id,
        tenantId: tx2.tenantId,
        userId: tx2.userId,
        type: tx2.type,
        amount: 9999, // Tampered unauthorized balance hack
        balanceAfter: 9999,
        referenceId: tx2.referenceId,
        title: tx2.title,
        description: tx2.description,
        timestamp: tx2.timestamp,
        previousHash: tx2.previousHash,
        hash: tx2.hash, // Stale old hash
      );

      // The tampered entry fails individual hash verification
      expect(tamperedEntry.verifyIntegrity(), isFalse);
    });

    test('Legal disclaimer is strictly non-monetary and non-crypto', () {
      expect(EcoLedgerEntry.legalDisclaimer, contains('zero monetary value'));
      expect(EcoLedgerEntry.legalDisclaimer, contains('cryptocurrency'));
      expect(EcoLedgerEntry.legalDisclaimer, contains('Kyoto Protocol'));
    });
  });

  group('Phase 5: Citizen Impact Profile & UN SDG Mapping Tests', () {
    test('Test 5.3: Aggregates real metrics and maps to UN SDGs without double-counting', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(
                EvoraUser(
                  uid: 'test_citizen_004',
                  displayName: 'Sneha Negi',
                  tenantId: 'tenant_dehradun_01',
                  selectedLocality: 'Rajpur Road',
                  createdAt: DateTime(2026, 11, 1),
                ),
              )),
        ],
      );

      final missionsNotifier = container.read(missionsProvider.notifier);

      // Complete Mission 1: Rispana Cleanup (co2: 18kg, waste: 25kg, water: 450L, sdgs: [6, 11, 15], reward: 120)
      await missionsNotifier.joinMission('mission_rispana_cleanup');
      await missionsNotifier.verifyAndRewardMission(missionId: 'mission_rispana_cleanup');

      // Complete Mission 2: Rajpur Afforestation (co2: 65kg, trees: 2, sdgs: [13, 15], reward: 150)
      await missionsNotifier.joinMission('mission_rajpur_afforestation');
      await missionsNotifier.verifyAndRewardMission(missionId: 'mission_rajpur_afforestation');

      // Read derived impact summary
      final impact = container.read(citizenImpactProvider);

      expect(impact.missionsCompleted, 2);
      expect(impact.totalEcoCoins, 270); // 120 + 150
      expect(impact.co2AvoidedKg, 83.0); // 18 + 65
      expect(impact.wasteDivertedKg, 25.0);
      expect(impact.waterSavedLiters, 450.0);
      expect(impact.treesSupported, 2);

      // SDG metrics mapping
      expect(impact.sdgMetrics[6], 450.0); // SDG 6: Clean Water
      expect(impact.sdgMetrics[13], 65.0); // SDG 13: Climate Action CO2e
      expect(impact.sdgMetrics[15], 2.0); // 2 native trees planted (Rajpur Afforestation)
      expect(impact.sdgMetrics[12], 25.0); // SDG 12: Waste Diverted

      // Citizen Tier Promotion
      expect(impact.tier, CitizenEcoTier.valleyGuardian); // 270 >= 100
      expect(impact.earnedBadgeNames, contains('Rispana Guardian'));
      expect(impact.earnedBadgeNames, contains('Himalayan Forester'));
    });

    test('Tier calculation upgrades dynamically as EcoCoins accumulate', () {
      expect(CitizenEcoTier.fromCoins(50), CitizenEcoTier.himalayanSeedling);
      expect(CitizenEcoTier.fromCoins(150), CitizenEcoTier.valleyGuardian);
      expect(CitizenEcoTier.fromCoins(350), CitizenEcoTier.ridgeProtector);
      expect(CitizenEcoTier.fromCoins(750), CitizenEcoTier.doonEcologicalPioneer);
    });
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(EvoraUser? testUser) : super(null) {
    state = AuthState(user: testUser);
  }
}
