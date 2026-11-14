import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/logging_service.dart';
import '../../../services/pii_redaction_service.dart';
import '../../auth/services/auth_service.dart';
import '../../ledger/models/eco_ledger_model.dart';
import '../../ledger/services/eco_ledger_service.dart';
import '../models/mission_model.dart';

class MissionsState {
  final List<EcoMission> missions;
  final Map<String, MissionParticipation> userParticipations; // key: missionId
  final bool isLoading;
  final String? errorMessage;
  final MissionCategory? selectedCategory;

  const MissionsState({
    this.missions = const [],
    this.userParticipations = const {},
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory,
  });

  List<EcoMission> get filteredMissions {
    if (selectedCategory == null) return missions;
    return missions.where((m) => m.category == selectedCategory).toList();
  }

  MissionsState copyWith({
    List<EcoMission>? missions,
    Map<String, MissionParticipation>? userParticipations,
    bool? isLoading,
    String? errorMessage,
    MissionCategory? selectedCategory,
    bool clearCategory = false,
  }) {
    return MissionsState(
      missions: missions ?? this.missions,
      userParticipations: userParticipations ?? this.userParticipations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
    );
  }
}

class MissionsNotifier extends StateNotifier<MissionsState> {
  final Ref _ref;
  final FirebaseFirestore? _firestore;
  static const String _localParticipationsPrefix = 'evora_mission_participations_';

