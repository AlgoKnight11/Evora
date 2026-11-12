import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'logging_service.dart';

/// User Geo-Location Representation
class EvoraLocation {
  final double latitude;
  final double longitude;
  final String localityName;
  final bool isLiveGps;

  const EvoraLocation({
    required this.latitude,
    required this.longitude,
    required this.localityName,
    this.isLiveGps = false,
  });

  /// Default Dehradun Central Fallback (Ghanta Ghar / Clock Tower coordinates)
  static const EvoraLocation defaultDehradun = EvoraLocation(
    latitude: 30.3244,
    longitude: 78.0416,
    localityName: 'Dehradun Central (Clock Tower)',
    isLiveGps: false,
  );
}

/// Service managing device location permissions, GPS coordinate polling,
/// and spatial distance calculations for geofenced feeds.
class LocationService {
  static EvoraLocation _cachedLocation = EvoraLocation.defaultDehradun;

  static EvoraLocation get currentLocation => _cachedLocation;

  /// Check current permission status without prompting
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('[LocationService] Check permission error: $e');
      return LocationPermission.denied;
    }
  }

  /// Request runtime location permission and acquire live coordinates
  static Future<EvoraLocation> acquireLocation({bool requestIfNeeded = true}) async {
    final cid = LoggingService.generateCorrelationId();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfNeeded) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        LoggingService.logBreadcrumb('Location permission denied ($permission). Using fallback.', correlationId: cid);
        return _cachedLocation;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        LoggingService.logBreadcrumb('Location service disabled on device. Using fallback.', correlationId: cid);
        return _cachedLocation;
      }

      // Permission granted; obtain accurate coordinates with timeout
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _cachedLocation = EvoraLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        localityName: _resolveLocalityFromCoordinates(position.latitude, position.longitude),
        isLiveGps: true,
      );

      LoggingService.logBreadcrumb(
        'Acquired live GPS: ${_cachedLocation.latitude.toStringAsFixed(4)}, ${_cachedLocation.longitude.toStringAsFixed(4)} (${_cachedLocation.localityName})',
        correlationId: cid,
      );

      return _cachedLocation;
    } catch (e) {
      LoggingService.logError('Location acquisition error: $e', correlationId: cid);
      return _cachedLocation;
    }
  }

  /// Calculates Haversine distance in kilometers between two lat/long points
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );
      return distanceInMeters / 1000.0;
    } catch (_) {
      // Manual Haversine fallback if native engine fails
      const double earthRadiusKm = 6371.0;
      final dLat = _degreesToRadians(endLatitude - startLatitude);
      final dLon = _degreesToRadians(endLongitude - startLongitude);

      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(_degreesToRadians(startLatitude)) *
              cos(_degreesToRadians(endLatitude)) *
              sin(dLon / 2) *
              sin(dLon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return earthRadiusKm * c;
    }
  }

  /// Format distance into a human-friendly string (e.g. '400 m away' or '2.4 km away')
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km away';
    }
  }

  /// Privacy-preserving coordinate fuzzing for citizen safety
  /// Truncates precision to ~100m radius so home coordinates are never exposed
  static ({double lat, double lng}) applyPrivacyFuzzing(double lat, double lng) {
    final fuzzedLat = double.parse(lat.toStringAsFixed(3));
    final fuzzedLng = double.parse(lng.toStringAsFixed(3));
    return (lat: fuzzedLat, lng: fuzzedLng);
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Offline locality resolver for common Dehradun neighborhoods
  static String _resolveLocalityFromCoordinates(double lat, double lng) {
    if (lat > 30.36) return 'Rajpur Road / Malsi';
    if (lat > 30.34) return 'Jakhan / Pacific Mall';
    if (lat > 30.32) return 'Dehradun Central / Paltan Bazaar';
    if (lat > 30.30) return 'ISBT / Saharanpur Road';
    return 'Doon Valley Municipal Area';
  }
}
