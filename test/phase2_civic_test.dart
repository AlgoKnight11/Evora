import 'package:flutter_test/flutter_test.dart';
import 'package:evora/services/location_service.dart';
import 'package:evora/features/civic_book/models/civic_book_model.dart';
import 'package:evora/features/civic_flow/models/civic_flow_model.dart';
import 'package:evora/features/civic_flow/services/civic_flow_service.dart';

void main() {
  group('Phase 2 Location & Spatial Geofence Tests', () {
    test('Calculates Haversine distance between Dehradun Clock Tower and Jakhan', () {
      // Clock Tower: 30.3244, 78.0416
      // Jakhan: 30.3480, 78.0620
      final distance = LocationService.calculateDistanceKm(
        startLatitude: 30.3244,
        startLongitude: 78.0416,
        endLatitude: 30.3480,
        endLongitude: 78.0620,
      );

      // Distance should be approximately 3.3 km
      expect(distance, greaterThan(2.5));
      expect(distance, lessThan(4.5));
    });

    test('Distance formatting formats sub-kilometer and kilometer values', () {
      expect(LocationService.formatDistance(0.45), '450 m away');
      expect(LocationService.formatDistance(2.34), '2.3 km away');
    });

    test('Privacy fuzzing truncates coordinates to 3 decimal places (~100m)', () {
      final fuzzed = LocationService.applyPrivacyFuzzing(30.3244567, 78.0416789);
      expect(fuzzed.lat, 30.324);
      expect(fuzzed.lng, 78.042);
    });
  });

  group('Phase 2 CivicBook Voting & Scoring Tests', () {
    test('Post score computes correctly from upvotes and downvotes', () {
      final post = CivicBookPost(
        id: 'cb_test_01',
        tenantId: 'tenant_dehradun_01',
        authorId: 'u1',
        authorName: 'Test Resident',
        title: 'Waste near Paltan Bazaar',
        description: 'Trash pile on street corner',
        category: 'waste',
        latitude: 30.3244,
        longitude: 78.0416,
        locality: 'Paltan Bazaar',
        upvotesCount: 15,
        downvotesCount: 2,
        createdAt: DateTime.now(),
      );

      expect(post.score, 13);
    });
  });

  group('Phase 2 CivicFlow Grievance & Rate Limiting Tests', () {
    test('CivicFlow status label maps correctly', () {
      expect(CivicFlowStatus.getLabel(CivicFlowStatus.submitted), 'Submitted');
      expect(CivicFlowStatus.getLabel(CivicFlowStatus.inProgress), 'Action In Progress');
      expect(CivicFlowStatus.getLabel(CivicFlowStatus.resolved), 'Resolved');
    });

    test('Rate limiting activates on 3 submissions within 10 minutes', () {
      final now = DateTime.now();
      // 3 submissions in the last 2 minutes
      final activeTimes = [
        now.subtract(const Duration(minutes: 1)),
        now.subtract(const Duration(minutes: 3)),
        now.subtract(const Duration(minutes: 5)),
      ];

      final state = CivicFlowState(recentSubmissionTimes: activeTimes);
      expect(state.isRateLimited, isTrue);
      expect(state.rateLimitCooldownSeconds, greaterThan(0));

      // Expired submissions
      final oldTimes = [
        now.subtract(const Duration(minutes: 15)),
        now.subtract(const Duration(minutes: 20)),
      ];
      final calmState = CivicFlowState(recentSubmissionTimes: oldTimes);
      expect(calmState.isRateLimited, isFalse);
    });
  });
}
