import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final List<CivicBookPost> allPosts;
  final double selectedRadiusKm; // 3.0 or 5.0
  final String selectedCategory; // 'all' or specific category
  final EvoraLocation userLocation;
  final String? errorMessage;

  const CivicBookState({
    this.isLoading = false,
    this.allPosts = const [],
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
      if (selectedCategory != 'all' && post.category.toLowerCase() != selectedCategory.toLowerCase()) {
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
    List<CivicBookPost>? allPosts,
    double? selectedRadiusKm,
    String? selectedCategory,
    EvoraLocation? userLocation,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CivicBookState(
      isLoading: isLoading ?? this.isLoading,
      allPosts: allPosts ?? this.allPosts,
      selectedRadiusKm: selectedRadiusKm ?? this.selectedRadiusKm,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      userLocation: userLocation ?? this.userLocation,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Riverpod Notifier managing CivicBook Community Feed
class CivicBookNotifier extends StateNotifier<CivicBookState> {
  final FirebaseFirestore? _firestore;
  final Ref _ref;
  static const _uuid = Uuid();

  CivicBookNotifier(this._ref, [this._firestore]) : super(const CivicBookState()) {
    initFeed();
  }

  Future<void> initFeed() async {
    state = state.copyWith(isLoading: true, clearError: true);
    // 1. Acquire current device coordinates or fallback
    final loc = await LocationService.acquireLocation();
    state = state.copyWith(userLocation: loc);

    // 2. Load posts from Firestore or Fallback Seed
    await refreshPosts();
  }

  /// Refreshes posts from Firestore with realistic community seed fallback
  Future<void> refreshPosts() async {
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Refreshing CivicBook community posts', correlationId: cid);

    final currentUser = _ref.read(authProvider).user;
    final uid = currentUser?.uid ?? 'guest_uid';

    try {
      if (_firestore != null) {
        final querySnapshot = await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final List<CivicBookPost> fetchedPosts = [];

          for (final doc in querySnapshot.docs) {
            // Check current user's vote
            int userVote = 0;
            try {
              final voteDoc = await doc.reference.collection('votes').doc(uid).get();
              if (voteDoc.exists) {
                userVote = (voteDoc.data()?['value'] as num?)?.toInt() ?? 0;
              }
            } catch (_) {}

            fetchedPosts.add(CivicBookPost.fromMap(doc.data(), id: doc.id, userVote: userVote));
          }

          state = state.copyWith(allPosts: fetchedPosts, isLoading: false);
          return;
        }
      }
    } catch (e) {
      LoggingService.logError('Failed to fetch from Firestore: $e. Falling back to initial seed.', correlationId: cid);
    }

    // Fallback seed posts for Dehradun area (all within ~1-6 km of Clock Tower)
    final now = DateTime.now();
    final seedPosts = [
      CivicBookPost(
        id: 'seed_cb_001',
        tenantId: AppConstants.defaultTenantId,
        authorId: 'resident_01',
        authorName: 'Aarav Sharma',
        title: 'Overflowing Municipal Dumpster near Astley Hall',
        description:
            'Solid waste is spilling onto the pedestrian walkway near Astley Hall. Stray animals scattering plastic.',
        category: 'waste',
        imageUrl:
            'https://images.unsplash.com/photo-1530587191325-3db32d826c18?auto=format&fit=crop&w=800&q=80',
        latitude: 30.3255,
        longitude: 78.0425,
        locality: 'Rajpur Road / Astley Hall',
        upvotesCount: 14,
        downvotesCount: 1,
        commentsCount: 3,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      CivicBookPost(
        id: 'seed_cb_002',
        tenantId: AppConstants.defaultTenantId,
        authorId: 'resident_02',
        authorName: 'Priya Nautiyal',
        title: 'Deep Pothole at Jakhan Diversion',
        description:
            'Severe road crater formed after recent rains near Pacific Mall junction. Two-wheelers slipping during rush hour.',
        category: 'roads',
        imageUrl:
            'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?auto=format&fit=crop&w=800&q=80',
        latitude: 30.3480,
        longitude: 78.0620,
        locality: 'Jakhan / Rajpur Road',
        upvotesCount: 28,
        downvotesCount: 0,
        commentsCount: 7,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      CivicBookPost(
        id: 'seed_cb_003',
        tenantId: AppConstants.defaultTenantId,
        authorId: 'resident_03',
        authorName: 'Vikram Negi',
        title: 'Broken Streetlight near Paltan Bazaar Gate',
        description:
            'Streetlight pole #32 has been flickering and completely off for the past two nights. Pitch dark alley.',
        category: 'lights',
        imageUrl: null,
        latitude: 30.3220,
        longitude: 78.0380,
        locality: 'Paltan Bazaar',
        upvotesCount: 9,
        downvotesCount: 0,
        commentsCount: 2,
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      CivicBookPost(
        id: 'seed_cb_004',
        tenantId: AppConstants.defaultTenantId,
        authorId: 'resident_04',
        authorName: 'Sunita Rawat',
        title: 'Water Pipe Leakage Flooding Subhash Road',
        description:
            'Clean drinking water leaking continuously from an underground municipal pipeline connection.',
        category: 'water',
        imageUrl:
            'https://images.unsplash.com/photo-1541888946425-d0fbb186c5f8?auto=format&fit=crop&w=800&q=80',
        latitude: 30.3290,
        longitude: 78.0460,
        locality: 'Subhash Road',
        upvotesCount: 21,
        downvotesCount: 1,
        commentsCount: 5,
        createdAt: now.subtract(const Duration(hours: 18)),
      ),
    ];

    state = state.copyWith(allPosts: seedPosts, isLoading: false);
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
    final uid = currentUser?.uid ?? 'guest_uid';

    // Find post in current state
    final index = state.allPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.allPosts[index];
    final currentVote = post.currentUserVote;

    // Determine new vote value
    int newVote = value;
    if (currentVote == value) {
      newVote = 0; // Toggle off to neutral
    }

    // Compute updated counts
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

    // Optimistic UI update
    final updatedList = List<CivicBookPost>.from(state.allPosts);
    updatedList[index] = updatedPost;
    state = state.copyWith(allPosts: updatedList);

    // Sync to Firestore if online
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
    } catch (_) {}
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
    final authorId = currentUser?.uid ?? 'anon_user';
    final authorName = currentUser?.displayName ?? 'Local Resident';

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

    // 3. Save to Firestore
    try {
      if (_firestore != null) {
        await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .doc(newPost.id)
            .set(newPost.toMap());
      }
    } catch (e) {
      LoggingService.logError('Firestore write error: $e', correlationId: cid);
    }

    // 4. Update local state
    state = state.copyWith(
      isLoading: false,
      allPosts: [newPost, ...state.allPosts],
    );

    return true;
  }

  /// Add a comment to an existing post
  Future<bool> addComment(String postId, String text) async {
    if (text.trim().isEmpty) return false;

    final currentUser = _ref.read(authProvider).user;
    final comment = CivicComment(
      id: 'comm_${_uuid.v4().substring(0, 8)}',
      postId: postId,
      authorId: currentUser?.uid ?? 'anon_user',
      authorName: currentUser?.displayName ?? 'Resident',
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    // Update local post comment count
    final index = state.allPosts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = state.allPosts[index];
      final updatedPost = post.copyWith(commentsCount: post.commentsCount + 1);
      final list = List<CivicBookPost>.from(state.allPosts);
      list[index] = updatedPost;
      state = state.copyWith(allPosts: list);
    }

    // Save to Firestore subcollection
    try {
      if (_firestore != null) {
        final postRef = _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicBookPosts')
            .doc(postId);

        await postRef.collection('comments').doc(comment.id).set(comment.toMap());
        await postRef.update({'commentsCount': FieldValue.increment(1)});
      }
    } catch (_) {}

    return true;
  }
}

/// Global Riverpod Provider for CivicBook Feed
final civicBookProvider = StateNotifierProvider<CivicBookNotifier, CivicBookState>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return CivicBookNotifier(ref, firestore);
});
