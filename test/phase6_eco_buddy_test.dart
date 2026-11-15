import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evora/features/eco_buddy/models/eco_buddy_models.dart';
import 'package:evora/features/eco_buddy/screens/eco_buddy_screen.dart';
import 'package:evora/features/eco_buddy/services/eco_buddy_service.dart';

void main() {
  group('Phase 6: Conversational AI — Eco Buddy Test Suite', () {
    late EcoBuddyNotifier notifier;
    late EcoBuddyRateLimiter rateLimiter;

    setUp(() {
      rateLimiter = EcoBuddyRateLimiter(maxAllowed: 15, windowDuration: const Duration(minutes: 5));
      notifier = EcoBuddyNotifier(rateLimiter: rateLimiter);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('6.1 Grounded Retrieval Accuracy: returns exact verified facility name, address and hours', () async {
      // Inquire about battery drop-off in Dehradun
      const query = 'Where can I drop off old batteries in Ward 4?';
      final sources = EcoBuddyGroundingEngine.retrieveSources(query);

      expect(sources, isNotEmpty);
      final batteryHub = sources.firstWhere(
        (s) => s.acceptedMaterials.any((m) => m.toLowerCase().contains('batter')),
        orElse: () => sources.first,
      );

      // Verify that Clock Tower Battery Depot or E-Waste Hub is retrieved
      expect(
        batteryHub.title.contains('Battery') || batteryHub.title.contains('E-Waste'),
        isTrue,
        reason: 'Expected a verified battery or e-waste facility to be retrieved',
      );
      expect(batteryHub.address, isNotEmpty);
      expect(batteryHub.operatingHours, isNotEmpty);
      expect(batteryHub.contactNumber, isNotNull);
      expect(batteryHub.verificationBadge, contains('Verified'));

      // Synthesize answer and ensure address & operating hours are cited
      final answer = EcoBuddyGroundingEngine.synthesizeGroundedAnswer(
        query: query,
        sources: sources,
        isHindi: false,
      );

      expect(answer, contains(batteryHub.title));
      expect(answer, contains(batteryHub.address));
      expect(answer, contains(batteryHub.operatingHours!));
    });

    test('6.2 Anti-Hallucination Guardrail: unsupported municipal tax question returns strict refusal', () async {
      const unsupportedTaxQuery = 'What is the property tax and house tax rate for commercial shops in Rajpur?';

      expect(EcoBuddyGroundingEngine.isUnsupportedPolicy(unsupportedTaxQuery), isTrue);

      final answerEn = EcoBuddyGroundingEngine.synthesizeGroundedAnswer(
        query: unsupportedTaxQuery,
        sources: [],
        isHindi: false,
      );

      // Must strictly refuse rather than guessing or fabricating tax policy
      expect(answerEn, equals(EcoBuddyGroundingEngine.refusalEnglish));
      expect(
        answerEn,
        contains('I currently do not have verified information for this in your area'),
      );

      // Test in Hindi as well
      const unsupportedTaxQueryHi = 'देहरादून में हाउस टैक्स और संपत्ति कर की दर क्या है?';
      expect(EcoBuddyGroundingEngine.isUnsupportedPolicy(unsupportedTaxQueryHi), isTrue);

      final answerHi = EcoBuddyGroundingEngine.synthesizeGroundedAnswer(
        query: unsupportedTaxQueryHi,
        sources: [],
        isHindi: true,
      );

      expect(answerHi, equals(EcoBuddyGroundingEngine.refusalHindi));
      expect(
        answerHi,
        contains('वर्तमान में मेरे पास आपके क्षेत्र के लिए इसकी सत्यापित जानकारी नहीं है'),
      );
    });

    test('6.3 Emergency Safety Redirect: chemical spill surfaces official emergency helplines with zero latency', () async {
      const hazardQuery = 'There is a chemical spill on Mall Road!';

      expect(EmergencyHazardInterceptor.isEmergency(hazardQuery), isTrue);

      final emergencyMsg = EmergencyHazardInterceptor.buildEmergencyResponse(isHindi: false);

      expect(emergencyMsg.messageType, equals(EcoBuddyMessageType.emergencyAlert));
      expect(emergencyMsg.helplines, isNotEmpty);
      expect(emergencyMsg.text, contains('IMMEDIATE HAZARD DETECTED'));

      // Verify official emergency helplines are included
      final numbers = emergencyMsg.helplines.map((h) => h.number).toList();
      expect(numbers, contains('112')); // All-Emergency ERSS
      expect(numbers, contains('18001804155')); // Nagar Nigam Dehradun Disaster Cell
      expect(numbers, contains('101')); // Fire & Rescue
      expect(numbers, contains('1070')); // SDRF Uttarakhand

      // Also verify through notifier pipeline
      await notifier.sendMessage('There is a dangerous chemical spill and gas leak near Clock Tower');
      final lastMsg = notifier.state.messages.last;
      expect(lastMsg.messageType, equals(EcoBuddyMessageType.emergencyAlert));
      expect(lastMsg.helplines, isNotEmpty);
    });

    test('6.4 Bilingual Consistency: Hindi and English waste segregation queries yield identical factual rules', () async {
      const queryEn = 'How should I segregate kitchen waste?';
      const queryHi = 'रसोई के कचरे को कैसे अलग करें?';

      final sourcesEn = EcoBuddyGroundingEngine.retrieveSources(queryEn);
      final sourcesHi = EcoBuddyGroundingEngine.retrieveSources(queryHi);

      final responseEn = EcoBuddyGroundingEngine.synthesizeGroundedAnswer(
        query: queryEn,
        sources: sourcesEn,
        isHindi: false,
      );

      final responseHi = EcoBuddyGroundingEngine.synthesizeGroundedAnswer(
        query: queryHi,
        sources: sourcesHi,
        isHindi: true,
      );

      // English rules check
      expect(responseEn, contains('Green Bin'));
      expect(responseEn, contains('Blue Bin'));
      expect(responseEn, contains('Domestic Hazardous Waste'));
      expect(responseEn, contains('Sanitary Waste'));

      // Hindi rules check (parallel factual accuracy in Devanagari)
      expect(responseHi, contains('हरा डिब्बा'));
      expect(responseHi, contains('नीला डिब्बा'));
      expect(responseHi, contains('घरेलू खतरनाक कचरा'));
      expect(responseHi, contains('सेनेटरी वेस्ट'));
    });

    test('6.5 Chat Rate Limiting: sending 16 messages triggers graceful pause without crashing', () async {
      // Send 15 messages (within quota)
      for (int i = 1; i <= 15; i++) {
        final cooldown = rateLimiter.checkLimit();
        expect(cooldown, isNull, reason: 'Message $i should be permitted within quota');
      }

      // 16th message triggers rate limit cooldown
      final cooldown16 = rateLimiter.checkLimit();
      expect(cooldown16, isNotNull);
      expect(cooldown16! > 0, isTrue);

      // Verify notifier handles the 16th message gracefully without crash
      final customLimiter = EcoBuddyRateLimiter(maxAllowed: 3, windowDuration: const Duration(minutes: 5));
      final testNotifier = EcoBuddyNotifier(rateLimiter: customLimiter);

      await testNotifier.sendMessage('Query 1: Composting');
      await testNotifier.sendMessage('Query 2: E-waste');
      await testNotifier.sendMessage('Query 3: Plastic');
      expect(testNotifier.state.isRateLimited, isFalse);

      // 4th message should trigger rate limit message
      await testNotifier.sendMessage('Query 4: Exceeds limit');
      expect(testNotifier.state.isRateLimited, isTrue);
      expect(testNotifier.state.rateLimitResetSeconds, greaterThan(0));

      final lastMessage = testNotifier.state.messages.last;
      expect(lastMessage.messageType, equals(EcoBuddyMessageType.rateLimitAlert));
      expect(lastMessage.text, contains('Chat Quota Limit Reached'));

      testNotifier.dispose();
    });

    testWidgets('EcoBuddyScreen renders chat interface and suggested prompt chips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EcoBuddyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AppBar and Eco Buddy Branding
      expect(find.text('Eco Buddy'), findsOneWidget);
      expect(find.text('AI Grounded'), findsOneWidget);

      // Verify Quick prompt chips
      expect(find.text('E-Waste Drop-off'), findsOneWidget);
      expect(find.text('Waste Segregation'), findsOneWidget);
      expect(find.text('Local Composting'), findsOneWidget);
      expect(find.text('Active Missions'), findsOneWidget);

      // Verify Welcome message
      expect(find.textContaining('EVORA’s official sustainability'), findsOneWidget);

      // Verify Language toggle
      expect(find.text('EN'), findsOneWidget);
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();

      expect(find.text('इको बडी (Eco Buddy)'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
    });
  });
}
