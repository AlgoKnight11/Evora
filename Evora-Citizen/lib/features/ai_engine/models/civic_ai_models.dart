import 'dart:io';

/// Normalized bounding box (0..1000 scale) of PII detected in a citizen photo.
class PiiBoundingBox {
  /// 'face' or 'license_plate'
  final String label;
  final int ymin;
  final int xmin;
  final int ymax;
  final int xmax;

  const PiiBoundingBox({
    required this.label,
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
  });

  bool get isValid => xmax > xmin && ymax > ymin;

  factory PiiBoundingBox.fromMap(Map<String, dynamic> map) {
    int clampCoord(dynamic v) => ((v as num?)?.round() ?? 0).clamp(0, 1000);

    // Support both flat {ymin, xmin, ymax, xmax} and array {box_2d: [ymin, xmin, ymax, xmax]}
    final boxList = map['box_2d'];
    if (boxList is List && boxList.length >= 4) {
      return PiiBoundingBox(
        label: (map['label'] ?? 'face').toString().toLowerCase(),
        ymin: clampCoord(boxList[0]),
        xmin: clampCoord(boxList[1]),
        ymax: clampCoord(boxList[2]),
        xmax: clampCoord(boxList[3]),
      );
    }

    return PiiBoundingBox(
      label: (map['label'] ?? 'face').toString().toLowerCase(),
      ymin: clampCoord(map['ymin']),
      xmin: clampCoord(map['xmin']),
      ymax: clampCoord(map['ymax']),
      xmax: clampCoord(map['xmax']),
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'ymin': ymin,
        'xmin': xmin,
        'ymax': ymax,
        'xmax': xmax,
      };
}

/// Summary returned after on-device image compression, EXIF removal, and PII blur.
class PiiRedactionResult {
  final File? file;
  final List<int> bytes;
  final int facesBlurred;
  final int platesBlurred;
  final int originalBytesLength;
  final int processedBytesLength;

  const PiiRedactionResult({
    this.file,
    required this.bytes,
    required this.facesBlurred,
    required this.platesBlurred,
    required this.originalBytesLength,
    required this.processedBytesLength,
  });

  int get totalRedacted => facesBlurred + platesBlurred;
  bool get hasRedactions => totalRedacted > 0;
}

/// Individual municipal department involvement identified by AI triage.
class DepartmentAssignment {
  final String department;
  final String role; // 'lead' or 'supporting'
  final String reason;

  const DepartmentAssignment({
    required this.department,
    required this.role,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
        'department': department,
        'role': role,
        'reason': reason,
      };
}

/// Structured output returned by Gemini 3.8 Flash CivicFlow Vision Classifier.
class CivicVisionAnalysis {
  final bool isValidCivicIssue;
  final String? rejectionReason;
  final String category;
  final String subcategory;
  final String civicBookCategoryKey;
  final double confidence; // 0.0 .. 1.0
  final String severity; // 'low', 'medium', 'high', 'urgent'
  final String suggestedTitle;
  final String suggestedDescription;
  final String leadDepartment;
  final List<String> requiredDepartments;
  final List<DepartmentAssignment> departmentAssignments;
  final List<PiiBoundingBox> piiRegions;
  final String issueFingerprintText;
  final bool fromCache;
  final String correlationId;

  const CivicVisionAnalysis({
    required this.isValidCivicIssue,
    this.rejectionReason,
    required this.category,
    required this.subcategory,
    required this.civicBookCategoryKey,
    required this.confidence,
    required this.severity,
    required this.suggestedTitle,
    required this.suggestedDescription,
    required this.leadDepartment,
    required this.requiredDepartments,
    required this.departmentAssignments,
    this.piiRegions = const [],
    required this.issueFingerprintText,
    this.fromCache = false,
    required this.correlationId,
  });

  bool get isMultiDepartment => requiredDepartments.length > 1;
  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  Map<String, String> get departmentReasonsMap {
    final map = <String, String>{};
    for (final d in departmentAssignments) {
      map[d.department] = d.reason;
    }
    return map;
  }

  CivicVisionAnalysis copyWith({bool? fromCache}) {
    return CivicVisionAnalysis(
      isValidCivicIssue: isValidCivicIssue,
      rejectionReason: rejectionReason,
      category: category,
      subcategory: subcategory,
      civicBookCategoryKey: civicBookCategoryKey,
      confidence: confidence,
      severity: severity,
      suggestedTitle: suggestedTitle,
      suggestedDescription: suggestedDescription,
      leadDepartment: leadDepartment,
      requiredDepartments: requiredDepartments,
      departmentAssignments: departmentAssignments,
      piiRegions: piiRegions,
      issueFingerprintText: issueFingerprintText,
      fromCache: fromCache ?? this.fromCache,
      correlationId: correlationId,
    );
  }
}

/// Candidate existing report/post found within duplicate geofence radius (~500m).
class DuplicateCandidate {
  /// 'civic_flow_case' or 'civic_book_post'
  final String sourceType;
  final String sourceId;
  final String referenceLabel; // e.g., CF-2026-123456 or 'CivicBook Post'
  final String title;
  final String description;
  final String category;
  final String locality;
  final String status;
  final double distanceMeters;
  final double similarityScore; // 0.0 .. 1.0
  final String matchReason;
  final String? imageUrl;
  final int upvotesCount;
  final DateTime createdAt;

  const DuplicateCandidate({
    required this.sourceType,
    required this.sourceId,
    required this.referenceLabel,
    required this.title,
    required this.description,
    required this.category,
    required this.locality,
    required this.status,
    required this.distanceMeters,
    required this.similarityScore,
    required this.matchReason,
    this.imageUrl,
    this.upvotesCount = 0,
    required this.createdAt,
  });

  int get matchPercent => (similarityScore * 100).round().clamp(0, 100);
}
