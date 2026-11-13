import '../models/evoswitch_models.dart';

/// Pure, deterministic calculation engine for EvoSwitch
/// Evaluates kg CO2e avoided, rupees saved, and tree equivalents against verified baselines.
class EvoSwitchService {
  /// 1 mature Himalayan broadleaf tree absorbs ~20 kg CO2e per year
  static const double kgCo2PerTreeYear = 20.0;

  /// Indian Central Electricity Authority (CEA) Northern Grid factor: ~0.72 kg CO2e / kWh
  static const double gridEmissionFactorKgPerKwh = 0.72;

  /// 1. Travel & Commute Comparison
  /// Compares Petrol Car (baseline 0.170 kg CO2e/km, ₹9.5/km) vs Green Alternatives
  static EvoSwitchImpactResult calculateTravelImpact({
    required double tripDistanceKm,
    required String greenMode, // 'electric_bus', 'ev_scooter', 'bicycle_walk', 'metro'
    int frequencyDaysPerYear = 250, // standard working days in a year
  }) {
    const double carEmissionPerKm = 0.170;
    const double carCostPerKm = 9.5;

    double greenEmissionPerKm;
    double greenCostPerKm;
    String modeName;

    switch (greenMode) {
      case 'electric_bus':
        greenEmissionPerKm = 0.038;
        greenCostPerKm = 1.5;
        modeName = 'Electric City Bus';
        break;
      case 'ev_scooter':
        greenEmissionPerKm = 0.015;
        greenCostPerKm = 0.6;
        modeName = 'Electric Two-Wheeler';
        break;
      case 'petrol_scooter':
        greenEmissionPerKm = 0.045;
        greenCostPerKm = 2.6;
        modeName = 'Two-Wheeler';
        break;
      case 'bicycle_walk':
      default:
        greenEmissionPerKm = 0.0;
        greenCostPerKm = 0.0;
        modeName = 'Bicycle / Walking';
        break;
    }

    final totalAnnualKm = tripDistanceKm * frequencyDaysPerYear;
    final co2PerCar = totalAnnualKm * carEmissionPerKm;
    final co2PerGreen = totalAnnualKm * greenEmissionPerKm;
    final co2AvoidedKg = co2PerCar - co2PerGreen;

    final costPerCar = totalAnnualKm * carCostPerKm;
    final costPerGreen = totalAnnualKm * greenCostPerKm;
    final moneySaved = costPerCar - costPerGreen;

    final trees = co2AvoidedKg / kgCo2PerTreeYear;

    return EvoSwitchImpactResult(
      co2eAvoidedKg: double.parse(co2AvoidedKg.toStringAsFixed(1)),
      moneySavedRupees: double.parse(moneySaved.toStringAsFixed(0)),
      treesEquivalent: double.parse(trees.toStringAsFixed(1)),
      headline: 'Save ${co2AvoidedKg.toStringAsFixed(0)} kg CO₂e / year',
      subheadline: 'By taking the $modeName for your ${tripDistanceKm.toStringAsFixed(0)} km daily route.',
      methodologyExplanation:
          'Based on ARAI/CPCB vehicle emission baselines: Petrol car emits ~170g CO₂e/km vs $modeName (~${(greenEmissionPerKm * 1000).round()}g/km). $frequencyDaysPerYear days/yr commute.',
    );
  }

  /// 2. Shopping & Reusables Comparison
  /// Eliminating disposable PET bottles and single-use polybags
  static EvoSwitchImpactResult calculateShoppingImpact({
    required int singleUseBottlesPerWeek,
    required int polybagsPerWeek,
  }) {
    // 1 PET bottle (500ml) = 25g plastic + 82g CO2e + ₹20 cost
    // 1 Polybag = 8g plastic + 33g CO2e + ₹5 cost
    final annualBottles = singleUseBottlesPerWeek * 52;
    final annualBags = polybagsPerWeek * 52;

    final plasticAvoidedGrams = (annualBottles * 25.0) + (annualBags * 8.0);
    final co2AvoidedKg = ((annualBottles * 0.082) + (annualBags * 0.033));
    final moneySaved = (annualBottles * 20.0) + (annualBags * 5.0);
    final trees = co2AvoidedKg / kgCo2PerTreeYear;

    return EvoSwitchImpactResult(
      co2eAvoidedKg: double.parse(co2AvoidedKg.toStringAsFixed(1)),
      moneySavedRupees: double.parse(moneySaved.toStringAsFixed(0)),
      plasticAvoidedGrams: double.parse(plasticAvoidedGrams.toStringAsFixed(0)),
      treesEquivalent: double.parse(trees.toStringAsFixed(1)),
      headline: 'Eliminate ${(plasticAvoidedGrams / 1000).toStringAsFixed(1)} kg plastic waste',
      subheadline: 'Using a stainless steel flask and reusable cloth bags.',
      methodologyExplanation:
          'Lifecycle carbon factors: ~82g CO₂e per 500ml PET bottle and ~33g CO₂e per virgin LDPE plastic carry bag averted from Himalayan landfills.',
    );
  }

