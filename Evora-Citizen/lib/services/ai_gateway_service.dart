import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../features/ai_engine/models/civic_ai_models.dart';
import '../features/civic_flow/models/civic_taxonomy.dart';
import 'logging_service.dart';
import 'pii_redaction_service.dart';

/// Custom exception surfaced by [AiGatewayService] with diagnostic context.
class AiGatewayException implements Exception {
  final String message;
  final int? statusCode;
  final bool isMissingKey;
  final bool isRateLimited;
  final String correlationId;

  const AiGatewayException(
    this.message, {
    this.statusCode,
    this.isMissingKey = false,
    this.isRateLimited = false,
    required this.correlationId,
  });

  @override
  String toString() => message;
}

/// Lightweight FIFO concurrency limiter mirroring backend Cloud Tasks behavior
/// so peak bursts (e.g. 50 concurrent requests) never overwhelm the API quota.
class _AiConcurrencySemaphore {
  final int maxConcurrent;
  int _active = 0;
  int maxObservedActive = 0;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  _AiConcurrencySemaphore(this.maxConcurrent);

  int get activeCount => _active;
  int get queuedCount => _waitQueue.length;

  Future<void> acquire() async {
    if (_active < maxConcurrent) {
      _active++;
      if (_active > maxObservedActive) maxObservedActive = _active;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final next = _waitQueue.removeFirst();
      next.complete();
    } else if (_active > 0) {
      _active--;
    }
  }
}

/// Centralized AI Gateway communicating with Gemini 3.8 Flash (Interactions API)
/// and Gemini Embedding 2 for Vision Triage, Multi-Department Routing,
/// PII Bounding Box Detection, and Multimodal Embeddings.
class AiGatewayService {
  final http.Client _client;
  final String? apiKeyOverride;
  final _AiConcurrencySemaphore _semaphore;
  final Duration baseRetryDelay;
  final Random _random = Random();

  // In-memory Semantic Response Cache keyed by SHA-256 content hash
  final Map<String, CivicVisionAnalysis> _visionCache = {};
  final Map<String, List<double>> _embeddingCache = {};

  // Observability counters (useful for diagnostics & concurrency tests)
  int totalRequestsProcessed = 0;
  int totalRetriesAttempted = 0;
  int totalCacheHits = 0;

  AiGatewayService({
    http.Client? client,
    this.apiKeyOverride,
    int maxConcurrent = AppConstants.maxConcurrentAiRequests,
    this.baseRetryDelay = const Duration(milliseconds: 500),
  })  : _client = client ?? http.Client(),
        _semaphore = _AiConcurrencySemaphore(maxConcurrent);

  int get activeQueueSlots => _semaphore.activeCount;
  int get pendingQueueLength => _semaphore.queuedCount;
  int get maxObservedConcurrency => _semaphore.maxObservedActive;

  String get _resolvedApiKey {
    final key = (apiKeyOverride ?? AppConstants.geminiApiKey).trim();
    if (key.isEmpty || key.contains('your_') || key.contains('placeholder')) {
      return '';
    }
    return key;
  }

  bool get isConfigured => _resolvedApiKey.isNotEmpty;

