/// Parses DateTime safely from ISO-8601 String, DateTime, or Firestore Timestamp
DateTime _parseFlowDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value != null) {
    try {
      final dt = (value as dynamic).toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
  }
  return DateTime.now();
}

/// CivicFlow Case Status Values
class CivicFlowStatus {
  static const String submitted = 'submitted';
  static const String underTriage = 'under_triage';
  static const String needsInfo = 'needs_info';
  static const String verified = 'verified';
  static const String assigned = 'assigned';
  static const String inProgress = 'in_progress';
  static const String blocked = 'blocked';
  static const String resolvedPending = 'resolved_pending';
  static const String resolved = 'resolved';
  static const String closed = 'closed';

  static String getLabel(String status) {
    switch (status) {
      case submitted:
        return 'Submitted';
      case underTriage:
        return 'Under Triage';
      case needsInfo:
        return 'Needs Information';
      case verified:
        return 'Ground Verified';
      case assigned:
        return 'Assigned to Ward';
      case inProgress:
        return 'Action In Progress';
      case blocked:
        return 'On Hold';
      case resolvedPending:
        return 'Pending Verification';
      case resolved:
        return 'Resolved';
      case closed:
        return 'Closed';
      default:
        return 'Active';
    }
  }
}

/// Official Timeline Stage in Case Resolution
class CivicFlowTimelineEvent {
  final String status;
  final String title;
  final String description;
  final DateTime timestamp;
  final String actor;

  const CivicFlowTimelineEvent({
    required this.status,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.actor,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'actor': actor,
    };
  }

  factory CivicFlowTimelineEvent.fromMap(Map<String, dynamic> map) {
    return CivicFlowTimelineEvent(
      status: map['status'] ?? 'submitted',
      title: map['title'] ?? 'Status Update',
      description: map['description'] ?? '',
      timestamp: _parseFlowDateTime(map['timestamp']),
      actor: map['actor'] ?? 'System',
    );
  }
}

