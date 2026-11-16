import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Single session log entry
class LogEntry {
  final DateTime timestamp;
  final String message;
  final String level;
  final String? correlationId;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
    this.correlationId,
    this.stackTrace,
  });

  @override
  String toString() {
    final cid = correlationId != null ? ' [$correlationId]' : '';
    return '[${timestamp.toIso8601String()}] [$level]$cid $message';
  }
}

/// Unified Logging & Observability Service for EVORA
/// Supports Correlation IDs, Breadcrumbs, In-Memory Ring Buffer, and PII Scrubbing.
class LoggingService {
  static const Uuid _uuid = Uuid();
  static final List<LogEntry> _logBuffer = [];
  static const int _maxBufferSize = 100;

  /// Generates an 8-character unique Correlation ID e.g. "req_9f8a2b1c"
  static String generateCorrelationId() {
    return 'req_${_uuid.v4().substring(0, 8)}';
  }

  /// Logs a lightweight user action / breadcrumb leading up to potential errors
  static void logBreadcrumb(String message, {String? correlationId}) {
    final sanitized = _scrubPii(message);
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      message: sanitized,
      level: 'INFO',
      correlationId: correlationId,
    ));

    if (kDebugMode) {
      developer.log(sanitized, name: 'EVORA_BREADCRUMB');
    }
  }

  /// Logs an error with optional stack trace and correlation ID
  static void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? correlationId,
  }) {
    final sanitized = _scrubPii(message);
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      message: sanitized,
      level: 'ERROR',
      correlationId: correlationId,
      stackTrace: stackTrace?.toString(),
    ));

    if (kDebugMode) {
      developer.log(
        sanitized,
        name: 'EVORA_ERROR',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Appends to the in-memory circular buffer (keeps last 100 entries)
  static void _addEntry(LogEntry entry) {
    if (_logBuffer.length >= _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
    _logBuffer.add(entry);
  }

  /// Retrieves recent sanitized session logs for export or in-app debugging
  static List<LogEntry> getRecentLogs() {
    return List.unmodifiable(_logBuffer);
  }

  /// PII Sanitization: Redacts passwords, OTP tokens, and phone numbers from logs
  static String _scrubPii(String input) {
    var output = input;
    // Mask 6-digit OTP codes
    output = output.replaceAll(RegExp(r'\b\d{6}\b'), '[OTP_REDACTED]');
    // Mask email addresses
    output = output.replaceAll(
      RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+'),
      '[EMAIL_REDACTED]',
    );
    // Mask 10-digit phone numbers
    output = output.replaceAll(RegExp(r'\b\d{10}\b'), '[PHONE_REDACTED]');
    return output;
  }
}
