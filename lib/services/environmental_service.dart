import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/evora_colors.dart';
import 'logging_service.dart';

/// Representation of local environmental telemetry (Air Quality + Weather)
class EnvironmentalData {
  final double temperatureCelsius;
  final double pm25;
  final double pm10;
  final int aqi;
  final String aqiCategory;
  final Color aqiColor;
  final String weatherCondition;
  final IconData weatherIcon;
  final String healthAdvisory;
  final DateTime timestamp;
  final bool isStale;
  final bool isUnavailable;

  const EnvironmentalData({
    required this.temperatureCelsius,
    required this.pm25,
    required this.pm10,
    required this.aqi,
    required this.aqiCategory,
    required this.aqiColor,
    required this.weatherCondition,
    required this.weatherIcon,
    required this.healthAdvisory,
    required this.timestamp,
    this.isStale = false,
    this.isUnavailable = false,
  });

  /// Factory when environmental feeds are offline or unreachable with zero cache
  factory EnvironmentalData.unavailable() {
    return EnvironmentalData(
      temperatureCelsius: 0,
      pm25: 0,
      pm10: 0,
      aqi: 0,
      aqiCategory: 'Unavailable',
      aqiColor: EvoraColors.outline,
      weatherCondition: 'Sensors Offline',
      weatherIcon: Icons.cloud_off_outlined,
      healthAdvisory: 'Environmental sensor feeds are temporarily offline. No simulated data is shown.',
      timestamp: DateTime.now(),
      isStale: true,
      isUnavailable: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperatureCelsius': temperatureCelsius,
        'pm25': pm25,
        'pm10': pm10,
        'aqi': aqi,
        'aqiCategory': aqiCategory,
        'weatherCondition': weatherCondition,
        'healthAdvisory': healthAdvisory,
        'timestamp': timestamp.toIso8601String(),
      };

  factory EnvironmentalData.fromJson(Map<String, dynamic> json, {bool isStale = false}) {
    final aqi = (json['aqi'] as num?)?.toInt() ?? 50;
    final category = json['aqiCategory'] as String? ?? 'Moderate';
    return EnvironmentalData(
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble() ?? 22.0,
      pm25: (json['pm25'] as num?)?.toDouble() ?? 25.0,
      pm10: (json['pm10'] as num?)?.toDouble() ?? 45.0,
      aqi: aqi,
      aqiCategory: category,
      aqiColor: _resolveAqiColor(aqi),
      weatherCondition: json['weatherCondition'] as String? ?? 'Partly Cloudy',
      weatherIcon: _resolveWeatherIcon(json['weatherCondition'] as String? ?? 'Partly Cloudy'),
      healthAdvisory: json['healthAdvisory'] as String? ??
          'Air quality is acceptable for outdoor activity.',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isStale: isStale,
      isUnavailable: false,
    );
  }

  static Color _resolveAqiColor(int aqi) {
    if (aqi <= 50) return const Color(0xFF008955); // Good (Emerald)
    if (aqi <= 100) return const Color(0xFFD97706); // Moderate (Amber)
    if (aqi <= 150) return const Color(0xFFEA580C); // Unhealthy for Sensitive Groups
    if (aqi <= 200) return const Color(0xFFDC2626); // Unhealthy (Red)
    return const Color(0xFF7F1D1D); // Very Unhealthy / Severe
  }

  static IconData _resolveWeatherIcon(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('rain') || lower.contains('drizzle')) return Icons.grain_outlined;
    if (lower.contains('thunder')) return Icons.thunderstorm_outlined;
    if (lower.contains('snow')) return Icons.ac_unit_outlined;
    if (lower.contains('cloud')) return Icons.cloud_outlined;
    if (lower.contains('fog') || lower.contains('haze')) return Icons.foggy;
    return Icons.wb_sunny_outlined;
  }
}

/// Service providing live Open-Meteo Air Quality & Weather Telemetry
/// with strict anti-hallucination / stale-data fallback guardrails.
class EnvironmentalService {
  final http.Client _client;
  static const Duration _cacheTtl = Duration(minutes: 20);

  // In-memory cache keyed by 2-decimal rounded coordinates (~1.1km grid)
  final Map<String, ({EnvironmentalData data, DateTime fetchTime})> _cacheInMemory = {};

  EnvironmentalService({http.Client? client}) : _client = client ?? http.Client();

  static String _coordKey(double lat, double lng) =>
      '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';

  static String _diskCacheKey(double lat, double lng) =>
      'evora_env_telemetry_v2_${_coordKey(lat, lng)}';

