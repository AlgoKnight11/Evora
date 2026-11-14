import 'package:flutter/material.dart';

/// Categories of citizen sustainability campaigns in EVORA
enum MissionCategory {
  afforestation,
  cleanup,
  ewaste,
  composting,
  transit,
  plasticFree;

  String get label {
    switch (this) {
      case MissionCategory.afforestation:
        return 'Afforestation & Trees';
      case MissionCategory.cleanup:
        return 'River & Civic Cleanups';
      case MissionCategory.ewaste:
        return 'E-Waste Recycling';
      case MissionCategory.composting:
        return 'Home & Community Compost';
      case MissionCategory.transit:
        return 'Green Commute';
      case MissionCategory.plasticFree:
        return 'Zero Single-Use Plastic';
    }
  }

  IconData get icon {
    switch (this) {
      case MissionCategory.afforestation:
        return Icons.park_outlined;
      case MissionCategory.cleanup:
        return Icons.cleaning_services_outlined;
      case MissionCategory.ewaste:
        return Icons.devices_other_outlined;
      case MissionCategory.composting:
        return Icons.compost_outlined;
      case MissionCategory.transit:
        return Icons.directions_bus_filled_outlined;
      case MissionCategory.plasticFree:
        return Icons.shopping_bag_outlined;
    }
  }

  Color get color {
    switch (this) {
      case MissionCategory.afforestation:
        return const Color(0xFF008955);
      case MissionCategory.cleanup:
        return const Color(0xFF0284C7);
      case MissionCategory.ewaste:
        return const Color(0xFF7C3AED);
      case MissionCategory.composting:
        return const Color(0xFF16A34A);
      case MissionCategory.transit:
        return const Color(0xFFEA580C);
      case MissionCategory.plasticFree:
        return const Color(0xFFD97706);
    }
  }
}

/// Lifecycle states of a citizen's mission participation
enum MissionParticipationStatus {
  available,
  joined,
  inProgress,
  submitted,
  verified,
  rejected;

  String get label {
    switch (this) {
      case MissionParticipationStatus.available:
        return 'Available';
      case MissionParticipationStatus.joined:
        return 'Joined';
      case MissionParticipationStatus.inProgress:
        return 'In Progress';
      case MissionParticipationStatus.submitted:
        return 'Under Verification';
      case MissionParticipationStatus.verified:
        return 'Completed';
      case MissionParticipationStatus.rejected:
        return 'Needs Revision';
    }
  }

  Color get color {
    switch (this) {
      case MissionParticipationStatus.available:
        return Colors.grey;
      case MissionParticipationStatus.joined:
        return const Color(0xFF0284C7);
      case MissionParticipationStatus.inProgress:
        return const Color(0xFFEA580C);
      case MissionParticipationStatus.submitted:
        return const Color(0xFFD97706);
      case MissionParticipationStatus.verified:
        return const Color(0xFF008955);
      case MissionParticipationStatus.rejected:
        return const Color(0xFFDC2626);
    }
  }
}

/// Representation of an environmental campaign mission
class EcoMission {
  final String id;
  final String tenantId;
  final String title;
  final String description;
  final MissionCategory category;
  final String timeCommitment;
  final String locality;
  final int ecoCoinsReward;
  final List<String> instructions;
  final List<String> eligibility;
  final List<String> safetyGuidelines;
  final String requiredProofDescription;
  final List<int> sdgs; // e.g. [6, 11, 12, 13, 15]
  final double co2AvoidedKg;
  final double wasteDivertedKg;
  final double waterSavedLiters;
  final int treesSupported;
  final DateTime deadline;
  final int maxParticipants;
  final int participantsCount;
  final String badgeName;
  final String? bannerImageUrl;

