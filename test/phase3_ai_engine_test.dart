import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evora/features/ai_engine/models/civic_ai_models.dart';
import 'package:evora/features/ai_engine/services/duplicate_detector_service.dart';
import 'package:evora/features/ai_engine/widgets/duplicate_alert_sheet.dart';
import 'package:evora/features/auth/models/user_model.dart';
import 'package:evora/features/auth/services/auth_service.dart';
import 'package:evora/features/civic_book/models/civic_book_model.dart';
import 'package:evora/features/civic_flow/models/civic_flow_model.dart';
import 'package:evora/features/civic_flow/models/civic_taxonomy.dart';
import 'package:evora/features/civic_flow/services/civic_flow_service.dart';
import 'package:evora/services/ai_gateway_service.dart';
import 'package:evora/services/device_permission_service.dart';
import 'package:evora/services/pii_redaction_service.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(EvoraUser? testUser) : super(null) {
    state = AuthState(user: testUser);
  }
}

Uint8List _createSampleImageBytes({int width = 120, int height = 120}) {
  final image = img.Image(width: width, height: height);
  // Fill clean background
  img.fill(image, color: img.ColorRgb8(240, 240, 240));
  // Draw high-contrast checkerboard inside (12..48, 12..48) representing a face/plate region
  for (int y = 12; y < 48; y++) {
    for (int x = 12; x < 48; x++) {
      final isDark = ((x + y) % 2 == 0);
      image.setPixelRgba(
        x,
        y,
        isDark ? 10 : 250,
        isDark ? 10 : 250,
        isDark ? 10 : 250,
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

String _mockInteractionJson({
  bool valid = true,
  String category = 'Drainage & Waterlogging',
  String subcategory = 'Blocked Stormwater Drain',
  double confidence = 0.94,
  String severity = 'high',
  String leadDept = 'Stormwater & Drainage Wing',
  List<Map<String, dynamic>>? involvedDepartments,
  List<Map<String, dynamic>>? piiRegions,
}) {
  final payload = {
    'is_valid_civic_issue': valid,
    if (!valid) 'rejection_reason': 'Not a valid civic or municipal issue photo.',
    'category': category,
    'subcategory': subcategory,
    'confidence': confidence,
    'severity': severity,
    'suggested_title': 'Blocked drain damaging adjoining asphalt road',
    'suggested_description':
        'Stormwater drain overflow has eroded road shoulder near exposed street pole.',
    'lead_department': leadDept,
    'involved_departments': involvedDepartments ??
        [
          {
            'department': leadDept,
            'role': 'lead',
            'reason': 'Unblock clogged stormwater culvert.',
          },
          {
            'department': 'PWD / Road Engineering Wing',
            'role': 'supporting',
            'reason': 'Repair water-damaged road edge pothole.',
          },
          {
            'department': 'Electricity / Streetlight Wing',
            'role': 'supporting',
            'reason': 'Secure leaning streetlight junction box.',
          },
        ],
    'pii_regions': piiRegions ??
        [
          {'label': 'face', 'ymin': 100, 'xmin': 100, 'ymax': 400, 'xmax': 400},
          {'label': 'license_plate', 'ymin': 600, 'xmin': 500, 'ymax': 780, 'xmax': 850},
        ],
    'issue_fingerprint': 'blocked drain pothole road damage electrical wire',
  };

  return jsonEncode({
    'id': 'int_test_001',
    'status': 'completed',
    'steps': [
      {
        'type': 'model_output',
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(payload),
          }
        ],
      }
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = EvoraUser(
    uid: 'user_phase3_001',
    displayName: 'Bhavya Sharma',
    tenantId: 'tenant_dehradun_01',
    selectedLocality: 'Dehradun Central',
    createdAt: DateTime(2026, 11, 11),
  );

  group('Phase 3 Vision Classification & Multi-Department Routing Tests', () {
    test('Parses Interactions API response with Multi-Department Routing & PII boxes', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('/v1beta/interactions'));
        expect(request.headers['Api-Revision'], '2026-05-20');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gemini-3.8-flash');
        expect(body['store'], isFalse);
        return http.Response(_mockInteractionJson(), 200);
      });

      final gateway = AiGatewayService(
        client: mockClient,
        apiKeyOverride: 'test_ai_key_12345',
      );

      final result = await gateway.analyzeCivicIssueImage(
        imageBytes: _createSampleImageBytes(),
        compressImage: false,
      );

      expect(result.isValidCivicIssue, isTrue);
      expect(result.category, 'Drainage & Waterlogging');
      expect(result.subcategory, 'Blocked Stormwater Drain');
      expect(result.confidencePercent, 94);
      expect(result.severity, 'high');
      expect(result.isMultiDepartment, isTrue);
      expect(result.leadDepartment, 'Stormwater & Drainage Wing');
      expect(result.requiredDepartments.length, 3);
      expect(
        result.requiredDepartments,
        containsAll([
          'Stormwater & Drainage Wing',
          'PWD / Road Engineering Wing',
          'Electricity / Streetlight Wing',
        ]),
      );
      expect(result.piiRegions.length, 2);
    });

    test('Normalizes out-of-vocabulary predictions strictly into official CivicTaxonomy enums', () {
      expect(CivicTaxonomy.normalizeCategory('pothole damage'), 'Roads & Footpaths');
      expect(CivicTaxonomy.normalizeCategory('trash overflow'), 'Solid Waste');
      expect(CivicTaxonomy.normalizeDepartment('UPCL streetlight wire'), 'Electricity / Streetlight Wing');
      expect(
        CivicTaxonomy.normalizeSubcategory('Roads & Footpaths', 'big pothole on road'),
        'Dangerous Pothole',
      );
    });

    test('CivicFlowNotifier persists Multi-Department fields and supporter count', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testUser)),
          civicFlowProvider.overrideWith((ref) => CivicFlowNotifier(ref, null, false)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(civicFlowProvider.notifier);
      final caseNumber = await notifier.submitCase(
        category: 'Drainage & Waterlogging',
        subcategory: 'Blocked Stormwater Drain',
        description: 'Blocked drain overflowing onto broken road next to street pole.',
        locality: 'Rajpur Road',
        assignedDepartment: 'Stormwater & Drainage Wing',
        requiredDepartments: const [
          'Stormwater & Drainage Wing',
          'PWD / Road Engineering Wing',
        ],
        departmentReasons: const {
          'Stormwater & Drainage Wing': 'Unclog blocked drain.',
          'PWD / Road Engineering Wing': 'Patch eroded road shoulder.',
        },
        aiConfidence: 0.92,
        piiRedactedCount: 2,
        embeddingVector: const [0.8, 0.6],
      );

      expect(caseNumber, isNotNull);
      final savedCase = container.read(civicFlowProvider).citizenCases.single;
      expect(savedCase.isMultiDepartment, isTrue);
      expect(savedCase.requiredDepartments.length, 2);
      expect(savedCase.aiConfidence, 0.92);
      expect(savedCase.piiRedactedCount, 2);

      await notifier.supportExistingCase(savedCase.id);
      expect(container.read(civicFlowProvider).citizenCases.single.supportersCount, 2);
    });
  });

  group('Phase 3 PII Auto-Redaction & EXIF Stripping Tests', () {
    test('Pixelates face and plate bounding boxes while leaving outer background intact', () async {
      final rawBytes = _createSampleImageBytes(width: 100, height: 100);
      final decodedBefore = img.decodeImage(rawBytes)!;
      final outsideCornerBefore = decodedBefore.getPixel(95, 95);

      final redaction = await PiiRedactionService.redactBytes(
        sourceBytes: rawBytes,
        regions: const [
          PiiBoundingBox(label: 'face', ymin: 120, xmin: 120, ymax: 480, xmax: 480),
          PiiBoundingBox(label: 'license_plate', ymin: 650, xmin: 550, ymax: 750, xmax: 750),
        ],
      );

      expect(redaction.facesBlurred, 1);
      expect(redaction.platesBlurred, 1);
      expect(redaction.totalRedacted, 2);

      final decodedAfter = img.decodeImage(Uint8List.fromList(redaction.bytes))!;
      final outsideCornerAfter = decodedAfter.getPixel(95, 95);
      // Outer margin should remain near bright uniform gray/white (~240)
      expect((outsideCornerAfter.r - outsideCornerBefore.r).abs(), lessThan(15));

      // Inside pixelation box should now be smoothed near mid-gray (~130) instead of alternating 10/250
      final insidePixel = decodedAfter.getPixel(30, 30);
      expect(insidePixel.r, greaterThan(60));
      expect(insidePixel.r, lessThan(200));
    });
  });

  group('Phase 3 Geospatial 500m & Semantic Duplicate Detector Tests', () {
    test('Test 3.2: Triggers duplicate alert within 500m and ignores >500m or resolved cases', () async {
      final detector = DuplicateDetectorService(null);

      // Clock Tower Dehradun: 30.3244, 78.0416
      // Nearby (~55m north): 30.3249, 78.0416
      // Far (~1.2km north): 30.3352, 78.0416
      final activeNearbyCase = CivicFlowCase(
        id: 'cf_near_01',
        caseNumber: 'CF-2026-888111',
        tenantId: 'tenant_dehradun_01',
        citizenId: 'other_user',
        citizenName: 'Rohan',
        category: 'Solid Waste',
        subcategory: 'Garbage Dump Overflow',
        description: 'Huge overflowing garbage heap blocking lane near clock tower',
        locality: 'Dehradun Central',
        latitude: 30.3244,
        longitude: 78.0416,
        embeddingVector: const [0.95, 0.31, 0.0],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final resolvedSameSpotCase = CivicFlowCase(
        id: 'cf_resolved_02',
        caseNumber: 'CF-2026-111222',
        tenantId: 'tenant_dehradun_01',
        citizenId: 'other_user',
        citizenName: 'Anita',
        category: 'Solid Waste',
        subcategory: 'Garbage Dump Overflow',
        description: 'Garbage cleared last month',
        locality: 'Dehradun Central',
        latitude: 30.3244,
        longitude: 78.0416,
        status: CivicFlowStatus.resolved,
        embeddingVector: const [0.95, 0.31, 0.0],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final farPost = CivicBookPost(
        id: 'cb_far_01',
        tenantId: 'tenant_dehradun_01',
        authorId: 'u2',
        authorName: 'Vikram',
        title: 'Garbage pile overflow',
        description: 'Uncollected garbage dump',
        category: 'waste',
        latitude: 30.3352,
        longitude: 78.0416,
        locality: 'Dalanwala',
        embeddingVector: const [0.95, 0.31, 0.0],
        createdAt: DateTime.now(),
      );

      final matches = await detector.findNearbyDuplicates(
        latitude: 30.3249,
        longitude: 78.0416,
        category: 'Solid Waste',
        subcategory: 'Garbage Dump Overflow',
        summaryText: 'Garbage dump overflowing on road corner',
        embeddingVector: const [0.94, 0.34, 0.0],
        inMemoryCases: [activeNearbyCase, resolvedSameSpotCase],
        inMemoryPosts: [farPost],
      );

      expect(matches.length, 1);
      expect(matches.single.sourceId, 'cf_near_01');
      expect(matches.single.distanceMeters, lessThan(100));
      expect(matches.single.matchPercent, greaterThanOrEqualTo(90));
    });
  });

  group('Phase 3 Concurrency, Queueing & Rate-Limit Backoff Tests', () {
    test('Test 3.3: Simulates 50 concurrent vision requests with bounded concurrency & 429 retries', () async {
      int httpCallCount = 0;
      final mockClient = MockClient((request) async {
        httpCallCount++;
        // Simulate transient HTTP 429 throttling on first 5 calls
        if (httpCallCount <= 5) {
          return http.Response(
            '{"error":{"message":"Quota burst limit exceeded"}}',
            429,
          );
        }
        await Future.delayed(const Duration(milliseconds: 5));
        return http.Response(_mockInteractionJson(), 200);
      });

      final gateway = AiGatewayService(
        client: mockClient,
        apiKeyOverride: 'test_key_concurrency',
        maxConcurrent: 3,
        baseRetryDelay: const Duration(milliseconds: 5),
      );

      // Dispatch 50 distinct requests concurrently (slightly varied description hints to bypass cache)
      final futures = List.generate(50, (index) {
        return gateway.analyzeCivicIssueImage(
          imageBytes: _createSampleImageBytes(width: 60, height: 60),
          userDescriptionHint: 'Concurrent test photo #$index',
          compressImage: false,
        );
      });

      final results = await Future.wait(futures);

      expect(results.length, 50);
      expect(gateway.maxObservedConcurrency, lessThanOrEqualTo(3));
      expect(gateway.totalRetriesAttempted, greaterThanOrEqualTo(5));
      expect(gateway.totalRequestsProcessed, 50);

      // Dispatch repeat request -> must hit response cache instantly
      final cachedResult = await gateway.analyzeCivicIssueImage(
        imageBytes: _createSampleImageBytes(width: 60, height: 60),
        userDescriptionHint: 'Concurrent test photo #0',
        compressImage: false,
      );
      expect(cachedResult.fromCache, isTrue);
      expect(gateway.totalCacheHits, 1);
    });

    test('Promotes automatically to fallback Flash-Lite model when gemini-3.8-flash returns 503', () async {
      final calledModels = <String>[];
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model'] as String;
        calledModels.add(model);

        if (model == 'gemini-3.8-flash' || model == 'gemini-3.5-flash-lite') {
          return http.Response(
            '{"error":{"message":"$model is currently experiencing high demand"}}',
            503,
          );
        }
        return http.Response(_mockInteractionJson(), 200);
      });

      final gateway = AiGatewayService(
        client: mockClient,
        apiKeyOverride: 'test_key_fallback',
        baseRetryDelay: const Duration(milliseconds: 2),
      );

      final result = await gateway.analyzeCivicIssueImage(
        imageBytes: _createSampleImageBytes(width: 60, height: 60),
        compressImage: false,
      );

      expect(result.isValidCivicIssue, isTrue);
      expect(result.isMultiDepartment, isTrue);
      expect(calledModels, containsAll(['gemini-3.8-flash', 'gemini-3.5-flash-lite', 'gemini-3.1-flash-lite']));
      expect(calledModels.last, 'gemini-3.1-flash-lite');
    });
  });

  group('Phase 3 UI Insets & Native Permission Tests', () {
    testWidgets('DuplicateAlertSheet keeps Submit Anyway button above Android nav bar inset', (tester) async {
      const navBarHeight = 48.0;
      const screenSize = Size(400, 800);

      final candidates = List.generate(
        3,
        (i) => DuplicateCandidate(
          sourceId: 'cf_$i',
          sourceType: 'civic_flow_case',
          referenceLabel: 'CF-2026-10000$i',
          title: 'Roads & Footpaths — Dangerous Pothole #$i',
          description: 'Large waterlogged pothole obstructing vehicular traffic.',
          category: 'Roads & Footpaths',
          locality: 'Dehradun Central',
          status: 'Submitted',
          distanceMeters: (i + 1) * 5.0,
          similarityScore: 0.92 - (i * 0.04),
          matchReason: 'High AI visual/semantic similarity',
          createdAt: DateTime(2026, 11, 12),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: screenSize,
              viewPadding: EdgeInsets.only(bottom: navBarHeight),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: DuplicateAlertSheet(
                  candidates: candidates,
                  onSupportCandidate: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitAnywayFinder = find.text('Submit Anyway — This Is a Separate Issue');
      expect(submitAnywayFinder, findsOneWidget);

      final buttonRect = tester.getRect(find.widgetWithText(OutlinedButton, 'Submit Anyway — This Is a Separate Issue'));
      expect(buttonRect.bottom, lessThanOrEqualTo(screenSize.height - navBarHeight));
    });

    test('DevicePermissionService resolves cleanly in host test environment', () async {
      expect(await DevicePermissionService.ensureCameraPermission(), isTrue);
      expect(await DevicePermissionService.ensureGalleryPermission(), isTrue);
    });
  });
}
