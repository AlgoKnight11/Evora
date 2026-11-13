import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../core/utils/external_launcher.dart';
import '../models/circular_facility_model.dart';
import '../services/circular_directory_service.dart';

class FacilitiesDirectoryScreen extends ConsumerStatefulWidget {
  const FacilitiesDirectoryScreen({super.key});

  @override
  ConsumerState<FacilitiesDirectoryScreen> createState() =>
      _FacilitiesDirectoryScreenState();
}

class _FacilitiesDirectoryScreenState
    extends ConsumerState<FacilitiesDirectoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchDirections(CircularFacility facility) async {
    final success = await ExternalLauncher.launchDirections(
      latitude: facility.latitude,
      longitude: facility.longitude,
      destinationName: facility.name,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps navigation for ${facility.name}'),
          backgroundColor: EvoraColors.error,
        ),
      );
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final success = await ExternalLauncher.launchCall(phone);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not dial phone number: $phone'),
          backgroundColor: EvoraColors.error,
        ),
      );
    }
  }

  void _showFacilityDetails(CircularFacility facility) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final rawBottom = [
          media.padding.bottom,
          media.viewPadding.bottom,
          media.viewInsets.bottom,
        ].reduce((a, b) => a > b ? a : b);
        final bottomInset = rawBottom > 0 ? (rawBottom + 16.0) : 56.0;

        return Container(
          padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset),
          decoration: const BoxDecoration(
            color: EvoraColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EvoraColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(facility.category.icon, color: EvoraColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (facility.isVerifiedPartner)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: EvoraColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 14, color: EvoraColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Verified Municipal Partner',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: EvoraColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          facility.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${facility.locality} • ${facility.distanceFormatted}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: EvoraColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                facility.description,
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: EvoraColors.onSurface),
              ),
              const SizedBox(height: 16),
              const Text(
                'Accepted Materials & Items',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: facility.acceptedMaterials.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: EvoraColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      m,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: EvoraColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      facility.operatingHours,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 18, color: EvoraColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      facility.address,
                      style: const TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Call Facility'),
                      onPressed: () => _launchPhoneCall(facility.phone),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Directions'),
                      onPressed: () => _launchDirections(facility),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(circularDirectoryProvider);
    final notifier = ref.read(circularDirectoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste & Circular Directory'),
        actions: [
          IconButton(
            icon: Icon(
              state.verifiedOnly ? Icons.verified : Icons.verified_outlined,
              color: state.verifiedOnly ? EvoraColors.primary : null,
            ),
            tooltip: 'Verified Partners Only',
            onPressed: () => notifier.toggleVerifiedOnly(!state.verifiedOnly),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Box
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: TextFormField(
                controller: _searchController,
                onChanged: notifier.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search by material (e.g. batteries, plastic, clothes)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: EvoraColors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),

            // Horizontal Category Selector
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                itemCount: CircularCategory.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (ctx, index) {
                  final cat = CircularCategory.values[index];
                  final isSelected = state.selectedCategory == cat;

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
                    onSelected: (_) => notifier.selectCategory(cat),
                  );
                },
              ),
            ),

            // Distance Radius Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  const Text('Radius: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  _buildRadiusChip('All', null, state.maxDistanceKm, notifier.setDistanceFilter),
                  const SizedBox(width: 6),
                  _buildRadiusChip('< 3 km', 3.0, state.maxDistanceKm, notifier.setDistanceFilter),
                  const SizedBox(width: 6),
                  _buildRadiusChip('< 5 km', 5.0, state.maxDistanceKm, notifier.setDistanceFilter),
                  const SizedBox(width: 6),
                  _buildRadiusChip('< 10 km', 10.0, state.maxDistanceKm, notifier.setDistanceFilter),
                  const Spacer(),
                  Text(
                    '${state.filteredFacilities.length} hubs found',
                    style: const TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Facilities List
            Expanded(
              child: state.filteredFacilities.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_outlined, size: 52, color: EvoraColors.outline),
                            const SizedBox(height: 14),
                            const Text(
                              'No Facilities Found',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try searching for another material or selecting a wider distance radius.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EvoraColors.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                                notifier.selectCategory(CircularCategory.all);
                                notifier.setDistanceFilter(null);
                              },
                              child: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      itemCount: state.filteredFacilities.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final item = state.filteredFacilities[index];

                        return InkWell(
                          onTap: () => _showFacilityDetails(item),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: EvoraColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: EvoraColors.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: EvoraColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(item.category.icon, size: 13, color: EvoraColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.category.label,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: EvoraColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (item.distanceFormatted.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          item.distanceFormatted,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.locality,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: EvoraColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: item.acceptedMaterials.take(3).map((m) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: EvoraColors.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        m,
                                        style: const TextStyle(fontSize: 11, color: EvoraColors.onSurface),
                                      ),
                                    );
                                  }).toList()
                                    ..addAll(item.acceptedMaterials.length > 3
                                        ? [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                              child: Text(
                                                '+${item.acceptedMaterials.length - 3} more',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: EvoraColors.primary,
                                                ),
                                              ),
                                            ),
                                          ]
                                        : []),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.phone_outlined, size: 16),
                                        label: const Text('Call'),
                                        onPressed: () => _launchPhoneCall(item.phone),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.directions_outlined, size: 16),
                                        label: const Text('Directions'),
                                        onPressed: () => _launchDirections(item),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusChip(
    String label,
    double? value,
    double? activeValue,
    Function(double?) onSelect,
  ) {
    final isSelected = activeValue == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? EvoraColors.primary : EvoraColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : EvoraColors.onSurface,
          ),
        ),
      ),
    );
  }
}
