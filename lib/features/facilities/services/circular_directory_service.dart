import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/location_service.dart';
import '../../../services/logging_service.dart';
import '../models/circular_facility_model.dart';

class CircularDirectoryState {
  final List<CircularFacility> allFacilities;
  final List<CircularFacility> filteredFacilities;
  final CircularCategory selectedCategory;
  final String searchQuery;
  final double? maxDistanceKm;
  final bool verifiedOnly;
  final bool isLoading;
  final EvoraLocation userLocation;

  const CircularDirectoryState({
    this.allFacilities = const [],
    this.filteredFacilities = const [],
    this.selectedCategory = CircularCategory.all,
    this.searchQuery = '',
    this.maxDistanceKm,
    this.verifiedOnly = false,
    this.isLoading = false,
    this.userLocation = EvoraLocation.defaultDehradun,
  });

  CircularDirectoryState copyWith({
    List<CircularFacility>? allFacilities,
    List<CircularFacility>? filteredFacilities,
    CircularCategory? selectedCategory,
    String? searchQuery,
    double? maxDistanceKm,
    bool? clearMaxDistance,
    bool? verifiedOnly,
    bool? isLoading,
    EvoraLocation? userLocation,
  }) {
    return CircularDirectoryState(
      allFacilities: allFacilities ?? this.allFacilities,
      filteredFacilities: filteredFacilities ?? this.filteredFacilities,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      maxDistanceKm: (clearMaxDistance == true) ? null : (maxDistanceKm ?? this.maxDistanceKm),
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      isLoading: isLoading ?? this.isLoading,
      userLocation: userLocation ?? this.userLocation,
    );
  }
}

class CircularDirectoryNotifier extends StateNotifier<CircularDirectoryState> {
  final FirebaseFirestore? _firestore;
  static const String _cacheKey = 'evora_circular_facilities_v1';

  CircularDirectoryNotifier([this._firestore])
      : super(
          CircularDirectoryState(
            allFacilities: _applyDistanceCalculations(
              seedFacilities,
              LocationService.currentLocation,
            ),
            filteredFacilities: _applyFilters(
              _applyDistanceCalculations(
                seedFacilities,
                LocationService.currentLocation,
              ),
              const CircularDirectoryState(),
            ),
          ),
        ) {
    initDirectory();
  }