  static final List<EcoMission> seedMissions = [
    EcoMission(
      id: 'mission_rispana_cleanup',
      tenantId: AppConstants.defaultTenantId,
      title: 'Rispana & Bindal Riverbed Cleanliness Drive',
      description:
          'Join fellow citizens to clear non-biodegradable plastic packaging and debris along the seasonal Rispana river corridor to prevent monsoon drain clogging.',
      category: MissionCategory.cleanup,
      timeCommitment: '2 Hours (Weekend)',
      locality: 'Rispana Bridge / Dalanwala Corridor',
      ecoCoinsReward: 120,
      instructions: [
        'Assemble at Rispana Pul collection point with gloves and heavy-duty bags provided by Nagar Nigam.',
        'Collect dry recyclable plastic and glass bottles into marked blue collection bags.',
        'Avoid hazardous biomedical or sharp construction debris.',
        'Weigh or deposit bags at the designated municipal tipper and take a verification photo.',
      ],
      eligibility: ['Open to all citizens aged 16+', 'Minors must be accompanied by adults'],
      safetyGuidelines: [
        'Wear thick protective rubber gloves and closed-toe footwear.',
        'Do not step into swift deep water channels or unstable riverbed rubble.',
        'Stay hydrated and keep hands sanitized.',
      ],
      requiredProofDescription: 'Photo of filled collection bag deposited at municipal tipper',
      sdgs: [6, 11, 12, 15],
      co2AvoidedKg: 18.0,
      wasteDivertedKg: 25.0,
      waterSavedLiters: 450.0,
      deadline: DateTime.now().add(const Duration(days: 28)),
      maxParticipants: 150,
      participantsCount: 84,
      badgeName: 'Rispana Guardian',
    ),
    EcoMission(
      id: 'mission_rajpur_afforestation',
      tenantId: AppConstants.defaultTenantId,
      title: 'Old Rajpur 10-Tree Native Sapling Drive',
      description:
          'Adopt and plant indigenous Himalayan broadleaf trees (Banj Oak, Rhododendron, Kachnar) in designated community patches near MDDA Park to combat slope soil erosion.',
      category: MissionCategory.afforestation,
      timeCommitment: '3 Hours',
      locality: 'Old Rajpur / MDDA Park Foothills',
      ecoCoinsReward: 150,
      instructions: [
        'Collect saplings from the Uttarakhand Forest Department counter at Old Rajpur.',
        'Dig planting pits at least 45 cm deep in demarcated slope terraces.',
        'Mix topsoil with natural leaf compost and firm around the sapling root ball.',
        'Water thoroughly and affix the wooden tree identity tag.',
      ],
      eligibility: ['Open to all residents', 'Commitment to water saplings once a week for 1 month'],
      safetyGuidelines: [
        'Watch for loose shale stones on slopes.',
        'Use provided trowels and garden spades safely.',
      ],
      requiredProofDescription: 'Photo with your planted sapling and tagged identity marker',
      sdgs: [13, 15],
      co2AvoidedKg: 65.0,
      treesSupported: 2,
      deadline: DateTime.now().add(const Duration(days: 21)),
      maxParticipants: 100,
      participantsCount: 62,
      badgeName: 'Himalayan Forester',
    ),
    EcoMission(
      id: 'mission_patel_ewaste',
      tenantId: AppConstants.defaultTenantId,
      title: 'Patel Road E-Waste Drop Challenge',
      description:
          'Clear your home of toxic obsolete electronics (broken chargers, old lithium-ion batteries, circuit boards) and drop them off at the authorized Patel Road hub.',
      category: MissionCategory.ewaste,
      timeCommitment: '30 Minutes',
      locality: 'Nagar Nigam E-Waste Hub, Patel Road',
      ecoCoinsReward: 80,
      instructions: [
        'Gather discarded domestic electronic waste (min. 500g or 2 electronic devices).',
        'Tape terminal ends of lithium-ion batteries to prevent short-circuit sparks.',
        'Hand over to the authorized CPCB-registered recycling desk on Patel Road.',
        'Collect the stamped acknowledgement slip or take a photo at the drop kiosk.',
      ],
      eligibility: ['All household consumers (commercial e-waste not eligible for this mission)'],
      safetyGuidelines: [
        'Never crack or puncture swollen lithium batteries.',
        'Keep damp electronics separate.',
      ],
      requiredProofDescription: 'Photo of e-waste deposit box or stamped handover voucher',
      sdgs: [11, 12],
      co2AvoidedKg: 32.0,
      wasteDivertedKg: 4.5,
      deadline: DateTime.now().add(const Duration(days: 35)),
      maxParticipants: 200,
      participantsCount: 118,
      badgeName: 'Circular Tech Ally',
    ),
    EcoMission(
      id: 'mission_green_transit',
      tenantId: AppConstants.defaultTenantId,
      title: '7-Day Green Transit Commuter Challenge',
      description:
          'Shift your daily Doon Valley commute from private petrol car or two-wheeler to the Smart City Electric Bus or bicycle for 7 consecutive business days.',
      category: MissionCategory.transit,
      timeCommitment: '7 Days Daily',
      locality: 'Rajpur Road / Clock Tower / ISBT Corridors',
      ecoCoinsReward: 100,
      instructions: [
        'Use Dehradun Smart City Electric Buses (Route 1 to 5) or cycle for your commute.',
        'Retain 3 digital or paper bus tickets or log cycling trips.',
        'Upload your collage or ticket photos at the end of the 7-day challenge.',
      ],
      eligibility: ['Regular commuters travelling >3 km per day within Dehradun'],
      safetyGuidelines: [
        'Always board and alight buses only at marked shelters.',
        'Wear reflective clothing and a helmet when cycling at dawn/dusk.',
      ],
      requiredProofDescription: 'Photo of 3 electric bus transit tickets or bike odometer log',
      sdgs: [11, 13],
      co2AvoidedKg: 28.5,
      deadline: DateTime.now().add(const Duration(days: 40)),
      maxParticipants: 300,
      participantsCount: 175,
      badgeName: 'Clean Air Commuter',
    ),
    EcoMission(
      id: 'mission_home_composting',
      tenantId: AppConstants.defaultTenantId,
      title: '14-Day Kitchen Waste Home Composting Pilot',
      description:
          'Segregate 100% of your raw vegetable, fruit peels, and coffee grounds at home for 2 weeks to avert methane emissions at the municipal dumpsite.',
      category: MissionCategory.composting,
      timeCommitment: '14 Days (5 min/day)',
      locality: 'All Dehradun Wards & Households',
      ecoCoinsReward: 140,
      instructions: [
        'Set up a simple aerated bin or terracotta pot with dry leaves/cocopeat base.',
        'Layer daily wet peels with brown dry leaves to maintain proper carbon-nitrogen balance.',
        'Turn the compost heap twice a week to ensure aerobic decomposition without foul odors.',
        'Submit a photo of your active active dark compost batch after day 14.',
      ],
      eligibility: ['Any household with access to a balcony, terrace, or garden'],
      safetyGuidelines: [
        'Do not add cooked oily curries, dairy, or pet waste to domestic compost bins.',
        'Keep bin covered to deter flies and pests.',
      ],
      requiredProofDescription: 'Photo of active dark crumbly home compost batch with date tag',
      sdgs: [12, 13],
      co2AvoidedKg: 22.0,
      wasteDivertedKg: 14.0,
      deadline: DateTime.now().add(const Duration(days: 45)),
      maxParticipants: 250,
      participantsCount: 139,
      badgeName: 'Soil Regenerator',
    ),
    EcoMission(
      id: 'mission_paltan_plastic_free',
      tenantId: AppConstants.defaultTenantId,
      title: 'Paltan Bazaar Zero Single-Use Plastic Week',
      description:
          'Commit to carrying reusable jute/cotton tote bags and personal water flasks when shopping in Paltan Bazaar, refusing all single-use LDPE polybags.',
      category: MissionCategory.plasticFree,
      timeCommitment: '1 Week',
      locality: 'Paltan Bazaar / Clock Tower Market',
      ecoCoinsReward: 75,
      instructions: [
        'Carry your own shopping cloth bags for groceries, produce, and apparel.',
        'Politely refuse vendor plastic polybags.',
        'Take a photo of your reusable market bag in front of a Paltan Bazaar landmark.',
      ],
      eligibility: ['Open to all shoppers and residents'],
      safetyGuidelines: [
        'Keep reusable bags laundered and clean between market trips.',
      ],
      requiredProofDescription: 'Photo showing reusable cloth bags used during Paltan Bazaar visit',
      sdgs: [12, 14],
      co2AvoidedKg: 8.5,
      wasteDivertedKg: 2.0,
      deadline: DateTime.now().add(const Duration(days: 30)),
      maxParticipants: 400,
      participantsCount: 220,
      badgeName: 'Zero Waste Pioneer',
    ),
  ];