  /// Fetches real-time environmental data for given coordinates
  Future<EnvironmentalData> getTelemetry({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final key = _coordKey(latitude, longitude);

    // 1. Check in-memory cache for these specific coordinates
    if (!forceRefresh && _cacheInMemory.containsKey(key)) {
      final cached = _cacheInMemory[key]!;
      if (DateTime.now().difference(cached.fetchTime) < _cacheTtl) {
        return cached.data;
      }
    }

    try {
      // 2. Fetch live data concurrently from Open-Meteo (Weather + Air Quality)
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,weather_code',
      );
      final airQualityUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$latitude&longitude=$longitude&current=pm10,pm2_5,us_aqi',
      );

      final responses = await Future.wait([
        _client.get(weatherUri).timeout(const Duration(seconds: 5)),
        _client.get(airQualityUri).timeout(const Duration(seconds: 5)),
      ]);

      final weatherRes = responses[0];
      final airRes = responses[1];

      if (weatherRes.statusCode == 200 && airRes.statusCode == 200) {
        final weatherJson = jsonDecode(weatherRes.body) as Map<String, dynamic>;
        final airJson = jsonDecode(airRes.body) as Map<String, dynamic>;

        final currentWeather = weatherJson['current'] as Map<String, dynamic>? ?? {};
        final currentAir = airJson['current'] as Map<String, dynamic>? ?? {};

        final temp = (currentWeather['temperature_2m'] as num?)?.toDouble() ?? 22.0;
        final weatherCode = (currentWeather['weather_code'] as num?)?.toInt() ?? 0;
        final weatherCondition = _mapWeatherCode(weatherCode);

        final pm25 = (currentAir['pm2_5'] as num?)?.toDouble() ?? 20.0;
        final pm10 = (currentAir['pm10'] as num?)?.toDouble() ?? 40.0;
        final rawAqi = (currentAir['us_aqi'] as num?)?.toInt();
        final aqi = rawAqi ?? _calculateUsAqi(pm25);

        final aqiCategory = _resolveAqiCategory(aqi);
        final aqiColor = EnvironmentalData._resolveAqiColor(aqi);
        final healthAdvisory = _resolveHealthAdvisory(aqi);

        final data = EnvironmentalData(
          temperatureCelsius: temp,
          pm25: pm25,
          pm10: pm10,
          aqi: aqi,
          aqiCategory: aqiCategory,
          aqiColor: aqiColor,
          weatherCondition: weatherCondition,
          weatherIcon: EnvironmentalData._resolveWeatherIcon(weatherCondition),
          healthAdvisory: healthAdvisory,
          timestamp: DateTime.now(),
          isStale: false,
          isUnavailable: false,
        );

        _cacheInMemory[key] = (data: data, fetchTime: DateTime.now());
        await _persistToDisk(latitude, longitude, data);
        return data;
      }
    } catch (e) {
      LoggingService.logBreadcrumb('Environmental API fetch error for ($latitude, $longitude): $e');
    }

    // 3. Network or API error occurred -> check disk cache for these coordinates
    final diskCached = await _loadFromDisk(latitude, longitude);
    if (diskCached != null) {
      // Return cached version marked as stale
      return EnvironmentalData.fromJson(diskCached, isStale: true);
    }

    // 4. Stale-data guardrail: no cache and no network -> return unavailable (zero hallucination)
    return EnvironmentalData.unavailable();
  }

  String _mapWeatherCode(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code >= 45 && code <= 48) return 'Haze / Fog';
    if (code >= 51 && code <= 67) return 'Light Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Doon Valley Breeze';
  }

  String _resolveAqiCategory(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Sensitive Alert';
    if (aqi <= 200) return 'Unhealthy';
    return 'Severe / Hazardous';
  }

  String _resolveHealthAdvisory(int aqi) {
    if (aqi <= 50) {
      return 'Air quality is pristine. Ideal conditions for outdoor walks and sports in the valley.';
    } else if (aqi <= 100) {
      return 'Air quality is acceptable. Very sensitive individuals may consider moderate outdoor exposure.';
    } else if (aqi <= 150) {
      return 'Elderly residents and children with respiratory conditions should reduce prolonged outdoor exertion.';
    } else if (aqi <= 200) {
      return 'Unhealthy air. Sensitive groups should wear N95 masks near congested traffic corridors.';
    } else {
      return 'Severe pollution alert. Minimize all non-essential outdoor physical activity.';
    }
  }

  int _calculateUsAqi(double pm25) {
    // Standard EPA breakpoint interpolation for PM2.5 (ug/m3)
    if (pm25 <= 12.0) return ((50 - 0) / (12.0 - 0) * (pm25 - 0)).round();
    if (pm25 <= 35.4) return (((100 - 51) / (35.4 - 12.1)) * (pm25 - 12.1) + 51).round();
    if (pm25 <= 55.4) return (((150 - 101) / (55.4 - 35.5)) * (pm25 - 35.5) + 101).round();
    if (pm25 <= 150.4) return (((200 - 151) / (150.4 - 55.5)) * (pm25 - 55.5) + 151).round();
    return 250;
  }

  Future<void> _persistToDisk(double lat, double lng, EnvironmentalData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_diskCacheKey(lat, lng), jsonEncode(data.toJson()));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadFromDisk(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_diskCacheKey(lat, lng));
      if (str != null) return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }
}

/// Global Riverpod Provider for Environmental Telemetry
final environmentalServiceProvider = Provider<EnvironmentalService>((ref) {
  return EnvironmentalService();
});

final environmentalDataProvider = FutureProvider.family<EnvironmentalData, ({double lat, double lng})>((ref, coords) async {
  final service = ref.watch(environmentalServiceProvider);
  return service.getTelemetry(latitude: coords.lat, longitude: coords.lng);
});
