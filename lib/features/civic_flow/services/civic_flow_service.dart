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
import '../models/civic_flow_model.dart';

/// State of the Citizen's CivicFlow Grievance Cases
class CivicFlowState {
  final bool isLoading;
  final List<CivicFlowCase> citizenCases;
  final String? errorMessage;
  final String? lastSubmittedCaseNumber;

  // Rate Limiting tracking timestamps (max 3 cases per 10 minutes)
  final List<DateTime> recentSubmissionTimes;

  const CivicFlowState({
    this.isLoading = false,
    this.citizenCases = const [],
    this.errorMessage,
    this.lastSubmittedCaseNumber,
    this.recentSubmissionTimes = const [],
  });

  /// Check whether client is currently rate limited (3 submissions within 10 minutes)
  bool get isRateLimited {
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    final activeCount = recentSubmissionTimes.where((t) => t.isAfter(tenMinutesAgo)).length;
    return activeCount >= 3;
  }

  /// Remaining seconds until rate limit window clears
  int get rateLimitCooldownSeconds {
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    final activeTimes = recentSubmissionTimes.where((t) => t.isAfter(tenMinutesAgo)).toList();
    if (activeTimes.length < 3) return 0;
    final oldestInWindow = activeTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    final expiresAt = oldestInWindow.add(const Duration(minutes: 10));
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  CivicFlowState copyWith({
    bool? isLoading,
    List<CivicFlowCase>? citizenCases,
    String? errorMessage,
    String? lastSubmittedCaseNumber,
    List<DateTime>? recentSubmissionTimes,
    bool clearError = false,
  }) {
    return CivicFlowState(
      isLoading: isLoading ?? this.isLoading,
      citizenCases: citizenCases ?? this.citizenCases,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSubmittedCaseNumber: lastSubmittedCaseNumber ?? this.lastSubmittedCaseNumber,
      recentSubmissionTimes: recentSubmissionTimes ?? this.recentSubmissionTimes,
    );
  }
}

/// Riverpod StateNotifier managing formal municipal grievances (100% Real Data, Zero Static Samples)
class CivicFlowNotifier extends StateNotifier<CivicFlowState> {
  final FirebaseFirestore? _firestore;
  final Ref _ref;
  static const _uuid = Uuid();

  static String _casesCacheKey(String uid) => 'evora_cf_real_cases_v1_$uid';

  CivicFlowNotifier(
    this._ref, [
    this._firestore,
    bool autoLoad = true,
  ]) : super(const CivicFlowState()) {
    if (autoLoad) {
      fetchCitizenCases();
    }
  }

  String _resolveDisplayName(String? rawName, {String fallback = 'Local Resident'}) {
    final trimmed = rawName?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : fallback;
  }