  /// Analyzes a citizen photo + optional user description via `gemini-3.8-flash`
  /// using the Interactions API (`POST /v1beta/interactions`), returning:
  /// - Single authoritative Category/Subcategory matching [CivicTaxonomy]
  /// - Multi-departmental routing (`leadDepartment` + co-assigned `requiredDepartments`)
  /// - Severity & confidence score
  /// - Normalized `0..1000` PII bounding boxes (faces & license plates)
  Future<CivicVisionAnalysis> analyzeCivicIssueImage({
    required Uint8List imageBytes,
    String? userDescriptionHint,
    String? localityHint,
    bool compressImage = true,
  }) async {
    final cid = LoggingService.generateCorrelationId();
    final apiKey = _resolvedApiKey;
    if (apiKey.isEmpty) {
      throw AiGatewayException(
        'GEMINI_API_KEY is not configured in .env. Please save your API key to enable AI Vision triage.',
        isMissingKey: true,
        correlationId: cid,
      );
    }

    final Uint8List preparedBytes = compressImage
        ? await PiiRedactionService.compressAndStripExif(imageBytes)
        : imageBytes;

    // Check semantic cache first
    final hintNormalized = (userDescriptionHint ?? '').trim().toLowerCase();
    final hashBytes = sha256
        .convert([...preparedBytes, ...utf8.encode('|$hintNormalized')])
        .toString();

    final cached = _visionCache[hashBytes];
    if (cached != null) {
      totalCacheHits++;
      totalRequestsProcessed++;
      LoggingService.logBreadcrumb('AI Vision cache hit ($hashBytes)', correlationId: cid);
      return cached.copyWith(fromCache: true);
    }

    final base64Image = base64Encode(preparedBytes);

    final systemInstruction = '''
You are EVORA CivicFlow AI Triage Engine for Indian urban local bodies (Dehradun, Uttarakhand).
Analyze citizen-submitted photographs and optional descriptions to:
1. Validate whether the photo shows a real civic, municipal, environmental, or infrastructure issue. (Set is_valid_civic_issue=false for unrelated selfies, blank screens, indoor pets, or blurry unreadable shots).
2. Classify strictly into ONE primary category & subcategory from the approved taxonomy below:
${_formatTaxonomyForPrompt()}
3. Detect MULTI-DEPARTMENTAL involvement when multiple civic hazards coexist (e.g., flooded road with broken asphalt + exposed electric pole wire -> assign one Lead department and add all Supporting departments with specific action reasons). If single-issue, list only the Lead department.
   Official Departments: ${CivicTaxonomy.allDepartments.join(', ')}.
4. Privacy Redaction: Carefully inspect the entire image for ANY visible human faces (including background passersby) and ANY vehicle license/number plates (cars, bikes, autos, trucks). Return every detected region in pii_regions using integer 0..1000 normalized coordinates [ymin, xmin, ymax, xmax].

Strictly follow the output JSON schema. Do not invent categories or departments outside the provided lists.
''';

    final userPrompt = StringBuffer()
      ..writeln('Inspect this uploaded civic issue photo.')
      ..writeln(
        userDescriptionHint != null && userDescriptionHint.trim().isNotEmpty
            ? 'Citizen note: "${userDescriptionHint.trim()}"'
            : 'Citizen note: None provided.',
      )
      ..writeln(
        localityHint != null && localityHint.trim().isNotEmpty
            ? 'Reported locality: ${localityHint.trim()}'
            : '',
      )
      ..writeln(
        'Return accurate classification, multi-department assignments with reasons, concise title/description, severity, and any face/license_plate bounding boxes.',
      );

    final Map<String, dynamic> jsonSchema = {
      'type': 'object',
      'properties': {
        'is_valid_civic_issue': {'type': 'boolean'},
        'rejection_reason': {'type': 'string'},
        'category': {
          'type': 'string',
          'enum': CivicTaxonomy.categories.keys.toList(),
        },
        'subcategory': {'type': 'string'},
        'confidence': {'type': 'number'},
        'severity': {
          'type': 'string',
          'enum': ['low', 'medium', 'high', 'urgent'],
        },
        'suggested_title': {'type': 'string'},
        'suggested_description': {'type': 'string'},
        'lead_department': {
          'type': 'string',
          'enum': CivicTaxonomy.allDepartments,
        },
        'involved_departments': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'department': {
                'type': 'string',
                'enum': CivicTaxonomy.allDepartments,
              },
              'role': {
                'type': 'string',
                'enum': ['lead', 'supporting'],
              },
              'reason': {'type': 'string'},
            },
            'required': ['department', 'role', 'reason'],
          },
        },
        'pii_regions': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'label': {
                'type': 'string',
                'enum': ['face', 'license_plate'],
              },
              'ymin': {'type': 'integer'},
              'xmin': {'type': 'integer'},
              'ymax': {'type': 'integer'},
              'xmax': {'type': 'integer'},
            },
            'required': ['label', 'ymin', 'xmin', 'ymax', 'xmax'],
          },
        },
        'issue_fingerprint': {'type': 'string'},
      },
      'required': [
        'is_valid_civic_issue',
        'category',
        'subcategory',
        'confidence',
        'severity',
        'suggested_title',
        'suggested_description',
        'lead_department',
        'involved_departments',
        'pii_regions',
        'issue_fingerprint',
      ],
    };

    Map<String, dynamic> buildPayload({
      required String modelName,
      required bool useArrayResponseFormat,
    }) {
      return {
        'model': modelName,
        'system_instruction': systemInstruction,
        'store': false, // Never retain unredacted citizen images on API side
        'input': [
          {
            'type': 'image',
            'data': base64Image,
            'mime_type': 'image/jpeg',
          },
          {
            'type': 'text',
            'text': userPrompt.toString(),
          },
        ],
        'generation_config': {
          'thinking_level': 'low',
          'max_output_tokens': 1400,
        },
        'response_format': useArrayResponseFormat
            ? [
                {
                  'type': 'text',
                  'mime_type': 'application/json',
                  'schema': jsonSchema,
                }
              ]
            : {
                'type': 'text',
                'mime_type': 'application/json',
                'schema': jsonSchema,
              },
      };
    }

    http.Response? response;
    Object? lastNetworkError;
    final modelsToTry = AppConstants.geminiVisionFallbackModels;

    for (int i = 0; i < modelsToTry.length; i++) {
      final modelName = modelsToTry[i];
      final hasMoreModels = i < modelsToTry.length - 1;

      try {
        response = await _executeQueuedWithRetry(
          cid: cid,
          maxRetries: 3,
          maxBusyRetries: hasMoreModels ? 1 : 2,
          requestTimeout: Duration(seconds: hasMoreModels ? 15 : 25),
          requestFn: () => _client.post(
            Uri.parse(AppConstants.geminiInteractionsEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
              'Api-Revision': AppConstants.geminiApiRevision,
            },
            body: jsonEncode(
              buildPayload(modelName: modelName, useArrayResponseFormat: true),
            ),
          ),
        );

        // Graceful revision fallback if endpoint expects object response_format
        if (response.statusCode == 400 &&
            response.body.toLowerCase().contains('response_format')) {
          response = await _executeQueuedWithRetry(
            cid: cid,
            maxRetries: 2,
            maxBusyRetries: 1,
            requestTimeout: const Duration(seconds: 20),
            requestFn: () => _client.post(
              Uri.parse(AppConstants.geminiInteractionsEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
                'Api-Revision': AppConstants.geminiApiRevision,
              },
              body: jsonEncode(
                buildPayload(modelName: modelName, useArrayResponseFormat: false),
              ),
            ),
          );
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          break;
        }

        final shouldPromoteFallback = hasMoreModels &&
            (response.statusCode == 503 ||
                response.statusCode == 429 ||
                response.statusCode == 404 ||
                response.statusCode >= 500);
        if (!shouldPromoteFallback) {
          break;
        }
        LoggingService.logBreadcrumb(
          'Promoting Vision fallback after $modelName returned HTTP ${response.statusCode}',
          correlationId: cid,
        );
      } catch (e) {
        lastNetworkError = e;
        if (!hasMoreModels) rethrow;
        LoggingService.logBreadcrumb(
          'Promoting Vision fallback after $modelName error: $e',
          correlationId: cid,
        );
      }
    }

    if (response == null) {
      throw AiGatewayException(
        'Vision analysis failed: ${lastNetworkError ?? "Unable to reach Gemini API"}',
        correlationId: cid,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiGatewayException(
        'Vision analysis failed (${response.statusCode}): ${_extractErrorMessage(response.body)}',
        statusCode: response.statusCode,
        isRateLimited: response.statusCode == 429,
        correlationId: cid,
      );
    }

    final analysis = _parseVisionResponse(
      responseBody: response.body,
      correlationId: cid,
    );

    _visionCache[hashBytes] = analysis;
    totalRequestsProcessed++;
    return analysis;
  }

  /// Generates a normalized Matryoshka vector embedding (`output_dimensionality: 256`)
  /// using `gemini-embedding-2` (image + text multimodal), falling back gracefully
  /// to `gemini-embedding-001` (text) if needed.
  Future<List<double>?> generateEmbedding({
    required String text,
    Uint8List? imageBytes,
  }) async {
    final cid = LoggingService.generateCorrelationId();
    final apiKey = _resolvedApiKey;
    if (apiKey.isEmpty || (text.trim().isEmpty && imageBytes == null)) {
      return null;
    }

    final cleanText = text.trim();
    final cacheKey = sha256
        .convert([
          ...utf8.encode(cleanText),
          ...(imageBytes ?? const <int>[]),
        ])
        .toString();

    final cached = _embeddingCache[cacheKey];
    if (cached != null) {
      totalCacheHits++;
      return cached;
    }

    final parts = <Map<String, dynamic>>[];
    if (cleanText.isNotEmpty) {
      parts.add({'text': cleanText});
    }

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final prepared = await PiiRedactionService.compressAndStripExif(
        imageBytes,
        maxDimension: 768,
        quality: 75,
      );
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(prepared),
        },
      });
    }

    Future<List<double>?> callEmbedEndpoint(
      String endpoint,
      List<Map<String, dynamic>> payloadParts,
    ) async {
      final body = {
        'content': {'parts': payloadParts},
        'output_dimensionality': AppConstants.geminiEmbeddingDimensions,
      };
      final response = await _executeQueuedWithRetry(
        cid: cid,
        requestFn: () => _client.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(body),
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final values = (decoded['embedding']?['values'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList();
      if (values == null || values.isEmpty) return null;
      return _l2Normalize(values);
    }

    try {
      List<double>? vector = await callEmbedEndpoint(
        AppConstants.geminiEmbeddingsEndpoint,
        parts,
      );

      // Clean fallback to text embedding model if multimodal model unavailable
      if (vector == null && cleanText.isNotEmpty) {
        vector = await callEmbedEndpoint(
          AppConstants.geminiTextEmbeddingFallbackEndpoint,
          [{'text': cleanText}],
        );
      }

      if (vector != null) {
        _embeddingCache[cacheKey] = vector;
      }
      return vector;
    } catch (e) {
      LoggingService.logError('Embedding generation note: $e', correlationId: cid);
      return null;
    }
  }

  /// Cosine similarity in [-1.0, 1.0] between two dense vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom <= 1e-12) return 0.0;
    return (dot / denom).clamp(-1.0, 1.0);
  }

  static List<double> _l2Normalize(List<double> vec) {
    double sumSq = 0.0;
    for (final v in vec) {
      sumSq += v * v;
    }
    final norm = sqrt(sumSq);
    if (norm <= 1e-12) return vec;
    return vec.map((v) => v / norm).toList();
  }

  /// Acquires a bounded concurrency slot and retries 429/5xx/timeouts with
  /// exponential backoff + random jitter.
  /// - [maxRetries] applies to HTTP 429 / general network glitches.
  /// - [maxBusyRetries] limits retries on HTTP 503/5xx & TimeoutException when
  ///   fallback models are available so busy primary models degrade fast.
  Future<http.Response> _executeQueuedWithRetry({
    required String cid,
    required Future<http.Response> Function() requestFn,
    int maxRetries = 3,
    int? maxBusyRetries,
    Duration requestTimeout = const Duration(seconds: 30),
  }) async {
    final busyLimit = maxBusyRetries ?? maxRetries;
    await _semaphore.acquire();
    try {
      int attempt = 0;
      while (true) {
        try {
          final res = await requestFn().timeout(requestTimeout);

          final isRateLimit = res.statusCode == 429;
          final isServerBusy = res.statusCode >= 500 && res.statusCode < 600;
          final retryCap = isServerBusy ? busyLimit : maxRetries;

          if ((!isRateLimit && !isServerBusy) || attempt >= retryCap) {
            return res;
          }

          attempt++;
          totalRetriesAttempted++;

          final retryAfterHeader = res.headers['retry-after'];
          final retryAfterSecs =
              retryAfterHeader != null ? int.tryParse(retryAfterHeader.trim()) : null;

          final backoffMs = baseRetryDelay.inMilliseconds * pow(2, attempt - 1).toInt();
          final jitterMs = _random.nextInt(max(10, backoffMs ~/ 2));
          final waitDuration = retryAfterSecs != null
              ? Duration(seconds: retryAfterSecs.clamp(1, 10))
              : Duration(milliseconds: backoffMs + jitterMs);

          LoggingService.logBreadcrumb(
            'Gemini API ${res.statusCode} -> retry $attempt/$retryCap after ${waitDuration.inMilliseconds}ms',
            correlationId: cid,
          );
          await Future.delayed(waitDuration);
        } on TimeoutException {
          if (attempt >= busyLimit) rethrow;
          attempt++;
          totalRetriesAttempted++;
          await Future.delayed(
            Duration(milliseconds: baseRetryDelay.inMilliseconds * pow(2, attempt - 1).toInt()),
          );
        } on SocketException {
          if (attempt >= maxRetries) rethrow;
          attempt++;
          totalRetriesAttempted++;
          await Future.delayed(
            Duration(milliseconds: baseRetryDelay.inMilliseconds * pow(2, attempt - 1).toInt()),
          );
        }
      }
    } finally {
      _semaphore.release();
    }
  }

  CivicVisionAnalysis _parseVisionResponse({
    required String responseBody,
    required String correlationId,
  }) {
    final root = jsonDecode(responseBody) as Map<String, dynamic>;
    String rawText = '';

    // 1. Standard Interactions API `steps` format (May 2026+)
    final steps = root['steps'] as List<dynamic>?;
    if (steps != null && steps.isNotEmpty) {
      for (final step in steps.reversed) {
        if (step is Map<String, dynamic> && step['type'] == 'model_output') {
          rawText = _extractTextFromContentList(step['content']);
          if (rawText.isNotEmpty) break;
        }
      }
      // Fallback: last step with any text content
      if (rawText.isEmpty) {
        for (final step in steps.reversed) {
          if (step is Map<String, dynamic>) {
            rawText = _extractTextFromContentList(step['content']);
            if (rawText.isNotEmpty) break;
          }
        }
      }
    }

    // 2. Fallback: Legacy `outputs` or `candidates` shapes
    if (rawText.isEmpty && root['outputs'] is List) {
      final outputs = root['outputs'] as List<dynamic>;
      for (final out in outputs.reversed) {
        if (out is Map<String, dynamic> && out['text'] is String) {
          rawText = out['text'] as String;
          break;
        }
      }
    }

    final cleanJsonStr = _stripJsonFences(rawText);
    if (cleanJsonStr.isEmpty) {
      throw AiGatewayException(
        'Gemini returned an empty classification response.',
        correlationId: correlationId,
      );
    }

    final parsed = jsonDecode(cleanJsonStr) as Map<String, dynamic>;

    final isValid = parsed['is_valid_civic_issue'] as bool? ?? true;
    final rejectionReason = (parsed['rejection_reason'] as String?)?.trim();
    final category = CivicTaxonomy.normalizeCategory(parsed['category']?.toString());
    final subcategory = CivicTaxonomy.normalizeSubcategory(
      category,
      parsed['subcategory']?.toString(),
    );

    final confidenceRaw = (parsed['confidence'] as num?)?.toDouble() ?? 0.85;
    final confidence = confidenceRaw.clamp(0.0, 1.0);

    final sevRaw = (parsed['severity']?.toString() ?? 'medium').toLowerCase();
    final severity = const {'low', 'medium', 'high', 'urgent'}.contains(sevRaw)
        ? sevRaw
        : 'medium';

    final leadDept = CivicTaxonomy.normalizeDepartment(
      parsed['lead_department']?.toString(),
      fallbackCategory: category,
    );

    // Multi-department normalization & deduplication
    final assignments = <DepartmentAssignment>[];
    final seenDepts = <String>{};

    final rawInvolved = parsed['involved_departments'] as List<dynamic>? ?? const [];
    for (final entry in rawInvolved) {
      if (entry is! Map<String, dynamic>) continue;
      final normalizedDept = CivicTaxonomy.normalizeDepartment(
        entry['department']?.toString(),
        fallbackCategory: category,
      );
      if (seenDepts.contains(normalizedDept)) continue;
      seenDepts.add(normalizedDept);

      final role = (entry['role']?.toString().toLowerCase() == 'lead' ||
              normalizedDept == leadDept)
          ? 'lead'
          : 'supporting';
      final reason = (entry['reason']?.toString() ?? '').trim();
      assignments.add(DepartmentAssignment(
        department: normalizedDept,
        role: role,
        reason: reason.isNotEmpty
            ? reason
            : 'Inspection and remediation for $subcategory.',
      ));
    }

    // Ensure lead department is present first
    if (!seenDepts.contains(leadDept)) {
      assignments.insert(
        0,
        DepartmentAssignment(
          department: leadDept,
          role: 'lead',
          reason: 'Primary department responsible for $category ($subcategory).',
        ),
      );
    } else {
      assignments.sort((a, b) {
        if (a.department == leadDept) return -1;
        if (b.department == leadDept) return 1;
        return 0;
      });
    }

    final requiredDepartments = assignments.map((a) => a.department).toList();

    final piiList = <PiiBoundingBox>[];
    final rawPii = parsed['pii_regions'] as List<dynamic>? ?? const [];
    for (final item in rawPii) {
      if (item is Map<String, dynamic>) {
        final box = PiiBoundingBox.fromMap(item);
        if (box.isValid) piiList.add(box);
      }
    }

    final title = (parsed['suggested_title']?.toString() ?? '').trim();
    final desc = (parsed['suggested_description']?.toString() ?? '').trim();
    final fingerprint = (parsed['issue_fingerprint']?.toString() ?? '').trim();

    return CivicVisionAnalysis(
      isValidCivicIssue: isValid,
      rejectionReason: (rejectionReason != null && rejectionReason.isNotEmpty)
          ? rejectionReason
          : null,
      category: category,
      subcategory: subcategory,
      civicBookCategoryKey: CivicTaxonomy.toCivicBookKey(category),
      confidence: confidence,
      severity: severity,
      suggestedTitle: title.isNotEmpty ? title : '$subcategory Issue Reported',
      suggestedDescription: desc.isNotEmpty
          ? desc
          : 'Detected $subcategory ($category) requiring municipal attention.',
      leadDepartment: leadDept,
      requiredDepartments: requiredDepartments,
      departmentAssignments: assignments,
      piiRegions: piiList,
      issueFingerprintText: fingerprint.isNotEmpty
          ? fingerprint
          : '$category $subcategory $title $desc',
      correlationId: correlationId,
    );
  }

  String _extractTextFromContentList(dynamic content) {
    if (content is String) return content;
    if (content is! List) return '';
    final buf = StringBuffer();
    for (final item in content) {
      if (item is Map<String, dynamic>) {
        final type = item['type']?.toString();
        if (type == 'text' || item['text'] != null) {
          buf.write(item['text']?.toString() ?? '');
        }
      }
    }
    return buf.toString();
  }

  String _stripJsonFences(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      trimmed = trimmed.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return trimmed.trim();
  }

  String _extractErrorMessage(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return map['error']?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  String _formatTaxonomyForPrompt() {
    final sb = StringBuffer();
    CivicTaxonomy.categories.forEach((cat, subs) {
      sb.writeln('- $cat: ${subs.join(" | ")}');
    });
    return sb.toString();
  }
}

/// Global Riverpod provider for the Phase 3 Gemini AI Gateway.
final aiGatewayProvider = Provider<AiGatewayService>((ref) {
  return AiGatewayService();
});
