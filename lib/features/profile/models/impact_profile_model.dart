import 'package:flutter/material.dart';

/// UN Sustainable Development Goals tracked in EVORA's civic impact engine
class SdgInfo {
  final int number;
  final String title;
  final String officialName;
  final Color color;
  final IconData icon;
  final String localContext;
  final String primaryMetricUnit;

  const SdgInfo({
    required this.number,
    required this.title,
    required this.officialName,
    required this.color,
    required this.icon,
    required this.localContext,
    required this.primaryMetricUnit,
  });

  static const Map<int, SdgInfo> registry = {
    6: SdgInfo(
      number: 6,
      title: 'Clean Water & Sanitation',
      officialName: 'Ensure availability and sustainable management of water and sanitation for all',
      color: Color(0xFF0284C7), // Sky Blue
      icon: Icons.water_drop_outlined,
      localContext:
          'Restoring seasonal flows of Rispana & Bindal rivers, unblocking municipal stormwater drains, and averting sewer runoffs into Doon groundwater.',
      primaryMetricUnit: 'Liters Restored',
    ),
    11: SdgInfo(
      number: 11,
      title: 'Sustainable Cities',
      officialName: 'Make cities and human settlements inclusive, safe, resilient, and sustainable',
      color: Color(0xFFD97706), // Amber Orange
      icon: Icons.location_city_outlined,
      localContext:
          'Reporting and triaging civic hazards (potholes, streetlights, uncollected waste) with Dehradun Municipal Corporation (NNND).',
      primaryMetricUnit: 'Civic Hazards Fixed',
    ),
    12: SdgInfo(
      number: 12,
      title: 'Responsible Consumption',
      officialName: 'Ensure sustainable consumption and production patterns',
      color: Color(0xFFCA8A04), // Gold Yellow
      icon: Icons.autorenew_outlined,
      localContext:
          'Diverting toxic e-waste and domestic organic matter from Shishambara landfill to circular recovery and decentralized composting hubs.',
      primaryMetricUnit: 'kg Waste Diverted',
    ),
    13: SdgInfo(
      number: 13,
      title: 'Climate Action',
      officialName: 'Take urgent action to combat climate change and its impacts',
      color: Color(0xFF15803D), // Forest Green
      icon: Icons.eco_outlined,
      localContext:
          'Quantifying real avoided greenhouse gases (kg CO₂e) through green public transit, home energy setpoint shifts, and composting methane aversion.',
      primaryMetricUnit: 'kg CO₂e Avoided',
    ),
    15: SdgInfo(
      number: 15,
      title: 'Life on Land',
      officialName: 'Protect, restore and promote sustainable use of terrestrial ecosystems',
      color: Color(0xFF008955), // Mountain Emerald
      icon: Icons.forest_outlined,
      localContext:
          'Native Himalayan oak and broadleaf tree planting in Mussoorie foothills, forest litter cleanup, and biodiversity preservation.',
      primaryMetricUnit: 'Trees Planted & Adopted',
    ),
  };
}

/// Citizen sustainability level tier in EVORA
enum CitizenEcoTier {
  himalayanSeedling,
  valleyGuardian,
  ridgeProtector,
  doonEcologicalPioneer;

  String get title {
    switch (this) {
      case CitizenEcoTier.himalayanSeedling:
        return 'Himalayan Seedling';
      case CitizenEcoTier.valleyGuardian:
        return 'Valley Guardian';
      case CitizenEcoTier.ridgeProtector:
        return 'Ridge Protector';
      case CitizenEcoTier.doonEcologicalPioneer:
        return 'Doon Eco Pioneer';
    }
  }

  Color get color {
    switch (this) {
      case CitizenEcoTier.himalayanSeedling:
        return const Color(0xFF64748B);
      case CitizenEcoTier.valleyGuardian:
        return const Color(0xFF0284C7);
      case CitizenEcoTier.ridgeProtector:
        return const Color(0xFF7C3AED);
      case CitizenEcoTier.doonEcologicalPioneer:
        return const Color(0xFF008955);
    }
  }