  const EcoMission({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.description,
    required this.category,
    required this.timeCommitment,
    required this.locality,
    required this.ecoCoinsReward,
    required this.instructions,
    required this.eligibility,
    required this.safetyGuidelines,
    required this.requiredProofDescription,
    required this.sdgs,
    this.co2AvoidedKg = 0.0,
    this.wasteDivertedKg = 0.0,
    this.waterSavedLiters = 0.0,
    this.treesSupported = 0,
    required this.deadline,
    this.maxParticipants = 500,
    this.participantsCount = 0,
    required this.badgeName,
    this.bannerImageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'title': title,
        'description': description,
        'category': category.name,
        'timeCommitment': timeCommitment,
        'locality': locality,
        'ecoCoinsReward': ecoCoinsReward,
        'instructions': instructions,
        'eligibility': eligibility,
        'safetyGuidelines': safetyGuidelines,
        'requiredProofDescription': requiredProofDescription,
        'sdgs': sdgs,
        'co2AvoidedKg': co2AvoidedKg,
        'wasteDivertedKg': wasteDivertedKg,
        'waterSavedLiters': waterSavedLiters,
        'treesSupported': treesSupported,
        'deadline': deadline.toIso8601String(),
        'maxParticipants': maxParticipants,
        'participantsCount': participantsCount,
        'badgeName': badgeName,
        'bannerImageUrl': bannerImageUrl,
      };

  factory EcoMission.fromJson(Map<String, dynamic> json) {
    return EcoMission(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? 'tenant_dehradun_01',
      title: json['title'] as String? ?? 'Untitled Mission',
      description: json['description'] as String? ?? '',
      category: MissionCategory.values.firstWhere(
        (c) => c.name == (json['category'] as String? ?? 'cleanup'),
        orElse: () => MissionCategory.cleanup,
      ),
      timeCommitment: json['timeCommitment'] as String? ?? '1-2 Hours',
      locality: json['locality'] as String? ?? 'Dehradun Municipal Area',
      ecoCoinsReward: (json['ecoCoinsReward'] as num?)?.toInt() ?? 50,
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      eligibility: (json['eligibility'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      safetyGuidelines: (json['safetyGuidelines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      requiredProofDescription: json['requiredProofDescription'] as String? ??
          'Photo proof of completed action',
      sdgs: (json['sdgs'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [11, 13],
      co2AvoidedKg: (json['co2AvoidedKg'] as num?)?.toDouble() ?? 0.0,
      wasteDivertedKg: (json['wasteDivertedKg'] as num?)?.toDouble() ?? 0.0,
      waterSavedLiters: (json['waterSavedLiters'] as num?)?.toDouble() ?? 0.0,
      treesSupported: (json['treesSupported'] as num?)?.toInt() ?? 0,
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 500,
      participantsCount: (json['participantsCount'] as num?)?.toInt() ?? 0,
      badgeName: json['badgeName'] as String? ?? 'Eco Pioneer',
      bannerImageUrl: json['bannerImageUrl'] as String?,
    );
  }
}

/// Representation of a citizen's active or completed mission participation
class MissionParticipation {
  final String id;
  final String missionId;
  final String userId;
  final String tenantId;
  final MissionParticipationStatus status;
  final DateTime joinedAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? proofImageUrl;
  final String? proofNotes;
  final int coinsCredited;
  final String? verificationFeedback;

  const MissionParticipation({
    required this.id,
    required this.missionId,
    required this.userId,
    required this.tenantId,
    required this.status,
    required this.joinedAt,
    this.startedAt,
    this.submittedAt,
    this.verifiedAt,
    this.proofImageUrl,
    this.proofNotes,
    this.coinsCredited = 0,
    this.verificationFeedback,
  });

  bool get isCompleted => status == MissionParticipationStatus.verified;
  bool get isUnderReview => status == MissionParticipationStatus.submitted;

  MissionParticipation copyWith({
    String? id,
    String? missionId,
    String? userId,
    String? tenantId,
    MissionParticipationStatus? status,
    DateTime? joinedAt,
    DateTime? startedAt,
    DateTime? submittedAt,
    DateTime? verifiedAt,
    String? proofImageUrl,
    String? proofNotes,
    int? coinsCredited,
    String? verificationFeedback,
  }) {
    return MissionParticipation(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      proofNotes: proofNotes ?? this.proofNotes,
      coinsCredited: coinsCredited ?? this.coinsCredited,
      verificationFeedback: verificationFeedback ?? this.verificationFeedback,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'missionId': missionId,
        'userId': userId,
        'tenantId': tenantId,
        'status': status.name,
        'joinedAt': joinedAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
        'verifiedAt': verifiedAt?.toIso8601String(),
        'proofImageUrl': proofImageUrl,
        'proofNotes': proofNotes,
        'coinsCredited': coinsCredited,
        'verificationFeedback': verificationFeedback,
      };

  factory MissionParticipation.fromJson(Map<String, dynamic> json) {
    return MissionParticipation(
      id: json['id'] as String? ?? '',
      missionId: json['missionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? 'tenant_dehradun_01',
      status: MissionParticipationStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'available'),
        orElse: () => MissionParticipationStatus.available,
      ),
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '') ?? DateTime.now(),
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
      proofImageUrl: json['proofImageUrl'] as String?,
      proofNotes: json['proofNotes'] as String?,
      coinsCredited: (json['coinsCredited'] as num?)?.toInt() ?? 0,
      verificationFeedback: json['verificationFeedback'] as String?,
    );
  }
}