  Future<List<CivicFlowCase>> _loadCachedCases(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_casesCacheKey(uid));
      if (raw == null) return [];
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) {
            final map = e as Map<String, dynamic>;
            return CivicFlowCase.fromMap(map, id: map['id'] ?? '');
          })
          .where((c) => c.id.isNotEmpty && !c.id.startsWith('sample_') && !c.id.startsWith('seed_'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedCases(String uid, List<CivicFlowCase> cases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(cases.map((c) => c.toMap()).toList());
      await prefs.setString(_casesCacheKey(uid), encoded);
    } catch (_) {}
  }

  /// Fetches real cases filed by the current authenticated citizen (zero static sample data)
  Future<void> fetchCitizenCases() async {
    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) {
      state = state.copyWith(citizenCases: [], isLoading: false, clearError: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Fetching real citizen CivicFlow cases', correlationId: cid);

    final uid = currentUser.uid;

    final Map<String, CivicFlowCase> mergedById = {};

    // 1. Load real cached cases belonging to this user
    final cached = await _loadCachedCases(uid);
    for (final c in cached) {
      mergedById[c.id] = c;
    }

    // 2. Fetch live cases from Firestore (single-field filter avoids composite index errors)
    try {
      if (_firestore != null) {
        final querySnapshot = await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicFlowCases')
            .where('citizenId', isEqualTo: currentUser.uid)
            .get();

        for (final doc in querySnapshot.docs) {
          if (doc.id.startsWith('sample_') || doc.id.startsWith('seed_')) continue;
          final remoteCase = CivicFlowCase.fromMap(doc.data(), id: doc.id);
          mergedById[doc.id] = remoteCase;
        }
      }
    } catch (e) {
      LoggingService.logError('Firestore CivicFlow fetch note: $e', correlationId: cid);
    }

    final realCases = mergedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _saveCachedCases(uid, realCases);
    if (!mounted) return;
    state = state.copyWith(citizenCases: realCases, isLoading: false);
  }

  /// Submit a new formal grievance case with sliding window rate limiting
  Future<String?> submitCase({
    required String category,
    required String subcategory,
    required String description,
    required String locality,
    String? landmark,
    File? imageFile,
    String? sourceCivicBookPostId,
  }) async {
    // 1. Enforce sliding window rate limit
    if (state.isRateLimited) {
      final cd = state.rateLimitCooldownSeconds;
      state = state.copyWith(
        errorMessage: 'Submission limit reached (3 cases per 10 mins). Please wait ${cd}s before filing another case.',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Submitting formal CivicFlow case: $category', correlationId: cid);

    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in required to file a formal grievance.',
      );
      return null;
    }
    final uid = currentUser.uid;
    final citizenName = _resolveDisplayName(currentUser.displayName);
    final citizenPhone = currentUser.phoneNumber;

    // 2. Upload photo evidence to Cloudinary with EXIF stripping
    String? imageUrl;
    if (imageFile != null) {
      final uploadRes = await CloudinaryService.uploadImage(
        imageFile,
        folder: 'civic_flow_cases',
      );
      if (uploadRes.isSuccess) {
        imageUrl = uploadRes.url;
      }
    }

    if (!mounted) return null;

    // 3. Acquire location coordinates
    final loc = LocationService.currentLocation;
    final now = DateTime.now();
    final randomDigits = (_uuid.v4().hashCode.abs() % 900000) + 100000;
    final caseNumber = 'CF-${now.year}-$randomDigits';

    final initialTimeline = [
      CivicFlowTimelineEvent(
        status: CivicFlowStatus.submitted,
        title: 'Case Submitted by Citizen',
        description: 'Grievance recorded with unique tracking ID $caseNumber and queued for municipal triage.',
        timestamp: now,
        actor: citizenName,
      ),
    ];

    final newCase = CivicFlowCase(
      id: 'cf_${_uuid.v4().substring(0, 8)}',
      caseNumber: caseNumber,
      tenantId: AppConstants.defaultTenantId,
      citizenId: uid,
      citizenName: citizenName,
      citizenPhone: citizenPhone,
      category: category,
      subcategory: subcategory,
      description: description.trim(),
      landmark: landmark?.trim().isNotEmpty == true ? landmark!.trim() : null,
      locality: locality.trim(),
      latitude: loc.latitude,
      longitude: loc.longitude,
      imageUrl: imageUrl,
      priority: 'medium',
      status: CivicFlowStatus.submitted,
      sourceCivicBookPostId: sourceCivicBookPostId,
      timeline: initialTimeline,
      createdAt: now,
      updatedAt: now,
    );

    // 4. Persist locally & update state
    final updatedCases = [newCase, ...state.citizenCases];
    await _saveCachedCases(uid, updatedCases);
    if (!mounted) return null;

    final updatedTimes = [now, ...state.recentSubmissionTimes];
    state = state.copyWith(
      isLoading: false,
      citizenCases: updatedCases,
      lastSubmittedCaseNumber: caseNumber,
      recentSubmissionTimes: updatedTimes,
    );

    // 5. Save to Firestore
    try {
      if (_firestore != null) {
        await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicFlowCases')
            .doc(newCase.id)
            .set(newCase.toMap());
      }
    } catch (e) {
      LoggingService.logError('Firestore submitCase sync note: $e', correlationId: cid);
    }

    LoggingService.logBreadcrumb('Case created successfully with reference $caseNumber', correlationId: cid);
    return caseNumber;
  }

  /// Citizen responds to a "Needs Information" request
  Future<bool> respondToNeedsInfo(String caseId, String responseText) async {
    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) return false;
    final index = state.citizenCases.indexWhere((c) => c.id == caseId);
    if (index == -1) return false;

    final uid = currentUser.uid;

    final targetCase = state.citizenCases[index];
    final now = DateTime.now();

    final updateEvent = CivicFlowTimelineEvent(
      status: CivicFlowStatus.underTriage,
      title: 'Citizen Provided Requested Information',
      description: responseText.trim(),
      timestamp: now,
      actor: 'Citizen',
    );

    final updatedTimeline = [...targetCase.timeline, updateEvent];
    final updatedCase = targetCase.copyWith(
      status: CivicFlowStatus.underTriage,
      timeline: updatedTimeline,
      updatedAt: now,
    );

    final list = List<CivicFlowCase>.from(state.citizenCases);
    list[index] = updatedCase;
    state = state.copyWith(citizenCases: list);
    await _saveCachedCases(uid, list);

    // Sync to Firestore
    try {
      if (_firestore != null) {
        await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicFlowCases')
            .doc(caseId)
            .update({
          'status': CivicFlowStatus.underTriage,
          'timeline': updatedTimeline.map((e) => e.toMap()).toList(),
          'updatedAt': now.toIso8601String(),
        });
      }
    } catch (_) {}

    return true;
  }

  /// Confirm resolution or request reopening
  Future<bool> verifyResolution(String caseId, {required bool isSatisfied, String? feedback}) async {
    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) return false;
    final index = state.citizenCases.indexWhere((c) => c.id == caseId);
    if (index == -1) return false;

    final uid = currentUser.uid;

    final targetCase = state.citizenCases[index];
    final now = DateTime.now();

    final newStatus = isSatisfied ? CivicFlowStatus.resolved : CivicFlowStatus.inProgress;
    final title = isSatisfied ? 'Citizen Confirmed Resolution' : 'Citizen Requested Reopen';
    final desc = feedback ?? (isSatisfied ? 'Citizen satisfied with work.' : 'Issue unresolved; reopening case.');

    final event = CivicFlowTimelineEvent(
      status: newStatus,
      title: title,
      description: desc,
      timestamp: now,
      actor: 'Citizen',
    );

    final updatedTimeline = [...targetCase.timeline, event];
    final updatedCase = targetCase.copyWith(
      status: newStatus,
      citizenFeedback: feedback,
      timeline: updatedTimeline,
      updatedAt: now,
    );

    final list = List<CivicFlowCase>.from(state.citizenCases);
    list[index] = updatedCase;
    state = state.copyWith(citizenCases: list);
    await _saveCachedCases(uid, list);

    try {
      if (_firestore != null) {
        await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicFlowCases')
            .doc(caseId)
            .update({
          'status': newStatus,
          'citizenFeedback': feedback,
          'timeline': updatedTimeline.map((e) => e.toMap()).toList(),
          'updatedAt': now.toIso8601String(),
        });
      }
    } catch (_) {}

    return true;
  }
}

/// Global Riverpod Provider for CivicFlow Grievance Cases
final civicFlowProvider = StateNotifierProvider<CivicFlowNotifier, CivicFlowState>((ref) {
  ref.watch(authProvider.select((s) => s.user?.uid));
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return CivicFlowNotifier(ref, firestore);
});