  /// 3. Repair & Upcycle vs Buy New
  static EvoSwitchImpactResult calculateRepairImpact({
    required String itemType, // 'smartphone', 'appliance', 'footwear', 'bicycle'
  }) {
    double embodiedCo2Saved;
    double moneySaved;
    String name;

    switch (itemType) {
      case 'smartphone':
        embodiedCo2Saved = 48.0;
        moneySaved = 12000.0;
        name = 'Smartphone Screen / Battery Repair';
        break;
      case 'appliance':
        embodiedCo2Saved = 34.0;
        moneySaved = 4500.0;
        name = 'Home Appliance Repair (Mixer/Fan)';
        break;
      case 'footwear':
        embodiedCo2Saved = 12.0;
        moneySaved = 1800.0;
        name = 'Footwear Resoling & Stitching';
        break;
      case 'bicycle':
      default:
        embodiedCo2Saved = 32.0;
        moneySaved = 3800.0;
        name = 'Bicycle Overhaul & Reconditioning';
        break;
    }

    final trees = embodiedCo2Saved / kgCo2PerTreeYear;

    return EvoSwitchImpactResult(
      co2eAvoidedKg: embodiedCo2Saved,
      moneySavedRupees: moneySaved,
      treesEquivalent: double.parse(trees.toStringAsFixed(1)),
      headline: 'Prevent $embodiedCo2Saved kg CO₂e embodied emissions',
      subheadline: 'By choosing $name via local repair artisans instead of buying a new product.',
      methodologyExplanation:
          'Embodied carbon accounts for raw material extraction, high-temperature manufacturing, and shipping prevented by life-extension repair guilds.',
    );
  }

  /// 4. Organic Kitchen Waste & Composting
  static EvoSwitchImpactResult calculateWasteImpact({
    required double organicKgPerDay,
  }) {
    // 1 kg organic waste in anaerobic landfill emits ~0.65 kg CO2e (methane)
    // 1 kg in aerobic composting emits ~0.10 kg CO2e
    // Net avoided = 0.55 kg CO2e per kg
    final annualKg = organicKgPerDay * 365;
    final co2AvoidedKg = annualKg * 0.55;
    final compostYieldKg = annualKg * 0.35;
    final compostValueRupees = compostYieldKg * 15.0; // ₹15 per kg organic vermicompost in Dehradun
    final trees = co2AvoidedKg / kgCo2PerTreeYear;

    return EvoSwitchImpactResult(
      co2eAvoidedKg: double.parse(co2AvoidedKg.toStringAsFixed(1)),
      moneySavedRupees: double.parse(compostValueRupees.toStringAsFixed(0)),
      treesEquivalent: double.parse(trees.toStringAsFixed(1)),
      headline: 'Yield ${(compostYieldKg).toStringAsFixed(0)} kg organic compost / year',
      subheadline: 'And avert ${co2AvoidedKg.toStringAsFixed(0)} kg potent methane emissions from Shishambara landfill.',
      methodologyExplanation:
          'IPCC Waste Model: Diverting wet biodegradable waste from anaerobic municipal dump heaps prevents potent methane (CH₄) generation.',
    );
  }

  /// 5. Household Energy Habits
  static EvoSwitchImpactResult calculateEnergyImpact({
    required int bulbsSwappedToLed,
    required int acDegreesRaised, // e.g. 6 degrees (18C -> 24C)
  }) {
    // 1. Bulb savings: 60W Incandescent to 9W LED saves 51W. 5 hrs/day * 365 days = 93 kWh/year per bulb.
    final bulbAnnualKwh = bulbsSwappedToLed * (51.0 * 5.0 * 365.0 / 1000.0);

    // 2. AC savings: 1.5 ton AC (1500W) running 8 hours/day for 120 summer days.
    // Each 1 degree Celsius increase saves ~6% electricity (BEE India guideline).
    final acBaseKwh = 1.5 * 8.0 * 120.0; // 1440 kWh
    final acSavingsPercent = (acDegreesRaised * 0.06).clamp(0.0, 0.45);
    final acAnnualKwh = acBaseKwh * acSavingsPercent;

    final totalKwhSaved = bulbAnnualKwh + acAnnualKwh;
    final co2AvoidedKg = totalKwhSaved * gridEmissionFactorKgPerKwh;
    final moneySaved = totalKwhSaved * 7.20; // ~₹7.20 per kWh domestic tariff Uttarakhand UPCL
    final trees = co2AvoidedKg / kgCo2PerTreeYear;

    return EvoSwitchImpactResult(
      co2eAvoidedKg: double.parse(co2AvoidedKg.toStringAsFixed(1)),
      moneySavedRupees: double.parse(moneySaved.toStringAsFixed(0)),
      treesEquivalent: double.parse(trees.toStringAsFixed(1)),
      headline: 'Cut ${totalKwhSaved.toStringAsFixed(0)} kWh electricity / year',
      subheadline: 'Saving ~₹${moneySaved.toStringAsFixed(0)} on your UPCL domestic power bill.',
      methodologyExplanation:
          'Calculated using UPCL domestic tariffs (₹7.20/kWh) and CEA India grid factor (0.72 kg CO₂/kWh). 9W LED saves 51W; AC at 24°C vs 18°C saves 6% power per °C.',
    );
  }
}
