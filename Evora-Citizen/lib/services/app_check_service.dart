import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logging_service.dart';

/// Service managing Firebase App Check attestation and token lifecycle.
/// Protects backend resources (Firestore, Cloud Functions, Storage) against
/// unauthorized scripts, bots, and Man-in-the-Middle abuse.
class AppCheckService {
  final FirebaseAppCheck? _customAppCheck;
  bool _isActivated = false;

  AppCheckService({FirebaseAppCheck? appCheck}) : _customAppCheck = appCheck;

  FirebaseAppCheck get _appCheck => _customAppCheck ?? FirebaseAppCheck.instance;

  bool get isActivated => _isActivated;

  /// Activates Firebase App Check with platform-specific attestation providers:
  /// - Android: Play Integrity in release, Debug provider in development
  /// - iOS / macOS: DeviceCheck in release, Debug provider in development
  Future<void> initialize() async {
    final cid = LoggingService.generateCorrelationId();
    try {
      if (kIsWeb) {
        // Web attestation (ReCaptcha v3 / Enterprise) can be added when Web target activates
        LoggingService.logBreadcrumb('App Check: Web platform deferred', correlationId: cid);
        return;
      }

      await _appCheck.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        appleProvider: kReleaseMode
            ? AppleProvider.deviceCheck
            : AppleProvider.debug,
      );

      _isActivated = true;
      LoggingService.logBreadcrumb(
        'Firebase App Check activated successfully (${kReleaseMode ? "Production Play Integrity" : "Debug Provider"})',
        correlationId: cid,
      );

      // In debug mode, retrieve token to verify provider status
      if (!kReleaseMode) {
        final token = await getToken();
        if (token != null) {
          debugPrint('🛡️ [AppCheck Debug] Active token acquired: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
        }
      }
    } catch (e) {
      LoggingService.logError(
        'Firebase App Check activation note: $e',
        correlationId: cid,
      );
    }
  }

  /// Retrieves the current App Check token, with optional cache bypass.
  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      return await _appCheck.getToken(forceRefresh);
    } catch (e) {
      debugPrint('[AppCheck] getToken error: $e');
      return null;
    }
  }

  /// Stream of token change events for real-time validation.
  Stream<String?> get onTokenChange => _appCheck.onTokenChange;

  /// Validates whether a token is present and structurally valid.
  bool isValidToken(String? token) {
    if (token == null) return false;
    final trimmed = token.trim();
    return trimmed.isNotEmpty && trimmed.length >= 16;
  }
}

/// Global Riverpod provider for App Check service.
final appCheckServiceProvider = Provider<AppCheckService>((ref) {
  return AppCheckService();
});