  static const List<CircularFacility> seedFacilities = [
    CircularFacility(
      id: 'fac_kargi_mrf',
      name: 'Kargi Chowk Material Recovery Facility (MRF)',
      category: CircularCategory.recycling,
      address: 'Kargi Chowk, Haridwar Bypass Road',
      locality: 'Dehradun South',
      latitude: 30.2912,
      longitude: 78.0210,
      phone: '+91 135 2652155',
      operatingHours: 'Mon - Sat: 08:00 AM - 05:00 PM',
      acceptedMaterials: [
        'PET Bottles',
        'Cardboard & Paper',
        'High-Density Polyethylene',
        'Multi-Layer Plastics',
        'Tin Cans',
      ],
      isVerifiedPartner: true,
      description:
          'Official municipal material recovery and dry waste segregation facility processing plastic waste for Dehradun Nagar Nigam.',
    ),
    CircularFacility(
      id: 'fac_central_ewaste',
      name: 'Dehradun Central E-Waste & Battery Hub',
      category: CircularCategory.ewaste,
      address: 'Near Clock Tower, Paltan Bazaar',
      locality: 'Dehradun Central',
      latitude: 30.3248,
      longitude: 78.0425,
      phone: '+91 135 2712390',
      operatingHours: 'Tue - Sun: 10:00 AM - 07:00 PM',
      acceptedMaterials: [
        'Old Mobile Phones',
        'Laptops & Chargers',
        'Lithium-ion Batteries',
        'CFL & LED Tubes',
        'Small Appliances',
        'Cables & Adapters',
      ],
      isVerifiedPartner: true,
      description:
          'Authorized hazardous and electronic waste collection point. Certified for safe recycling under Uttarakhand Pollution Control Board guidelines.',
    ),
    CircularFacility(
      id: 'fac_rajpur_compost',
      name: 'Rajpur Road Organic & Composting Depot',
      category: CircularCategory.composting,
      address: 'Near Old Toll Gate, Jakhan',
      locality: 'Rajpur Road',
      latitude: 30.3615,
      longitude: 78.0712,
      phone: '+91 135 2734412',
      operatingHours: 'Mon - Sat: 07:30 AM - 04:30 PM',
      acceptedMaterials: [
        'Kitchen Food Scraps',
        'Pruned Garden Waste',
        'Dry Leaves & Twigs',
        'Vegetable Peels',
        'Used Coffee Grounds',
      ],
      isVerifiedPartner: true,
      description:
          'Community-scale aerobic composting center converting Valley garden and kitchen waste into organic nutrient-rich soil enricher.',
    ),
    CircularFacility(
      id: 'fac_paltan_refill',
      name: 'Doon Heritage Refill & Zero-Waste Hub',
      category: CircularCategory.refill,
      address: 'Shop 14, Heritage Arcade, Paltan Bazaar',
      locality: 'Paltan Bazaar',
      latitude: 30.3228,
      longitude: 78.0398,
      phone: '+91 98971 23456',
      operatingHours: 'Mon - Sat: 10:00 AM - 08:00 PM',
      acceptedMaterials: [
        'Bio-Enzyme Detergent Refill',
        'Cold-Pressed Cooking Oil Dispenser',
        'Cloth Bag Exchange',
        'Glass Jar Deposits',
      ],
      isVerifiedPartner: true,
      description:
          'Zero-single-use packaging grocery and cleaning refill station encouraging residents to bring their own containers.',
    ),
    CircularFacility(
      id: 'fac_dalanwala_repair',
      name: 'Dalanwala Circular Repair & Upcycling Guild',
      category: CircularCategory.repair,
      address: '18 Circular Lane, Dalanwala',
      locality: 'Dalanwala',
      latitude: 30.3280,
      longitude: 78.0550,
      phone: '+91 135 2671188',
      operatingHours: 'Mon - Sat: 10:00 AM - 06:30 PM',
      acceptedMaterials: [
        'Footwear Resoling & Leather Stitching',
        'Ceiling Fan & Motor Rewinding',
        'Mixer Grinder Repair',
        'Bicycle Servicing',
        'Garment Darning & Zipper Fix',
      ],
      isVerifiedPartner: true,
      description:
          'Local artisans cooperative restoring broken household goods, footwear, and bicycles to prevent premature disposal.',
    ),
    CircularFacility(
      id: 'fac_pacific_takeback',
      name: 'Pacific Mall Electronics Takeback Dropoff',
      category: CircularCategory.ewaste,
      address: 'Lower Ground Floor, Pacific Mall, Rajpur Road',
      locality: 'Jakhan',
      latitude: 30.3540,
      longitude: 78.0675,
      phone: '+91 135 6609999',
      operatingHours: 'Daily: 11:00 AM - 09:30 PM',
      acceptedMaterials: [
        'Smartphones & Tablets',
        'Alkaline & Dry Batteries',
        'Headphones & Smartwatches',
        'Plastic Delivery Bubblewrap',
      ],
      isVerifiedPartner: true,
      description:
          'Convenient mall drop-off kiosk in partnership with certified Uttarakhand e-waste aggregators.',
    ),
    CircularFacility(
      id: 'fac_majra_metal',
      name: 'Majra Circular Scrap & Metal Recycling Depot',
      category: CircularCategory.recycling,
      address: 'Plot 7, Transport Nagar Road, Majra',
      locality: 'Majra / ISBT',
      latitude: 30.2970,
      longitude: 78.0080,
      phone: '+91 94120 54321',
      operatingHours: 'Mon - Sat: 09:00 AM - 07:00 PM',
      acceptedMaterials: [
        'Scrap Iron & Steel',
        'Aluminum Utensils',
        'Copper Wire Scrap',
        'Glass Liquor & Sauce Bottles',
        'Old Newsprint & Cardboard',
      ],
      isVerifiedPartner: true,
      description:
          'Organized scrap aggregator guaranteeing fair weighing and verified channel recycling for household recyclables.',
    ),
    CircularFacility(
      id: 'fac_shishambara_plant',
      name: 'Shishambara Integrated Waste & Resource Recovery Plant',
      category: CircularCategory.recycling,
      address: 'Shishambara, Vikas Nagar Highway',
      locality: 'West Doon',
      latitude: 30.3685,
      longitude: 77.8760,
      phone: '+91 135 2798100',
      operatingHours: 'Daily: 07:00 AM - 06:00 PM',
      acceptedMaterials: [
        'Bulk Municipal Dry Waste',
        'Industrial Packaging Scrap',
        'Refuse Derived Fuel (RDF) Raw Plastic',
        'Construction & Demolition Debris',
      ],
      isVerifiedPartner: true,
      description:
          'Regional waste processing complex managing mechanized sorting, compost manufacturing, and energy recovery for Greater Dehradun.',
    ),
  ];