  static CitizenEcoTier fromCoins(int totalCoins) {
    if (totalCoins >= 600) return CitizenEcoTier.doonEcologicalPioneer;
    if (totalCoins >= 300) return CitizenEcoTier.ridgeProtector;
    if (totalCoins >= 100) return CitizenEcoTier.valleyGuardian;
    return CitizenEcoTier.himalayanSeedling;
  }
}

/// Cumulative environmental impact summary for a citizen
class CitizenImpactSummary {
  final String userId;
  final int totalEcoCoins;
  final int missionsCompleted;
  final int civicCasesResolved;
  final int observationsPosted;
  final double co2AvoidedKg;
  final double wasteDivertedKg;
  final double waterSavedLiters;
  final int treesSupported;
  final Map<int, double> sdgMetrics;
  final List<String> earnedBadgeNames;

  const CitizenImpactSummary({
    required this.userId,
    required this.totalEcoCoins,
    required this.missionsCompleted,
    required this.civicCasesResolved,
    required this.observationsPosted,
    required this.co2AvoidedKg,
    required this.wasteDivertedKg,
    required this.waterSavedLiters,
    required this.treesSupported,
    required this.sdgMetrics,
    required this.earnedBadgeNames,
  });

  CitizenEcoTier get tier => CitizenEcoTier.fromCoins(totalEcoCoins);

  factory CitizenImpactSummary.empty(String uid) {
    return CitizenImpactSummary(
      userId: uid,
      totalEcoCoins: 0,
      missionsCompleted: 0,
      civicCasesResolved: 0,
      observationsPosted: 0,
      co2AvoidedKg: 0.0,
      wasteDivertedKg: 0.0,
      waterSavedLiters: 0.0,
      treesSupported: 0,
      sdgMetrics: {
        6: 0.0,
        11: 0.0,
        12: 0.0,
        13: 0.0,
        15: 0.0,
      },
      earnedBadgeNames: ['Citizen Onboarded'],
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'totalEcoCoins': totalEcoCoins,
        'missionsCompleted': missionsCompleted,
        'civicCasesResolved': civicCasesResolved,
        'observationsPosted': observationsPosted,
        'co2AvoidedKg': co2AvoidedKg,
        'wasteDivertedKg': wasteDivertedKg,
        'waterSavedLiters': waterSavedLiters,
        'treesSupported': treesSupported,
        'sdgMetrics': sdgMetrics.map((k, v) => MapEntry(k.toString(), v)),
        'earnedBadgeNames': earnedBadgeNames,
      };

  factory CitizenImpactSummary.fromJson(Map<String, dynamic> json) {
    final rawSdg = json['sdgMetrics'] as Map<String, dynamic>? ?? {};
    final parsedSdg = <int, double>{};
    for (final entry in rawSdg.entries) {
      final k = int.tryParse(entry.key);
      if (k != null) {
        parsedSdg[k] = (entry.value as num?)?.toDouble() ?? 0.0;
      }
    }

    return CitizenImpactSummary(
      userId: json['userId'] as String? ?? '',
      totalEcoCoins: (json['totalEcoCoins'] as num?)?.toInt() ?? 0,
      missionsCompleted: (json['missionsCompleted'] as num?)?.toInt() ?? 0,
      civicCasesResolved: (json['civicCasesResolved'] as num?)?.toInt() ?? 0,
      observationsPosted: (json['observationsPosted'] as num?)?.toInt() ?? 0,
      co2AvoidedKg: (json['co2AvoidedKg'] as num?)?.toDouble() ?? 0.0,
      wasteDivertedKg: (json['wasteDivertedKg'] as num?)?.toDouble() ?? 0.0,
      waterSavedLiters: (json['waterSavedLiters'] as num?)?.toDouble() ?? 0.0,
      treesSupported: (json['treesSupported'] as num?)?.toInt() ?? 0,
      sdgMetrics: parsedSdg,
      earnedBadgeNames: (json['earnedBadgeNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Citizen Onboarded'],
    );
  }
}