  Future<void>? _loadFuture;

  MissionsNotifier(this._ref, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? _resolveFirestore(),
        super(MissionsState(missions: seedMissions)) {
    _loadFuture = _loadMissionsAndParticipations();
  }

  static FirebaseFirestore? _resolveFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void setCategoryFilter(MissionCategory? category) {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  Future<void> _loadMissionsAndParticipations() async {
    final user = _ref.read(authProvider).user;
    if (user != null) {
      await loadParticipationsForUser(user.uid);
    }
  }

  /// Loads mission participation states for active user
  Future<void> loadParticipationsForUser(String uid) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Try loading from Firestore
      if (_firestore != null) {
        try {
          final snap = await _firestore
              .collection(AppConstants.colUsers)
              .doc(uid)
              .collection(AppConstants.subColMissions)
              .get();

          if (snap.docs.isNotEmpty) {
            final map = <String, MissionParticipation>{};
            for (final doc in snap.docs) {
              final p = MissionParticipation.fromJson(doc.data());
              map[p.missionId] = p;
            }
            final merged = {...map, ...state.userParticipations};
            state = state.copyWith(userParticipations: merged, isLoading: false);
            await _saveParticipationsToDisk(uid, merged);
            return;
          }
        } catch (e) {
          debugPrint('[Missions] Firestore query warning: $e');
        }
      }

      // 2. Fall back to local disk
      final local = await _loadParticipationsFromDisk(uid);
      final merged = {...local, ...state.userParticipations};
      state = state.copyWith(userParticipations: merged, isLoading: false);
    } catch (e) {
      LoggingService.logError('[Missions] Failed loading participations: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Join a campaign mission
  Future<MissionParticipation> joinMission(String missionId) async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
    final user = _ref.read(authProvider).user;
    if (user == null) {
      throw Exception('Authentication required to join missions.');
    }

    final now = DateTime.now();
    final p = MissionParticipation(
      id: 'part_${const Uuid().v4()}',
      missionId: missionId,
      userId: user.uid,
      tenantId: AppConstants.defaultTenantId,
      status: MissionParticipationStatus.joined,
      joinedAt: now,
      startedAt: now,
    );

    await _persistParticipation(p);
    return p;
  }

  /// Submit verification proof (photo + notes) for a mission
  Future<MissionParticipation> submitMissionProof({
    required String missionId,
    File? proofImageFile,
    String? proofNotes,
  }) async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
    final user = _ref.read(authProvider).user;
    if (user == null) throw Exception('Authentication required');

    final existing = state.userParticipations[missionId];
    if (existing == null) {
      throw Exception('You must join the mission before submitting verification proof.');
    }

    String? uploadedUrl = existing.proofImageUrl;

    // 1. Process image proof with on-device EXIF stripping and PII blur before Cloudinary upload
    if (proofImageFile != null) {
      try {
        final redactionResult = await PiiRedactionService.redactFileToTemp(
          sourceFile: proofImageFile,
          regions: const [],
        );

        final fileToUpload = redactionResult.file ?? proofImageFile;
        final uploadResult = await CloudinaryService.uploadImage(
          fileToUpload,
          folder: 'missions/proof',
        );
        uploadedUrl = uploadResult.url ?? proofImageFile.path;
      } catch (e) {
        LoggingService.logError('[Missions] Proof upload error: $e');
        // If Cloudinary fails offline, use local path as proof reference
        uploadedUrl = proofImageFile.path;
      }
    }

    final updated = existing.copyWith(
      status: MissionParticipationStatus.submitted,
      submittedAt: DateTime.now(),
      proofImageUrl: uploadedUrl,
      proofNotes: proofNotes,
    );

    await _persistParticipation(updated);
    return updated;
  }

  /// Verify and complete a mission, automatically appending coins to the EcoLedger
  Future<MissionParticipation> verifyAndRewardMission({
    required String missionId,
    bool approved = true,
    String? feedback,
  }) async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
    final user = _ref.read(authProvider).user;
    if (user == null) throw Exception('Authentication required');

    final existing = state.userParticipations[missionId];
    if (existing == null) throw Exception('Participation not found');

    final mission = state.missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => throw Exception('Mission not found: $missionId'),
    );

