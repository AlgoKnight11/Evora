import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/ai_gateway_service.dart';
import '../../../services/location_service.dart';
import '../../../services/logging_service.dart';
import '../../civic_book/models/civic_book_model.dart';
import '../../civic_flow/models/civic_flow_model.dart';
import '../../civic_flow/models/civic_taxonomy.dart';
import '../models/civic_ai_models.dart';

/// Phase 3 Geospatial & Visual/Semantic Duplicate Detector.
///
/// Queries active open CivicFlow cases and CivicBook observations within a
/// strict 500m Haversine radius, comparing stored multimodal vectors (cosine
/// similarity) plus lexical/category heuristics when older posts lack vectors.
class DuplicateDetectorService {
  final FirebaseFirestore? _firestore;

  DuplicateDetectorService([this._firestore]);

  static const Set<String> _inactiveFlowStatuses = {
    CivicFlowStatus.resolved,
    CivicFlowStatus.closed,
  };

  /// Scans nearby active CivicFlow cases and CivicBook posts within [radiusKm]
  /// (default 0.5 km = 500m) for duplicates matching the prospective report.
  Future<List<DuplicateCandidate>> findNearbyDuplicates({
    required double latitude,
    required double longitude,
    required String category,
    required String subcategory,
    required String summaryText,
    List<double>? embeddingVector,
    List<CivicFlowCase> inMemoryCases = const [],
    List<CivicBookPost> inMemoryPosts = const [],
    String? excludePostId,
    double radiusKm = AppConstants.duplicateDetectionRadiusKm,
  }) async {
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb(
      'Running 500m duplicate check for $category ($subcategory)',
      correlationId: cid,
    );

    final Map<String, CivicFlowCase> caseById = {
      for (final c in inMemoryCases) c.id: c,
    };
    final Map<String, CivicBookPost> postById = {
      for (final p in inMemoryPosts) p.id: p,
    };

    // Merge live tenant records from Firestore (if online)
    if (_firestore != null) {
      try {
        final casesSnap = await _firestore
            .collection(AppConstants.colTenants)
            .doc(AppConstants.defaultTenantId)
            .collection(AppConstants.subColCivicFlowCases)
            .orderBy('createdAt', descending: true)
            .limit(60)
            .get();

        for (final doc in casesSnap.docs) {
          if (doc.id.startsWith('sample_') || doc.id.startsWith('seed_')) continue;
          caseById[doc.id] = CivicFlowCase.fromMap(doc.data(), id: doc.id);
        }
      } catch (e) {
        LoggingService.logError('Duplicate check CivicFlow fetch note: $e', correlationId: cid);
      }

      try {
        final postsSnap = await _firestore
            .collection(AppConstants.colTenants)
            .doc(AppConstants.defaultTenantId)
            .collection(AppConstants.subColCivicBookPosts)
            .orderBy('createdAt', descending: true)
            .limit(60)
            .get();

        for (final doc in postsSnap.docs) {
          if (doc.id.startsWith('seed_')) continue;
          postById[doc.id] = CivicBookPost.fromMap(doc.data(), id: doc.id);
        }
      } catch (e) {
        LoggingService.logError('Duplicate check CivicBook fetch note: $e', correlationId: cid);
      }
    }

    final normalizedNewCategory = CivicTaxonomy.normalizeCategory(category);
    final normalizedNewBookKey = CivicTaxonomy.toCivicBookKey(normalizedNewCategory);
    final newTokens = _tokenize('$normalizedNewCategory $subcategory $summaryText');

    final List<DuplicateCandidate> matches = [];

    // 1. Evaluate nearby active CivicFlow cases
    for (final c in caseById.values) {
      if (_inactiveFlowStatuses.contains(c.status)) continue;

      final distKm = LocationService.calculateDistanceKm(
        startLatitude: latitude,
        startLongitude: longitude,
        endLatitude: c.latitude,
        endLongitude: c.longitude,
      );
      if (distKm > radiusKm) continue;

      final distMeters = distKm * 1000.0;
      final eval = _scoreSimilarity(
        targetVector: embeddingVector,
        candidateVector: c.embeddingVector,
        newCategory: normalizedNewCategory,
        candidateCategory: CivicTaxonomy.normalizeCategory(c.category),
        newTokens: newTokens,
        candidateTokens: _tokenize('${c.category} ${c.subcategory} ${c.description} ${c.landmark ?? ''}'),
        distanceMeters: distMeters,
      );

      if (eval.isDuplicate) {
        matches.add(DuplicateCandidate(
          sourceType: 'civic_flow_case',
          sourceId: c.id,
          referenceLabel: c.caseNumber,
          title: '${c.category} — ${c.subcategory}',
          description: c.description,
          category: c.category,
          locality: c.locality,
          status: CivicFlowStatus.getLabel(c.status),
          distanceMeters: distMeters,
          similarityScore: eval.score,
          matchReason: eval.reason,
          imageUrl: c.imageUrl,
          upvotesCount: c.supportersCount,
          createdAt: c.createdAt,
        ));
      }
    }

    // 2. Evaluate nearby CivicBook community observations
    for (final p in postById.values) {
      if (excludePostId != null && p.id == excludePostId) continue;

      final distKm = LocationService.calculateDistanceKm(
        startLatitude: latitude,
        startLongitude: longitude,
        endLatitude: p.latitude,
        endLongitude: p.longitude,
      );
      if (distKm > radiusKm) continue;

      final distMeters = distKm * 1000.0;
      final candidateFlowCategory = CivicTaxonomy.fromCivicBookKey(p.category);
      final sameBucket = p.category.toLowerCase() == normalizedNewBookKey ||
          candidateFlowCategory == normalizedNewCategory;

      final eval = _scoreSimilarity(
        targetVector: embeddingVector,
        candidateVector: p.embeddingVector,
        newCategory: normalizedNewCategory,
        candidateCategory: sameBucket ? normalizedNewCategory : candidateFlowCategory,
        newTokens: newTokens,
        candidateTokens: _tokenize('${p.title} ${p.description} ${p.category}'),
        distanceMeters: distMeters,
      );

      if (eval.isDuplicate) {
        matches.add(DuplicateCandidate(
          sourceType: 'civic_book_post',
          sourceId: p.id,
          referenceLabel: p.isFormalCaseRaised
              ? 'CivicBook (Case Raised)'
              : 'CivicBook Observation',
          title: p.title,
          description: p.description,
          category: p.category,
          locality: p.locality,
          status: '${p.upvotesCount} upvotes',
          distanceMeters: distMeters,
          similarityScore: eval.score,
          matchReason: eval.reason,
          imageUrl: p.imageUrl,
          upvotesCount: p.upvotesCount,
          createdAt: p.createdAt,
        ));
      }
    }

    matches.sort((a, b) {
      final scoreCmp = b.similarityScore.compareTo(a.similarityScore);
      if (scoreCmp != 0) return scoreCmp;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return matches;
  }

  ({bool isDuplicate, double score, String reason}) _scoreSimilarity({
    required List<double>? targetVector,
    required List<double>? candidateVector,
    required String newCategory,
    required String candidateCategory,
    required Set<String> newTokens,
    required Set<String> candidateTokens,
    required double distanceMeters,
  }) {
    final sameCategory = newCategory == candidateCategory;
    final lexicalScore = _jaccardSimilarity(newTokens, candidateTokens);

    // Compute dense multimodal/semantic cosine similarity when both have embeddings
    double? vectorScore;
    if (targetVector != null &&
        candidateVector != null &&
        targetVector.isNotEmpty &&
        targetVector.length == candidateVector.length) {
      vectorScore = AiGatewayService.cosineSimilarity(targetVector, candidateVector);
    }

    // Immediate proximity boost: <= 100m apart for the same civic issue category
    final proximityBoost = distanceMeters <= 100.0
        ? 0.10
        : (distanceMeters <= 250.0 ? 0.05 : 0.0);

    if (vectorScore != null) {
      final fused = (vectorScore * 0.78 +
              (sameCategory ? 0.14 : 0.0) +
              lexicalScore * 0.08 +
              proximityBoost)
          .clamp(0.0, 0.99);

      final isMatch = vectorScore >= AppConstants.duplicateSimilarityThreshold ||
          (fused >= AppConstants.duplicateSimilarityThreshold && sameCategory);

      return (
        isDuplicate: isMatch,
        score: max(vectorScore, fused).clamp(0.0, 0.99),
        reason: vectorScore >= AppConstants.duplicateSimilarityThreshold
            ? 'High AI visual/semantic similarity ${(vectorScore * 100).round()}% within ${distanceMeters.round()}m'
            : 'Similar $candidateCategory report ${distanceMeters.round()}m away',
      );
    }

    // Fallback when comparing against historical posts that predate embeddings
    final heuristicScore =
        ((sameCategory ? 0.48 : 0.0) + lexicalScore * 0.52 + proximityBoost)
            .clamp(0.0, 0.98);

    final isMatch = (sameCategory && lexicalScore >= 0.25 && distanceMeters <= 500) ||
        (sameCategory && distanceMeters <= 120 && lexicalScore >= 0.15) ||
        lexicalScore >= 0.55;

    return (
      isDuplicate: isMatch,
      score: heuristicScore,
      reason: 'Matching $candidateCategory details within ${distanceMeters.round()}m',
    );
  }

  static double _jaccardSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  static Set<String> _tokenize(String text) {
    const stopWords = {
      'the',
      'and',
      'for',
      'with',
      'that',
      'this',
      'from',
      'near',
      'issue',
      'reported',
      'municipal',
      'please',
      'there',
      'here',
      'have',
      'been',
    };
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toSet();
  }
}

final duplicateDetectorProvider = Provider<DuplicateDetectorService>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return DuplicateDetectorService(firestore);
});
