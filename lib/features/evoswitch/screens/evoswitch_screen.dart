import 'package:flutter/material.dart';
import '../../../core/theme/evora_colors.dart';
import '../models/evoswitch_models.dart';
import '../services/evoswitch_service.dart';

class EvoSwitchScreen extends StatefulWidget {
  const EvoSwitchScreen({super.key});

  @override
  State<EvoSwitchScreen> createState() => _EvoSwitchScreenState();
}

class _EvoSwitchScreenState extends State<EvoSwitchScreen> {
  EvoSwitchCategory _selectedCategory = EvoSwitchCategory.travel;

  // Travel params
  double _travelDistanceKm = 12.0;
  String _travelMode = 'electric_bus';

  // Shopping params
  int _bottlesPerWeek = 4;
  int _polybagsPerWeek = 6;

  // Repair params
  String _repairItemType = 'smartphone';

  // Waste params
  double _organicKgPerDay = 1.2;

  // Energy params
  int _bulbsSwapped = 5;
  int _acDegreesRaised = 6;

  bool _showMethodology = false;

  EvoSwitchImpactResult _computeCurrentImpact() {
    switch (_selectedCategory) {
      case EvoSwitchCategory.travel:
        return EvoSwitchService.calculateTravelImpact(
          tripDistanceKm: _travelDistanceKm,
          greenMode: _travelMode,
        );
      case EvoSwitchCategory.shopping:
        return EvoSwitchService.calculateShoppingImpact(
          singleUseBottlesPerWeek: _bottlesPerWeek,
          polybagsPerWeek: _polybagsPerWeek,
        );
      case EvoSwitchCategory.repair:
        return EvoSwitchService.calculateRepairImpact(
          itemType: _repairItemType,
        );
      case EvoSwitchCategory.waste:
        return EvoSwitchService.calculateWasteImpact(
          organicKgPerDay: _organicKgPerDay,
        );
      case EvoSwitchCategory.energy:
        return EvoSwitchService.calculateEnergyImpact(
          bulbsSwappedToLed: _bulbsSwapped,
          acDegreesRaised: _acDegreesRaised,
        );
    }
  }