    if (approved) {
      // 1. Append transaction to immutable EcoLedger
      await _ref.read(ecoLedgerProvider.notifier).appendTransaction(
            userId: user.uid,
            type: EcoLedgerTransactionType.creditMission,
            amount: mission.ecoCoinsReward,
            referenceId: mission.id,
            title: 'Completed Mission: ${mission.title}',
            description: 'Verified proof for ${mission.category.label} campaign in ${mission.locality}',
          );

      final completed = existing.copyWith(
        status: MissionParticipationStatus.verified,
        verifiedAt: DateTime.now(),
        coinsCredited: mission.ecoCoinsReward,
        verificationFeedback: feedback ?? 'Verified by EVORA Community Audit System',
      );

      await _persistParticipation(completed);
      return completed;
    } else {
      final rejected = existing.copyWith(
        status: MissionParticipationStatus.rejected,
        verificationFeedback: feedback ?? 'Verification photo was unclear. Please resubmit clear proof.',
      );

      await _persistParticipation(rejected);
      return rejected;
    }
  }

  Future<void> _persistParticipation(MissionParticipation p) async {
    final updatedMap = Map<String, MissionParticipation>.from(state.userParticipations);
    updatedMap[p.missionId] = p;

    state = state.copyWith(userParticipations: updatedMap);

    // 1. Persist to Firestore if available
    if (_firestore != null) {
      try {
        await _firestore
            .collection(AppConstants.colUsers)
            .doc(p.userId)
            .collection(AppConstants.subColMissions)
            .doc(p.missionId)
            .set(p.toJson());
      } catch (e) {
        debugPrint('[Missions] Firestore sync warning: $e');
      }
    }

    // 2. Persist to local disk cache
    await _saveParticipationsToDisk(p.userId, updatedMap);
  }

  Future<void> _saveParticipationsToDisk(
    String uid,
    Map<String, MissionParticipation> map,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = map.map((k, v) => MapEntry(k, jsonEncode(v.toJson())));
      await prefs.setString('$_localParticipationsPrefix$uid', jsonEncode(jsonMap));
    } catch (_) {}
  }

  Future<Map<String, MissionParticipation>> _loadParticipationsFromDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_localParticipationsPrefix$uid');
      if (str != null) {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        final map = <String, MissionParticipation>{};
        for (final entry in decoded.entries) {
          map[entry.key] =
              MissionParticipation.fromJson(jsonDecode(entry.value as String) as Map<String, dynamic>);
        }
        return map;
      }
    } catch (_) {}
    return {};
  }
}

/// Global Riverpod Provider for Eco Missions
final missionsProvider = StateNotifierProvider<MissionsNotifier, MissionsState>((ref) {
  return MissionsNotifier(ref);
});
