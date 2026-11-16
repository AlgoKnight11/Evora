import 'package:flutter/material.dart';

/// Category of circular and waste facilities
enum CircularCategory {
  all,
  ewaste,
  recycling,
  composting,
  refill,
  repair;

  String get label {
    switch (this) {
      case CircularCategory.all:
        return 'All Hubs';
      case CircularCategory.ewaste:
        return 'E-Waste & Batteries';
      case CircularCategory.recycling:
        return 'Dry Waste & Plastic';
      case CircularCategory.composting:
        return 'Organic & Composting';
      case CircularCategory.refill:
        return 'Refill & Zero-Waste';
      case CircularCategory.repair:
        return 'Repair & Upcycling';
    }
  }

  IconData get icon {
    switch (this) {
      case CircularCategory.all:
        return Icons.hub_outlined;
      case CircularCategory.ewaste:
        return Icons.battery_charging_full_outlined;
      case CircularCategory.recycling:
        return Icons.recycling_outlined;
      case CircularCategory.composting:
        return Icons.eco_outlined;
      case CircularCategory.refill:
        return Icons.water_drop_outlined;
      case CircularCategory.repair:
        return Icons.build_circle_outlined;
    }
  }

  static CircularCategory fromString(String key) {
    return CircularCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == key.toLowerCase(),
      orElse: () => CircularCategory.recycling,
    );
  }
}

/// Official or community verified circular economy facility in Uttarakhand
class CircularFacility {
  final String id;
  final String name;
  final CircularCategory category;
  final String address;
  final String locality;
  final double latitude;
  final double longitude;
  final String phone;
  final String operatingHours;
  final List<String> acceptedMaterials;
  final bool isVerifiedPartner;
  final String description;
  final double? distanceKm;

  const CircularFacility({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.locality,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.operatingHours,
    required this.acceptedMaterials,
    this.isVerifiedPartner = true,
    required this.description,
    this.distanceKm,
  });

  String get distanceFormatted {
    if (distanceKm == null) return '';
    if (distanceKm! < 1.0) {
      final meters = (distanceKm! * 1000).round();
      return '$meters m away';
    }
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  CircularFacility copyWith({
    double? distanceKm,
  }) {
    return CircularFacility(
      id: id,
      name: name,
      category: category,
      address: address,
      locality: locality,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      operatingHours: operatingHours,
      acceptedMaterials: acceptedMaterials,
      isVerifiedPartner: isVerifiedPartner,
      description: description,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'address': address,
      'locality': locality,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'operatingHours': operatingHours,
      'acceptedMaterials': acceptedMaterials,
      'isVerifiedPartner': isVerifiedPartner,
      'description': description,
    };
  }

  factory CircularFacility.fromMap(Map<String, dynamic> map, {String? id, double? distanceKm}) {
    final rawCategory = map['category'] as String? ?? 'recycling';
    return CircularFacility(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Municipal Facility',
      category: CircularCategory.fromString(rawCategory),
      address: map['address'] as String? ?? '',
      locality: map['locality'] as String? ?? 'Dehradun',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 30.3244,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 78.0416,
      phone: map['phone'] as String? ?? '',
      operatingHours: map['operatingHours'] as String? ?? 'Mon-Sat: 09:00 AM - 06:00 PM',
      acceptedMaterials: (map['acceptedMaterials'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isVerifiedPartner: map['isVerifiedPartner'] as bool? ?? true,
      description: map['description'] as String? ?? '',
      distanceKm: distanceKm,
    );
  }
}