/// CivicFlow Official Grievance Case Model
class CivicFlowCase {
  final String id;
  final String caseNumber; // e.g. CF-2026-000123
  final String tenantId;
  final String citizenId;
  final String citizenName;
  final String? citizenPhone;
  final String category;
  final String subcategory;
  final String description;
  final String? landmark;
  final String locality;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String status;
  final String? assignedDepartment;
  final List<String> requiredDepartments;
  final Map<String, String> departmentReasons;
  final double? aiConfidence;
  final int piiRedactedCount;
  final int supportersCount;
  final List<double>? embeddingVector;
  final String? assignedOfficer;
  final String? sourceCivicBookPostId;
  final String? officerNotes;
  final String? citizenFeedback;
  final List<CivicFlowTimelineEvent> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CivicFlowCase({
    required this.id,
    required this.caseNumber,
    required this.tenantId,
    required this.citizenId,
    required this.citizenName,
    this.citizenPhone,
    required this.category,
    required this.subcategory,
    required this.description,
    this.landmark,
    required this.locality,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.priority = 'medium',
    this.status = CivicFlowStatus.submitted,
    this.assignedDepartment,
    this.requiredDepartments = const [],
    this.departmentReasons = const {},
    this.aiConfidence,
    this.piiRedactedCount = 0,
    this.supportersCount = 1,
    this.embeddingVector,
    this.assignedOfficer,
    this.sourceCivicBookPostId,
    this.officerNotes,
    this.citizenFeedback,
    this.timeline = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isMultiDepartment => requiredDepartments.length > 1;

  CivicFlowCase copyWith({
    String? status,
    String? assignedDepartment,
    List<String>? requiredDepartments,
    Map<String, String>? departmentReasons,
    double? aiConfidence,
    int? piiRedactedCount,
    int? supportersCount,
    List<double>? embeddingVector,
    String? assignedOfficer,
    String? officerNotes,
    String? citizenFeedback,
    List<CivicFlowTimelineEvent>? timeline,
    DateTime? updatedAt,
  }) {
    return CivicFlowCase(
      id: id,
      caseNumber: caseNumber,
      tenantId: tenantId,
      citizenId: citizenId,
      citizenName: citizenName,
      citizenPhone: citizenPhone,
      category: category,
      subcategory: subcategory,
      description: description,
      landmark: landmark,
      locality: locality,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      priority: priority,
      status: status ?? this.status,
      assignedDepartment: assignedDepartment ?? this.assignedDepartment,
      requiredDepartments: requiredDepartments ?? this.requiredDepartments,
      departmentReasons: departmentReasons ?? this.departmentReasons,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      piiRedactedCount: piiRedactedCount ?? this.piiRedactedCount,
      supportersCount: supportersCount ?? this.supportersCount,
      embeddingVector: embeddingVector ?? this.embeddingVector,
      assignedOfficer: assignedOfficer ?? this.assignedOfficer,
      sourceCivicBookPostId: sourceCivicBookPostId,
      officerNotes: officerNotes ?? this.officerNotes,
      citizenFeedback: citizenFeedback ?? this.citizenFeedback,
      timeline: timeline ?? this.timeline,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'caseNumber': caseNumber,
      'tenantId': tenantId,
      'citizenId': citizenId,
      'citizenName': citizenName,
      'citizenPhone': citizenPhone,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'landmark': landmark,
      'locality': locality,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'priority': priority,
      'status': status,
      'assignedDepartment': assignedDepartment,
      'requiredDepartments': requiredDepartments,
      'departmentReasons': departmentReasons,
      'aiConfidence': aiConfidence,
      'piiRedactedCount': piiRedactedCount,
      'supportersCount': supportersCount,
      if (embeddingVector != null) 'embeddingVector': embeddingVector,
      'assignedOfficer': assignedOfficer,
      'sourceCivicBookPostId': sourceCivicBookPostId,
      'officerNotes': officerNotes,
      'citizenFeedback': citizenFeedback,
      'timeline': timeline.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CivicFlowCase.fromMap(Map<String, dynamic> map, {required String id}) {
    final rawTimeline = map['timeline'] as List<dynamic>?;
    final timelineEvents = rawTimeline != null
        ? rawTimeline
            .map((e) => CivicFlowTimelineEvent.fromMap(e as Map<String, dynamic>))
            .toList()
        : <CivicFlowTimelineEvent>[];

    final rawDepts = map['requiredDepartments'] as List<dynamic>?;
    final depts = rawDepts?.map((e) => e.toString()).toList() ?? const <String>[];

    final rawReasons = map['departmentReasons'] as Map<String, dynamic>?;
    final reasons = rawReasons != null
        ? rawReasons.map((k, v) => MapEntry(k, v.toString()))
        : const <String, String>{};

    final rawVec = map['embeddingVector'] as List<dynamic>?;
    final vec = rawVec?.map((e) => (e as num).toDouble()).toList();

    return CivicFlowCase(
      id: id,
      caseNumber: map['caseNumber'] ?? 'CF-${DateTime.now().year}-000001',
      tenantId: map['tenantId'] ?? 'tenant_dehradun_01',
      citizenId: map['citizenId'] ?? '',
      citizenName: map['citizenName'] ?? 'Citizen',
      citizenPhone: map['citizenPhone'],
      category: map['category'] ?? 'Solid Waste',
      subcategory: map['subcategory'] ?? 'General',
      description: map['description'] ?? '',
      landmark: map['landmark'],
      locality: map['locality'] ?? 'Dehradun Central',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 30.3244,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 78.0416,
      imageUrl: map['imageUrl'],
      priority: map['priority'] ?? 'medium',
      status: map['status'] ?? CivicFlowStatus.submitted,
      assignedDepartment: map['assignedDepartment'],
      requiredDepartments: depts,
      departmentReasons: reasons,
      aiConfidence: (map['aiConfidence'] as num?)?.toDouble(),
      piiRedactedCount: (map['piiRedactedCount'] as num?)?.toInt() ?? 0,
      supportersCount: (map['supportersCount'] as num?)?.toInt() ?? 1,
      embeddingVector: vec,
      assignedOfficer: map['assignedOfficer'],
      sourceCivicBookPostId: map['sourceCivicBookPostId'],
      officerNotes: map['officerNotes'],
      citizenFeedback: map['citizenFeedback'],
      timeline: timelineEvents,
      createdAt: _parseFlowDateTime(map['createdAt']),
      updatedAt: _parseFlowDateTime(map['updatedAt']),
    );
  }
}
