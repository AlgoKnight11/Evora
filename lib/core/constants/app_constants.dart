import 'package:flutter_dotenv/flutter_dotenv.dart';

/// EVORA Global Application Constants
class AppConstants {
  static const String appName = 'EVORA';
  static const String appTagline = 'Greener Choices. Healthier Cities.';
  static const String appVersion = '1.0.0';

  static String? _safeEnv(String key) => dotenv.isInitialized ? dotenv.maybeGet(key) : null;

  // Cloudinary Configuration (Loaded securely from .env)
  static String get cloudinaryCloudName =>
      _safeEnv('CLOUDINARY_CLOUD_NAME') ??
      const String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: 'ztamooew');

  static String get cloudinaryUploadPreset =>
      _safeEnv('CLOUDINARY_UPLOAD_PRESET') ??
      const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'evora_unsigned');

  static String get cloudinaryUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  // Google Gemini AI API Key (Loaded securely from .env)
  static String get geminiApiKey =>
      _safeEnv('GEMINI_API_KEY') ??
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Default Pilot Tenant
  static String get defaultTenantId =>
      _safeEnv('DEFAULT_TENANT_ID') ??
      const String.fromEnvironment('DEFAULT_TENANT_ID', defaultValue: 'tenant_dehradun_01');

  static const String defaultCity = 'Dehradun';
  static const String defaultState = 'Uttarakhand';

  // Geofencing Defaults
  static const double defaultFeedRadiusKm = 3.0;
  static const double expandedFeedRadiusKm = 5.0;

  // Cloud Firestore Top-Level Collections
  static const String colTenants = 'tenants';
  static const String colUsers = 'users';

  // Tenant-Scoped Subcollections
  static const String subColMembers = 'members';
  static const String subColWards = 'wards';
  static const String subColDepartments = 'departments';
  static const String subColCivicFlowCases = 'civicFlowCases';
  static const String subColTasks = 'tasks';
  static const String subColCivicBookPosts = 'civicBookPosts';
  static const String subColFacilities = 'facilities';
  static const String subColMissions = 'missions';
  static const String subColMissionParticipations = 'missionParticipations';
  static const String subColImpactLedger = 'impactLedger';
  static const String subColEcoCoinLedger = 'ecoCoinLedger';
  static const String subColNotifications = 'notifications';
  static const String subColModerationCases = 'moderationCases';
  static const String subColAuditEvents = 'auditEvents';
  static const String subColServicePolicies = 'servicePolicies';

  // Rate Limiting Policy Thresholds
  static const int maxOtpRequestsPerHour = 5;
  static const int maxCasesPerTenMinutes = 3;
  static const int maxEcoBuddyMessagesPerFiveMinutes = 15;
}
