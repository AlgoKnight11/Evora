import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../facilities/models/circular_facility_model.dart';
import '../../facilities/services/circular_directory_service.dart';
import '../../missions/services/missions_service.dart';
import '../models/eco_buddy_models.dart';

/// Detects life/property hazard keywords and immediately surfaces official
/// Uttarakhand emergency helplines without waiting for LLM completion.
class EmergencyHazardInterceptor {
  static final RegExp _emergencyRegex = RegExp(
    r'\b(gas leak|lpg leak|cylinder blast|active fire|fire outbreak|building collapse|roof collapse|fallen wire|live wire|electric shock|chemical spill|toxic fumes|flooding emergency|landslide|severely injured|explosion|huge fire)\b|'
    r'(आग लग|आग की लपटें|सिलेंडर ब्लास्ट|धमाका|गैस रिसाव|गैस लीक|मकान गिर|दीवार गिर|बिजली का तार|करंट लग|विस्फोट|केमिकल रिसाव|जहरीली गैस|भूस्खलन|बाढ़ आपातकाल)',
    caseSensitive: false,
  );

  /// Returns true if [text] matches acute emergency keywords.
  static bool isEmergency(String text) {
    return _emergencyRegex.hasMatch(text);
  }

  /// Builds a high-priority emergency redirect message.
  static EcoBuddyMessage buildEmergencyResponse({required bool isHindi}) {
    final text = isHindi
        ? '🚨 **तत्काल आपातकालीन सुरक्षा चेतावनी**\n\n'
            'आपके संदेश में गंभीर जीवन या सुरक्षा खतरे का संकेत मिला है। '
            '**कृपया नागरिक ऐप के उत्तर की प्रतीक्षा न करें।** '
            'तुरंत सुरक्षित स्थान पर जाएं और नीचे दी गई आधिकारिक आपातकालीन हेल्पलाइन पर संपर्क करें:'
        : '🚨 **IMMEDIATE HAZARD DETECTED**\n\n'
            'Your message indicates an active safety or life-hazard emergency. '
            '**Do NOT wait for regular civic triage.** '
            'Please evacuate to a safe perimeter and contact official municipal and disaster helplines immediately:';

    return EcoBuddyMessage(
      id: const Uuid().v4(),
      text: text,
      sender: EcoBuddySender.assistant,
      messageType: EcoBuddyMessageType.emergencyAlert,
      timestamp: DateTime.now(),
      helplines: EmergencyHelpline.defaultDehradunHelplines,
      isHindi: isHindi,
    );
  }
}

/// Sliding-window rate limiter enforcing max 15 messages per 5 minutes per citizen.
class EcoBuddyRateLimiter {
  final int maxAllowed;
  final Duration windowDuration;
  final List<DateTime> _messageTimestamps = [];

  EcoBuddyRateLimiter({
    this.maxAllowed = AppConstants.maxEcoBuddyMessagesPerFiveMinutes,
    this.windowDuration = const Duration(minutes: 5),
  });

  /// Evaluates whether an incoming message is permitted.
  /// Returns `null` if allowed, or remaining cooldown in seconds if rate limited.
  int? checkLimit() {
    final now = DateTime.now();
    _messageTimestamps.removeWhere((ts) => now.difference(ts) > windowDuration);

    if (_messageTimestamps.length >= maxAllowed) {
      final oldestInWindow = _messageTimestamps.first;
      final elapsed = now.difference(oldestInWindow);
      final remaining = windowDuration.inSeconds - elapsed.inSeconds;
      return remaining > 0 ? remaining : 1;
    }

    _messageTimestamps.add(now);
    return null;
  }

  /// Clears the rate limiter history (for testing or session resets).
  void reset() {
    _messageTimestamps.clear();
  }

  int get currentCount {
    final now = DateTime.now();
    _messageTimestamps.removeWhere((ts) => now.difference(ts) > windowDuration);
    return _messageTimestamps.length;
  }
}

