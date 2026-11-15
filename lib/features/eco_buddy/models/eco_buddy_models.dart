import 'package:flutter/material.dart';
import '../../facilities/models/circular_facility_model.dart';

/// Defines the sender role in an Eco Buddy conversation.
enum EcoBuddySender {
  user,
  assistant,
  system,
}

/// Category classification of messages exchanged with Eco Buddy.
enum EcoBuddyMessageType {
  text,
  emergencyAlert,
  groundedFacility,
  groundedMission,
  groundedRule,
  rateLimitAlert,
}

/// Represents a verified source cited by Eco Buddy.
class GroundedSource {
  final String title;
  final String sourceType; // 'Circular Facility', 'Community Mission', 'Municipal Waste Rule'
  final String locality;
  final String address;
  final String? contactNumber;
  final String? operatingHours;
  final List<String> acceptedMaterials;
  final String verificationBadge;
  final DateTime timestamp;

  const GroundedSource({
    required this.title,
    required this.sourceType,
    required this.locality,
    required this.address,
    this.contactNumber,
    this.operatingHours,
    this.acceptedMaterials = const [],
    this.verificationBadge = 'Verified Municipal Record',
    required this.timestamp,
  });

  factory GroundedSource.fromFacility(CircularFacility facility) {
    return GroundedSource(
      title: facility.name,
      sourceType: 'Circular Living Facility',
      locality: facility.locality,
      address: facility.address,
      contactNumber: facility.phone,
      operatingHours: facility.operatingHours,
      acceptedMaterials: facility.acceptedMaterials,
      verificationBadge: facility.isVerifiedPartner
          ? 'Verified Dehradun Nagar Nigam Facility'
          : 'Community Reported Facility',
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'sourceType': sourceType,
        'locality': locality,
        'address': address,
        'contactNumber': contactNumber,
        'operatingHours': operatingHours,
        'acceptedMaterials': acceptedMaterials,
        'verificationBadge': verificationBadge,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GroundedSource.fromMap(Map<String, dynamic> map) => GroundedSource(
        title: map['title'] as String? ?? '',
        sourceType: map['sourceType'] as String? ?? 'Verified Source',
        locality: map['locality'] as String? ?? 'Dehradun',
        address: map['address'] as String? ?? '',
        contactNumber: map['contactNumber'] as String?,
        operatingHours: map['operatingHours'] as String?,
        acceptedMaterials: List<String>.from(map['acceptedMaterials'] ?? const []),
        verificationBadge: map['verificationBadge'] as String? ?? 'Verified Municipal Record',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Official emergency helpline surfaced when acute hazards are detected.
class EmergencyHelpline {
  final String name;
  final String number;
  final String description;
  final IconData icon;
  final Color themeColor;

  const EmergencyHelpline({
    required this.name,
    required this.number,
    required this.description,
    required this.icon,
    required this.themeColor,
  });

  static const List<EmergencyHelpline> defaultDehradunHelplines = [
    EmergencyHelpline(
      name: 'All-Emergency Response (ERSS)',
      number: '112',
      description: 'Police, Ambulance, Fire & Life Safety across Uttarakhand',
      icon: Icons.emergency,
      themeColor: Color(0xFFDC2626), // Red
    ),
    EmergencyHelpline(
      name: 'Nagar Nigam Dehradun Disaster Control',
      number: '18001804155',
      description: 'Toll-Free Municipal Disaster & Hazard Control Cell',
      icon: Icons.location_city,
      themeColor: Color(0xFFEA580C), // Orange
    ),
    EmergencyHelpline(
      name: 'Fire & Emergency Rescue',
      number: '101',
      description: 'Immediate fire brigade dispatch and structural rescues',
      icon: Icons.local_fire_department,
      themeColor: Color(0xFFB91C1C), // Deep Red
    ),
    EmergencyHelpline(
      name: 'State Disaster Response Force (SDRF)',
      number: '1070',
      description: 'Uttarakhand State Emergency Operation Centre',
      icon: Icons.shield,
      themeColor: Color(0xFF0284C7), // Blue
    ),
  ];
}

/// Single conversational message in the Eco Buddy dialogue.
class EcoBuddyMessage {
  final String id;
  final String text;
  final EcoBuddySender sender;
  final EcoBuddyMessageType messageType;
  final DateTime timestamp;
  final List<GroundedSource> sources;
  final List<EmergencyHelpline> helplines;
  final bool isStreaming;
  final bool isHindi;

  const EcoBuddyMessage({
    required this.id,
    required this.text,
    required this.sender,
    this.messageType = EcoBuddyMessageType.text,
    required this.timestamp,
    this.sources = const [],
    this.helplines = const [],
    this.isStreaming = false,
    this.isHindi = false,
  });

  EcoBuddyMessage copyWith({
    String? id,
    String? text,
    EcoBuddySender? sender,
    EcoBuddyMessageType? messageType,
    DateTime? timestamp,
    List<GroundedSource>? sources,
    List<EmergencyHelpline>? helplines,
    bool? isStreaming,
    bool? isHindi,
  }) {
    return EcoBuddyMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      messageType: messageType ?? this.messageType,
      timestamp: timestamp ?? this.timestamp,
      sources: sources ?? this.sources,
      helplines: helplines ?? this.helplines,
      isStreaming: isStreaming ?? this.isStreaming,
      isHindi: isHindi ?? this.isHindi,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'sender': sender.name,
        'messageType': messageType.name,
        'timestamp': timestamp.toIso8601String(),
        'sources': sources.map((s) => s.toMap()).toList(),
        'isHindi': isHindi,
      };

  factory EcoBuddyMessage.fromMap(Map<String, dynamic> map) => EcoBuddyMessage(
        id: map['id'] as String? ?? '',
        text: map['text'] as String? ?? '',
        sender: EcoBuddySender.values.firstWhere(
          (e) => e.name == map['sender'],
          orElse: () => EcoBuddySender.assistant,
        ),
        messageType: EcoBuddyMessageType.values.firstWhere(
          (e) => e.name == map['messageType'],
          orElse: () => EcoBuddyMessageType.text,
        ),
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
        sources: (map['sources'] as List<dynamic>?)
                ?.map((e) => GroundedSource.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        isHindi: map['isHindi'] as bool? ?? false,
      );
}

/// Suggested quick prompt chips for citizens on the chat screen.
class EcoBuddyQuickPrompt {
  final String id;
  final String labelEn;
  final String labelHi;
  final String promptEn;
  final String promptHi;
  final IconData icon;

  const EcoBuddyQuickPrompt({
    required this.id,
    required this.labelEn,
    required this.labelHi,
    required this.promptEn,
    required this.promptHi,
    required this.icon,
  });

  static const List<EcoBuddyQuickPrompt> defaultPrompts = [
    EcoBuddyQuickPrompt(
      id: 'e_waste_drop',
      labelEn: 'E-Waste Drop-off',
      labelHi: 'ई-कचरा केंद्र',
      promptEn: 'Where can I safely drop off old electronics and laptop batteries in Dehradun?',
      promptHi: 'देहरादून में पुराने इलेक्ट्रॉनिक्स और लैपटॉप की बैटरी कहाँ जमा कर सकते हैं?',
      icon: Icons.battery_charging_full_outlined,
    ),
    EcoBuddyQuickPrompt(
      id: 'waste_segregation',
      labelEn: 'Waste Segregation',
      labelHi: 'कचरा पृथक्करण',
      promptEn: 'How should I segregate wet, dry, and domestic hazardous kitchen waste?',
      promptHi: 'गीले, सूखे और घरेलू खतरनाक कचरे को सही तरीके से कैसे अलग करें?',
      icon: Icons.delete_outline,
    ),
    EcoBuddyQuickPrompt(
      id: 'composting_centers',
      labelEn: 'Local Composting',
      labelHi: 'खाद केंद्र',
      promptEn: 'Find nearest community composting facilities in Dehradun.',
      promptHi: 'देहरादून में निकटतम सामुदायिक कंपोस्टिंग केंद्र खोजें।',
      icon: Icons.compost_outlined,
    ),
    EcoBuddyQuickPrompt(
      id: 'active_missions',
      labelEn: 'Active Missions',
      labelHi: 'सक्रिय अभियान',
      promptEn: 'What community eco missions can I join to earn EcoCoins in Dehradun?',
      promptHi: 'देहरादून में इको कॉइन्स अर्जित करने के लिए मैं किन अभियानों में भाग ले सकता हूँ?',
      icon: Icons.nature_people_outlined,
    ),
  ];
}
