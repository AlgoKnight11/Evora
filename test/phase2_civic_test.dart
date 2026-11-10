import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evora/features/auth/models/user_model.dart';
import 'package:evora/features/auth/services/auth_service.dart';
import 'package:evora/features/civic_book/models/civic_book_model.dart';
import 'package:evora/features/civic_book/services/civic_book_service.dart';
import 'package:evora/features/civic_flow/models/civic_flow_model.dart';
import 'package:evora/features/civic_flow/services/civic_flow_service.dart';
import 'package:evora/services/location_service.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(EvoraUser testUser) : super(null) {
    state = AuthState(user: testUser);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = EvoraUser(
    uid: 'user_test_001',
    displayName: 'Bhavya Sharma',
    tenantId: 'tenant_dehradun_01',
    selectedLocality: 'Dehradun Central',
    createdAt: DateTime(2026, 11, 10),
  );

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

  group('Phase 2 CivicBook Voting, Scoring & Real-Only Comments Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

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

    test('CivicBook starts empty with zero static/seed posts', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testUser)),
          civicBookProvider.overrideWith((ref) => CivicBookNotifier(ref, null, false)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(civicBookProvider.notifier);
      await notifier.refreshPosts();

      final state = container.read(civicBookProvider);
      expect(state.allPosts, isEmpty);
      expect(state.filteredPosts, isEmpty);
    });

    test('Creating a post and adding real comments surfaces and persists only actual user data', () async {
      final container1 = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testUser)),
          civicBookProvider.overrideWith((ref) => CivicBookNotifier(ref, null, false)),
        ],
      );

      final notifier1 = container1.read(civicBookProvider.notifier);
      final created = await notifier1.createPost(
        title: 'Overflowing drain on Rajpur Road',
        description: 'Stormwater drain blocked with plastic debris after rain.',
        category: 'water',
      );
      expect(created, isTrue);

      final post = container1.read(civicBookProvider).allPosts.single;
      expect(post.authorName, 'Bhavya Sharma');
      expect(post.commentsCount, 0);

      await notifier1.loadComments(post.id);
      expect(container1.read(civicBookProvider).commentsByPost[post.id], isEmpty);

      final commented = await notifier1.addComment(post.id, 'Municipal van should clear this today.');
      expect(commented, isTrue);

      final stateAfterComment = container1.read(civicBookProvider);
      final comments = stateAfterComment.commentsByPost[post.id]!;
      expect(comments.length, 1);
      expect(comments.first.authorName, 'Bhavya Sharma');
      expect(comments.first.text, 'Municipal van should clear this today.');
      expect(stateAfterComment.allPosts.single.commentsCount, 1);
      container1.dispose();

      // Simulate fresh app launch loading from persisted local store
      final container2 = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testUser)),
          civicBookProvider.overrideWith((ref) => CivicBookNotifier(ref, null, false)),
        ],
      );
      addTearDown(container2.dispose);

      final notifier2 = container2.read(civicBookProvider.notifier);
      await notifier2.refreshPosts();
      await notifier2.loadComments(post.id);

      final restoredState = container2.read(civicBookProvider);
      expect(restoredState.allPosts.length, 1);
      expect(restoredState.commentsByPost[post.id]?.length, 1);
      expect(
        restoredState.commentsByPost[post.id]?.first.text,
        'Municipal van should clear this today.',
      );
    });
  });

  group('Phase 2 CivicFlow Grievance & Rate Limiting Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CivicFlow status label maps correctly', () {
      expect(CivicFlowStatus.getLabel(CivicFlowStatus.submitted), 'Submitted');
      expect(CivicFlowStatus.getLabel(CivicFlowStatus.inProgress), 'Action In Progress');
      expect(CivicFlowStatus.getLabel(CivicFlowStatus.resolved), 'Resolved');
    });

    test('CivicFlow starts empty with zero static sample cases', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testUser)),
          civicFlowProvider.overrideWith((ref) => CivicFlowNotifier(ref, null, false)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(civicFlowProvider.notifier);
      await notifier.fetchCitizenCases();

      expect(container.read(civicFlowProvider).citizenCases, isEmpty);
    });

    test('Rate limiting activates on 3 submissions within 10 minutes with accurate cooldown', () {
      final now = DateTime.now();
      // 3 submissions, newest first (same order as CivicFlowNotifier.submitCase)
      final activeTimes = [
        now.subtract(const Duration(minutes: 1)),
        now.subtract(const Duration(minutes: 3)),
        now.subtract(const Duration(minutes: 8)),
      ];

      final state = CivicFlowState(recentSubmissionTimes: activeTimes);
      expect(state.isRateLimited, isTrue);
      // Oldest was 8 minutes ago -> ~2 minutes (<= 130s) remaining
      expect(state.rateLimitCooldownSeconds, greaterThan(60));
      expect(state.rateLimitCooldownSeconds, lessThanOrEqualTo(130));

      // Expired submissions
      final oldTimes = [
        now.subtract(const Duration(minutes: 15)),
        now.subtract(const Duration(minutes: 20)),
      ];
      final calmState = CivicFlowState(recentSubmissionTimes: oldTimes);
      expect(calmState.isRateLimited, isFalse);
      expect(calmState.rateLimitCooldownSeconds, 0);
    });
  });
}
