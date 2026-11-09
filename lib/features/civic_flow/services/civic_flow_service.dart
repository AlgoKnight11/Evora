import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (!isRateLimited) return 0;
    final oldestInWindow = recentSubmissionTimes.first;
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

/// Riverpod StateNotifier managing formal municipal grievances
class CivicFlowNotifier extends StateNotifier<CivicFlowState> {
  final FirebaseFirestore? _firestore;
  final Ref _ref;
  static const _uuid = Uuid();

  CivicFlowNotifier(this._ref, [this._firestore]) : super(const CivicFlowState()) {
    fetchCitizenCases();
  }

  /// Fetches cases filed by the current authenticated citizen
  Future<void> fetchCitizenCases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final cid = LoggingService.generateCorrelationId();
    LoggingService.logBreadcrumb('Fetching citizen CivicFlow cases', correlationId: cid);

    final currentUser = _ref.read(authProvider).user;
    final uid = currentUser?.uid;

    try {
      if (_firestore != null && uid != null) {
        final querySnapshot = await _firestore
            .collection('tenants')
            .doc(AppConstants.defaultTenantId)
            .collection('civicFlowCases')
            .where('citizenId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final fetched = querySnapshot.docs
              .map((doc) => CivicFlowCase.fromMap(doc.data(), id: doc.id))
              .toList();

          state = state.copyWith(citizenCases: fetched, isLoading: false);
          return;
        }
      }
    } catch (e) {
      LoggingService.logError('Failed to fetch cases from Firestore: $e', correlationId: cid);
    }

    // Fallback seed case for previewing the 10-stage timeline on day 1
    final now = DateTime.now();
    final sampleCase = CivicFlowCase(
      id: 'sample_cf_001',
      caseNumber: 'CF-${now.year}-000108',
      tenantId: AppConstants.defaultTenantId,
      citizenId: uid ?? 'citizen_demo',
      citizenName: currentUser?.displayName ?? 'Local Resident',
      citizenPhone: currentUser?.phoneNumber ?? '+91 98765 43210',
      category: 'Roads & Footpaths',
      subcategory: 'Dangerous Pothole',
      description:
          'Deep pothole spanning approximately 1.5 meters across northbound lane near Dilaram Chowk. Causing vehicle damage.',
      landmark: 'Opposite Central Bank ATM, Dilaram Chowk',
      locality: 'Rajpur Road',
      latitude: 30.3340,
      longitude: 78.0480,
      imageUrl:
          'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?auto=format&fit=crop&w=800&q=80',
      priority: 'high',
      status: CivicFlowStatus.inProgress,
      assignedDepartment: 'Public Works Department (PWD) - Ward 3 Division',
      assignedOfficer: 'Er. R. S. Chauhan (Assistant Engineer)',
      officerNotes:
          'Road patch material dispatched. Bitumen leveling underway as of 11:30 AM.',
      timeline: [
        CivicFlowTimelineEvent(
          status: CivicFlowStatus.submitted,
          title: 'Grievance Submitted',
          description: 'Case registered with reference number CF-${now.year}-000108.',
          timestamp: now.subtract(const Duration(days: 2, hours: 4)),
          actor: 'Citizen',
        ),
        CivicFlowTimelineEvent(
          status: CivicFlowStatus.underTriage,
          title: 'Triage Completed',
          description: 'Categorized under Road Infrastructure and verified within Ward 3 jurisdiction.',
          timestamp: now.subtract(const Duration(days: 2, hours: 1)),
          actor: 'Nagar Nigam Portal Control Desk',
        ),
        CivicFlowTimelineEvent(
          status: CivicFlowStatus.verified,
          title: 'Ground Inspection Verified',
          description: 'Field officer verified crater dimensions. Pothole poses safety hazard.',
          timestamp: now.subtract(const Duration(days: 1, hours: 8)),
          actor: 'Ward Inspector M. Negi',
        ),
        CivicFlowTimelineEvent(
          status: CivicFlowStatus.assigned,
          title: 'Assigned to PWD Division',
          description: 'Assigned to PWD maintenance gang for fast-track cold-mix patch work.',
          timestamp: now.subtract(const Duration(days: 1, hours: 2)),
          actor: 'Er. R. S. Chauhan',
        ),
        CivicFlowTimelineEvent(
          status: CivicFlowStatus.inProgress,
          title: 'Bitumen Repair Underway',
          description: 'Maintenance vehicle on site. Road patch repair actively in progress.',
          timestamp: now.subtract(const Duration(hours: 3)),
          actor: 'PWD Field Team',
        ),
      ],
      createdAt: now.subtract(const Duration(days: 2, hours: 4)),
      updatedAt: now.subtract(const Duration(hours: 3)),
    );

    state = state.copyWith(citizenCases: [sampleCase], isLoading: false);
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
    final uid = currentUser?.uid ?? 'anon_citizen';
    final citizenName = currentUser?.displayName ?? 'Local Resident';
    final citizenPhone = currentUser?.phoneNumber;

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
      landmark: landmark?.trim(),
      locality: locality,
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

    // 4. Save to Firestore
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
      LoggingService.logError('Firestore write error for case: $e', correlationId: cid);
    }

    // 5. Update local state and rate limit log
    final updatedTimes = [now, ...state.recentSubmissionTimes];
    state = state.copyWith(
      isLoading: false,
      citizenCases: [newCase, ...state.citizenCases],
      lastSubmittedCaseNumber: caseNumber,
      recentSubmissionTimes: updatedTimes,
    );

    LoggingService.logBreadcrumb('Case created successfully with reference $caseNumber', correlationId: cid);
    return caseNumber;
  }

  /// Citizen responds to a "Needs Information" request
  Future<bool> respondToNeedsInfo(String caseId, String responseText) async {
    final index = state.citizenCases.indexWhere((c) => c.id == caseId);
    if (index == -1) return false;

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
    final index = state.citizenCases.indexWhere((c) => c.id == caseId);
    if (index == -1) return false;

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
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return CivicFlowNotifier(ref, firestore);
});
