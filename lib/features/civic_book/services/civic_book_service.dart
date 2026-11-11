import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/location_service.dart';
import '../../../services/logging_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/civic_book_model.dart';

/// State of the CivicBook Community Observation Feed
class CivicBookState {
  final bool isLoading;
  final bool isLoadingComments;
  final List<CivicBookPost> allPosts;
  final Map<String, List<CivicComment>> commentsByPost;
  final double selectedRadiusKm; // 3.0 or 5.0
  final String selectedCategory; // 'all' or specific category
  final EvoraLocation userLocation;
  final String? errorMessage;

  const CivicBookState({
    this.isLoading = false,
    this.isLoadingComments = false,
    this.allPosts = const [],
    this.commentsByPost = const {},
    this.selectedRadiusKm = AppConstants.defaultFeedRadiusKm, // 3.0 km
    this.selectedCategory = 'all',
    this.userLocation = EvoraLocation.defaultDehradun,
    this.errorMessage,
  });

  /// Filtered posts within the selected spatial radius and category
  List<CivicBookPost> get filteredPosts {
    return allPosts.where((post) {
      // 1. Spatial Radius Check (Haversine distance <= selectedRadius)
      final distance = LocationService.calculateDistanceKm(
        startLatitude: userLocation.latitude,
        startLongitude: userLocation.longitude,
        endLatitude: post.latitude,
        endLongitude: post.longitude,
      );

      final isWithinRadius = distance <= selectedRadiusKm;
      if (!isWithinRadius) return false;

      // 2. Category Check
      if (selectedCategory != 'all' &&
          post.category.toLowerCase() != selectedCategory.toLowerCase()) {
        return false;
      }

      return true;
    }).map((p) {
      final dist = LocationService.calculateDistanceKm(
        startLatitude: userLocation.latitude,
        startLongitude: userLocation.longitude,
        endLatitude: p.latitude,
        endLongitude: p.longitude,
      );
      return p.copyWith(distanceKm: dist);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  CivicBookState copyWith({
    bool? isLoading,
    bool? isLoadingComments,
    List<CivicBookPost>? allPosts,
    Map<String, List<CivicComment>>? commentsByPost,
    double? selectedRadiusKm,
    String? selectedCategory,
    EvoraLocation? userLocation,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CivicBookState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      allPosts: allPosts ?? this.allPosts,
      commentsByPost: commentsByPost ?? this.commentsByPost,
      selectedRadiusKm: selectedRadiusKm ?? this.selectedRadiusKm,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      userLocation: userLocation ?? this.userLocation,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Riverpod Notifier managing CivicBook Community Feed (100% Real Data, Zero Static Seeds)
class CivicBookNotifier extends StateNotifier<CivicBookState> {
  final FirebaseFirestore? _firestore;
  final Ref _ref;
  static const _uuid = Uuid();

  static const String _postsCacheKey = 'evora_cb_real_posts_v1';
  static String _commentsCacheKey(String postId) => 'evora_cb_real_comments_$postId';
  static String _votesCacheKey(String uid) => 'evora_cb_real_votes_$uid';

  CivicBookNotifier(
    this._ref, [
    this._firestore,
    bool autoLoad = true,
  ]) : super(const CivicBookState()) {
    if (autoLoad) {
      initFeed();
    }
  }

  String _resolveDisplayName(String? rawName, {String fallback = 'Local Resident'}) {
    final trimmed = rawName?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : fallback;
  }

  Future<void> initFeed() async {
    state = state.copyWith(isLoading: true, clearError: true);
    // 1. Acquire current device coordinates or fallback
    final loc = await LocationService.acquireLocation();
    if (!mounted) return;
    state = state.copyWith(userLocation: loc);

    // 2. Load real posts from Firestore & real local cache
    await refreshPosts();
  }

  Future<List<CivicBookPost>> _loadCachedPosts(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPosts = prefs.getString(_postsCacheKey);
      final rawVotes = uid != null ? prefs.getString(_votesCacheKey(uid)) : null;

      Map<String, int> userVotes = {};
      if (rawVotes != null) {
        final decodedVotes = jsonDecode(rawVotes) as Map<String, dynamic>;
        userVotes = decodedVotes.map((k, v) => MapEntry(k, (v as num).toInt()));
      }

      if (rawPosts == null) return [];
      final List<dynamic> decoded = jsonDecode(rawPosts);
      return decoded
          .map((e) {
            final map = e as Map<String, dynamic>;
            final id = map['id'] as String? ?? '';
            return CivicBookPost.fromMap(map, id: id, userVote: userVotes[id] ?? 0);
          })
          .where((p) => p.id.isNotEmpty && !p.id.startsWith('seed_'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedPosts(List<CivicBookPost> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(posts.map((p) => p.toMap()).toList());
      await prefs.setString(_postsCacheKey, encoded);
    } catch (_) {}
  }

  Future<void> _saveCachedVote(String uid, String postId, int voteValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawVotes = prefs.getString(_votesCacheKey(uid));
      Map<String, dynamic> votes = {};
      if (rawVotes != null) {
        votes = jsonDecode(rawVotes) as Map<String, dynamic>;
      }
      if (voteValue == 0) {
        votes.remove(postId);
      } else {
        votes[postId] = voteValue;
      }
      await prefs.setString(_votesCacheKey(uid), jsonEncode(votes));
    } catch (_) {}
  }

  Future<List<CivicComment>> _loadCachedComments(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_commentsCacheKey(postId));
      if (raw == null) return [];
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) {
            final map = e as Map<String, dynamic>;
            return CivicComment.fromMap(map, id: map['id'] ?? '');
          })
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedComments(String postId, List<CivicComment> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(comments.map((c) => c.toMap()).toList());
      await prefs.setString(_commentsCacheKey(postId), encoded);
    } catch (_) {}
  }

  /// Refreshes posts strictly from Firestore & verified real local cache (zero fake/seed data)
  Future<void> refreshPosts() async {
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Refreshing real CivicBook community posts', correlationId: cid);

    final currentUser = _ref.read(authProvider).user;
    final uid = currentUser?.uid;

    // 1. Load real cached posts (e.g. posts created while offline or dev-test phone mode)
    final Map<String, CivicBookPost> mergedById = {};
    final cachedPosts = await _loadCachedPosts(uid);
    for (final p in cachedPosts) {
      mergedById[p.id] = p;
    }

    // 2. Fetch live posts from Firestore
    try {
      if (_firestore != null) {
        final querySnapshot = await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        for (final doc in querySnapshot.docs) {
          if (doc.id.startsWith('seed_')) continue;

          int userVote = 0;
          if (uid != null) {
            try {
              final voteDoc = await doc.reference.collection('votes').doc(uid).get();
              if (voteDoc.exists) {
                userVote = (voteDoc.data()?['value'] as num?)?.toInt() ?? 0;
              } else {
                userVote = mergedById[doc.id]?.currentUserVote ?? 0;
              }
            } catch (_) {
              userVote = mergedById[doc.id]?.currentUserVote ?? 0;
            }
          }

          final firestorePost = CivicBookPost.fromMap(
            doc.data(),
            id: doc.id,
            userVote: userVote,
          );
          final cachedComments = await _loadCachedComments(doc.id);
          final resolvedCommentsCount = firestorePost.commentsCount > cachedComments.length
              ? firestorePost.commentsCount
              : cachedComments.length;

          mergedById[doc.id] = firestorePost.copyWith(commentsCount: resolvedCommentsCount);
        }
      }
    } catch (e) {
      LoggingService.logError('Firestore CivicBook fetch note: $e', correlationId: cid);
    }

    final realPosts = mergedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _saveCachedPosts(realPosts);
    if (!mounted) return;
    state = state.copyWith(allPosts: realPosts, isLoading: false);
  }

  /// Switch spatial feed radius between 3 km (default) and 5 km (expanded)
  void setRadius(double radiusKm) {
    state = state.copyWith(selectedRadiusKm: radiusKm);
    LoggingService.logBreadcrumb('Switched CivicBook geofence radius to $radiusKm km');
  }

  /// Switch category filter
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Cast an Upvote (+1), Downvote (-1), or Neutral (0)
  Future<void> toggleVote(String postId, int value) async {
    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) return;
    final uid = currentUser.uid;

    final index = state.allPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.allPosts[index];
    final currentVote = post.currentUserVote;

    int newVote = value;
    if (currentVote == value) {
      newVote = 0; // Toggle off to neutral
    }

    int upDelta = 0;
    int downDelta = 0;

    if (currentVote == 1) upDelta -= 1;
    if (currentVote == -1) downDelta -= 1;

    if (newVote == 1) upDelta += 1;
    if (newVote == -1) downDelta += 1;

    final updatedPost = post.copyWith(
      upvotesCount: (post.upvotesCount + upDelta).clamp(0, 99999),
      downvotesCount: (post.downvotesCount + downDelta).clamp(0, 99999),
      currentUserVote: newVote,
    );

    final updatedList = List<CivicBookPost>.from(state.allPosts);
    updatedList[index] = updatedPost;
    state = state.copyWith(allPosts: updatedList);

    await _saveCachedVote(uid, postId, newVote);
    await _saveCachedPosts(updatedList);

    // Sync to Firestore if online & authorized
    try {
      if (_firestore != null) {
        final postRef = _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .doc(postId);

        final voteRef = postRef.collection('votes').doc(uid);

        if (newVote == 0) {
          await voteRef.delete();
        } else {
          await voteRef.set({
            'value': newVote,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await postRef.update({
          'upvotesCount': updatedPost.upvotesCount,
          'downvotesCount': updatedPost.downvotesCount,
        });
      }
    } catch (e) {
      LoggingService.logError('Firestore vote sync note: $e');
    }
  }

  /// Submit a new CivicBook observation post
  Future<bool> createPost({
    required String title,
    required String description,
    required String category,
    File? imageFile,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Creating CivicBook post: $title', correlationId: cid);

    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Sign in required to post.');
      return false;
    }
    final authorId = currentUser.uid;
    final authorName = _resolveDisplayName(currentUser.displayName);

    // 1. Upload photo to Cloudinary if provided
    String? uploadedUrl;
    if (imageFile != null) {
      final uploadResult = await CloudinaryService.uploadImage(
        imageFile,
        folder: 'civic_book_observations',
      );
      if (uploadResult.isSuccess) {
        uploadedUrl = uploadResult.url;
      }
    }

    if (!mounted) return false;

    // 2. Apply privacy fuzzing to coordinates (~100m generalization)
    final fuzzed = LocationService.applyPrivacyFuzzing(
      state.userLocation.latitude,
      state.userLocation.longitude,
    );

    final newPost = CivicBookPost(
      id: 'cb_${_uuid.v4().substring(0, 8)}',
      tenantId: AppConstants.defaultTenantId,
      authorId: authorId,
      authorName: authorName,
      title: title.trim(),
      description: description.trim(),
      category: category.toLowerCase(),
      imageUrl: uploadedUrl,
      latitude: fuzzed.lat,
      longitude: fuzzed.lng,
      locality: state.userLocation.localityName,
      upvotesCount: 1, // Author automatic upvote
      downvotesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
      currentUserVote: 1,
    );

    // 3. Persist locally and update state immediately
    final updatedPosts = [newPost, ...state.allPosts];
    await _saveCachedVote(authorId, newPost.id, 1);
    await _saveCachedPosts(updatedPosts);
    if (!mounted) return false;
    state = state.copyWith(
      isLoading: false,
      allPosts: updatedPosts,
    );

    // 4. Sync to Firestore
    try {
      if (_firestore != null) {
        final postRef = _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .doc(newPost.id);
        await postRef.set(newPost.toMap());
        await postRef.collection('votes').doc(authorId).set({
          'value': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      LoggingService.logError('Firestore createPost sync note: $e', correlationId: cid);
    }

    return true;
  }

  /// Load real comments for a specific CivicBook post (Firestore + Real Local Cache)
  Future<void> loadComments(String postId) async {
    state = state.copyWith(isLoadingComments: true);
    final cid = LoggingService.generateCorrelationId();

    final Map<String, CivicComment> merged = {};

    // 1. Fetch live comments from Firestore subcollection
    try {
      if (_firestore != null) {
        final snap = await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .doc(postId)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .get();

        for (final doc in snap.docs) {
          final comment = CivicComment.fromMap(doc.data(), id: doc.id);
          merged[doc.id] = comment;
        }
      }
    } catch (e) {
      LoggingService.logError('Firestore loadComments note: $e', correlationId: cid);
    }

    // 2. Re-read latest locally persisted + in-memory comments after await to prevent losing concurrent submissions
    final cached = await _loadCachedComments(postId);
    for (final c in cached) {
      merged.putIfAbsent(c.id, () => c);
    }
    if (!mounted) return;
    for (final c in (state.commentsByPost[postId] ?? const <CivicComment>[])) {
      merged.putIfAbsent(c.id, () => c);
    }

    final realComments = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _saveCachedComments(postId, realComments);
    if (!mounted) return;

    final updatedMap = Map<String, List<CivicComment>>.from(state.commentsByPost);
    updatedMap[postId] = realComments;

    // Ensure post commentsCount reflects real comments list size
    final index = state.allPosts.indexWhere((p) => p.id == postId);
    List<CivicBookPost> updatedPosts = state.allPosts;
    if (index != -1 && state.allPosts[index].commentsCount != realComments.length) {
      updatedPosts = List<CivicBookPost>.from(state.allPosts);
      updatedPosts[index] = state.allPosts[index].copyWith(commentsCount: realComments.length);
      await _saveCachedPosts(updatedPosts);
    }

    if (!mounted) return;
    state = state.copyWith(
      commentsByPost: updatedMap,
      allPosts: updatedPosts,
      isLoadingComments: false,
    );
  }

  /// Add a real comment to an existing post and surface it immediately
  Future<bool> addComment(String postId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) return false;
    final comment = CivicComment(
      id: 'comm_${_uuid.v4().substring(0, 8)}',
      postId: postId,
      authorId: currentUser.uid,
      authorName: _resolveDisplayName(currentUser.displayName, fallback: 'Resident'),
      text: trimmed,
      createdAt: DateTime.now(),
    );

    // 1. Prepend comment immediately to state so user sees it instantly
    final existingComments = List<CivicComment>.from(state.commentsByPost[postId] ?? []);
    final updatedComments = [comment, ...existingComments];

    final updatedMap = Map<String, List<CivicComment>>.from(state.commentsByPost);
    updatedMap[postId] = updatedComments;

    // 2. Update post commentsCount cleanly
    final updatedPosts = List<CivicBookPost>.from(state.allPosts);
    final index = updatedPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      updatedPosts[index] = updatedPosts[index].copyWith(
        commentsCount: updatedComments.length,
      );
    }

    state = state.copyWith(
      commentsByPost: updatedMap,
      allPosts: updatedPosts,
    );

    // 3. Persist locally so user's interaction always survives restarts
    await _saveCachedComments(postId, updatedComments);
    await _saveCachedPosts(updatedPosts);

    // 4. Save to Firestore subcollection
    try {
      if (_firestore != null) {
        final postRef = _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .doc(postId);

        await postRef.collection('comments').doc(comment.id).set(comment.toMap());
        try {
          await postRef.update({'commentsCount': updatedComments.length});
        } catch (_) {}
      }
    } catch (e) {
      LoggingService.logError('Firestore addComment sync note: $e');
    }

    return true;
  }
}

/// Global Riverpod Provider for CivicBook Feed
final civicBookProvider = StateNotifierProvider<CivicBookNotifier, CivicBookState>((ref) {
  ref.watch(authProvider.select((s) => s.user?.uid));
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return CivicBookNotifier(ref, firestore);
});
