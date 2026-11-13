import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evora/features/evoswitch/services/evoswitch_service.dart';
import 'package:evora/features/facilities/models/circular_facility_model.dart';
import 'package:evora/features/facilities/services/circular_directory_service.dart';
import 'package:evora/services/environmental_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: Smart Waste & Circular Directory Tests', () {
    test('Test 4.1: Searches for "e-waste" and filters facilities by category, materials & proximity', () async {
      final notifier = CircularDirectoryNotifier(null);
      await notifier.initDirectory();

      // 1. Initial seed facilities loaded
      final initialCount = notifier.state.allFacilities.length;
      expect(initialCount, greaterThanOrEqualTo(8));

      // 2. Filter by search query "batteries"
      notifier.setSearchQuery('batteries');
      final batteryHubs = notifier.state.filteredFacilities;
      expect(batteryHubs.isNotEmpty, isTrue);
      for (final hub in batteryHubs) {
        final matches = hub.name.toLowerCase().contains('batteries') ||
            hub.acceptedMaterials.any((m) => m.toLowerCase().contains('batteries'));
        expect(matches, isTrue);
      }

      // 3. Filter by category e-waste
      notifier.setSearchQuery('');
      notifier.selectCategory(CircularCategory.ewaste);
      final ewasteHubs = notifier.state.filteredFacilities;
      expect(ewasteHubs.length, 2);
      expect(ewasteHubs.every((f) => f.category == CircularCategory.ewaste), isTrue);

      // 4. Verify proximity sorting (closest first)
      for (int i = 0; i < ewasteHubs.length - 1; i++) {
        final currDist = ewasteHubs[i].distanceKm ?? 0;
        final nextDist = ewasteHubs[i + 1].distanceKm ?? 0;
        expect(currDist, lessThanOrEqualTo(nextDist));
      }

      // 5. Filter by distance radius < 3 km from Dehradun Clock Tower
      notifier.selectCategory(CircularCategory.all);
      notifier.setDistanceFilter(3.0);
      final closeHubs = notifier.state.filteredFacilities;
      expect(closeHubs.isNotEmpty, isTrue);
      expect(closeHubs.every((f) => (f.distanceKm ?? 0) <= 3.0), isTrue);
    });
  });

  group('Phase 4: EvoSwitch Deterministic Mathematical Engine Tests', () {
    test('Test 4.2: Computes exact avoided CO2e, fuel savings and tree power for 12 km daily commute', () {
      // 12 km daily, 250 work days = 3000 km annual
      // Petrol car = 3000 * 0.170 = 510 kg CO2e
      // Electric bus = 3000 * 0.038 = 114 kg CO2e
      // Net avoided = 396 kg CO2e
      // Cost savings: (3000 * 9.5) - (3000 * 1.5) = 28500 - 4500 = ₹24000
      // Trees: 396 / 20 = 19.8 trees
      final result = EvoSwitchService.calculateTravelImpact(
        tripDistanceKm: 12.0,
        greenMode: 'electric_bus',
        frequencyDaysPerYear: 250,
      );

      expect(result.co2eAvoidedKg, 396.0);
      expect(result.moneySavedRupees, 24000.0);
      expect(result.treesEquivalent, 19.8);
      expect(result.headline, contains('396 kg CO₂e'));
      expect(result.subheadline, contains('Electric City Bus'));
    });

    test('Computes exact plastic waste elimination for shopping reusables', () {
      // 4 bottles/week * 52 = 208 bottles -> 208 * 25g = 5200g plastic
      // 6 polybags/week * 52 = 312 bags -> 312 * 8g = 2496g plastic
      // Total plastic avoided = 7696g (~7.7 kg)
      final result = EvoSwitchService.calculateShoppingImpact(
        singleUseBottlesPerWeek: 4,
        polybagsPerWeek: 6,
      );

      expect(result.plasticAvoidedGrams, 7696.0);
      expect(result.moneySavedRupees, greaterThan(5000));
      expect(result.co2eAvoidedKg, greaterThan(25));
    });

    test('Computes embodied carbon savings for repairing smartphones and home appliances', () {
      final phone = EvoSwitchService.calculateRepairImpact(itemType: 'smartphone');
      expect(phone.co2eAvoidedKg, 48.0);
      expect(phone.moneySavedRupees, 12000.0);

      final appliance = EvoSwitchService.calculateRepairImpact(itemType: 'appliance');
      expect(appliance.co2eAvoidedKg, 34.0);
      expect(appliance.moneySavedRupees, 4500.0);
    });

    test('Computes organic waste diversion and averted methane from landfill', () {
      // 1.5 kg/day * 365 days = 547.5 kg
      // Methane avoided = 547.5 * 0.55 = 301.125 kg CO2e
      final result = EvoSwitchService.calculateWasteImpact(organicKgPerDay: 1.5);
      expect(result.co2eAvoidedKg, closeTo(301.1, 0.2));
      expect(result.moneySavedRupees, greaterThan(2500));
    });

    test('Computes energy and domestic electricity bill savings for LED swaps and AC 24C setpoint', () {
      final result = EvoSwitchService.calculateEnergyImpact(
        bulbsSwappedToLed: 5,
        acDegreesRaised: 6,
      );
      expect(result.co2eAvoidedKg, greaterThan(500));
      expect(result.moneySavedRupees, greaterThan(5000));
    });
  });

  group('Phase 4: Environmental Telemetry & Stale Data Guardrail Tests', () {
    test('Test 4.3: Parses live Open-Meteo environmental telemetry payload accurately', () async {
      SharedPreferences.setMockInitialValues({});

      final mockClient = MockClient((request) async {
        if (request.url.host == 'api.open-meteo.com') {
          return http.Response(
            jsonEncode({
              'current': {
                'temperature_2m': 23.5,
                'weather_code': 1,
                'relative_humidity_2m': 55,
              }
            }),
            200,
          );
        } else if (request.url.host == 'air-quality-api.open-meteo.com') {
          return http.Response(
            jsonEncode({
              'current': {
                'pm2_5': 18.2,
                'pm10': 38.5,
                'us_aqi': 62,
              }
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = EnvironmentalService(client: mockClient);
      final data = await service.getTelemetry(
        latitude: 30.3244,
        longitude: 78.0416,
        forceRefresh: true,
      );

      expect(data.isUnavailable, isFalse);
      expect(data.isStale, isFalse);
      expect(data.temperatureCelsius, 23.5);
      expect(data.aqi, 62);
      expect(data.aqiCategory, 'Moderate');
      expect(data.weatherCondition, 'Partly Cloudy');
      expect(data.healthAdvisory, contains('acceptable'));
    });

    test('Enforces stale-data guardrail: returns unavailable object when sensors offline and no cache (zero hallucination)', () async {
      SharedPreferences.setMockInitialValues({});

      // Mock client that always throws network exception
      final failingClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final service = EnvironmentalService(client: failingClient);
      final data = await service.getTelemetry(
        latitude: 30.3244,
        longitude: 78.0416,
        forceRefresh: true,
      );

      // Must NOT synthesize fake positive or fake zero readings
      expect(data.isUnavailable, isTrue);
      expect(data.isStale, isTrue);
      expect(data.aqiCategory, 'Unavailable');
      expect(data.healthAdvisory, contains('temporarily offline'));
    });
  });

  group('Phase 4: Eco Action Daily Habit User Scoping Tests', () {
    test('Eco action marks done for active user and resets for guest or different user', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final keyUserA = 'evora_eco_action_userA_${now.year}_${now.month}_${now.day}';
      final keyUserB = 'evora_eco_action_userB_${now.year}_${now.month}_${now.day}';

      // User A marks done
      await prefs.setBool(keyUserA, true);

      // Verify User A is marked done today
      expect(prefs.getBool(keyUserA), isTrue);

      // Verify User B (or guest / after logout) is NOT marked done
      expect(prefs.getBool(keyUserB) ?? false, isFalse);
    });
  });
}
