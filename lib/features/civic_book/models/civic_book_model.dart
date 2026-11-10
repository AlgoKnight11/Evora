/// Parses DateTime safely from ISO-8601 String, DateTime, or Firestore Timestamp
DateTime _parseCivicDateTime(dynamic value) {
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

/// CivicBook Community Post Model
class CivicBookPost {
  final String id;
  final String tenantId;
  final String authorId;
  final String authorName;
  final String title;
  final String description;
  final String category; // 'waste', 'roads', 'water', 'lights', 'greenery', 'sanitation', 'general'
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String locality;
  final int upvotesCount;
  final int downvotesCount;
  final int commentsCount;
  final bool isFormalCaseRaised;
  final String? civicFlowCaseId;
  final DateTime createdAt;

  // Transient state per user session
  final int currentUserVote; // 1 = upvoted, -1 = downvoted, 0 = neutral
  final double? distanceKm;

  const CivicBookPost({
    required this.id,
    required this.tenantId,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.locality,
    this.upvotesCount = 0,
    this.downvotesCount = 0,
    this.commentsCount = 0,
    this.isFormalCaseRaised = false,
    this.civicFlowCaseId,
    required this.createdAt,
    this.currentUserVote = 0,
    this.distanceKm,
  });

  int get score => upvotesCount - downvotesCount;

  CivicBookPost copyWith({
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? locality,
    int? upvotesCount,
    int? downvotesCount,
    int? commentsCount,
    bool? isFormalCaseRaised,
    String? civicFlowCaseId,
    int? currentUserVote,
    double? distanceKm,
  }) {
    return CivicBookPost(
      id: id,
      tenantId: tenantId,
      authorId: authorId,
      authorName: authorName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locality: locality ?? this.locality,
      upvotesCount: upvotesCount ?? this.upvotesCount,
      downvotesCount: downvotesCount ?? this.downvotesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isFormalCaseRaised: isFormalCaseRaised ?? this.isFormalCaseRaised,
      civicFlowCaseId: civicFlowCaseId ?? this.civicFlowCaseId,
      createdAt: createdAt,
      currentUserVote: currentUserVote ?? this.currentUserVote,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'locality': locality,
      'upvotesCount': upvotesCount,
      'downvotesCount': downvotesCount,
      'commentsCount': commentsCount,
      'isFormalCaseRaised': isFormalCaseRaised,
      'civicFlowCaseId': civicFlowCaseId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CivicBookPost.fromMap(Map<String, dynamic> map, {required String id, int userVote = 0, double? distance}) {
    return CivicBookPost(
      id: id,
      tenantId: map['tenantId'] ?? 'tenant_dehradun_01',
      authorId: map['authorId'] ?? 'unknown_author',
      authorName: map['authorName'] ?? 'Local Resident',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'general',
      imageUrl: map['imageUrl'],
      latitude: (map['latitude'] as num?)?.toDouble() ?? 30.3244,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 78.0416,
      locality: map['locality'] ?? 'Dehradun Central',
      upvotesCount: (map['upvotesCount'] as num?)?.toInt() ?? 0,
      downvotesCount: (map['downvotesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      isFormalCaseRaised: map['isFormalCaseRaised'] ?? false,
      civicFlowCaseId: map['civicFlowCaseId'],
      createdAt: _parseCivicDateTime(map['createdAt']),
      currentUserVote: userVote,
      distanceKm: distance,
    );
  }
}

/// CivicBook Post Comment Model
class CivicComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const CivicComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CivicComment.fromMap(Map<String, dynamic> map, {required String id}) {
    return CivicComment(
      id: id,
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Resident',
      text: map['text'] ?? '',
      createdAt: _parseCivicDateTime(map['createdAt']),
    );
  }
}