  void _onCommitSwitch(EvoSwitchImpactResult impact) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Committed! This sustainable choice saves ${impact.co2eAvoidedKg.toStringAsFixed(0)} kg CO₂e / yr.',
        ),
        backgroundColor: EvoraColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final impact = _computeCurrentImpact();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EvoSwitch Calculator'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner introducing the tool
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EvoraColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: EvoraColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.swap_calls_outlined, color: EvoraColors.primary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Green Choices. Measurable Impact.',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'See exact CO₂e averted, rupees saved, and tree equivalents using verified Indian emission standards.',
                            style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category Selector Tabs
              const Text(
                'Choose an Everyday Habit to Compare:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: EvoSwitchCategory.values.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, index) {
                    final cat = EvoSwitchCategory.values[index];
                    final isSelected = _selectedCategory == cat;

                    return FilterChip(
                      avatar: Icon(
                        cat.icon,
                        size: 16,
                        color: isSelected ? Colors.white : EvoraColors.primary,
                      ),
                      label: Text(cat.label),
                      selected: isSelected,
                      selectedColor: EvoraColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : EvoraColors.onSurface,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Input Controls Container
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: _buildCategoryControls(),
              ),
              const SizedBox(height: 20),

              // Main Impact Results Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [EvoraColors.primary, Color(0xFF004D34)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: EvoraColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'ANNUAL BENEFIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.eco, color: EvoraColors.secondary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      impact.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      impact.subheadline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricColumn(
                            'CO₂e Averted',
                            '${impact.co2eAvoidedKg.toStringAsFixed(0)} kg',
                            Icons.cloud_done_outlined,
                            EvoraColors.secondary,
                          ),
                          Container(width: 1, height: 36, color: Colors.white24),
                          _buildMetricColumn(
                            'Estimated Savings',
                            '₹${impact.moneySavedRupees.toStringAsFixed(0)}',
                            Icons.currency_rupee,
                            Colors.amberAccent,
                          ),
                          Container(width: 1, height: 36, color: Colors.white24),
                          _buildMetricColumn(
                            'Tree Power',
                            '${impact.treesEquivalent.toStringAsFixed(1)} trees',
                            Icons.park_outlined,
                            Colors.lightGreenAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Commit to this Sustainable Swap'),
                  onPressed: () => _onCommitSwitch(impact),
                ),
              ),
              const SizedBox(height: 14),

              // Methodology / How It Works Toggle
              InkWell(
                onTap: () => setState(() => _showMethodology = !_showMethodology),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: EvoraColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science_outlined, size: 18, color: EvoraColors.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Verified Calculation Methodology',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Icon(
                            _showMethodology ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 20,
                            color: EvoraColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (_showMethodology) ...[
                        const SizedBox(height: 10),
                        Text(
                          impact.methodologyExplanation,
                          style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCategoryControls() {
    switch (_selectedCategory) {
      case EvoSwitchCategory.travel:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Commute Distance:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: EvoraColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${_travelDistanceKm.toStringAsFixed(0)} km / day',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: EvoraColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
            Slider(
              value: _travelDistanceKm,
              min: 2,
              max: 50,
              divisions: 24,
              activeColor: EvoraColors.primary,
              onChanged: (v) => setState(() => _travelDistanceKm = v),
            ),
            const SizedBox(height: 10),
            const Text('Switch From Personal Car To:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChoice('Electric City Bus', 'electric_bus', Icons.electric_bolt),
                _buildModeChoice('Electric Scooter', 'ev_scooter', Icons.moped_outlined),
                _buildModeChoice('Two-Wheeler', 'petrol_scooter', Icons.two_wheeler_outlined),
                _buildModeChoice('Bicycle / Walk', 'bicycle_walk', Icons.directions_bike),
              ],
            ),
          ],
        );

      case EvoSwitchCategory.shopping:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Single-Use Water Bottles / Week:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$_bottlesPerWeek bottles', style: const TextStyle(fontWeight: FontWeight.w800, color: EvoraColors.primary)),
              ],
            ),
            Slider(
              value: _bottlesPerWeek.toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              onChanged: (v) => setState(() => _bottlesPerWeek = v.round()),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Plastic Polybags / Week:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$_polybagsPerWeek bags', style: const TextStyle(fontWeight: FontWeight.w800, color: EvoraColors.primary)),
              ],
            ),
            Slider(
              value: _polybagsPerWeek.toDouble(),
              min: 0,
              max: 25,
              divisions: 25,
              onChanged: (v) => setState(() => _polybagsPerWeek = v.round()),
            ),
          ],
        );

      case EvoSwitchCategory.repair:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Item to Repair Instead of Replacing:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRepairChoice('Smartphone / Screen', 'smartphone', Icons.smartphone_outlined),
                _buildRepairChoice('Mixer / Fan Appliance', 'appliance', Icons.kitchen_outlined),
                _buildRepairChoice('Footwear Resoling', 'footwear', Icons.roller_skating_outlined),
                _buildRepairChoice('Bicycle Overhaul', 'bicycle', Icons.pedal_bike_outlined),
              ],
            ),
          ],
        );

      case EvoSwitchCategory.waste:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kitchen Waste Composted / Day:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${_organicKgPerDay.toStringAsFixed(1)} kg/day', style: const TextStyle(fontWeight: FontWeight.w800, color: EvoraColors.primary)),
              ],
            ),
            Slider(
              value: _organicKgPerDay,
              min: 0.2,
              max: 5.0,
              divisions: 24,
              onChanged: (v) => setState(() => _organicKgPerDay = v),
            ),
            const SizedBox(height: 4),
            const Text(
              'Home composting prevents wet waste from decomposing anaerobically in open dumps.',
              style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
            ),
          ],
        );

      case EvoSwitchCategory.energy:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Old Bulbs Replaced with 9W LED:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$_bulbsSwapped bulbs', style: const TextStyle(fontWeight: FontWeight.w800, color: EvoraColors.primary)),
              ],
            ),
            Slider(
              value: _bulbsSwapped.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => setState(() => _bulbsSwapped = v.round()),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AC Temperature Setting:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${18 + _acDegreesRaised}°C (from 18°C)', style: const TextStyle(fontWeight: FontWeight.w800, color: EvoraColors.primary)),
              ],
            ),
            Slider(
              value: _acDegreesRaised.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              onChanged: (v) => setState(() => _acDegreesRaised = v.round()),
            ),
          ],
        );
    }
  }

  Widget _buildModeChoice(String label, String key, IconData icon) {
    final isSelected = _travelMode == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : EvoraColors.primary),
      label: Text(label),
      selected: isSelected,
      selectedColor: EvoraColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : EvoraColors.onSurface,
      ),
      onSelected: (_) => setState(() => _travelMode = key),
    );
  }

  Widget _buildRepairChoice(String label, String key, IconData icon) {
    final isSelected = _repairItemType == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : EvoraColors.primary),
      label: Text(label),
      selected: isSelected,
      selectedColor: EvoraColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : EvoraColors.onSurface,
      ),
      onSelected: (_) => setState(() => _repairItemType = key),
    );
  }
}