/// Verified domain facts engine for local Dehradun recycling, waste rules & missions.
class EcoBuddyGroundingEngine {
  static const String refusalEnglish =
      'I currently do not have verified information for this in your area. '
      'Please check the Circular Directory or file an inquiry via CivicFlow.';

  static const String refusalHindi =
      'वर्तमान में मेरे पास आपके क्षेत्र के लिए इसकी सत्यापित जानकारी नहीं है। '
      'कृपया सर्कुलर डायरेक्टरी देखें या सिविकफ्लो (CivicFlow) के माध्यम से जानकारी प्राप्त करें।';

  static final RegExp _unsupportedPolicyRegex = RegExp(
    r'\b(property tax|house tax|commercial tax|trade license|building permit|construction approval|mutation fee|water bill concession|traffic challan|traffic fine|voter id|election booth|birth certificate|death certificate|tender notice)\b|'
    r'(हाउस टैक्स|प्रॉपर्टी टैक्स|संपत्ति कर|व्यापार लाइसेंस|भवन निर्माण अनुमति|दाखिल खारिज|पानी का बिल छूट|ट्रैफिक चालान|वोटर कार्ड|मतदान केंद्र|जन्म प्रमाण पत्र|मृत्यु प्रमाण पत्र)',
    caseSensitive: false,
  );

  /// Checks if a query is asking for unverified municipal policies or tax schemes.
  static bool isUnsupportedPolicy(String query) {
    return _unsupportedPolicyRegex.hasMatch(query);
  }