  Future<void> initDirectory() async {
    state = state.copyWith(isLoading: true);
    final loc = LocationService.currentLocation;

    // 1. Try reading from Firestore if online
    List<CircularFacility> facilities = [];
    try {
      final firestore = _firestore;
      if (firestore != null) {
        final snap = await firestore
            .collection('tenants')
            .doc('tenant_dehradun_01')
            .collection('facilities')
            .get();
        if (snap.docs.isNotEmpty) {
          facilities = snap.docs.map((d) => CircularFacility.fromMap(d.data(), id: d.id)).toList();
        }
      }
    } catch (e) {
      LoggingService.logBreadcrumb('Firestore facilities read error: $e');
    }

    // 2. If Firestore empty, use cached or bundled seed data
    if (facilities.isEmpty) {
      final cached = await _loadFromCache();
      facilities = cached.isNotEmpty ? cached : seedFacilities;
    }

    // 3. Compute distances from current user position
    final withDistances = _applyDistanceCalculations(facilities, loc);

    state = state.copyWith(
      allFacilities: withDistances,
      filteredFacilities: _applyFilters(withDistances, state),
      userLocation: loc,
      isLoading: false,
    );

    // Save to cache
    await _saveToCache(withDistances);
  }

  void updateLocation(EvoraLocation newLocation) {
    final updated = _applyDistanceCalculations(state.allFacilities, newLocation);
    state = state.copyWith(
      userLocation: newLocation,
      allFacilities: updated,
      filteredFacilities: _applyFilters(updated, state),
    );
  }

  void selectCategory(CircularCategory category) {
    final nextState = state.copyWith(selectedCategory: category);
    state = nextState.copyWith(
      filteredFacilities: _applyFilters(state.allFacilities, nextState),
    );
  }

  void setSearchQuery(String query) {
    final nextState = state.copyWith(searchQuery: query);
    state = nextState.copyWith(
      filteredFacilities: _applyFilters(state.allFacilities, nextState),
    );
  }

  void setDistanceFilter(double? maxKm) {
    final nextState = state.copyWith(
      maxDistanceKm: maxKm,
      clearMaxDistance: maxKm == null,
    );
    state = nextState.copyWith(
      filteredFacilities: _applyFilters(state.allFacilities, nextState),
    );
  }

  void toggleVerifiedOnly(bool val) {
    final nextState = state.copyWith(verifiedOnly: val);
    state = nextState.copyWith(
      filteredFacilities: _applyFilters(state.allFacilities, nextState),
    );
  }

  List<CircularFacility> getClosestFacilities({int limit = 3}) {
    final list = List<CircularFacility>.from(state.allFacilities);
    list.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    return list.take(limit).toList();
  }

  static List<CircularFacility> _applyDistanceCalculations(
    List<CircularFacility> list,
    EvoraLocation loc,
  ) {
    return list.map((f) {
      final dist = LocationService.calculateDistanceKm(
        startLatitude: loc.latitude,
        startLongitude: loc.longitude,
        endLatitude: f.latitude,
        endLongitude: f.longitude,
      );
      return f.copyWith(distanceKm: dist);
    }).toList();
  }

  static List<CircularFacility> _applyFilters(
    List<CircularFacility> source,
    CircularDirectoryState s,
  ) {
    return source.where((f) {
      // Category filter
      if (s.selectedCategory != CircularCategory.all && f.category != s.selectedCategory) {
        return false;
      }
      // Distance filter
      if (s.maxDistanceKm != null && f.distanceKm != null && f.distanceKm! > s.maxDistanceKm!) {
        return false;
      }
      // Verified only
      if (s.verifiedOnly && !f.isVerifiedPartner) {
        return false;
      }
      // Search query (name, locality, address, or materials)
      if (s.searchQuery.trim().isNotEmpty) {
        final q = s.searchQuery.toLowerCase().trim();
        final matchName = f.name.toLowerCase().contains(q);
        final matchLocality = f.locality.toLowerCase().contains(q);
        final matchAddress = f.address.toLowerCase().contains(q);
        final matchMaterials = f.acceptedMaterials.any((m) => m.toLowerCase().contains(q));
        if (!matchName && !matchLocality && !matchAddress && !matchMaterials) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
  }

  Future<void> _saveToCache(List<CircularFacility> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((e) => e.toMap()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<CircularFacility>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map((e) => CircularFacility.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

final circularDirectoryProvider =
    StateNotifierProvider<CircularDirectoryNotifier, CircularDirectoryState>((ref) {
  return CircularDirectoryNotifier(FirebaseFirestore.instance);
});
