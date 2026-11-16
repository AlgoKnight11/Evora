import 'package:flutter/material.dart';

enum EvoSwitchCategory {
  travel,
  shopping,
  repair,
  waste,
  energy;

  String get label {
    switch (this) {
      case EvoSwitchCategory.travel:
        return 'Travel & Commute';
      case EvoSwitchCategory.shopping:
        return 'Shopping & Reusables';
      case EvoSwitchCategory.repair:
        return 'Repair vs Buy New';
      case EvoSwitchCategory.waste:
        return 'Organic Composting';
      case EvoSwitchCategory.energy:
        return 'Home Energy Habits';
    }
  }

  IconData get icon {
    switch (this) {
      case EvoSwitchCategory.travel:
        return Icons.directions_bus_outlined;
      case EvoSwitchCategory.shopping:
        return Icons.shopping_bag_outlined;
      case EvoSwitchCategory.repair:
        return Icons.build_outlined;
      case EvoSwitchCategory.waste:
        return Icons.compost_outlined;
      case EvoSwitchCategory.energy:
        return Icons.bolt_outlined;
    }
  }
}

/// Deterministic calculation result showing environmental and financial savings
class EvoSwitchImpactResult {
  final double co2eAvoidedKg;
  final double moneySavedRupees;
  final double plasticAvoidedGrams;
  final double treesEquivalent;
  final String headline;
  final String subheadline;
  final String methodologyExplanation;

  const EvoSwitchImpactResult({
    required this.co2eAvoidedKg,
    required this.moneySavedRupees,
    this.plasticAvoidedGrams = 0,
    required this.treesEquivalent,
    required this.headline,
    required this.subheadline,
    required this.methodologyExplanation,
  });
}