  /// Retrieves relevant verified facilities and missions matching the query keywords.
  static List<GroundedSource> retrieveSources(String query) {
    final lower = query.toLowerCase();
    final sources = <GroundedSource>[];

    final hasBattery = lower.contains('batter') || lower.contains('बैटरी');
    final hasEwaste = lower.contains('electron') ||
        lower.contains('laptop') ||
        lower.contains('phone') ||
        lower.contains('wire') ||
        lower.contains('e-waste') ||
        lower.contains('ewaste') ||
        lower.contains('ई-कचरा');
    final hasPlastic = lower.contains('plastic') || lower.contains('प्लास्टिक') || lower.contains('पॉलीथीन');
    final hasMetal = lower.contains('metal') || lower.contains('scrap') || lower.contains('iron');
    final hasPaper = lower.contains('paper') || lower.contains('cardboard') || lower.contains('gatta');
    final hasOrganic = lower.contains('compost') ||
        lower.contains('vegetable') ||
        lower.contains('food') ||
        lower.contains('kitchen') ||
        lower.contains('खाद') ||
        lower.contains('जैविक');

    // 1. Match Circular Facilities
    for (final facility in CircularDirectoryNotifier.seedFacilities) {
      bool matched = false;

      // Category / intent matching
      if (hasBattery &&
          (facility.name.toLowerCase().contains('battery') ||
              facility.acceptedMaterials.any((m) => m.toLowerCase().contains('batter')))) {
        matched = true;
      } else if (hasEwaste && facility.category == CircularCategory.ewaste) {
        matched = true;
      } else if (hasPlastic &&
          (facility.category == CircularCategory.recycling &&
              facility.acceptedMaterials.any((m) => m.toLowerCase().contains('plastic')))) {
        matched = true;
      } else if (hasOrganic && facility.category == CircularCategory.composting) {
        matched = true;
      } else if (hasMetal &&
          facility.acceptedMaterials.any((m) => m.toLowerCase().contains('metal') || m.toLowerCase().contains('scrap'))) {
        matched = true;
      } else if (hasPaper &&
          facility.acceptedMaterials.any((m) => m.toLowerCase().contains('paper') || m.toLowerCase().contains('cardboard'))) {
        matched = true;
      }

      // Material matches
      if (!matched) {
        for (final mat in facility.acceptedMaterials) {
          final matLower = mat.toLowerCase();
          if (lower.contains(matLower)) {
            matched = true;
            break;
          }
        }
      }

      // Locality / name matches
      if (!matched) {
        if (lower.contains(facility.locality.toLowerCase()) ||
            lower.contains(facility.name.toLowerCase()) ||
            (lower.contains('patel') && facility.locality.toLowerCase().contains('patel')) ||
            (lower.contains('rajpur') && facility.locality.toLowerCase().contains('rajpur')) ||
            (lower.contains('paltan') && facility.locality.toLowerCase().contains('paltan')) ||
            (lower.contains('clock tower') && facility.name.toLowerCase().contains('clock tower')) ||
            (lower.contains('kargi') && facility.locality.toLowerCase().contains('kargi'))) {
          matched = true;
        }
      }

      if (matched) {
        sources.add(GroundedSource.fromFacility(facility));
      }
    }

    // 2. Match Active Missions
    for (final mission in MissionsNotifier.seedMissions) {
      if (lower.contains(mission.title.toLowerCase()) ||
          lower.contains(mission.locality.toLowerCase()) ||
          lower.contains('mission') ||
          lower.contains('अभियान') ||
          (lower.contains('rispana') && mission.title.toLowerCase().contains('rispana')) ||
          (lower.contains('ecocoins') && lower.contains('earn'))) {
        sources.add(
          GroundedSource(
            title: mission.title,
            sourceType: 'Community Campaign Mission',
            locality: mission.locality,
            address: '${mission.locality} (${mission.timeCommitment})',
            contactNumber: 'Nagar Nigam Mission Cell',
            operatingHours: 'Active Community Drive (+${mission.ecoCoinsReward} EcoCoins)',
            acceptedMaterials: [mission.badgeName, mission.category.label],
            verificationBadge: 'Verified EVORA Civic Mission',
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    return sources;
  }

  /// Synthesizes a factual, strictly-grounded response in the target language.
  static String synthesizeGroundedAnswer({
    required String query,
    required List<GroundedSource> sources,
    required bool isHindi,
  }) {
    final lower = query.toLowerCase();

    // Check for explicit unverified policies first
    if (isUnsupportedPolicy(query)) {
      return isHindi ? refusalHindi : refusalEnglish;
    }

    // Waste Segregation Rules check (CPCB / Uttarakhand SPCB Standards)
    final isSegregationQuery = lower.contains('segregat') ||
        lower.contains('separate') ||
        lower.contains('kitchen waste') ||
        lower.contains('wet waste') ||
        lower.contains('dry waste') ||
        lower.contains('अलग') ||
        lower.contains('कचरा') ||
        lower.contains('गीले कचरे') ||
        lower.contains('सूखे कचरे') ||
        lower.contains('रसोई के कचरे');

    if (isSegregationQuery) {
      if (isHindi) {
        return '🌱 **देहरादून नगर निगम एवं सीपीसीबी कचरा पृथक्करण नियम:**\n\n'
            '**1. हरा डिब्बा (गीला / जैविक कचरा):**\n'
            '• फलों और सब्जियों के छिलके, बचा हुआ खाना, चाय पत्ती, सूखे पत्ते और फूलों का कचरा।\n'
            '• *नियम:* कभी भी प्लास्टिक की पन्नियों या पॉलीथीन में बंद करके न डालें।\n\n'
            '**2. नीला डिब्बा (सूखा / पुनर्चक्रण योग्य कचरा):**\n'
            '• सूखा कागज, साफ गत्ता, प्लास्टिक की बोतलें, धोए हुए दूध के पैकेट, एल्युमिनियम कैन और कांच की शीशियां।\n'
            '• *नियम:* सामग्री साफ और सूखी होनी चाहिए ताकि दुर्गंध या संदूषण न हो।\n\n'
            '**3. घरेलू खतरनाक कचरा (लाल/काला डिब्बा):**\n'
            '• एक्सपायर्ड दवाइयां, कीटनाशक की बोतलें, ट्यूबलाइट, सीएफएल बल्ब, पेंट के डिब्बे और बैटरी सेल्स। इन्हें नगर निगम के विशेष केंद्रों (उदा. पलटन बाजार केंद्र) में जमा करें।\n\n'
            '**4. सेनेटरी वेस्ट:**\n'
            '• नैपकिन और डायपर को पुराने अखबार में लपेटकर उस पर लाल निशान लगाएं।';
      } else {
        return '🌱 **Dehradun Municipal Corporation (NNND) Waste Segregation Standards:**\n\n'
            '**1. Green Bin (Wet / Biodegradable Waste):**\n'
            '• Kitchen scraps, vegetable & fruit peels, leftover food, tea leaves, fallen garden leaves, and floral waste.\n'
            '• *Strict Rule:* Never enclose wet waste in single-use plastic bags.\n\n'
            '**2. Blue Bin (Dry / Recyclable Waste):**\n'
            '• Paper, clean cardboard cartons, plastic beverage bottles, rinsed milk pouches, metal cans, and glass jars.\n'
            '• *Strict Rule:* Ensure recyclables are dry and rinsed to prevent contamination.\n\n'
            '**3. Domestic Hazardous Waste (Red/Black Disposal):**\n'
            '• Expired medicines, insect spray cans, CFL bulbs, tube lights, paint residue, and battery cells. Deliver to designated depots (e.g. Clock Tower Battery Depot).\n\n'
            '**4. Sanitary Waste:**\n'
            '• Diapers and hygiene products must be securely wrapped in newspaper with a red cross or dot.';
      }
    }

    // Facility Grounded Response
    if (sources.isNotEmpty) {
      final buffer = StringBuffer();
      if (isHindi) {
        buffer.writeln('📍 **आपके प्रश्न के अनुसार देहरादून में सत्यापित केंद्र:**\n');
        for (final src in sources.take(3)) {
          buffer.writeln('### ${src.title}');
          buffer.writeln('• **स्थान / पता:** ${src.address}');
          if (src.operatingHours != null) {
            buffer.writeln('• **संचालन समय:** ${src.operatingHours}');
          }
          if (src.contactNumber != null) {
            buffer.writeln('• **संपर्क नंबर:** ${src.contactNumber}');
          }
          if (src.acceptedMaterials.isNotEmpty) {
            buffer.writeln('• **स्वीकृत सामग्री:** ${src.acceptedMaterials.join(", ")}');
          }
          buffer.writeln('• *प्रमाणीकरण:* ✅ ${src.verificationBadge}\n');
        }
        buffer.write('💡 *सुझाव:* अधिक विवरण या नेविगेशन के लिए आप सर्कुलर डायरेक्टरी भी देख सकते हैं।');
      } else {
        buffer.writeln('📍 **Here are the verified Dehradun facilities matching your query:**\n');
        for (final src in sources.take(3)) {
          buffer.writeln('### ${src.title}');
          buffer.writeln('• **Address / Locality:** ${src.address}');
          if (src.operatingHours != null) {
            buffer.writeln('• **Operating Hours:** ${src.operatingHours}');
          }
          if (src.contactNumber != null) {
            buffer.writeln('• **Contact:** ${src.contactNumber}');
          }
          if (src.acceptedMaterials.isNotEmpty) {
            buffer.writeln('• **Accepted Items:** ${src.acceptedMaterials.join(", ")}');
          }
          buffer.writeln('• *Status:* ✅ ${src.verificationBadge}\n');
        }
        buffer.write('💡 *Tip:* You can also open the Circular Directory tab to view route navigation and directions.');
      }
      return buffer.toString();
    }

    // Fallback: If no verified records match and query is not about segregation
    return isHindi ? refusalHindi : refusalEnglish;
  }
}

/// State object representing the conversational state of Eco Buddy.
class EcoBuddyState {
  final List<EcoBuddyMessage> messages;
  final bool isLoading;
  final bool isRateLimited;
  final int rateLimitResetSeconds;
  final String? errorMessage;
  final bool isHindi;

  const EcoBuddyState({
    required this.messages,
    this.isLoading = false,
    this.isRateLimited = false,
    this.rateLimitResetSeconds = 0,
    this.errorMessage,
    this.isHindi = false,
  });

  EcoBuddyState copyWith({
    List<EcoBuddyMessage>? messages,
    bool? isLoading,
    bool? isRateLimited,
    int? rateLimitResetSeconds,
    String? errorMessage,
    bool? isHindi,
  }) {
    return EcoBuddyState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isRateLimited: isRateLimited ?? this.isRateLimited,
      rateLimitResetSeconds: rateLimitResetSeconds ?? this.rateLimitResetSeconds,
      errorMessage: errorMessage,
      isHindi: isHindi ?? this.isHindi,
    );
  }
}

/// Main business logic notifier orchestrating Eco Buddy conversations,
/// zero-latency emergency redirects, rate limiting, and grounded RAG synthesis.
class EcoBuddyNotifier extends StateNotifier<EcoBuddyState> {
  final http.Client _client;
  final String? apiKeyOverride;
  final EcoBuddyRateLimiter _rateLimiter;
  Timer? _cooldownTimer;

  EcoBuddyNotifier({
    http.Client? client,
    this.apiKeyOverride,
    EcoBuddyRateLimiter? rateLimiter,
  })  : _client = client ?? http.Client(),
        _rateLimiter = rateLimiter ?? EcoBuddyRateLimiter(),
        super(
          EcoBuddyState(
            messages: [_buildWelcomeMessage(isHindi: false)],
            isHindi: false,
          ),
        );

  static EcoBuddyMessage _buildWelcomeMessage({required bool isHindi}) {
    return EcoBuddyMessage(
      id: 'welcome_msg_01',
      text: isHindi
          ? 'नमस्ते! 🙏 मैं हूँ **इको बडी (Eco Buddy)**, ईवीओआरए (EVORA) का आधिकारिक पर्यावरण एवं सतत जीवन सहायक।\n\n'
              'मैं आपको देहरादून के सत्यापित पुनर्चक्रण केंद्रों, कचरा प्रबंधन नियमों और नागरिक अभियानों की सही जानकारी दे सकता हूँ। '
              'आप मुझसे हिंदी या अंग्रेजी में पूछ सकते हैं!'
          : 'Hello! 👋 I am **Eco Buddy**, EVORA’s official sustainability and circular living assistant for Dehradun.\n\n'
              'I am strictly grounded in verified municipal recycling centers, waste segregation guidelines, and community eco-missions. '
              'Feel free to ask in English or Hindi!',
      sender: EcoBuddySender.assistant,
      messageType: EcoBuddyMessageType.text,
      timestamp: DateTime.now(),
      isHindi: isHindi,
    );
  }

  /// Toggles between English and Hindi.
  void toggleLanguage() {
    final nextHindi = !state.isHindi;
    state = state.copyWith(isHindi: nextHindi);
  }

  /// Clears chat history and restores the initial welcome message.
  void clearChat() {
    _rateLimiter.reset();
    _cooldownTimer?.cancel();
    state = EcoBuddyState(
      messages: [_buildWelcomeMessage(isHindi: state.isHindi)],
      isHindi: state.isHindi,
    );
  }

  /// Sends a predefined quick prompt chip.
  Future<void> sendQuickPrompt(EcoBuddyQuickPrompt prompt) async {
    final text = state.isHindi ? prompt.promptHi : prompt.promptEn;
    await sendMessage(text);
  }

  /// Sends a user message through the full guardrail pipeline.
  Future<void> sendMessage(String userText) async {
    final cleanText = userText.trim();
    if (cleanText.isEmpty || state.isLoading) return;

    // Detect Devanagari script in user input to align response language naturally
    final bool textHasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(cleanText);
    final bool activeHindi = state.isHindi || textHasHindi;

    final userMessage = EcoBuddyMessage(
      id: const Uuid().v4(),
      text: cleanText,
      sender: EcoBuddySender.user,
      messageType: EcoBuddyMessageType.text,
      timestamp: DateTime.now(),
      isHindi: activeHindi,
    );

    // 1. Append user message to UI immediately
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      errorMessage: null,
      isHindi: activeHindi,
    );

    // 2. Step 1 Guardrail: Check Rate Limiter (Max 15 per 5 minutes)
    final cooldownRemaining = _rateLimiter.checkLimit();
    if (cooldownRemaining != null) {
      _triggerRateLimitNotice(cooldownRemaining, isHindi: activeHindi);
      return;
    }

    // 3. Step 2 Guardrail: Deterministic Emergency Hazard Interceptor
    if (EmergencyHazardInterceptor.isEmergency(cleanText)) {
      final emergencyResponse = EmergencyHazardInterceptor.buildEmergencyResponse(
        isHindi: activeHindi,
      );
      state = state.copyWith(
        messages: [...state.messages, emergencyResponse],
        isLoading: false,
      );
      return;
    }

    // 4. Step 3: Local Grounded Knowledge Retrieval
    final matchedSources = EcoBuddyGroundingEngine.retrieveSources(cleanText);

    // 5. Step 4: Strict Zero-Hallucination & Policy Verification Check
    if (EcoBuddyGroundingEngine.isUnsupportedPolicy(cleanText)) {
      final refusalText = activeHindi
          ? EcoBuddyGroundingEngine.refusalHindi
          : EcoBuddyGroundingEngine.refusalEnglish;

      final guardrailMessage = EcoBuddyMessage(
        id: const Uuid().v4(),
        text: refusalText,
        sender: EcoBuddySender.assistant,
        messageType: EcoBuddyMessageType.text,
        timestamp: DateTime.now(),
        isHindi: activeHindi,
      );

      state = state.copyWith(
        messages: [...state.messages, guardrailMessage],
        isLoading: false,
      );
      return;
    }

    // 6. Step 5: Answer Synthesis (Gemini LLM when available, Grounded Engine fallback)
    try {
      String finalAnswer = '';
      final apiKey = (apiKeyOverride ?? AppConstants.geminiApiKey).trim();

      if (apiKey.isNotEmpty && !apiKey.contains('placeholder') && !apiKey.contains('your_')) {
        try {
          finalAnswer = await _queryGeminiWithGroundedContext(
            userPrompt: cleanText,
            sources: matchedSources,
            isHindi: activeHindi,
            apiKey: apiKey,
          );
        } catch (e) {
          // If network / API fails, gracefully fallback to local Grounded Engine
          debugPrint('Gemini online query fallback: $e');
        }
      }

      if (finalAnswer.trim().isEmpty) {
        finalAnswer = EcoBuddyGroundingEngine.synthesizeGroundedAnswer(
          query: cleanText,
          sources: matchedSources,
          isHindi: activeHindi,
        );
      }

      final assistantMessage = EcoBuddyMessage(
        id: const Uuid().v4(),
        text: finalAnswer,
        sender: EcoBuddySender.assistant,
        messageType: matchedSources.isNotEmpty
            ? EcoBuddyMessageType.groundedFacility
            : EcoBuddyMessageType.text,
        timestamp: DateTime.now(),
        sources: matchedSources,
        isHindi: activeHindi,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to process query: $e',
      );
    }
  }

  /// Calls Google Gemini API with strict system prompt grounding.
  Future<String> _queryGeminiWithGroundedContext({
    required String userPrompt,
    required List<GroundedSource> sources,
    required bool isHindi,
    required String apiKey,
  }) async {
    final systemInstruction =
        'You are Eco Buddy, the official AI sustainability and circular economy assistant for EVORA in Dehradun, Uttarakhand, India.\n'
        'You communicate fluently and warmly in ${isHindi ? "Hindi (Devanagari script)" : "English"}.\n\n'
        'STRICT NON-NEGOTIABLE GROUNDING RULES:\n'
        '1. You must answer using ONLY the verified municipal facts and facilities provided in the context below.\n'
        '2. If the user asks about unverified local issues, tax policies, building permits, commercial trade licenses, birth certificates, or municipal decisions NOT present in the context, you MUST strictly reply with:\n'
        '   "${isHindi ? EcoBuddyGroundingEngine.refusalHindi : EcoBuddyGroundingEngine.refusalEnglish}"\n'
        '3. NEVER guess or invent addresses, telephone numbers, or municipal tax policies.\n'
        '4. Format all responses cleanly with markdown bolding and bullet points.';

    final contextBuffer = StringBuffer();
    contextBuffer.writeln('VERIFIED DEHRADUN DATASETS:');
    if (sources.isNotEmpty) {
      for (final s in sources) {
        contextBuffer.writeln('- Facility: ${s.title}');
        contextBuffer.writeln('  Address: ${s.address}');
        contextBuffer.writeln('  Locality: ${s.locality}');
        if (s.contactNumber != null) contextBuffer.writeln('  Phone: ${s.contactNumber}');
        if (s.operatingHours != null) contextBuffer.writeln('  Hours: ${s.operatingHours}');
        contextBuffer.writeln('  Accepted Items: ${s.acceptedMaterials.join(", ")}');
      }
    } else {
      contextBuffer.writeln('- No specific matching circular facilities in local dataset.');
    }

    final fullUserMessage = '$contextBuffer\n\nCITIZEN QUERY: $userPrompt';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': fullUserMessage}
          ]
        }
      ],
      'generation_config': {
        'temperature': 0.2,
        'max_output_tokens': 800,
      }
    };

    final response = await _client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final textPart = candidates[0]['content']?['parts']?[0]?['text']?.toString();
        if (textPart != null && textPart.isNotEmpty) {
          return textPart.trim();
        }
      }
    }

    return '';
  }

  void _triggerRateLimitNotice(int cooldownSeconds, {required bool isHindi}) {
    final text = isHindi
        ? '⏳ **संदेश सीमा सक्रिय (15 संदेश / 5 मिनट)**\n\n'
            'आपने सुरक्षित उपयोग सीमा पूरी कर ली है। कृपया **$cooldownSeconds सेकंड** प्रतीक्षा करें ताकि सर्वर पर अधिक भार न पड़े।'
        : '⏳ **Chat Quota Limit Reached (15 messages / 5 minutes)**\n\n'
            'You have reached the temporary messaging quota. Please pause for **$cooldownSeconds seconds** before sending another query.';

    final rateLimitMessage = EcoBuddyMessage(
      id: const Uuid().v4(),
      text: text,
      sender: EcoBuddySender.assistant,
      messageType: EcoBuddyMessageType.rateLimitAlert,
      timestamp: DateTime.now(),
      isHindi: isHindi,
    );

    state = state.copyWith(
      messages: [...state.messages, rateLimitMessage],
      isLoading: false,
      isRateLimited: true,
      rateLimitResetSeconds: cooldownSeconds,
    );

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.rateLimitResetSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(
          isRateLimited: false,
          rateLimitResetSeconds: 0,
        );
      } else {
        state = state.copyWith(rateLimitResetSeconds: remaining);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

/// Global Riverpod provider for Eco Buddy state and actions.
final ecoBuddyProvider =
    StateNotifierProvider<EcoBuddyNotifier, EcoBuddyState>((ref) {
  return EcoBuddyNotifier();
});
